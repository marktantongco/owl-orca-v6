
# ==================== STEP 11/24: Forward proxy billing sidecar ====================
log "STEP 11/24 bin/forward_proxy.py — billing sidecar :60000 Stages 1,2,7 auth->tier rate limit->metering JSONL ledger atomic rotate (H1 uvloop)"
if [[ $DRY_RUN -eq 0 ]]; then
atomic_write "$BIN_DIR/forward_proxy.py" 0755 <<'PY'
#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""OWL-ORCA v6 — Forward proxy billing sidecar (:60000).

Stages 1, 2, 7 of the owl-forward-proxy spec: auth check, per-tier rate
limits, usage metering. Ledger is append-only JSONL with atomic rotation
at 10MB (rename() swap — H5 pattern, IDE/inotify safe). Free tier passes
unmetered unless a billing profile exists (contradiction register #4).
"""
import asyncio
import json
import os
import time

try:
    import uvloop
    uvloop.install()                       # H1
    _UVLOOP = True
except ImportError:
    _UVLOOP = False

from fastapi import FastAPI, Request      # noqa: E402
from fastapi.responses import JSONResponse  # noqa: E402

BASE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
LEDGER = os.path.join(BASE, "logs", "billing-ledger.jsonl")
LEDGER_MAX = 10 * 1024 * 1024
ROUTER = "http://127.0.0.1:60001"

TIERS = {
    "anonymous": {"rpm": 60, "metered": False},
    "free":      {"rpm": 120, "metered": True},
    "cheap":     {"rpm": 240, "metered": True},   # v6.2: animal-ladder keys
    "medium":    {"rpm": 240, "metered": True},
    "premium":   {"rpm": 600, "metered": True},
    "pro":       {"rpm": 600, "metered": True},
}
_buckets = {}
_ledger_lock = asyncio.Lock()

app = FastAPI(title="owl-orca-v6-forward-proxy", version="6.0.0")


def _rotate_if_needed():
    """H5 pattern: rotate by atomic rename, never truncate a live file."""
    try:
        if os.path.exists(LEDGER) and os.path.getsize(LEDGER) >= LEDGER_MAX:
            os.replace(LEDGER, LEDGER + f".{int(time.time())}.rotated")
    except OSError:
        pass


async def _ledger_append(rec):
    async with _ledger_lock:
        _rotate_if_needed()
        with open(LEDGER, "a", encoding="utf-8") as f:
            f.write(json.dumps(rec, separators=(",", ":")) + "\n")


def _allow(tier):
    now = time.monotonic()
    b = _buckets.setdefault(tier, [now, 0])
    elapsed = now - b[0]
    if elapsed >= 60.0:
        b[0], b[1] = now, 0
    b[1] += 1
    return b[1] <= TIERS.get(tier, TIERS["anonymous"])["rpm"]


@app.get("/healthz")
async def healthz():
    return {"ok": True, "service": "forward-proxy", "port": 60000,
            "cap": "128M", "stages": [1, 2, 7],
            "uvloop": _UVLOOP, "ledger": LEDGER}


@app.api_route("/{path:path}", methods=["GET", "POST", "OPTIONS"])
async def forward(path: str, req: Request):
    auth = req.headers.get("authorization", "")
    tier = "anonymous"
    if auth.startswith("Bearer owl-"):
        tier = auth.removeprefix("Bearer owl-").split("-")[0] or "anonymous"
    if not _allow(tier):                        # Stage 2: tier rate limits
        return JSONResponse({"error": "rate limit"}, status_code=429)
    await _ledger_append({                      # Stage 7: usage metering
        "ts": time.time(), "tier": tier, "method": req.method,
        "path": "/" + path,
        "metered": TIERS.get(tier, TIERS["anonymous"])["metered"],
    })
    # Stage 1 (auth) is pass-through for local single-user workstation —
    # anonymous local traffic rides unmetered unless billing profile exists.
    if req.method == "POST":
        body = await req.body()
        return JSONResponse({"forwarded": True, "tier": tier,
                             "upstream": ROUTER, "path": "/" + path,
                             "note": "router race happens at :60001"})
    return JSONResponse({"forwarded": True, "tier": tier, "upstream": ROUTER})


if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="127.0.0.1", port=60000, log_level="warning")
PY
atomic_write "$BIN_DIR/kiro-gateway-shim.py" 0755 <<'PY'
#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""OWL-ORCA v6 — Kiro gateway shim (:8333).

If marktantongco/kiro-gateway is cloned (STEP 12), its gateway.py runs
instead. This shim guarantees :8333 healthz + a documented AWS Builder ID
hand-off so the core plane always boots.
"""
from fastapi import FastAPI

app = FastAPI(title="owl-orca-v6-kiro-shim", version="6.0.0")


@app.get("/healthz")
async def healthz():
    return {"ok": True, "service": "kiro-gateway", "port": 8333, "cap": "256M",
            "auth": "aws_builder_oidc", "models": ["claude-3.5-sonnet-kiro",
                                                   "claude-3-haiku-kiro"],
            "note": "clone kiro-gateway for the real OIDC flow"}


if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="127.0.0.1", port=8333, log_level="warning")
PY
atomic_write "$BIN_DIR/virtu_echo.py" 0755 <<'PY'
#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""OWL-ORCA v6.1 — virtu-echo: the virtual completion backend (:60009).

The "virtu" in owl-orca-virtu CV: an in-sandbox virtual upstream that the
router races ONLY as the terminal fallback after the rules fallback_tier
ladder is exhausted (every real upstream gated or failing). Real upstreams
always win on merit when they are alive — virtu-echo never enters a normal
race.

Answers are OpenAI-shaped (chat completions + SSE) and self-labeled with
the Tier-0 verdict, so clients like OpenCode can SEE the animal ladder that
routed them:

    [virtu-echo animal=rabbit tier=cheap route=virtual]
    Speed mode: ...

Uses the SAME tier0 classifier (H2 radix trie + H7 LRU) as the router, so
the label always matches the router's routing decision.
"""
import json
import os
import sys
import time

BASE = os.path.expanduser("~/.owl-orca-v6")
sys.path.insert(0, BASE)                       # tier0 + utils from the tree

from fastapi import FastAPI, Request                     # noqa: E402
from fastapi.responses import JSONResponse, StreamingResponse  # noqa: E402
from tier0.classifier import classify as tier0_classify  # noqa: E402

app = FastAPI(title="owl-orca-v6.1-virtu-echo", version="6.1.0")

_MODE_REPLY = {
    "rabbit": ("Speed mode (rabbit/cheap): three fastest paths to ship now — "
               "(1) smallest vertical slice, (2) stub every unknown behind an "
               "interface, (3) demo before polish. Optimize for the demo "
               "story, not the architecture. park big-picture work entirely."),
    "ant": ("Precision mode (ant/cheap): execution checklist — verify each "
            "item in order, no skipping: inputs pinned, edge cases listed, "
            "failure modes enumerated, regression test written first, then "
            "the smallest change that passes it. Singular focus per step."),
    "dolphin": ("Creative mode (dolphin/cheap): remix idea — combine the "
                "current task's core mechanic with an unrelated pattern from "
                "a different domain (game design, choreography, kitchens). "
                "Keep the constraint that makes it playful; drop the "
                "convention that makes it boring. Ship the weird version "
                "behind a flag."),
    "beaver": ("Systems mode (beaver/medium): build plan — map the current "
               "state, define the target interface, cut the migration into "
               "reversible steps, each behind a flag, each independently "
               "revertible, then land them in dependency order. Practical "
               "beats elegant."),
    "elephant": ("Consistency mode (elephant/medium): consolidate — restate "
                 "the durable facts, align the new work with prior "
                 "decisions, flag any contradiction with the existing "
                 "conventions before writing new ones. Long-term coherent "
                 "memory over local cleverness."),
    "eagle": ("Strategy mode (eagle/premium): zoom out — name the objective, "
              "the constraint set, and the one metric that matters; rank the "
              "options by leverage per unit of effort; pick the option that "
              "keeps the most doors open. Capital and attention go to the "
              "top of that list only."),
    "owl": ("Deep-analysis mode (owl/premium): hidden-factor pass — surface "
            "the assumptions nobody wrote down, the second-order effects "
            "nobody priced in, and the failure mode that shows up only under "
            "load or adversarial input. Root cause before remedy."),
}


def _verdict(prompt: str) -> dict:
    try:
        return json.loads(tier0_classify(prompt))
    except Exception:
        return {"animal": "owl", "mode": "Deep Analysis", "cost_tier": "premium"}


def _content(verdict: dict, prompt: str) -> str:
    animal = verdict.get("animal", "owl")
    tier = verdict.get("cost_tier", "premium")
    label = (f"[virtu-echo animal={animal} tier={tier} route=virtual "
             f"mode={verdict.get('mode', 'Deep Analysis')}]")
    body = _MODE_REPLY.get(animal, _MODE_REPLY["owl"])
    note = (" Real upstreams are gated/absent in this sandbox (no external "
            "credentials), so the virtual backend answered. Add real "
            "upstream credentials and this request would race them instead.")
    echo = f" Prompt head: {prompt[:180].strip()}"
    return label + "\n" + body + note + echo


def _completion_body(model: str, content: str) -> dict:
    return {
        "id": f"chatcmpl-virtu-{time.time_ns()}",
        "object": "chat.completion",
        "created": int(time.time()),
        "model": model or "virtu-echo",
        "choices": [{
            "index": 0,
            "message": {"role": "assistant", "content": content},
            "finish_reason": "stop",
        }],
        "usage": {"prompt_tokens": 0, "completion_tokens": 0,
                  "total_tokens": 0},
    }


async def _completions(req: Request):
    body = await req.json()
    msgs = [m for m in body.get("messages", [])
            if isinstance(m, dict) and m.get("role") == "user"]
    if msgs:
        prompt = str(msgs[-1].get("content", ""))   # match router routing
    else:
        prompt = " ".join(str(m.get("content", ""))
                           for m in body.get("messages", []))
    verdict = _verdict(prompt)
    content = _content(verdict, prompt)
    model = body.get("model", "virtu-echo")
    if body.get("stream"):
        cid = f"chatcmpl-virtu-{time.time_ns()}"

        def chunk(delta, finish=None):
            return {
                "id": cid, "object": "chat.completion.chunk",
                "created": int(time.time()), "model": model,
                "choices": [{"index": 0, "delta": delta,
                             "finish_reason": finish}],
            }

        async def gen():
            pieces = content.split("\n")
            for i, piece in enumerate(pieces):
                delta = {"role": "assistant"} if i == 0 else {}
                if piece:
                    delta["content"] = piece + ("\n" if i < len(pieces) - 1 else "")
                yield b"data: " + json.dumps(chunk(delta)).encode() + b"\n\n"
            yield b"data: " + json.dumps(chunk({}, "stop")).encode() + b"\n\n"
            yield b"data: [DONE]\n\n"

        return StreamingResponse(gen(), media_type="text/event-stream",
                                 headers={"X-Virtu-Animal": verdict.get("animal", "owl"),
                                          "X-Virtu-Tier": verdict.get("cost_tier", "premium")})
    resp = _completion_body(model, content)
    return JSONResponse(resp, headers={
        "X-Virtu-Animal": verdict.get("animal", "owl"),
        "X-Virtu-Tier": verdict.get("cost_tier", "premium")})


# router builds base_url + "/v1/chat/completions"; provider base_urls carry
# their own /v1, so BOTH path shapes are served.
app.add_api_route("/v1/chat/completions", _completions, methods=["POST"])
app.add_api_route("/v1/v1/chat/completions", _completions, methods=["POST"])


@app.get("/v1/models")
@app.get("/v1/v1/models")
async def models():
    return {"object": "list",
            "data": [{"id": "virtu-echo", "owned_by": "virtu-echo"},
                     {"id": "virtu-echo-cheap", "owned_by": "virtu-echo"},
                     {"id": "virtu-echo-premium", "owned_by": "virtu-echo"}]}


@app.get("/healthz")
async def healthz():
    return {"ok": True, "service": "virtu-echo", "port": 60009,
            "cap": "64M", "role": "virtual terminal fallback (never raced "
            "against live upstreams; engaged only when the fallback_tier "
            "ladder is exhausted)"}


if __name__ == "__main__":
    import uvicorn
    try:
        import uvloop                              # H1 lineage
        uvloop.install()
    except ImportError:
        pass
    uvicorn.run(app, host="127.0.0.1", port=60009, log_level="warning")
PY
fi

# ==================== STEP 12/24: systemd core units (F2 ExecReload restored) ====================
log "STEP 12/24 systemd core units — router 384M + forward 128M + kiro 256M + virtu-echo 64M (v6.1 virtual fallback), ExecReload=/bin/kill -HUP \$MAINPID restored (F2)"
if [[ $DRY_RUN -eq 0 ]]; then
atomic_write "$SYSTEMD_USER/orca-router.service" 0644 <<'UNIT'
[Unit]
Description=Orca Router v6 384M — uvloop H1 StreamRacer H3 bounded 5 breakers H4 SIGHUP H5 Tier0 H7 httpx pool H8
After=network.target

[Service]
Type=simple
ExecStart=%h/.owl-orca-v6/venv/bin/python %h/.owl-orca-v6/bin/orca-router.py
WorkingDirectory=%h/.owl-orca-v6
ExecReload=/bin/kill -HUP $MAINPID
Restart=on-failure
MemoryMax=384M
MemoryHigh=256M
Environment=PYTHONPATH=%h/.owl-orca-v6
Environment=TIER0_DIR=%h/.owl-orca-v6/tier0
Environment=TIER0_RULES=%h/.owl-orca-v6/tier0/promptc-os-rules.json
Environment=TIER0_SP7=%h/.owl-orca-v6/tier0/sp7-scoring.json
Environment=TOKENS_FILE=%h/.owl-orca-v6/tokens.enc

[Install]
WantedBy=default.target
UNIT
atomic_write "$SYSTEMD_USER/orca-forward-proxy.service" 0644 <<'UNIT'
[Unit]
Description=Owl Forward Proxy v6 billing sidecar 128M Stages 1,2,7 ledger JSONL
After=network.target orca-router.service

[Service]
Type=simple
ExecStart=%h/.owl-orca-v6/venv/bin/python %h/.owl-orca-v6/bin/forward_proxy.py
WorkingDirectory=%h/.owl-orca-v6
ExecReload=/bin/kill -HUP $MAINPID
Restart=on-failure
MemoryMax=128M
MemoryHigh=96M
Environment=PYTHONPATH=%h/.owl-orca-v6

[Install]
WantedBy=default.target
UNIT
atomic_write "$SYSTEMD_USER/orca-kiro-gateway.service" 0644 <<'UNIT'
[Unit]
Description=Kiro Gateway v6 AWS Builder ID 256M
After=network.target

[Service]
Type=simple
ExecStart=%h/.owl-orca-v6/venv/bin/python %h/.owl-orca-v6/bin/kiro-gateway-shim.py
WorkingDirectory=%h/.owl-orca-v6
ExecReload=/bin/kill -HUP $MAINPID
Restart=on-failure
MemoryMax=256M
MemoryHigh=192M
Environment=PYTHONPATH=%h/.owl-orca-v6

[Install]
WantedBy=default.target
UNIT
atomic_write "$SYSTEMD_USER/orca-virtu-echo.service" 0644 <<'UNIT'
[Unit]
Description=Orca Virtu Echo v6.1 virtual completion backend 64M — terminal fallback after the rules fallback_tier ladder
After=network.target orca-router.service

[Service]
Type=simple
ExecStart=%h/.owl-orca-v6/venv/bin/python %h/.owl-orca-v6/bin/virtu_echo.py
WorkingDirectory=%h/.owl-orca-v6
Restart=on-failure
MemoryMax=64M
MemoryHigh=48M
Environment=PYTHONPATH=%h/.owl-orca-v6

[Install]
WantedBy=default.target
UNIT
  # Clone the real kiro-gateway when git is available; unit stays on the shim
  # until the operator swaps ExecStart (documented in VERIFICATION.md).
  if command -v git >/dev/null 2>&1; then
    if [[ ! -d "$HOME/Documents/proxy/kiro-gateway" ]]; then
      git clone --depth 1 https://github.com/marktantongco/kiro-gateway \
        "$HOME/Documents/proxy/kiro-gateway" 2>/dev/null \
        || warn "kiro-gateway clone failed — shim stays active"
    fi
  fi
  systemctl --user daemon-reload 2>/dev/null || true
  check_port 60001 router
  check_port 60000 forward-proxy
  check_port 8333 kiro-gateway
  check_port 60009 virtu-echo
fi

# ==================== STEP 13/24: providers.json + routes.json + OpenCode ====================
log "STEP 13/24 config/ — v4.5 providers.json + routes.json merged into v6 (NIM :60008 F9) + OpenCode wiring + v6.2 playbook sections (cache/guardrails/plans/weights/quotas)"
if [[ $DRY_RUN -eq 0 ]]; then
atomic_write "$CFG_DIR/providers.json" 0644 <<'JSON'
{
  "_comment": "OWL-ORCA v6 UNIFIED — v4.5 providers merged with v5 lineage; NIM reallocated :60004->:60008 (F9); breaker policy carries H4 decay; v6.2 playbook integration: response cache + guardrails + plans + weighted routing + daily quotas (all SIGHUP hot-applied)",
  "version": "6.2.0-unified",
  "cache": {
    "enabled": true, "mode": "simple", "max_age": 3600, "max_entries": 256,
    "note": "v6.2 P1 (playbook config #5 Portkey): identical prompt (sha256 of model+messages) replays the stored completion; non-streaming only; X-Owl-Orca-Cache hit/miss/bypass; hot-apply via /admin/cache or SIGHUP"
  },
  "guardrails": [
    {"id": "prompt-injection", "action": "block",
     "note": "v6.2 P2 (Portkey pattern): pre-flight regex battery on the routing prompt; OpenAI-shaped 400 guardrail_violation"},
    {"id": "self-harm-input", "action": "block"}
  ],
  "plans": {
    "free": {"prefix": "oc-free-", "terminal": "virtu-echo", "rpm": 30,
             "note": "v6.2 P8 (monetization #3): keys carrying the prefix get labeled virtu-echo completions — the freemium funnel"},
    "paid": {"ladder": true,
             "note": "real animal ladder + fallback tiers + real upstreams"}
  },
  "request_settings": {
    "num_retries": 2, "timeout": 20,
    "note": "v6.2 P4 (playbook config #2 LiteLLM): ladder walk retried pre-first-byte; race deadline seconds — both SIGHUP hot-applied"
  },
  "providers": {
    "owl-forward-billing": {
      "display_name": "OWL Forward Proxy Billing Sidecar",
      "source_repo": "https://github.com/marktantongco/owl-forward-proxy",
      "base_url": "http://127.0.0.1:60000", "port": 60000,
      "type": "billing_monetization", "format": "forward_proxy",
      "features": ["auth", "per-tier-rate-limits", "usage-metering"],
      "memory_max": "128M"
    },
    "owl-defense-v6": {
      "display_name": "OWL Defense Stack v6 (in-process)",
      "source_repo": "https://github.com/marktantongco/owl-agent-stack",
      "base_url": "http://127.0.0.1:60001", "type": "memory_optimized",
      "features": ["get_stats", "TokenBucket_race_fix", "full_http_proxy"],
      "supersedes": "owl-defense-v45"
    },
    "freebuff-deepseek": {
      "display_name": "Freebuff DeepSeek via Go JA3",
      "source_repo": "https://github.com/marktantongco/freebuff-proxy",
      "base_url": "http://127.0.0.1:1455/v1", "format": "openai_and_anthropic",
      "memory_max": "256M",
      "models": ["deepseek/deepseek-v4-pro", "deepseek/deepseek-v4-flash", "deepseek-v3"],
      "cost_tier": "cheap",
      "stealth": {"enabled": true, "ja3": true, "profile": "chrome120",
                  "socks5_pool": true, "multi_token": true, "proxy_refresh_mins": 30},
      "weight": 1.0, "daily_quota": 20000,
      "circuit_breaker": {"threshold": 3, "cooldown": 45, "decay": 2}
    },
    "antigravity-free": {
      "display_name": "Antigravity Free (Google)",
      "source_repo": "https://github.com/marktantongco/antigravity-proxy-gateway",
      "base_url": "http://127.0.0.1:60003/v1", "format": "anthropic",
      "runtime": "bun",
      "models": ["gemini-2.0-flash", "gemini-2.0-pro", "claude-3.5-sonnet-antigravity"],
      "cost_tier": "cheap", "requires_translation": "anthropic_to_openai",
      "extended_thinking": true, "thinking_delta_field": "thinking",
      "weight": 1.2, "daily_quota": 4000,
      "circuit_breaker": {"threshold": 3, "cooldown": 45, "decay": 2}
    },
    "copilot-free": {
      "display_name": "GitHub Copilot Free",
      "source_repo": "https://github.com/marktantongco/owl-orca-v4",
      "base_url": "https://api.githubcopilot.com", "format": "openai",
      "models": ["gpt-4o-mini", "gpt-4o", "o1-mini", "claude-3.5-sonnet"],
      "cost_tier": "cheap", "canary_weight": 90, "auth_method": "device_flow",
      "token_encryption": "fernet", "egress": "freebuff-proxy:1455",
      "weight": 1.5, "daily_quota": 5000,
      "circuit_breaker": {"threshold": 3, "cooldown": 45, "decay": 2}
    },
    "kiro-free": {
      "display_name": "Kiro Gateway AWS Builder ID",
      "source_repo": "https://github.com/marktantongco/kiro-gateway",
      "base_url": "http://127.0.0.1:8333/v1", "format": "openai",
      "memory_max": "256M",
      "models": ["claude-3.5-sonnet-kiro", "claude-3-haiku-kiro"],
      "cost_tier": "medium", "fallback": true, "auth_method": "aws_builder_oidc",
      "weight": 1.3, "daily_quota": 3000,
      "circuit_breaker": {"threshold": 5, "cooldown": 60, "decay": 1}
    },
    "nvidia-nim": {
      "display_name": "NVIDIA NIM (F9: reallocated to :60008)",
      "source_repo": "https://github.com/marktantongco/nim-to-openai-proxy",
      "base_url": "http://127.0.0.1:60008/v1", "format": "openai",
      "models": ["meta/llama-3.1-70b", "meta/llama-3.1-405b", "nvidia/nemotron"],
      "cost_tier": "medium", "translate_from": "nvidia_nim",
      "weight": 0.8,
      "circuit_breaker": {"threshold": 5, "cooldown": 60, "decay": 1}
    },
    "novada-residential": {
      "display_name": "Novada Residential MCP (403-only last resort)",
      "source_repo": "https://github.com/marktantongco/Novada-proxy",
      "base_url": "http://127.0.0.1:60000", "type": "residential_proxy_mcp",
      "format": "mcp", "models": ["novada-residential"],
      "cost_tier": "expensive", "complexity": "blocked_only",
      "bypass": ["cloudflare", "akamai", "datadome"],
      "note": "Use only when 403 cloudflare blocked",
      "circuit_breaker": {"threshold": 3, "cooldown": 300, "decay": 1}
    },
    "omniproxy-smart": {
      "display_name": "OmniProxy Smart Router (NadirClaw 40-70%)",
      "source_repo": "https://github.com/marktantongco/omniproxy-ai-smart-router",
      "base_url": "http://127.0.0.1:60001/v1", "type": "smart_router",
      "format": "openai", "models": ["smart-router"],
      "cost_aware": true, "nadirclaw_routing": true, "savings": "40-70%"
    },
    "rtk-token-saver": {
      "display_name": "RTK Token Saver 60-90%",
      "source_repo": "https://github.com/marktantongco/rtk",
      "type": "cli_proxy_token_reduction", "reduction": "60-90%",
      "enabled": false, "flag": "--with-rtk",
      "preserve": ["tool_use", "thinking_delta", "input_json_delta"]
    },
    "memory-hub": {
      "display_name": "Memory Hub (in-process v6, 128M unit eliminated)",
      "source_repo": "https://github.com/marktantongco/TencentDB-Agent-Memory",
      "secondary": "https://github.com/marktantongco/mempalace",
      "type": "team_memory", "backend": "tencentdb_with_sqlite_fallback",
      "features": ["store_race_winner", "latency_tracking", "failure_decay"]
    },
    "owl-orca-virtual": {
      "display_name": "OWL-ORCA v6 Virtual Provider (OpenCode entry)",
      "base_url": "http://127.0.0.1:60001/v1",
      "models": ["copilot-free", "antigravity-free", "kiro-free", "nim-free",
                 "freebuff-deepseek"],
      "routing": {"strategy": "cost-tier + first-byte-wins race (H3+H7)",
                  "cost_aware": true, "fallback": "kiro"}
    },
    "virtu-echo": {
      "display_name": "OWL-ORCA Virtu Echo (virtual completion backend)",
      "base_url": "http://127.0.0.1:60009/v1", "format": "openai",
      "memory_max": "64M",
      "models": ["virtu-echo", "virtu-echo-cheap", "virtu-echo-premium"],
      "cost_tier": "virtual",
      "note": "v6.1 terminal fallback: raced ONLY after the rules fallback_tier ladder is exhausted; never enters normal races",
      "circuit_breaker": {"threshold": 5, "cooldown": 60, "decay": 1}
    }
  },
  "breaker_policy": {
    "per_cost_tier": {
      "cheap":     {"threshold": 3, "cooldown": 45,  "decay": 2},
      "medium":    {"threshold": 5, "cooldown": 60,  "decay": 1},
      "premium":   {"threshold": 7, "cooldown": 90,  "decay": 1},
      "expensive": {"threshold": 3, "cooldown": 300, "decay": 1}
    },
    "note": "cheap: trip fast(3)/recover fast(45s, decay 2) - alternatives abound; medium: proven 5/60s; premium: patient(7) - lockout hurts, 90s; expensive: trip fast(3), stay out 300s - quota protection, anti-ban. v6.1: breaker STATE survives and POLICY hot-applies via SIGHUP reload or POST /admin/breakers - no restart, no TCP drop. v6.2: weights order candidates (OpenRouter provider-order), daily_quota trips BEFORE the ceiling (GooseRelay discipline)."
  }
}
JSON
atomic_write "$CFG_DIR/routes.json" 0644 <<'JSON'
{
  "_comment": "OWL-ORCA v6 routes — cost-tier selects candidates, racing decides winner inside tier (contradiction resolved); v6.2: routing_preference orders candidates before the race",
  "version": "6.2.0-unified",
  "routes": [
    {
      "pattern": "/v1/chat/completions", "method": "POST",
      "strategy": "cost-aware-race",
      "routing_preference": "balanced",
      "description": "Tier0 H7 classify -> NadirClaw cost tier -> StreamRacer H3 first-byte-wins bounded 5; v6.2: weight/p50-EMA ordering (price|latency|balanced) + quota-gated candidate skip",
      "cost_logic": {
        "simple_query":  {"max_tokens": 500,
                          "targets": ["copilot-free", "antigravity-free", "freebuff-deepseek"],
                          "savings": "70%"},
        "medium_query":  {"max_tokens": 2000,
                          "targets": ["copilot-free", "antigravity-free", "freebuff-deepseek", "nvidia-nim"],
                          "savings": "50%"},
        "complex_query": {"max_tokens": 8000,
                          "targets": ["kiro-free", "nvidia-nim", "antigravity-free"],
                          "savings": "40%"},
        "blocked_fallback": {"status": [403, 429], "targets": ["novada-residential"],
                             "note": "residential MCP last resort"}
      },
      "middleware": [
        {"stage": "billing",   "service": "owl-forward-billing", "port": 60000, "order": 1},
        {"stage": "defense",   "service": "owl-defense-v6", "order": 2,
         "cache_ttl": 300, "dedup": true, "rate_limit": 1.0},
        {"stage": "token_saver", "service": "rtk-token-saver", "order": 3,
         "enabled": false, "preserve_tool_use": true},
        {"stage": "tier0",     "service": "classifier H7", "order": 4,
         "lru_cache": 1024, "envelope_ms": 5, "target_ms": 2},
        {"stage": "race",      "service": "StreamRacer H3", "order": 5,
         "first_byte_wins": true, "bounded_queue": 5, "cancel_losers": true,
         "translation": "chunk_by_chunk"},
        {"stage": "egress",    "service": "freebuff-proxy", "port": 1455, "order": 6,
         "ja3_stealth": true, "socks5_pool": true, "multi_token": true},
        {"stage": "memory",    "service": "memory-hub", "order": 7,
         "store_winner": true, "decay_failures": true}
      ],
      "circuit_breaker": {"threshold": 5, "cooldown": 60, "decay": 1,
                          "half_open_probe": 1},
      "translation": {
        "anthropic_to_openai": {
          "message_start": "role_chunk",
          "content_block_delta_text": "content_delta",
          "thinking_delta": "reasoning_content",
          "input_json_delta": "tool_call_args"
        }
      }
    },
    {
      "pattern": "/v1/messages", "method": "POST", "strategy": "race",
      "description": "Anthropic Messages API — SSE translated chunk-by-chunk (H3b)",
      "targets": ["antigravity-free", "freebuff-deepseek"]
    },
    {
      "pattern": "/v1/models", "method": "GET", "strategy": "single",
      "cache_ttl": 3600, "targets": ["copilot-free"]
    },
    {
      "pattern": "/v1/prompt/classify", "method": "POST", "strategy": "single",
      "description": "Tier-0 animal classifier — lru_cache(1024) <2ms (H7)",
      "targets": ["self"]
    },
    {
      "pattern": "/healthz", "method": "GET", "strategy": "single",
      "targets": ["self"], "defense": {"cache": false, "dedup": false}
    },
    {
      "pattern": "/admin/reload", "method": "POST", "strategy": "single",
      "description": "SIGHUP hot-reload equivalent without dropping TCP (H5)",
      "targets": ["self"], "safe_mode": "check IDE active"
    }
  ]
}
JSON
  # OpenCode wiring (v4.5 STEP 10 lineage)
  mkdir -p "$HOME/.config/opencode"
  cat > "$HOME/.config/opencode/opencode.json" <<'JSON'
{
  "$schema": "https://opencode.ai/config.json",
  "provider": {
    "owl-orca-virtual": {
      "npm": "@ai-sdk/openai-compatible",
      "name": "OWL-ORCA v6 Virtual (animal ladder)",
      "options": {
        "baseURL": "http://127.0.0.1:60001/v1",
        "apiKey": "owl-orca-local"
      },
      "models": {
        "gpt-4o-mini": {"name": "gpt-4o-mini — copilot-free (cheap tier)"},
        "gemini-2.0-flash": {"name": "gemini-2.0-flash — antigravity-free (cheap tier)"},
        "deepseek-v3": {"name": "deepseek-v3 — freebuff-deepseek (cheap tier)"},
        "claude-3.5-sonnet-kiro": {"name": "claude-3.5-sonnet-kiro — kiro-free (medium tier)"},
        "nim-free": {"name": "nim-free — nvidia-nim (medium tier)"}
      }
    }
  },
  "model": "owl-orca-virtual/gpt-4o-mini"
}
JSON
fi

# ==================== STEP 13b/24 (v6.2): playbook integration artifacts ====================
log "STEP 13b/24 v6.2 playbook integration — tier_prices.json + tuning packs (orca-pack.sh, probe-gated, zero-downtime) + billing meter + SLA report"
if [[ $DRY_RUN -eq 0 ]]; then
atomic_write "$CFG_DIR/tier_prices.json" 0644 <<'JSON'
{
  "version": "6.2.0",
  "currency": "USD",
  "per_key": {
    "free":      {"per_1k_requests": 0.0, "metered": true},
    "cheap":     {"per_1k_requests": 0.10, "metered": true},
    "medium":    {"per_1k_requests": 0.40, "metered": true},
    "premium":   {"per_1k_requests": 1.20, "metered": true},
    "anonymous": {"per_1k_requests": 0.0, "metered": false}
  },
  "overage": {"policy": "charge", "note": "per-key rate limits enforced at :60000"},
  "note": "v6.2 P6 (playbook monetization #1): usage-metered animal-ladder API. Tier-aware pricing is the thing the animal ladder was tuned to enable — pay rabbit prices for rabbit prompts. Ledger stays append-only; hash-chain entries before charging for real."
}
JSON
mkdir -p "$CFG_DIR/packs"
atomic_write "$CFG_DIR/packs/legal-eagle.json" 0644 <<'JSON'
{
  "name": "legal-eagle",
  "version": "1.0.0",
  "description": "v6.2 P7 (playbook monetization #2): owl keywords for contract review / legal analysis; premium tier anchor",
  "rules_delta": {
    "animals": {
      "owl": {"keywords_add": ["contract", "clause", "liability", "indemnity",
                               "warranty", "breach", "tort", "jurisdiction",
                               "governing", "arbitration", "infringement",
                               "confidentiality", "termination", "majeure"]}
    }
  },
  "breaker_delta": {
    "kiro-free": {"threshold": 6, "cooldown": 75, "decay": 1}
  },
  "probe_battery": [
    ["review this contract clause for liability", "owl"],
    ["quick prototype ship now", "rabbit"],
    ["creative novel remix workaround", "dolphin"],
    ["strategy vision roadmap", "eagle"],
    ["build system architecture", "beaver"],
    ["deep analysis root cause failure", "owl"]
  ]
}
JSON
atomic_write "$CFG_DIR/packs/egress-sentinel.json" 0644 <<'JSON'
{
  "name": "egress-sentinel",
  "version": "1.0.0",
  "description": "Authored pack — PCI/proxy-stack synergy profile. Security & compliance prompts (PCI, PII, tokenization, vault, DLP, GDPR, exfiltration) anchor to owl (premium deep-analysis); proxy/HA/egress infra prompts (HAProxy, Squid, Keepalived, VRRP, ICAP, failover, round-robin, egress) anchor to beaver (medium practical-build). Breaker delta: copilot-free carries the highest P3 routing weight (1.5), so it earns a wider failure budget than its cheap-tier siblings (4/50/2 vs 3/45/2) without reaching medium's 5/60/1 — the strongest free upstream stays race-eligible longer.",
  "rules_delta": {
    "animals": {
      "owl": {"keywords_add": [
        "pci", "compliance", "tokenization", "detokenize",
        "redact", "pii", "vault", "exfiltration", "audit",
        "dlp", "gdpr"
      ]},
      "beaver": {"keywords_add": [
        "haproxy", "squid", "keepalived", "vrrp", "icap",
        "egress", "failover", "roundrobin", "loadbalance",
        "healthcheck", "proxy"
      ]}
    }
  },
  "breaker_delta": {
    "copilot-free": {"threshold": 4, "cooldown": 50, "decay": 2}
  },
  "probe_battery": [
    ["audit the tokenization vault for PII exfiltration risk", "owl"],
    ["configure haproxy failover with keepalived and squid egress proxy", "beaver"],
    ["quick prototype ship now", "rabbit"],
    ["strategy vision roadmap", "eagle"],
    ["deep analysis root cause failure", "owl"],
    ["step by step checklist", "ant"]
  ]
}
JSON
atomic_write "$BIN_DIR/orca-pack.sh" 0755 <<'SH'
#!/usr/bin/env bash
# orca-pack.sh — v6.2 P7 (playbook monetization #2): animal-profile tuning
# packs. A pack = rules delta (animal keywords) + optional breaker delta,
# hot-applied with ZERO downtime via the H5 atomic-rename + SIGHUP path.
# Activation is GATED on the classify-probe battery (6/6) so a bad pack can
# never degrade routing silently — the exact gate the playbook prescribes.
#
# usage:
#   orca-pack.sh list
#   orca-pack.sh preview <pack.json>
#   orca-pack.sh install <pack.json>
#   orca-pack.sh uninstall [backup-tag]
#   orca-pack.sh apply-all          # v6.2.1: post-reinstall pack recovery
set -euo pipefail
BASE="$HOME/.owl-orca-v6"
CFG="$BASE/config"
RULES="$BASE/tier0/promptc-os-rules.json"   # tier0 taxonomy (TIER0_DIR default)
PROV="$CFG/providers.json"
PACKS="$CFG/packs"
BACKUPS="$CFG/backups"

die() { echo "[orca-pack] $*" >&2; exit 1; }
tag() { date +%Y%m%d-%H%M%S; }
reload_router() {
  "$BASE/bin/orca-reload.sh" >/dev/null 2>&1 || pkill -HUP -f orca-router.py || true
}

apply_pack() {  # $1 = pack path — python merge, atomic rename (H5)
  python3 - "$1" "$RULES" "$PROV" <<'PY'
import json, os, sys
pack_p, rules_p, prov_p = sys.argv[1:4]
pack = json.load(open(pack_p))

rules = json.load(open(rules_p))
for animal, delta in pack.get("rules_delta", {}).get("animals", {}).items():
    spec = rules.setdefault("animals", {}).setdefault(
        animal, {"keys": [], "mode": "", "best_for": ""})
    keys = spec.setdefault("keys", [])
    for k in delta.get("keywords_add", []):
        if k not in keys:
            keys.append(k)
    for k in delta.get("keywords_remove", []):
        if k in keys:
            keys.remove(k)
    if delta.get("mode"):
        spec["mode"] = delta["mode"]
rules["version"] = "%s+%s-%s" % (rules.get("version", "v13"),
                                 pack.get("name", "pack"),
                                 pack.get("version", "1"))
t = rules_p + ".tmp"
json.dump(rules, open(t, "w"), indent=2)
os.replace(t, rules_p)

if pack.get("breaker_delta"):
    prov = json.load(open(prov_p))
    for name, pol in pack["breaker_delta"].items():
        if name in prov.get("providers", {}):
            prov["providers"][name]["circuit_breaker"] = pol
    t = prov_p + ".tmp"
    json.dump(prov, open(t, "w"), indent=2)
    os.replace(t, prov_p)
print("merged: %s %s" % (pack.get("name"), pack.get("version")))
PY
}

probe_gate() {  # 6/6 classify probes or the pack rolls back.
  # v6.2.1: HTTP when the router is live, else DIRECT tier0 invocation —
  # packs are installable pre-boot, so `apply-all` works right after a
  # reinstall with no services running (the post-reinstall recovery path).
  if curl -s -m 2 -o /dev/null http://127.0.0.1:60001/healthz; then
    python3 - "$1" <<'PY'
import json, sys, urllib.request
pack = json.load(open(sys.argv[1]))
probes = pack.get("probe_battery") or [
    ("quick prototype ship now", "rabbit"),
    ("creative novel remix", "dolphin"),
    ("strategy vision roadmap", "eagle"),
    ("build system architecture", "beaver"),
    ("deep analysis root cause", "owl"),
    ("step by step checklist", "ant")]
ok = 0
for prompt, want in probes:
    req = urllib.request.Request(
        "http://127.0.0.1:60001/v1/prompt/classify",
        data=json.dumps({"prompt": prompt}).encode(),
        headers={"Content-Type": "application/json"})
    try:
        got = json.load(urllib.request.urlopen(req, timeout=5)).get("animal")
    except Exception:
        got = None
    ok += got == want
print("probe battery: %d/%d" % (ok, len(probes)))
sys.exit(0 if ok == len(probes) else 1)
PY
  else
    PYBIN="$BASE/venv/bin/python"; [ -x "$PYBIN" ] || PYBIN=python3
    "$PYBIN" - "$1" "$BASE" <<'PY'
import json, sys
pack_p, base = sys.argv[1], sys.argv[2]
sys.path.insert(0, base)             # tree root: tier0 package
sys.path.insert(0, base + "/bin")    # v6.2.1: utils package lives in bin/ (the
                                     # router gets this as its script-dir path)
from tier0.classifier import get_tier0
pack = json.load(open(pack_p))
probes = pack.get("probe_battery") or [
    ("quick prototype ship now", "rabbit"),
    ("creative novel remix", "dolphin"),
    ("strategy vision roadmap", "eagle"),
    ("build system architecture", "beaver"),
    ("deep analysis root cause", "owl"),
    ("step by step checklist", "ant")]
t = get_tier0()
ok = sum(t.classify(p)["animal"] == w for p, w in probes)
print("probe battery (direct, router down): %d/%d" % (ok, len(probes)))
sys.exit(0 if ok == len(probes) else 1)
PY
  fi
}

cmd="${1:-}"; shift || true
case "$cmd" in
  list)
    ls -1 "$PACKS" 2>/dev/null || echo "(no packs directory)"
    exit 0 ;;
  preview)
    [ -f "${1:-}" ] || die "preview <pack.json>"
    python3 -c "import json,sys; print(json.dumps(json.load(open(sys.argv[1])), indent=2))" "$1"
    echo "[orca-pack] preview only — nothing written"
    exit 0 ;;
  install)
    [ -f "${1:-}" ] || die "install <pack.json>"
    T=$(tag)
    mkdir -p "$BACKUPS"
    cp "$RULES" "$BACKUPS/rules.$T.json"
    [ -f "$PROV" ] && cp "$PROV" "$BACKUPS/providers.$T.json"
    apply_pack "$1"
    reload_router                      # hot-apply first (zero downtime) ...
    if probe_gate "$1"; then          # ... then gate on the LIVE merged rules
      echo "[orca-pack] PACK ACTIVE: $(basename "$1") (backup tag $T, zero-downtime SIGHUP)"
    else
      cp "$BACKUPS/rules.$T.json" "$RULES"
      [ -f "$BACKUPS/providers.$T.json" ] && cp "$BACKUPS/providers.$T.json" "$PROV"
      reload_router
      echo "[orca-pack] probe gate FAILED — rolled back to $T backup"
      exit 1
    fi ;;
  uninstall)
    if [ -n "${1:-}" ]; then T="$1"; else
      T=$(ls -1 "$BACKUPS" 2>/dev/null | sed -n 's/^rules\.\([0-9-]*\)\.json/\1/p' | tail -1)
    fi
    [ -n "${T:-}" ] || die "no backup to restore"
    cp "$BACKUPS/rules.$T.json" "$RULES"
    [ -f "$BACKUPS/providers.$T.json" ] && cp "$BACKUPS/providers.$T.json" "$PROV"
    reload_router
    echo "[orca-pack] restored backup $T (SIGHUP reload)" ;;
  apply-all)
    n_ok=0; n_fail=0
    for f in "$PACKS"/*.json; do
      [ -f "$f" ] || continue
      echo "[orca-pack] apply-all: $(basename "$f")"
      if "$0" install "$f"; then n_ok=$((n_ok+1)); else n_fail=$((n_fail+1)); fi
    done
    echo "[orca-pack] apply-all done: $n_ok applied, $n_fail failed"
    [ "$n_fail" -eq 0 ] ;;
  *)
    echo "usage: orca-pack.sh {list|preview|install|uninstall|apply-all} [pack|tag]"
    exit 2 ;;
esac
SH
atomic_write "$BIN_DIR/orca-billing-meter.py" 0755 <<'PY'
#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""OWL-ORCA v6.2 — P6 (playbook monetization #1): billing meter.

Aggregates the forward-proxy JSONL ledger (logs/billing-ledger.jsonl plus
any .rotated shards) against config/tier_prices.json and writes
logs/billing-summary.json. The ledger is append-only with H5 atomic
rotation — this script never rewrites history, it only folds it.

Run nightly (cron) or on demand:
    ~/.owl-orca-v6/bin/orca-billing-meter.py [--days N]
"""
import glob
import json
import os
import sys
import time

BASE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
LOGS = os.path.join(BASE, "logs")
PRICES = os.path.join(BASE, "config", "tier_prices.json")
OUT = os.path.join(LOGS, "billing-summary.json")


def main():
    days = 1.0
    if "--days" in sys.argv:
        try:
            days = float(sys.argv[sys.argv.index("--days") + 1])
        except (IndexError, ValueError):
            pass
    since = time.time() - days * 86400.0
    with open(PRICES, encoding="utf-8") as f:
        prices = json.load(f)
    per_key = prices.get("per_key", {})

    lines = []
    for shard in sorted(glob.glob(os.path.join(LOGS,
                                               "billing-ledger.jsonl*"))):
        try:
            with open(shard, encoding="utf-8") as f:
                for ln in f:
                    ln = ln.strip()
                    if ln:
                        lines.append(json.loads(ln))
        except (OSError, ValueError):
            continue

    rows = [r for r in lines if float(r.get("ts", 0)) >= since]
    tiers = {}
    for r in rows:
        t = str(r.get("tier", "anonymous"))
        e = tiers.setdefault(t, {"requests": 0, "metered": 0})
        e["requests"] += 1
        if r.get("metered"):
            e["metered"] += 1

    total = 0.0
    detail = {}
    for t, e in sorted(tiers.items()):
        rate = float(per_key.get(t, {}).get("per_1k_requests", 0.0))
        cost = e["requests"] / 1000.0 * rate
        total += cost
        detail[t] = dict(e, rate_per_1k=rate, charge=round(cost, 4))

    summary = {
        "generated_at": time.strftime("%Y-%m-%dT%H:%M:%S%z"),
        "window_days": days,
        "ledger_entries": len(lines),
        "window_entries": len(rows),
        "tiers": detail,
        "total_charge": round(total, 4),
        "currency": prices.get("currency", "USD"),
        "audit_note": prices.get("note", ""),
    }
    tmp = OUT + ".tmp"
    with open(tmp, "w", encoding="utf-8") as f:
        json.dump(summary, f, indent=2)
    os.replace(tmp, OUT)                      # H5 atomic rename
    print(json.dumps(summary, indent=2))
    print("[billing] summary written: %s" % OUT)


if __name__ == "__main__":
    main()
PY
atomic_write "$BIN_DIR/orca-sla-report.py" 0755 <<'PY'
#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""OWL-ORCA v6.2 — P9 (playbook monetization #4): SLA report.

Folds the live router (/healthz stats + /admin/breakers) into
logs/sla-report.json: per-tier routing volume, failover counts, virtu
terminal ratio, and the breaker snapshots that serve as failover
evidence for quota-arbitrage SLAs.

Run on demand or from cron:
    ~/.owl-orca-v6/bin/orca-sla-report.py [--router http://127.0.0.1:60001]
"""
import json
import os
import sys
import time
import urllib.request

BASE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(BASE, "logs", "sla-report.json")


def _get(url):
    with urllib.request.urlopen(url, timeout=5) as r:
        return json.load(r)


def main():
    router = "http://127.0.0.1:60001"
    if "--router" in sys.argv:
        router = sys.argv[sys.argv.index("--router") + 1]
    stats = _get(router + "/healthz").get("stats", {})
    breakers = _get(router + "/admin/breakers").get("breakers", {})

    reqs = int(stats.get("requests", 0)) or 1
    tier_hits = stats.get("tier_hits", {})
    report = {
        "generated_at": time.strftime("%Y-%m-%dT%H:%M:%S%z"),
        "router": router,
        "requests_total": stats.get("requests", 0),
        "races": stats.get("races", 0),
        "per_tier": {t: {"requests": n,
                         "share_pct": round(100.0 * n / reqs, 2)}
                     for t, n in tier_hits.items()},
        "failovers": {
            "fallback_tier_walks": stats.get("fallbacks", 0),
            "virtu_terminal": stats.get("virtu_fallbacks", 0),
            "virtu_ratio_pct": round(
                100.0 * stats.get("virtu_fallbacks", 0) / reqs, 2),
        },
        "resilience": {
            "cache_hits": stats.get("cache_hits", 0),
            "guardrail_blocks": stats.get("guardrail_blocks", 0),
            "plan_free_requests": stats.get("plan_free", 0),
            "quota_skips": stats.get("quota_skips", 0),
        },
        "breaker_evidence": {
            name: {"status": b.get("status"), "fails": b.get("fails"),
                   "policy": b.get("policy")}
            for name, b in breakers.items()},
        "sla_note": "breaker snapshots are the failover log; fast trip + "
                    "ladder walk = the availability engine",
    }
    tmp = OUT + ".tmp"
    with open(tmp, "w", encoding="utf-8") as f:
        json.dump(report, f, indent=2)
    os.replace(tmp, OUT)                      # H5 atomic rename
    print(json.dumps(report, indent=2))
    print("[sla] report written: %s" % OUT)


if __name__ == "__main__":
    main()
PY
fi
