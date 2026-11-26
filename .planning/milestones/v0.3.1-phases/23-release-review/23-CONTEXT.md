# Phase 23: Release Review - Context

**Gathered:** 2026-11-26
**Status:** Ready for planning
**Mode:** Autonomous smart discuss: the recommended answers were taken, building on the author's
kickoff answers for v0.3.1 (Phase 22 CONTEXT) and the Release Review shape of v0.3.0's Phase 21
(`.planning/milestones/v0.3.0-phases/21-release-review/`)

<domain>
## Phase Boundary

Release Review for v0.3.1 (REL-09): code cleanup, CLAUDE.md accuracy, README print reminders,
version 0.3.1, the `v0.3.1` changelog section draft, and the author's review together with the
deferred in-game checks of Phase 22. **The autonomous run stops before the author's review**: no
push, merge or tag; the author tests in game, reviews README / CHANGELOG and runs
`/gsd-complete-milestone` (squash-merge into `main`, tag `v0.3.1`).

</domain>

<decisions>
## Implementation Decisions

### Code cleanup
- Remove duplication and leftovers added during v0.3.1 (QuestButton.lua, Messages.lua,
  UI/Table.lua, UI/InPlace.lua, Listings.lua); no behaviour change; `stylua .`
- Strip mentions of in-milestone bugs (the Phase 22 review findings WR-01..03 were introduced and
  fixed inside v0.3.1) from code comments, CLAUDE.md and README.md; `.planning/` keeps them
- No phase numbers or milestone-internal wording in code comments or CLAUDE.md
- CLAUDE.md: check the QuestButton, Messages, Listings, UI/Table and UI/InPlace lines against the
  code; "Early release (v0.3.0)" in its intro becomes v0.3.1

### README
- Agents don't rewrite README.md: proposed lines go into 23-HUMAN-UAT.md as exact before / after
  text (the invite outcome on rows, if the README describes the Listed column or invites)
- Screenshot reminder: a row showing accepted / declined / expired, if the README has a print of
  the list (the author retakes prints)

### Version and changelog
- Version 0.3.1; the TOC keeps `## Version: @project-version@`
- Draft `## v0.3.1` at the top of CHANGELOG.md (prepend only; never rewrite existing sections),
  for players, relative to v0.3.0: a one-line summary, then
  - Added: after inviting a player from the list, their row says whether they accepted,
    declined, or the invite expired
  - Fixed (bugs that existed in v0.3.0): the elite quest button could raise Lua errors when
    clicked; the first search after logging in or reloading could show the whole category
    instead of the activity you picked
- Nothing about bugs introduced and fixed inside v0.3.1

### Author review (UAT, the run stops before it)
- 23-HUMAN-UAT.md: the author's review of README.md (proposals) and the CHANGELOG.md draft, plus
  every deferred in-game check of Phase 22 (22-HUMAN-UAT.md) gathered in one list, and the review
  info item IN-02 (narrowing when the picks changed to a subset while the search was out) and the
  55 s decline-as-expired rule as author decisions to confirm in game

### Claude's Discretion
- How the cleanup is split into tasks; the exact changelog wording within the rules above

</decisions>

<code_context>
## Existing Code Insights

### Reusable Assets
- Phase 21's plans and UAT (`.planning/milestones/v0.3.0-phases/21-release-review/`) as the template

### Established Patterns
- CHANGELOG: `## vX.Y.Z`, one-line summary, `### Added / Changed / Fixed`, short player-facing bullets
- README and CHANGELOG are the author's; agents only draft the changelog section and propose README lines

### Integration Points
- CLAUDE.md, CHANGELOG.md (prepend), the phase HUMAN-UAT files

</code_context>

<specifics>
## Specific Ideas

No specific requirements beyond the above.

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope.

</deferred>
