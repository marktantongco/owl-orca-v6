<!-- owl-orca v6.2 prompt-card | kind: config | GooseRelay Zstd Quota Discipline (20k/day shared) -->
# GooseRelay Zstd Quota Discipline (20k/day shared)

**Rank #9 of the top-10 battle-tested upstream configurations**
**Origin:** Kianmhz/GooseRelayVPN — 1,425 stars, verified; zstd compression 65% payload reduction
**Battle evidence:** Ecosystem-verified quota economics: 20,000 requests/day SHARED per Google account; zstd streaming compression stretches effective volume roughly 65%; key hygiene (64-hex, 0600, never shared) documented.

## What it is

A relay that multiplexes free upstream quotas over compressed tunnels. The quota math is the discipline: per-account daily ceilings are shared across all consumers, so breakers must trip BEFORE the ceiling, not after.

## The config (copy-ready)

```yaml
goose-client.json: { zstd: true, tunnel_key: <64-hex 0600> }
goose zstd quota: 20,000 req/day shared per Google account
breaker guidance: expensive 3/300 — trip fast, stay out 300s
```

## Why it earns its rank

The purest expression of why 'expensive' tier breakers lock out for 300 seconds: shared quota burned by a failing route is quota every other consumer loses. Fast trip + long lockout converts a shared tragedy-of-the-commons into a scheduled resource.

## Rebuild instruction (paste to any coding agent)

> Rebuild this routing configuration in the owl-orca gateway: implement
> **GooseRelay Zstd Quota Discipline (20k/day shared)** exactly as specified above. Source lineage: Kianmhz/GooseRelayVPN — 1,425 stars, verified; zstd compression 65% payload reduction.
> Verify with a probe battery before declaring done; wire config changes
> through the atomic-rename + SIGHUP hot-apply path so no TCP drop occurs.
