#!/usr/bin/env bash
# fresh_box_tuned_verify.sh — fresh install of the TUNED installer, boot,
# and prove tuning survived the rebuild (rabbit routing + per-tier breakers).
set -u
INSTALLER=$(cd "$(dirname "$0")/.." && pwd)/install.sh
BASE=${OWL_ORCA_HOME:-$HOME/.owl-orca-v6}
BASE=${OWL_ORCA_HOME:-$HOME/.owl-orca-v6}

echo "=== FRESH INSTALL (--core-only) ==="
timeout 420 bash "$INSTALLER" --core-only > /tmp/fresh_install.log 2>&1
echo "install exit=$?"
grep -E "v13-tuned|Done — OWL-ORCA" /tmp/fresh_install.log | head -3

echo "=== BOOT (setsid detached) ==="
PY=$BASE/venv/bin/python
setsid nohup $PY $BASE/bin/orca-router.py       </dev/null >/tmp/orca-router.log  2>&1 &
setsid nohup $PY $BASE/bin/forward_proxy.py     </dev/null >/tmp/forward-proxy.log 2>&1 &
setsid nohup $PY $BASE/bin/kiro-gateway-shim.py </dev/null >/tmp/kiro-shim.log    2>&1 &
setsid nohup $PY $BASE/bin/mempalace-lazy.py    </dev/null >/tmp/mempalace.log    2>&1 &
sleep 8
ss -tln 2>/dev/null | grep -E "60001|60000|8333|60004" | wc -l | xargs echo "ports listening:"

echo "=== TUNED RULES VERSION ==="
python3 -c "import json; print(json.load(open('$BASE/tier0/promptc-os-rules.json'))['version'])"

echo "=== ANIMAL CLASSIFICATION (tuning baked in?) ==="
for p in "quick prototype fast ship now" \
         "strategy vision roadmap long-term patterns" \
         "deep analysis hidden factors root cause" \
         "build system step by step practical" \
         "creative unconventional playful remix" \
         "cross-field analogy bridge innovation"; do
  printf '%-46s -> ' "$p"
  curl -s --max-time 4 -X POST http://127.0.0.1:60001/v1/prompt/classify \
       -d "{\"prompt\":\"$p\"}" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d['animal'], d['cost_tier'], d['elapsed_ms'],'ms')" 2>/dev/null || echo FAIL
done

echo "=== TUNED BREAKERS (cheap trips at 3, medium holds to 5) ==="
for i in 1 2 3 4; do
  code=$(curl -s -o /dev/null -w "%{http_code}" --max-time 6 \
    -X POST http://127.0.0.1:60001/v1/chat/completions \
    -d '{"model":"premium-openai","messages":[{"role":"user","content":"hi"}]}' 2>/dev/null)
  echo "hit$i -> HTTP $code"
done
curl -s --max-time 4 http://127.0.0.1:60001/healthz | python3 -c \
  "import sys,json; print(json.dumps(json.load(sys.stdin)['hacks']['H4_breakers'],indent=1))" 2>/dev/null

echo "=== H5 SIGHUP (hot reload, no TCP drop) ==="
RPID=$(pgrep -f "orca-router.py" | head -1)
kill -HUP $RPID && sleep 2
curl -s --max-time 4 http://127.0.0.1:60001/healthz > /dev/null && echo "post-HUP healthz OK (PID $RPID)"
echo "=== FRESH-BOX VERIFY DONE ==="
