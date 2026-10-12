#!/usr/bin/env bash
# Live integration test for owl-orca-v6 router: boot, H5 SIGHUP swap, H3/H4 race.
set -uo pipefail
cd "$HOME/.owl-orca-v6"
./venv/bin/python bin/orca-router.py > logs/router-live.log 2>&1 &
SRV=$!
trap 'kill $SRV 2>/dev/null' EXIT
sleep 4

echo "=== boot ==="
curl -sf http://127.0.0.1:60001/healthz >/dev/null && echo "router :60001 UP (pid $SRV)"

echo "=== H5: atomic-rename config swap + SIGHUP, socket must survive ==="
ss -H -tln 'sport = :60001' | grep -q ':60001' && echo "BEFORE: :60001 LISTEN"
python3 - <<'EOF'
import json, os
p = os.path.expanduser("~/.owl-orca-v6/tier0/promptc-os-rules.json")
rules = json.load(open(p))
rules["animals"]["rabbit"]["keys"].append("hacktestxyz")
tmp = p + ".swp"
json.dump(rules, open(tmp, "w"))
os.replace(tmp, p)                       # H5: atomic rename inode swap
print("config swapped by rename()")
EOF
kill -HUP $SRV
sleep 1.5
ss -H -tln 'sport = :60001' | grep -q ':60001' && echo "AFTER HUP: :60001 STILL LISTEN — zero TCP drop"
R=$(curl -s -X POST http://127.0.0.1:60001/v1/prompt/classify \
     -H 'Content-Type: application/json' -d '{"prompt":"hacktestxyz"}')
echo "classify('hacktestxyz') -> $R"
[[ "$R" == *'"rabbit"'* ]] && echo "H5 RELOAD PASS: new keyword live without restart"

echo "=== /admin/reload endpoint (H5 http path) ==="
curl -s -X POST http://127.0.0.1:60001/admin/reload; echo

echo "=== H3+H4: race without provider creds -> breakers engage ==="
curl -s -X POST http://127.0.0.1:60001/v1/chat/completions \
  -H 'Content-Type: application/json' \
  -d '{"stream":false,"messages":[{"role":"user","content":"hello"}]}' | head -c 200; echo
sleep 1
curl -s http://127.0.0.1:60001/healthz | python3 -c \
  "import json,sys; d=json.load(sys.stdin); print('H3 streamracer:', d['hacks']['H3_streamracer']); print('H4 breakers:', d['hacks']['H4_breakers'])"

echo "=== H3 streaming: SSE generator path ==="
curl -s -N -X POST http://127.0.0.1:60001/v1/chat/completions \
  -H 'Content-Type: application/json' \
  -d '{"stream":true,"messages":[{"role":"user","content":"hello"}]}' | head -c 200; echo

echo "=== SIGHUP log evidence ==="
grep -c "SIGHUP" logs/router-live.log && tail -3 logs/router-live.log
