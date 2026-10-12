# 8 · Roadmap & Synergy

**Goal:** where this goes (three horizons), and a concrete adaptation analysis for the classic PCI-era proxy-stack patterns (Nginx / HAProxy / Squid / Keepalived / ICAP tokenization) that owl-orca can borrow from — plus the boundaries worth respecting.

---

## 8.1 Three horizons

| Horizon | Theme | Items | Expected outcome |
|---|---|---|---|
| **H1 · Sharpen** | weeks | semantic response cache (embedding-similarity hits → 0-token completions) · pack exchange format (signed, shareable profiles) · agent-reach channel fan-out | repeat traffic gets materially cheaper; packs become portable assets |
| **H2 · Harden** | months | HA pair with floating VIP (Keepalived/VRRP pattern) · key vaulting at the egress layer (ICAP-style last-mile swap) · egress policy packs | reloads survive node failure; client apps stop holding real keys |
| **H3 · Scale** | year | multi-region router mesh (routers racing routers) · local model pool as tier −1 (Ollama/vLLM lane) · pack marketplace economy | latency/cost compound downward while the operator surface stays one curl |

Every horizon lands through doors that already exist: the SIGHUP reload, the probe-gated pack, and the race.

## 8.2 Role mapping: PCI proxy stack → owl-orca

The classic stack assigns one job per box. Owl-Orca already implements the same jobs in one process — the mapping shows what to borrow:

| PCI stack role | owl-orca equivalent | Borrow next |
|---|---|---|
| **Nginx** — inbound TLS/WAF/rate-limit | router `:60001` + guardrails + 1 rps | real WAF rule packs (as packs, probe-gated) |
| **HAProxy** — L7 LB, `httpchk`, weighted round-robin, stats page | StreamRacer + weight/EMA ordering + `/healthz` | active/passive pair + HAProxy-style stats `:8404` surface |
| **Squid** — forward proxy, egress control, caching | forward proxy `:60000` + response cache + egress `:1455` | egress allow-list packs; cache promotion rules |
| **Keepalived + Ansible** — HA VIP + reproducible deploy | single-file installer + snapshots | VRRP-style VIP for a two-node router pair |
| **TokenShield (ICAP)** — mid-tier tokenize/detokenize | Fernet vault for upstream tokens | reference-token vaulting at egress (H2) |

## 8.3 Five concrete synergies (ranked by leverage)

1. **Semantic cache = Squid cache, but for prompts.** Same miss/hit economics, different key. A hash-keyed response cache already ships (P1); similarity keying is the H1 upgrade. Every hit is a 0-token, 0-latency completion.
2. **Key vaulting = TokenShield, applied to your own keys.** Apps send reference tokens (`tok_openai_xxx`); the egress layer swaps real credentials last-mile. Client compromise stops leaking provider keys.
3. **HA pair = HAProxy + Keepalived, applied to the router.** Two owl-orca nodes, one virtual `:60001`. SIGHUP reloads already survive; this makes them survive *node loss*.
4. **Egress governance = Squid ACL discipline.** Per-domain, per-app egress rules as packs — WAF-grade control with the pack system's rollback semantics.
5. **Ansible-style reproducibility is already exceeded.** One-file install + snapshot + `apply-all` recovery beats playbook sprawl; the missing piece is only multi-node orchestration.

## 8.4 Adoption queue (if you build this)

1. `isCreditCardField` → `isCacheablePrompt()` on the cache layer (fork the tokenizer idea, keep the pattern)
2. Egress-layer vault: swap reference tokens at `:1455`
3. Two-node router pair with a floating VIP; systemd + VRRP
4. Pack exchange format with signatures (H1 item that unlocks the marketplace)

## 8.5 Boundaries (the honest part)

- **Provider diversity is the legitimate strategy; same-provider account pooling is not.** Racing five *different* free tiers you own is resilience engineering. Pooling accounts of one provider to multiply a free tier is ToS abuse — this stack doesn't do it, and the quota guard exists to keep you honest.
- The borrow list above is patterns (caching, vaulting, HA, egress ACLs) — all legitimate infrastructure practice. "Free unlimited tokens" schemes beyond your own entitlements are out of scope.
- Local model lanes (Ollama/vLLM, H3) are the *fully legitimate* cost-collapse path: your hardware, your terms.

---

**Next:** [Monetization Ideas →](09-monetization-ideas.md)
