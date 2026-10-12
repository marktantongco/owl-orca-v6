#!/bin/bash
# oc_battery.sh — full OpenCode traffic battery through the tuned animal
# ladder, one sandbox invocation (reaper kills background procs between
# invocations). Boots router + virtu-echo, runs 5 animal-mode prompts via
# `opencode run`, captures outputs + final router stats.
set -u
OUT=${1:-/tmp/orca-battery}
mkdir -p "$OUT"
BASE=${OWL_ORCA_HOME:-$HOME/.owl-orca-v6}
PY=$BASE/venv/bin/python

pkill -f "orca-router.py|virtu_echo.py" 2>/dev/null; sleep 0.5
setsid nohup $PY $BASE/bin/virtu_echo.py  </dev/null >"$OUT/virtu.log" 2>&1 &
setsid nohup $PY $BASE/bin/orca-router.py </dev/null >"$OUT/router.log" 2>&1 &
for i in $(seq 1 40); do
  a=$(curl -s -m 1 http://127.0.0.1:60001/healthz -o /dev/null -w "%{http_code}")
  b=$(curl -s -m 1 http://127.0.0.1:60009/healthz -o /dev/null -w "%{http_code}")
  [ "$a" = "200" ] && [ "$b" = "200" ] && break; sleep 0.25
done
echo "boot: router=$a virtu=$b"

cd "${OPENCODE_PROJECT_DIR:-$HOME}"
i=0
while IFS= read -r p; do
  [ -z "$p" ] && continue
  i=$((i+1))
  echo "--- RUN $i: $p"
  timeout -k 5 150 opencode run "$p" > "$OUT/oc_$i.txt" 2>&1 < /dev/null
  echo "    exit=$? bytes=$(wc -c < "$OUT/oc_$i.txt")"
  head -c 220 "$OUT/oc_$i.txt" | tr '\n' ' ' | sed 's/  */ /g'; echo
done <<'PROMPTS'
quick prototype a fast hello-world CLI and ship it now
deep analysis of the hidden failure factors and root cause in this design
strategy vision roadmap: what should we build next quarter
build the deployment system step by step, practical infra work
creative unconventional playful remix: invent a wild feature idea
PROMPTS

echo "=== ROUTER STATS ==="
curl -s http://127.0.0.1:60001/healthz | python3 -c "
import json,sys
d=json.load(sys.stdin); s=d['stats']
print('requests:', s['requests'], '| races:', s['races'],
      '| virtu_fallbacks:', s['virtu_fallbacks'], '| tier_hits:', s['tier_hits'])
print('breakers:', json.dumps(d['hacks']['H4_breakers']))"
