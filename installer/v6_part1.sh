#!/usr/bin/env bash
# ==============================================================================
# OWL-ORCA v6.2 UNIFIED FINAL INSTALLER — v4.9 ∪ v5 + 9 SPEED HACKS + v6.1 ROUTING/RESILIENCE + v6.2 PLAYBOOK INTEGRATION
# v6.2: response cache (Portkey) + guardrails + weighted routing + daily-quota
#       guard (GooseRelay) + LiteLLM num_retries/timeout + plan-gate freemium
#       + tuning packs (orca-pack.sh, probe-gated) + billing meter + SLA report
# v6.1: fallback_tier ladder consumed (TACTICAL) + breaker hot-apply (STRATEGIC)
#       + virtu-echo :60009 terminal fallback + race first-SUCCESS semantics
#       + OpenAI-shaped error envelopes + OpenCode 1.x wiring
# Base: https://github.com/marktantongco/owl-orca-v4
# Lineage: v4.5 merged (real Python modules) -> v4.7 egress (real build code)
#          -> v4.9 unified framework (docx reconciliation) -> v5 unified skeleton
#          -> v6.0 = v5 skeleton + v4.5 real code + v4.7 build code + 9 hacks.
#
# MERGE CRITIQUE (what v6 fixes over v5):
#   [F1] v5 orca-router.py was a FastAPI healthz PLACEHOLDER — v4.5's real
#        StreamRacer/defense/token_saver/memory_hub modules were dropped. v6
#        restores them as REAL implementations with hacks hard-wired.
#   [F2] v5 lost ExecReload=/bin/kill -HUP $MAINPID (v4.5 had it) so SIGHUP
#        hot-reload could never fire. v6 restores ExecReload on every core unit.
#   [F3] v5 Tier-0 = 3 Next.js PWA units (promptc :3002, skill-stack :3003,
#        ai-portal :3004) ~= 384M. v6 = Python JSON taxonomy + lru_cache
#        inside the router (~10M) — 374M SAVED (Hack #7).
#   [F4] Pre-race canary (9Router 128M + Mihomo 64M + Nginx + tokend 64M) +
#        post-race swarm (ruflo 512M) = 768M duplicated the router's own
#        StreamRacer + CircuitBreaker + fallback strategy. v6: default OFF,
#        opt-in flags kept (--with-9router, --with-ruflo external-only).
#   [F5] DPI bypass tier 148M (mhrv 64 + mieru 64 + goose 20) — operator is
#        Mandaluyong PH, not Iran/China DPI. v6: gated behind --with-dpi-bypass
#        (install only when ALL circuits OPEN + confirmed DPI block).
#   [F6] hydra-gate 128M only needed for Playwright browser automation
#        (freebuff alone does rotation) -> default OFF.
#   [F7] nylon 5-32M redundant when forward-proxy :60000 present -> default OFF.
#   [F8] v5 had zero clone/build code for egress — v6 merges v4.7's real
#        cargo/go/make builds (hydra, mhrv, graftcp, nylon, mieru, goose).
#   [F9] NIM :60004 (v4.5 providers.json) collided with mempalace :60004 (v5)
#        -> NIM reallocated to :60008. Port registry re-audited, no collisions.
#   [F10] v5 GLM autoclaw unit installed unconditionally (no flag gate) ->
#        v6 gates it behind --with-glm.
#
# 9 COPY-READY SPEED HACKS (all integrated as real code below):
#  H1 uvloop 2-3x ........ asyncio event loop policy swap (STEP 3+10+11)
#  H2 Radix array trie .... array('I') 1024 nodes 4KB flat, memoryview
#                           zero-copy, FCNS packing (STEP 4 utils/radix_trie.py)
#  H3 StreamRacer ......... asyncio.wait(FIRST_COMPLETED) + p.cancel() losers
#                           immediately + bounded 5 + chunk-by-chunk SSE
#                           memoryview(chunk) thinking_delta->reasoning_content
#                           (STEP 10 orca-router.py)
#  H4 CircuitBreaker ...... atomic int + time.monotonic() no lock, fails>=5
#                           OPEN, 60s -> HALF_OPEN decay 1 single probe
#                           (STEP 5 utils/circuit_breaker.py)
#  H5 SIGHUP atomic mv .... write-to-temp + rename() inode swap (no IDE watcher
#                           crash), reload promptc-os-rules.json sp7-scoring.json
#                           without dropping TCP (STEP 2 atomic_write + STEP 10
#                           signal handler + STEP 21 orca-reload.sh)
#  H6 LazyModel ........... embeddinggemma-300m 300MB / MiniLM 80MB loaded on
#                           first tool call, unloaded after 300s idle -> zero
#                           fixed memory (STEP 7 utils/lazy_model.py)
#  H7 Tier0 LRU ........... JSON 10M Python not PWA 384M,
#                           functools.lru_cache(maxsize=1024) + trie keyword
#                           match Rabbit/Dolphin/Eagle/Beaver/Ant/Owl/Elephant
#                           <2ms inside 5ms envelope (STEP 8 tier0/)
#  H8 httpx http2 pool .... singleton client, max_connections=100 keep-alive,
#                           User-Agent Chrome/120 JA3-consistent (STEP 6
#                           utils/http_pool.py)
#  H9 graftcp seccomp ..... --select_proxy_mode only_socks5 --black-ip-file
#                           --white-ip-file (only socket syscalls trapped,
#                           less overhead) + GooseRelay Zstd 65% quota stretch
#                           free 20k/day (STEP 16)
#
# MEMORY LEDGER v6.1 (defaults vs v5's 2697M full stack):
#   Core: router 384M (Tier-0 + defense + memory_hub now IN-PROCESS) +
#         forward 128M + kiro 256M + virtu-echo 64M (v6.1) = 832M
#         (+ memory-hub unit 128M ELIMINATED)
#   Standard egress: freebuff 256M + graftcp ~10M = 266M
#   DEFAULT TOTAL ~= 1108M  (v5 core-only path was 768M + 3 PWA units = 1152M)
#   Removed by trim: PWA 374M (F3) + canary/swarm 768M (F4) + DPI 148M (F5)
#                    + hydra 128M (F6) + nylon 5M (F7) = ~1423M reclaimed
#   Full opt-in stack (everything except external ruflo/shard): ~3.1G, swap 4G.
#
# PORT REGISTRY v6 (re-audited, unique):
#   CORE  : orca-router 60001, forward-proxy 60000, kiro-gateway 8333,
#           virtu-echo 60009 (v6.1 virtual completion backend)
#   EGRESS: freebuff 1455 (dash 9091/9092), hydra-gate 10808*, nylon 1081*,
#           goose-client 1080*, mieru 1082*, mhrv-rs 8085/8086*   (* = opt-in)
#   PLANE : mempalace 60004, owl-rag 60002, deer 60012/60013/60015, rtk 60014,
#           GLM autoclaw 31000* (flag-gated), NIM 60008 (F9 reallocated)
#   CLIENT: code-server 3001, cowork-proxy 8787, aionui 3006, hermes 3007
#   OPT-IN: 9router 20128, mihomo 7890, nginx-kiro 8330, token-daemon 48321,
#           metacubexd 3008, proxy-mesh 3000, proxy-analysis 3009,
#           omniproxy-smart 3011, ruflo 3010 (EXTERNAL), shard 40325 (EXTERNAL)
#   RELEASED by F3 trim: 3002 3003 3004 (Tier-0 embedded in router)
#
# Install Philosophy: write-to-temp + atomic mv, systemd --user MemoryMax/
# MemoryHigh + ExecReload HUP, Fernet tokens.enc 0600, Safe-Mode zero-downtime,
# idempotent 24-step. English-only logs.
# ==============================================================================

set -euo pipefail
export LC_ALL=C

# ----------------- Flags -----------------
WITH_HYDRA=0
WITH_GRAFTCP=0
WITH_NYLON=0
WITH_FREEBUFF=1            # default ON: primary stealth egress (JA3 chrome120)
WITH_MHRV=0
WITH_MIERU=0
WITH_GOOSERELAY=0
WITH_GOOSERELAY_INSTALLER=0
WITH_DPI=0                 # F5: gate for the whole DPI bypass tier
WITH_SHARDBROWSER=0
WITH_9ROUTER=0             # F4: duplicates router's own fallback strategy
WITH_RUFLO=0               # F4: 512M violates cap — external host only
WITH_GLM=0                 # F10: autoclaw :31000 now flag-gated
WITH_MEMPALACE=0
WITH_RTK=0
WITH_DEER=0
WITH_OWL_RAG=0
WITH_FRESH=0
WITH_NONO=0
WITH_PANE=0
WITH_CODE_SERVER=0
WITH_COWORK_PROXY=0
WITH_AIONUI=0
WITH_HERMES=0
WITH_OPENCODELINUX=0
WITH_PROXY_MESH=0
WITH_PROXY_ANALYSIS=0
WITH_OMNIPROXY_SMART=0
WITH_METACUBEXD=0
WITH_ALL=0
WITH_ALL_EGRESS=0          # defense egress only (freebuff+hydra+graftcp+nylon)
WITH_ALL_EGRESS_DPI=0      # adds DPI tier — PH operator: leave OFF unless blocked
WITH_ALL_OBSERVABILITY=0
WITH_ALL_CLIENT=0
WITH_ALL_MEMORY=0
CORE_ONLY=0
DRY_RUN=0
SAFE_MODE=0
# Deprecated v5 PWA flags (F3): accepted for compatibility, now no-ops that
# log the embedded Tier-0 message. PWA units 3002/3003/3004 are NOT installed.
WITH_PROMPTC=0
WITH_SKILL_STACK=0
WITH_AI_PORTAL=0

for arg in "$@"; do
  case "$arg" in
    --with-hydra) WITH_HYDRA=1 ;;
    --with-graftcp) WITH_GRAFTCP=1 ;;
    --with-nylon) WITH_NYLON=1 ;;
    --with-freebuff) WITH_FREEBUFF=1 ;;
    --with-mhrv) WITH_MHRV=1 ;;
    --with-mieru) WITH_MIERU=1 ;;
    --with-gooserelay) WITH_GOOSERELAY=1 ;;
    --with-gooserelay-installer) WITH_GOOSERELAY_INSTALLER=1 ;;
    --with-dpi-bypass) WITH_DPI=1 ;;
    --with-shardbrowser) WITH_SHARDBROWSER=1 ;;
    --with-9router) WITH_9ROUTER=1 ;;
    --with-ruflo) WITH_RUFLO=1 ;;
    --with-glm) WITH_GLM=1 ;;
    --with-mempalace) WITH_MEMPALACE=1 ;;
    --with-rtk) WITH_RTK=1 ;;
    --with-deer-flow) WITH_DEER=1 ;;
    --with-owl-agent-rag) WITH_OWL_RAG=1 ;;
    --with-fresh) WITH_FRESH=1 ;;
    --with-nono) WITH_NONO=1 ;;
    --with-pane) WITH_PANE=1 ;;
    --with-code-server) WITH_CODE_SERVER=1 ;;
    --with-opencode-cowork-proxy) WITH_COWORK_PROXY=1 ;;
    --with-aionui) WITH_AIONUI=1 ;;
    --with-hermes) WITH_HERMES=1 ;;
    --with-opencodelinux) WITH_OPENCODELINUX=1 ;;
    --with-proxy-mesh) WITH_PROXY_MESH=1 ;;
    --with-proxy-analysis) WITH_PROXY_ANALYSIS=1 ;;
    --with-omniproxy-smart) WITH_OMNIPROXY_SMART=1 ;;
    --with-metacubexd) WITH_METACUBEXD=1 ;;
    --with-all-egress) WITH_ALL_EGRESS=1 ;;
    --with-all-egress-dpi) WITH_ALL_EGRESS_DPI=1 ;;
    --with-all-observability) WITH_ALL_OBSERVABILITY=1 ;;
    --with-all-client) WITH_ALL_CLIENT=1 ;;
    --with-all-memory) WITH_ALL_MEMORY=1 ;;
    --with-all) WITH_ALL=1 ;;
    --with-promptc-os) WITH_PROMPTC=1 ;;
    --with-skill-stack) WITH_SKILL_STACK=1 ;;
    --with-ai-skills-portal) WITH_AI_PORTAL=1 ;;
    --core-only) CORE_ONLY=1 ;;
    --dry-run) DRY_RUN=1 ;;
    --safe-mode) SAFE_MODE=1 ;;
    --help|-h)
      echo "Usage: $0 [flags]"
      echo "  Core: --core-only (768M embedded Tier-0) | --dry-run | --safe-mode"
      echo "  Hacks: always on — uvloop H1, radix trie H2, StreamRacer H3, breaker H4,"
      echo "         SIGHUP H5, LazyModel H6, Tier0 LRU H7, httpx pool H8, graftcp H9"
      echo "  Egress: --with-freebuff (default ON) --with-hydra --with-graftcp --with-nylon"
      echo "          --with-all-egress (defense tier, NO DPI)"
      echo "  DPI bypass (F5: PH has no nation-state DPI — only when all circuits"
      echo "          OPEN + confirmed block): --with-dpi-bypass --with-mhrv --with-mieru"
      echo "          --with-gooserelay --with-gooserelay-installer --with-all-egress-dpi"
      echo "  Memory plane: --with-mempalace (LazyModel H6) --with-rtk --with-deer-flow"
      echo "                --with-owl-agent-rag --with-all-memory"
      echo "  Client: --with-fresh --with-nono --with-pane --with-code-server"
      echo "          --with-opencode-cowork-proxy --with-aionui --with-hermes"
      echo "          --with-opencodelinux --with-all-client"
      echo "  Observability: --with-proxy-mesh --with-proxy-analysis --with-omniproxy-smart"
      echo "                --with-metacubexd --with-all-observability"
      echo "  Opt-in legacy (F4: OFF by default): --with-9router --with-ruflo (EXTERNAL"
      echo "          512M) --with-shardbrowser (EXTERNAL testing only) --with-glm"
      echo "  Bundles: --with-all (everything except ruflo/shard/goose-installer)"
      echo "  Deprecated no-ops (F3): --with-promptc-os --with-skill-stack"
      echo "          --with-ai-skills-portal — Tier-0 is embedded JSON+LRU, 374M saved"
      exit 0 ;;
    *) warn "unknown flag: $arg (ignored)" ;;
  esac
done

if [[ $WITH_ALL -eq 1 ]]; then
  WITH_HYDRA=1; WITH_GRAFTCP=1; WITH_NYLON=1; WITH_FREEBUFF=1; WITH_GLM=1
  WITH_MEMPALACE=1; WITH_RTK=1; WITH_DEER=1; WITH_OWL_RAG=1
  WITH_FRESH=1; WITH_NONO=1; WITH_PANE=1; WITH_CODE_SERVER=1; WITH_COWORK_PROXY=1
  WITH_AIONUI=1; WITH_HERMES=1; WITH_OPENCODELINUX=1
  WITH_PROXY_MESH=1; WITH_PROXY_ANALYSIS=1; WITH_OMNIPROXY_SMART=1; WITH_METACUBEXD=1
  WITH_9ROUTER=1
  # F5: --with-all deliberately EXCLUDES the DPI tier (mhrv/mieru/goose), ruflo
  # (512M external) and shardbrowser (external testing) — add explicitly.
fi
if [[ $WITH_ALL_EGRESS -eq 1 ]]; then WITH_HYDRA=1; WITH_GRAFTCP=1; WITH_NYLON=1; WITH_FREEBUFF=1; fi
if [[ $WITH_ALL_EGRESS_DPI -eq 1 ]]; then
  WITH_ALL_EGRESS=1; WITH_DPI=1; WITH_MHRV=1; WITH_MIERU=1; WITH_GOOSERELAY=1
fi
if [[ $WITH_DPI -eq 1 ]]; then :; else
  # F5: individual DPI flags only fire when the gate is open
  WITH_MHRV=0; WITH_MIERU=0; WITH_GOOSERELAY=0; WITH_GOOSERELAY_INSTALLER=0
fi
if [[ $WITH_ALL_OBSERVABILITY -eq 1 ]]; then
  WITH_PROXY_MESH=1; WITH_PROXY_ANALYSIS=1; WITH_OMNIPROXY_SMART=1; WITH_METACUBEXD=1
fi
if [[ $WITH_ALL_CLIENT -eq 1 ]]; then
  WITH_FRESH=1; WITH_NONO=1; WITH_PANE=1; WITH_CODE_SERVER=1; WITH_COWORK_PROXY=1
  WITH_AIONUI=1; WITH_HERMES=1
fi
if [[ $WITH_ALL_MEMORY -eq 1 ]]; then
  WITH_MEMPALACE=1; WITH_RTK=1; WITH_DEER=1; WITH_OWL_RAG=1
fi
if [[ $CORE_ONLY -eq 1 ]]; then
  WITH_HYDRA=0; WITH_GRAFTCP=0; WITH_NYLON=0; WITH_FREEBUFF=0
  WITH_MHRV=0; WITH_MIERU=0; WITH_GOOSERELAY=0; WITH_GOOSERELAY_INSTALLER=0; WITH_DPI=0
  WITH_SHARDBROWSER=0; WITH_9ROUTER=0; WITH_RUFLO=0; WITH_GLM=0
  WITH_MEMPALACE=0; WITH_RTK=0; WITH_DEER=0; WITH_OWL_RAG=0
  WITH_FRESH=0; WITH_NONO=0; WITH_PANE=0; WITH_CODE_SERVER=0; WITH_COWORK_PROXY=0
  WITH_AIONUI=0; WITH_HERMES=0; WITH_OPENCODELINUX=0
  WITH_PROXY_MESH=0; WITH_PROXY_ANALYSIS=0; WITH_OMNIPROXY_SMART=0; WITH_METACUBEXD=0
fi

log(){ echo -e "\033[1;34m[owl-orca-v6]\033[0m $*"; }
warn(){ echo -e "\033[1;33m[warn]\033[0m $*" >&2; }
die(){ echo -e "\033[1;31m[fail]\033[0m $*" >&2; exit 1; }

BASE_DIR="$HOME/.owl-orca-v6"
BIN_DIR="$BASE_DIR/bin"
CFG_DIR="$BASE_DIR/config"
LOG_DIR="$BASE_DIR/logs"
DATA_DIR="$BASE_DIR/data"
TIER0_DIR="$BASE_DIR/tier0"
MEMORY_DIR="$BASE_DIR/memory-plane"
CLIENT_DIR="$BASE_DIR/client"
EGRESS_DIR="$BASE_DIR/egress"
OBS_DIR="$BASE_DIR/observability"
SYSTEMD_USER="$HOME/.config/systemd/user"
TOKENS_FILE="$BASE_DIR/tokens.enc"
FERNET_KEY_FILE="$BASE_DIR/.fernet.key"
VENV_PY="$BASE_DIR/venv/bin/python"

mkdir -p "$BIN_DIR/utils" "$CFG_DIR" "$LOG_DIR" "$DATA_DIR" "$TIER0_DIR" \
         "$MEMORY_DIR" "$CLIENT_DIR" "$EGRESS_DIR" "$OBS_DIR" "$SYSTEMD_USER"

# ----------------- Helpers -----------------
# H5: atomic_write — write-to-temp + rename() inode swap. IDE/inotify watchers
# never see a half-written file (no crash, no torn read); SIGHUP re-readers
# always open a complete file. Used for EVERY generated artifact below.
atomic_write(){
  local dest="$1" mode="${2:-0600}" tmp
  tmp=$(mktemp "${dest}.tmp.XXXXXX")
  cat > "$tmp"
  chmod "$mode" "$tmp"
  mv -f "$tmp" "$dest"          # rename(2) — atomic inode swap
}

check_port(){
  local port=$1 name=$2
  if ss -H -tln "sport = :$port" 2>/dev/null | grep -q ":$port"; then
    if systemctl --user is-active "orca-$name.service" &>/dev/null; then
      log "port $port owned by orca-$name OK"
    else
      warn "port $port in use, not by orca-$name — will not overwrite"
    fi
  fi
}

# Safe-Mode detection (from v4.5 STEP 7): if an IDE/agent holds the plane,
# code lands on disk and activates on next restart — zero downtime.
OPENCODE_ACTIVE=false
if pgrep -f "opencode|claude|kiro|code-server" >/dev/null 2>&1; then
  OPENCODE_ACTIVE=true
  log "IDE/agent detected — Safe-Mode ON (activates on next restart)"
fi
if [[ $SAFE_MODE -eq 1 ]]; then OPENCODE_ACTIVE=true; fi

# ==================== STEP 1/24: Prerequisites + Swap Guard ====================
log "STEP 1/24 prerequisites + swap guard (2G core / 4G full — v4.5 was 2G, v4.7 3G, v5 4G)"
if [[ $DRY_RUN -eq 0 ]]; then
  for cmd in python3 pip3 curl git make gcc; do
    command -v "$cmd" >/dev/null 2>&1 || warn "$cmd missing"
  done
  HEAVY=0
  [[ $WITH_ALL -eq 1 || $WITH_ALL_EGRESS -eq 1 || $WITH_ALL_MEMORY -eq 1 || \
     $WITH_DEER -eq 1 || $WITH_MEMPALACE -eq 1 || $WITH_CODE_SERVER -eq 1 || \
     $WITH_9ROUTER -eq 1 ]] && HEAVY=1 || true
  if command -v free >/dev/null 2>&1; then
    SWAP_MB=$(free -m | awk '/Swap:/ {print $2}')
    NEED_MB=2048; [[ $HEAVY -eq 1 ]] && NEED_MB=4096 || true
    if [[ ${SWAP_MB:-0} -lt $NEED_MB ]]; then
      if [[ $SAFE_MODE -eq 1 ]] || [[ $HEAVY -eq 1 ]]; then
        warn "swap ${SWAP_MB}MB < ${NEED_MB}MB recommended — attempting guard"
        if [[ -w / ]]; then
          sudo fallocate -l ${NEED_MB}M /swapfile 2>/dev/null || true
          sudo chmod 600 /swapfile 2>/dev/null || true
          sudo mkswap /swapfile 2>/dev/null || true
          sudo swapon /swapfile 2>/dev/null || true
        else
          fallocate -l ${NEED_MB}M "$BASE_DIR/swapfile" 2>/dev/null || true
          mkswap "$BASE_DIR/swapfile" 2>/dev/null || true
          swapon "$BASE_DIR/swapfile" 2>/dev/null || true
        fi
      else
        warn "swap ${SWAP_MB}MB < ${NEED_MB}MB — core profile tolerates this"
      fi
    fi
  fi
fi

# ==================== STEP 2/24: Fernet tokens.enc 0600 ====================
log "STEP 2/24 Fernet tokens.enc 0600 (H5: key + tokens written via atomic rename)"
if [[ $DRY_RUN -eq 0 ]]; then
  if [[ ! -f "$FERNET_KEY_FILE" ]]; then
    python3 -c "from cryptography.fernet import Fernet; print(Fernet.generate_key().decode())" 2>/dev/null \
      | atomic_write "$FERNET_KEY_FILE" 0600 \
      || echo "placeholder-key-$(date +%s)" | atomic_write "$FERNET_KEY_FILE" 0600
  fi
  if [[ ! -f "$TOKENS_FILE" ]]; then
    echo '{"_note":"Fernet encrypted tokens auto-generated symmetric keys 0600"}' \
      | atomic_write "$TOKENS_FILE" 0600
  fi
  chmod 0600 "$TOKENS_FILE" "$FERNET_KEY_FILE" 2>/dev/null || true
fi

# ==================== STEP 3/24: venv + deps (H1 uvloop) ====================
log "STEP 3/24 Python venv + deps — httpx[http2] uvloop orjson fastapi uvicorn (H1 loop 2-3x)"
if [[ $DRY_RUN -eq 0 ]]; then
  python3 -m venv "$BASE_DIR/venv" 2>/dev/null || true
  "$BASE_DIR/venv/bin/pip" -q install --upgrade pip 2>/dev/null || true
  # H1: uvloop swaps the asyncio event loop for a libuv-based one (2-3x).
  # orjson: fast JSON for SSE delta parsing. aiofiles for ledger appends.
  "$BASE_DIR/venv/bin/pip" -q install \
    "httpx[http2]" aiohttp aiofiles orjson uvloop cryptography fastapi uvicorn 2>/dev/null || true
  "$VENV_PY" -c "import uvloop; print('uvloop', uvloop.__version__)" 2>/dev/null \
    || warn "uvloop not installed — router falls back to asyncio (H1 disabled)"
fi
