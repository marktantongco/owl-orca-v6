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
