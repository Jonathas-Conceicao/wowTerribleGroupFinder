# Phase 21: Release Review - Context

**Gathered:** 2026-11-24
**Status:** Ready for planning
**Mode:** Autonomous smart discuss: the recommended answers were taken, building on the author's
kickoff answers in `.planning/research/v0.3.0/KICKOFF-DECISIONS.md` (locked)

<domain>
## Phase Boundary

Release Review for v0.3.0 (REL-08): code cleanup, CLAUDE.md accuracy, README print reminders,
version 0.3.0, the `v0.3.0` changelog section draft, and the author's review together with the
deferred in-game checks of Phases 18-20. Same shape as v0.2.2's Phase 17
(`.planning/milestones/v0.2.2-phases/17-release-review/`). **The autonomous run stops before the
author's review**: no push, merge or tag; the author tests in game, reviews README / CHANGELOG and
runs `/gsd-complete-milestone`.

</domain>

<decisions>
## Implementation Decisions

### Code cleanup
- Remove duplication and leftovers added during v0.3.0 (QuestButton.lua, GearSlots.lua,
  UI/InPlace.lua, ItemLevel.lua, Core.lua, Settings.lua); no behaviour change; `stylua .`
- Strip every mention of in-milestone bugs (things introduced and fixed inside v0.3.0, e.g. the
  Phase 19 / 20 review findings) from code comments, CLAUDE.md and README.md; `.planning/` keeps them
- No phase numbers or milestone-internal wording in code comments or CLAUDE.md
- CLAUDE.md stays an accurate architecture description: check the Core, Settings, SettingsPanel,
  ItemLevel, ItemLevelUI, GearSlots, QuestButton, InPlace, MeterReset lines and the Key
  Constraints taint bullet against the code; the "Early release (v0.2.2)" in its intro becomes
  v0.3.0

### README
- Agents don't rewrite README.md: proposed wording changes go into 21-HUMAN-UAT.md as exact
  before / after lines for the author (the opt-in defaults: the extras are off until turned on in
  Settings; the elite quest eye; slot item level and enchants on the character sheet and Inspect
  window). A factual line that is now wrong (e.g. the README saying an extra is on by default) is
  also listed there, not edited
- Screenshot reminders in 21-HUMAN-UAT.md: the Settings page (new order and options), the tracker
  eye, the Listing hint, the slot info on the sheet / Inspect window; the author retakes prints

### Version and changelog
- Version 0.3.0; the TOC keeps `## Version: @project-version@`
- Draft `## v0.3.0` at the top of CHANGELOG.md (prepend only; never rewrite existing sections),
  for players, relative to v0.2.2 (clear to a player, nothing players never saw): a one-line
  summary, then Added (the eye beside elite quests in the quest tracker opens the group finder's
  Listing tab with the quest's details; each item's level and enchant beside its slot on the
  character sheet and the Inspect window, "No enchant" where a slot can take one, each with its
  own setting), Changed (only the group finder's options are on for new installs: item level,
  talents, slot info and the damage meter prompts are off until turned on in Settings; existing
  settings are kept; Settings sections reordered: Group finder, Player inspection, Damage meter,
  Messages). Fixed only for bugs that existed in v0.2.2 (none known)

### Author review (UAT, the run stops before it)
- 21-HUMAN-UAT.md: the author's review of README.md (proposals) and the CHANGELOG.md draft, plus
  every deferred in-game check of Phases 18-20 (18-, 19-, 20-HUMAN-UAT.md) gathered in one list,
  and the open author decisions (rings enchantable on Forever? head / shoulder / off-hand "No
  enchant" noise? hint box look with the widened finder)

### Claude's Discretion
- How the cleanup is split into tasks; the exact changelog wording within the rules above

</decisions>

<code_context>
## Existing Code Insights

### Reusable Assets
- Phase 17's plans and UAT (`.planning/milestones/v0.2.2-phases/17-release-review/`) as the template

### Established Patterns
- CHANGELOG: `## vX.Y.Z`, one-line summary, `### Added / Changed / Fixed`, short player-facing bullets
- README and CHANGELOG are the author's; agents only draft the changelog section and propose README lines

### Integration Points
- CLAUDE.md, CHANGELOG.md (prepend), the phase HUMAN-UAT files

</code_context>

<specifics>
## Specific Ideas

- The changelog explains the opt-in defaults so existing players aren't surprised and new players
  know where to turn things on

</specifics>

<deferred>
## Deferred Ideas

- Milestone completion (push, squash-merge, tag) — the author runs `/gsd-complete-milestone`

</deferred>
