<!-- owl-orca v6.2 prompt-card | kind: hack | H2 Radix Array Trie (array('I'), 4KB, zero-copy memoryview) -->
# H2: Radix Array Trie (array('I'), 4KB, zero-copy memoryview)

**One of the top-10 upstream speed/resilience hacks**
**Proof:** selftest 1.88 microsecond/lookup; 1,180 nodes in 8,192 bytes.

## The technique

Keyword classification over a flat array('I') trie instead of dict chains: FCNS-packed, grows by doubling, scanned through memoryview slices so no copies. 4KB of resident memory classifies every prompt in under 2 microseconds.

## Rebuild instruction (paste to any coding agent)

> Implement hack H2 (**Radix Array Trie (array('I'), 4KB, zero-copy memoryview)**) in the owl-orca router with the exact
> semantics described above. The proof bar: selftest 1.88 microsecond/lookup; 1,180 nodes in 8,192 bytes.
> Do not declare done until the same proof passes in-process.
