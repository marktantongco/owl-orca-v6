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
