# Rigorous Terragrunt benchmarks. See README.md for methodology.
BIN   ?= /workspace/tg-check/bin
TOFU  ?= $(BIN)/tofu
UNITS ?= 30 100
export BENCH_BIN=$(BIN) TOFU

.PHONY: help mirror overhead cache cache-registry summary floci clean
help:
	@echo "make mirror          one-time: build local provider mirror (needs network)"
	@echo "make overhead        warm 'run --all plan' overhead suite, offline (UNITS='$(UNITS)')"
	@echo "make cache           cold 'run --all init' cache suite, offline mirror (30 units)"
	@echo "make cache-registry  cache suite against registry.opentofu.org (network, noisy)"
	@echo "make summary         mean/stddev/min/max tables from results/*.json"
	@echo "make floci           start Floci (local AWS emulator) for BACKEND=floci"
mirror:         ; bench/mirror.sh
overhead:       ; python3 bench/run.py overhead --units $(UNITS) --backend $(or $(BACKEND),local)
cache:          ; python3 bench/run.py cache --units 30
cache-registry: ; python3 bench/run.py cache --units 30 --registry
summary:        ; python3 bench/summary.py results
floci:          ; docker compose up -d floci && docker compose run --rm floci-setup
clean:          ; rm -rf work/overhead-* work/cache-*
