# Phase 10: Settings Window - Context

**Gathered:** 2026-11-14
**Status:** Ready for planning
**Mode:** Smart discuss, recommended answers auto-accepted (author: never pause autonomous runs; decisions listed for review at the end)

<domain>
## Phase Boundary

The addon's page in the game's own Settings (AddOns): a checkbox for every optional extra (four item level spots, Dynamic refresh, swipe animations, region flags) and a button that opens the group finder on the Messages tab; `/tgf settings` opens the page. Every toggle takes effect immediately and is saved. The finder changes themselves are not optional. Auto-send / Auto-invite stay on the Messages tab.

</domain>

<decisions>
## Implementation Decisions

### Page layout (native Blizzard Settings, vertical layout)
- Category name: "TerribleGroupFinder" under AddOns, using the addon's icon if the API allows
- Sections (headers), in order:
  1. "Item level": Player tooltips, Item tooltips, Character sheet, Inspect window
  2. "Group finder": Dynamic refresh, Swipe animations (indented under / disabled with Dynamic refresh off), Region flags
  3. "Messages": a button "Edit whisper messages" that opens the finder on the Messages tab
- Each checkbox has a one-line tooltip saying what it does (plain words, e.g. "Show 'Item Level N' on friendly players' tooltips")
- Labels come from the `ns.Settings` registry (one source of truth); the registry's labels / tooltips are reworded where needed

### Wiring
- Settings stay the single source of truth in `ns.Settings` (saved only once set; `Get` falls back to the default): the page uses proxy settings (`Settings.RegisterProxySetting` with getter `ns.Settings.Get` and setter `ns.Settings.Set`) rather than `RegisterAddOnSetting` writing the saved table directly, so listeners (redraws) fire and defaults are never written on registration; names prefixed `TGF_`
- Swipe animations is a child of Dynamic refresh (`SetParentInitializer`, shown disabled when Dynamic refresh is off)
- Opening: `/tgf settings` (and `/tgf config` alias) → `Settings.OpenToCategory(category:GetID())`, out of combat only (a printed message in combat)
- "Edit whisper messages" button: a public `IP.OpenMessages()` that shows the group finder and selects our Messages tab (calling the tab's show last); out of combat only; it does not close the Settings panel; if the windows overlap, that's acceptable (in-game check)
- `/tgf` help lists `settings`

### Preview / no Settings API
- Where Blizzard's Settings API is missing (the web simulator / preview stand-in), `/tgf settings` prints each option and its state, and `/tgf set <key> on|off` changes one (no second custom window)

### Claude's Discretion
- Exact tooltip wording; whether the category gets the addon icon; harness stubs for the Settings API

</decisions>

<code_context>
## Existing Code Insights

### Reusable Assets
- `Settings.lua`: `ns.Settings.Register/List/Init/Get/Set/OnChange`, seven options with `label` (add `tooltip`, `section`)
- `UI/InPlace.lua`: Messages side tab (`ShowMessages`, `messagesTab`), `IP.ToggleAuto` gone; `/tgf` dispatcher in `Core.lua`
- Research: `research/STACK.md` (Settings API calls with file:line), `research/PITFALLS.md` pitfall 11

### Integration Points
- New `UI/SettingsPanel.lua` (TOC after `UI/InPlace.lua`), `Core.lua` slash commands, `UI/InPlace.lua` `IP.OpenMessages`

</code_context>

<specifics>
## Specific Ideas

- Author: "a basic config window where both these and all future ilvl and other config can be managed, and a button to 'change message preset' or something, you can rethink this button text, that opens the group finder in our message tab"; "settings panel to allow any ilvl info (tooltip, sheet, inspect) to be disabled independently, also to disable/enable the dynamic refresh; disabling the changes to LFG window itself doesn't need to be there"

</specifics>

<deferred>
## Deferred Ideas

- Auto-send / Auto-invite in the settings page (stay on the Messages tab)

</deferred>
