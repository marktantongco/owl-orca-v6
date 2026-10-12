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
