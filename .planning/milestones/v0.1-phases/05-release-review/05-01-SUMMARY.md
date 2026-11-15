---
phase: 05-release-review
plan: 01
subsystem: cleanup
tags: [cleanup, comments, docs]
requirements: [REL-04]
key-files:
  modified: [UI/Table.lua, UI/Widgets.lua, UI/InPlace.lua, Messages.lua, Core.lua, CLAUDE.md]
metrics:
  completed: 2026-11-11
---

# Phase 5 Plan 01: Code Cleanup Summary

Dead code removed, cheap review fixes applied, comments and CLAUDE.md made present-tense and accurate; stylua clean and all four smoke modes at 0 failed.

## Done

- Widgets: `W.Line` deleted.
- Table: `row.item` removed (`row.listing` kept); `scrollView` local in `BuildList`; `VoiceLabels()` cached; `HoveredRow()` read after the `band:IsVisible()` guard; searching branch clears status text and `shownIDs`; hide hint reads "use the hide button to show"; header comment and `D-19` comment reworded.
- InPlace: `searching()` / `failed()` are false while `ns.UsingPreview()`.
- Messages: key buttons wrap at most once (stock 4 + 3); example uses the first sample of the preset's kind (`Sample()`); pasted newlines keep the cursor (ASCII prefix only); migration comments reworded.
- Core: `ns.GEAR_SCORE` comment without version or `.planning` path.
- CLAUDE.md: hidden without (X), GearScore line (off behind `ns.GEAR_SCORE`), Widgets GS colours note, Table sort list and Your GS note, `Media/Textures/` line, release.bat line (secrets, changelog section). The Messages line already named keys, Auto-invite and the lock, so it is unchanged.

## Skipped

- `ForEachFrame` kept: `HoveredRow` / `RefreshTooltip` call it.
- 02 IN-05 (header label width-bound) skipped: not a two-anchor change (the sort arrow is anchored to the text edge).
- Out of scope items (D-05), the `PREVIOUS` / `VERSION` migration and `Delist`'s `C_LFGList.RemoveListing()` left as is.

## Harness edits (outside the repo, not committed)

- `ItemOf` fallback returns `fr.item or fr.listing`.
- `--attach` search-state block: `ns.state.preview` off while searching, on again afterwards; new checks that `searching()` / `failed()` are false in preview and that searching clears status text and shown IDs.

## Verification

- `stylua --check .` clean; default, `--gs`, `--fallback`, `--attach` each `SUMMARY: 0 failed`.
- Planning-reference grep over shipped Lua/XML: no hits. README.md, CHANGELOG.md, .pkgmeta and the TOC unchanged.
- Version: TOC keeps `## Version: @project-version@` (0.1.0, tag `v0.1.0`); nothing to edit.

## Deviations from Plan

None - plan executed as written.

## Commits

- 780d083 refactor(05-01): remove dead code and tidy the table, source flags and status
- 6fdca92 fix(05-01): key buttons wrap once, example by kind, paste keeps the cursor
- (CLAUDE.md commit, see git log)

## Self-Check: PASSED
