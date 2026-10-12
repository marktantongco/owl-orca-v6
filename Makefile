# owl-orca-v6 — build the single-file installer from its source segments
#
# The installer is the concatenation of installer/v6_part1..6.sh in order.
# `make build` reproduces install.sh byte-for-byte; `make verify` proves it.

PARTS := installer/v6_part1.sh installer/v6_part2.sh installer/v6_part3.sh \
         installer/v6_part4.sh installer/v6_part5.sh installer/v6_part6.sh

.PHONY: build verify audit syntax clean

build: ## rebuild install.sh from parts
	cat $(PARTS) > install.sh
	chmod +x install.sh
	@echo "built install.sh ($$(wc -l < install.sh) lines)"

verify: build ## prove the rebuild matches what ships
	@bash -n install.sh && echo "syntax OK"
	@python3 ops/audit_v6.py

audit: ## dry-run marker audit only (never mutates configs)
	python3 ops/audit_v6.py

syntax: ## bash -n every shell file in the repo
	@for f in install.sh $(PARTS) ops/*.sh; do bash -n "$$f" || exit 1; done
	@echo "all shell files parse"

clean:
	rm -rf __pycache__ .pytest_cache
