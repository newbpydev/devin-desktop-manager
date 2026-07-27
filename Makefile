SHELL := /bin/sh
.SHELLFLAGS := -eu -c

VERSION := 0.1.0
override PROJECT_ROOT := $(realpath $(dir $(firstword $(MAKEFILE_LIST))))
BASH ?= bash
BATS ?= bats
SHELLCHECK ?= shellcheck
BASHCOV ?= bashcov
DIST_DIR ?= dist
COVERAGE_MINIMUM ?= 90
COVERAGE_DIR ?= coverage

ifeq ($(origin APP),undefined)
APP :=
APP_DEFAULT := 1
else
APP_DEFAULT := 0
endif

override MAKE_BASH := $(value BASH)
override MAKE_BATS := $(value BATS)
override MAKE_SHELLCHECK := $(value SHELLCHECK)
override MAKE_BASHCOV := $(value BASHCOV)
override MAKE_APP := $(value APP)
override MAKE_HOME := $(value HOME)
override MAKE_XDG_CONFIG_HOME := $(value XDG_CONFIG_HOME)
override MAKE_XDG_DATA_HOME := $(value XDG_DATA_HOME)
override MAKE_XDG_STATE_HOME := $(value XDG_STATE_HOME)
override MAKE_XDG_CACHE_HOME := $(value XDG_CACHE_HOME)
override MAKE_XDG_RUNTIME_DIR := $(value XDG_RUNTIME_DIR)
override MAKE_TMPDIR := $(value TMPDIR)
override MAKE_DIST_DIR := $(value DIST_DIR)
override MAKE_COVERAGE_MINIMUM := $(value COVERAGE_MINIMUM)
override MAKE_COVERAGE_DIR := $(value COVERAGE_DIR)
export MAKE_BASH MAKE_BATS MAKE_SHELLCHECK MAKE_BASHCOV MAKE_APP MAKE_HOME
export PROJECT_ROOT APP_DEFAULT
export MAKE_XDG_CONFIG_HOME MAKE_XDG_DATA_HOME MAKE_XDG_STATE_HOME
export MAKE_XDG_CACHE_HOME MAKE_XDG_RUNTIME_DIR MAKE_TMPDIR MAKE_DIST_DIR
export MAKE_COVERAGE_MINIMUM MAKE_COVERAGE_DIR
unexport BASH BATS SHELLCHECK BASHCOV APP HOME XDG_CONFIG_HOME XDG_DATA_HOME
unexport XDG_STATE_HOME XDG_CACHE_HOME XDG_RUNTIME_DIR TMPDIR DIST_DIR
unexport COVERAGE_MINIMUM COVERAGE_DIR

.DEFAULT_GOAL := help

.PHONY: help install-manager link link-dev install status check update rollback \
	set-defaults doctor run app-version test lint verify package release-check \
	coverage uninstall uninstall-yes clean

VALID_GOALS := help install-manager link link-dev install status check update \
	rollback set-defaults doctor run app-version test lint verify package \
	release-check coverage uninstall uninstall-yes clean

ifneq ($(origin MANAGER),undefined)
$(error usage: MANAGER is no longer supported; checkout targets always use bin/devin-desktop-manager)
endif

ifneq ($(words $(MAKECMDGOALS)),0)
ifneq ($(words $(MAKECMDGOALS)),1)
$(error usage: exactly one explicit Make goal is allowed)
endif
ifneq ($(filter-out $(VALID_GOALS),$(MAKECMDGOALS)),)
$(error usage: unknown Make goal; run 'make help')
endif
endif

define RESOLVE_EXECUTABLE
resolve_executable() { \
	label=$$1; value=$$2; \
	case "$$value" in \
		'') printf '%s\n' "$$label: invalid executable identity: empty value" >&2; return 2 ;; \
		*[!\ -~]*) printf '%s\n' "$$label: invalid executable identity: control characters are not allowed" >&2; return 2 ;; \
		/*) ;; \
		*/*) printf '%s\n' "$$label: invalid executable identity: use a command name or absolute path" >&2; return 2 ;; \
	esac; \
	candidate=$$(command -v "$$value" 2>/dev/null) || { \
		printf '%s\n' "$$label: executable not found: $$value" >&2; return 1; \
	}; \
	case "$$candidate" in \
		/*) ;; \
		*) printf '%s\n' "$$label: executable did not resolve to an absolute file: $$value" >&2; return 2 ;; \
	esac; \
	if [ ! -f "$$candidate" ] || [ ! -x "$$candidate" ]; then \
		printf '%s\n' "$$label: resolved path is not an executable file: $$candidate" >&2; return 1; \
	fi; \
	directory=$${candidate%/*}; basename=$${candidate##*/}; \
	physical_directory=$$(CDPATH= cd -P -- "$$directory" 2>/dev/null && pwd -P) || { \
		printf '%s\n' "$$label: cannot resolve executable directory: $$directory" >&2; return 1; \
	}; \
	printf '%s/%s\n' "$$physical_directory" "$$basename"; \
}
endef

define RESOLVE_BASH
$(RESOLVE_EXECUTABLE); \
bash_path=$$(resolve_executable BASH "$$MAKE_BASH") || exit $$?
endef

define CALLER_ENVIRONMENT
HOME="$$MAKE_HOME" \
XDG_CONFIG_HOME="$$MAKE_XDG_CONFIG_HOME" \
XDG_DATA_HOME="$$MAKE_XDG_DATA_HOME" \
XDG_STATE_HOME="$$MAKE_XDG_STATE_HOME" \
XDG_CACHE_HOME="$$MAKE_XDG_CACHE_HOME" \
XDG_RUNTIME_DIR="$$MAKE_XDG_RUNTIME_DIR" \
TMPDIR="$$MAKE_TMPDIR"
endef

define RUN_MANAGER
$(RESOLVE_BASH); \
$(CALLER_ENVIRONMENT) BASH_ENV= ENV= "$$bash_path" --noprofile --norc \
	"$$PROJECT_ROOT/bin/devin-desktop-manager" $(1)
endef

help:
	@printf '%s\n' \
		'Devin Desktop Manager $(VERSION)' \
		'' \
		'Install and lifecycle:' \
		'  make help            Show this command reference' \
		'  make install         Copy the manager, then install official stable Devin Desktop' \
		'  make install-manager Atomically copy only the manager into ~/.local/bin' \
		'  make link            Alias for link-dev' \
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
		'  make release-check   Verify tests, version consistency, and release packaging' \
		'  make clean           Remove generated coverage and release output'

install-manager:
	@$(RESOLVE_BASH); \
	destination=$$MAKE_HOME/.local/bin/devin-desktop-manager; \
	$(CALLER_ENVIRONMENT) BASH_ENV= ENV= "$$bash_path" --noprofile --norc \
		"$$PROJECT_ROOT/scripts/install-manager" \
		"$$PROJECT_ROOT/bin/devin-desktop-manager" "$$destination"

link: link-dev

link-dev:
	@$(RESOLVE_BASH); \
	destination=$$MAKE_HOME/.local/bin/devin-desktop-manager; \
	$(CALLER_ENVIRONMENT) BASH_ENV= ENV= "$$bash_path" --noprofile --norc \
		"$$PROJECT_ROOT/scripts/install-manager" --link \
		"$$PROJECT_ROOT/bin/devin-desktop-manager" "$$destination"

install: install-manager
	@$(call RUN_MANAGER,install)

status check update rollback set-defaults doctor:
	@$(call RUN_MANAGER,$@)

run:
	@app="$$MAKE_APP"; \
	if [ "$$APP_DEFAULT" = 1 ]; then app=$$MAKE_HOME/.local/bin/devin-desktop; fi; \
	case "$$app" in \
		/*) ;; \
		'') printf '%s\n' 'run: error: APP is not an executable file: empty path' >&2; exit 1 ;; \
		*[!\ -~]*) printf '%s\n' 'run: error: APP contains control characters' >&2; exit 1 ;; \
		*) printf '%s\n' "run: error: APP must be an absolute path: $$app" >&2; exit 1 ;; \
	esac; \
	if [ ! -f "$$app" ] || [ ! -x "$$app" ]; then \
		printf '%s\n' "run: error: APP is not an executable file: $$app" >&2; exit 1; \
	fi; \
	$(CALLER_ENVIRONMENT) exec "$$app"

app-version:
	@app="$$MAKE_APP"; \
	if [ "$$APP_DEFAULT" = 1 ]; then app=$$MAKE_HOME/.local/bin/devin-desktop; fi; \
	case "$$app" in \
		/*) ;; \
		'') printf '%s\n' 'app-version: error: APP is not an executable file: empty path' >&2; exit 1 ;; \
		*[!\ -~]*) printf '%s\n' 'app-version: error: APP contains control characters' >&2; exit 1 ;; \
		*) printf '%s\n' "app-version: error: APP must be an absolute path: $$app" >&2; exit 1 ;; \
	esac; \
	if [ ! -f "$$app" ] || [ ! -x "$$app" ]; then \
		printf '%s\n' "app-version: error: APP is not an executable file: $$app" >&2; exit 1; \
	fi; \
	$(CALLER_ENVIRONMENT) exec "$$app" --version

test:
	@$(RESOLVE_BASH); \
	bats_path=$$(resolve_executable BATS "$$MAKE_BATS") || exit $$?; \
	$(CALLER_ENVIRONMENT) BASH_ENV= ENV= \
		"$$bash_path" --noprofile --norc "$$bats_path" tests

coverage:
	@$(RESOLVE_BASH); \
	bats_path=$$(resolve_executable BATS "$$MAKE_BATS") || exit $$?; \
	bashcov_path=$$(resolve_executable BASHCOV "$$MAKE_BASHCOV") || exit $$?; \
	rm -f -- "$$MAKE_COVERAGE_DIR/.resultset.json"; \
	$(CALLER_ENVIRONMENT) COVERAGE_MINIMUM="$$MAKE_COVERAGE_MINIMUM" \
		COVERAGE_DIR="$$MAKE_COVERAGE_DIR" \
		COVERAGE_COMMAND_NAME=bats-suite \
		"$$bashcov_path" -- "$$bats_path" tests; \
	$(CALLER_ENVIRONMENT) BASH_ENV= ENV= "$$bash_path" --noprofile --norc \
		"$$PROJECT_ROOT/scripts/check-coverage" \
		"$$MAKE_COVERAGE_DIR/.resultset.json" "$$MAKE_COVERAGE_MINIMUM"

lint:
	@$(RESOLVE_BASH); \
	shellcheck_path=$$(resolve_executable SHELLCHECK "$$MAKE_SHELLCHECK") || exit $$?; \
	$(CALLER_ENVIRONMENT) BASH_ENV= ENV= "$$bash_path" --noprofile --norc -n \
		"$$PROJECT_ROOT/bin/devin-desktop-manager" scripts/*; \
	$(CALLER_ENVIRONMENT) "$$shellcheck_path" \
		"$$PROJECT_ROOT/bin/devin-desktop-manager" scripts/*

verify: lint test

package:
	@$(RESOLVE_BASH); \
	$(CALLER_ENVIRONMENT) BASH_ENV= ENV= "$$bash_path" --noprofile --norc \
		"$$PROJECT_ROOT/scripts/package-release" "$(VERSION)" "$$MAKE_DIST_DIR"

release-check: lint coverage
	@$(RESOLVE_BASH); \
	$(CALLER_ENVIRONMENT) BASH_ENV= ENV= "$$bash_path" --noprofile --norc \
		"$$PROJECT_ROOT/scripts/release-check" "$(VERSION)"; \
	$(CALLER_ENVIRONMENT) BASH_ENV= ENV= "$$bash_path" --noprofile --norc \
		"$$PROJECT_ROOT/scripts/package-release" "$(VERSION)" "$$MAKE_DIST_DIR"

uninstall:
	@$(call RUN_MANAGER,uninstall)

uninstall-yes:
	@$(call RUN_MANAGER,uninstall --yes)

clean:
	@rm -rf -- "$$MAKE_DIST_DIR" "$$MAKE_COVERAGE_DIR"
