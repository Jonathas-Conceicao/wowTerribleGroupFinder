---
status: partial
phase: 05-release-review
source: [05-CONTEXT.md, 05-RESEARCH.md, 05-01-SUMMARY.md, 05-02-SUMMARY.md]
started: 2026-11-11T21:00:00Z
updated: 2026-11-11T23:40:00Z
---

## Current Test

[awaiting the author's review of README.md, CHANGELOG.md and the open decisions below]

## Tests

### 1. README review
expected: README.md was not edited. Suggested changes: drop "sortable by ... gear score" (the sorts are role, level, activity, listed) and the gear score bullet (gear score is off); describe the Messages tab (key buttons, Default button, Auto-send, Auto-invite and the 1 s contact lock); describe the own-listing row with delist, the row tooltip, Needs my role, the hide button, the search box and the icon; mention player location (each row shows the solo player's or the leader's zone, and a group's tooltip shows each member's zone; added in the inserted phase 04.1, after this review was drafted); reword "**Status:** prototype / proof of concept." for a first release (and decide whether CLAUDE.md's "Prototype stage" wording changes too).
result: [pending]

### 2. README screenshots
expected: No screenshots exist in the repo, so the screenshot step was skipped. Add some if wanted before the release.
result: [pending]

### 3. CHANGELOG draft review
expected: Review the `## v0.1.0` section (now with a player location bullet under Added, from the inserted phase 04.1) (first `## ` heading, so the release workflow publishes it). The old `## Unreleased` bootstrap line ("Project bootstrap: TOC, core namespace, install and release scripts.") likely folds into v0.1.0 or goes; left as is, the author edits it.
result: [pending]

### 4. Version
expected: Version 0.1.0, tag `v0.1.0`; the TOC keeps `## Version: @project-version@`. Confirm.
result: [pending]

### 5. Preset migration
expected: Messages.lua keeps `PREVIOUS` / `VERSION` (migration of earlier default presets). For a first release it only affects the author's own saved presets: keep or drop it later.
result: pass — author: no compatibility with the dev build needed; migration dropped (saved texts are kept as saved, missing ones get the defaults)

### 6. Delist behaviour
expected: `Instance:Delist` (UI/Table.lua) calls `C_LFGList.RemoveListing()` directly, while CLAUDE.md says create/update/unlist stays Blizzard's own tab. Accept for v0.1.0, or change later (and adjust CLAUDE.md).
result: [pending]

### 7. LICENSE shipping
expected: `.pkgmeta` excludes `LICENSE`, and install/package scripts do not copy it. Recommendation: ship it (the TOC declares GPL-3.0): drop `LICENSE` from the `.pkgmeta` ignore list and add it to the file set of `scripts/install.ps1` and `scripts/package.ps1`. `.pkgmeta` is unchanged for now.
result: pass — author: ship it; dropped from the `.pkgmeta` ignore list and added to the install / package file set (test zip now 14 entries, LICENSE included)

### 8. Branch names
expected: The current branch is `milestone/v0.1-milestone`; the intended name was `milestone/v0.1-initial-release`. A stray local branch `milestone/v1.0-milestone` also exists. Rename / delete as you decide before the squash-merge to main.
result: pass — author: name doesn't matter, keep `milestone/v0.1-milestone`; the stray `milestone/v1.0-milestone` (fully contained in it) was deleted

### 9. Store publishing
expected: Repository secrets `CF_API_KEY` and `WAGO_API_TOKEN` must be set before the tag push. Whether CurseForge / Wago accept the `forever` game type is only known after the first tag.
result: [pending]

### 10. Playstyle colour
expected: The playstyle line in the row tooltip is green; the ROADMAP said light grey. Your call.
result: [pending] — author: either way; decides after trying it in game (green for now)

### 11. Deferred cleanup items (later milestone)
expected: Tooltip blank-line rules vs UI-SPEC; raw `|cff..` status colours; a hint on a non-leader's own row; feedback for clicks during the lock or lockdown prefill; intro text length; listings during chat lockdown (02 IN-09); triple refresh on show (02 IN-03); header label width-bound (02 IN-05, skipped: a second anchor would move the sort arrow); localisation.
result: [pending]

### 12. In-game checks
expected: Run the pending in-game checks in `.planning/phases/01-gear-score-off-and-release-plumbing/01-HUMAN-UAT.md` (4 pending), `.planning/phases/02-list-foundation/02-HUMAN-UAT.md` (11 pending), `.planning/phases/03-rows-tooltip-and-own-listing/03-HUMAN-UAT.md` (11 pending), `.planning/phases/04-messages-and-contact/04-HUMAN-UAT.md` (11 pending) and `.planning/phases/04.1-player-location/04.1-HUMAN-UAT.md` (8 pending: player location, the zone on each row's second line and in group tooltips): 45 in total. Plus a quick look at this phase's cleanup in game: key buttons still 4 + 3 and never a third row, the example line names a solo player (invite) / a group (request), pasting multi-line text keeps the cursor where it was, the hide hint wording, and no stale status while searching.
result: [pending]

### 13. Phase confirmation
expected: After the above, confirm Phase 5; then close the milestone per PROJECT.md (push the branch, squash-merge into main, tag `v0.1.0`). Not done by agents in this phase.
result: [pending]

## Summary

total: 13
passed: 0
issues: 0
pending: 13
skipped: 0
blocked: 0

## Gaps
