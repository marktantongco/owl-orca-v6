#!/bin/bash
# drive_traffic.sh — one-shot: boot services + drive OpenCode through the
# tuned animal ladder, all within a single invocation (sandbox reaper kills
# background processes between invocations).
# Usage: drive_traffic.sh <logdir> [prompts...]
set -u
BASE=${OWL_ORCA_HOME:-$HOME/.owl-orca-v6}
PY=$BASE/venv/bin/python
OUT=${1:-/tmp/orca-traffic}
shift || true
mkdir -p "$OUT"

pkill -f "orca-router.py|forward_proxy.py|kiro-gateway-shim.py|mempalace-lazy.py|virtu_echo.py" 2>/dev/null
sleep 0.5

setsid nohup $PY $BASE/bin/orca-router.py       </dev/null >"$OUT/router.log"  2>&1 &
setsid nohup $PY $BASE/bin/forward_proxy.py     </dev/null >"$OUT/forward.log" 2>&1 &
setsid nohup $PY $BASE/bin/kiro-gateway-shim.py </dev/null >"$OUT/kiro.log"    2>&1 &
setsid nohup $PY $BASE/bin/mempalace-lazy.py    </dev/null >"$OUT/mempalace.log" 2>&1 &
setsid nohup $PY $BASE/bin/virtu_echo.py        </dev/null >"$OUT/virtu.log"   2>&1 &

for i in $(seq 1 40); do
  ok=$(curl -s -m 1 http://127.0.0.1:60001/healthz -o /dev/null -w "%{http_code}")
  vi=$(curl -s -m 1 http://127.0.0.1:60009/healthz -o /dev/null -w "%{http_code}")
  [ "$ok" = "200" ] && [ "$vi" = "200" ] && break
  sleep 0.25
done
echo "boot: router=$ok virtu=$vi"

# direct ladder probes (curl) — capture headers proving the animal routing
probe() {
  name=$1; prompt=$2
  curl -s -m 15 -D "$OUT/h_$name.txt" -X POST http://127.0.0.1:60001/v1/chat/completions \
    -H 'Content-Type: application/json' \
    -d "{\"model\":\"gpt-4o-mini\",\"messages\":[{\"role\":\"user\",\"content\":\"$prompt\"}]}" \
    -o "$OUT/b_$name.json"
  tier=$(rg -o "X-Owl-Orca-Tier: .*" "$OUT/h_$name.txt" | head -1 | tr -d "\r")
  animal=$(rg -o "X-Owl-Orca-Animal: .*" "$OUT/h_$name.txt" | head -1 | tr -d "\r")
  route=$(rg -o "X-Owl-Orca-Route: .*" "$OUT/h_$name.txt" | head -1 | tr -d "\r")
  prov=$(rg -o "X-Owl-Orca-Provider: .*" "$OUT/h_$name.txt" | head -1 | tr -d "\r")
  echo "probe[$name]: $animal | $tier | $route | $prov"
}

probe rabbit  "quick prototype a fast todo app and ship it now"
probe beaver  "build the system step by step, practical architecture"
probe eagle   "strategy vision roadmap for the next year, capital allocation"
probe owl     "deep analysis of hidden factors and root cause"

# OpenCode real traffic
i=0
for p in "$@"; do
  i=$((i+1))
  echo "--- opencode run #$i: ${p:0:60}"
  (cd "${OPENCODE_PROJECT_DIR:-$HOME}" && timeout 75 opencode run "$p" >"$OUT/oc_$i.txt" 2>&1) || true
  tail -c 500 "$OUT/oc_$i.txt" | rg -v "^$" | head -12
done

echo "=== final healthz stats ==="
curl -s http://127.0.0.1:60001/healthz | python3 -c "
import json,sys
d=json.load(sys.stdin)
s=d['stats']
print('requests:', s['requests'], 'races:', s['races'],
      'fallbacks:', s['fallbacks'], 'virtu_fallbacks:', s['virtu_fallbacks'])
print('tier_hits:', s['tier_hits'])
print('breakers:', d['hacks']['H4_breakers'])"
