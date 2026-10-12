<!-- owl-orca v6.2 prompt-card | kind: config | LiteLLM Proxy Fallbacks with allowed_fails + cooldown_time -->
# LiteLLM Proxy Fallbacks with allowed_fails + cooldown_time

**Rank #2 of the top-10 battle-tested upstream configurations**
**Origin:** BerriAI/litellm — 60,977 stars (live API, Oct 2026)
**Battle evidence:** The de-facto industry standard for OpenAI-compatible multi-provider routing; deployed at thousands of companies; config pattern documented in the proxy reliability guide.

## What it is

A Python proxy exposing one OpenAI-compatible endpoint over 100+ providers, with per-model fallback chains, cooldown-based circuit breaking (allowed_fails within cooldown_time then move to next deployment), retries, and wildcard model routing.

## The config (copy-ready)

```yaml
model_list:
  - model_name: gpt-4o
    litellm_params: { model: openai/gpt-4o, api_key: os.environ/OPENAI_KEY }
router_settings:
  num_retries: 3
  fallbacks: [{ 'gpt-4o': ['gpt-4o-mini'] }]
  allowed_fails: 3        # trip after 3 failures
  cooldown_time: 60       # seconds
```

## Why it earns its rank

Battle-tested at massive scale with the same breaker/cooldown/fallback primitives our v6 stack implements — external validation of the per-tier threshold/cooldown design (cheap 3/45s, medium 5/60s, premium 7/90s, expensive 3/300s).

## Rebuild instruction (paste to any coding agent)

> Rebuild this routing configuration in the owl-orca gateway: implement
> **LiteLLM Proxy Fallbacks with allowed_fails + cooldown_time** exactly as specified above. Source lineage: BerriAI/litellm — 60,977 stars (live API, Oct 2026).
> Verify with a probe battery before declaring done; wire config changes
> through the atomic-rename + SIGHUP hot-apply path so no TCP drop occurs.
