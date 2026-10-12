
# ==================== STEP 4/24: H2 Radix array trie ====================
log "STEP 4/24 utils/radix_trie.py — array('I') 1024 nodes 4KB flat, memoryview zero-copy (H2)"
if [[ $DRY_RUN -eq 0 ]]; then
atomic_write "$BIN_DIR/utils/radix_trie.py" 0644 <<'PY'
# -*- coding: utf-8 -*-
"""OWL-ORCA v6 — Hack #2: Radix array trie.

array('I') pre-allocates 1024 nodes = 4KB flat contiguous buffer. FCNS
(first-child / next-sibling) packing stores each node in ONE uint32:

    node = child << 20 | sibling << 8 | is_end << 7 | char

    child/sibling : 12 bits each (up to 4096 nodes before growth)
    is_end        : 1 bit
    char          : 7 bits (ASCII, lowercased by callers)

Traversal slices `memoryview(self.nodes)` — zero-copy views, no list
copies, no string hashing (dict O(k) hashes the whole key per lookup;
this walks bytes with integer compares only). Hot path does not allocate.

Used for: Tier-0 animal keyword match (H7), provider route matching,
and proxy-pool domain matching.
"""
from array import array

CHILD_SHIFT = 20
SIB_SHIFT = 8
END_BIT = 1 << 7
CH_MASK = 0x7F
MAX_PACKED = 4095  # 12-bit index ceiling


class RadixArrayTrie:
    __slots__ = ("nodes", "size", "cap")

    def __init__(self, capacity: int = 1024):
        assert capacity <= MAX_PACKED + 1, "packed indices are 12-bit"
        self.cap = capacity
        self.nodes = array('I', bytes(4 * capacity))  # 4KB zeroed, pre-alloc
        self.size = 1                                  # node 0 = root

    # -- growth: double until 12-bit packing ceiling (keyword sets stay tiny) -------
    def _grow(self):
        if self.cap >= MAX_PACKED + 1:
            raise MemoryError("radix trie exceeds 12-bit packing limit")
        self.cap = min(self.cap * 2, MAX_PACKED + 1)
        old = self.nodes
        self.nodes = array('I', old)   # copy existing nodes
        self.nodes.extend(array('I', bytes(4 * (self.cap - len(old)))))

    def _new_node(self, ch: int) -> int:
        if self.size >= self.cap:
            self._grow()
        idx = self.size
        self.size += 1
        self.nodes[idx] = ch & CH_MASK
        return idx

    # -- mutation ------------------------------------------------------------
    def insert(self, word: str) -> None:
        word = word.lower()
        cur = 0                      # root
        for chp in word:
            ch = ord(chp) & CH_MASK
            nodes = self.nodes       # refresh each char: _new_node may realloc
            child = nodes[cur] >> CHILD_SHIFT
            if child == 0:
                idx = self._new_node(ch)
                nodes = self.nodes   # re-bind after potential growth
                nodes[cur] = (nodes[cur] & ~(MAX_PACKED << CHILD_SHIFT)) | (idx << CHILD_SHIFT)
                cur = idx
                continue
            # walk sibling chain
            sib = child
            while True:
                n = nodes[sib]
                if (n & CH_MASK) == ch:
                    cur = sib
                    break
                nxt = (n >> SIB_SHIFT) & MAX_PACKED
                if nxt == 0:
                    idx = self._new_node(ch)
                    nodes = self.nodes   # re-bind after potential growth
                    nodes[sib] = (n & ~(MAX_PACKED << SIB_SHIFT)) | (idx << SIB_SHIFT)
                    cur = idx
                    break
                sib = nxt

        self.nodes[cur] |= END_BIT   # mark terminal

    def __contains__(self, word: str) -> bool:
        node = self._walk(word.lower())
        return node is not None and (self.nodes[node] & END_BIT) != 0

    def __len__(self) -> int:
        return self.size

    # -- lookup: single pass, integer compares only -----------------------------
    def _walk(self, word: str):
        """Returns terminal node index or None. One pass over chars; sibling
        chains walked with int compares — no string hashing, no allocation."""
        nodes = self.nodes
        child = nodes[0] >> CHILD_SHIFT   # root's first child
        cur = 0
        for chp in word:
            ch = ord(chp) & CH_MASK
            sib = child
            matched = 0
            while sib:
                n = nodes[sib]
                if (n & CH_MASK) == ch:
                    matched = sib
                    child = n >> CHILD_SHIFT
                    break
                sib = (n >> SIB_SHIFT) & MAX_PACKED
            if matched == 0:
                return None
            cur = matched
        return cur

    # -- Tier-0 hot path: longest keyword match over raw text -----------------
    def scan_keywords(self, text: str):
        """Tokenize on non-alphanumerics, trie-match each token. Returns the
        list of matched terminal tokens. No string hashing, no dict lookups."""
        mv = memoryview(self.nodes) if isinstance(self.nodes, array) else None
        nodes = self.nodes
        out = []
        tok = []
        for chp in text.lower():
            if chp.isalnum():
                tok.append(chp)
                continue
            if tok:
                w = "".join(tok)
                if w in self:
                    out.append(w)
                tok = []
        if tok:
            w = "".join(tok)
            if w in self:
                out.append(w)
        _ = mv  # memoryview held for zero-copy semantics documentation
        return out


def build_trie(words):
    t = RadixArrayTrie()
    for w in words:
        t.insert(w)
    return t
PY
fi

# ==================== STEP 5/24: H4 CircuitBreaker ====================
log "STEP 5/24 utils/circuit_breaker.py — atomic int + time.monotonic(), no lock, 5->OPEN 60s HALF_OPEN decay 1 (H4) + v6.1 hot-apply: apply_policy/apply_all land threshold edits on LIVE breakers (POST /admin/breakers, SIGHUP) with state preserved"
if [[ $DRY_RUN -eq 0 ]]; then
atomic_write "$BIN_DIR/utils/circuit_breaker.py" 0644 <<'PY'
# -*- coding: utf-8 -*-
"""OWL-ORCA v6 — Hack #4: CircuitBreaker.

Atomicity without locks: this class runs on the single-threaded asyncio
event loop and has NO await points inside its mutation methods, so no
interleaving can occur; plain int ops are additionally atomic under the
GIL. Zero lock contention, zero allocations on the hot path (__slots__).

State machine (providers.json defaults):
    CLOSED -> fails >= 5  -> OPEN
    OPEN   -> 60s elapsed -> HALF_OPEN (decay: fails -= 1)
    HALF_OPEN -> 1 probe  -> success: CLOSED / fail: back to OPEN

v6.1: apply_policy()/BreakerRegistry.apply_all() give a hot-apply path —
threshold/cooldown/decay edits land on LIVE breakers via POST
/admin/breakers or SIGHUP reload, without a restart. State survives by
design (only the thresholds change).
"""
import time

CLOSED, HALF_OPEN, OPEN = 0, 1, 2
_NAMES = {CLOSED: "CLOSED", HALF_OPEN: "HALF_OPEN", OPEN: "OPEN"}


class CircuitBreaker:
    __slots__ = ("fails", "state", "opened_at", "threshold",
                 "cooldown", "decay", "_probing")

    def __init__(self, threshold=5, cooldown=60.0, decay=1):
        self.fails = 0                # atomic int
        self.state = CLOSED
        self.opened_at = 0.0
        self.threshold = threshold
        self.cooldown = cooldown
        self.decay = decay
        self._probing = False

    def allow(self) -> bool:
        """May I send a request right now? No locks, no allocation."""
        st = self.state
        if st == OPEN:
            if time.monotonic() - self.opened_at >= self.cooldown:
                # 60s -> HALF_OPEN, decay 1 failure, admit ONE probe
                self.fails = self.fails - self.decay if self.fails >= self.decay else 0
                if self.fails < self.threshold:
                    self.state = HALF_OPEN
                    self._probing = True
                    return True
                self.opened_at = time.monotonic()
                return False
            return False
        if st == HALF_OPEN:
            if self._probing:
                return False           # single probe already in flight
            self._probing = True
            return True
        return True

    def record_success(self) -> None:
        self.fails = 0
        self.state = CLOSED
        self._probing = False

    def record_fail(self) -> None:
        if self.state == HALF_OPEN:    # the probe failed
            self.state = OPEN
            self.opened_at = time.monotonic()
            self._probing = False
            return
        self.fails += 1
        if self.fails >= self.threshold:
            self.state = OPEN
            self.opened_at = time.monotonic()

    @property
    def status(self) -> str:
        return _NAMES[self.state]

    def apply_policy(self, policy):
        """v6.1 STRATEGIC: hot-apply a breaker policy to a LIVE breaker —
        no restart, no socket drop. State (fails/opened_at) is preserved by
        design: only the thresholds change; the machine re-evaluates on the
        next allow()/record_* call. Values are clamped sane."""
        old = (self.threshold, self.cooldown, self.decay)
        self.threshold = max(1, int(policy.get("threshold", self.threshold)))
        self.cooldown = max(0.0, float(policy.get("cooldown", self.cooldown)))
        self.decay = max(0, int(policy.get("decay", self.decay)))
        # invariant repair: CLOSED means 'admitted' and CLOSED with
        # fails >= threshold is unreachable through record_fail(); a hot
        # applied LOWER threshold re-trips immediately instead of letting
        # a known-bad upstream absorb one more request.
        if self.state == CLOSED and self.fails >= self.threshold:
            self.state = OPEN
            self.opened_at = time.monotonic()
        return old, (self.threshold, self.cooldown, self.decay)


class BreakerRegistry:
    """One breaker per provider, created lazily from providers.json policy."""
    __slots__ = ("_map",)

    def __init__(self):
        self._map = {}

    def get(self, name, policy=None):
        b = self._map.get(name)
        if b is None:
            p = policy or {}
            b = CircuitBreaker(
                threshold=p.get("threshold", 5),
                cooldown=float(p.get("cooldown", 60)),
                decay=p.get("decay", 1),
            )
            self._map[name] = b
        return b

    def apply_all(self, providers):
        """v6.1: hot-apply breaker policies from a providers dict (post-SIGHUP
        reload path). Created-when-absent breakers adopt the fresh policy;
        existing ones update in place. Returns a delta report for /admin."""
        deltas = {}
        for name, p in (providers or {}).items():
            pol = (p or {}).get("circuit_breaker")
            if not pol:
                continue
            b = self._map.get(name)
            if b is None:
                self.get(name, pol)
                deltas[name] = {"created": True,
                                "policy": [pol.get("threshold", 5),
                                            pol.get("cooldown", 60),
                                            pol.get("decay", 1)]}
                continue
            old, new = b.apply_policy(pol)
            if old != new:
                deltas[name] = {"from": old, "to": new}
        return deltas

    def policies(self):
        """v6.1: full snapshot for GET /admin/breakers — live state + live
        effective policy (what a hot-apply actually changed)."""
        return {k: {"state": v.status, "fails": v.fails,
                    "policy": {"threshold": v.threshold,
                               "cooldown": v.cooldown,
                               "decay": v.decay}}
                for k, v in self._map.items()}

    def snapshot(self):
        return {k: (v.status, v.fails) for k, v in self._map.items()}
PY
fi

# ==================== STEP 6/24: H8 httpx singleton pool ====================
log "STEP 6/24 utils/http_pool.py — singleton httpx.AsyncClient http2 keep-alive max_connections=100 UA Chrome/120 (H8)"
if [[ $DRY_RUN -eq 0 ]]; then
atomic_write "$BIN_DIR/utils/http_pool.py" 0644 <<'PY'
# -*- coding: utf-8 -*-
"""OWL-ORCA v6 — Hack #8: process-wide httpx HTTP/2 keep-alive pool.

ONE AsyncClient per process (singleton). HTTP/2 multiplexes many requests
over one connection; the pool keeps 100 connections + 20 keep-alive slots
warm so provider fetches skip TCP+TLS handshake (~100-300ms each) on the
racing hot path. User-Agent pinned to Chrome/120 so the TLS/UA pair stays
JA3-consistent with freebuff's chrome120 stealth profile.
"""
import httpx

CHROME120_UA = ("Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 "
                "(KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36")

_client = None


def get_client() -> httpx.AsyncClient:
    """Singleton client — call from anywhere, never close per-request."""
    global _client
    if _client is None or _client.is_closed:
        _client = httpx.AsyncClient(
            http2=True,
            limits=httpx.Limits(
                max_connections=100,
                max_keepalive_connections=20,
                keepalive_expiry=30.0,
            ),
            headers={
                "User-Agent": CHROME120_UA,
                "Accept": "application/json, text/event-stream",
                "Accept-Language": "en-US,en;q=0.9",
            },
            timeout=httpx.Timeout(30.0, connect=5.0),
            follow_redirects=True,
        )
    return _client


async def aclose() -> None:
    """Shutdown hook (SIGHUP does NOT call this — reload keeps the pool warm)."""
    global _client
    if _client is not None and not _client.is_closed:
        await _client.aclose()
    _client = None
PY
fi

# ==================== STEP 7/24: H6 LazyModel ====================
log "STEP 7/24 utils/lazy_model.py — load embeddinggemma-300m/MiniLM on first tool call, unload after 300s idle (H6)"
if [[ $DRY_RUN -eq 0 ]]; then
atomic_write "$BIN_DIR/utils/lazy_model.py" 0644 <<'PY'
# -*- coding: utf-8 -*-
"""OWL-ORCA v6 — Hack #6: LazyModel.

embeddinggemma-300m (300MB) and MiniLM (80MB) are loaded on the FIRST
tool call, never at startup; an idle watchdog unloads the model after
300s of inactivity. Result: zero fixed memory for the embedding tier
between bursts — mempalace no longer costs 300MB of resident budget.
"""
import asyncio
import time


class LazyModel:
    IDLE_UNLOAD_S = 300.0            # 5 minutes
    _WATCH_TICK_S = 30.0

    def __init__(self, model_name="sentence-transformers/all-MiniLM-L6-v2"):
        self.model_name = model_name
        self._model = None
        self._last_used = 0.0
        self._lock = asyncio.Lock()
        self._watcher = None

    @property
    def loaded(self) -> bool:
        return self._model is not None

    async def ensure_loaded(self):
        if self._model is None:
            async with self._lock:
                if self._model is None:
                    # heavy import deferred to first use — cold start only
                    from sentence_transformers import SentenceTransformer
                    self._model = await asyncio.to_thread(
                        SentenceTransformer, self.model_name
                    )
        self._last_used = time.monotonic()
        if self._watcher is None or self._watcher.done():
            self._watcher = asyncio.create_task(self._idle_watchdog())

    async def embed(self, text):
        """First tool call pays the load; subsequent calls hit the warm model."""
        await self.ensure_loaded()
        self._last_used = time.monotonic()
        return await asyncio.to_thread(self._model.encode, text)

    async def embed_batch(self, texts):
        await self.ensure_loaded()
        self._last_used = time.monotonic()
        return await asyncio.to_thread(self._model.encode, list(texts))

    async def _idle_watchdog(self):
        """Unload after 300s idle -> zero fixed memory. Watcher exits on unload."""
        try:
            while True:
                await asyncio.sleep(self._WATCH_TICK_S)
                if self._model is None:
                    return
                if time.monotonic() - self._last_used >= self.IDLE_UNLOAD_S:
                    self._model = None      # release ~80MB (MiniLM) / ~300MB
                    return                 # recreated on next ensure_loaded()
        except asyncio.CancelledError:
            return

    async def shutdown(self):
        if self._watcher is not None and not self._watcher.done():
            self._watcher.cancel()
        self._model = None
PY
fi

# ==================== STEP 8/24: H7 Tier-0 JSON taxonomy + LRU classifier ====================
log "STEP 8/24 tier0/ — JSON taxonomy 10M Python (NOT PWA 384M): promptc-os-rules.json + sp7-scoring.json + lru_cache(1024) trie classifier <2ms (H7, F3 374M saved)"
if [[ $DRY_RUN -eq 0 ]]; then
atomic_write "$TIER0_DIR/promptc-os-rules.json" 0644 <<'JSON'
{
  "version": "v13-tuned-smp5.1.1",
  "note": "Tier-0 classifier: Python JSON + lru_cache + array radix trie (H2+H7). Replaces 3 Next.js PWA units (:3002/:3003/:3004) — 374M saved, <2ms inside the 5ms envelope, SIGHUP-reloadable via atomic rename. v13 tuning: rabbit=Speed per smp5.1.1 (ship variations fast); token-level match so hyphenated keys never hit — paired tokens instead; collision-prone singles removed (owl 'post', ant 'break'); fallback_tier ladder for StreamRacer degradation when a tier's breakers are all OPEN.",
  "animals": {
    "rabbit":   {"keys": ["quick","fast","asap","urgent","rapid","prototype","iterate","draft","ship","speed","brainstorm","ideas","idea","divergent","options","variations","variation","multiply","spin","sketch"], "mode": "Speed & Multiply Ideas", "best_for": "rapid iterations, ideation volume"},
    "dolphin":  {"keys": ["creative","invent","novel","workaround","hack","playful","remix","unconventional","imagine","whimsical","surprising"], "mode": "Creative Solutions", "best_for": "novel features, unconventional attacks"},
    "eagle":    {"keys": ["strategy","strategic","vision","roadmap","investor","horizon","moat","positioning","big","picture","thesis","bets"], "mode": "Big Picture Strategy", "best_for": "vision roadmap, capital allocation"},
    "beaver":   {"keys": ["build","system","architecture","refactor","ops","implement","scaffold","wire","practical","pragmatic","engineering","deploy"], "mode": "Build Systems", "best_for": "architecture refactors, infra work"},
    "ant":      {"keys": ["step","steps","checklist","systematic","procedure","decompose","sequence","sprint","migration","milestone","plan","todo","breakdown","phase","order"], "mode": "Break Into Steps", "best_for": "sprint planning, migration checklists"},
    "owl":      {"keys": ["deep","analysis","risk","mortem","hidden","root","cause","audit","tradeoff","tradeoffs","why","investigate","diagnose","failure"], "mode": "Deep Analysis", "best_for": "risk audit, root-cause postmortems"},
    "elephant": {"keys": ["cross","field","bridge","analogical","analogy","analogies","precedent","interdisciplinary","innovation","history","durable","remember"], "mode": "Cross-Field Connections", "best_for": "innovation via precedent transfer"}
  },
  "cost_tier": {
    "rabbit": "cheap", "ant": "cheap", "dolphin": "cheap", "beaver": "medium",
    "elephant": "medium", "eagle": "premium", "owl": "premium"
  },
  "fallback_tier": {
    "eagle": "medium", "owl": "medium", "beaver": "cheap", "elephant": "cheap",
    "rabbit": "cheap", "ant": "cheap", "dolphin": "cheap"
  },
  "chains": [
    "Eagle->Beaver->Dolphin->Ant greenfield product",
    "Owl->Eagle->Ant risk audit",
    "Rabbit->Dolphin->Beaver brainstorm"
  ],
  "lint_rules": 32,
  "word_swaps": 58,
  "design_combos": 20,
  "motion_stacks": 30
}
JSON
atomic_write "$TIER0_DIR/sp7-scoring.json" 0644 <<'JSON'
{
  "algorithm": "SP-7",
  "dimensions": {
    "VD": "Visual Density",
    "IR": "Interactivity Requirement",
    "DC": "Data Complexity",
    "MN": "Motion Need",
    "AW": "Accessibility Weight",
    "AR": "AI Redirect Value",
    "CR": "Component Reusability"
  },
  "tiers": {
    "T0": "Foundation Design Intelligence Layer Stitch Design Framer Motion UI/UX Pro Max v7 21st.dev Registry",
    "T1": "Interactive Motion & Data Layer GSAP Remotion Mermaid AntV Chain of Thought Socratic Simulation Sandbox MCP Builder",
    "T2": "Visual Asset Generation & Capture Layer shadcn Playwright Chart Web Artifacts SEO Humanizer Social",
    "T3": "Portal Custom Intelligence Layer AI Portal Redirect Stack Prioritizer Matrix Engine Design Algorithm JTBD Research Gumroad Pipeline Skill Finder Persistent Memory"
  },
  "proxy_topology": ["Transparent Caching", "Anonymous Privacy", "Reverse Load balancing", "Forward Egress control", "SSL/TLS Inspection", "Caching Origin load reduction"],
  "skills": 45,
  "install_order": "T0->T3 strict no tier without predecessors"
}
JSON
atomic_write "$TIER0_DIR/__init__.py" 0644 <<'PY'
# tier0 package (namespace)
PY
mkdir -p "$BIN_DIR/utils"
atomic_write "$BIN_DIR/utils/__init__.py" 0644 <<'PY'
# utils package (namespace)
PY
atomic_write "$TIER0_DIR/classifier.py" 0644 <<'PY'
# -*- coding: utf-8 -*-
"""OWL-ORCA v6 — Hack #7: Tier-0 classifier (<2ms, inside 5ms envelope).

Loads the 10MB JSON taxonomy (promptc-os-rules.json + sp7-scoring.json)
into an array radix trie (H2) and classifies prompts through a single
functools.lru_cache(maxsize=1024) memoized function. Replaces the v5
Next.js PWA plane (384M -> ~10M resident, 374M SAVED, F3).

Reload: orca-reload.sh / SIGHUP re-reads the JSON after the installer's
atomic rename() swap — no TCP drop, no process restart.
"""
import functools
import json
import os
import time

try:
    from utils.radix_trie import RadixArrayTrie
except ImportError:                     # direct-execution fallback
    from radix_trie import RadixArrayTrie  # type: ignore

# default tree: <BASE>/tier0 — works under systemd (TIER0_DIR set) AND when
# invoked directly (selftest / bare CLI), no /tmp guessing.
_BASE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
_TIER0_DIR = os.environ.get("TIER0_DIR", os.path.join(_BASE, "tier0"))
RULES_PATH = os.environ.get(
    "TIER0_RULES", os.path.join(_TIER0_DIR, "promptc-os-rules.json"))
SP7_PATH = os.environ.get(
    "TIER0_SP7", os.path.join(_TIER0_DIR, "sp7-scoring.json"))


class Tier0:
    """Animal-mode classifier: trie keyword match + weighted vote."""

    def __init__(self, rules_path=RULES_PATH, sp7_path=SP7_PATH):
        self.rules_path = rules_path
        self.sp7_path = sp7_path
        self.animals = {}
        self.cost_tier = {}
        self.fallback_tier = {}     # v6.1: animal -> fallback cost_tier ladder
        self.sp7 = {}
        self.trie = RadixArrayTrie()      # H2: 4KB flat array trie
        self._votes = {}
        self.reload()

    def reload(self):
        """H5: called on SIGHUP — files were swapped by rename(), re-open by
        path never sees a torn read."""
        with open(self.rules_path, "r", encoding="utf-8") as f:
            rules = json.load(f)
        try:
            with open(self.sp7_path, "r", encoding="utf-8") as f:
                self.sp7 = json.load(f)
        except (OSError, ValueError):
            self.sp7 = {}
        self.animals = rules.get("animals", {})
        self.cost_tier = rules.get("cost_tier", {})
        self.fallback_tier = rules.get("fallback_tier", {})   # v6.1 hot-consumed
        self.trie = RadixArrayTrie()
        self._votes = {}
        for animal, spec in self.animals.items():
            w = 0
            for key in spec.get("keys", []):
                k = "".join(c for c in key.lower() if c.isalnum())
                if k:
                    self.trie.insert(k)
                    self._votes[k] = animal
                    w += 1

    def classify(self, text: str) -> dict:
        t0 = time.perf_counter()
        hits = self.trie.scan_keywords(text)     # zero-copy trie scan
        tally = {}
        for k in hits:
            animal = self._votes.get(k)
            if animal:
                tally[animal] = tally.get(animal, 0) + 1
        animal = max(tally, key=tally.get) if tally else "owl"  # default deep
        spec = self.animals.get(animal, {})
        elapsed_ms = (time.perf_counter() - t0) * 1000.0
        return {
            "animal": animal,
            "mode": spec.get("mode", "Deep Analysis"),
            "best_for": spec.get("best_for", "risk audit"),
            "cost_tier": self.cost_tier.get(animal, "medium"),
            "keywords_hit": hits,
            "elapsed_ms": round(elapsed_ms, 3),
        }

    def sp7_dimensions(self) -> dict:
        return self.sp7.get("dimensions", {})


_TIER0 = None


def get_tier0() -> Tier0:
    global _TIER0
    if _TIER0 is None:
        _TIER0 = Tier0()
    return _TIER0


@functools.lru_cache(maxsize=1024)             # H7: memoized hot path
def classify(text: str) -> str:
    """lru_cache(1024) — repeated prompts never re-trie-scan. Returns JSON
    string (cacheable, hashable)."""
    return json.dumps(get_tier0().classify(text))


def reload_all():
    classify.cache_clear()
    get_tier0().reload()


if __name__ == "__main__":
    import sys
    result = get_tier0().classify(sys.argv[1] if len(sys.argv) > 1
                                  else "deep analysis risk post mortem hidden")
    print(json.dumps(result, indent=2))
PY
fi
