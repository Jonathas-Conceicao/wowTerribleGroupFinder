# Phase 6: Gear Score Removal and Settings Foundation - Context

**Gathered:** 2026-11-14
**Status:** Ready for planning
**Mode:** Infrastructure phase (smart discuss skipped: removal + plumbing, no new user-facing behaviour)

<domain>
## Phase Boundary

Gear score no longer exists anywhere in the addon (code, column, sort, "Your GS", tooltip lines, ready-check inspects, saved `gs` data), old saved data is cleaned up by a schema migration, and a settings registry (`ns.Settings`, flat saved keys, all defaulting to on) is in place so every later v0.2 feature lands with its toggle. No settings UI in this phase (Phase 10).

</domain>

<decisions>
## Implementation Decisions

### Locked by the author (milestone start, 2026-11-14)
- Gear score is dropped in favour of item level: delete the code; keep the design notes in `.planning/research/GEARSCORE.md` as history; backlog 999.1 closes as "dropped"
- Settings never turn off the finder changes themselves (the table is the addon)
- Seven toggles, all default on: item level on player tooltips, item tooltips, character sheet, Inspect; Dynamic refresh; swipe animations; region flags
- Auto-send / Auto-invite stay on the Messages tab (not part of the registry's toggles)

### From research (research/SUMMARY.md, ARCHITECTURE.md, PITFALLS.md)
- Flat top-level keys in `TerribleGroupFinderDB` (`Core.lua` fills defaults one level deep): `ilvlPlayerTooltip`, `ilvlItemTooltip`, `ilvlCharacterSheet`, `ilvlInspect`, `dynamicRefresh`, `swipeAnimations`, `regionFlags`
- `schema` bumps to 2; `Migrate(db)` runs before every module `Init`; it clears `gs`; mutate the DB in place, never rebind `TerribleGroupFinderDB` (the Settings API will hold a reference in Phase 10)
- `Settings.Get(key)` is read where each feature acts (never cached), so toggles are live without `/reload`; `Settings.Set` + `onChange` listeners for the few spots that need a redraw
- Remove `GearScore.lua`, its TOC line and every `ns.GS` / `GEAR_SCORE` reference (Core, Widgets, Table, Preview) in one change; the removal list is enumerated in `research/ARCHITECTURE.md`

### Claude's Discretion
- The prototype's old `autoRefresh` key (a different, removed feature) is simply cleared by the migration rather than mapped (it never shipped)
- Exact module/API shape of `ns.Settings` (names, listener API), within the research's recommendations
- How the smoke harness (outside the repo, in the session scratchpad) is updated for the removal (drop the `--gs` mode, add settings-default and migration checks)

</decisions>

<code_context>
## Existing Code Insights

### Reusable Assets
- `Core.lua`: `DEFAULTS` table + one-level default fill in `ns:ADDON_LOADED`, `ns.db`, `/tgf` dispatcher
- `ItemLevel.lua`, `Region.lua` (prototypes) already read `ns.db` at Init; Region keeps `DB.shards`

### Established Patterns
- Namespaced modules (`ns.X = {}`), Init functions called from `ns:ADDON_LOADED`
- Lua formatted with `stylua .`; files CRLF; tests are the stubbed smoke harness

### Integration Points
- Gear score touches: `GearScore.lua`, `Core.lua` (`ns.GEAR_SCORE`, `ns.GS.Init`), `UI/Widgets.lua` (GS colours), `UI/Table.lua` (GS column, sort, tooltip lines, "Your GS"), `Preview.lua` (gs in sample strings), `TerribleGroupFinder.toc`, `CLAUDE.md`, `.planning/ROADMAP.md`

</code_context>

<specifics>
## Specific Ideas

No specific requirements beyond the locked decisions — infrastructure phase.

</specifics>

<deferred>
## Deferred Ideas

None — the settings UI is Phase 10.

</deferred>
