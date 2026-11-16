# Phase 14: Spec Points - Context

**Gathered:** 2026-11-16
**Status:** Ready for planning
**Mode:** Smart discuss, recommended answers auto-picked (author's standing rule for /gsd-autonomous: no pauses; decisions reported at the end)

<domain>
## Phase Boundary

A friendly player's tooltip (yourself included) shows their talent points per tree, e.g.
`Talents 36/12/3`, on a line under the item level line, from the game's own data gathered by
the same quiet inspect item level uses; its own setting, on by default. No talent tree names,
no spec icons, no other spots (sheet, Inspect window, rows) in this phase.

</domain>

<decisions>
## Implementation Decisions

### Data (SPC-01)
- Source: `C_SpecializationInfo.GetSpecializationInfo(index, isInspect)` → `pointsSpent` per tree, for `index` = 1..number of trees (Forever's classic talents: 3 per class); `isInspect = true` right after the inspect answers (`INSPECT_READY` for that GUID, before `ClearInspectPlayer()`), `false` for yourself. The deprecated `GetTalentTabInfo` shim does not load on Forever (`AllowLoadGameType: classic, standard`), so it is not used. Research confirms the exact call and how the tree count is found (`GetNumSpecializations` / `C_SpecializationInfo.GetNumSpecializationsForClassID` / iterate until nil)
- Inspected values are read in the same inspect answer handling as item level (`ns.ILvl`'s `OnInspectReady` / `ReadCurrent` path), under the same guards (only for the GUID the latest inspect answered, never while the Inspect window is open or pending, no extra inspects), and kept in the same session cache by GUID; a value is only updated by a later inspect
- Your own: read live when your tooltip shows (talent changes apply at once)
- Unknown, secret, or all trees 0 (no talent points yet): no line
- `/tgf ilvl` probe also prints the talent figures it reads (you, and each group member it inspects), so the author can confirm in game that Forever fills inspected `pointsSpent`

### Display (SPC-01)
- Line text: `Talents 36/12/3` (label then the numbers, matching the `Item Level 60` style; the trees in the game's order), gold like the item level line, added right after the item level line; when the item level line is off or unknown, the talents line still shows on its own
- Same tooltip spot and gating as the player tooltip item level: friendly players only (never enemies / attackable), yourself included

### Setting (SPC-02)
- Key `specPoints`, label "Talent points", tooltip "Show talent points per tree (e.g. 31/20/0) on friendly players' tooltips.", default on (author decision)
- Settings page: the "Item level" section is renamed "Item level and talents" and holds the new option after "Player tooltips"; independent of the item level options (no parent)
- Read where it acts (never cached), like the other options

### Claude's Discretion
- Where the talent cache lives (a field next to item level in the same GUID cache vs a parallel table), as long as the inspect guards are shared
- Smoke-harness updates in the session scratchpad

</decisions>

<code_context>
## Existing Code Insights

### Reusable Assets
- `ItemLevel.lua` (`ns.ILvl`): quiet inspect queue, `OnInspectReady(guid)`, `ReadCurrent`, `Remember(unit, r)`, session cache by GUID, `OnLearned` observers, `/tgf ilvl` probe (`ProbeSelf`, `PrintRead`)
- `ItemLevelUI.lua` (`ns.ILvlUI`): player tooltip spot (`AddLine(tooltip, ilvl)`, gated by `ilvlPlayerTooltip`, re-shown on `OnLearned`)
- `Settings.lua` `OPTIONS` list; `UI/SettingsPanel.lua` builds sections from `opt.section`

### Established Patterns
- Every spot is an independent pcall-guarded installer gated by its own settings key where it acts
- Secret values guarded with `issecretvalue()`

### Integration Points
- The player tooltip post-call (TooltipDataProcessor) already adds the item level line; the talents line goes right after it in the same handler or a sibling handler gated by `specPoints`

</code_context>

<specifics>
## Specific Ideas

- Author: "fetch spec point similar to how we get ilvl info, and show a "36/12/3" or similar on the tooltip of a player too, can show it bellow ilvl line we already have, and is a independent option user can enable"

</specifics>

<deferred>
## Deferred Ideas

- Talent points on the Inspect window, the character sheet or group finder rows
- Tree / spec names or icons

</deferred>
