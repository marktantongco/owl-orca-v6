# 7 · Integrations

**Goal:** wire clients, upstreams, and the surrounding agent ecosystem — and know which companion repos provide the moving parts.

---

## 7.1 Clients (anything OpenAI-shaped)

| Client | Wiring | Notes |
|---|---|---|
| **OpenCode** | `baseURL: http://127.0.0.1:60001/v1` | battery-proven under real agent traffic; see [Installation §1.5](01-installation.md) |
| **OpenAI SDKs** | point `base_url` at `:60001/v1` | python/js/go — identical contract |
| **Anthropic Messages clients** | `/v1/messages` on `:60001` | live SSE translation (`thinking_delta` → `reasoning_content`) |
| **curl / scripts** | plain HTTP | every endpoint accepts JSON |

## 7.2 Upstreams and their companion repos

Each upstream is a proxy project in the same account — install the ones you want, add their block to `providers.json`:

| Upstream | Companion repo | Auth | Format |
|---|---|---|---|
| GitHub Copilot free | `marktantongco/owl-orca-v4` | device flow, Fernet vault | openai |
| Antigravity (Google) | `marktantongco/antigravity-proxy-gateway` | — | anthropic (translated) |
| Kiro (AWS Builder) | `marktantongco/kiro-gateway` | AWS Builder ID OIDC (shim `:8333`) | openai |
| Freebuff DeepSeek | `marktantongco/freebuff-proxy` | multi-token, JA3 stealth `:1455` | openai + anthropic |
| NVIDIA NIM | `marktantongco/nim-to-openai-proxy` | — | translated, `:60008` |
| OmniProxy smart router | `marktantongco/omniproxy-ai-smart-router` | — | NadirClaw cost-aware |
| Novada residential | `marktantongco/Novada-proxy` | MCP | 403-blocked last resort |

**Discipline note:** use your own accounts, respect each upstream's ToS, and let the quota guard keep you inside the lines. The stack manages *your* quotas — it doesn't evade limits.

## 7.3 The agent ecosystem

- **agent-reach** — social channel fan-out (twitter / reddit / opencli) so an owl-orca-backed agent can publish. Configure once: `agent-reach configure twitter-cookies` (Cookie-Editor header string) and the channel unlocks for `twitter-cli`/`rdt`
- **skills.sh stack** — the 19-skill research/execution suite (superpowers, impeccable, find-skills, github-researcher, ...) documented in `download/skills-manifest.json` of the companion ecosystem
- **OpenCode wiring file** — `~/.config/opencode/opencode.json` (Installation §1.5)

## 7.4 Integration contract (what to build against)

Stable surface — anything built against these keeps working across v6.x:

- `POST /v1/chat/completions` — OpenAI request/response shapes, OpenAI-shaped errors
- `POST /v1/messages` — Anthropic shapes with live SSE translation
- `GET /v1/models` — model roster (1h cache)
- `GET /healthz` — observability contract (stats, hacks, breakers)
- `/admin/*` — operator surface (reload, breakers, routing, quota, cache)
- Response headers: `X-Owl-Orca-Route`, `X-Owl-Orca-Provider`, `X-Owl-Orca-Plan`, `X-Owl-Orca-Cache` — the provenance trail

**Extension point for new channel types:** add a provider block (Configuration §3.4) or a pack (Packs §4.4). No router code changes needed for either.

---

**Next:** [Roadmap & Synergy →](08-roadmap-synergy.md)
