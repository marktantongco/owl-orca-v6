<!-- owl-orca v6.2 prompt-card | kind: hack | H8 httpx singleton pool (HTTP/2, 100 conns, Chrome UA) -->
# H8: httpx singleton pool (HTTP/2, 100 conns, Chrome UA)

**One of the top-10 upstream speed/resilience hacks**
**Proof:** selftest singleton PASS; all upstream races share one pool.

## The technique

One AsyncClient with HTTP/2 multiplexing and a 100-connection ceiling for every upstream: no per-request TCP+TLS handshakes, browser-grade User-Agent, and a hard ceiling that keeps fd exhaustion impossible under race fan-out.

## Rebuild instruction (paste to any coding agent)

> Implement hack H8 (**httpx singleton pool (HTTP/2, 100 conns, Chrome UA)**) in the owl-orca router with the exact
> semantics described above. The proof bar: selftest singleton PASS; all upstream races share one pool.
> Do not declare done until the same proof passes in-process.
