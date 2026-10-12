<!-- owl-orca v6.2 prompt-card | kind: config | Per-Tier Circuit-Breaker Policy with Decay + Hot-Apply -->
# Per-Tier Circuit-Breaker Policy with Decay + Hot-Apply

**Rank #3 of the top-10 battle-tested upstream configurations**
**Origin:** owl-orca v6.1 (utils/circuit_breaker.py + POST /admin/breakers)
**Battle evidence:** Proven live today: hot-apply changed kiro-free 5/60/1 to 2/30/1 mid-flight; the breaker tripped at the NEW threshold; SIGHUP file-driven apply restored 7/45/1 with state preserved; :60001 socket never dropped.

## What it is

One lock-free breaker per upstream (atomic int fails, time.monotonic, no awaits inside mutation) with a four-tier policy: cheap trips fast (3 fails) and recovers fast (45s, decay 2) because alternatives abound; medium is the proven 5/60s; premium is patient (7 fails, 90s) because lockout hurts; expensive trips fast and stays out 300s for quota protection. v6.1 adds live policy edits: POST /admin/breakers or edit providers.json + SIGHUP — threshold changes land on live breakers, state (fails/opened_at) preserved, invariant repair re-trips a CLOSED breaker whose fails already exceed a lowered threshold.

## The config (copy-ready)

```yaml
breaker_policy per_cost_tier:
  cheap:     { threshold: 3,  cooldown: 45,  decay: 2 }
  medium:    { threshold: 5,  cooldown: 60,  decay: 1 }
  premium:   { threshold: 7,  cooldown: 90,  decay: 1 }
  expensive: { threshold: 3,  cooldown: 300, decay: 1 }
hot-apply: POST /admin/breakers {provider: {threshold, cooldown, decay}}
```

## Why it earns its rank

Anti-ban and quota protection need asymmetric recovery: free-tier upstreams are plentiful so fast trip/fast recovery maximizes availability, while paid/residential pools must lock out long to avoid wasting quota on a failing route. The state-preserving hot-apply means threshold tuning never costs a TCP drop.

## Rebuild instruction (paste to any coding agent)

> Rebuild this routing configuration in the owl-orca gateway: implement
> **Per-Tier Circuit-Breaker Policy with Decay + Hot-Apply** exactly as specified above. Source lineage: owl-orca v6.1 (utils/circuit_breaker.py + POST /admin/breakers).
> Verify with a probe battery before declaring done; wire config changes
> through the atomic-rename + SIGHUP hot-apply path so no TCP drop occurs.
