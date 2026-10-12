<!-- owl-orca v6.2 prompt-card | kind: hack | H4 Circuit-breaker hot-apply (no restart, no TCP drop) -->
# H4: Circuit-breaker hot-apply (no restart, no TCP drop)

**One of the top-10 upstream speed/resilience hacks**
**Proof:** POST /admin/breakers changed kiro 5/60/1 to 2/30/1 live; tripped at new threshold; SIGHUP path applied 7/45/1 with state preserved; healthz 200 through both.

## The technique

Threshold/cooldown/decay edits land on live breakers via the admin API or SIGHUP reload. State survives by design — only the thresholds change — and invariant repair re-trips a CLOSED breaker whose fails already exceed a lowered threshold, so a known-bad upstream cannot absorb one more request after a policy tightening.

## Rebuild instruction (paste to any coding agent)

> Implement hack H4 (**Circuit-breaker hot-apply (no restart, no TCP drop)**) in the owl-orca router with the exact
> semantics described above. The proof bar: POST /admin/breakers changed kiro 5/60/1 to 2/30/1 live; tripped at new threshold; SIGHUP path applied 7/45/1 with state preserved; healthz 200 through both.
> Do not declare done until the same proof passes in-process.
