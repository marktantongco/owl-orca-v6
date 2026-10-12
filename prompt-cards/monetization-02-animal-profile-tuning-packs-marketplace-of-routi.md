<!-- owl-orca v6.2 prompt-card | kind: monetization | Animal-Profile Tuning Packs (marketplace of routing personalities) -->
# Animal-Profile Tuning Packs (marketplace of routing personalities)

**Rank #2 of the top-5 wild monetization ideas**

## Concept

The seven-animal taxonomy is a config file (promptc-os-rules.json: keywords, cost tiers, fallback ladders, mode descriptions). Sell tuning packs as JSON products: 'Legal Eagle' (owl keywords for contract review), 'Traction Rabbit' (growth-hacking speed vocab), 'Research Owl Deep' — each pack is rules + breaker policy + a mode-prompt set, hot-applied via SIGHUP with zero downtime.

## Why it works

The v13 tuning session proved the mechanism: +15 speed keys reclassified a misrouted prompt class instantly, no restart. Pack installs are the same atomic-rename + SIGHUP path — a two-second 'install' with rollback by file swap.

## Mechanics

- pack format: rules-delta + breaker-delta + prompt pack (validated JSON)
- install = atomic_write + orca-reload.sh; uninstall = swap back
- preview mode: POST /v1/prompt/classify with pack overlay (dry classification)
- registry: signed packs, semantic-versioned, each with probe batteries

## Risk

Bad packs degrade routing silently — require the classify-probe battery (6/6 pass) as a gate before activation.

## Build instruction (paste to any coding agent)

> Build the minimum viable version of **Animal-Profile Tuning Packs (marketplace of routing personalities)** on the owl-orca v6.2
> stack. Mechanics to implement: pack format: rules-delta + breaker-delta + prompt pack (validated JSON); install = atomic_write + orca-reload.sh; uninstall = swap back; preview mode: POST /v1/prompt/classify with pack overlay (dry classification); registry: signed packs, semantic-versioned, each with probe batteries.
> Respect the risk constraint: Bad packs degrade routing silently — require the classify-probe battery (6/6 pass) as a gate before activation.
