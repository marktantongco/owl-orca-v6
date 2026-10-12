<!-- owl-orca v6.2 prompt-card | kind: config | Tier-0 Classify + Cost-Tier Candidate Sets + First-SUCCESS Race -->
# Tier-0 Classify + Cost-Tier Candidate Sets + First-SUCCESS Race

**Rank #1 of the top-10 battle-tested upstream configurations**
**Origin:** owl-orca v6.1 router (marktantongco/owl-orca-v4 lineage)
**Battle evidence:** Proven live today: 10/10 OpenCode requests classified (rabbit/owl/eagle/beaver/dolphin all correct), per-tier breaker differentiation reproduced on a fresh install, 0.02-0.05 ms classification latency.

## What it is

A radix-trie keyword classifier (Tier-0) assigns every prompt to one of seven animal modes, each mapped to a cost tier (cheap/medium/premium). The tier selects the candidate upstream set; a bounded race (max 5 racers, first byte wins, losers cancelled) decides the winner INSIDE the tier. A rules-declared fallback_tier ladder walks adjacent tiers when a whole tier is breaker-gated, terminating at a virtual completion backend so clients never see a naked 502.

## The config (copy-ready)

```yaml
cost_logic: simple_query -> [copilot-free, antigravity-free, freebuff-deepseek]
            medium_query -> [copilot-free, antigravity-free, freebuff-deepseek, nvidia-nim]
            complex_query -> [kiro-free, nvidia-nim, antigravity-free]
fallback_tier: { eagle: medium, owl: medium, beaver: cheap, ... }
terminal fallback: virtu-echo :60009 (labeled virtual completions)
```

## Why it earns its rank

It resolves the cost-vs-latency contradiction register: cost tiers prevent a $40/M token model from answering a 'quick prototype' prompt, while the race keeps first-byte latency at the fastest healthy upstream. The v6.1 first-SUCCESS wait fixed the original FIRST_COMPLETED poisoning bug where gated candidates resolved instantly as None and cancelled live racers mid-connect.

## Rebuild instruction (paste to any coding agent)

> Rebuild this routing configuration in the owl-orca gateway: implement
> **Tier-0 Classify + Cost-Tier Candidate Sets + First-SUCCESS Race** exactly as specified above. Source lineage: owl-orca v6.1 router (marktantongco/owl-orca-v4 lineage).
> Verify with a probe battery before declaring done; wire config changes
> through the atomic-rename + SIGHUP hot-apply path so no TCP drop occurs.
