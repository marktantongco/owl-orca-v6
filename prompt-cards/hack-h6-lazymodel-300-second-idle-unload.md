<!-- owl-orca v6.2 prompt-card | kind: hack | H6 LazyModel 300-second idle unload -->
# H6: LazyModel 300-second idle unload

**One of the top-10 upstream speed/resilience hacks**
**Proof:** mempalace-lazy boots with loaded=false — zero fixed memory until first tool call.

## The technique

Embedding models (MiniLM/embeddinggemma-300m) load on first use and unload after 300 idle seconds. The memory plane holds nothing resident by default: a 128M unit became 0M fixed cost, 300M peak on demand.

## Rebuild instruction (paste to any coding agent)

> Implement hack H6 (**LazyModel 300-second idle unload**) in the owl-orca router with the exact
> semantics described above. The proof bar: mempalace-lazy boots with loaded=false — zero fixed memory until first tool call.
> Do not declare done until the same proof passes in-process.
