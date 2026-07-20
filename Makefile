SHELL := /usr/bin/env bash

VERSION := 0.1.0
PROJECT_MANAGER := $(CURDIR)/bin/devin-desktop-manager
INSTALLER := $(CURDIR)/scripts/install-manager
MANAGER ?= $(HOME)/.local/bin/devin-desktop-manager
APP ?= $(HOME)/.local/bin/devin-desktop
DIST_DIR ?= $(CURDIR)/dist
BATS ?= bats
SHELLCHECK ?= shellcheck
BASHCOV ?= bashcov
COVERAGE_MINIMUM ?= 90
COVERAGE_DIR ?= coverage

.DEFAULT_GOAL := help

.PHONY: help install-manager link link-dev install status check update rollback \
	set-defaults doctor run app-version test lint verify package release-check \
	coverage uninstall uninstall-yes clean

help:
	@printf '%s\n' \
		'Devin Desktop Manager $(VERSION)' \
		'' \
		'Install and lifecycle:' \
		'  make install         Copy the manager, then install official stable Devin Desktop' \
		'  make install-manager Atomically copy only the manager into ~/.local/bin' \
		'  make status          Show the active and rollback releases' \
		'  make check           Check the official stable channel without changing files' \
		'  make update          Download and transactionally activate the latest release' \
		'  make rollback        Swap the active and previous releases' \
		'  make set-defaults    Claim Devin/Windsurf URL and workspace defaults explicitly' \
		'  make doctor          Validate the installation and desktop integration' \
		'  make run             Launch Devin Desktop in the foreground' \
		'  make app-version     Show the upstream application build information' \
		'  make uninstall       Interactively remove manager-owned installed files' \
		'  make uninstall-yes   Remove manager-owned installed files without prompting' \
		'' \
		'Development and release:' \
		'  make link-dev        Symlink the manager source for local development' \
		'  make test            Run the offline Bats behavior suite' \
		'  make coverage        Run tests with at least 90% line coverage' \
		'  make lint            Run Bash syntax and ShellCheck validation' \
		'  make verify          Run lint and the complete offline test suite' \
		'  make package         Build a deterministic source archive and SHA256SUMS' \
		'  make release-check   Verify tests, version consistency, and release packaging'

install-manager:
	@"$(INSTALLER)" "$(PROJECT_MANAGER)" "$(MANAGER)"

link: link-dev

link-dev:
	@"$(INSTALLER)" --link "$(PROJECT_MANAGER)" "$(MANAGER)"

install: install-manager
	@"$(MANAGER)" install

status check update rollback set-defaults doctor:
	@"$(MANAGER)" $@

run:
	@"$(APP)"

app-version:
	@"$(APP)" --version

test:
	@"$(BATS)" tests

coverage:
	@rm -f -- "$(COVERAGE_DIR)/.resultset.json"
	@COVERAGE_MINIMUM="$(COVERAGE_MINIMUM)" COVERAGE_DIR="$(COVERAGE_DIR)" \
		COVERAGE_COMMAND_NAME=bats-suite \
		"$(BASHCOV)" -- "$(BATS)" tests
	@./scripts/check-coverage \
		"$(COVERAGE_DIR)/.resultset.json" "$(COVERAGE_MINIMUM)"

lint:
	@bash -n "$(PROJECT_MANAGER)" scripts/*
	@"$(SHELLCHECK)" "$(PROJECT_MANAGER)" scripts/*

verify: lint test

package:
	@./scripts/package-release "$(VERSION)" "$(DIST_DIR)"

release-check: verify coverage
	@./scripts/release-check "$(VERSION)"
	@./scripts/package-release "$(VERSION)" "$(DIST_DIR)"

uninstall:
	@"$(MANAGER)" uninstall

uninstall-yes:
	@"$(MANAGER)" uninstall --yes

clean:
	@rm -rf -- "$(DIST_DIR)" "$(COVERAGE_DIR)"
