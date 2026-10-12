<!-- owl-orca v6.2 prompt-card | kind: hack | H9 graftcp seccomp only_socks5 (only-socket trap) -->
# H9: graftcp seccomp only_socks5 (only-socket trap)

**One of the top-10 upstream speed/resilience hacks**
**Proof:** wrapper persisted; per-invocation 10M; upstream 2,584 stars.

## The technique

Traps only socket syscalls (vs full ptrace) with black/white IP lists so the egress tunnel is opt-in per process. Any tool inherits stealth egress without code changes or a resident daemon.

## Rebuild instruction (paste to any coding agent)

> Implement hack H9 (**graftcp seccomp only_socks5 (only-socket trap)**) in the owl-orca router with the exact
> semantics described above. The proof bar: wrapper persisted; per-invocation 10M; upstream 2,584 stars.
> Do not declare done until the same proof passes in-process.
