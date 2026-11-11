---
gsd_state_version: 1.0
milestone: v0.1
milestone_name: milestone
status: awaiting_author_review
stopped_at: Phase 5 awaiting author review (plans executed, verification human_needed; review items in 05-HUMAN-UAT.md)
last_updated: "2026-11-11T22:00:00.000Z"
last_activity: 2026-11-11
progress:
  total_phases: 5
  completed_phases: 4
  total_plans: 17
  completed_plans: 17
  percent: 80
---

# Project State

## Project Reference

See: .planning/PROJECT.md (updated 2026-11-11)

**Core value:** Finding the right players or group fast: the listing must be easy to read and order (role, level, gear score) without leaving or replacing Forever's own group finder.
**Current focus:** Phase 5 — Release Review

## Current Position

Phase: 5 (Release Review)
Plan: 2 of 2 executed (05-01 cleanup, 05-02 changelog draft + author UAT)
Status: Phase 5 awaiting author review — not complete; the author's review of README.md, the CHANGELOG v0.1.0 draft and the open decisions in `phases/05-release-review/05-HUMAN-UAT.md` closes it
Last activity: 2026-11-11 — Phase 5 executed; code review clean (2 info); verification human_needed (3/4, SC4 = author review)

Progress: [████████░░] 80%

## Performance Metrics

**Velocity:**

- Total plans completed: 15
- Average duration: -
- Total execution time: -

**By Phase:**

| Phase | Plans | Total | Avg/Plan |
|-------|-------|-------|----------|
| 1 | 3 | - | - |
| 2 | 4 | ~2h 10m | ~33min |
| 3 | 4 | - | - |
| 4 | 4 | - | - |

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
| Phase 04 P04 | 30min | 3 tasks | 2 files |

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
- Phase 4 plan 04: Messages tab fill-to-interior via SetFillToInterior, else own fillToInterior field, else 30x30 fallback; UpdateTabs post-hook unchecks stock tabs while Messages shows
- 04: presets stored with `{addon}` (rendered `[TGF]`, normalised first and once in Format / on focus lost / on key insert); `{gs}` removed; unknown keys render literally; `{players}` = `max(GetNumGroupMembers(), 1)`
- 04: Auto-invite only after a real auto-send and only with `ns.CanInvite()`; lockdown prefills (no send, no invite, no lock); a failed send prints a notice and starts no lock
- 04: 1 s contact lock in Messages.lua (GetTime deadline + C_Timer); only auto-send clicks start it; others ignore clicks with unchanged look; `W.SetPressed` swaps the UIPanelButton art; delist / hide outside the lock
- 04: one-time preset migration keyed on `messages.version` (old defaults → new, custom kept); rendered text clipped to 255 bytes on a UTF-8 boundary
- 04: one `M.BuildPanel` for game and preview (Who-tab layers, InputScrollFrameTemplate boxes, two key-button rows)
- 04: execution ran four single-plan waves sequentially on the main tree; REQUIREMENTS.md ticked by hand (SDK requirements command splits lines)
- 05: version 0.1.0 / tag `v0.1.0` (TOC keeps `@project-version@`); `## v0.1.0` drafted above the untouched `## Unreleased`; README untouched (suggestions in 05-HUMAN-UAT.md); `.pkgmeta` unchanged (shipping LICENSE recommended to the author); preset migration and `Instance:Delist`'s `RemoveListing` kept as author questions; `ForEachFrame` kept, 02 IN-05 skipped
- 05: REL-04 stays unchecked until the author confirms the review

### Pending Todos

None yet.

### Blockers/Concerns

- In-game checks are deferred to the author; phases are verified by stubbed fengari smoke tests and `/tgf` preview
- Phase 1 in-game checks pending (4 items in `phases/01-gear-score-off-and-release-plumbing/01-HUMAN-UAT.md`: Browse without GS, Messages without `{gs}`, no ready-check inspects, TGA icon shows)
- Phase 2 in-game checks pending (11 items in `phases/02-list-foundation/02-HUMAN-UAT.md`); check #1 first: if our XML templates don't resolve via `C_XMLUtil.GetTemplateInfo`, the table silently uses the fallback list
- Phase 3 in-game checks pending (11 items in `phases/03-rows-tooltip-and-own-listing/03-HUMAN-UAT.md`), incl. the author decision on playstyle colour (ROADMAP SC3 says light grey; built green as stock's row label per D-17) and remaining-slot semantics on quest/custom groups
- Phase 3 advisory UI review (18/24, `03-UI-REVIEW.md`): tooltip blank-line rules vs UI-SPEC (no blank after leader block when there is no comment; two extra blanks in extras), raw `|cff..` colours for delisted/invited/sent, no hint on a non-leader's own row; review info items IN-01..IN-03 in `03-REVIEW.md`. Candidates for Phase 5 cleanup
- Phase 4 in-game checks pending (11 items in `phases/04-messages-and-contact/04-HUMAN-UAT.md`): live whisper + invite, 1 s pressed look (does `SetButtonState`/art swap hold through mouse-up), lockdown prefill, Auto-invite disabled look + tooltip, key-button widths (two rows under 410 px), 56 px boxes, Who layers, side-tab icon fill (Q4 `INV_Letter_15`), preset migration, taint log
- Phase 4 advisory UI review (19/24, `04-UI-REVIEW.md`): key-row forced break at `i == 5` can start a third row over Auto-send (same as review IN-01); intro text near its 4-line cap; no feedback on locked clicks / lockdown prefill; disabled Auto-invite label font size; example line uses sample data in game. Candidates for Phase 5 cleanup
- Phase 4 code review: open info items IN-01 (key-row wrap could start a third row with wide labels), IN-02 (example sample picked by position), IN-03 (newline strip moves the cursor) in `04-REVIEW.md` / `04-REVIEW.iter2.md`; hardcoded English labels remain (future localization item); Activity width at 620 (UAT Q1)
- Phase 5 inputs: README.md still mentions gear score (lines ~7, ~12); `.pkgmeta` excludes LICENSE from the release zip (author convention, review WR-01; GPL-3.0 may want it shipped); `CF_API_KEY` is the packager's deprecated name for `CF_API_TOKEN` (kept per author); whether CurseForge / Wago accept the `forever` game type is only known after the first tagged release; open review info items IN-01..IN-09 in `phases/02-list-foundation/02-REVIEW.md`

## Session Continuity

Last session: 2026-11-11T22:00:00.000Z
Stopped at: Phase 5 awaiting author review (do not run gsd-complete-milestone until the author confirms 05-HUMAN-UAT.md)
Resume file: .planning/phases/05-release-review/05-HUMAN-UAT.md
