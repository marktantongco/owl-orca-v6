# 5 · Operations Runbook

**Goal:** day-to-day operation from memory, and a 3 a.m. page you can resolve in one screen. The full formatted runbook also ships as [`owl-orca-v6-ops-runbook.html`](owl-orca-v6-ops-runbook.html).

---

## 5.1 Daily driver commands

```bash
B=~/.owl-orca-v6/bin
$B/orca-health-check.sh          # services + hack selftest in one shot
$B/orca-reload.sh                # hot-reload configs (socket stays LISTEN)
$B/orca-billing-meter.py         # fold ledger → logs/billing-summary.json
$B/orca-sla-report.py            # → logs/sla-report.json (tier shares, breaker evidence)
$B/orca                          # cheat-sheet banner of everything above
```

## 5.2 Health matrix

| Check | Command | Healthy |
|---|---|---|
| Router | `curl -s :60001/healthz` | `200`, `H1_uvloop: true` |
| Forward proxy | `curl -s :60000/healthz` | `200`, stages 1,2,7 listed |
| Virtu-Echo | `curl -s :60009/healthz` | `200` |
| Breakers | `curl -s :60001/admin/breakers` | no unexpected `OPEN` |
| Quota | `curl -s :60001/admin/quota` | `remaining > 0` on primaries |
| Cache | `curl -s :60001/admin/cache` | hit ratio climbing on repeat traffic |

## 5.3 Change management (the only three verbs)

```bash
# 1. READ everything
curl -s http://127.0.0.1:60001/healthz | python3 -m json.tool

# 2. WRITE with tmp + atomic rename (never truncate a live file)
python3 - <<'EOF'
import json, os
p = os.path.expanduser("~/.owl-orca-v6/config/providers.json")
d = json.load(open(p)); d["request_settings"]["timeout"] = 12
json.dump(d, open(p + ".tmp", "w"), indent=2); os.replace(p + ".tmp", p)
EOF

# 3. RELOAD + verify
~/.owl-orca-v6/bin/orca-reload.sh && curl -s http://127.0.0.1:60001/healthz
```

Rollback: `ls ~/.owl-orca-v6/config/backups/` → copy the timestamped file back → reload.

## 5.4 Breaker operations

```bash
# Inspect (state survives restarts)
curl -s http://127.0.0.1:60001/admin/breakers | python3 -m json.tool

# Retune policy live (threshold/cooldown/decay, per provider or per tier)
curl -s -X POST http://127.0.0.1:60001/admin/breakers \
  -H 'Content-Type: application/json' \
  -d '{"provider":"kiro-free","policy":{"threshold":6,"cooldown":75,"decay":1}}'
```

**Interpretation guide:** a provider flapping `OPEN ⇄ HALF_OPEN` with decay working is *healthy* — it is re-probing. A provider permanently `OPEN` either lost auth (re-run its login flow) or exhausted quota (`/admin/quota`).

## 5.5 Quota operations

```bash
curl -s http://127.0.0.1:60001/admin/quota | python3 -m json.tool
# "freebuff-deepseek": { "daily_quota": 20000, "used": 8412, "remaining": 11588 }
```

Quota spend is charged atomically on wins (`quota-state.json`, same atomic-rename discipline). A quota-full provider is **skipped, not downed** — if every provider is full, the tier falls back to the full list (preference, not hard-down).

## 5.6 Money surfaces

```bash
# Ledger → summary (per tier, per day)
~/.owl-orca-v6/bin/orca-billing-meter.py            # logs/billing-summary.json

# SLA evidence (attach this to any reliability claim)
~/.owl-orca-v6/bin/orca-sla-report.py               # logs/sla-report.json
```

`sla-report.json` contains per-tier request shares, failover counts, virtu ratio, and per-breaker event evidence — the artifact to attach when a customer asks "prove your uptime".

## 5.7 Backup / snapshot / restore

```bash
# Snapshot (include pack-active state; tar the tree, exclude venv)
tar --exclude='~/.owl-orca-v6/venv' -czf \
  owl-orca-v6.2.1-tuned-snapshot-$(date +%Y%m%d).tar.gz -C ~ .owl-orca-v6
sha256sum owl-orca-v6.2.1-tuned-snapshot-*.tar.gz > snapshot.sha256

# Restore
tar -xzf owl-orca-v6.2.1-tuned-snapshot-<date>.tar.gz -C ~
~/.owl-orca-v6/bin/orca-pack.sh apply-all          # re-activate packs
~/.owl-orca-v6/bin/orca-health-check.sh
```

## 5.8 Troubleshooting quick table

| Symptom | First look | Fix |
|---|---|---|
| `healthz` non-200 | `~/.owl-orca-v6/logs/router.log` | `systemctl --user restart owl-orca-router` (last resort — reload first) |
| All races → virtu-echo | `/admin/breakers` | upstream auth expired — re-run provider login; breakers self-heal |
| `400 guardrail_violation` | your prompt | guardrail battery matched injection patterns — by design |
| Slow races | `/admin/routing` | EMA drifted — check upstream latency or lower `weight` on slow lanes |
| Pack won't activate | probe output | a probe expects a different animal — fix the pack's `keywords_add` |
| Quota exhausted early | `/admin/quota` | raise `daily_quota` (reload) or add another cheap provider |

## 5.9 Incident pattern: total brownout

Total brownout is a *designed state*, not a failure: the ladder walks to virtu-echo, completions stay labeled (`X-Owl-Orca-Route: virtu_echo`), agents keep their loop, and `sla-report.json` records the window. Recovery is: fix one upstream → breaker decays to HALF_OPEN → probe re-admits it → traffic resumes. No restarts required at any point.

---

**Next:** [Validation & Testing →](06-validation.md)
