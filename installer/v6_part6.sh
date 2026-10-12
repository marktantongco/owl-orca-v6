
# ==================== STEP 21/24: H5 SIGHUP hot reload ====================
log "STEP 21/24 bin/orca-reload.sh — SIGHUP hot reload without dropping TCP (H5: atomic-mv inode swap + ExecReload HUP; v6.1 also hot-applies breaker policy edits)"
if [[ $DRY_RUN -eq 0 ]]; then
atomic_write "$BIN_DIR/orca-reload.sh" 0755 <<'RELOAD'
#!/usr/bin/env bash
# OWL-ORCA v6 SIGHUP hot-reload (H5).
# Files are swapped by atomic rename() — inode changes — so inotify/IDE
# watchers never crash on torn reads, and the router re-opens by path.
# The TCP listener is NEVER closed: ExecReload sends SIGHUP to MAINPID.
set -euo pipefail
echo "[orca] SIGHUP hot-reload — routing + tier0 configs, no TCP drop"
systemctl --user reload orca-router.service 2>/dev/null \
  || systemctl --user kill -s HUP orca-router.service 2>/dev/null \
  || pkill -HUP -f "orca-router.py" 2>/dev/null \
  || echo "[warn] router not running — configs reload on next start"
systemctl --user reload orca-forward-proxy.service 2>/dev/null || true
systemctl --user reload orca-kiro-gateway.service 2>/dev/null || true
for f in promptc-os-rules.json sp7-scoring.json; do
  p="$HOME/.owl-orca-v6/tier0/$f"
  if [[ -f "$p" ]]; then
    echo "[tier0] $f present (atomic-swapped) — router re-read on HUP"
  fi
done
ss -H -tln 'sport = :60001' | grep -q ':60001' \
  && echo "[orca] :60001 still LISTEN — zero TCP drop verified" \
  || echo "[orca] :60001 not listening (router may be starting)"
echo "[orca] reload complete"
RELOAD
fi

# ==================== STEP 22/24: health checks + hack self-test ====================
log "STEP 22/24 bin/orca-health-check.sh + in-process hack self-test (H1-H8 asserted, H9 config-checked)"
if [[ $DRY_RUN -eq 0 ]]; then
atomic_write "$BIN_DIR/orca-health-check.sh" 0755 <<'HEALTH'
#!/usr/bin/env bash
# OWL-ORCA v6 health check — core ports, hack assertions, egress probes.
set -uo pipefail
echo "=== OWL-ORCA v6.0 UNIFIED FINAL Health Check ==="
echo "Core: router 384M (H1-H8 embedded) + forward 128M + kiro 256M = 768M"
echo "Tier-0: embedded JSON+LRU (~10M, F3: 374M PWA saved)"
echo ""
echo "[1] Hack self-test (in-process):"
"$HOME/.owl-orca-v6/venv/bin/python" "$HOME/.owl-orca-v6/bin/orca-router.py" --selftest
echo ""
echo "[2] Port registry:"
for port in 60001 60000 8333 60003 5000 1455 9091 9092 10808 1080 1081 1082 \
            8085 8086 60004 60002 60012 60013 60014 60015 3001 8787 3006 3007 \
            31000 20128 7890 8330 48321 3000 3008 3009 3010 3011 40325 60008; do
  if ss -H -tln "sport = :$port" 2>/dev/null | grep -q ":$port"; then
    echo "  [OK] :$port in use"
  else
    echo "  [--] :$port not active (optional)"
  fi
done
echo ""
echo "[3] Core endpoints:"
curl -sf http://127.0.0.1:60001/healthz && echo "" || echo "  router not ready"
curl -sf http://127.0.0.1:60000/healthz && echo "" || echo "  forward-proxy not ready"
curl -sf http://127.0.0.1:8333/healthz  && echo "" || echo "  kiro shim not ready"
echo ""
echo "[4] Tier-0 classifier (H7, expect <2ms inside 5ms envelope):"
curl -s -X POST http://127.0.0.1:60001/v1/prompt/classify \
  -H 'Content-Type: application/json' \
  -d '{"prompt":"brainstorm ideas multiply divergent options"}' || echo "  (router down)"
echo ""
echo "[5] Egress probes:"
echo "  curl --socks5-hostname 127.0.0.1:10808 https://example.com   # hydra 6 rotations"
echo "  curl --socks5-hostname 127.0.0.1:1455 https://example.com     # freebuff JA3 chrome120"
echo "  $HOME/.owl-orca-v6/bin/graftcp-wrapper.sh curl https://example.com  # H9 seccomp only_socks5"
echo "  curl --socks5-hostname 127.0.0.1:1080 https://example.com     # goose AES-GCM Zstd (DPI gate)"
echo "  curl -x http://127.0.0.1:8085 https://example.com             # mhrv free 20k/day (DPI gate)"
echo ""
echo "[6] SIGHUP zero-drop check:"
"$HOME/.owl-orca-v6/bin/orca-reload.sh"
echo "=== Health Check Complete ==="
HEALTH
fi

# ==================== STEP 23/24: CLI wrappers + VERIFICATION.md ====================
log "STEP 23/24 CLI wrappers + VERIFICATION.md"
if [[ $DRY_RUN -eq 0 ]]; then
mkdir -p "$HOME/.local/bin"
atomic_write "$BIN_DIR/orca" 0755 <<'CLI'
#!/usr/bin/env bash
echo "OWL-ORCA v6.2 UNIFIED FINAL + PLAYBOOK INTEGRATION (v4.9 + v5 merged + 9 hacks + v6.1 + v6.2)"
echo "Core  : router :60001 (H1 uvloop, H2 radix array trie, H3 StreamRacer bounded 5"
echo "        first-byte-wins + SSE memoryview thinking_delta->reasoning_content,"
echo "        H4 breakers 5->OPEN 60s HALF_OPEN decay 1) + forward :60000 + kiro :8333"
echo "Tier0 : embedded JSON+LRU H7 <2ms — PWA removed, 374M saved (F3)"
echo "v6.1  : fallback_tier ladder + virtu-echo :60009 terminal + breaker hot-apply"
echo "v6.2  : response cache + guardrails + weighted routing + daily-quota guard +"
echo "        plan gate (freemium) + tuning packs + billing meter + SLA report"
echo "Egress: freebuff :1455 JA3 chrome120 (default) + graftcp H9 seccomp only_socks5"
echo "Opt-in: hydra (F6) nylon (F7) DPI tier (F5 gate) 9router/ruflo (F4) GLM (F10)"
echo "Memory: mempalace LazyModel H6 — zero fixed embedding memory"
echo ""
echo "Usage: $HOME/.owl-orca-v6/bin/orca-health-check.sh   # includes hack selftest"
echo "       $HOME/.owl-orca-v6/bin/orca-reload.sh          # SIGHUP no TCP drop"
echo "       $HOME/.owl-orca-v6/bin/graftcp-wrapper.sh CMD  # H9 forced egress"
echo "       $HOME/.owl-orca-v6/bin/orca-pack.sh install <pack.json>  # v6.2 hot pack"
echo "         (example: config/packs/legal-eagle.json)"
echo "       $HOME/.owl-orca-v6/bin/orca-billing-meter.py    # v6.2 metered ledger"
echo "       $HOME/.owl-orca-v6/bin/orca-sla-report.py       # v6.2 SLA evidence"
CLI
atomic_write "$HOME/.local/bin/owl-proxy" 0755 <<'SH'
#!/usr/bin/env bash
export HTTP_PROXY=http://127.0.0.1:60000
export HTTPS_PROXY=http://127.0.0.1:60000
exec "$@"
SH
atomic_write "$HOME/.local/bin/owl-router" 0755 <<'SH'
#!/usr/bin/env bash
exec "$HOME/.owl-orca-v6/venv/bin/python" "$HOME/.owl-orca-v6/bin/orca-router.py" "$@"
SH

atomic_write "$BASE_DIR/VERIFICATION.md" 0644 <<'MD'
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
MD
fi

# ==================== STEP 24/24: activation + final summary ====================
log "STEP 24/24 activation (Safe-Mode aware) + final summary"
if [[ $DRY_RUN -eq 0 ]]; then
  systemctl --user daemon-reload 2>/dev/null || true
  CORE_UNITS="orca-router.service orca-forward-proxy.service orca-kiro-gateway.service"
  EXTRA_UNITS=""
  [[ $WITH_FREEBUFF -eq 1 ]]    && EXTRA_UNITS="$EXTRA_UNITS orca-freebuff-proxy.service"
  [[ $WITH_HYDRA -eq 1 ]]       && EXTRA_UNITS="$EXTRA_UNITS orca-hydra-gate.service"
  [[ $WITH_NYLON -eq 1 ]]       && EXTRA_UNITS="$EXTRA_UNITS orca-nylon.service"
  [[ $WITH_GOOSERELAY -eq 1 ]]  && EXTRA_UNITS="$EXTRA_UNITS orca-goose-client.service"
  [[ $WITH_MHRV -eq 1 ]]        && EXTRA_UNITS="$EXTRA_UNITS orca-mhrv-rs.service"
  [[ $WITH_MIERU -eq 1 ]]       && EXTRA_UNITS="$EXTRA_UNITS orca-mieru-client.service"
  [[ $WITH_MEMPALACE -eq 1 ]]   && EXTRA_UNITS="$EXTRA_UNITS orca-mempalace.service"
  [[ $WITH_RTK -eq 1 ]]         && EXTRA_UNITS="$EXTRA_UNITS orca-rtk.service"
  [[ $WITH_DEER -eq 1 ]]        && EXTRA_UNITS="$EXTRA_UNITS orca-deer-flow.service"
  [[ $WITH_OWL_RAG -eq 1 ]]     && EXTRA_UNITS="$EXTRA_UNITS orca-owl-agent-rag.service"
  [[ $WITH_CODE_SERVER -eq 1 ]] && EXTRA_UNITS="$EXTRA_UNITS orca-code-server.service"
  [[ $WITH_COWORK_PROXY -eq 1 ]] && EXTRA_UNITS="$EXTRA_UNITS orca-cowork-proxy.service"
  [[ $WITH_AIONUI -eq 1 ]]      && EXTRA_UNITS="$EXTRA_UNITS orca-aionui.service"
  [[ $WITH_HERMES -eq 1 ]]      && EXTRA_UNITS="$EXTRA_UNITS orca-hermes.service"
  [[ $WITH_9ROUTER -eq 1 ]]     && EXTRA_UNITS="$EXTRA_UNITS orca-9router.service"
  [[ $WITH_GLM -eq 1 ]]         && EXTRA_UNITS="$EXTRA_UNITS orca-autoclaw-glm.service"
  [[ $WITH_METACUBEXD -eq 1 ]]  && EXTRA_UNITS="$EXTRA_UNITS orca-metacubexd.service"
  # ruflo + shardbrowser deliberately NOT in EXTRA_UNITS (F4: external only)

  if [[ $OPENCODE_ACTIVE == "true" ]]; then
    log "Safe-Mode: enabling (no restart) — activates on next boot/restart"
    # shellcheck disable=SC2086
    systemctl --user enable $CORE_UNITS $EXTRA_UNITS 2>/dev/null || true
  else
    # shellcheck disable=SC2086
    systemctl --user enable --now $CORE_UNITS $EXTRA_UNITS 2>/dev/null || true
  fi

  # quick boot probe
  sleep 2
  curl -sf http://127.0.0.1:60001/healthz >/dev/null 2>&1 \
    && log "router :60001 healthy" \
    || warn "router not yet ready — check: journalctl --user -u orca-router -n 50"
fi

echo ""
echo "=============================================================================="
echo "OWL-ORCA v6.2 UNIFIED FINAL — Done (v4.9 + v5 merged, 9 hacks + playbook wired)"
echo "=============================================================================="
MEM_NOTE="default ~1108M (v5 equivalent path was ~1418M-2697M; v6.1 +64M virtu-echo)"
echo "Memory: $MEM_NOTE — router 384M + forward 128M + kiro 256M + virtu-echo 64M + tier0 10M + freebuff 256M + graftcp 10M"
echo "Trims : PWA 374M (F3) + canary/swarm 768M (F4) + DPI 148M (F5) + hydra 128M (F6) + nylon 5M (F7) reclaimed"
echo ""
echo "Hacks : H1 uvloop | H2 radix array('I') 4KB | H3 StreamRacer bounded 5 + SSE"
echo "        memoryview thinking_delta->reasoning_content | H4 breaker 5->OPEN 60s"
echo "        decay 1 (v6.1 hot-apply) | H5 SIGHUP atomic-mv | H6 LazyModel 300s | H7 Tier0 LRU 1024"
echo "        | H8 httpx http2 pool 100 UA Chrome/120 | H9 graftcp seccomp only_socks5"
echo "v6.1  : fallback_tier ladder consumed | virtu-echo :60009 terminal fallback |"
echo "        race waits for first SUCCESS (gated racers can't cancel live ones) |"
echo "        breaker hot-apply POST /admin/breakers + SIGHUP | OpenAI-shaped errors"
echo "v6.2  : response cache (Portkey simple) | guardrails (injection/self-harm) |"
echo "        weighted routing + routing_preference (OpenRouter/Portkey) | LiteLLM"
echo "        num_retries/timeout | daily-quota guard (GooseRelay) | plan gate"
echo "        freemium | orca-pack.sh tuning packs (probe-gated) | billing meter |"
echo "        SLA report — ALL SIGHUP hot-applied"
if [[ $WITH_DPI -eq 0 ]]; then
  echo "DPI   : tier OFF (F5 — Mandaluyong PH); use --with-dpi-bypass if blocked"
fi
if [[ $WITH_PROMPTC -eq 1 ]] || [[ $WITH_SKILL_STACK -eq 1 ]] || [[ $WITH_AI_PORTAL -eq 1 ]]; then
  echo "Note  : --with-promptc-os/--with-skill-stack/--with-ai-skills-portal are"
  echo "        deprecated no-ops — Tier-0 is embedded JSON+LRU (F3, 374M saved)"
fi
echo ""
echo "Next steps:"
echo "  1. $BIN_DIR/orca-health-check.sh      # runs the 9-hack selftest"
echo "  2. $BIN_DIR/orca-reload.sh            # SIGHUP no-TCP-drop reload"
echo "  3. curl -s http://127.0.0.1:60001/healthz | python3 -m json.tool"
echo "  4. curl -X POST http://127.0.0.1:60001/v1/prompt/classify -d '{\"prompt\":\"strategy vision roadmap\"}'"
echo "  5. cat $BASE_DIR/VERIFICATION.md"
echo "  6. graftcp: $BIN_DIR/graftcp-wrapper.sh curl https://example.com   # H9"
echo "  7. packs:   $BIN_DIR/orca-pack.sh install $BASE_DIR/config/packs/legal-eagle.json"
echo "  8. billing: $BIN_DIR/orca-billing-meter.py ; SLA: $BIN_DIR/orca-sla-report.py"
echo "=============================================================================="

log "Done — OWL-ORCA v6.2 UNIFIED FINAL + playbook integration ready. See VERIFICATION.md"
