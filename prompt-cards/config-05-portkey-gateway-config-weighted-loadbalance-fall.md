<!-- owl-orca v6.2 prompt-card | kind: config | Portkey Gateway Config: Weighted Loadbalance + Fallback + Cache + Guardrails -->
# Portkey Gateway Config: Weighted Loadbalance + Fallback + Cache + Guardrails

**Rank #5 of the top-10 battle-tested upstream configurations**
**Origin:** Portkey-AI/gateway (production branch README, fetched today: guardrails 7x, fallback, cache, loadbalance)
**Battle evidence:** Open-source AI gateway deployed as a control plane for production LLM traffic; config-led approach (single gateway.json) adopted by teams needing deterministic routing behavior.

## What it is

A TypeScript gateway where one JSON config composes strategies: weighted load balancing across same-model providers, cascading fallbacks on error classes, response caching for identical prompts, request guardrails (injection/failure filters), and per-config retry/timeout policies.

## The config (copy-ready)

```yaml
config: [
  { provider: openai, weight: 0.7,
    on_status: 'error', fallback: anthropic-claude },
  { provider: anthropic, weight: 0.3,
    cache: { mode: 'simple', max_age: 3600 } },
guardrails: [ { id: 'self-harm-input' }, { id: 'prompt-injection' } ]
```

## Why it earns its rank

Validates composing routing, resilience, caching and policy in ONE declarative file — the design shape our providers.json + routes.json pair follows, with the addition that our files hot-apply via SIGHUP without a process restart.

## Rebuild instruction (paste to any coding agent)

> Rebuild this routing configuration in the owl-orca gateway: implement
> **Portkey Gateway Config: Weighted Loadbalance + Fallback + Cache + Guardrails** exactly as specified above. Source lineage: Portkey-AI/gateway (production branch README, fetched today: guardrails 7x, fallback, cache, loadbalance).
> Verify with a probe battery before declaring done; wire config changes
> through the atomic-rename + SIGHUP hot-apply path so no TCP drop occurs.
