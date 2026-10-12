# Changelog

## v6.2.1 — 2026-10-12

First public release of the v6 lineage.

**Stack**
- 7-layer OpenAI-compatible router (`:60001`): guardrails, response cache, tier-0 animal classifier (< 2 ms), StreamRacer bounded-5 first-success race, per-tier circuit breakers, fallback ladder, Virtu-Echo labeled terminal (`:60009`)
- Forward billing proxy (`:60000`) with per-tier keys and JSONL ledger
- 9 performance hacks hard-wired (H1 uvloop … H9 graftcp seccomp)
- SIGHUP hot-reload everywhere: atomic-rename configs, zero TCP drops

**v6.2 playbook integration (P1–P10)**
- Response cache (sha256 key, 256 LRU, provenance header replay)
- Guardrail battery (prompt-injection, self-harm → OpenAI-shaped 400)
- Weighted routing + first-byte latency EMA ordering (price | latency | balanced)
- LiteLLM-style `request_settings` hot-apply
- Daily-quota guard (skip at ceiling, never hard-down)
- Plan gate freemium (`oc-free-` keys → labeled virtu-echo, 30 rpm)
- Tuning packs with 6/6 probe gate and auto-rollback (`orca-pack.sh`)
- Billing meter + SLA evidence reports
- 27 prompt cards (10 config / 11 hacks / 5 monetization)

**v6.2.1 fixes**
- `audit_v6.py` real-install matrix silently reverted pack deltas → audit is now dry-run-only (`AUDIT_REAL_INSTALL=1` opt-in)
- `orca-pack.sh apply-all`: post-reinstall pack recovery with the router down (direct tier-0 probes)
- Both fixes baked into the installer (4,134 lines)

**Proof**
- 51/51 marker audit · 9/9 fresh-box v6.2 battery · 5/5 animals under real OpenCode 1.19.0 traffic with pack breakers live across reinstall

**Earlier lineage** (pre-public): v4.5 real Python modules → v4.7 egress build code → v4.9 unified framework → v5 skeleton → v6.0 merge with 9 hacks → v6.1 fallback ladder + breaker hot-apply → v6.2 playbook integration.
