#!/usr/bin/env bash
# core_boot_verify.sh — Mock Test #2 verification battery (single invocation)
# Boots core-only profile with setsid-detached processes, then proves:
#   health, Tier-0 animal classification, breaker transitions, SIGHUP reload.
set -u
BASE=${OWL_ORCA_HOME:-$HOME/.owl-orca-v6}
PY=$BASE/venv/bin/python
LOG=/tmp/owl-core-boot

pkill -f "orca-router.py" 2>/dev/null
pkill -f "forward_proxy.py" 2>/dev/null
pkill -f "kiro-gateway-shim.py" 2>/dev/null
pkill -f "mempalace-lazy.py" 2>/dev/null
sleep 1

setsid nohup $PY $BASE/bin/orca-router.py      </dev/null >$LOG-router.log  2>&1 &
setsid nohup $PY $BASE/bin/forward_proxy.py    </dev/null >$LOG-forward.log 2>&1 &
setsid nohup $PY $BASE/bin/kiro-gateway-shim.py </dev/null >$LOG-kiro.log    2>&1 &
setsid nohup $PY $BASE/bin/mempalace-lazy.py   </dev/null >$LOG-mempalace.log 2>&1 &

echo "waiting for boot..."; sleep 8

echo "=== PORTS ==="
ss -tln 2>/dev/null | grep -E "60001|60000|8333|60004" || echo "NO PORTS"

echo "=== ROUTER HEALTHZ ==="
curl -s --max-time 4 http://127.0.0.1:60001/healthz | python3 -m json.tool 2>/dev/null | head -40

echo "=== FORWARD PROXY LEDGER ==="
curl -s --max-time 4 http://127.0.0.1:60000/healthz 2>/dev/null | head -c 300; echo

echo "=== KIRO SHIM ==="
curl -s --max-time 4 http://127.0.0.1:8333/healthz 2>/dev/null | head -c 300; echo

echo "=== MEMPALACE (H6 lazy) ==="
curl -s --max-time 4 http://127.0.0.1:60004/status 2>/dev/null | head -c 300; echo

echo "=== TIER-0 ANIMAL CLASSIFICATION (H7) ==="
for p in "strategy vision roadmap long-term patterns" \
         "quick prototype fast ship now" \
         "deep analysis hidden factors root cause" \
         "build system step by step practical" \
         "creative unconventional playful remix"; do
  printf '%-45s -> ' "$p"
  curl -s --max-time 4 -X POST http://127.0.0.1:60001/v1/prompt/classify \
       -d "{\"prompt\":\"$p\"}" | head -c 220; echo
done

echo "=== BREAKER PROOF (H4) — 6 hits on failing upstream ==="
for i in 1 2 3 4 5 6; do
  code=$(curl -s -o /dev/null -w "%{http_code}" --max-time 6 \
     -X POST http://127.0.0.1:60001/v1/chat/completions \
     -d '{"model":"premium-openai","messages":[{"role":"user","content":"hi"}]}' 2>/dev/null)
  echo "hit$i -> HTTP $code"
done
echo "--- breakers after:"
curl -s --max-time 4 http://127.0.0.1:60001/healthz | python3 -c \
  "import sys,json; d=json.load(sys.stdin); print(json.dumps(d.get('hacks',{}).get('H4_breakers',{}),indent=1))" 2>/dev/null

echo "=== SIGHUP RELOAD PROOF (H5) ==="
RPID=$(pgrep -f "orca-router.py" | head -1)
BEFORE=$(ss -tn 2>/dev/null | grep -c ":60001")
kill -HUP $RPID && sleep 2
curl -s --max-time 4 http://127.0.0.1:60001/healthz >/dev/null && echo "post-HUP healthz: OK (socket survived)"
echo "HUP sent to PID $RPID"

echo "=== DONE — services left running (setsid) ==="
pgrep -af "orca-router|forward_proxy|kiro-gateway|mempalace" | head -5
