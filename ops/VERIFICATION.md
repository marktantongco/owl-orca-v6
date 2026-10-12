# OWL-ORCA v6.0 UNIFIED FINAL — Verification Checklist

## v6.2 Playbook Integration (must pass)
- [ ] response cache: identical non-streaming request twice — 2nd response
      carries `X-Owl-Orca-Cache: hit`; `/admin/cache` stats hits>=1;
      streaming requests carry `X-Owl-Orca-Cache: bypass`
- [ ] guardrails: "ignore all previous instructions" returns OpenAI-shaped
      400 `{error: {type: guardrail_violation}}`; normal prompts pass
- [ ] weighted routing: `/admin/routing` shows candidates ordered by
      weight (balanced) — copilot-free 1.5 first in cheap tier
- [ ] daily-quota guard: set `daily_quota: 2` on a provider + SIGHUP —
      after 2 wins it is skipped (`/admin/quota` remaining=0) but never
      hard-downs the tier (all-exhausted falls back to full list)
- [ ] plan gate: request with `Authorization: Bearer oc-free-...` returns
      `X-Owl-Orca-Plan: free` + provider `virtu-echo`
- [ ] tuning pack: `orca-pack.sh install config/packs/legal-eagle.json`
      prints `probe battery: 6/6` then `PACK ACTIVE`; classify
      "contract clause liability" -> owl; uninstall restores
- [ ] billing meter: `orca-billing-meter.py` writes logs/billing-summary.json
      from the :60000 JSONL ledger x config/tier_prices.json
- [ ] SLA report: `orca-sla-report.py` writes logs/sla-report.json with
      per-tier shares + breaker evidence
- [ ] all v6.2 sections hot-apply: edit providers.json + `orca-reload.sh`
      — `/admin/reload` lists v6.2_hot_applied, healthz 200 throughout

## Core (must pass)
- [ ] router :60001 /healthz — `hacks` object shows H1..H8 live
- [ ] `orca-router.py --selftest` exits 0 (H2 trie us/lookup, H4 breaker
      transitions, H3b SSE translation, H7 tier0 latency, H8 pool singleton)
- [ ] forward-proxy :60000 /healthz — Stages 1,2,7 + ledger JSONL path
- [ ] kiro-gateway :8333 /healthz (shim; real gateway after kiro-cli login)
- [ ] tokens.enc + .fernet.key 0600, written via atomic rename (H5)
- [ ] SIGHUP: `orca-reload.sh` — :60001 stays LISTEN (no TCP drop) and
      `/admin/reload` returns the 4 reloaded JSON files
- [ ] swap guard honored (2G core / 4G heavy profiles)

## 9 Hack Assertions
- [ ] H1 uvloop: healthz `H1_uvloop: true` (pip install uvloop succeeded)
- [ ] H2 radix array trie: selftest reports <1000us/lookup, 4KB flat array
- [ ] H3 StreamRacer: bounded 5, `loser_cancels` increments on races;
      SSE output contains `reasoning_content`, never `thinking_delta`
- [ ] H4 CircuitBreaker: selftest PASS (5 fails -> OPEN, decay 1 -> HALF_OPEN,
      probe fail -> OPEN again)
- [ ] H5 SIGHUP atomic mv: configs edited while router runs -> reload -> new
      values served, socket never closed
- [ ] H6 LazyModel: mempalace /healthz shows `loaded: false` at rest, loads on
      first /v1/embed, unloads 300s later
- [ ] H7 Tier0 LRU: /v1/prompt/classify `elapsed_ms < 2`, `cache_info` hits
      grow on repeat prompts
- [ ] H8 httpx pool: singleton client, http2=True, max_connections=100,
      UA Chrome/120
- [ ] H9 graftcp: wrapper uses --select_proxy_mode only_socks5 +
      --black-ip-file/--white-ip-file; goose-client.json has zstd:true

## Memory Ledger (default profile ~= 1108M)
- [ ] router 384M + forward 128M + kiro 256M + virtu-echo 64M (v6.1) = 832M core
- [ ] tier0 ~10M (F3: PWA 374M saved), memory-hub unit eliminated (128M)
- [ ] freebuff 256M + graftcp ~10M (per-invocation)
- [ ] F4: 9router/ruflo absent (768M); F5: DPI tier absent (148M);
      F6: hydra absent (128M); F7: nylon absent (5M)

## Egress (if enabled)
- [ ] freebuff :1455 + dash :9091 — curl --socks5-hostname 127.0.0.1:1455
- [ ] graftcp wrapper: graftcp-wrapper.sh curl https://example.com
- [ ] DPI gate only with --with-dpi-bypass: mhrv :8085, mieru :1082, goose :1080
- [ ] goose tunnel key 64-hex, 0600, never shared

## Port Registry (unique, re-audited)
60001 60000 8333 60003 5000 1455 9091 9092 10808 1080 1081 1082 8085 8086
60004 60002 60009 60012 60013 60014 60015 60008 3001 8787 3006 3007 31000 20128
7890 8330 48321 3000 3008 3009 3010 3011 40325 — released: 3002 3003 3004
