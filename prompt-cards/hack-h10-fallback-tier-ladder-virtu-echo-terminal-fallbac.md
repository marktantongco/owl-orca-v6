<!-- owl-orca v6.2 prompt-card | kind: hack | H10 fallback_tier ladder + virtu-echo terminal fallback -->
# H10: fallback_tier ladder + virtu-echo terminal fallback

**One of the top-10 upstream speed/resilience hacks**
**Proof:** Tactical proof: eagle prompt, premium+medium gated, ladder landed on freebuff-mock with route=fallback_tier header; 6 fallbacks, 0 virtu deaths; with all tiers dead, virtu-echo answered every OpenCode run with a labeled completion.

## The technique

The rules-declared animal-to-tier fallback ladder is now consumed at both selection time (config-level gaps) and race time (breaker-gated tiers), terminating in a virtual completion backend that self-labels which animal routed it. Clients get a real, honest, labeled answer instead of a naked 502 — and the label doubles as the observability probe for the whole ladder.

## Rebuild instruction (paste to any coding agent)

> Implement hack H10 (**fallback_tier ladder + virtu-echo terminal fallback**) in the owl-orca router with the exact
> semantics described above. The proof bar: Tactical proof: eagle prompt, premium+medium gated, ladder landed on freebuff-mock with route=fallback_tier header; 6 fallbacks, 0 virtu deaths; with all tiers dead, virtu-echo answered every OpenCode run with a labeled completion.
> Do not declare done until the same proof passes in-process.
