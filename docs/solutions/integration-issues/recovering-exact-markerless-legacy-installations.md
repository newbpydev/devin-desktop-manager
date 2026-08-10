---
title: Recovering Exact Markerless Legacy Installations
date: 2026-08-09
category: integration-issues
module: Devin Desktop legacy ownership migration
problem_type: integration_issue
component: tooling
symptoms:
  - "`make update`, `make install`, and `make uninstall` refused a complete initial-manager installation"
  - "`make doctor` reported several integration failures for one recoverable legacy layout"
root_cause: logic_error
resolution_type: code_fix
severity: high
related_components:
  - development_workflow
  - testing_framework
tags:
  - legacy-installation
  - ownership-migration
  - mimeapps
  - fail-closed
  - desktop-integration
  - recovery
---

# Recovering Exact Markerless Legacy Installations

## Problem

The public manager could recover its narrowly recognized markerless 0.1.0
layouts, but it rejected the complete desktop layout created by the initial
manager before ownership sentinels and state were introduced. The affected
mutating lifecycle commands stopped at the shared ownership-migration gate,
leaving a manager-created installation that the manager could neither update
nor uninstall.

## Symptoms

- `make update`, `make install`, and `make uninstall` failed with
  `public 0.1.0 post-link installation could not be safely verified; refusing
  ownership migration`.
- `make doctor` described the legacy desktop entries, icon, MIME declaration,
  and state permissions as separate failures even though they formed one
  internally consistent historical layout.
- Repeating the commands did not change the result because the existing
  classifier had no accepted profile for that layout.

## What Didn't Work

- Re-running `make install` replaced the manager command but then reached the
  same application migration gate. Retrying was useful only after installing
  code with the expanded classifier.
- Treating any manager-looking filename or desktop ID as ownership proof would
  have made the update succeed, but it would also have allowed foreign or
  user-modified files to authorize destructive cleanup.
- Manually creating ownership markers, deleting locks, or editing release
  metadata would bypass the evidence the manager needs to distinguish a
  recoverable installation from a conflict.
- Reusing the public post-link predicate was insufficient because that profile
  deliberately requires manager desktop defaults to be unclaimed, while the
  initial manager legitimately wrote legacy desktop defaults.

## Solution

Classify the complete historical profile before any mutation, and grant
recovery only when every independent ownership signal agrees.

The markerless classifier now separates pre-activation, public post-link,
public stateful, and `initial-complete` profiles
(`bin/devin-desktop-manager:2106-2144`). The initial-manager path validates all
of the following:

1. release inventory, current and optional previous links, cache shape, and
   absent or compatible state;
2. user-owned regular desktop files with exact allowed semantics
   (`bin/devin-desktop-manager:1711-1818`);
3. icon and workspace MIME assets that match the active release
   (`bin/devin-desktop-manager:2031-2067`);
4. every relevant `mimeapps.list` record, including safe desktop-ID shape and
   traceable provenance for manager-looking associations
   (`bin/devin-desktop-manager:1843-2028`); and
5. safe external defaults, which are preserved as the originals rather than
   treated as manager ownership.

Only a complete match becomes `initial-complete`; a near miss records one
bounded reason and observed value and remains refused
(`bin/devin-desktop-manager:2069-2171`). Lifecycle commands then require the
application to be stopped, revalidate under their locks, write the ownership
evidence, and migrate release metadata
(`bin/devin-desktop-manager:2282-2353`).

Integration replacement preserves the classified external defaults, removes
only validated legacy associations and files, verifies the new defaults, and
writes current manager state (`bin/devin-desktop-manager:3435-3469`). Uninstall
uses the same profile evidence to remove the legacy associations before
staging the owned roots (`bin/devin-desktop-manager:5372-5395`).

`doctor` shares the read-only classifier and reports one recoverable Legacy
Installation instead of downstream symptoms; it does not claim ownership
(`bin/devin-desktop-manager:4930-4949`). Mutating commands classify again, so
a layout changed after `doctor` is refused.

## Why This Works

The defect was not a missing force option. It was a missing exact historical
profile in the ownership state machine. The old public post-link
classification treated legacy manager defaults as evidence that the layout
was already claimed or ambiguous, even when the initial manager itself had
created every matching asset.

The fix adds a positive proof for one historically produced shape while
keeping refusal as the default. Ownership follows the intersection of release,
filesystem, desktop semantics, asset, MIME provenance, effective-default,
process, and lock evidence. No single marker-looking artifact can grant
ownership.

Recovery remains transactional. If desktop registration or default
verification fails after ownership metadata is written, the transaction
restores the previous release and desktop state; a retry must revalidate the
remaining legacy evidence before cleanup. The regression suite proves rollback
and retry at `tests/manager.bats:1026-1108`.

## Prevention

- Model every shipped persistent layout as a named state-machine profile
  before changing ownership schemas.
- Use one read-only classifier for diagnosis and mutating commands, but always
  classify again after acquiring lifecycle locks.
- Require complete conjunctive evidence before claiming markerless roots;
  never infer ownership from a filename, desktop key, or association alone.
- Validate all untrusted record fields before branching on whether they appear
  manager-related, and map diagnostic fragments through bounded safe
  vocabularies (`bin/devin-desktop-manager:1843-1901`).
- Preserve safe external defaults explicitly and prove legacy association
  removal without rewriting unrelated MIME ordering
  (`tests/manager.bats:997-1024`).
- Cover the canonical profile and near misses: current-only and
  current-plus-previous releases, evicted cache, absent state, altered desktop
  semantics, foreign ownership, malformed MIME data, running application,
  interruption, retry, rollback, repeated update, and repeated uninstall
  (`tests/manager.bats:614-1190`).
- Keep container portability evidence separate from native desktop acceptance;
  the repository's focused portability runner exercises the recovery path
  without claiming launcher or desktop-environment parity.

## Related Issues

- [Behavior-Preserving Simplification for Security-Sensitive Bash](../best-practices/behavior-preserving-simplification-for-security-sensitive-bash.md)
- [Legacy installation recovery workflow](../../user-workflows-test-plans/legacy-installation-recovery-user-workflow-test.md)
- [Legacy installation recovery workorder](../../workorders/legacy-installation-recovery-issues-workorder.md)

No matching GitHub issue was found when this learning was captured.
