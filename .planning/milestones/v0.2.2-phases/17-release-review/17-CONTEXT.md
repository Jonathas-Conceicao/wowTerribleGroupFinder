# Phase 17: Release Review - Context

**Gathered:** 2026-11-19
**Status:** Ready for planning

<domain>
## Phase Boundary

Release Review for v0.2.2 (REL-07): code cleanup, README (prints as the author directed, wording
as proposals), version 0.2.2, the `## v0.2.2` changelog draft, and the author's review together
with the deferred in-game checks of Phase 16. Same shape as v0.2.1's Phase 15
(`.planning/milestones/v0.2.1-phases/15-release-review/`).

</domain>

<decisions>
## Implementation Decisions

### Code cleanup
- Remove duplication and leftovers added during v0.2.2 (MeterReset.lua, UI/SettingsPanel.lua,
  Messages.lua, Core.lua, Settings.lua); no behaviour change; `stylua .`
- Strip any mention of in-milestone bugs (things introduced and fixed inside v0.2.2, e.g. the
  Phase 16 review findings: dropped action on unapplied settings, a listing gone before the menu
  pick, `/tgf meter` while moving, a question lost on Move) from code comments, CLAUDE.md,
  README.md and commit messages on main; `.planning/` keeps them
- CLAUDE.md stays an accurate architecture description (check the MeterReset, Messages,
  SettingsPanel, Settings and Core lines against the code)

### README prints (author's direction, applied in this phase)
- Commit the author's two new prints as they are, in `Media/Screenshots/` (already the proper
  place; `.pkgmeta` ignores it, so they don't ship): `tgf_refresh.gif` (1280x720, ~32 MB) and
  `tgf_tooltip_info.png` (223x151)
- README: the gif replaces the FIRST image (`tgf_lfg_window.png`) in the top `<p align="center">`
  block; keep the second (`tgf_lfg_message_config.png`); widths adjusted so both show at the same
  height within the same total (~98%): the gif `width="64%"`, the Messages print `width="34%"`;
  alt text for the gif describes the Browse table refreshing in place
- `tgf_lfg_window.png` stays in the repo even though the README no longer shows it
- `tgf_tooltip_info.png` is committed but not placed in the README (the author's call)

### README wording (proposals only)
- Any other README change is NOT edited: exact before / after lines go into 17-HUMAN-UAT.md for
  the author to accept or rewrite: the damage meter bullet (the prompt can be moved from Settings;
  joining-a-group prompt off by default) and the whispers bullet (several activities: pick one,
  or Edit). No flagpedia credit. Screenshot reminder: list prints that may be outdated

### Version and changelog
- Version 0.2.2; the TOC keeps `## Version: @project-version@`
- Draft `## v0.2.2` at the top of CHANGELOG.md (never rewrite existing sections; author's edits
  to v0.2.1 stay): one-line summary, then Added / Changed (Fixed only for bugs that existed in
  v0.2.1; none known), for players, relative to v0.2.1 (clear to a player, nothing players never
  saw). Added: move the damage meter prompt (Settings > Damage meter > Move; Lock / Default);
  pick the activity when whispering a listing with several activities, or Edit to write it
  yourself. Changed: the prompt shows the addon's icon and the game's own buttons; Move and Edit
  whisper messages close the Settings window themselves; "Ask to reset on joining a group" is
  off by default for new installs (existing settings kept)

### Author review (UAT)
- 17-HUMAN-UAT.md: the author's review of README.md (incl. the new gif layout) and the
  CHANGELOG.md draft, plus the deferred in-game checks of Phase 16 (16-HUMAN-UAT.md), presented
  together at the end of the autonomous run

### Claude's Discretion
- Exact cleanup items, changelog / README proposal wording within the rules above

</decisions>

<code_context>
## Existing Code Insights

- README top block: `<p align="center">` with two `<img ... width="56%">` / `width="42%">`
- `.pkgmeta` ignores `Media/Source` and `Media/Screenshots`
- `scripts/package.bat` builds a local zip in `dist/` (same file set as install)

</code_context>

<specifics>
## Specific Ideas

- "for the gif one replace the first image on Readme by it, try to keep the spacing adjusted.
  Keep the old image even tho not on Readme anymore." (author)

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope

</deferred>
