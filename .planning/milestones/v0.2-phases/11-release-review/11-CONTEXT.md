# Phase 11: Release Review - Context

**Gathered:** 2026-11-14
**Status:** Ready for planning
**Mode:** Fixed procedure (PROJECT.md → Milestone Close-out); no discuss needed

<domain>
## Phase Boundary

Close-out of milestone v0.2 per PROJECT.md → Milestone Close-out, in order: (1) code cleanup, (2) README screenshots, (3) version, (4) changelog draft, (5) author review. Output: v0.2.0 clean, documented and ready for the author's approval to ship. No new features.

</domain>

<decisions>
## Implementation Decisions

### Procedure (locked, PROJECT.md)
1. Code cleanup: remove duplication / dead code / scaffolding added during the milestone (e.g. `Region.R.MarkupFor` if only the smoke harness uses it — update the harness instead; harness-only exports like `UI.sheetRow` may stay if documented as test hooks); strip every mention of in-milestone bugs from code and doc comments, README.md and CLAUDE.md (the character sheet taint story, review finding IDs like CR-01 / WR-02 in code comments, "prototype" wording for shipped features); no behaviour change; `stylua .`
2. README screenshots: the README describes v0.1 screens; v0.2 changed the Browse rows (flags, icons) and adds the settings page, item level spots. Screenshots can only be taken in game by the author → list exactly which screenshots to re-take / add, as an author item (do not fabricate images); update README text for the new features (item level spots, settings page, Dynamic refresh, region flags, `/tgf settings`) only as a DRAFT for the author's review
3. Version: TOC keeps `## Version: @project-version@`; confirm v0.2.0; the TOC load list matches the shipped file set (Settings.lua, ItemLevel.lua, ItemLevelUI.lua, Region.lua, UI/Motion.lua, UI/SettingsPanel.lua present; GearScore.lua gone); `scripts/package.ps1` builds a zip that contains the flag textures (`Media/Textures/flag_us.tga`, `flag_au.tga`) and the new files
4. Changelog draft: a new `## v0.2.0` section at the top of `CHANGELOG.md` from the net changes against tag `v0.1.0` (one-line summary, then Added / Changed / Removed / Fixed; user-facing, short). Fixed lists only bugs that existed in v0.1.0 (e.g. Needs my role greying groups with a slot for you — commit 2f0b323). Never mention bugs introduced and fixed inside the milestone. Never rewrite existing sections
5. Author review: the author reviews README.md and the CHANGELOG.md section — this is the phase's UAT, collected with the other deferred in-game checks at the end

### Content facts for the changelog (net vs v0.1.0)
- Added: item level on friendly player tooltips, item tooltips, the character sheet (a row at the bottom of the stats), the Inspect window; settings page (Settings > AddOns, `/tgf settings`, `/tgf set`); Dynamic refresh (the refresh button keeps the list and updates it in place, with swipe / slide animations; tryable in `/tgf preview`); region flags (US / Oceania) on listings incl. your own; tooltips on every row icon; `/tgf ilvl` and `/tgf region` probes
- Removed: gear score (it was switched off in v0.1; its saved data is cleared)
- Fixed: Needs my role greyed groups that had a slot for you

### Claude's Discretion
- Exact cleanup list; changelog wording (short, plain)

</decisions>

<code_context>
## Existing Code Insights

- Files touched in v0.2: Core.lua, Settings.lua, Preview.lua, ItemLevel.lua, ItemLevelUI.lua, Region.lua, Listings.lua, UI/Table.lua, UI/Widgets.lua, UI/InPlace.lua, UI/Motion.lua, UI/MainFrame.lua, UI/SettingsPanel.lua, TerribleGroupFinder.toc, Media/Textures/flag_*.tga, Media/Source/flags.js, CLAUDE.md
- Previous release review for reference: `.planning/milestones/v0.1-phases/05-release-review/`
- Smoke harness outside the repo (scratchpad `smoke/`), all modes must stay `SUMMARY: 0 failed`

</code_context>

<specifics>
## Specific Ideas

None beyond the procedure.

</specifics>

<deferred>
## Deferred Ideas

- v0.1 release-review cleanup list (`milestones/v0.1-phases/05-release-review/05-HUMAN-UAT.md` item 11): not folded in unless trivial and behaviour-neutral
- Backlog 999.5 (quest log LFG button) stays in the backlog

</deferred>
