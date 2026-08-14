# EdgeJudge umbrella. Run from the repository root.
SHELL := /bin/bash
.DEFAULT_GOAL := help

BOOTSTRAP := ./scripts/bootstrap.sh
WEIGHTS := ./scripts/download_weights.sh
SMOKE := ./scripts/smoke_test.sh
DRIVER := ./scripts/driver.sh
NAV := ./scripts/nav.sh

.PHONY: help setup setup-full code envs sdk weights weights-full smoke smoke-imports smoke-edge driver nav serve

help:
	@echo "EdgeJudge"
	@echo "  make setup          Init code deps, sim+perception envs, Go2 SDK"
	@echo "  make setup-full     setup + full OmniVLA conda env"
	@echo "  make weights        OmniVLA-edge + SAM2 + HF perception caches"
	@echo "  make weights-full   + omnivla-original"
	@echo "  make smoke          Offline stop-judge on examples/sample.png"
	@echo "  make driver         Native Go2 ROS 2 driver (needs ROBOT_IP in .env)"
	@echo "  make nav            go2_nav.py wizard"
	@echo "  make serve          Full OmniVLA ZeroMQ server (GPU host)"
	@echo "Non-interactive nav: ./scripts/nav.sh run --nav edge --sam 'Human.'"
	@echo "See SETUP.md and README.md."

setup:
	$(BOOTSTRAP) --all

setup-full:
	$(BOOTSTRAP) --all --full

code:
	$(BOOTSTRAP) --code

envs:
	$(BOOTSTRAP) --envs

sdk:
	$(BOOTSTRAP) --sdk

weights:
	$(WEIGHTS) --edge

weights-full:
	$(WEIGHTS) --full

smoke:
	$(SMOKE)

smoke-imports:
	$(SMOKE) --imports

smoke-edge:
	$(SMOKE) --edge

driver:
	$(DRIVER)

nav:
	$(NAV) $(NAV_ARGS)

serve:
	$(NAV) serve $(SERVE_ARGS)
