---
gsd_state_version: 1.0
milestone: v0.1
milestone_name: milestone
status: executing
stopped_at: Completed 04-02-PLAN.md
last_updated: "2026-11-11T19:11:51.826Z"
last_activity: 2026-11-11 -- Phase --phase execution started
progress:
  total_phases: 6
  completed_phases: 3
  total_plans: 15
  completed_plans: 13
  percent: 87
---

# Project State

## Project Reference

See: .planning/PROJECT.md (updated 2026-11-11)

**Core value:** Finding the right players or group fast: the listing must be easy to read and order (role, level, gear score) without leaving or replacing Forever's own group finder.
**Current focus:** Phase --phase — 4

## Current Position

Phase: --phase (4) — EXECUTING
Plan: 1 of --name
Status: Executing Phase --phase
Last activity: 2026-11-11 -- Phase --phase execution started

Progress: [█████████░] 87%

## Performance Metrics

**Velocity:**

- Total plans completed: 11
- Average duration: -
- Total execution time: -

**By Phase:**

| Phase | Plans | Total | Avg/Plan |
|-------|-------|-------|----------|
| 1 | 3 | - | - |
| 2 | 4 | ~2h 10m | ~33min |
| 3 | 4 | - | - |

| Plan | Duration | Tasks | Files |
|------|----------|-------|-------|
| Phase 01 P01 | ~30min | 3 tasks | 5 files |
| Phase 01 P02 | 10min | 2 tasks | 2 files |
| Phase 02 P01 | 40min | 3 tasks | 5 files |
| Phase 02 P02 | 35min | 3 tasks | 5 files |
| Phase 02 P03 | ~30min | 3 tasks | 3 files |
| Phase 02 P04 | 25min | 3 tasks | 3 files |
| Phase 3 P01 | 25min | 3 tasks | 4 files |
| Phase 3 P02 | 40min | 3 tasks | 4 files |
| Phase 04 P01 | 40min | 2 tasks | 2 files |
| Phase 04 P02 | 30min | 2 tasks | 2 files |

## Accumulated Context

### Decisions

Decisions are logged in PROJECT.md Key Decisions.
Recent decisions affecting current work:

- Roadmap: ScrollBox move (UIP-05) sits in Phase 2 because it unblocks the header and row look (UIP-02, UIP-06)
- Roadmap: gear score is switched off first (Phase 1) so later phases never build GS columns or `{gs}` keys
- Roadmap: contact lock and Auto-invite (Phase 4) come after rows exist, since the lock covers row and bottom buttons
- 01-03: IconTexture resolved from TOC path (strip addon prefix, probe .blp/.tga); CF_API_KEY kept as secret name
- 02-01: list host is WowScrollBoxList + MinimalScrollBar with scriptless header/row templates (`UI/Templates.xml`); W.List per-kind pools are the fallback
- 02: selection is by resultID; cleared on results / failure / search start / Browse re-show (stock parity, adopted in the AFK run)
- 02: whispers and invites use the plain character name; Auto-send never sends during chat messaging lockdown (prefills instead)
- 02 execution ran the four single-plan waves sequentially on the main tree (no worktrees: one plan per wave, all in UI/Table.lua)
- 03: own row = `LFG_SELF_LISTING` in light green + stock delist button (UIMenuButtonStretchTemplate, redx) for solo/leader only; click calls only `C_LFGList.RemoveListing()`; own row shown only while `HasActiveEntryInfo()` (`source.hasListing`)
- 03: tooltip = GameTooltip in Forever's stock order; extras after (playstyle green, spec/area, friends, listed age, hidden note); re-shown for the hovered row after every Refresh
- 03: Needs my role reads `GetSearchResultMemberCounts` `*_REMAINING`; all-zero on a non-full group falls back to the composition estimate (in-game check)
- 03: hide button = icon button (`W.IconButton`, 24x22, eye atlases, x/+ fallback); `row.message` is now a plain Whisper button (unlist path removed)
- Phase 4 plan 02: pressed look derived from LockSource/LockID on every row fill; Group Invite never pressed, starts no lock

### Pending Todos

None yet.

### Blockers/Concerns

- In-game checks are deferred to the author; phases are verified by stubbed fengari smoke tests and `/tgf` preview
- Phase 1 in-game checks pending (4 items in `phases/01-gear-score-off-and-release-plumbing/01-HUMAN-UAT.md`: Browse without GS, Messages without `{gs}`, no ready-check inspects, TGA icon shows)
- Phase 2 in-game checks pending (11 items in `phases/02-list-foundation/02-HUMAN-UAT.md`); check #1 first: if our XML templates don't resolve via `C_XMLUtil.GetTemplateInfo`, the table silently uses the fallback list
- Phase 3 in-game checks pending (11 items in `phases/03-rows-tooltip-and-own-listing/03-HUMAN-UAT.md`), incl. the author decision on playstyle colour (ROADMAP SC3 says light grey; built green as stock's row label per D-17) and remaining-slot semantics on quest/custom groups
- Phase 3 advisory UI review (18/24, `03-UI-REVIEW.md`): tooltip blank-line rules vs UI-SPEC (no blank after leader block when there is no comment; two extra blanks in extras), raw `|cff..` colours for delisted/invited/sent, no hint on a non-leader's own row; review info items IN-01..IN-03 in `03-REVIEW.md`. Candidates for Phase 5 cleanup
- Phase 4 inputs: `row.message` is a plain Whisper button calling `Instance:Message` → `ns.Messages.Send`; the bottom Send Message uses `ShownSelection`; the delist and hide buttons must stay outside the 1 s contact lock; hardcoded English labels remain (future localization item); Activity width at 620 (UAT Q1)
- Phase 5 inputs: README.md still mentions gear score (lines ~7, ~12); `.pkgmeta` excludes LICENSE from the release zip (author convention, review WR-01; GPL-3.0 may want it shipped); `CF_API_KEY` is the packager's deprecated name for `CF_API_TOKEN` (kept per author); whether CurseForge / Wago accept the `forever` game type is only known after the first tagged release; open review info items IN-01..IN-09 in `phases/02-list-foundation/02-REVIEW.md`

## Session Continuity

Last session: 2026-11-11T19:11:51.819Z
Stopped at: Completed 04-02-PLAN.md
Resume file: None

**Planned Phase:** 4 (Messages and Contact) — 4 plans — 2026-11-11T19:01:27.307Z
