SHELL := /usr/bin/env bash

.PHONY: help check syntax lint status review regression codex review-qualification network-qualification

help:
	@printf '%s\n' \
		'NetHunter Toolkit — Development Workflow' \
		'' \
		'Commands:' \
		'  make verify   Run Bash, ShellCheck and isolated integration tests' \
		'  make check    Run the Git-dependent development check' \
		'  make syntax   Check Bash syntax for project shell files' \
		'  make lint     Run ShellCheck for project shell files' \
		'  make status   Show development repository status' \
		'  make regression Run the runtime regression gate' \
		'  make codex     Run the Codex development workflow'

check:
	@./tools/check.sh

syntax:
	@python tools/validate.py --syntax-only

lint:
	@python tools/validate.py --lint-only

verify:
	@python tools/validate.py

status:
	@printf '%s\n' 'NetHunter Toolkit — Development Status' ''
	@printf 'Branch : '; git symbolic-ref --short HEAD
	@printf 'HEAD   : '; git rev-parse --short HEAD
	@printf 'Version: '; \
		awk -F= '/^TOOLKIT_VERSION=/{gsub(/"/,"",$$2); print $$2}' \
			config/version.conf
	@printf 'State  : '; \
		awk -F= '/^TOOLKIT_STATUS=/{gsub(/"/,"",$$2); print $$2}' \
			config/version.conf
	@printf '%s\n' '' 'Worktree:'
	@git status --short
	@if [ -z "$$(git status --porcelain)" ]; then \
		printf '%s\n' 'CLEAN'; \
	fi

review:
	@if [ -z "$$REVIEW_SCOPE" ]; then \
		printf '%s\n' 'REVIEW: RED — REVIEW_SCOPE is required' >&2; \
		printf '%s\n' 'Example: REVIEW_SCOPE="modules/10-network.sh lib/network" make review' >&2; \
		exit 1; \
	fi
	@./tools/review.sh --scope $${REVIEW_SCOPE}

regression:
	@./tools/regression.sh

codex:
	@if [ -z "$$REVIEW_SCOPE" ]; then \
		printf '%s\n' 'CODEX: RED — REVIEW_SCOPE is required' >&2; \
		printf '%s\n' 'Example: REVIEW_SCOPE="modules/10-network.sh lib/network" make codex' >&2; \
		exit 1; \
	fi
	@./tools/codex-workflow.sh --scope $${REVIEW_SCOPE}

review-qualification:
	@./tools/review-qualification.sh

network-qualification:
	@./tools/network-qualification.sh

.PHONY: maintenance-test verify
maintenance-test:
	@python tools/test_installation.py
