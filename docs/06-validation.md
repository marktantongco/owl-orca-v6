# 6 · Validation & Testing

**Goal:** you can reproduce every claim this repo makes — on a fresh box, in one command per claim. The verification checklist itself ships as [`ops/VERIFICATION.md`](../ops/VERIFICATION.md).

**One rule:** every proof here runs in a **single invocation** (background services are reaped between tool invocations on CI-style sandboxes — the scripts boot, prove, and report within one run).

---

## 6.1 The verification pyramid

```
        ┌─ oc_battery.sh ─────────── real agent traffic (OpenCode) ─┐
        ├─ prove_v62.sh ──────────── 9 v6.2 features on fresh boot ─┤  full-stack
        ├─ prove_v61.sh ──────────── fallback ladder + breaker SIGHUP┤  proofs
        ├─ audit_v6.py ───────────── 51/51 static marker audit ──────┤
        └─ orca-router.py --selftest  H1..H8 hack assertions ────────┘  unit level
```

## 6.2 Static audit — `ops/audit_v6.py`

```bash
python3 ops/audit_v6.py          # expect: 51/51 PASS
```

Verifies the installer carries every v6 + v6.2 marker (hacks, breaker policy, cache, guardrails, plans, packs, billing, SLA). Since v6.2.1 the audit is **dry-run only** — it can never rewrite your live configs (the old real-install matrix was the bug that silently reverted pack deltas; opt back in with `AUDIT_REAL_INSTALL=1` if you ever need that behavior).

## 6.3 Hack selftest — `--selftest`

```bash
~/.owl-orca-v6/venv/bin/python ~/.owl-orca-v6/bin/orca-router.py --selftest
```

Asserts the performance-critical innards: H2 trie lookup latency, H4 breaker state transitions (5 fails → OPEN, decay → HALF_OPEN, probe fail → OPEN again), H3b SSE translation, H7 tier-0 latency, H8 pool singleton. Exits 0 on pass.

## 6.4 v6.1 proof — fallback ladder + breaker hot-apply

```bash
bash ops/prove_v61.sh            # boots its own services + mock upstream
```

Proves: tier walk under broken providers, breaker policy SIGHUP hot-apply (threshold 2→7 live), labeled OpenAI-shaped errors instead of naked 502s, and that the listening socket survives reload.

## 6.5 v6.2 proof — the nine-feature battery

```bash
bash ops/prove_v62.sh            # boots router + virtu + forward + mock upstream
```

| # | Feature | Pass signal |
|---|---|---|
| P1 | Response cache | miss → hit → bypass headers; `/admin/cache` stats |
| P2 | Guardrails | injection prompt → 400 `guardrail_violation`; normal → 200 |
| P3 | Weighted routing | `/admin/routing` shows copilot-free first in cheap tier |
| P4 | request_settings | retry/timeout hot-applied via one SIGHUP |
| P5 | Daily-quota guard | provider skipped at exactly N wins, tier never hard-downed |
| P6 | Billing meter | ledger × tier prices = expected USD (math verified) |
| P7 | Tuning pack | 6/6 probe gate → PACK ACTIVE → legal prompt → owl |
| P8 | Plan gate | `oc-free-` key → `X-Owl-Orca-Plan: free` + virtu-echo |
| P9 | SLA report | per-tier shares + 7 breaker evidence entries |

The script uses `ops/mock_upstream.py` as a controllable fake freebuff upstream (`:1455`) so proofs never depend on external services.

## 6.6 Real agent traffic — the OpenCode battery

```bash
bash ops/oc_battery.sh           # needs: opencode installed + wired to :60001
```

Sends five prompts (one per animal) through **real OpenCode agent traffic**, then prints router stats. Expected: 5/5 completions, races counted, zero dropped sockets — with pack breaker deltas still live (this battery is what caught the audit-revert bug in v6.2.1).

## 6.7 Fresh-box verification

```bash
bash ops/fresh_box_tuned_verify.sh   # fresh install → snapshot → restore → pack apply-all → re-prove
```

Round-trips the whole lifecycle: install, snapshot, wipe, restore, `apply-all` packs, re-run the battery. If this passes, your restore path is real.

## 6.8 Continuous verification (suggested cron)

```cron
*/30 * * * *  ~/.owl-orca-v6/bin/orca-health-check.sh >> ~/.owl-orca-v6/logs/health.log 2>&1
0 2 * * *     ~/.owl-orca-v6/bin/orca-sla-report.py
```

---

**Next:** [Integrations →](07-integrations.md)
