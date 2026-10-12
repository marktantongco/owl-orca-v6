#!/usr/bin/env bash
# orca-pack.sh — v6.2 P7 (playbook monetization #2): animal-profile tuning
# packs. A pack = rules delta (animal keywords) + optional breaker delta,
# hot-applied with ZERO downtime via the H5 atomic-rename + SIGHUP path.
# Activation is GATED on the classify-probe battery (6/6) so a bad pack can
# never degrade routing silently — the exact gate the playbook prescribes.
#
# usage:
#   orca-pack.sh list
#   orca-pack.sh preview <pack.json>
#   orca-pack.sh install <pack.json>
#   orca-pack.sh uninstall [backup-tag]
#   orca-pack.sh apply-all          # v6.2.1: post-reinstall pack recovery
set -euo pipefail
BASE="$HOME/.owl-orca-v6"
CFG="$BASE/config"
RULES="$BASE/tier0/promptc-os-rules.json"   # tier0 taxonomy (TIER0_DIR default)
PROV="$CFG/providers.json"
PACKS="$CFG/packs"
BACKUPS="$CFG/backups"

die() { echo "[orca-pack] $*" >&2; exit 1; }
tag() { date +%Y%m%d-%H%M%S; }
reload_router() {
  "$BASE/bin/orca-reload.sh" >/dev/null 2>&1 || pkill -HUP -f orca-router.py || true
}

apply_pack() {  # $1 = pack path — python merge, atomic rename (H5)
  python3 - "$1" "$RULES" "$PROV" <<'PY'
import json, os, sys
pack_p, rules_p, prov_p = sys.argv[1:4]
pack = json.load(open(pack_p))

rules = json.load(open(rules_p))
for animal, delta in pack.get("rules_delta", {}).get("animals", {}).items():
    spec = rules.setdefault("animals", {}).setdefault(
        animal, {"keys": [], "mode": "", "best_for": ""})
    keys = spec.setdefault("keys", [])
    for k in delta.get("keywords_add", []):
        if k not in keys:
            keys.append(k)
    for k in delta.get("keywords_remove", []):
        if k in keys:
            keys.remove(k)
    if delta.get("mode"):
        spec["mode"] = delta["mode"]
rules["version"] = "%s+%s-%s" % (rules.get("version", "v13"),
                                 pack.get("name", "pack"),
                                 pack.get("version", "1"))
t = rules_p + ".tmp"
json.dump(rules, open(t, "w"), indent=2)
os.replace(t, rules_p)

if pack.get("breaker_delta"):
    prov = json.load(open(prov_p))
    for name, pol in pack["breaker_delta"].items():
        if name in prov.get("providers", {}):
            prov["providers"][name]["circuit_breaker"] = pol
    t = prov_p + ".tmp"
    json.dump(prov, open(t, "w"), indent=2)
    os.replace(t, prov_p)
print("merged: %s %s" % (pack.get("name"), pack.get("version")))
PY
}

probe_gate() {  # 6/6 classify probes or the pack rolls back.
  # v6.2.1: HTTP when the router is live, else DIRECT tier0 invocation —
  # packs are installable pre-boot, so `apply-all` works right after a
  # reinstall with no services running (the post-reinstall recovery path).
  if curl -s -m 2 -o /dev/null http://127.0.0.1:60001/healthz; then
    python3 - "$1" <<'PY'
import json, sys, urllib.request
pack = json.load(open(sys.argv[1]))
probes = pack.get("probe_battery") or [
    ("quick prototype ship now", "rabbit"),
    ("creative novel remix", "dolphin"),
    ("strategy vision roadmap", "eagle"),
    ("build system architecture", "beaver"),
    ("deep analysis root cause", "owl"),
    ("step by step checklist", "ant")]
ok = 0
for prompt, want in probes:
    req = urllib.request.Request(
        "http://127.0.0.1:60001/v1/prompt/classify",
        data=json.dumps({"prompt": prompt}).encode(),
        headers={"Content-Type": "application/json"})
    try:
        got = json.load(urllib.request.urlopen(req, timeout=5)).get("animal")
    except Exception:
        got = None
    ok += got == want
print("probe battery: %d/%d" % (ok, len(probes)))
sys.exit(0 if ok == len(probes) else 1)
PY
  else
    PYBIN="$BASE/venv/bin/python"; [ -x "$PYBIN" ] || PYBIN=python3
    "$PYBIN" - "$1" "$BASE" <<'PY'
import json, sys
pack_p, base = sys.argv[1], sys.argv[2]
sys.path.insert(0, base)             # tree root: tier0 package
sys.path.insert(0, base + "/bin")    # v6.2.1: utils package lives in bin/
from tier0.classifier import get_tier0
pack = json.load(open(pack_p))
probes = pack.get("probe_battery") or [
    ("quick prototype ship now", "rabbit"),
    ("creative novel remix", "dolphin"),
    ("strategy vision roadmap", "eagle"),
    ("build system architecture", "beaver"),
    ("deep analysis root cause", "owl"),
    ("step by step checklist", "ant")]
t = get_tier0()
ok = sum(t.classify(p)["animal"] == w for p, w in probes)
print("probe battery (direct, router down): %d/%d" % (ok, len(probes)))
sys.exit(0 if ok == len(probes) else 1)
PY
  fi
}

cmd="${1:-}"; shift || true
case "$cmd" in
  list)
    ls -1 "$PACKS" 2>/dev/null || echo "(no packs directory)"
    exit 0 ;;
  preview)
    [ -f "${1:-}" ] || die "preview <pack.json>"
    python3 -c "import json,sys; print(json.dumps(json.load(open(sys.argv[1])), indent=2))" "$1"
    echo "[orca-pack] preview only — nothing written"
    exit 0 ;;
  install)
    [ -f "${1:-}" ] || die "install <pack.json>"
    T=$(tag)
    mkdir -p "$BACKUPS"
    cp "$RULES" "$BACKUPS/rules.$T.json"
    [ -f "$PROV" ] && cp "$PROV" "$BACKUPS/providers.$T.json"
    apply_pack "$1"
    reload_router                      # hot-apply first (zero downtime) ...
    if probe_gate "$1"; then          # ... then gate on the LIVE merged rules
      echo "[orca-pack] PACK ACTIVE: $(basename "$1") (backup tag $T, zero-downtime SIGHUP)"
    else
      cp "$BACKUPS/rules.$T.json" "$RULES"
      [ -f "$BACKUPS/providers.$T.json" ] && cp "$BACKUPS/providers.$T.json" "$PROV"
      reload_router
      echo "[orca-pack] probe gate FAILED — rolled back to $T backup"
      exit 1
    fi ;;
  uninstall)
    if [ -n "${1:-}" ]; then T="$1"; else
      T=$(ls -1 "$BACKUPS" 2>/dev/null | sed -n 's/^rules\.\([0-9-]*\)\.json/\1/p' | tail -1)
    fi
    [ -n "${T:-}" ] || die "no backup to restore"
    cp "$BACKUPS/rules.$T.json" "$RULES"
    [ -f "$BACKUPS/providers.$T.json" ] && cp "$BACKUPS/providers.$T.json" "$PROV"
    reload_router
    echo "[orca-pack] restored backup $T (SIGHUP reload)" ;;
  apply-all)
    n_ok=0; n_fail=0
    for f in "$PACKS"/*.json; do
      [ -f "$f" ] || continue
      echo "[orca-pack] apply-all: $(basename "$f")"
      if "$0" install "$f"; then n_ok=$((n_ok+1)); else n_fail=$((n_fail+1)); fi
    done
    echo "[orca-pack] apply-all done: $n_ok applied, $n_fail failed"
    [ "$n_fail" -eq 0 ] ;;
  *)
    echo "usage: orca-pack.sh {list|preview|install|uninstall|apply-all} [pack|tag]"
    exit 2 ;;
esac
