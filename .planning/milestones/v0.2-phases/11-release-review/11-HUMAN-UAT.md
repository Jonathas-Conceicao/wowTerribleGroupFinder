---
status: complete
phase: 11-release-review
source: [11-CONTEXT.md, 11-01-SUMMARY.md, 11-02-SUMMARY.md]
started: 2026-11-14T00:00:00Z
updated: 2026-11-15T12:00:00Z
---

## Current Test

[complete: README and CHANGELOG approved, screenshots kept for v0.2, 2026-11-15]

## Tests

### 1. Re-take tgf_lfg_window.png
expected: `Media/Screenshots/tgf_lfg_window.png` shows the Browse tab with v0.2 rows (region flags after names, row icons), ideally with a row tooltip showing the region line.
result: skipped
reason: the author keeps the current screenshots for v0.2 (2026-11-15); agents remind them when a change may need a new one

### 2. Check tgf_lfg_message_config.png
expected: `Media/Screenshots/tgf_lfg_message_config.png` still matches the Messages tab; re-take only if it changed.
result: skipped
reason: as item 1

### 3. New screenshots for the README
expected: Optional: the settings page (Settings > AddOns > TerribleGroupFinder, `tgf_settings.png`), item level on a player tooltip and an item tooltip (`tgf_ilvl.png`), the character sheet Item Level row, the Inspect window value. Save in `Media/Screenshots/`, then add the image tags to README.md (only for files that exist).
result: skipped
reason: as item 1

### 4. README review
expected: README.md carries a v0.2 draft (item level spots, region flags, row icon tooltips, Dynamic refresh, settings page, `/tgf settings`, `/tgf set`, `/tgf ilvl`, `/tgf region`). Review and rewrite as wished.
result: pass
note: reviewed as a diff against v0.1.0 (2026-11-15); `{ilvl}` added to the key table

### 5. CHANGELOG review
expected: The `## v0.2.0` section at the top of CHANGELOG.md (first `## ` heading, published by the release workflow) is a draft. Review and rewrite as wished.
result: pass
note: the author's rule (2026-11-15): entries clear to a player, relative to the last release; the gear score line was dropped (never relevant to players)

### 6. Version
expected: Confirm v0.2.0 (TOC keeps `## Version: @project-version@`; tag `v0.2.0` on `main` after the squash merge, per PROJECT.md Git Workflow). Not done by agents.
result: pass

### 7. Deferred v0.1 cleanup list
expected: Question: fold the list (05-HUMAN-UAT item 11) into this release now, or keep it deferred.
result: pass
note: kept deferred (2026-11-15)

### 8. Phase confirmation
expected: The author's confirmation closes Phase 11 and the milestone close-out (push, squash-merge, tag).
result: pass
note: the author ran /gsd-complete-milestone (2026-11-15); pushing still waits for their explicit OK

## Summary

total: 8
passed: 5
issues: 0
pending: 0
skipped: 3
blocked: 0

## Gaps
