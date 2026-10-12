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
