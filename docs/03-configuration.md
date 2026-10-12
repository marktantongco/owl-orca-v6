# 3 · Configuration Reference

**Goal:** you can add a provider, retune a breaker, flip routing preference, and know that every change lands live — no restarts.

All configs live in `~/.owl-orca-v6/config/`. Every file supports hot-reload via `orca-reload.sh` (SIGHUP) or `POST /admin/reload`.

---

## 3.1 `providers.json` — the upstream roster

```jsonc
{
  "providers": {
    "copilot-free": {
      "display_name": "GitHub Copilot Free",
      "base_url": "https://api.githubcopilot.com",
      "format": "openai",                    // wire format: openai | anthropic | mcp
      "models": ["gpt-4o-mini", "gpt-4o", "o1-mini", "claude-3.5-sonnet"],
      "cost_tier": "cheap",                  // cheap | medium | premium | expensive
      "weight": 1.5,                         // race ordering: higher = earlier lane
      "daily_quota": 5000,                   // skipped at the ceiling, never hard-down
      "auth_method": "device_flow",
      "token_encryption": "fernet",
      "circuit_breaker": { "threshold": 4, "cooldown": 50, "decay": 2 }
    }
  }
}
```

**Field semantics:**

| Field | Meaning | Hot |
|---|---|---|
| `weight` | pre-race ordering multiplier (OpenRouter provider-order pattern) | ✅ |
| `daily_quota` | GooseRelay-style daily ceiling; `quota-state.json` tracks spend | ✅ |
| `circuit_breaker` | per-provider override of the tier default | ✅ |
| `cost_tier` | which candidate band this provider races in | ✅ |
| `format: anthropic` | activates H3b SSE translation (`thinking_delta` → `reasoning_content`) | ✅ |
| `requires_translation` | protocol shim between wire formats | ✅ |

Global knobs in the same file:

```jsonc
{
  "cache": { "enabled": true, "max_age": 3600, "max_entries": 256 },   // P1 response cache
  "guardrails": [ { "id": "prompt-injection", "action": "block" } ],   // P2 pre-flight
  "request_settings": { "num_retries": 2, "timeout": 20 },             // P4 race deadline
  "plans": { "free": { "prefix": "oc-free-", "terminal": "virtu-echo", "rpm": 30 } }, // P8
  "breaker_policy": { "per_cost_tier": { "cheap": { "threshold": 3, "cooldown": 45, "decay": 2 }, ... } }
}
```

## 3.2 `routes.json` — the request path

Each route declares strategy, candidate tiers, and the middleware chain:

```jsonc
{
  "pattern": "/v1/chat/completions", "method": "POST",
  "strategy": "cost-aware-race",
  "routing_preference": "balanced",          // price | latency | balanced
  "cost_logic": {
    "simple_query":  { "max_tokens": 500,  "targets": ["copilot-free", "antigravity-free", "freebuff-deepseek"], "savings": "70%" },
    "complex_query": { "max_tokens": 8000, "targets": ["kiro-free", "nvidia-nim", "antigravity-free"], "savings": "40%" }
  },
  "middleware": [
    { "stage": "billing", "service": "owl-forward-billing", "port": 60000, "order": 1 },
    { "stage": "defense", "cache_ttl": 300, "dedup": true, "rate_limit": 1.0 },
    { "stage": "tier0",  "lru_cache": 1024, "envelope_ms": 5 },
    { "stage": "race",   "first_byte_wins": true, "bounded_queue": 5, "cancel_losers": true },
    { "stage": "egress", "ja3_stealth": true, "socks5_pool": true },
    { "stage": "memory", "store_winner": true, "decay_failures": true }
  ]
}
```

`routing_preference` re-orders candidates *before* the race: `price` maximizes savings, `latency` chases the EMA, `balanced` blends both.

## 3.3 `tier_prices.json` — the billing dial

```json
{ "cheap": 0.10, "medium": 0.40, "premium": 1.20 }   // USD per 1k completions tokens
```

The billing meter folds the `:60000` ledger against these prices — change them mid-month and the next report uses the new rates for new usage.

## 3.4 Adding a provider (the 60-second version)

```bash
cd ~/.owl-orca-v6/config

# 1. Append your provider block (shown for a local Ollama lane)
python3 - <<'EOF'
import json, os
p = os.path.expanduser("~/.owl-orca-v6/config/providers.json")
d = json.load(open(p))
d["providers"]["local-ollama"] = {
    "display_name": "Local Ollama",
    "base_url": "http://127.0.0.1:11434/v1",
    "format": "openai",
    "models": ["llama3"],
    "cost_tier": "cheap",
    "weight": 0.9,
    "daily_quota": 100000
}
json.dump(d, open(p + ".tmp", "w"), indent=2); os.replace(p + ".tmp", p)
EOF

# 2. Hot-apply (socket stays LISTEN)
~/.owl-orca-v6/bin/orca-reload.sh

# 3. Prove it — candidate list should include local-ollama
curl -s http://127.0.0.1:60001/admin/routing | python3 -m json.tool
```

## 3.5 Admin endpoints (the operator surface)

| Endpoint | Method | Purpose |
|---|---|---|
| `/healthz` | GET | hacks live, breaker states, stats, v6.2 features |
| `/admin/reload` | POST | same as SIGHUP; returns the reloaded file list |
| `/admin/breakers` | GET/POST | inspect / hot-apply breaker policy |
| `/admin/routing` | GET | candidate order per tier (weight × EMA) |
| `/admin/quota` | GET | daily quota state per provider |
| `/admin/cache` | GET | response cache hits/entries |
| `/v1/prompt/classify` | POST | run tier-0 on any text (with timing) |

## 3.6 Config change discipline

1. **Never edit in place with the router mid-write** — use the `tmp + os.replace` pattern (every CLI in this repo does)
2. **Reload, then verify** — `orca-reload.sh && curl -s localhost:60001/healthz`
3. **Rollback is `config/backups/`** — every pack/reload writes timestamped backups; `cp` one back and reload
4. For anything user-facing, gate it: tuning packs do this with a 6/6 probe battery (next guide)

---

**Next:** [Tuning Packs →](04-packs.md)
