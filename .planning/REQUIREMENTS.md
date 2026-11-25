# Requirements: v0.3.0 Elite Quests finder and more inspect data

**Defined:** 2026-11-24
**Milestone:** v0.3.0 Elite Quests finder and more inspect data
**Core Value:** Finding the right players or group fast: the listing must be easy to read and
order (role, level, activity, location) and quick to act on, without leaving or replacing
Forever's own group finder.
**Research:** [research/v0.3.0/SUMMARY.md](research/v0.3.0/SUMMARY.md)

## v0.3.0 Requirements

### Opt-in defaults and Settings (OPT)

- [x] **OPT-01**: On a new install only Elite quest button, Dynamic refresh, Swipe animations
  and Region flags are on by default; every other option (item level spots, talent points, slot
  item level, slot enchants, both damage meter prompts) is off, so the addon doesn't clash with
  similar addons

- [x] **OPT-02**: A player with saved data from before v0.3.0 keeps the options they had: the
  six options on by default in v0.2.2 (`ilvlPlayerTooltip`, `specPoints`, `ilvlItemTooltip`,
  `ilvlCharacterSheet`, `ilvlInspect`, `meterResetOnInstance`) stay on unless they turned them
  off (an `ns.Migrate` schema-4 step from a frozen list, never from the registry); the new
  options take the new defaults

- [x] **OPT-03**: The Settings page shows its sections in this order: Group finder (Elite quest
  button, Dynamic refresh > Swipe animations, Region flags), Player inspection (item level spots,
  talent points, slot item level, slot enchants), Damage meter, Messages

- [x] **OPT-04**: Elite quest button, Slot item level and Slot enchants can be turned on or off
  from the Settings page and with `/tgf set <key> on|off`; the change shows at once

### Elite quest eye (QST)

- [x] **QST-01**: A tracked elite quest in the objective tracker shows an eye button in retail's
  tracker style (the `socialqueuing-icon-eye` on a square button, a plain fallback where the art
  is missing) with a tooltip; other quests show none; elite is `C_QuestLog.IsEliteQuest` (tag ID
  fallback), never the localized title text

- [x] **QST-02**: Clicking the eye out of combat opens Forever's group finder on its Listing tab
  (`LFGVanilla_ShowFrame`, as the Messages button does); in combat it says so and does nothing

- [x] **QST-03**: The Listing tab then shows a hint of our own frame: the quest name (to type
  as the description), the Quests & Zones category and the quest's zone; the player picks,
  types and posts; the hint clears when the finder closes, the tab changes or a listing is made;
  nothing of Blizzard's finder is selected, filled or written

- [x] **QST-04**: The eye never doubles a game eye on the same quest, and after using it the
  player's own Post and Search still work (no taint)

### Per-slot gear info (GEAR)

- [x] **GEAR-01**: With Slot item level on, each equipped slot on the character sheet and on the
  Inspect window shows that item's level

- [x] **GEAR-02**: With Slot enchants on, each slot shows its enchant's name, and a slot Forever
  lets you enchant shows "No enchant" when it has none, at every level; the enchantable slots
  are Forever's (vanilla's plus the slots Forever added, neck and any other, checked against
  Forever)

- [x] **GEAR-03**: On the Inspect window a slot shows nothing until that player's data is
  known, and "No enchant" never shows while it is unknown; values only for the player the
  window shows

- [x] **GEAR-04**: The slot info is our own frames on the slot buttons (hooks only); the
  character sheet and the Inspect window keep working untainted, and turning an option off
  clears it from open windows

### Release (REL)

- [x] **REL-08**: Release Review for v0.3.0: code cleanup, CLAUDE.md entries, README print
  reminders, version, changelog draft (the opt-in defaults explained: existing players keep
  their settings) for the author's review, then the tag `v0.3.0`

## Future Requirements

- Route A for the eye: let the game pre-select the quest's search (`SetSearchToQuestID`) if a
  probe shows it is safe and not sticky
- A quest log eye button (backlog 999.5's quest log placement)

## Out of Scope

| Item | Reason |
|------|--------|
| Sockets / gems on slots | No Forever item has sockets (the game's own socket display only shows for Timerunning); dropped by the author |
| Writing the listing description or selecting the category / activity for the player | The description box is secure (`SetSecurityDisableSetText`); setting Blizzard's selections from addon code taints the restricted Post and Search |
| Retail's quest finder (`LFGListUtil_FindQuestGroup`) or a shim for it | `Blizzard_GroupFinder` doesn't load on Forever; a global of ours would be a write the addon avoids |
| Dungeon / raid quests, world quests | Elite (group) quests only this milestone |
| A secure-click route into Blizzard's category buttons | `Click()` from addon code runs tainted; deferred |

## Traceability

| Requirement | Phase | Status |
|-------------|-------|--------|
| OPT-01 | Phase 18 | Complete |
| OPT-02 | Phase 18 | Complete |
| OPT-03 | Phase 18 | Complete |
| OPT-04 | Phase 18 | Complete |
| QST-01 | Phase 19 | Complete |
| QST-02 | Phase 19 | Complete |
| QST-03 | Phase 19 | Complete |
| QST-04 | Phase 19 | Complete |
| GEAR-01 | Phase 20 | Complete |
| GEAR-02 | Phase 20 | Complete |
| GEAR-03 | Phase 20 | Complete |
| GEAR-04 | Phase 20 | Complete |
| REL-08 | Phase 21 | Complete |
