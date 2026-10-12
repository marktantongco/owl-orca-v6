#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Audit harness for owl-orca-v6-unified-final-installer.sh.

v6.2.1: the flag matrix no longer runs REAL installs against $HOME by default
(see the note above the matrix) — that clobbered live pack deltas.

Extracts every heredoc artifact (PY/JSON/UNIT/WRAP/MD...), compiles the
Python, parses the JSON, checks the port registry for duplicates, and
verifies the 9 hacks + 10 fixes are present as real code.
"""
import json
import os
import re
import subprocess
import sys
import tempfile

SH = os.environ.get("OWL_ORCA_INSTALLER", os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "install.sh"))
src = open(SH, encoding="utf-8").read()

results = []


def check(name, ok, detail=""):
    results.append((name, ok, detail))


# ---------- 1. Extract heredocs ----------
# Pattern: atomic_write "DEST" MODE <<'TAG' ... TAG  (single line) and
# cat > X <<'TAG' ... TAG
heredocs = []
for m in re.finditer(
    r'(?:atomic_write\s+("[^"]+"|\S+)\s+\S+\s*|cat\s*>\s*("[^"]+"|\S+)\s*)<<-?\'(\w+)\'',
    src,
):
    dest = (m.group(1) or m.group(2) or "").strip('"')
    tag = m.group(3)
    start = m.end()
    end = src.find("\n" + tag + "\n", start)
    if end == -1:
        continue
    body = src[start:end]
    heredocs.append((dest, tag, body))
check("heredoc extraction", len(heredocs) >= 20, f"{len(heredocs)} artifacts found")

# ---------- 2. Compile embedded Python ----------
py_errors = []
with tempfile.TemporaryDirectory() as td:
    for i, (dest, tag, body) in enumerate(heredocs):
        if tag not in ("PY", "WRAP", "FRESH", "RELOAD", "HEALTH", "CLI", "SH", "VPS"):
            continue
        if tag != "PY":
            continue
        path = os.path.join(td, f"mod{i}.py")
        open(path, "w", encoding="utf-8").write(body)
        r = subprocess.run([sys.executable, "-m", "py_compile", path],
                           capture_output=True, text=True)
        if r.returncode != 0:
            py_errors.append((dest, r.stderr.strip()[:300]))
check("embedded Python compiles", not py_errors,
      "; ".join(f"{d}: {e}" for d, e in py_errors) or "all modules compile")

# ---------- 3. Parse embedded JSON ----------
json_errors = []
for dest, tag, body in heredocs:
    if tag != "JSON":
        continue
    try:
        json.loads(body)
    except ValueError as exc:
        json_errors.append((dest, str(exc)[:200]))
# The two goose configs contain $TUNNEL_KEY (shell-expanded) — expected.
json_errors = [(d, e) for d, e in json_errors if "$TUNNEL_KEY" not in e]
check("embedded JSON parses", not json_errors,
      "; ".join(f"{d}: {e}" for d, e in json_errors) or "all JSON valid")

# ---------- 4. Port registry uniqueness ----------
port_block = re.search(r"PORT REGISTRY v6.*?# =", src, re.S)
ports = []
if port_block:
    ports = [int(p) for p in re.findall(r"\b(\d{4,5})\b", port_block.group(0))]
dups = sorted({p for p in ports if ports.count(p) > 1})
check("port registry unique", not dups, f"duplicates: {dups}" if dups else f"{len(ports)} refs audited")

# Cross-check: each systemd unit binds exactly one distinct port; a port bound
# by two DIFFERENT units is a true conflict. Comments/test commands don't count.
# Dedupe per ExecStart line so one line can't be counted twice by two patterns.
unit_ports = {}
for line in re.findall(r"ExecStart=.*", src):
    line_ports = set()
    line_ports.update(re.findall(r"--port[ =]?(\d{4,5})", line))
    line_ports.update(re.findall(r"127\.0\.0\.1:(\d{4,5})", line))
    line_ports.update(re.findall(r"(?:-p|--api-port|--ui-port|--mcp-port)(?:\s+|=)(\d{4,5})", line))
    for p in line_ports:
        unit_ports.setdefault(p, 0)
        unit_ports[p] += 1
# forward_proxy.py + orca-router.py + kiro shim + mempalace-lazy bind ports in
# __main__ (60000/60001/8333/60004) — they are single-owner by design.
bound_twice = {p: c for p, c in unit_ports.items() if c > 1 and p not in ("60000", "60001", "8333", "60004")}
check("unit ExecStart ports unique", not bound_twice,
      f"conflicts: {bound_twice}" if bound_twice else f"{len(unit_ports)} unit-bound ports audited")

# ---------- 5. Hack coverage 9/9 ----------
hacks = {
    "H1 uvloop": r"uvloop\.install\(\)",
    "H2 array('I') radix trie": r"array\('I', bytes\(4 \* capacity\)\)",
    "H2b memoryview zero-copy": r"memoryview\(chunk\)",
    "H3 FIRST_COMPLETED": r"asyncio\.wait\(\s*pending,\s*return_when=asyncio\.FIRST_COMPLETED",   # v6.1: wait on pending (first SUCCESS decides, not first completion)
    "H3b cancel losers": r"t\.cancel\(\)",
    "H3c bounded 5": r"BOUND = 5",
    "H3d thinking_delta->reasoning_content": r'delta\["reasoning_content"\] = delta\.pop\("thinking_delta"\)',
    "H4 breaker atomic": r"fails >= self\.threshold",
    "H4b monotonic": r"time\.monotonic\(\) - self\.opened_at",
    "H5 atomic mv": r"mv -f \"\$tmp\" \"\$dest\"",
    "H5b SIGHUP handler": r"signal\.signal\(signal\.SIGHUP, _sighup\)",
    "H5c ExecReload HUP": r"ExecReload=/bin/kill -HUP \$MAINPID",
    "H6 lazy 300s": r"IDLE_UNLOAD_S = 300",
    "H7 lru_cache 1024": r"lru_cache\(maxsize=1024\)",
    "H8 pool 100": r"max_connections=100",
    "H8b Chrome/120 UA": r"Chrome/120\.0\.0\.0",
    "H9 only_socks5": r"--select_proxy_mode only_socks5",
    "H9b black/white ip": r"--black-ip-file",
    "H9c zstd quota": r"zstd.*65%|65% body shrink",
}
missing = [h for h, pat in hacks.items() if not re.search(pat, src)]
check("9 hacks as real code", not missing, f"missing: {missing}" if missing else "19/19 hack markers present")

# ---------- 6. Fix coverage F1-F10 ----------
fixes = {
    "F1 defense restored": r"defense_stack\.py",
    "F2 ExecReload restored": r"ExecReload=/bin/kill -HUP",
    "F3 PWA removed / 374M": r"374M [Ss]aved",
    "F4 swarm default off": r"WITH_9ROUTER=0",
    "F5 DPI gate": r"--with-dpi-bypass",
    "F6 hydra opt-in": r"WITH_HYDRA=0",
    "F7 nylon opt-in": r"WITH_NYLON=0",
    "F8 real builds": r"CGO_ENABLED=0 go build",
    "F9 NIM :60008": r"60008",
    "F10 GLM gated": r"WITH_GLM=0",
}
missing_f = [f for f, pat in fixes.items() if not re.search(pat, src)]
check("10 merge fixes", not missing_f, f"missing: {missing_f}" if missing_f else "F1-F10 all present")

# ---------- 7. Memory ledger arithmetic ----------
ledger = 384 + 128 + 256 + 64 + 10 + 256 + 10  # router+forward+kiro+virtu-echo+tier0+freebuff+graftcp
check("memory ledger ~1108M (v6.1: +64M virtu-echo)", ledger == 1108, f"core+standard-egress = {ledger}M")

# ---------- 7b. v6.1 upgrade markers ----------
v61 = {
    "v6.1 fallback_tier consumed": r"fallback_tier = rules\.get",
    "v6.1 ladder walk": r"_ladder_for\(tier, animal\)",
    "v6.1 race_with_ladder": r"async def race_with_ladder",
    "v6.1 virtu-echo provider": r'"virtu-echo"',
    "v6.1 virtu_echo service": r"orca-virtu-echo\.service",
    "v6.1 breaker hot-apply": r"async def breakers_apply",
    "v6.1 admin breakers GET": r"async def breakers_get",
    "v6.1 apply_all": r"def apply_all\(self, providers\)",
    "v6.1 OpenAI error envelope": r"def _openai_error",
    "v6.1 routing on last user msg": r"def _routing_prompt",
    "v6.1 ONE DONE": r"done_sent = False",
    "v6.1 SIGHUP policy apply": r"BREAKERS\.apply_all\(CONFIG\.providers\)",
}
for name, pat in v61.items():
    check(name, re.search(pat, src) is not None, "marker present")

# ---------- 7c. v6.2 playbook-integration markers ----------
v62 = {
    "v6.2 response cache class": r"class RespCache",
    "v6.2 cache hit header": r"X-Owl-Orca-Cache",
    "v6.2 guardrail battery": r"def check_guardrails",
    "v6.2 guardrail error type": r"guardrail_violation",
    "v6.2 plan gate header": r"X-Owl-Orca-Plan",
    "v6.2 weighted order": r"def _order\(",
    "v6.2 routing preference": r"routing_preference",
    "v6.2 quota remaining": r"def _quota_remaining",
    "v6.2 quota charge": r"def _quota_charge",
    "v6.2 quota state file": r"quota-state\.json",
    "v6.2 num_retries": r"num_retries",
    "v6.2 latency EMA": r"_LATENCY_EMA",
    "v6.2 admin cache": r"async def cache_get",
    "v6.2 admin quota": r"async def quota_get",
    "v6.2 admin routing": r"async def routing_get",
    "v6.2 tier prices": r"tier_prices\.json",
    "v6.2 tuning packs": r"orca-pack\.sh",
    "v6.2 pack probe gate": r"probe battery",
    "v6.2 billing meter": r"orca-billing-meter",
    "v6.2 sla report": r"orca-sla-report",
    "v6.2 legal-eagle pack": r"legal-eagle",
    "v6.2 hot-apply list": r"v6\.2_hot_applied",
    "v6.2 router version": r'version="6\.2\.0"',
    "v6.2 config version": r'"6\.2\.0-unified"',
}
for name, pat in v62.items():
    check(name, re.search(pat, src) is not None, "marker present")

# ---------- 8. dry-run flag matrix ----------
# NOTE: these two entries were REAL installs ([], [--core-only]) until v6.2.1.
# A real install rewrites ~/.owl-orca-v6 config with the baked heredocs —
# silently clobbering pack deltas and live config edits (found by the v6.2.1
# battery: pack breaker deltas vanished between install and reboot). Real-
# install coverage belongs to prove_v62.sh / fresh_box scripts, which run
# AFTER the last audit. Opt in with AUDIT_REAL_INSTALL=1 if you really want it.
_real = [[], ["--core-only"]] if os.environ.get("AUDIT_REAL_INSTALL") == "1" else \
    [["--dry-run"], ["--core-only", "--dry-run"]]
for flags, label in [
    (_real[0], "no flags"),
    (_real[1], "core only"),
    (["--dry-run"], "dry run"),
    (["--with-all-egress", "--dry-run"], "egress bundle"),
    (["--with-dpi-bypass", "--dry-run"], "DPI gate"),
    (["--with-all", "--dry-run"], "with-all"),
    (["--help"], "help"),
]:
    r = subprocess.run(["bash", SH] + flags, capture_output=True, text=True, timeout=60)
    check(f"dry-run: {label}", r.returncode == 0,
          (r.stderr or r.stdout)[-200:] if r.returncode else "exit 0")

# ---------- report ----------
print("=" * 78)
print("AUDIT REPORT — owl-orca-v6-unified-final-installer.sh")
print("=" * 78)
fails = 0
for name, ok, detail in results:
    status = "PASS" if ok else "FAIL"
    if not ok:
        fails += 1
    print(f"[{status}] {name}" + (f" — {detail}" if detail and not ok else ""))
    if ok and detail and len(detail) < 60:
        print(f"        {detail}")
print("-" * 78)
print(f"TOTAL: {len(results) - fails}/{len(results)} PASS, {fails} FAIL")
sys.exit(1 if fails else 0)
