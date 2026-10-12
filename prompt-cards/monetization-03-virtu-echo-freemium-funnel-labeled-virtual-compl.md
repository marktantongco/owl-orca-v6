<!-- owl-orca v6.2 prompt-card | kind: monetization | Virtu-Echo Freemium Funnel (labeled virtual completions as demo) -->
# Virtu-Echo Freemium Funnel (labeled virtual completions as demo)

**Rank #3 of the top-5 wild monetization ideas**

## Concept

virtu-echo already answers every request when real upstreams are gated, self-labeling which animal routed it. Ship a free tier that IS virtu-echo: unlimited, honest, labeled virtual completions with mode-flavored guidance — then upsell real upstream quality per tier. The label itself is the sales pitch: users see 'animal=rabbit tier=cheap' and want the real rabbit model behind it.

## Why it works

The funnel costs 64M of memory and zero upstream quota. Free users experience the full routing surface (classification, headers, SSE) so the paid switch flips one providers.json entry — no new client, no behavior change, same endpoint.

## Mechanics

- free tier: virtu-echo (rate-limited by forward proxy)
- paid: identical API, upstreams un-gated (API keys per plan)
- conversion surface: X-Owl-Orca-Provider header + labeled content
- capped free usage enforced at tier simple_query rate limits

## Risk

Must clearly label virtual answers as virtual (already done — the label is in the content) to avoid charging for canned text.

## Build instruction (paste to any coding agent)

> Build the minimum viable version of **Virtu-Echo Freemium Funnel (labeled virtual completions as demo)** on the owl-orca v6.2
> stack. Mechanics to implement: free tier: virtu-echo (rate-limited by forward proxy); paid: identical API, upstreams un-gated (API keys per plan); conversion surface: X-Owl-Orca-Provider header + labeled content; capped free usage enforced at tier simple_query rate limits.
> Respect the risk constraint: Must clearly label virtual answers as virtual (already done — the label is in the content) to avoid charging for canned text.
