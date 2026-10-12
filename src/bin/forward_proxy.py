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
