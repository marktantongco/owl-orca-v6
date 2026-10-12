<!-- owl-orca v6.2 prompt-card | kind: monetization | Usage-Metered Animal-Ladder API (billing sidecar as the product) -->
# Usage-Metered Animal-Ladder API (billing sidecar as the product)

**Rank #1 of the top-5 wild monetization ideas**

## Concept

Sell the router itself as a metered API: the forward-proxy billing sidecar already writes a JSONL ledger (per-tier rate limits, usage metering, atomic rotation). Wrap it in Stripe metering and price per tier: cheap $0.10/1k requests, medium $0.40, premium $1.20 — the classifier justifies the spread because tier assignment is deterministic and auditable.

## Why it works

The ledger, tier gates and breaker SLAs are already built; the marginal cost of commerce is a webhook. Tier-aware pricing is the exact thing the animal ladder was tuned to enable — 'pay rabbit prices for rabbit prompts.'

## Mechanics

- billing-ledger.jsonl (Stages 1,2,7) -> nightly meter aggregation
- tier_prices.json per cost tier + overage policy
- per-key rate limits enforced by the existing forward proxy
- breaker snapshots as SLA evidence (uptime per tier)

## Risk

Metering disputes require response-level audit trails; keep ledger entries append-only and hash-chained before charging.

## Build instruction (paste to any coding agent)

> Build the minimum viable version of **Usage-Metered Animal-Ladder API (billing sidecar as the product)** on the owl-orca v6.2
> stack. Mechanics to implement: billing-ledger.jsonl (Stages 1,2,7) -> nightly meter aggregation; tier_prices.json per cost tier + overage policy; per-key rate limits enforced by the existing forward proxy; breaker snapshots as SLA evidence (uptime per tier).
> Respect the risk constraint: Metering disputes require response-level audit trails; keep ledger entries append-only and hash-chained before charging.
