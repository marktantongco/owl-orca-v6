# 1 · Installation & Setup

**Goal:** a running owl-orca stack, verified end-to-end, answering your first routed completion — in about ten minutes.

---

## 1.1 Prerequisites

| Requirement | Why | Check |
|---|---|---|
| Linux (any modern distro) | systemd units, `/proc` stats | `uname -s` |
| Python 3.12+ | router runtime + venv | `python3 --version` |
| ~1.1 GB free RAM | default profile (832 MB core services) | `free -h` |
| ~400 MB disk | tree + venv | `df -h ~` |
| curl + jq | verification commands | `which curl jq` |
| root (optional) | system-level systemd units; user units work otherwise | — |

Nothing else. The installer is **self-contained** — it creates its own virtualenv, writes its own configs, and generates its own encryption keys.

## 1.2 Install

```bash
git clone https://github.com/marktantongco/owl-orca-v6.git
cd owl-orca-v6

bash install.sh
```

What the installer does, in order:

1. Creates the runtime tree at `~/.owl-orca-v6` (`bin/`, `tier0/`, `config/`, `logs/`, `venv/`)
2. Builds the Python 3.12 venv and installs `fastapi`, `uvicorn`, `httpx`, `uvloop`, `cryptography`
3. Writes `providers.json`, `routes.json`, `tier_prices.json`, and the example packs
4. Generates the Fernet key + encrypted token vault (`0600`, atomic rename)
5. Installs systemd units with `ExecReload=/bin/kill -HUP $MAINPID` (the H5 hot-reload hook)
6. Drops `VERIFICATION.md` and the `orca-*` helper CLI into the tree

Re-running `install.sh` is safe: it resets configs to defaults but leaves the token vault intact. Custom state (packs, quota) is recovered with one command after any reinstall — see [Packs §4.5](04-packs.md).

## 1.3 Verify

```bash
# 1. Marker audit — expect "51/51 PASS" (dry-run only; never mutates your tree)
python3 ops/audit_v6.py

# 2. Service health + hack selftest
~/.owl-orca-v6/bin/orca-health-check.sh

# 3. Live router status (H1..H8 flags, breaker states, v6.2 features)
curl -s http://127.0.0.1:60001/healthz | python3 -m json.tool | head -40
```

You should see all services report `200`, and the `hacks` object showing `H1_uvloop: true` and friends.

## 1.4 Your first routed completion

```bash
curl -s http://127.0.0.1:60001/v1/chat/completions \
  -H 'Content-Type: application/json' \
  -d '{
    "model": "copilot-free",
    "messages": [{"role": "user", "content": "strategy vision roadmap for Q3"}]
  }' | python3 -m json.tool
```

Then watch the router explain what it did:

```bash
# Which animal did the prompt classify to? (expect: eagle)
curl -s -X POST http://127.0.0.1:60001/v1/prompt/classify \
  -d '{"prompt": "strategy vision roadmap for Q3"}' | python3 -m json.tool

# Race stats: requests, races, virtu fallbacks, tier hits
curl -s http://127.0.0.1:60001/healthz | python3 -c \
  "import json,sys; print(json.load(sys.stdin)['stats'])"
```

## 1.5 Wire up OpenCode

OpenCode (or any OpenAI-compatible client) points at the virtual provider on `:60001`:

```jsonc
// ~/.config/opencode/opencode.json
{
  "provider": {
    "owl-orca-virtual": {
      "npm": "@ai-sdk/openai-compatible",
      "name": "OWL-ORCA v6 Virtual",
      "options": { "baseURL": "http://127.0.0.1:60001/v1" },
      "models": {
        "copilot-free": {}, "antigravity-free": {},
        "kiro-free": {}, "nim-free": {}, "freebuff-deepseek": {}
      }
    }
  }
}
```

Then run the five-animal battery to prove real agent traffic flows through the ladder:

```bash
bash ops/oc_battery.sh
# expect: boot: router=200 virtu=200, 5 runs, all completions returned,
#         stats showing 5 requests, 5 races, 0-10 virtu fallbacks
```

## 1.6 Uninstall / restore

```bash
# Remove everything (units + tree)
systemctl --user stop owl-orca-*.service 2>/dev/null
rm -rf ~/.owl-orca-v6

# Restore a snapshot (if you took one — see Runbook §5.7)
# tar -xzf owl-orca-v6.2.1-tuned-snapshot-<date>.tar.gz -C ~/
```

---

**Next:** [Architecture Deep-Dive →](02-architecture.md)
