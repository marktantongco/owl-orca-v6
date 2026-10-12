<!-- owl-orca v6.2 prompt-card | kind: hack | H7 lru_cache(1024) classify memoization -->
# H7: lru_cache(1024) classify memoization

**One of the top-10 upstream speed/resilience hacks**
**Proof:** selftest 0.703 ms cold; repeats hit the LRU (cache_info in healthz).

## The technique

The trie classifier is memoized on the prompt string: repeated prompts (retries, title-generation, agents that resend context) skip the scan entirely. Combined with H2 the whole routing decision costs less than one TLS handshake byte.

## Rebuild instruction (paste to any coding agent)

> Implement hack H7 (**lru_cache(1024) classify memoization**) in the owl-orca router with the exact
> semantics described above. The proof bar: selftest 0.703 ms cold; repeats hit the LRU (cache_info in healthz).
> Do not declare done until the same proof passes in-process.
