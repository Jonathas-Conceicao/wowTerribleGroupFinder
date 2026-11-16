# Phase 14: Spec Points - Research

**Researched:** 2026-11-16
**Domain:** WoW Forever (game type `camelot`, interface 16001) talent data for yourself and an inspected player; tooltip line; one new setting
**Confidence:** HIGH for the API path (Blizzard's own Forever talent frame and two installed Forever addons agree); MEDIUM for live behaviour that only an in-game check can settle (listed under Open Questions / HUMAN-UAT)

## Summary

**The locked data source (`C_SpecializationInfo.GetSpecializationInfo(i, isInspect).pointsSpent`) is not what Forever uses, and it probably gives nothing useful there.** CONTEXT.md left it to research to confirm the call ("Research confirms the exact call and how the tree count is found"), and the evidence points the other way:

- Forever's talent UI is the modern **Trait** talent frame, with Camelot overrides. It shows the points per tree in its tree headers from `C_Traits.GetGroupCurrencyInfo(configID, groupIDs)[i].currencyInfos[1].spent`. The groups come from `C_Traits.GetGroupDisplayInfoByTreeID(treeID)`, and the tree from `C_Traits.GetConfigInfo(configID).treeIDs[1]` [VERIFIED: wow-ui-source forever, `Blizzard_PlayerSpells/Camelot/ClassTalents/Blizzard_ClassTalentsFrame.lua:82-109, 331-344`; `Blizzard_SharedTalentUI/Blizzard_SharedTalentFrame.lua:1310-1323`].
- No Forever (Camelot) file reads `pointsSpent`. The only readers are the Cata talent frame and the `Blizzard_DeprecatedSpecialization` shims, and those don't load on camelot (`AllowLoadGameType: classic, standard`). The Mists shim even notes that "pointsSpent … are not supported outputs in 5.5.x and onward" [VERIFIED: grep of the whole source tree; `Deprecated_Specialization_Mists.lua:20`].
- Forever has **one specialization per class**, not three. `SpecializationVisuals` is keyed by one spec ID per class (1482-1491). The character sheet shows a spec name only when `C_SpecializationInfo.IsSpecSelectionEnabled(classID)` [VERIFIED: `Blizzard_PlayerSpells/Camelot/ClassTalents/Blizzard_ClassTalentUtil.lua:13-40`; `Blizzard_UIPanels_Game/Camelot/PaperDollFrame.lua:493-500`]. So `GetSpecializationInfo(1..3)` cannot be expected to map to the three talent trees.
- Two installed Forever addons read talents through Trait configs. RaiderIO picks the Forever config with `C_SpecializationInfo.GetCombatConfigIDForSpecGroup(C_SpecializationInfo.GetActiveSpecGroup())` and checks that its type is `Enum.TraitConfigType.CamelotCombat`; for an inspect it reads `Constants.TraitConsts.INSPECT_TRAIT_CONFIG_ID` inside its `INSPECT_READY` handler. MythicSim notes "One TraitTree per class holds all three tabs" and sums `C_Traits.GetTreeCurrencyInfo(...).spent` [VERIFIED: `_forever_/Interface/AddOns/RaiderIO/beacon.lua:1117-1131, 1340-1352, 1955-1976` and `ReadForeverConfig`; `MythicSim/Forever.lua:108-117, 140-171, 217-226`; `MRT/Inspect.lua:991-996`].

**Primary recommendation:** read the points per tree the way Forever's own talent frame does. Take the config (your active Camelot combat config, or `INSPECT_TRAIT_CONFIG_ID` = -1 for the inspect), its tree, the tree's groups in the game's order, and `spent` per group. For an inspect, read in the same `INSPECT_READY` handling as item level, before `ClearInspectPlayer()`. Have the `/tgf ilvl` probe print both this figure and `GetSpecializationInfo(i, …).pointsSpent`, so the author can confirm in game. **The planner should report this change of source to the author** (it replaces a locked decision's mechanism, not its intent; everything else in CONTEXT.md stands).

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Read your own points per tree (live) | Data module `ItemLevel.lua` (`ns.ILvl`) | — | Client API reads, no UI. Next to `ShownMine` |
| Read an inspected player's points | `ItemLevel.lua` inspect path (`ReadCurrent`, the foreign `OnInspectReady` path) | — | Must share the inspect guard and its timing (before `ClearInspectPlayer`) |
| Session cache by GUID | `ItemLevel.lua` `known[guid]` | — | One cache, one observer list (`OnLearned`) |
| Tooltip line `Talents 36/12/3` | `ItemLevelUI.lua` player tooltip spot | — | Same spot and hostility / secret gating as the item level line |
| Setting `specPoints` | `Settings.lua` OPTIONS | `UI/SettingsPanel.lua` (no code change: sections come from `opt.section`) | Registry is the single source |
| Probe output | `ItemLevel.lua` `ProbeSelf` / `ReadCurrent` (non-quiet) | `Core.lua` `/tgf ilvl` (unchanged) | The author's in-game confirmation |

## User Constraints

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

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

### Deferred Ideas (OUT OF SCOPE)
- Talent points on the Inspect window, the character sheet or group finder rows
- Tree / spec names or icons
</user_constraints>

**Research note on the first locked bullet:** that bullet delegates the exact call to research. The call research confirms is the C_Traits group-currency read (below). Everything the bullet *requires* stays as written: the same inspect answer, before `ClearInspectPlayer`, `isInspect` semantics (the config `-1` stands for "the inspected player"), live for yourself, trees in the game's order, the probe printing what it reads. The probe still prints `pointsSpent` as well, so the author can see both.

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| SPC-01 | Friendly players' tooltips show their talent points per tree (e.g. `36/12/3`) on a line under the item level line, from the same quiet inspect item level uses; your own tooltip from your own talents; nothing while unknown | API path (Code Examples 1-3), integration points in `ItemLevel.lua` / `ItemLevelUI.lua`, pitfalls 1-7 |
| SPC-02 | Spec points have their own setting in the settings page, independent of the item level options, on by default | `Settings.lua:121-181` OPTIONS (default forced true at :178-181), section rename, `UI/SettingsPanel.lua:36-40` sections by `opt.section` (no change needed) |
</phase_requirements>

## Project Constraints (from CLAUDE.md)

- Forever only, one TOC (`## Interface: 16001`); no flavour forks
- Guard reads with `issecretvalue()` where values may be secret
- Taint: outside the finder only hook (`hooksecurefunc`, `TooltipDataProcessor`) and add our own frames / text; never write Blizzard's data. Reading `PlayerSpellsFrame:IsInspecting()` is a read and is allowed; never call `SetInspectUnit`, `ClearInspectUnit`, or anything that writes
- Features read `ns.Settings.Get` where they act, never cached; each option has `section`, `tooltip`, optional `parent`; all defaults on (`Settings.lua:178-181` forces `default = true`)
- The ItemLevel module's guard rules (one inspect at a time, 1.5 s apart, out of combat, a 30 s wait, never while the Inspect window is shown or pending, 2 s after a foreign inspect, values only for the latest inspect's GUID, `ClearInspectPlayer()` only when no later inspect started) must not weaken
- Run `stylua .` from the repo root after each task
- Never `sed -i` / shell redirects on `.md` or `.planning/` files; use the Edit tool
- Never touch `CHANGELOG.md`. No changelog entries during the milestone
- Keep CLAUDE.md's Architecture section current: the `Settings.lua` key list (add `specPoints`), the `ItemLevel.lua` / `ItemLevelUI.lua` lines (talent points, probe), the `UI/SettingsPanel.lua` section names ("Item level and talents")
- Memory: flag that the player tooltip gains a line (a README screenshot may need retaking; the author retakes it). Never mention the early reference addon

## Standard Stack

No packages. Client APIs only (all present in the forever branch's generated docs):

| API | Signature (docs) | Purpose | Evidence |
|-----|------------------|---------|----------|
| `C_SpecializationInfo.GetActiveSpecGroup(isInspect?, isPet?)` | → `groupIndex` | your active spec group (dual spec) | `SpecializationInfoDocumentation.lua:41-55` |
| `C_SpecializationInfo.GetCombatConfigIDForSpecGroup(groupIndex)` | → `configID?` | your Camelot combat config for that group | `SpecializationInfoDocumentation.lua:90-103`; used by Forever's frame `Camelot/.../Blizzard_ClassTalentsFrame.lua:119-121, 183` and RaiderIO's `ReadForeverConfig` |
| `C_ClassTalents.GetActiveConfigID()` | → `activeConfigID?` | the shared frame's first choice | `ClassTalentsDocumentation.lua:73-80`; `Blizzard_PlayerSpells/ClassTalents/Blizzard_ClassTalentsFrame.lua:893-900` |
| `Constants.TraitConsts.INSPECT_TRAIT_CONFIG_ID` | `-1` | the inspected player's config | `TraitConstantsDocumentation.lua:352`; `ClassTalentsFrame.lua:883-888` |
| `C_Traits.GetConfigInfo(configID)` | → `{ ID, type, name, treeIDs, … }` (may return nothing) | the tree ID (`treeIDs[1]`) and type check | `SharedTraitsDocumentation.lua:201-215, 1013-1023`; `SharedTalentFrame.lua:1315-1323` |
| `Enum.TraitConfigType.CamelotCombat` | `4` | sanity check that a config is Forever's talents | `TraitConstantsDocumentation.lua:138` |
| `C_Traits.GetGroupDisplayInfoByTreeID(treeID)` | → `{ { groupID, treeID, skillLineID, orderIndex, displayName, icon } }` | the trees ("groups"), in display order | `SharedTraitsDocumentation.lua:297-310, 1080-1091` |
| `C_Traits.GetGroupCurrencyInfo(configID, groupIDs)` | → `{ { traitNodeGroupID, currencyInfos = { { traitCurrencyID, quantity, maxQuantity?, spent, spentInTree? } } } }` | points spent per tree | `SharedTraitsDocumentation.lua:281-295, 972-979, 1188-1198` |

None of these is marked `SecretReturns` or `SecretWhenUnitIdentityRestricted`. They carry only `SecretArguments = "AllowedWhenUntainted"`, which matters only when *passing* secret arguments, and we never do [VERIFIED: grep `SecretReturns|SecretWhen` in `SharedTraitsDocumentation.lua` returns nothing]. Guard the results with `issecretvalue()` anyway, as the project requires (cheap, and future-proof).

**For the probe only (comparison, not shown on tooltips):** `C_SpecializationInfo.GetSpecializationInfo(i, isInspect, false, nil, nil, nil)`, positional returns with `pointsSpent` the **7th** (`specId, name, description, icon, role, primaryStat, pointsSpent, background, previewPointsSpent, isUnlocked`) [VERIFIED: `SpecializationInfoDocumentation.lua:254-282`; argument order as Blizzard calls it, `Camelot/PaperDollFrame.lua:499` `(spec, false, false, nil, UnitSex("player"))`]. Also `C_SpecializationInfo.GetSpecialization()`.

## Package Legitimacy Audit

No external packages are installed in this phase (WoW addon Lua; client APIs only). slopcheck not applicable.

**Packages removed:** none. **Packages flagged:** none.

## Architecture Patterns

### Data flow

```
Your tooltip (TooltipDataProcessor Unit post-call, ItemLevelUI.OnTooltipUnit)
  ├─ unit is you ──> ILvl.TalentsOf("player") ──> ReadTalents(own configID)  [live, every show]
  └─ friendly other ─> ILvl.TalentsOf(unit) ──> known[guid].talents
          │ nil (never answered) and (ilvl wanted & unknown OR talents wanted & unknown)
          └─> ILvl.RequestInspect(unit)  (unchanged guard: Busy, gap, tried, CanInspect)
                   │ NotifyInspect (ours, serial/lastTarget)
                   ▼
              INSPECT_READY(guid) ── OnInspectReady
                   ├─ ours: ReadCurrent(0)  ── serial/lastTarget check ── read talents NOW (config -1)
                   │        then items (may retry 1 s x3; talents already captured on c)
                   │        Remember(unit, r, talents) ── known[guid] ── OnLearned(guid)
                   │        Done ── ClearInspectPlayer (only if no later inspect, windows closed)
                   └─ foreign (latest inspect): Try() ── same: talents on the first Try, then items
OnLearned(guid) ──> ItemLevelUI.RefreshTooltip(guid): add / update the item level line, then the talents line
```

### Recommended structure (no new files)

```
ItemLevel.lua    + ReadTalents(configID) helper, OwnConfigID(), INSPECT_CONFIG,
                 + known[guid].talents (field next to ilvl), ILvl.TalentsOf(unit), ILvl.TalentsText(t)?
                 + talents captured in ReadCurrent / foreign Try before any retry and before Done
                 + Busy()/Done guard: PlayerSpellsFrame:IsInspecting()
                 + probe lines (self, each inspected member)
ItemLevelUI.lua  player tooltip: second line (Talents a/b/c), gated by specPoints; refresh/update both lines
Settings.lua     specPoints option after ilvlPlayerTooltip; the 4 item level sections renamed
CLAUDE.md        architecture lines (Settings keys, ItemLevel, ItemLevelUI, SettingsPanel sections)
```

### Pattern 1: Read points per tree from a config (Forever's own way)
Follow `ClassTalentsFrameMixin:RefreshTreeHeaders` exactly. Take the groups in `ipairs` order (that is the order Blizzard lays the headers out, left to right; it does not sort by `orderIndex`), match the currency info by `traitNodeGroupID`, take `currencyInfos[1].spent`, and count a missing group as 0 (Blizzard shows "0") [VERIFIED: `Camelot/.../Blizzard_ClassTalentsFrame.lua:95-108, 336-343`].

### Pattern 2: Your own config
Blizzard's shared frame tries `C_ClassTalents.GetActiveConfigID()`, then its saved list, then the Camelot override `GetFallbackConfigID()` = `GetCombatConfigIDForSpecGroup(activeTab)`. The active tab is the primary tab when `GetActiveSpecGroup() == 1`, and the tab IDs are 1 / 2 [VERIFIED: `ClassTalentsFrame.lua:893-900`; `Camelot/.../Blizzard_ClassTalentsFrame.lua:111-121, 144-145`]. RaiderIO goes straight to `GetCombatConfigIDForSpecGroup(GetActiveSpecGroup())` and checks for type `CamelotCombat` [VERIFIED: RaiderIO `ReadForeverConfig`]. **Use:** `GetCombatConfigIDForSpecGroup(GetActiveSpecGroup())` first; if that gives nothing, `C_ClassTalents.GetActiveConfigID()`. When the type field is readable, require `type == Enum.TraitConfigType.CamelotCombat` (when the Enum exists). The probe prints both IDs and the type.

### Pattern 3: Inspected config: when it is valid
- **Valid at `INSPECT_READY` for that GUID:** Forever's talent frame refreshes the `-1` config on `INSPECT_READY` for its unit: "The inspect config is replaced when data arrives" [VERIFIED: `Camelot/.../Blizzard_ClassTalentsFrame.lua:66-77`]. RaiderIO reads it inside its `INSPECT_READY` handler [VERIFIED: `beacon.lua:1955-1976`].
- **Gone after `ClearInspectPlayer()` (inferred):** Forever's Inspect window skips `ClearInspectPlayer()` while `PlayerSpellsFrame:IsInspecting()`, so that it doesn't wipe the talent frame's inspected view [VERIFIED: `Blizzard_InspectUI/Camelot/Blizzard_InspectUI.lua:144-151`]. Treat the data as valid only between our `INSPECT_READY` and our `Done`. The probe checks this (see Open Questions).
- **Unit-agnostic:** config `-1` is "whoever the latest inspect answered", not a unit argument. So the existing `serial == c.serial and lastTarget == c.guid` check (`ItemLevel.lua:471-473`, `:702`) is exactly the guard needed. Read talents **synchronously in the first pass** (`tries == 0`, inside the `INSPECT_READY` dispatch) and keep them on `c`; don't re-read them on the 1 s item retries.

### Anti-Patterns to Avoid
- **`GetSpecializationInfo(i).pointsSpent` as the tooltip source:** no Forever UI reads it, there is one spec per class, and on the 5.5 client it is documented as unsupported. Probe only.
- **Reading config `-1` from a timer or on tooltip show:** it may then belong to someone else's inspect, or be cleared. Read only in the guarded `INSPECT_READY` pass.
- **Hard-coding 3 trees:** use `#displayInfos` (the game's group count). Show whatever count comes back (Forever classes have 3).
- **Calling `PlayerSpellsFrame:SetInspectUnit`, `C_Traits.GenerateInspectImportString`, or anything that loads a UI:** reads only.
- **A parallel inspect for talents:** never. One inspect fills both values.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Points per tree | Summing node ranks by position (MythicSim's canvas math) | `C_Traits.GetGroupCurrencyInfo` `spent` | That's what Forever's own header shows; node math needs off-canvas exceptions (MythicSim's notes) |
| Tree count / order | Class tables of tree names | `C_Traits.GetGroupDisplayInfoByTreeID` in `ipairs` order | Same order as the talent frame |
| Inspect scheduling | A second queue | `ILvl.RequestInspect` and its guard | Already proven live |
| Tooltip line add/update | New tooltip hook | The existing `OnTooltipUnit` / `RefreshTooltip` / `UpdateLine` mechanics, generalized to two lines | One post-call, consistent order |

## Integration Points (this repo, file:line)

**`ItemLevel.lua`**
- `:93` `known = {}` (guid → `{ ilvl, source, name, at }`). **Recommend:** add a `talents` field here: a list of numbers, or `false` meaning "answered, nothing readable" (Claude's discretion; one cache, so "updated only by a later inspect" holds for free).
- `:227-253` `OnLearned` / `Remember(unit, r)`. Today it returns early when `not r.complete` (`:238`), so talents would be lost when items never load. **Change:** `Remember(unit, r, talents)` keeps the talents even when the item level is incomplete (keeping the old `ilvl` if any), and fires `learned` when either value was stored. Observers (`ItemLevelUI.lua:158`, `:269`) use only `guid`, so the call stays `fn(guid, ilvl)` (`ilvl` may be nil).
- `:256-273` `ILvl.Of(unit)`: model a sibling `ILvl.TalentsOf(unit)` on it (you: live `ReadTalents(OwnConfigID())`; others: `known[guid].talents`). Plus `ILvl.TalentsKnown(unit)` (true when an answer was recorded, even `false` or all-zero), so the tooltip knows whether to request an inspect.
- `:319-344` `ProbeSelf`: add the talent lines (see Probe below).
- `:410-422` `InspectOpen` / `Busy`: **add** `PlayerSpellsFrame and PlayerSpellsFrame.IsInspecting and PlayerSpellsFrame:IsInspecting()` (pcall; secret / nil counts as busy-or-not as below). See Pitfall 3.
- `:453-464` `Done`: `ClearInspectPlayer()` additionally only when `PlayerSpellsFrame` is not inspecting (mirrors `Blizzard_InspectUI/Camelot/Blizzard_InspectUI.lua:149`).
- `:466-504` `ReadCurrent(tries)`: after the serial/lastTarget check (`:471`), when `tries == 0` capture `c.talents = ReadTalents(INSPECT_CONFIG)`, and keep `c.talentsRead = true` even when the result is nil. Pass `c.talents` to `Remember` at `:483`. In the non-quiet branch (`:484-496`) print the talent probe lines. `gotValue` for `Done` stays "ilvl known" (keeps the 30 s retry semantics). **Also:** when items stay incomplete after the retries, still `Remember` the talents.
- `:569-590` `ILvl.RequestInspect`: unchanged (the gate lives in the caller).
- `:675-717` foreign `OnInspectReady` / `Try`: on the first `Try` (synchronous, `tries == 0`) capture talents under the same `serial == s and lastTarget == guid` check, then `Remember(u, r, talents)`.

**`ItemLevelUI.lua`**
- `:64-97` one line's state (`lineFor`, `lineText`, `lineIndex`, `AddLine`, `UpdateLine`): generalize it to two tracked lines (ilvl, talents), each with its own text and index, `UpdateLine` per line.
- `:99-122` `OnTooltipUnit`: today it returns at once when `ilvlPlayerTooltip` is off (`:104`). **Change:** proceed when either `ilvlPlayerTooltip` or `specPoints` is on. Add the ilvl line (if on and known), then the talents line (if on, known and not all zero). Request an inspect when the unit isn't you, is friendly and readable, and (`ilvl` wanted and unknown) or (`talents` wanted and not answered).
- `:126-151` `RefreshTooltip(guid)`: the same two-line logic. Add whichever line is missing, in order (ilvl then talents), and update the ones present. With only the ilvl setting on, it behaves as today.
- `:153-162` `PlayerTooltip` installer: add `ns.Settings.OnChange("specPoints", …)`? Not needed: tooltips rebuild on the next show (the ilvl option doesn't either).
- `:22-31` `UI.Text(n)`: add `UI.TalentText(list)` → `"Talents " .. table.concat(list, "/")`. Label: `TALENTS` global when it is a plain, non-secret string, else `"Talents"` [ASSUMED: global `TALENTS` exists as "Talents"; the fallback makes this harmless].
- `:597-602` `UI.Init`: no new spot (same "player" installer).

**`Settings.lua`**
- `:121-145`: rename `section = "Item level"` → `"Item level and talents"` on all four item level options. Insert `{ key = "specPoints", section = "Item level and talents", label = "Talent points", tooltip = "Show talent points per tree (e.g. 31/20/0) on friendly players' tooltips." }` right after `ilvlPlayerTooltip` (`:127`). No `parent`. The default comes from `:178-181`.
- `:20` RESERVED: no change. `specPoints` is new; `Core.lua` `ns.Migrate` needs nothing.

**`UI/SettingsPanel.lua`**: no change. Headers come from consecutive `opt.section` values (`:36-40`). `/tgf set specpoints on|off` works through `opt.key:lower()` (`:124`).

**`Core.lua`**: `/tgf ilvl` at `:321-322` stays. Optionally update the USAGE string (`:298`); no change is needed.

## Common Pitfalls

### Pitfall 1: Wrong API, empty numbers
**What goes wrong:** `GetSpecializationInfo(i).pointsSpent` returns 0 / defaults on Forever, or maps to the class's single spec, so no line ever shows (or `x/0/0`).
**How to avoid:** use the C_Traits group currency read; the probe prints both for comparison.
**Warning signs:** the probe's `pointsSpent` column is all 0 while the `C_Traits` column matches the talent frame.

### Pitfall 2: Reading `-1` at the wrong moment
**What goes wrong:** the talents of another player (a later or foreign inspect), or nothing (after `ClearInspectPlayer`).
**How to avoid:** read only in the `INSPECT_READY` dispatch, after the `serial` / `lastTarget` check, on the first pass. Never from a retry timer without the same check, and never after `Done`.

### Pitfall 3: Breaking Forever's "Inspect Talents" view (existing gap, now in scope)
**What goes wrong:** Forever's friendly-player menu has **Inspect Talents** (`Blizzard_UnitPopup/Camelot/UnitPopupMenus.lua:46-55`). It does `NotifyInspect` and then, on `INSPECT_READY`, `PlayerSpellsUtil.OpenToClassTalentsTab(unit)` (`UnitPopupSharedButtonMixins.lua:304-350`; `PlayerSpellsUtil.lua` loads on camelot, `[AllowLoadGameType mainline]` with camelot in the mainline family). While that frame shows the inspected tree (config `-1`), our quiet inspect (allowed 2 s after a foreign inspect) replaces the `-1` data, and our `Done` may `ClearInspectPlayer()` and empty the view. `InspectOpen()` (`ItemLevel.lua:410-418`) checks only `InspectFrame`.
**How to avoid:** `Busy()` also returns true while `PlayerSpellsFrame:IsInspecting()`. `Done` doesn't clear while it is. Blizzard's Inspect window uses the same test (`Blizzard_InspectUI/Camelot/Blizzard_InspectUI.lua:149`). Read-only call; guard with `PlayerSpellsFrame and type(PlayerSpellsFrame.IsInspecting) == "function"`, pcall, secret → busy.

### Pitfall 4: Inspect loops for players with no talent data
**What goes wrong:** a low-level player (no config, or all 0) never gets "known" talents, so every hover re-requests an inspect (only the 30 s `tried` throttle applies, and only when ilvl failed too).
**How to avoid:** record that the inspect answered (`talents = false`, or the all-zero list). The tooltip asks for an inspect only when no answer is recorded. All-zero or `false` → no line, no new inspect (a later foreign inspect may still update it).

### Pitfall 5: Losing talents when items don't load
**What goes wrong:** `Remember` bails when `not r.complete` (`ItemLevel.lua:238`), so talents read fine are dropped.
**How to avoid:** store the talents independently of item completeness (and keep any earlier ilvl).

### Pitfall 6: Tooltip shows talents only when the item level option is on
**What goes wrong:** `OnTooltipUnit` returns at `ItemLevelUI.lua:104` when `ilvlPlayerTooltip` is off.
**How to avoid:** gate each line on its own key. Run the handler when either key is on.

### Pitfall 7: Line order and in-place updates
**What goes wrong:** `UpdateLine` tracks one line by index. With two lines, a refresh can rewrite the wrong line, or append the ilvl line after the talents line.
**How to avoid:** track both texts and indices. On a refresh, add missing lines in order (ilvl first). If only the ilvl line is missing but the talents line is already there, update in place rather than appending out of order. The simplest rule: when the ilvl line is missing and the talents line exists, skip adding ilvl late. Both values normally arrive in the same `Remember`, so this case is rare; document whichever rule you choose.

### Pitfall 8: Your own staged (unsaved) talent clicks
**What goes wrong:** with the talent frame open and points clicked but not applied, the active config's `GetGroupCurrencyInfo` might count staged points.
**How to avoid:** accept it (live read is the decision), or check it in game. It is listed in Open Questions. `GetTreeCurrencyInfo` has `excludeStagedChanges`, but it is per tree, not per group.

## Code Examples

### 1. Points per tree from a config (mirrors Forever's tree headers)
```lua
-- Source: Blizzard_PlayerSpells/Camelot/ClassTalents/Blizzard_ClassTalentsFrame.lua:82-109, 331-344 (forever)
local INSPECT_CONFIG = (Constants and Constants.TraitConsts and Constants.TraitConsts.INSPECT_TRAIT_CONFIG_ID) or -1

-- Points spent per tree in the game's order, or nil when the config can't be read.
local function ReadTalents(configID)
	if Secret(configID) or type(configID) ~= "number" or not (C_Traits and C_Traits.GetConfigInfo
		and C_Traits.GetGroupDisplayInfoByTreeID and C_Traits.GetGroupCurrencyInfo) then
		return nil
	end
	local ok, info = pcall(C_Traits.GetConfigInfo, configID)
	if not ok or Secret(info) or type(info) ~= "table" or Secret(info.treeIDs) or type(info.treeIDs) ~= "table" then
		return nil
	end
	local treeID = info.treeIDs[1]
	if Secret(treeID) or type(treeID) ~= "number" then
		return nil
	end
	local ok2, groups = pcall(C_Traits.GetGroupDisplayInfoByTreeID, treeID)
	if not ok2 or Secret(groups) or type(groups) ~= "table" or #groups == 0 then
		return nil
	end
	local ids = {}
	for i, g in ipairs(groups) do
		if Secret(g.groupID) then return nil end
		ids[i] = g.groupID
	end
	local ok3, currency = pcall(C_Traits.GetGroupCurrencyInfo, configID, ids)
	if not ok3 or Secret(currency) or type(currency) ~= "table" then
		return nil
	end
	local out = {}
	for i, id in ipairs(ids) do
		local spent = 0 -- a group with no currency info shows "0", as Blizzard's header does
		for _, c in ipairs(currency) do
			if c.traitNodeGroupID == id then
				local first = c.currencyInfos and c.currencyInfos[1]
				local v = first and first.spent
				if Secret(v) then return nil end
				spent = type(v) == "number" and v or 0
				break
			end
		end
		out[i] = spent
	end
	return out
end
```

### 2. Your own config
```lua
-- Source: RaiderIO ReadForeverConfig; Camelot ClassTalentsFrame GetFallbackConfigID (:119-121); shared RefreshConfigID (:893-900)
local function OwnConfigID()
	local S = C_SpecializationInfo
	if S and S.GetCombatConfigIDForSpecGroup and S.GetActiveSpecGroup then
		local ok, group = pcall(S.GetActiveSpecGroup)
		if ok and not Secret(group) and group then
			local ok2, id = pcall(S.GetCombatConfigIDForSpecGroup, group)
			if ok2 and not Secret(id) and type(id) == "number" then
				return id
			end
		end
	end
	if C_ClassTalents and C_ClassTalents.GetActiveConfigID then
		local ok, id = pcall(C_ClassTalents.GetActiveConfigID)
		if ok and not Secret(id) and type(id) == "number" then
			return id
		end
	end
	return nil
end
```

### 3. Show rule
```lua
-- nil / false / all zero -> no line
local function Shown(t)
	if type(t) ~= "table" or #t == 0 then return nil end
	for _, n in ipairs(t) do if n > 0 then return t end end
	return nil
end
-- "Talents 36/12/3"
```

### 4. Probe additions (`/tgf ilvl`)
For you (in `ProbeSelf`), print:
- `GetActiveSpecGroup()`, `GetCombatConfigIDForSpecGroup(group)`, `C_ClassTalents.GetActiveConfigID()`, the config's `type` (and whether it equals `Enum.TraitConfigType.CamelotCombat`), `treeIDs[1]`
- each group: `groupID`, `orderIndex`, `displayName`, `spent`
- `GetSpecialization()` and, for `i = 1..3`, `GetSpecializationInfo(i, false)`: name and 7th return (`pointsSpent`)
- `tooltip shows: Talents a/b/c` or `nothing`

For each inspected member (non-quiet `ReadCurrent`), print:
- `GetConfigInfo(-1)` type and tree, the per-group `spent`
- `GetSpecializationInfo(i, true)` 7th return
- `tooltip shows: …`

In `Done`, for a non-quiet inspect only and right after `ClearInspectPlayer()`, print one more `ReadTalents(-1)` result labelled "after clear". This settles whether clearing wipes the data. It is a read only.

## State of the Art

| Old Approach | Current Approach (Forever) | Impact |
|--------------|----------------------------|--------|
| `GetTalentTabInfo(i, isInspect)` → `pointsSpent` (Era/Classic tabs) | Trait configs: `C_Traits` group currency per tree (`CamelotCombat` config type) | Deprecated shim not loaded on camelot; Details! still calls `GetTalentTabInfo` (`Details/core/gears.lua:766`) and likely gets nothing on Forever [ASSUMED] |
| `GetSpecializationInfo(i).pointsSpent` (Cata-era trees) | same as above | Mists shim says unsupported on 5.5+; Forever has one spec per class |

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | `ClearInspectPlayer()` empties the `-1` config (inferred from Blizzard skipping the clear while its talent frame inspects) | Pattern 3 | Low: we read before clearing either way; the probe's "after clear" line settles it |
| A2 | `GetGroupCurrencyInfo` on the inspect config returns the inspected player's spent points (as the talent frame's header shows when inspecting) | Pattern 3 | Medium: the line would never show for others. Probe check with a group member |
| A3 | Forever's group order from `GetGroupDisplayInfoByTreeID` is the talent frame's left-to-right order | Pattern 1 | Low: Blizzard's own header loop uses `ipairs`; probe prints `orderIndex` |
| A4 | Global `TALENTS` is the string "Talents" on Forever | Integration (UI.TalentText) | None: plain-string check plus "Talents" fallback |
| A5 | Staged (unapplied) clicks may count in your own live figure | Pitfall 8 | Low cosmetic |
| A6 | `GetSpecializationInfo(i).pointsSpent` is empty / unsuitable on Forever | Summary | If it does work, nothing is lost: the probe shows both; C_Traits is still what the game's UI shows |

## Open Questions (for HUMAN-UAT and the `/tgf ilvl` probe)

1. **Does the inspect config carry the other player's points at `INSPECT_READY`?** Probe in a group: per-member C_Traits line vs their talent frame (Inspect Talents from the menu). Expect equal.
2. **Does `pointsSpent` work at all on Forever?** Probe compares. If it matches C_Traits, record it in PROJECT.md decisions; keep C_Traits regardless (the game's own path).
3. **Is the data gone after `ClearInspectPlayer`?** Probe's "after clear" line.
4. **Own config choice:** do `GetCombatConfigIDForSpecGroup(GetActiveSpecGroup())` and `GetActiveConfigID()` agree, and is the type `CamelotCombat` (4)? With dual spec, switch specs and hover yourself: the line should follow.
5. **Staged clicks:** click points without applying, hover yourself; note whether the figure counts them.
6. **Inspect Talents coexistence:** open Inspect Talents on a party member, then hover other players for 10 s. The inspected tree must stay (no swap, no blank). Today's code would break it; the new guard must keep it intact.
7. **Low-level / no-talent player (level < 10):** no line, and no repeated inspects (`/tgf ilvl` shows one).
8. **Settings page:** section "Item level and talents"; "Talent points" second; toggling it off removes the line on the next hover, with the item level line unaffected, and vice versa.

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| stylua | formatting rule | ✓ | 2.3.1 | — |
| node | session smoke harness (fengari) | ✓ | v24.14.0 | — |
| Smoke harness | regression checks | ✓ (session scratchpad `smoke/`: `harness.lua` stub head above `local fail = 0`, tests in `tail.lua`, `node splice.js`, `node run.js <repo> [""|--fallback|--attach]`) | — | — |
| Live Forever client | HUMAN-UAT | author only | 16001 | deferred to the end (autonomous: no pauses) |

Harness stubs to add: `C_Traits.GetConfigInfo` / `GetGroupDisplayInfoByTreeID` / `GetGroupCurrencyInfo`, `C_SpecializationInfo.GetActiveSpecGroup` / `GetCombatConfigIDForSpecGroup`, `C_ClassTalents.GetActiveConfigID`, `Constants.TraitConsts.INSPECT_TRAIT_CONFIG_ID = -1`, `Enum.TraitConfigType.CamelotCombat = 4`, and a `PlayerSpellsFrame` with `IsInspecting()`. Existing ilvl tests (`tail.lua` around lines 797-829, 1455-1640) show the pattern: fire `INSPECT_READY` through `ilvlFrame.__scripts.OnEvent`, drive the tooltip post-call through `G.__tipPost`.

Suggested checks:
- own line `Talents 31/20/0` and its order after the ilvl line
- no line when all zero, when the C_Traits stubs are missing, or when a value is secret
- `specPoints` off → no talents line, ilvl line unaffected; ilvl off + spec on → talents line alone, and the inspect is still requested
- an inspect captures the talents in the same `INSPECT_READY` pass; a displaced inspect stores no talents
- items incomplete → talents still stored
- `PlayerSpellsFrame:IsInspecting()` true → no quiet inspect sent and no `ClearInspectPlayer`
- a settings section header named "Item level and talents"; `specPoints` second in it

## Security Domain

Not a web or service phase. The relevant controls are the client's: the taint / secret-value rules. V5 (input validation) maps to the `issecretvalue()` and type checks on every API return. No auth, session, crypto or storage (session-only cache, nothing saved beyond the `specPoints` boolean).

| Threat | Category | Mitigation |
|--------|----------|------------|
| Tainting Blizzard's talent / inspect UI | Tampering | Reads only; no writes to `PlayerSpellsFrame` / `InspectFrame`; no `SetInspectUnit` |
| Clobbering the user's own inspect | Denial of service (UX) | The guard extended to `PlayerSpellsFrame:IsInspecting()` (Pitfall 3) |
| Secret values in comparisons | Error / taint | `Secret()` before any comparison, fail closed (no line) |

## Suggested Plan Split (coarse granularity)

- **14-01 (wave 1): Talent data in `ns.ILvl`.** `ReadTalents`, `OwnConfigID`, the `known[guid].talents` field and the new `Remember` signature, the capture in `ReadCurrent` and the foreign `Try` (first pass, guarded), `ILvl.TalentsOf` / `TalentsKnown`, the `PlayerSpellsFrame:IsInspecting()` guard in `Busy` / `Done`, the probe lines (self, inspected, after clear), smoke harness stubs and data checks, the CLAUDE.md `ItemLevel.lua` line, `stylua .`
- **14-02 (wave 2, depends on 01): Tooltip line and setting.** `specPoints` in OPTIONS after `ilvlPlayerTooltip`, the section rename, the `ItemLevelUI` two-line tooltip (gate per key, inspect request when either value is missing, refresh / update in order), `UI.TalentText`, smoke checks for the display and settings, CLAUDE.md lines (`Settings.lua` keys, `ItemLevelUI.lua`, `UI/SettingsPanel.lua` section names), `stylua .`, the HUMAN-UAT list above (Open Questions 1-8), and a note that a README tooltip screenshot may need retaking

(A single plan with these as two tasks is also fine at coarse granularity. Keep the data task first.)

## Sources

### Primary (HIGH)
- wow-ui-source `forever`: `Blizzard_PlayerSpells/Camelot/ClassTalents/Blizzard_ClassTalentsFrame.lua` (tree headers, inspect refresh, fallback config); `Blizzard_PlayerSpells/ClassTalents/Blizzard_ClassTalentsFrame.lua:883-900, 1427-1437`; `Blizzard_SharedTalentUI/Blizzard_SharedTalentFrame.lua:1310-1342`; `Blizzard_PlayerSpells/Blizzard_PlayerSpells.toc` (Camelot overrides); `Blizzard_InspectUI/Blizzard_InspectUI.toc` (no inspect talent tab on camelot) and `Camelot/Blizzard_InspectUI.lua:41-50, 87-97, 144-151`; `Blizzard_UnitPopup/Camelot/UnitPopupMenus.lua:46-55`; `Blizzard_UnitPopupShared/UnitPopupSharedButtonMixins.lua:304-350`; `Blizzard_FrameXMLUtil/Blizzard_FrameXMLUtil.toc` (PlayerSpellsUtil mainline); `Blizzard_DeprecatedSpecialization/*.toc` and `Deprecated_Specialization_Mists.lua:18-20`
- Generated API docs: `SpecializationInfoDocumentation.lua:41-55, 90-103, 254-282`; `SharedTraitsDocumentation.lua:201-215, 281-310, 972-979, 1013-1023, 1080-1091, 1188-1198`; `TraitConstantsDocumentation.lua:138, 352-354`; `ClassTalentsDocumentation.lua:73-80`; `PaperDollInfoDocumentation.lua:352-357` (`INSPECT_READY`, synchronous, payload `inspecteeGUID`)

### Secondary (MEDIUM: installed Forever addons, usage evidence)
- RaiderIO `beacon.lua` (`ReadForeverConfig`, `TalentKind`, `ReadInspectedTalents`, `OnInspectReady`)
- MythicSim `Forever.lua:100-226` (one trait tree per class, three tabs; spent from tree currency)
- MRT `Inspect.lua:991-996` (`INSPECT_TRAIT_CONFIG_ID` → `GetConfigInfo` → `treeIDs[1]`)
- Details `core/gears.lua:756-770` (legacy `GetTalentTabInfo`, not a Forever path)

## Metadata

**Confidence breakdown:**
- API path: HIGH (Blizzard's Forever frame + RaiderIO + MRT agree)
- Inspect timing: HIGH for "valid at INSPECT_READY"; MEDIUM for "cleared by ClearInspectPlayer" (inferred)
- Integration / pitfalls: HIGH (read from the current code)

**Research date:** 2026-11-16
**Valid until:** 2026-12-16 (Forever client patches can change the Camelot overrides)
