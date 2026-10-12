<!-- owl-orca v6.2 prompt-card | kind: config | OpenRouter Provider-Order Routing (Aggregation Pattern) -->
# OpenRouter Provider-Order Routing (Aggregation Pattern)

**Rank #4 of the top-10 battle-tested upstream configurations**
**Origin:** OpenRouter (openrouter.ai) — commercial aggregator, docs verified in prior research
**Battle evidence:** Publicly operational aggregator routing billions of tokens across providers with per-provider ordering, fallbacks and price/latency/throughput preferences.

## What it is

A single /api/v1/chat/completions endpoint that fans across every provider hosting a model, with routing preferences (price, latency, throughput), explicit provider order/fallback preferences, and usage accounting. The pattern: 'models?provider.order' and routing parameters let the buyer set the tradeoff axis.

## The config (copy-ready)

```yaml
curl https://openrouter.ai/api/v1/chat/completions \
  -d '{ "model": "deepseek/deepseek-chat",
         "providers": { "order": ["DeepInfra","Fireworks"],
                        "allow_fallbacks": true } }'
```

## Why it earns its rank

The commercial proof that cost-aware multi-provider routing is a viable product, not just an ops technique — the same candidate-set-plus-preference model our Tier-0 implements locally with zero egress dependency.

## Rebuild instruction (paste to any coding agent)

> Rebuild this routing configuration in the owl-orca gateway: implement
> **OpenRouter Provider-Order Routing (Aggregation Pattern)** exactly as specified above. Source lineage: OpenRouter (openrouter.ai) — commercial aggregator, docs verified in prior research.
> Verify with a probe battery before declaring done; wire config changes
> through the atomic-rename + SIGHUP hot-apply path so no TCP drop occurs.
