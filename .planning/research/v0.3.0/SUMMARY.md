# Research Summary: TerribleGroupFinder v0.3.0

**Confidence:** MEDIUM. Facts from the Blizzard source are HIGH; Forever's server data and how things behave at runtime stay LOW until probed in game.
**Detailed reports:** [STACK.md](STACK.md), [FEATURES.md](FEATURES.md), [ARCHITECTURE.md](ARCHITECTURE.md), [PITFALLS.md](PITFALLS.md)

## Executive Summary

v0.3.0 has three pieces of work that hardly depend on each other:

- Six extras become opt-in, with a schema-4 migration and a reordered Settings page.
- An Elite quest eye button on the objective tracker.
- Item level, enchant and socket marks on each gear slot of the character sheet and the Inspect window.

All four reports agree on the method:

- Only `hooksecurefunc` and child frames of our own, kept in weak tables.
- No writes to fields on Blizzard's frames.
- Each installer is independent and guarded by `pcall`.
- Settings are read through `ns.Settings.Get` at the point of use.

**The eye button cannot do everything the brief asks.** Forever's finder has no path for quests:

- The retail `Blizzard_GroupFinder`, which owns `LFGListUtil_FindQuestGroup`, has `ExcludeLoadGameType: camelot`.
- The vanilla-style finder never sends a `questID`.
- The Listing description box is secure: `SetSecurityDisableSetText` and `SetSecurityDisablePaste` (`Blizzard_LFGVanilla_Listing.xml:615-617`).
- Picking category 116 or an activity from addon code taints the fields that the restricted `CreateListing` and `Search` read.

What we can do: open Forever's finder and show a hint of our own (the quest name, "Quests & Zones", a suggested zone). The player then picks the category and activity, writes the description and posts.

**The gear scope rests on Forever facts nobody has checked yet:**

- Sockets are very likely absent. The stock `SocketDisplay` only shows for Timerunning, and no source mentions sockets.
- Which slots count as enchantable is a design decision.
- Whether inspected item links carry enchant data is unproven.

Mitigation: `/tgf quest` and `/tgf gear` probes, and conservative defaults: draw nothing rather than draw something wrong.

## Where the reports agree

- **Retail quest flow:** absent on Forever. The description box can't be written, and selecting a category or activity from addon code is a taint hazard.
- **Opening the finder:**
  - The safe click is `LFGVanilla_ShowFrame(tab)` out of combat. `IP.OpenMessages` already does this.
  - Extract it into `IP.ShowFinder(tab)`.
- **Elite test:**
  - Use `C_QuestLog.IsEliteQuest`, which Forever's own title prefix uses (`Camelot/QuestUtilsOverrides.lua:6-9`).
  - Fall back to tag ID 1.
  - Wrap it in `pcall` and check `issecretvalue`.
  - Never use the localized "(Elite)" text, `suggestedGroup` or `CanCreateQuestGroup`.
- **Tracker:**
  - Never call `AddRightEdgeFrame` or `GetRightEdgeFrame`.
  - Our own button, parented to the block.
  - Blocks are pooled, so decide again on every layout pass.
- **Gear hooks:**
  - Hook `PaperDollItemSlotButton_Update` and `InspectPaperDollItemSlotButton_Update`.
  - Inspect UI is load-on-demand, so install it with `EventUtil.ContinueOnAddOnLoaded`.
  - No `NotifyInspect` or `ClearInspectPlayer`, and not the quiet queue.
  - Read live from `InspectFrame.unit`.
  - Never touch Blizzard's `SocketDisplay`.
- **Enchant data:**
  - The enchant ID is field 2 of the item link.
  - The enchant name comes from tooltip line type 15 (`ItemEnchantmentPermanent`).
  - "Missing" needs a static table of enchantable slots.
- **Migration:**
  - A frozen list of the six keys that were on in v0.2.2: `ilvlPlayerTooltip`, `specPoints`, `ilvlItemTooltip`, `ilvlCharacterSheet`, `ilvlInspect`, `meterResetOnInstance`.
  - Save `true` only for existing players, and only where `type(db[key]) ~= "boolean"`.
  - Never ask the registry: `Migrate` runs before `Settings.Init`, and `Get` now returns the new defaults.
  - Never loop over all options.
  - Compute `existing` once, at the top of `Migrate`.

## Where they disagree, and the recommendation

| Topic | Positions | Recommendation |
|---|---|---|
| Tracker hook | STACK and PITFALLS: the instance's `UpdateSingle`. ARCHITECTURE: `EndLayout`. | `EndLayout` on each quest module instance (Quest and Campaign). Never the mixin table. |
| Eye widget | ARCHITECTURE: Blizzard's template with overridden scripts. FEATURES and PITFALLS: a button of our own. | A plain button of our own with the retail art: `socialqueuing-icon-eye` at 13x13, `UI-SquareButton-*`, the mouse highlight, the press nudge. Check the atlas first and fall back to a plain texture. Tooltip `TOOLTIP_TRACKER_FIND_GROUP_BUTTON`, with an English fallback. |
| Shim for `LFGListUtil_FindQuestGroup` | STACK: yes. PITFALLS: no. | No shim. The duplicate guard reads `block.rightEdgeFrame` only. |
| Click destination | STACK and PITFALLS: Listing tab plus a hint. FEATURES: Browse with our search box prefilled. ARCHITECTURE: routes A, B and C via `SetSearchToQuestID`. | Baseline: `IP.ShowFinder(1)` plus our hint, and maybe our own glow on the category-116 button. Route A sits behind a constant, off unless a probe proves it safe. |
| Secure-click spike | FEATURES: spike it. PITFALLS: `Click()` on Blizzard's buttons runs tainted. | Defer it out of v0.3.0. |
| Which quests get the eye | STACK: elite, dungeon, raid, or a suggested group over 1. The others: elite only. | Elite only. |
| Room in the header | STACK and ARCHITECTURE: move `HeaderText`'s right anchor (anchors only). FEATURES and PITFALLS: accept the overlap. | Try the anchors-only move; fall back to the overlap. Needs a live check. |
| Setting key names | STACK: `gear*`. ARCHITECTURE and FEATURES: `slot*`. | `slot*`. |
| Phase split | PITFALLS: a separate settings phase. ARCHITECTURE: settings fold into the first phase. | Fold them into Phase 1. |

## Decisions for the author

1. **Eye route:** the scope is reduced to opening the finder plus a hint. Decide where it lands (the Listing tab or Browse) and whether to try route A if a probe shows it works.
2. **Stock eye duplicate guard:** a read-only skip, with no shim.
3. **Missing-enchant marks:** which slots count, and whether there is a level floor (a named constant).
4. **Sockets:** probe first, and drop the feature if nothing on Forever has sockets.
5. **Setting keys:** `eliteQuestButton` (on), plus `slotItemLevel`, `slotEnchants` and `slotSockets` (off), each covering both windows.
6. **Quest scope:** elite only, or also quests tagged dungeon or raid.
7. **First-run hint:** one chat line pointing to `/tgf settings`, or nothing.

## In-game probes (`/tgf quest`, `/tgf gear`)

1. `C_LFGList.CanCreateQuestGroup` for an elite quest: does the stock eye appear, and does clicking it error?
2. `type(C_LFGList.GetActivityIDForQuestID)` and its answer for an elite quest.
3. `GetAvailableActivities(116)`, `GetLfgCategoryInfo(116).autoChooseActivity`, and each activity's `mapID`, `fullName` and `shortName`.
4. Does `SetSearchToQuestID` fire `LFG_LIST_SHOW_SEARCH`, and does it stay set for later searches?
5. Do the atlases `socialqueuing-icon-eye` and `character-emptysocket` exist?
6. `GetItemNumSockets` over all equipped items.
7. The enchant field in inspected item links, and the type-15 tooltip line for an inspected unit.
8. Does the eye overlap a long quest title, and does the moved `HeaderText` anchor survive layout passes?
9. Taint check with `/console taintLog 2`: open the finder through the eye, then post and search by hand.

## Suggested phases

1. **Opt-in defaults, Settings sections, new keys.**
   - Schema-4 migration with the frozen list.
   - Flip the six defaults to off and register the new keys.
   - Page order: Group finder, Player inspection, Damage meter, Messages.
   - A test matrix of saved tables for `Migrate`.
2. **Elite quest eye.**
   - New `QuestButton.lua` with the `EndLayout` post-hook.
   - Extract `IP.ShowFinder(tab)`.
   - The hint overlay and the `/tgf quest` probe.
3. **Per-slot gear info.**
   - New `GearSlots.lua`: the character sheet first, then Inspect.
   - Three states per slot: no item, pending, known.
   - Sockets only if the probe finds any.
   - The `/tgf gear` probe.
4. **Release Review.**
   - Cleanup, CLAUDE.md entries, README screenshot flags.
   - Changelog draft (existing players keep their settings).
   - Live UAT of the probes.
   - Tag `v0.3.0`.

## Open gaps

- How the stock eye behaves on Forever.
- How a quest maps to a category-116 activity. Show the quest name and a zone hint; never pre-select.
- Whether sockets exist on Forever, and whether rings, neck, ranged and off-hand take enchants.
- Whether inspected units carry enchant data.
- Whether the `EndLayout` instance hook works, and how much the header overlaps.
- Settings' Defaults button turns off the `true` values migrated for existing players. CLAUDE.md already accepts this; it only needs documenting.
