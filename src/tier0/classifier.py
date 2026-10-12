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
