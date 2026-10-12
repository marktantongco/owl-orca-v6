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
