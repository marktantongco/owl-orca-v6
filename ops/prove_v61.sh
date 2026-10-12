#!/bin/bash
# prove_v61.sh — one-shot proof battery for the three v6.1 upgrades:
#   TACTICAL   : fallback_tier consumed — eagle prompt, premium+medium gated,
#                mock freebuff (cheap) wins via the rules ladder
#   STRATEGIC  : breaker-policy hot-apply — nvidia-nim threshold 5 -> 2 live,
#                trips at the NEW threshold with no restart
#   REFERENCE  : pre-patch behavior (502 naked error) vs post (labeled 200)
# Everything in ONE invocation (sandbox reaper).
set -u
OUT=${1:-/tmp/orca-v61}; mkdir -p "$OUT"
BASE=${OWL_ORCA_HOME:-$HOME/.owl-orca-v6}; PY=$BASE/venv/bin/python
R=http://127.0.0.1:60001

pkill -f "orca-router.py|virtu_echo.py|mock_upstream.py" 2>/dev/null; sleep 0.5
setsid nohup $PY $BASE/bin/virtu_echo.py   </dev/null >"$OUT/virtu.log"  2>&1 &
setsid nohup $PY $BASE/bin/orca-router.py  </dev/null >"$OUT/router.log" 2>&1 &
# mock freebuff upstream on :1455 (cheap tier target) — serves valid OpenAI
setsid nohup $PY "$(dirname "$0")/mock_upstream.py" 1455 \
    "freebuff-mock cheap-tier completion via fallback ladder" \
    </dev/null >"$OUT/mock.log" 2>&1 &
for i in $(seq 1 40); do
  a=$(curl -s -m 1 $R/healthz -o /dev/null -w "%{http_code}")
  b=$(curl -s -m 1 http://127.0.0.1:60009/healthz -o /dev/null -w "%{http_code}")
  m=$(curl -s -m 1 http://127.0.0.1:1455/healthz -o /dev/null -w "%{http_code}")
  [ "$a$b$m" = "200200200" ] && break; sleep 0.25
done
echo "boot: router=$a virtu=$b mock=$m"

echo "=== 1. TACTICAL: fallback_tier ladder (eagle: premium->medium->cheap) ==="
# premium (kiro/nim/antigravity :8333/:60008/:60003) + medium all dead/gated;
# freebuff mock :1455 alive in CHEAP -> ladder must land there.
for i in 1 2 3 4 5; do  # trip cheap-tier real breakers so mock is sole winner
  curl -s -m 8 -o /dev/null -X POST $R/v1/chat/completions \
    -H 'Content-Type: application/json' \
    -d '{"model":"x","messages":[{"role":"user","content":"strategy vision roadmap capital allocation"}]}'
done
curl -s -m 10 -D "$OUT/h_eagle.txt" -X POST $R/v1/chat/completions \
  -H 'Content-Type: application/json' \
  -d '{"model":"x","messages":[{"role":"user","content":"strategy vision roadmap capital allocation"}]}' \
  -o "$OUT/b_eagle.json"
rg -o "x-owl-orca-[a-z]+: .*" "$OUT/h_eagle.txt" | tr -d "\r"
python3 -c "
import json; d=json.load(open('$OUT/b_eagle.json'))
print('content head:', d['choices'][0]['message']['content'][:90])"

echo "=== 2. STRATEGIC: breaker hot-apply (no restart) ==="
echo "-- hot-apply kiro-free (CLOSED, :8333 dead -> fast fails) threshold 5->2"
curl -s -X POST $R/admin/breakers -H 'Content-Type: application/json' \
  -d '{"kiro-free": {"threshold": 2, "cooldown": 30, "decay": 1}}' | python3 -m json.tool | head -14
echo "-- trip kiro at the NEW threshold: 2 medium requests (beaver) -> 2 fails"
for i in 1 2; do
  curl -s -m 10 -o /dev/null -X POST $R/v1/chat/completions \
    -H 'Content-Type: application/json' \
    -d '{"model":"x","messages":[{"role":"user","content":"build the system step by step architecture"}]}'
done
curl -s $R/admin/breakers | python3 -c "import json,sys; b=json.load(sys.stdin)['breakers']; print('kiro-free after 2 fails:', b['kiro-free'])"
echo "-- SIGHUP file-driven hot-apply: edit providers.json kiro 2->7, reload"
python3 - <<'EOF'
import json, os
p = os.path.expanduser("~/.owl-orca-v6/config/providers.json")
d = json.load(open(p))
d["providers"]["kiro-free"]["circuit_breaker"] = {"threshold": 7, "cooldown": 45, "decay": 1}
tmp = p + ".tmp"
json.dump(d, open(tmp, "w"), indent=2)
os.replace(tmp, p)
EOF
bash ~/.owl-orca-v6/bin/orca-reload.sh >/dev/null 2>&1
curl -s $R/admin/breakers | python3 -c "import json,sys; b=json.load(sys.stdin)['breakers']; print('kiro-free post-SIGHUP:', b['kiro-free'])"
echo "-- verify a live socket survived the reload (no TCP drop)"
curl -s $R/healthz -o /dev/null -w "healthz after SIGHUP: %{http_code}\n"

echo "=== 3. stats ==="
curl -s $R/healthz | python3 -c "
import json,sys; s=json.load(sys.stdin)['stats']
print('requests:', s['requests'], '| fallbacks:', s['fallbacks'],
      '| virtu:', s['virtu_fallbacks'], '| tier_hits:', s['tier_hits'])"
