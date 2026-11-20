# Phase 16: Small Improvements - Context

**Gathered:** 2026-11-19
**Status:** Ready for planning

<domain>
## Phase Boundary

Commit the improvements prototyped on `topic/dev` after v0.2.1 (uncommitted on the milestone
branch, harness-tested, installed in the author's client) and build the one missing piece:

- MTR-05 movable damage meter prompt (Settings > Damage meter > "Prompt position" > Move; Lock /
  Default; `DB.meterPos`), MTR-06 game-menu button style, MTR-07 purple-eye icon on the left
- SET-01 the Settings page's Move and Edit whisper messages buttons close the options window
  (`SP.CloseThen`: the panel's own `Close(true)`, action after it hides, not in combat)
- MSG-01 / MSG-02 whisper activity menu at the cursor (`MenuUtil.CreateContextMenu`), with Edit
- MTR-08 (to build): `meterResetOnGroup` off by default for new installs; existing users keep it on

</domain>

<decisions>
## Implementation Decisions

### Prototype (already built, keep as is)
- `MeterReset.lua`: icon 76x76 at LEFT (18, 0); a body frame right of it holds the question
  (top) and the buttons (bottom, centered); frame 380x112; `SharedButtonTemplate` 120x26,
  fallback `ns.W.Button`; move mode with Default (clears `DB.meterPos`) and Lock (saves
  `{left, top}` in UIParent coordinates); `M.Move` / `M.EndMove`; `M.Init(saved)` drops a bad spot;
  a prompt doesn't show while the dialog is being moved
- `UI/SettingsPanel.lua`: the "Prompt position" / Move button in the Damage meter section;
  `SP.AfterClose(fn)` (one-time `HookScript("OnHide")`, latest wins, runs next frame);
  `SP.CloseThen(fn)` closes through `SettingsPanel:Close(true)` (unapplied game settings still
  ask; no game menu fallback), in combat or without the panel calls fn at once; pcall-guarded
- `Messages.lua`: `M.Send(l, preview, from, choice)`; menu when the preset (normalized) has
  `{activity}` and the listing has 2+ named activities; one entry per activity (Auto-send as the
  preset says) and Edit (prefill only, never sends or invites); no `MenuUtil` = first activity
- `Settings.lua`: `meterPos` reserved; `Core.lua`: `ns.MeterReset.Init(ns.db)`

### MTR-08 (to build)
- New default for `meterResetOnGroup`: off
- "Existing user" = `TerribleGroupFinderDB` already held any key when the addon loaded (before
  defaults are applied); schema 3 step in `ns.Migrate`: for an existing user whose
  `meterResetOnGroup` is unset, save `true`; then `schema = 3` (DEFAULTS schema 3)
- A fresh install (empty or missing DB) gets the new default (off), nothing saved
- Settings tooltip / CLAUDE.md "all default on" wording updated accordingly

### Activity menu scope
- Solo players and groups alike (both presets can use `{activity}`)
- Edit fills `{activity}` with every activity, comma-separated

### Claude's Discretion
- Plan split and harness test additions; commit granularity (prototype commit(s) first, then MTR-08)

</decisions>

<code_context>
## Existing Code Insights

### Reusable Assets
- `ns.Migrate(db)` in `Core.lua` (runs before every Init, schema 2 today; DEFAULTS applied after)
- `ns.Settings.Register` options with `default`; `Get` returns the default while unsaved
- Smoke harness in the session scratchpad (`smoke/run.js`, three modes) already covers the
  prototype (meter move, settings close, activity menu)

### Established Patterns
- Settings saved only once set; other modules' keys reserved in `Settings.lua`
- Taint: Blizzard frames are only hooked; the Settings panel closed only via its own `Close`
  from our two buttons (author's choice, recorded in CLAUDE.md)

### Integration Points
- `Core.lua` ADDON_LOADED: Migrate -> DEFAULTS -> Settings.Init -> module Inits
- `Settings.lua` option `meterResetOnGroup` (section Damage meter)

</code_context>

<specifics>
## Specific Ideas

- The prompt's icon is the addon's own `Media/Textures/tgf_icon_64x64` (no new art)
- Buttons look like the game menu's (red three-slice)

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope

</deferred>
