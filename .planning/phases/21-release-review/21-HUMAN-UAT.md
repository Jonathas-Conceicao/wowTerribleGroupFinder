---
status: complete
phase: 21-release-review
source: [21-CONTEXT.md, 21-01-SUMMARY.md, 21-02-SUMMARY.md, 18-HUMAN-UAT.md, 19-HUMAN-UAT.md, 20-HUMAN-UAT.md]
started: 2026-11-24
updated: 2026-11-24
---

## Current Test

[awaiting the author's review and in-game pass: the autonomous run stopped here]

## Tests

### 1. CHANGELOG review
expected: The `## v0.3.0` section at the top of CHANGELOG.md (first `## ` heading, published by the release workflow as the release notes) is a draft. Review and rewrite as wished. It has Added and Changed only: no bug that existed in v0.2.2 is known fixed, so there is no Fixed heading. `## v0.2.2` and everything below are unchanged.
result: passed (author, 2026-11-25)

### 2. README wording proposals
applied 2026-11-25 by the author's approval: a, b (rewritten for the round 2 eye), c, d, e and the region flags line; f (usage commands) dropped, as in the changelog
expected: README.md is not edited until you approve; the orchestrator applies only the approved lines. There is no flagpedia credit in any of them.

a. Opt-in defaults (a sentence after the intro paragraph)
Before: goes after the intro paragraph, the line `groups, and a new Messages tab holds whisper presets for contacting them in one click.`
After:
```

Only the group finder's options are on at first; item level, talents, slot info and the
damage meter prompts are turned on in Settings > AddOns > TerribleGroupFinder.
```

b. New bullet, Elite quest eye
Before: goes after the line `  game's row tooltip` (end of the Stock behaviour kept bullet).
After:
```
- **Elite quest eye** - an eye beside elite quests in the quest tracker opens the group
  finder's Listing tab with the quest's name, category and zone
```

c. New bullet, Slot item level and enchants
Before: goes after the line `  a row under Movement Speed on the character sheet, and on the Inspect window` (the Item level bullet, as changed in d).
After:
```
- **Slot item level and enchants** - each item's level and enchant beside its slot on the
  character sheet and the Inspect window, with "No enchant" where the slot can take one
```

d. Item level bullet (factual: now off by default; optionally folds in v0.2.1's talent points wording)
Before:
```
- **Item level** - shown on friendly players' tooltips, on weapon and armor tooltips, as
  a row under Movement Speed on the character sheet, and on the Inspect window
```
After:
```
- **Item level** - off until turned on in Settings; then shown on friendly players'
  tooltips (with their talent points per tree), on weapon and armor tooltips, as a row
  under Movement Speed on the character sheet, and on the Inspect window
```

e. Settings page bullet (four sections, new options, which start on)
Before:
```
- **Settings page** - in Settings > AddOns: turn each item level spot, Dynamic refresh,
  the animations and region flags on or off, and open the Messages tab from a button
```
After:
```
- **Settings page** - in Settings > AddOns, in four sections: Group finder (Elite quest
  button, Dynamic refresh, the animations, region flags; on at first), Player inspection
  (player and item tooltips, talent points, character sheet, Inspect window, slot item
  level and slot enchants; off at first), Damage meter (the two reset prompts, off at
  first, and Move) and Messages (a button opens the Messages tab)
```

f. Usage: `/tgf quest`, `/tgf gear` and the still-missing `/tgf meter`
Before:
```
- `/tgf ilvl` prints the item level figures the game gives for you and your group;
  `/tgf region` prints the region the addon reads for listings
```
After:
```
- `/tgf ilvl` prints the item level figures the game gives for you and your group;
  `/tgf region` prints the region the addon reads for listings; `/tgf quest` and
  `/tgf gear` print what the addon reads for your tracked quests and your gear;
  `/tgf meter` asks to reset the damage meter now
```

Reminder only (decide again; the v0.2.2 review applied none, README wording stayed as is). Still as before in README.md:
```
- **Region flags** - a US or Oceania flag after each name, your own listing included,
  with the region in the row tooltip
```
(proposed: a flag for US, Oceania, EU, China, Korea or Taiwan; other regions show their first two letters; the row tooltip names the region)
```
  | `{activity}` | the first activity of their listing |
```
(proposed: "the activity of their listing (you pick one when it lists several)")
Also still missing: a damage meter reset bullet (joining a group or entering an instance asks whether to reset Details! or the game's own meter; each prompt can be turned off; movable from Settings), and in the Whisper presets bullet the activity menu (a listing with several activities asks which one to name, or Edit to write it yourself).
result: passed (author, 2026-11-25)

### 3. Screenshot reminders
expected: You retake the prints (agents never make images). Wanted or not is your call:
- The Settings page: new section order (Group finder, Player inspection, Damage meter, Messages) and the new options (Elite quest button, Slot item level, Slot enchants)
- The tracker eye beside an elite quest
- The Listing tab with the hint box and the outlined Quests & Zones button
- The slot info (item level and enchant beside each slot) on the character sheet and the Inspect window
- The two prints in the README (`tgf_refresh.gif`, `tgf_lfg_message_config.png`) show screens v0.3.0 did not change.
This folds in 19-HUMAN-UAT item 8 and 20-HUMAN-UAT item 7 (whether these prints are wanted).
result: passed (author, 2026-11-25)

### 4. Version
expected: Confirm v0.3.0 (the TOC keeps `## Version: @project-version@`; tag `v0.3.0` on `main` after the squash merge, by your `/gsd-complete-milestone`; the squash-merge message lists only what players get, none of the in-milestone fixes the branch commits name). Local zip check from 21-01: 28 files, no warnings; entries are the TOC, Core, Settings, Preview, ItemLevel, ItemLevelUI, QuestButton, GearSlots, Region, MeterReset, Messages, Listings, UI/{Widgets.lua, Templates.xml, Motion, Table, MainFrame, InPlace, SettingsPanel, Listing}, Media/Textures/{tgf_icon_64x64, flag_au, cn, eu, kr, tw, us}.tga and LICENSE; nothing from Media/Source, Media/Screenshots or .planning.
result: passed (author, 2026-11-25)

### 5. Deferred in-game checks
expected: Run all of these in one session; the release waits on them. Deploy first: `./scripts/install.bat`, then `/reload` in game (the build was deployed by the autonomous run, see 21-02-SUMMARY.md); use `/console taintLog 1` for the taint checks. The source files stay as they are (fill results there or here, your choice).

From 18-HUMAN-UAT.md (opt-in defaults and Settings sections):
- (18-1) Fresh install defaults: with no saved file (rename `TerribleGroupFinder.lua` in SavedVariables), no item level text on tooltips / sheet / Inspect, no talent line, no meter prompt; the finder's table, Dynamic refresh with swipes and region flags work
- (18-2) Existing player keeps their options: with a v0.2.2 saved file (including one holding only `schema = 3`), everything that showed before still shows; an option the player had turned off stays off; the new slot options are off
- (18-3) Settings page order: Settings > AddOns > TerribleGroupFinder shows Group finder (Elite quest button, Dynamic refresh > Swipe animations, Region flags), Player inspection (Player tooltips, Talent points, Item tooltips, Character sheet, Inspect window, Slot item level, Slot enchants), Damage meter (two prompts, Move), Messages
- (18-4) New keys settable: `/tgf set eliteQuestButton off`, `/tgf set slotItemLevel on`, `/tgf set slotEnchants on` print the change and the open page's checkboxes follow

From 19-HUMAN-UAT.md (elite quest eye):
- (19-1) The eye in the tracker: tracked elite quests (and elite campaign quests) show the eye at the block's top right, left of a quest item button when there is one; non-elite quests show none; a long title isn't squeezed into a wrap (it may run under the eye); the eye keeps up as quests are tracked / untracked / completed
- (19-2) Tooltip: hovering shows "Find a group for this quest" (gold) and the note line
- (19-3) Click out of combat: the finder opens on Listing, widened, with the hint box (quest name + Elite, Category: Quests & Zones, Zone, Description) in the added strip and a pulsing outline on Quests & Zones; how the widened Listing tab looks is your call (the content stretches with the frame)
- (19-4) Post and Search still work: after using the eye, picking the category / activity, typing the description and posting works; searching on Browse works; `/console taintLog 1` shows nothing from TerribleGroupFinder, no ADDON_ACTION_BLOCKED
- (19-5) Hint clears: the hint and outline go away (and the width comes back) on finder close, tab change, a listing made, the close button, and combat start (width restored after combat)
- (19-6) In combat and with a listing: clicking in combat prints "can't open the group finder in combat." and opens nothing; clicking while you already have a listing opens Listing and prints the hint as a chat line
- (19-7) No double eye; setting; probe: a quest the game gives its own eye shows no second eye; Elite quest button off (Settings or `/tgf set`) hides every eye at once; `/tgf quest` lists the tracked quests (elite, tag, game eye, our eye, zone sources) and the Quests & Zones activities; check which zone source is right

From 20-HUMAN-UAT.md (per-slot gear info):
- (20-1) Layout on the character sheet and the Inspect window: with Slot item level and Slot enchants on, each slot shows two small lines beside its icon toward the model (left column right of the icon, right column and main hand left of it, off hand / ranged above); nothing overlaps the model, a neighbouring slot or the ammo slot; nothing is drawn on the icons; the layout holds at UI scale 0.8 and 1.2 (the offsets are constants at the top of `GearSlots.lua`)
- (20-2) Enchantable slots on Forever: "No enchant" (red) only on head, neck, back, chest, wrist, hands, legs, feet, main hand, off hand and a bow / gun / crossbow; never on shoulders (author, 2026-11-25: no enchanter shoulder enchants on Forever), belt, rings, trinkets; enchanted slots show the enchant's name, shoulders included (rings and head / off-hand marks: see item 6)
- (20-3) Inspect timing: nothing shows before the inspect answers; inspecting another player never shows the previous player's values; reopening starts blank; a player with uncached items fills in shortly after
- (20-4) Options: each option alone shows its line in the first spot; turning one off clears it from open windows at once; both off clears everything
- (20-5) Taint: with `/console taintLog 1`, equipping / unequipping and clicking slots on the sheet and the Inspect window log nothing from TerribleGroupFinder
- (20-6) `/tgf gear`: prints each of your slots (level, enchant ID, enchant line, sockets, enchantable) and the inspected player's while the Inspect window shows

Round 2 (author's feedback of 2026-11-25; supersedes 19-1's "left of a quest item button", 19-3's widened finder and 19-5's width restore):
- (R2-1) Eye: the addon's purple eye in retail's square button, at the block's top right; a quest item button sits left of it, centred on it (out of combat)
- (R2-2) Secure click, finder closed: one click opens the finder on Listing with Quests & Zones picked and the quest's zone ticked (when its row is on screen without scrolling); the finder keeps its normal width; the hint box sits outside it, right of the side tabs: quest name, Zone (ticked / tick it), Description: type "LFM <name>"
- (R2-3) Secure click, finder already open (on Browse, Messages or Listing): it doesn't close; same result as R2-2
- (R2-4) Post works after the eye: pick a playstyle, type the description, List Self / List Group: the listing is made, no ADDON_ACTION_BLOCKED, `/console taintLog 1` shows nothing from TerribleGroupFinder; also with "cast on key down" on and off (`ActionButtonUseKeyDown`)
- (R2-5) No zone match or row off screen: Quests & Zones still picked, the hint says "Zone: tick <zone>"; `/tgf quest` shows each quest's matched activity and whether `LFDMicroButton` / `LFGParentFrameTab1` were found
- (R2-6) Combat: hovering the eye in combat and clicking prints "can't open the group finder in combat."; combat starting while hovering gives no error; the tracker updates in combat raise no errors
- (R2-7) Slot info: all three weapons' text above their icons, 1 px higher than before; left and right columns 2 px further from their icons, nothing clipped
- (R2-9) Description: after the eye's click the cursor is in the empty description box, ready to type "LFM <name>". (Tried 2026-11-25: `Insert` is refused too, "Call is illegal when disabled by security settings", with a taint log line; the try was removed. Check the taint log stays clean now.)
- (R2-10) Hint box: beside the description box, just outside the finder (top right past the side tabs until a category is picked, then it moves); shows only the quest name and "Zone: X (ticked)"; 3 px more room between the text and the border. (Description settled 2026-11-25: addons can't write it; `CreateListing` has no text field; the `/tgf listtest` prototype was removed)
- (R2-8) [passed in game 2026-11-25, author] NEW tags: with a saved file from before (or the current dev one), Settings > AddOns shows NEW on TerribleGroupFinder and on Elite quest button, Slot item level, Slot enchants; closing Settings after viewing the page clears them for good; a fresh install shows none
result: passed (author, 2026-11-25)

### 6. Open author decisions
expected: Each with the default the code ships now:
- Rings enchantable on Forever? Shipped: left out (never "No enchant")
- Head / off-hand "No enchant" noise? Shipped: marked enchantable (shoulders decided 2026-11-25: not flagged)
- The hint box look: decided in round 2 (outside the finder, no widening)
- The slot text layout constants at the top of GearSlots.lua: tune if anything overlaps
- The eye in combat when anchored beside a quest item: shipped, it stays until the next layout; a click in combat only prints
result: passed (author, 2026-11-25)

### 7. Phase confirmation
expected: Your confirmation closes Phase 21; then `/gsd-complete-milestone` (push, squash-merge, tag `v0.3.0`). Nothing of this was done by the autonomous run: no push, merge or tag.
result: passed (author, 2026-11-25)

## Summary

total: 7
passed: 7
issues: 0
pending: 0
skipped: 0
blocked: 0

## Gaps
