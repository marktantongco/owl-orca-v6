# 4 · Tuning Packs

**Goal:** you install a pack, author your own, and recover pack state after a reinstall — all without downtime and with a probe gate that makes bad packs impossible to land silently.

A **pack** is a JSON delta: animal keywords to add/remove, optional breaker deltas, and a probe battery. `orca-pack.sh` merges it into the live taxonomy with atomic renames, SIGHUPs the router, **probes the merged rules, and rolls back automatically if the battery fails.**

---

## 4.1 The CLI

```bash
B=~/.owl-orca-v6/bin/orca-pack.sh

$B list                      # installed packs
$B preview config/packs/legal-eagle.json   # dry-run: what would change
$B install config/packs/legal-eagle.json   # gated install (expect: probe battery 6/6, PACK ACTIVE)
$B uninstall [backup-tag]    # restore from timestamped backup
$B apply-all                 # v6.2.1: reinstall ALL packs (works with the router DOWN)
```

## 4.2 Install a pack (copy-ready)

```bash
~/.owl-orca-v6/bin/orca-pack.sh install \
  ~/.owl-orca-v6/config/packs/legal-eagle.json
```

Expected output:

```
merged: legal-eagle 1.0.0
probe battery: 6/6
PACK ACTIVE — rules v13+legal-eagle-1.0.0
```

Now legal-domain prompts route to Owl (premium deep analysis):

```bash
curl -s -X POST http://127.0.0.1:60001/v1/prompt/classify \
  -d '{"prompt": "contract clause liability analysis"}' \
  | python3 -c "import json,sys; d=json.load(sys.stdin); print(d['animal'], d['cost_tier'])"
# → owl premium
```

## 4.3 The two shipped packs

| Pack | Effect |
|---|---|
| `legal-eagle.json` | 14 legal keywords → owl (legal work deserves premium analysis) |
| `egress-sentinel.json` | compliance/PII/tokenization → owl; proxy-infra (haproxy/squid/keepalived/icap) → beaver; breaker delta: copilot-free 4/50/2 (its 1.5 routing weight earns a wider failure budget) |

Packs **stack** — both can be active; the merge is additive on keywords, last-write on breaker deltas.

## 4.4 Author your own pack

Save as `~/.owl-orca-v6/config/packs/your-domain.json`:

```json
{
  "name": "your-domain",
  "version": "1.0.0",
  "description": "One sentence: what anchors where, and why the breaker delta (if any) is justified.",
  "rules_delta": {
    "animals": {
      "owl": {
        "keywords_add": ["your", "domain", "keywords", "here"]
      },
      "beaver": {
        "keywords_add": ["infra", "terms"],
        "keywords_remove": ["placeholder"]
      }
    }
  },
  "breaker_delta": {
    "copilot-free": { "threshold": 4, "cooldown": 50, "decay": 2 }
  },
  "probe_battery": [
    ["quick prototype ship now", "rabbit"],
    ["creative novel remix", "dolphin"],
    ["strategy vision roadmap", "eagle"],
    ["build system architecture", "beaver"],
    ["deep analysis root cause", "owl"],
    ["step by step checklist", "ant"]
  ]
}
```

**Authoring rules:**

1. `keywords_add` must be lowercase alphanumeric (the trie strips everything else anyway)
2. The **probe battery is your rollback insurance** — include one probe per animal your pack touches, asserting the *expected* animal. A pack that breaks routing fails 6/6 and never activates
3. `breaker_delta` only applies to providers that already exist in `providers.json`
4. Bump `version` on every change — it's stamped into the rules file (`v13+your-domain-1.0.1`) and shows in `orca-pack.sh list`

## 4.5 Post-reinstall recovery (`apply-all`)

A fresh `install.sh` resets configs to defaults. One command restores every pack — even with no services running (probes fall back to direct tier-0 invocation):

```bash
bash install.sh                       # configs reset (expected)
~/.owl-orca-v6/bin/orca-pack.sh apply-all
bash ops/oc_battery.sh                # re-prove the ladder under agent traffic
```

## 4.6 How the gate works (why you can trust it)

```
install ─▶ merge (tmp + os.replace) ─▶ SIGHUP ─▶ probe battery (HTTP or direct)
                                              ├─ 6/6 ─▶ PACK ACTIVE
                                              └─ else ─▶ auto-rollback from backups/
```

If the router is down, probes invoke tier-0 directly (sys.path fixed to the tree root) — so pack recovery never depends on services being healthy. This path is itself battery-tested: the v6.2.1 proof suite installs packs with the router stopped.

---

**Next:** [Operations Runbook →](05-operations-runbook.md)
