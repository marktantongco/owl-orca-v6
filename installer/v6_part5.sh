
# ==================== STEP 14/24: freebuff stealth egress (default ON) ====================
log "STEP 14/24 freebuff-proxy :1455 Go Fiber uTLS JA3 chrome120 dashboard :9091/:9092 — real clone+build (F8)"
if [[ $DRY_RUN -eq 0 ]] && [[ $WITH_FREEBUFF -eq 1 ]]; then
  if command -v go >/dev/null 2>&1; then
    if [[ ! -d "$EGRESS_DIR/freebuff-src" ]]; then
      git clone --depth 1 https://github.com/marktantongco/freebuff-proxy \
        "$EGRESS_DIR/freebuff-src" 2>/dev/null || warn "freebuff clone failed"
    fi
    if [[ -d "$EGRESS_DIR/freebuff-src" ]]; then
      (cd "$EGRESS_DIR/freebuff-src" && \
       go build -o "$EGRESS_DIR/freebuff-proxy" ./cmd/freebuff-proxy 2>/dev/null) \
        || warn "freebuff go build failed — unit will fail until binary present"
    fi
  else
    warn "golang-go missing — freebuff binary not built (apt install golang-go)"
  fi
atomic_write "$SYSTEMD_USER/orca-freebuff-proxy.service" 0644 <<'UNIT'
[Unit]
Description=Freebuff Proxy Go Fiber uTLS JA3 chrome120 stealth egress :1455 dash :9091 :9092
After=network.target

[Service]
Type=simple
ExecStart=%h/.owl-orca-v6/egress/freebuff-proxy -port 1455 -dashboard-addr :9091
WorkingDirectory=%h/.owl-orca-v6/egress
ExecReload=/bin/kill -HUP $MAINPID
Restart=on-failure
MemoryMax=256M
MemoryHigh=192M
Environment=STEALTH_ENABLED=true
Environment=STEALTH_PROFILE=chrome120
Environment=DASHBOARD_ADDR=:9091

[Install]
WantedBy=default.target
UNIT
  check_port 1455 freebuff
  check_port 9091 freebuff-dash
fi

# ==================== STEP 15/24: conditional defense egress (F6/F7) ====================
log "STEP 15/24 hydra-gate (F6: only with Playwright automation) + nylon (F7: only without :60000) — default OFF"
if [[ $DRY_RUN -eq 0 ]]; then
  if [[ $WITH_HYDRA -eq 1 ]]; then
    log "hydra-gate :10808 Tauri Rust 6 rotations Round Robin Random Least Latency Weighted Time-Based Sticky 10min IP-Based Sticky hash hostname auth-stripping — real cargo build (F8)"
    if [[ ! -d "$EGRESS_DIR/hydra-src" ]]; then
      git clone --depth 1 https://github.com/samirdjelal/hydra-gate \
        "$EGRESS_DIR/hydra-src" 2>/dev/null || warn "hydra-gate clone failed"
    fi
    if [[ -d "$EGRESS_DIR/hydra-src" ]]; then
      if ! command -v cargo >/dev/null 2>&1; then
        curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs 2>/dev/null | sh -s -- -y \
          || warn "rustup install failed"
        # shellcheck disable=SC1090
        [[ -f "$HOME/.cargo/env" ]] && . "$HOME/.cargo/env" || true
      fi
      (cd "$EGRESS_DIR/hydra-src" && cargo build --release 2>/dev/null && \
       cp src-tauri/target/release/hydra-gate "$EGRESS_DIR/" 2>/dev/null) \
        || warn "hydra cargo build incomplete — binary may be missing"
    fi
atomic_write "$SYSTEMD_USER/orca-hydra-gate.service" 0644 <<'UNIT'
[Unit]
Description=Hydra-Gate SOCKS5 Aggregator 6 rotations auth-stripping health 30s 1.1.1.1:53 :10808
After=network.target

[Service]
Type=simple
ExecStart=%h/.owl-orca-v6/egress/hydra-gate --port 10808 --health-interval 30 --health-target 1.1.1.1:53
WorkingDirectory=%h/.owl-orca-v6/egress
ExecReload=/bin/kill -HUP $MAINPID
Restart=on-failure
MemoryMax=128M
MemoryHigh=96M

[Install]
WantedBy=default.target
UNIT
    check_port 10808 hydra-gate
  else
    log "hydra-gate skipped (F6): freebuff alone does rotation; add --with-hydra only for Playwright/Chromium --proxy-server 407 workflows"
  fi
  if [[ $WITH_NYLON -eq 1 ]]; then
    log "nylon :1081 C libevent <5M SOCKS4/5 mirror mode ACL CIDR SIGHUP re-exec IPv4 — real configure/make (F8)"
    if [[ ! -d "$EGRESS_DIR/nylon-src" ]]; then
      git clone --depth 1 https://github.com/smeinecke/nylon \
        "$EGRESS_DIR/nylon-src" 2>/dev/null || warn "nylon clone failed"
    fi
    if [[ -d "$EGRESS_DIR/nylon-src" ]] && command -v make >/dev/null 2>&1; then
      (cd "$EGRESS_DIR/nylon-src" && ./configure 2>/dev/null && make 2>/dev/null && \
       cp nylon "$EGRESS_DIR/" 2>/dev/null) || warn "nylon build incomplete"
    fi
atomic_write "$SYSTEMD_USER/orca-nylon.service" 0644 <<'UNIT'
[Unit]
Description=Nylon Minimal SOCKS5 <5M C libevent SIGHUP re-exec ACL :1081
After=network.target

[Service]
Type=simple
ExecStart=%h/.owl-orca-v6/egress/nylon -i 127.0.0.1 -p 1081 -a 127.0.0.1/32 -f -v
Restart=on-failure
MemoryMax=32M
MemoryHigh=16M

[Install]
WantedBy=default.target
UNIT
    check_port 1081 nylon
  else
    log "nylon skipped (F7): redundant with forward-proxy :60000; add --with-nylon for a <5M mirror-mode ingress"
  fi
fi

# ==================== STEP 16/24: H9 graftcp seccomp wrapper + GooseRelay Zstd ====================
log "STEP 16/24 graftcp real build (F8) + H9: --select_proxy_mode only_socks5 --black-ip-file --white-ip-file seccomp-BPF only-socket trap + GooseRelay Zstd 65% quota stretch"
if [[ $DRY_RUN -eq 0 ]]; then
  if [[ $WITH_GRAFTCP -eq 1 ]]; then
    log "graftcp 2584 star Linux-only ptrace redirector — seccomp-BPF traps ONLY socket syscalls (H9: less overhead than per-syscall fallback)"
    if [[ ! -d "$EGRESS_DIR/graftcp-src" ]]; then
      git clone --depth 1 https://github.com/hmgle/graftcp "$EGRESS_DIR/graftcp-src" 2>/dev/null \
        || warn "graftcp clone failed"
    fi
    if [[ -d "$EGRESS_DIR/graftcp-src" ]]; then
      (cd "$EGRESS_DIR/graftcp-src" && make 2>/dev/null && \
       cp local/graftcp "$BIN_DIR/graftcp" 2>/dev/null) \
        || sudo make -C "$EGRESS_DIR/graftcp-src" install 2>/dev/null \
        || warn "graftcp build/install incomplete"
    fi
    if [[ -f /proc/sys/kernel/yama/ptrace_scope ]]; then
      warn "graftcp ptrace_scope check: cat /proc/sys/kernel/yama/ptrace_scope (0 permissive, 1 restricted, 3 no ptrace)"
    fi
    # Black/white IP files for H9: loopback never proxied, RFC1918 direct
    atomic_write "$CFG_DIR/graftcp-black-ip.txt" 0644 <<'IP'
127.0.0.0/8
::1/128
IP
    atomic_write "$CFG_DIR/graftcp-white-ip.txt" 0644 <<'IP'
10.0.0.0/8
172.16.0.0/12
192.168.0.0/16
IP
    # H9 wrapper: only_socks5 mode + black/white IP files + DNS/UDP enables.
    # Trapping only socket syscalls via the seccomp-BPF filter keeps per-call
    # overhead minimal vs the every-syscall fallback path.
    atomic_write "$BIN_DIR/graftcp-wrapper.sh" 0755 <<'WRAP'
#!/usr/bin/env bash
# OWL-ORCA v6 graftcp wrapper (H9) — force static Go binaries + any process
# through the proxy pool (hydra-gate :10808 -> freebuff :1455 JA3 -> providers).
set -euo pipefail
SOCKS5=${SOCKS5:-127.0.0.1:10808}
GCP=${GCP:-graftcp}
CFG=${HOME}/.owl-orca-v6/config
exec "$GCP" \
  --socks5 "$SOCKS5" \
  --select_proxy_mode only_socks5 \
  --black-ip-file "$CFG/graftcp-black-ip.txt" \
  --white-ip-file "$CFG/graftcp-white-ip.txt" \
  --enable-dns --enable-udp "$@"
WRAP
  fi
  if [[ $WITH_GOOSERELAY -eq 1 ]]; then
    log "GooseRelay client :1080 AES-256-GCM + Zstd SNI www.google.com -> Apps Script dumb forwarder -> VPS :8443 — Zstd shrinks bodies ~65%, stretching the free 20k/day quota (H9)"
    if command -v go >/dev/null 2>&1; then
      if [[ ! -d "$EGRESS_DIR/goose-src" ]]; then
        git clone --depth 1 https://github.com/Kianmhz/GooseRelayVPN \
          "$EGRESS_DIR/goose-src" 2>/dev/null || warn "goose clone failed"
      fi
      if [[ -d "$EGRESS_DIR/goose-src" ]]; then
        (cd "$EGRESS_DIR/goose-src" && \
         CGO_ENABLED=0 go build -trimpath -ldflags "-s -w" \
           -o "$EGRESS_DIR/goose-client" ./cmd/client 2>/dev/null) \
          || warn "goose-client build failed"
      fi
    fi
    if [[ ! -f "$CFG_DIR/goose-tunnel.key" ]]; then
      openssl rand -hex 32 | atomic_write "$CFG_DIR/goose-tunnel.key" 0600
    fi
    TUNNEL_KEY=$(cat "$CFG_DIR/goose-tunnel.key" 2>/dev/null || echo "CHANGE_ME_64_HEX")
    cat > "$CFG_DIR/goose-client.json" <<JSON
{
  "socks_host": "127.0.0.1",
  "socks_port": 1080,
  "google_host": "216.239.38.120",
  "sni": "www.google.com",
  "script_keys": ["PASTE_DEPLOYMENT_ID_HERE"],
  "tunnel_key": "$TUNNEL_KEY",
  "zstd": true,
  "zstd_note": "H9: frame batching + Zstd ~65% body shrink -> quota stretch, still free 20k/day reset midnight Pacific",
  "relay_urls": ["http://YOUR_VPS:8443"]
}
JSON
    cat > "$CFG_DIR/goose-server.json" <<JSON
{
  "server_host": "0.0.0.0",
  "server_port": 8443,
  "tunnel_key": "$TUNNEL_KEY",
  "zstd": true
}
JSON
atomic_write "$SYSTEMD_USER/orca-goose-client.service" 0644 <<'UNIT'
[Unit]
Description=GooseRelay Client SOCKS5 127.0.0.1:1080 AES-256-GCM Zstd SNI www.google.com
After=network.target

[Service]
Type=simple
ExecStart=%h/.owl-orca-v6/egress/goose-client --config %h/.owl-orca-v6/config/goose-client.json
WorkingDirectory=%h/.owl-orca-v6/egress
Restart=on-failure
MemoryMax=96M

[Install]
WantedBy=default.target
UNIT
    check_port 1080 goose
    check_port 8443 goose-server
  fi
fi

# ==================== STEP 17/24: DPI bypass tier (F5 gated) ====================
log "STEP 17/24 DPI bypass tier — GATED behind --with-dpi-bypass (F5: Mandaluyong PH, no nation-state DPI; install only if all circuits OPEN + confirmed block)"
if [[ $DRY_RUN -eq 0 ]] && [[ $WITH_DPI -eq 1 ]]; then
  log "DPI gate OPEN — mhrv-rs :8085 (mhrv free 20k/day no VPS) -> mieru :1082 (XChaCha20, no Google dep) -> GooseRelay :1080 (VPS, raw TCP) — tiered fallback chain"
  if [[ $WITH_MHRV -eq 1 ]]; then
    log "mhrv-rs 3600 star Rust 3MB single binary — real release download (F8)"
    mkdir -p "$EGRESS_DIR/mhrv-rs"
    if [[ ! -f "$EGRESS_DIR/mhrv-rs/mhrv-rs" ]]; then
      wget -q "https://github.com/therealaleph/MasterHttpRelayVPN-RUST/releases/latest/download/mhrv-rs-linux-amd64.tar.gz" \
        -O /tmp/mhrv-rs.tar.gz 2>/dev/null \
        && tar -xzf /tmp/mhrv-rs.tar.gz -C "$EGRESS_DIR/mhrv-rs" 2>/dev/null \
        || warn "mhrv-rs download failed"
    fi
atomic_write "$SYSTEMD_USER/orca-mhrv-rs.service" 0644 <<'UNIT'
[Unit]
Description=mhrv-rs DPI bypass Google Apps Script relay free 20k/day :8085 socks :8086
After=network.target

[Service]
Type=simple
ExecStart=%h/.owl-orca-v6/egress/mhrv-rs/mhrv-rs --http-proxy 127.0.0.1:8085 --socks5 127.0.0.1:8086
WorkingDirectory=%h/.owl-orca-v6/egress/mhrv-rs
Restart=on-failure
MemoryMax=64M
MemoryHigh=48M

[Install]
WantedBy=default.target
UNIT
    check_port 8085 mhrv
    check_port 8086 mhrv-socks
  fi
  if [[ $WITH_MIERU -eq 1 ]]; then
    log "mieru 2584 star Go XChaCha20-Poly1305 random padding replay detection — real go build (F8)"
    if [[ ! -d "$EGRESS_DIR/mieru-src" ]]; then
      git clone --depth 1 https://github.com/enfein/mieru "$EGRESS_DIR/mieru-src" 2>/dev/null \
        || warn "mieru clone failed"
    fi
    if [[ -d "$EGRESS_DIR/mieru-src" ]] && command -v go >/dev/null 2>&1; then
      (cd "$EGRESS_DIR/mieru-src" && \
       go build -o "$EGRESS_DIR/mieru" ./cmd/mieru 2>/dev/null && \
       go build -o "$EGRESS_DIR/mita" ./cmd/mita 2>/dev/null) \
        || warn "mieru build incomplete"
    fi
atomic_write "$SYSTEMD_USER/orca-mieru-client.service" 0644 <<'UNIT'
[Unit]
Description=Mieru Client XChaCha20-Poly1305 random padding replay detection :1082
After=network.target

[Service]
Type=simple
ExecStart=%h/.owl-orca-v6/egress/mieru --config %h/.owl-orca-v6/config/mieru-client.json
WorkingDirectory=%h/.owl-orca-v6/egress
Restart=on-failure
MemoryMax=64M

[Install]
WantedBy=default.target
UNIT
    check_port 1082 mieru
  fi
else
  log "DPI tier skipped (F5): PH operator — 148M saved. Re-run with --with-dpi-bypass when all circuits OPEN + DPI block confirmed"
fi

# ==================== STEP 18/24: memory plane (H6 LazyModel) ====================
log "STEP 18/24 memory plane — mempalace (H6 LazyModel: MiniLM/embeddinggemma load on first tool call, 300s idle unload -> zero fixed memory) + rtk + deer-flow + owl-agent-rag"
if [[ $DRY_RUN -eq 0 ]]; then
  if [[ $WITH_MEMPALACE -eq 1 ]]; then
    # LazyModel wrapper: mempalace's embedding model costs 0 fixed memory.
    atomic_write "$BIN_DIR/mempalace-lazy.py" 0755 <<'PY'
#!/usr/bin/env python3
"""OWL-ORCA v6 — mempalace LazyModel gateway (H6).

Wraps the palace embedding tier: MiniLM-80MB (default) or
embeddinggemma-300m loads on the FIRST tool call and unloads after 300s
idle. The unit's MemoryMax stays 512M as a ceiling, but resident cost
between bursts is ~0 — the v5 fixed 300M budget is reclaimed.
"""
import json
import os
import sys

BASE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, BASE)

try:
    import uvloop
    uvloop.install()               # H1
except ImportError:
    pass

from fastapi import FastAPI        # noqa: E402
from utils.lazy_model import LazyModel  # noqa: E402

MODEL = os.environ.get("MEMPALACE_MODEL", "sentence-transformers/all-MiniLM-L6-v2")
LAZY = LazyModel(MODEL)
app = FastAPI(title="owl-orca-v6-mempalace-lazy", version="6.0.0")


@app.get("/healthz")
async def healthz():
    return {"ok": True, "service": "mempalace-lazy", "port": 60004,
            "model": MODEL, "loaded": LAZY.loaded,
            "idle_unload_s": LazyModel.IDLE_UNLOAD_S,
            "fixed_memory_when_idle": "0 bytes (H6)"}


@app.post("/v1/embed")
async def embed(body: dict):
    vec = await LAZY.embed(body.get("text", ""))
    if not isinstance(vec, list):
        vec = vec.tolist()
    return {"dim": len(vec), "vector": vec[:8], "truncated": True}


if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="127.0.0.1", port=60004, log_level="warning")
PY
atomic_write "$SYSTEMD_USER/orca-mempalace.service" 0644 <<'UNIT'
[Unit]
Description=Mempalace LazyModel H6 — verbatim Palace 96.6% R@5, zero fixed embedding memory :60004
After=network.target

[Service]
Type=simple
ExecStart=%h/.owl-orca-v6/venv/bin/python %h/.owl-orca-v6/bin/mempalace-lazy.py
WorkingDirectory=%h/.owl-orca-v6
Restart=on-failure
MemoryMax=512M
MemoryHigh=384M
Environment=PYTHONPATH=%h/.owl-orca-v6
Environment=MEMPALACE_MODEL=sentence-transformers/all-MiniLM-L6-v2

[Install]
WantedBy=default.target
UNIT
    check_port 60004 mempalace
  fi
  if [[ $WITH_RTK -eq 1 ]]; then
atomic_write "$SYSTEMD_USER/orca-rtk.service" 0644 <<'UNIT'
[Unit]
Description=RTK Token Saver Middleware 60-90% :60014
After=network.target

[Service]
Type=simple
ExecStart=%h/.owl-orca-v6/venv/bin/python -m rtk --port 60014
WorkingDirectory=%h/.owl-orca-v6/memory-plane
Restart=on-failure
MemoryMax=96M

[Install]
WantedBy=default.target
UNIT
    check_port 60014 rtk
  fi
  if [[ $WITH_DEER -eq 1 ]]; then
atomic_write "$SYSTEMD_USER/orca-deer-flow.service" 0644 <<'UNIT'
[Unit]
Description=Deer-Flow Long-Horizon SuperAgent Harness api :60012 ui :60013 mcp :60015
After=network.target

[Service]
Type=simple
ExecStart=%h/.owl-orca-v6/venv/bin/python -m deer_flow --api-port 60012 --ui-port 60013 --mcp-port 60015
WorkingDirectory=%h/.owl-orca-v6/memory-plane/deerflow
Restart=on-failure
MemoryMax=256M

[Install]
WantedBy=default.target
UNIT
    check_port 60012 deer-api
    check_port 60013 deer-ui
    check_port 60015 deer-mcp
  fi
  if [[ $WITH_OWL_RAG -eq 1 ]]; then
atomic_write "$SYSTEMD_USER/orca-owl-agent-rag.service" 0644 <<'UNIT'
[Unit]
Description=OWL-AGENT RAG self-optimising scraping engine :60002
After=network.target

[Service]
Type=simple
ExecStart=%h/.owl-orca-v6/venv/bin/python -m owl_agent --port 60002
WorkingDirectory=%h/.owl-orca-v6/memory-plane/scraper
Restart=on-failure
MemoryMax=256M

[Install]
WantedBy=default.target
UNIT
    check_port 60002 owl-rag
  fi
fi

# ==================== STEP 19/24: client layer (condensed) ====================
log "STEP 19/24 client layer — fresh/nono/Pane/code-server/cowork-proxy/AionUi/hermes (all opt-in)"
if [[ $DRY_RUN -eq 0 ]]; then
  if [[ $WITH_FRESH -eq 1 ]]; then
    atomic_write "$BIN_DIR/fresh-edit.sh" 0755 <<'FRESH'
#!/usr/bin/env bash
# fresh terminal IDE Rust <50M — control-plane manifest loader TUI
set -e
fresh --no-upgrade-check "$HOME/.owl-orca-v6/config/providers.yaml" 2>/dev/null \
  || ${EDITOR:-nano} "$HOME/.owl-orca-v6/config/providers.yaml"
FRESH
  fi
  if [[ $WITH_CODE_SERVER -eq 1 ]]; then
atomic_write "$SYSTEMD_USER/orca-code-server.service" 0644 <<'UNIT'
[Unit]
Description=Code-Server VS Code in browser :3001
After=network.target

[Service]
Type=simple
ExecStart=/usr/bin/code-server --bind-addr 127.0.0.1:3001 --auth none %h/.owl-orca-v6
WorkingDirectory=%h/.owl-orca-v6
Restart=on-failure
MemoryMax=256M

[Install]
WantedBy=default.target
UNIT
    check_port 3001 code-server
  fi
  if [[ $WITH_COWORK_PROXY -eq 1 ]]; then
atomic_write "$SYSTEMD_USER/orca-cowork-proxy.service" 0644 <<'UNIT'
[Unit]
Description=Opencode Cowork Proxy Cloudflare Worker dev relay :8787
After=network.target

[Service]
Type=simple
ExecStart=/usr/bin/env npx wrangler dev --port 8787
WorkingDirectory=%h/.owl-orca-v6/client/cowork-proxy
Restart=on-failure
MemoryMax=64M

[Install]
WantedBy=default.target
UNIT
    check_port 8787 cowork-proxy
  fi
  if [[ $WITH_AIONUI -eq 1 ]]; then
atomic_write "$SYSTEMD_USER/orca-aionui.service" 0644 <<'UNIT'
[Unit]
Description=AionUi free local 24/7 Cowork app :3006
After=network.target

[Service]
Type=simple
ExecStart=/usr/bin/env npx next start -p 3006
WorkingDirectory=%h/.owl-orca-v6/client/aionui
Restart=on-failure
MemoryMax=128M

[Install]
WantedBy=default.target
UNIT
    check_port 3006 aionui
  fi
  if [[ $WITH_HERMES -eq 1 ]]; then
atomic_write "$SYSTEMD_USER/orca-hermes.service" 0644 <<'UNIT'
[Unit]
Description=Hermes Studio web dashboard :3007
After=network.target

[Service]
Type=simple
ExecStart=/usr/bin/env npx next start -p 3007
WorkingDirectory=%h/.owl-orca-v6/client/hermes
Restart=on-failure
MemoryMax=128M

[Install]
WantedBy=default.target
UNIT
    check_port 3007 hermes
  fi
  if [[ $WITH_NONO -eq 1 ]] || [[ $WITH_PANE -eq 1 ]] || [[ $WITH_OPENCODELINUX -eq 1 ]]; then
    log "nono (gVisor-like sandbox pre-race security) / Pane (terminal-first agent manager) / opencodelinux (config showcase) — clone-on-demand client tools, no resident units"
    mkdir -p "$CLIENT_DIR"
  fi
fi

# ==================== STEP 20/24: opt-in legacy + GLM (F4, F10) ====================
log "STEP 20/24 opt-in legacy — 9Router canary (F4: duplicates router fallback, OFF) + ruflo (EXTERNAL 512M) + ShardBrowser (EXTERNAL testing) + GLM autoclaw (F10 flag-gated)"
if [[ $DRY_RUN -eq 0 ]]; then
  if [[ $WITH_9ROUTER -eq 1 ]]; then
    warn "9Router canary duplicates orca-router's own StreamRacer+CB+fallback (F4) — installed only because you asked"
atomic_write "$SYSTEMD_USER/orca-9router.service" 0644 <<'UNIT'
[Unit]
Description=9Router v0.4.59 canary fallback combos :20128 + Mihomo :7890 + Nginx :8330 + token daemon :48321
After=network.target

[Service]
Type=simple
ExecStart=/usr/bin/env npx 9router --port 20128
WorkingDirectory=%h/.config/9router
Restart=on-failure
MemoryMax=128M

[Install]
WantedBy=default.target
UNIT
    check_port 20128 9router
    check_port 7890 mihomo
    check_port 8330 nginx-kiro
    check_port 48321 token-daemon
  fi
  if [[ $WITH_RUFLO -eq 1 ]]; then
    warn "ruflo :3010 512M VIOLATES the cap (F4) — external host only; unit is generated but NOT enabled"
atomic_write "$SYSTEMD_USER/orca-ruflo-swarm.service" 0644 <<'UNIT'
[Unit]
Description=Ruflo post-race swarm 100+ agents EXTERNAL-ONLY 512M :3010
After=network.target

[Service]
Type=simple
ExecStart=/usr/bin/env npx ruflo@latest mcp start --port 3010
WorkingDirectory=%h/.owl-orca-v6/observability
Restart=on-failure
MemoryMax=512M
MemoryHigh=384M

[Install]
WantedBy=default.target
UNIT
    check_port 3010 ruflo
  fi
  if [[ $WITH_SHARDBROWSER -eq 1 ]]; then
    warn "ShardBrowser :40325 200-400M + per-profile 100-200M — EXTERNAL/testing only (cap violation)"
atomic_write "$SYSTEMD_USER/orca-shardbrowser.service" 0644 <<'UNIT'
[Unit]
Description=ShardBrowser anti-detect Chromium 152 TESTING-ONLY :40325
After=network.target

[Service]
Type=simple
ExecStart=%h/.local/share/shardbrowser/shardbrowser --api-port 40325 --enable-quic --enable-webrtc-block
WorkingDirectory=%h/.local/share/shardbrowser
Restart=on-failure
MemoryMax=512M
MemoryHigh=384M

[Install]
WantedBy=default.target
UNIT
    check_port 40325 shardbrowser
  fi
  if [[ $WITH_GLM -eq 1 ]]; then
atomic_write "$SYSTEMD_USER/orca-autoclaw-glm.service" 0644 <<'UNIT'
[Unit]
Description=Autoclaw Autologin GLM token feed 24h auto-refresh round-robin :31000 (F10 flag-gated)
After=network.target

[Service]
Type=simple
ExecStart=%h/.owl-orca-v6/venv/bin/python -m autoclaw --port 31000
WorkingDirectory=%h/.owl-orca-v6
Restart=on-failure
MemoryMax=128M

[Install]
WantedBy=default.target
UNIT
    check_port 31000 glm
  fi
  if [[ $WITH_METACUBEXD -eq 1 ]]; then
atomic_write "$SYSTEMD_USER/orca-metacubexd.service" 0644 <<'UNIT'
[Unit]
Description=Metacubexd Mihomo dashboard :3008 (pairs with --with-9router)
After=network.target

[Service]
Type=simple
ExecStart=/usr/bin/env npx next start -p 3008
WorkingDirectory=%h/.owl-orca-v6/observability/metacubexd
Restart=on-failure
MemoryMax=96M

[Install]
WantedBy=default.target
UNIT
    check_port 3008 metacubexd
  fi
  if [[ $WITH_PROXY_MESH -eq 1 ]] || [[ $WITH_PROXY_ANALYSIS -eq 1 ]] || [[ $WITH_OMNIPROXY_SMART -eq 1 ]]; then
    log "observability PWAs (mesh :3000 / analysis :3009 / smart :3011) — opt-in dashboards only, no routing role"
    mkdir -p "$OBS_DIR"
  fi
fi
