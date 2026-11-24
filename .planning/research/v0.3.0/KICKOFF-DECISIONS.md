# v0.3.0 autonomous kickoff decisions (2026-11-24)

The author's answers at the start of `/gsd-autonomous --from 18 --to 21`. Every phase's CONTEXT.md takes
these as locked decisions; nothing here is asked again during the run.

## Milestone scope (from /gsd-new-milestone)

- Defaults for new installs only; existing players keep what they had (schema 4, frozen list)
- Eye: objective tracker only (not the quest log), retail look; click opens the Listing tab + our hint
- Enchants: Forever's enchantable slots (vanilla's plus neck and Forever's other new slot, to be
  researched); the text reads "No enchant" (not "missing"), at every level
- Sockets dropped
- Settings: one key per detail (`slotItemLevel`, `slotEnchants`), each on both windows
- Section order: Group finder, Player inspection, Damage meter, Messages
- Implement, don't probe: build with fallbacks; `/tgf quest` and `/tgf gear` are debug commands
  shipped alongside; in-game checks at the end

## Phase 18

- Section names "Group finder" and "Player inspection"; option labels "Elite quest button",
  "Slot item level", "Slot enchants"
- No first-run chat notice
- The Settings page's Defaults button resets to the new defaults (as today)

## Phase 19

- Eye: retail's eye on the square button; tooltip "Find a group for this quest"
- Elite campaign quests included
- A long title may run under the eye if room can't be made
- Our own outline on the Quests & Zones category button (our frame, read-only)
- In combat: a chat line, nothing opens
- **Hint: a small box in the game's dialog style at the top of the Listing tab, with a close
  button**: the quest name (to type as the description), Category: Quests & Zones, Zone; it clears
  when the finder closes, the tab changes or a listing is made

## Phase 20

- **Layout: both beside the icon**: item level and enchant on two small lines beside the slot
  icon, toward the model (right of the left column, left of the right column, weapons
  accordingly); nothing drawn on the icon itself
- "No enchant" in red; the enchant text is the item tooltip's enchant line, cut to fit
- The Inspect window uses the same layout

## Phase 21

- Changelog draft for the author's review; the author retakes screenshots
- **The autonomous run stops before the author's review**: after the changelog draft and the
  deferred in-game checks list; the author tests in game, reviews README / CHANGELOG, then runs
  `/gsd-complete-milestone` (no push, merge or tag by the run)
