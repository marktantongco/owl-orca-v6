# 2 · Architecture Deep-Dive

**Goal:** you can name every layer, every port, and the file that implements each — and you understand why the weird design choices are load-bearing.

---

## 2.1 The request lifecycle

```
client ──▶ :60001 router ──▶ guardrails ──▶ response cache ──▶ tier-0 classify
                                                              │ (animal → cost band)
            ◀── SSE translate ── StreamRacer race ◀── candidate order ◀──┘
                     │  (5 lanes, first success wins, losers canceled)
                     ├── breaker OPEN?  → skip lane
                     ├── quota full?    → skip lane (never hard-down the tier)
                     └── all broken?    → fallback_tier ladder → virtu-echo (labeled)
```

Every phase is observable: response headers (`X-Owl-Orca-Cache`, `X-Owl-Orca-Plan`, `X-Owl-Orca-Route`), `/healthz` stats, and the `:60000` JSONL ledger record the decision trail.

## 2.2 Layer map — where the code lives

| Layer | Port | Implementation |
|---|---|---|
| Ingress router | `:60001` | `src/bin/orca-router.py` — FastAPI + uvicorn (uvloop), radix-array trie routes |
| Defense plane | in-process | guardrail regex battery + dedup/rate-limit in the router |
| Tier-0 classifier | embedded | `src/tier0/classifier.py` + `promptc-os-rules.json` + `sp7-scoring.json` |
| Race engine | in-process | StreamRacer in the router; SSE translation (H3b) for Anthropic upstreams |
| Breaker + fallback | `:60009` | `src/bin/utils/circuit_breaker.py`, ladder logic in router, `virtu_echo.py` |
| Forward proxy / billing | `:60000` | `src/bin/forward_proxy.py` — tier auth, rate limits, JSONL ledger |
| Kiro shim | `:8333` | `src/bin/kiro-gateway-shim.py` — AWS Builder ID OIDC to OpenAI shape |
| Egress | `:1455` | freebuff-proxy companion repo (JA3 stealth) — external, opt-in |
| Billing meter / SLA | CLI | `src/bin/orca-billing-meter.py`, `orca-sla-report.py` |

## 2.3 The animal taxonomy (tier-0)

Seven animals, three price bands, one terminal:

| Animal | Mode | Band | Keys |
|---|---|---|---|
| Rabbit | Speed & Multiply Ideas | cheap | 20 |
| Ant | Break Into Steps | cheap | 15 |
| Dolphin | Creative Solutions | cheap | 11 |
| Beaver | Build Systems | medium | 23 |
| Elephant | Cross-Field Connections | medium | 12 |
| Eagle | Big Picture Strategy | premium | 12 |
| Owl | Deep Analysis | premium | 38 |

Classification is a **radix-trie keyword scan + weighted vote** wrapped in `functools.lru_cache(1024)` — repeat prompts never re-scan. Measured: **< 2 ms** (inside the 5 ms routing envelope). This replaced v5's three Next.js PWA planes: 384 MB → ~10 MB resident.

## 2.4 StreamRacer semantics

- **Bounded queue of 5** — every candidate in the tier's list, ordered by `weight × first-byte latency EMA`
- **First *success* wins** — not first byte: a lane that emits an error first is ignored, the race continues until a valid completion streams
- **Losers are canceled** mid-stream — one completion is paid for, not five
- **`request_settings`** (`num_retries`, `timeout`) are LiteLLM-style knobs, hot-applied — retries happen pre-first-byte during the ladder walk

## 2.5 Breaker + ladder + terminal

Breaker policy is per **cost tier** (not per provider) by default; per-provider overrides and pack deltas are merged on top:

```
cheap:  3 fails → OPEN 45s (decay 2)   medium: 5 → 60s (decay 1)
premium: 7 fails → OPEN 90s (decay 1)  expensive: 3 → 300s (decay 1)
```

When a band is exhausted (breakers OPEN, quotas full), the **`fallback_tier` ladder** walks *down*: owl/eagle → medium → cheap → **virtu-echo**. Virtu-Echo (`:60009`) is a labeled virtual completion — it keeps the agent's loop alive during total brownout, and every response it produces is visibly marked (`X-Owl-Orca-Route: virtu_echo`). Honesty is a design constraint, not a setting.

## 2.6 Hot-reload (H5) — the trick that makes the rest livable

1. Edit any config (`providers.json`, `routes.json`, `tier_prices.json`, taxonomy)
2. The tooling writes `file.tmp` and **`os.replace()`s** it — atomic on POSIX, no torn reads
3. `SIGHUP` (or `POST /admin/reload`) re-opens files by path and swaps in-memory state
4. The listening socket is never closed — `:60001` stays `LISTEN` throughout

The systemd units ship `ExecReload=/bin/kill -HUP $MAINPID` so `systemctl --user reload owl-orca-router` is the same thing.

## 2.7 Memory profile (default)

| Component | Resident |
|---|---|
| router :60001 | 384 MB |
| forward :60000 | 128 MB |
| kiro :8333 | 256 MB |
| virtu-echo :60009 | 64 MB |
| tier-0 + memory hub | ~10 MB |
| **core total** | **~832 MB** (+ optional freebuff 256 MB) |

Optional tiers (DPI bypass, 9router, ruflo) are off by default and gated behind explicit install flags — the installer refuses to spend RAM you didn't ask for.

---

**Next:** [Configuration Reference →](03-configuration.md)
