# Phase 15: Release Review - Context

**Gathered:** 2026-11-16
**Status:** Ready for planning
**Mode:** Smart discuss, recommended answers auto-picked (author's standing rule for /gsd-autonomous: no pauses; decisions reported at the end)

<domain>
## Phase Boundary

The project's Release Review (PROJECT.md → Milestone Close-out) for v0.2.1: code cleanup, README
screenshot check, version, the `## v0.2.1` changelog draft, and the author's review of README.md
and the drafted CHANGELOG.md section (the phase's UAT, last step). Tagging happens at milestone
completion, after the author's review, never inside this phase.

</domain>

<decisions>
## Implementation Decisions

### Code cleanup
- Remove duplication and leftovers added during v0.2.1 (MeterReset.lua, Region.lua, UI/Table.lua, Preview.lua, ItemLevel.lua, ItemLevelUI.lua, Settings.lua, Media/Source/png2tga.js); no behaviour change; `stylua .`
- Strip any mention of in-milestone bugs (things introduced and fixed inside v0.2.1, e.g. review findings such as the pooled-row tag width, the popup overlap, the same-run re-ask) from code comments, CLAUDE.md, README.md and commit messages on main; `.planning/` keeps them
- CLAUDE.md stays an accurate architecture description (check the MeterReset, Region, Table, Preview, ItemLevel, ItemLevelUI, Settings and SettingsPanel lines against the code)

### README (draft for the author; agents change README only as the author directs — the author reviews every change)
- README.md is NOT edited in this phase. Instead, write proposed README wording (exact before / after lines) into the phase's HUMAN-UAT for the author to accept or rewrite; the orchestrator applies only what the author approves. Proposals cover: the Region flags bullet (flags for US, Oceania, EU, China, Korea, Taiwan; two letters for other region names); an Item level bullet mention of talent points on player tooltips; a new bullet for the damage meter reset prompt; `/tgf meter` in Usage; the Settings page bullet listing the new options. No flagpedia credit (author decision). No screenshot changes (author retakes prints)
- Screenshot check: list which README prints may be outdated (rows with new flags / tags; tooltips with the talents line; the new dialog) for the author; reminder only

### Version and changelog
- Version 0.2.1; the TOC keeps `## Version: @project-version@`
- Draft `## v0.2.1` at the top of CHANGELOG.md (never rewrite existing sections): a one-line summary, then Added / Changed / Fixed as needed, written for players, relative to v0.2.0 (memory rule: clear to a player, not a dev; nothing players never saw). Expected content: Added — damage meter reset prompt (joining a group / entering an instance, Details! or the game's meter, two settings, `/tgf meter`); talent points on player tooltips with its own setting; flags for EU, China, Korea and Taiwan regions, and two-letter text for other region names. Changed — the US and Oceania flags have new art; the settings section "Item level" is now "Item level and talents". Fixed — only bugs that existed in v0.2.0 (none known)

### Author review (UAT)
- The phase's HUMAN-UAT is the author's review of README.md and the CHANGELOG.md draft, plus the deferred in-game checks of phases 12-14; presented together at the end of the autonomous run

### Claude's Discretion
- Exact cleanup items, README / changelog wording within the rules above

</decisions>

<code_context>
## Existing Code Insights

### Reusable Assets
- `.planning/milestones/v0.2-phases/11-release-review/` — the previous Release Review's plans and summaries (same steps)
- CHANGELOG.md's v0.2.0 section — tone and structure to match

### Established Patterns
- Changelog: short player-facing lines, Added / Changed / Fixed, relative to the last release
- README: feature bullets, Usage with slash commands, AI Usage disclaimer (keep)

### Integration Points
- `.github/workflows/release.yml` publishes the first `## ` section of CHANGELOG.md as the release notes

</code_context>

<specifics>
## Specific Ideas

- Author: "changelog should _always_ be clear to a player (not a dev) and relative to last release state"
- Author: no flagpedia mention in the README

</specifics>

<deferred>
## Deferred Ideas

- New README screenshots (the author retakes them)

</deferred>
