<!-- owl-orca v6.2 prompt-card | kind: config | Kiro Gateway AWS Builder OIDC (Claude upstream) -->
# Kiro Gateway AWS Builder OIDC (Claude upstream)

**Rank #6 of the top-10 battle-tested upstream configurations**
**Origin:** marktantongco/kiro-gateway (kiro-ai-ecosystem, 9 ports: 20128/8333/48321/8330/7890)
**Battle evidence:** Ecosystem-verified: the gateway opens Claude 3.5 Sonnet/Haiku access via AWS Builder ID OIDC; the v6 shim on :8333 documents the hand-off and the real gateway clones in STEP 12.

## What it is

An OIDC device-flow gateway that exchanges a free AWS Builder ID for Claude family models behind an OpenAI-compatible endpoint. In the v6 stack it anchors the medium tier; its breaker policy is 5/60/1 and it carries fallback=true.

## The config (copy-ready)

```yaml
kiro-free: { base_url: http://127.0.0.1:8333/v1,
             format: openai, auth_method: aws_builder_oidc,
             models: [claude-3.5-sonnet-kiro, claude-3-haiku-kiro],
             cost_tier: medium, fallback: true }
```

## Why it earns its rank

The strongest free Claude-class upstream in the verified set, and the medium tier's anchor: when beaver/elephant (systems/consistency) prompts need Claude-grade output, the ladder reaches this first. The 9router lineage around it (Nginx :8330, Mihomo :7890) is the reference topology for multi-account OIDC.

## Rebuild instruction (paste to any coding agent)

> Rebuild this routing configuration in the owl-orca gateway: implement
> **Kiro Gateway AWS Builder OIDC (Claude upstream)** exactly as specified above. Source lineage: marktantongco/kiro-gateway (kiro-ai-ecosystem, 9 ports: 20128/8333/48321/8330/7890).
> Verify with a probe battery before declaring done; wire config changes
> through the atomic-rename + SIGHUP hot-apply path so no TCP drop occurs.
