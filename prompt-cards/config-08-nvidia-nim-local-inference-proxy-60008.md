<!-- owl-orca v6.2 prompt-card | kind: config | NVIDIA NIM Local Inference Proxy (:60008) -->
# NVIDIA NIM Local Inference Proxy (:60008)

**Rank #8 of the top-10 battle-tested upstream configurations**
**Origin:** marktantongco/nim-to-openai-proxy (F9 port reallocation verified)
**Battle evidence:** Verified standing in the v4.9 reconciliation: reallocated from :60004 to :60008 to clear the mempalace collision; runs Llama-3.1-70B/405B and Nemotron behind an OpenAI translator.

## What it is

Self-hosted NIM containers exposed through a translation proxy so the router treats them identically to cloud providers — the medium tier's zero-egress-dependent candidate and the natural landing for GPU-equipped deploys.

## The config (copy-ready)

```yaml
nvidia-nim: { base_url: http://127.0.0.1:60008/v1,
              translate_from: nvidia_nim,
              models: [meta/llama-3.1-70b, meta/llama-3.1-405b,
                        nvidia/nemotron],
              cost_tier: medium, breaker: 5/60/1 }
```

## Why it earns its rank

Local inference in the candidate set de-risks the whole ladder: when every cloud route is gated, the ladder can still terminate at a local model instead of a virtual echo — the same shape as our virtu-echo terminal fallback but with real weights.

## Rebuild instruction (paste to any coding agent)

> Rebuild this routing configuration in the owl-orca gateway: implement
> **NVIDIA NIM Local Inference Proxy (:60008)** exactly as specified above. Source lineage: marktantongco/nim-to-openai-proxy (F9 port reallocation verified).
> Verify with a probe battery before declaring done; wire config changes
> through the atomic-rename + SIGHUP hot-apply path so no TCP drop occurs.
