<!-- owl-orca v6.2 prompt-card | kind: hack | H3 StreamRacer first-SUCCESS race (bounded 5, cancel losers) -->
# H3: StreamRacer first-SUCCESS race (bounded 5, cancel losers)

**One of the top-10 upstream speed/resilience hacks**
**Proof:** THE bug real traffic found today: FIRST_COMPLETED decided on gated racers resolving as None instantly, cancelling live racers mid-connect. Fixed: the wait loops until a real session completes. 10/10 races, 9 winner-cancels in battery.

## The technique

Fire up to 5 candidates, first byte wins, losers cancelled with half-open sockets closed. The v6.1 semantics fix separates completion from success — a gated or failing racer completing early must never cancel a live racer that is about to win. This is the difference between a race that works in demos and one that works under breaker pressure.

## Rebuild instruction (paste to any coding agent)

> Implement hack H3 (**StreamRacer first-SUCCESS race (bounded 5, cancel losers)**) in the owl-orca router with the exact
> semantics described above. The proof bar: THE bug real traffic found today: FIRST_COMPLETED decided on gated racers resolving as None instantly, cancelling live racers mid-connect. Fixed: the wait loops until a real session completes. 10/10 races, 9 winner-cancels in battery.
> Do not declare done until the same proof passes in-process.
