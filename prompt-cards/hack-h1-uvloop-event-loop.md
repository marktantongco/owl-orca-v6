<!-- owl-orca v6.2 prompt-card | kind: hack | H1 uvloop Event Loop -->
# H1: uvloop Event Loop

**One of the top-10 upstream speed/resilience hacks**
**Proof:** uvloop.install() at router + forward-proxy + virtu-echo boot; selftest PASS.

## The technique

Replaces the asyncio C selector loop with libuv: 2-4x throughput on connection-heavy proxies. One line, zero API changes — the cheapest win in the stack and the reason the 9-hack series starts here.

## Rebuild instruction (paste to any coding agent)

> Implement hack H1 (**uvloop Event Loop**) in the owl-orca router with the exact
> semantics described above. The proof bar: uvloop.install() at router + forward-proxy + virtu-echo boot; selftest PASS.
> Do not declare done until the same proof passes in-process.
