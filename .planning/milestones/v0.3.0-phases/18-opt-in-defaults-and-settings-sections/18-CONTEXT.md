# Phase 18: Opt-in Defaults and Settings Sections - Context

**Gathered:** 2026-11-24
**Status:** Ready for planning
**Mode:** Autonomous smart discuss: the recommended answers were taken, building on the author's
kickoff answers in `.planning/research/v0.3.0/KICKOFF-DECISIONS.md` (locked)

<domain>
## Phase Boundary

The settings registry and its page change; no feature code beyond reading the new keys' defaults.
On a new install only Elite quest button, Dynamic refresh, Swipe animations and Region flags are
on; every other option is off. Players with saved data keep what they had (schema 4). The page
lists Group finder, Player inspection, Damage meter, Messages in that order. Three new keys are
registered (`eliteQuestButton`, `slotItemLevel`, `slotEnchants`), inert until Phases 19 / 20 read
them. Requirements: OPT-01..04.

</domain>

<decisions>
## Implementation Decisions

### Defaults (OPT-01)
- Every option in `Settings.lua`'s `OPTIONS` carries an explicit `default`; the `default == nil
  -> true` fill loop goes, so a forgotten default is an error at `Register` (it already asserts a
  boolean)
- On: `eliteQuestButton`, `dynamicRefresh`, `swipeAnimations`, `regionFlags`. Off:
  `ilvlPlayerTooltip`, `specPoints`, `ilvlItemTooltip`, `ilvlCharacterSheet`, `ilvlInspect`,
  `slotItemLevel`, `slotEnchants`, `meterResetOnGroup`, `meterResetOnInstance`

### Migration (OPT-02)
- `ns.Migrate` gets a schema-4 step after the schema-3 one; `DEFAULTS.schema = 4`
- `existing` stays computed once at the top (`next(db) ~= nil` before anything is written); the
  schema-4 step uses that same local, never a recomputation (schema 3 writes `db.schema`)
- A frozen local list of the six keys that were on in v0.2.2 (`ilvlPlayerTooltip`, `specPoints`,
  `ilvlItemTooltip`, `ilvlCharacterSheet`, `ilvlInspect`, `meterResetOnInstance`): for an existing
  table at schema < 4, each key whose saved value isn't a boolean is saved `true`; a saved boolean
  is never touched; never read from `ns.Settings` (Migrate runs before `Settings.Init`, and `Get`
  now answers the new defaults); never loops over all options (the new keys keep their new
  defaults; `meterResetOnGroup` is schema 3's)
- A table holding only `schema = 3` counts as existing (it is a v0.2.2 install that never set
  anything); a v0.2.1 table runs schema 3 then 4
- The comment above `ns.Migrate` describes schema 4 in the same style as schema 3

### Page order and labels (OPT-03, OPT-04)
- Sections follow registration order (`UI/SettingsPanel.lua` adds a header when `section` changes),
  so `OPTIONS` is reordered: Group finder (Elite quest button, Dynamic refresh, Swipe animations
  as its child, Region flags), Player inspection (Player tooltips, Talent points, Item tooltips,
  Character sheet, Inspect window, Slot item level, Slot enchants), Damage meter (the two prompts;
  the Move button still goes after it), Messages (the existing button)
- "Item level and talents" is renamed "Player inspection"
- New labels / tooltips: "Elite quest button" ("Show an eye button beside elite quests in the
  objective tracker; it opens the group finder's Listing tab with what you need to list a group
  for that quest."), "Slot item level" ("Show each item's level beside its slot on the character
  sheet and the Inspect window."), "Slot enchants" ("Show each item's enchant beside its slot on
  the character sheet and the Inspect window, or \"No enchant\" where the slot can be enchanted.")
- `/tgf set` and the no-Settings-API fallback list come from `ns.Settings.List()` and need no change
  beyond the registry
- No first-run chat notice; the page's Defaults button resets to the new defaults (as today)

### Claude's Discretion
- Exact wording of the comments; whether the frozen list lives in Core.lua next to Migrate (it
  should: Migrate owns it)
- A small offline check of Migrate (a Lua snippet run with any available Lua, or a reasoned table of
  fixtures in the plan) covering `{}`, `{schema=3}`, `{schema=3, specPoints=false}`, a v0.2.1 table,
  `{schema=4}`

</decisions>

<code_context>
## Existing Code Insights

### Reusable Assets
- `ns.Migrate(db)` (Core.lua:37) with schema 3 as the precedent (frozen key, `existing` local)
- `ns.Settings.Register / List / Get` (Settings.lua); `OPTIONS` table at Settings.lua:122

### Established Patterns
- Settings saved only once set; `Get` falls back to the option's default
- Section headers come from registration order (UI/SettingsPanel.lua:35-39); `parent` makes a child
  initializer (swipeAnimations under dynamicRefresh)

### Integration Points
- Core.lua `DEFAULTS.schema`, Migrate runs at Core.lua:289 before module Init
- CLAUDE.md's Core.lua and Settings.lua lines describe defaults and schema; update them

</code_context>

<specifics>
## Specific Ideas

- The author wants the addon to only change the group finder by default, to avoid clashing with
  similar addons (item level / inspect addons, meter helpers)

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope.

</deferred>
