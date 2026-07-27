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
override MAKE_PATH := $(value PATH)
override MAKE_DIST_DIR := $(value DIST_DIR)
override MAKE_COVERAGE_MINIMUM := $(value COVERAGE_MINIMUM)
override MAKE_COVERAGE_DIR := $(value COVERAGE_DIR)
export MAKE_BASH MAKE_BATS MAKE_SHELLCHECK MAKE_BASHCOV MAKE_APP MAKE_HOME
export PROJECT_ROOT APP_DEFAULT
export MAKE_XDG_CONFIG_HOME MAKE_XDG_DATA_HOME MAKE_XDG_STATE_HOME
export MAKE_XDG_CACHE_HOME MAKE_XDG_RUNTIME_DIR MAKE_TMPDIR MAKE_DIST_DIR
export MAKE_COVERAGE_MINIMUM MAKE_COVERAGE_DIR MAKE_PATH
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
bash_path=$$(resolve_executable BASH "$$MAKE_BASH") || exit $$?; \
env_path=$$(resolve_executable ENV env) || exit $$?
endef

define PREPARE_SCRIPT_RUNNER
$(RESOLVE_BASH); \
run_script() { \
  BASH_ENV= ENV= LC_ALL=C TZ=UTC \
  HOME="$$MAKE_HOME" PATH="$$MAKE_PATH" \
  XDG_CONFIG_HOME="$$MAKE_XDG_CONFIG_HOME" \
  XDG_DATA_HOME="$$MAKE_XDG_DATA_HOME" \
  XDG_STATE_HOME="$$MAKE_XDG_STATE_HOME" \
  XDG_CACHE_HOME="$$MAKE_XDG_CACHE_HOME" \
  XDG_RUNTIME_DIR="$$MAKE_XDG_RUNTIME_DIR" TMPDIR="$$MAKE_TMPDIR" \
  PREFLIGHT_BATS="$$MAKE_BATS" PREFLIGHT_SHELLCHECK="$$MAKE_SHELLCHECK" \
  PREFLIGHT_BASHCOV="$$MAKE_BASHCOV" \
  "$$env_path" -u BASHOPTS -u SHELLOPTS -u PS4 -u CDPATH \
    -u RUBYOPT -u RUBYLIB -u BUNDLE_GEMFILE -u BUNDLE_PATH \
    -u GIT_CONFIG -u GIT_CONFIG_GLOBAL -u GIT_CONFIG_SYSTEM -u GIT_CONFIG_COUNT \
    -u TAR_OPTIONS -u GZIP -u ENV -u BASH_ENV \
    "$$bash_path" --noprofile --norc -c \
    'while read -r _ _ fn; do unset -f "$$fn" 2>/dev/null || true; done < <(declare -F); exec "$$@"' \
    make-bootstrap "$$bash_path" --noprofile --norc "$$@"; \
}
endef

define RUN_PREFLIGHT
run_script "$$PROJECT_ROOT/scripts/preflight" $(1) --project-root "$$PROJECT_ROOT"
endef

define RESOLVE_APP
app="$$MAKE_APP"; \
if [ "$$APP_DEFAULT" = 1 ]; then app=$$MAKE_HOME/.local/bin/devin-desktop; fi; \
case "$$app" in \
	/*) ;; \
	'') printf '%s\n' '$(1): error: APP is not an executable file: empty path' >&2; exit 1 ;; \
	*[!\ -~]*) printf '%s\n' '$(1): error: APP contains control characters' >&2; exit 1 ;; \
	*) printf '%s\n' "$(1): error: APP must be an absolute path: $$app" >&2; exit 1 ;; \
esac; \
if [ ! -f "$$app" ] || [ ! -x "$$app" ]; then \
	printf '%s\n' "$(1): error: APP is not an executable file: $$app" >&2; exit 1; \
fi
endef

define ACQUIRE_MANAGER_PUBLICATION_LOCKS
publication_parent=$$MAKE_HOME/.local/bin; \
state_home=$${MAKE_XDG_STATE_HOME:-$$MAKE_HOME/.local/state}; \
publication_lock=$$publication_parent/.devin-desktop-manager.publication.lock; \
lifecycle_lock=$$state_home/devin-desktop-manager.lock; \
legacy_lock=$$MAKE_HOME/.local/opt/devin-desktop/.manager.lock; \
current_uid=$$(id -u); \
mkdir -p -- "$$publication_parent" "$$state_home"; \
validate_lock_parent() { \
	path=$$1; label=$$2; \
	[ -d "$$path" ] && [ ! -L "$$path" ] || { printf '%s\n' "$$label parent must be a non-symbolic directory: $$path" >&2; return 1; }; \
	owner=$$(stat -c '%u' -- "$$path") || return 1; \
	permissions=$$(stat -c '%a' -- "$$path") || return 1; \
	[ "$$owner" = "$$current_uid" ] || { printf '%s\n' "$$label parent must be owned by the current user: $$path" >&2; return 1; }; \
	other=$${permissions#$${permissions%?}}; before_other=$${permissions%?}; group=$${before_other#$${before_other%?}}; \
	[ $$((group & 2)) -eq 0 ] && [ $$((other & 2)) -eq 0 ] || { printf '%s\n' "$$label parent must not be writable by other users: $$path" >&2; return 1; }; \
}; \
validate_lock_parent "$$publication_parent" 'manager publication'; \
validate_lock_parent "$$state_home" 'manager lifecycle'; \
validate_lock_path() { \
	path=$$1; allowed_links=$$2; \
	[ -f "$$path" ] && [ ! -L "$$path" ] || { printf '%s\n' "install: error: unsafe manager lock path: $$path" >&2; return 1; }; \
	metadata=$$(stat -c '%u:%h' -- "$$path") || return 1; owner=$${metadata%:*}; links=$${metadata#*:}; \
	[ "$$owner" = "$$current_uid" ] || { printf '%s\n' "install: error: unsafe manager lock path: $$path" >&2; return 1; }; \
	case ",$$allowed_links," in *",$$links,"*) ;; *) printf '%s\n' "install: error: unsafe manager lock path: $$path" >&2; return 1 ;; esac; \
}; \
validate_lock_identity() { \
	fd=$$1; path=$$2; allowed_links=$$3; \
	validate_lock_path "$$path" "$$allowed_links" || return 1; \
	path_identity=$$(stat -Lc '%d:%i:%u:%F:%h' -- "$$path") || return 1; \
	fd_identity=$$(stat -Lc '%d:%i:%u:%F:%h' -- "/proc/self/fd/$$fd") || return 1; \
	[ "$$path_identity" = "$$fd_identity" ] || { printf '%s\n' "install: error: manager lock descriptor $$fd does not match: $$path" >&2; return 1; }; \
}; \
create_lock() { path=$$1; [ -e "$$path" ] || [ -L "$$path" ] || (set -C; : >"$$path") 2>/dev/null || { [ -e "$$path" ] || return 1; }; validate_lock_path "$$path" 1; }; \
create_lock "$$publication_lock"; create_lock "$$lifecycle_lock"; \
exec 9<>"$$publication_lock"; \
validate_lock_identity 9 "$$publication_lock" 1; \
flock -n 9 || { printf '%s\n' 'install: error: another manager publication operation is active; do not delete the lock file; rerun make install after it exits' >&2; exit 1; }; \
validate_lock_identity 9 "$$publication_lock" 1; \
exec 8<>"$$lifecycle_lock"; \
validate_lock_identity 8 "$$lifecycle_lock" 1; \
flock -n 8 || { printf '%s\n' 'install: error: another manager lifecycle operation is active; do not delete the lock file; rerun make install after it exits' >&2; exit 1; }; \
validate_lock_identity 8 "$$lifecycle_lock" 1; \
legacy_option=; \
if [ -e "$$legacy_lock" ] || [ -L "$$legacy_lock" ]; then \
	validate_lock_path "$$legacy_lock" 1,2; \
	exec 7<>"$$legacy_lock"; \
	validate_lock_identity 7 "$$legacy_lock" 1,2; \
	flock -n 7 || { printf '%s\n' 'install: error: another legacy manager lifecycle operation is active; do not delete the lock file; rerun make install after it exits' >&2; exit 1; }; \
	validate_lock_identity 7 "$$legacy_lock" 1,2; \
	legacy_option='--legacy-lock-fd 7'; \
fi
endef

define DO_LINT
shellcheck_path=$$(resolve_executable SHELLCHECK "$$MAKE_SHELLCHECK") || exit $$?; \
run_script -n "$$PROJECT_ROOT/bin/devin-desktop-manager" scripts/*; \
LC_ALL=C TZ=UTC "$$shellcheck_path" \
	"$$PROJECT_ROOT/bin/devin-desktop-manager" scripts/*
endef

define DO_TEST
bats_path=$$(resolve_executable BATS "$$MAKE_BATS") || exit $$?; \
run_script "$$bats_path" tests
endef

define DO_COVERAGE
bats_path=$$(resolve_executable BATS "$$MAKE_BATS") || exit $$?; \
bashcov_path=$$(resolve_executable BASHCOV "$$MAKE_BASHCOV") || exit $$?; \
rm -f -- "$$MAKE_COVERAGE_DIR/.resultset.json"; \
HOME="$$MAKE_HOME" LC_ALL=C TZ=UTC COVERAGE_MINIMUM="$$MAKE_COVERAGE_MINIMUM" \
	COVERAGE_DIR="$$MAKE_COVERAGE_DIR" COVERAGE_COMMAND_NAME=bats-suite \
	"$$bashcov_path" -- "$$bats_path" tests; \
run_script "$$PROJECT_ROOT/scripts/check-coverage" \
	"$$MAKE_COVERAGE_DIR/.resultset.json" "$$MAKE_COVERAGE_MINIMUM"
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
	@$(PREPARE_SCRIPT_RUNNER); \
	run_script "$$PROJECT_ROOT/scripts/preflight" install-manager; \
	destination=$$MAKE_HOME/.local/bin/devin-desktop-manager; \
	run_script "$$PROJECT_ROOT/scripts/install-manager" --canonical \
		"$$PROJECT_ROOT/bin/devin-desktop-manager" "$$destination"

link: link-dev

link-dev:
	@$(PREPARE_SCRIPT_RUNNER); \
	run_script "$$PROJECT_ROOT/scripts/preflight" install-manager; \
	destination=$$MAKE_HOME/.local/bin/devin-desktop-manager; \
	run_script "$$PROJECT_ROOT/scripts/install-manager" --link --canonical \
		"$$PROJECT_ROOT/bin/devin-desktop-manager" "$$destination"

install:
	@$(PREPARE_SCRIPT_RUNNER); \
	$(call RUN_PREFLIGHT,install); \
	destination=$$MAKE_HOME/.local/bin/devin-desktop-manager; \
	if [ -e "$$destination" ] || [ -L "$$destination" ]; then \
		manageable=false; \
		if [ -L "$$destination" ]; then \
			resolved_destination=$$(readlink -f -- "$$destination" 2>/dev/null || true); \
			[ "$$resolved_destination" = "$$PROJECT_ROOT/bin/devin-desktop-manager" ] && manageable=true; \
			[ "$$manageable" = true ] || grep -Fqx 'readonly MANAGER_ID="io.github.newbpydev.devin-desktop-manager"' "$$resolved_destination" 2>/dev/null && manageable=true; \
		else \
			grep -Fqx 'readonly MANAGER_ID="io.github.newbpydev.devin-desktop-manager"' "$$destination" 2>/dev/null && manageable=true; \
		fi; \
		[ "$$manageable" = true ] || { printf '%s\n' "install: error: refusing to replace unrelated path: $$destination" >&2; exit 1; }; \
	fi; \
	$(ACQUIRE_MANAGER_PUBLICATION_LOCKS); \
	run_script "$$PROJECT_ROOT/scripts/install-manager" --canonical \
		--publication-lock-fd 9 --lifecycle-lock-fd 8 $$legacy_option \
		"$$PROJECT_ROOT/bin/devin-desktop-manager" "$$destination"; \
	if ! run_script "$$PROJECT_ROOT/bin/devin-desktop-manager" \
		--publication-lock-fd 9 --lifecycle-lock-fd 8 $$legacy_option install; then \
		printf '%s\n' 'install: error: manager installation succeeded, but application installation did not; recoverable state remains; rerun make install to resume' >&2; \
		exit 1; \
	fi

status check update rollback set-defaults doctor:
	@$(PREPARE_SCRIPT_RUNNER); \
	$(call RUN_PREFLIGHT,manager-$@); \
	run_script "$$PROJECT_ROOT/bin/devin-desktop-manager" $@

run:
	@$(PREPARE_SCRIPT_RUNNER); \
	$(call RUN_PREFLIGHT,application); \
	$(call RESOLVE_APP,run); \
	HOME="$$MAKE_HOME" exec "$$app"

app-version:
	@$(PREPARE_SCRIPT_RUNNER); \
	$(call RUN_PREFLIGHT,application); \
	$(call RESOLVE_APP,app-version); \
	HOME="$$MAKE_HOME" exec "$$app" --version

test:
	@$(PREPARE_SCRIPT_RUNNER); \
	$(call RUN_PREFLIGHT,test); \
	$(DO_TEST)

coverage:
	@$(PREPARE_SCRIPT_RUNNER); \
	$(call RUN_PREFLIGHT,coverage); \
	$(DO_COVERAGE)

lint:
	@$(PREPARE_SCRIPT_RUNNER); \
	$(call RUN_PREFLIGHT,lint); \
	$(DO_LINT)

verify:
	@$(PREPARE_SCRIPT_RUNNER); \
	$(call RUN_PREFLIGHT,verify); \
	$(DO_LINT); \
	$(DO_TEST)

package:
	@$(PREPARE_SCRIPT_RUNNER); \
	$(call RUN_PREFLIGHT,package); \
	run_script "$$PROJECT_ROOT/scripts/package-release" "$(VERSION)" "$$MAKE_DIST_DIR"

release-check:
	@$(PREPARE_SCRIPT_RUNNER); \
	$(call RUN_PREFLIGHT,release-check); \
	$(DO_LINT); \
	$(DO_COVERAGE); \
	run_script "$$PROJECT_ROOT/scripts/release-check" "$(VERSION)"; \
	run_script "$$PROJECT_ROOT/scripts/package-release" "$(VERSION)" "$$MAKE_DIST_DIR"

uninstall:
	@$(PREPARE_SCRIPT_RUNNER); \
	$(call RUN_PREFLIGHT,manager-uninstall); \
	run_script "$$PROJECT_ROOT/bin/devin-desktop-manager" uninstall

uninstall-yes:
	@$(PREPARE_SCRIPT_RUNNER); \
	$(call RUN_PREFLIGHT,manager-uninstall-yes); \
	run_script "$$PROJECT_ROOT/bin/devin-desktop-manager" uninstall --yes

clean:
	@$(PREPARE_SCRIPT_RUNNER); \
	$(call RUN_PREFLIGHT,clean); \
	rm -rf -- "$$MAKE_DIST_DIR" "$$MAKE_COVERAGE_DIR"
