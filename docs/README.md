# Owl-Orca v6 Wiki — The Walkthrough Guides

Every page here is **copy-ready**: the commands are meant to be pasted verbatim into a terminal on a fresh Linux box. Start at the top and walk down — the order is the install order.

| # | Guide | What you'll accomplish |
|---|---|---|
| 1 | [Installation & Setup](01-installation.md) | a running stack, verified, with your first routed completion |
| 2 | [Architecture Deep-Dive](02-architecture.md) | you understand every layer and where its code lives |
| 3 | [Configuration Reference](03-configuration.md) | you can add providers, retune breakers, hot-apply anything |
| 4 | [Tuning Packs](04-packs.md) | you install, author, and recover packs safely |
| 5 | [Operations Runbook](05-operations-runbook.md) | you can run this thing day-to-day (and survive 3 a.m.) |
| 6 | [Validation & Testing](06-validation.md) | you can prove every claim this repo makes |
| 7 | [Integrations](07-integrations.md) | you can wire clients, upstreams, and the agent ecosystem |
| 8 | [Roadmap & Synergy](08-roadmap-synergy.md) | you know where this goes next and what it borrows from proxy-stack patterns |
| 9 | [Monetization Ideas](09-monetization-ideas.md) | you can turn the stack into revenue with tools that exist today |

**The 60-second version of this whole wiki:**

```bash
bash install.sh                              # install to ~/.owl-orca-v6
python3 ops/audit_v6.py                      # expect: 51/51 PASS
~/.owl-orca-v6/bin/orca-health-check.sh      # services + hack selftest
curl -s http://127.0.0.1:60001/healthz | jq  # live router
```

Need the ops runbook as a document? It ships in this repo: [`owl-orca-v6-ops-runbook.html`](owl-orca-v6-ops-runbook.html). The upstream research playbook is here too: [`owl-orca-v6.1-upstream-playbook.docx`](owl-orca-v6.1-upstream-playbook.docx).

---

## Want these pages in the official GitHub Wiki tab?

This `docs/` folder is the source of truth. The Wiki tab needs a one-time click (GitHub provisions its git backend only when the first page is saved — there is no API for it), then one copy-paste publishes everything:

1. Open the **Wiki** tab → **Create the first page** → save any placeholder.
2. From a clone of this repository:

```bash
git clone https://github.com/marktantongco/owl-orca-v6.wiki.git wiki-live
cp docs/*.md wiki-live/
sed -i 's#src="../images/#src="https://raw.githubusercontent.com/marktantongco/owl-orca-v6/main/images/#' \
  wiki-live/09-monetization-ideas.md
cd wiki-live
git add -A && git commit -m "wiki: publish the 10-page walkthrough" && git push
```

The pages cross-link to each other by filename, so the wiki navigates exactly like this folder — and the `sed` line re-points the concept-art images at the raw URLs hosted in the main repo.
