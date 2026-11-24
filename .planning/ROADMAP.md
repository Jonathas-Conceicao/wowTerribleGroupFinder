# Roadmap: TerribleGroupFinder

## Milestones

- ✅ **v0.1 Initial Release** — Phases 1-5 (shipped 2026-11-12, tag `v0.1.0`) — [archive](milestones/v0.1-ROADMAP.md)
- ✅ **v0.2 ILvL Info and Improved Refresh** — Phases 6-11 (shipped 2026-11-15, tag `v0.2.0`) — [archive](milestones/v0.2-ROADMAP.md)
- ✅ **v0.2.1 Reset Details reminder, more region flags and spec points** — Phases 12-15 (shipped 2026-11-16, tag `v0.2.1`) — [archive](milestones/v0.2.1-ROADMAP.md)
- ✅ **v0.2.2 Small Improvements** — Phases 16-17 (shipped 2026-11-20, tag `v0.2.2`) — [archive](milestones/v0.2.2-ROADMAP.md)
- 🚧 **v0.3.0 Elite Quests finder and more inspect data** — Phases 18-21 (in progress)

## Phases

<details>
<summary>✅ v0.1 Initial Release (Phases 1-5) — SHIPPED 2026-11-12</summary>

- [x] Phase 1: Gear Score Off and Release Plumbing (3/3 plans) — completed 2026-11-11
- [x] Phase 2: List Foundation (4/4 plans) — completed 2026-11-11
- [x] Phase 3: Rows, Tooltip and Own Listing (4/4 plans) — completed 2026-11-11
- [x] Phase 4: Messages and Contact (4/4 plans) — completed 2026-11-11
- [x] Phase 04.1: Player location (INSERTED) (2/2 plans) — completed 2026-11-11
- [x] Phase 5: Release Review (2/2 plans) — completed 2026-11-12

</details>

<details>
<summary>✅ v0.2 ILvL Info and Improved Refresh (Phases 6-11) — SHIPPED 2026-11-15</summary>

- [x] Phase 6: Gear Score Removal and Settings Foundation (2/2 plans) — completed 2026-11-14
- [x] Phase 7: Item Level Spots (3/3 plans) — completed 2026-11-14
- [x] Phase 8: Region Flags and Row Icon Tooltips (3/3 plans) — completed 2026-11-14
- [x] Phase 9: Dynamic Refresh (3/3 plans) — completed 2026-11-14
- [x] Phase 10: Settings Window (2/2 plans) — completed 2026-11-14
- [x] Phase 11: Release Review (2/2 plans) — completed 2026-11-15

</details>

<details>
<summary>✅ v0.2.1 Reset Details reminder, more region flags and spec points (Phases 12-15) — SHIPPED 2026-11-16</summary>

- [x] Phase 12: Damage Meter Reset Prompt (1/1 plan) — completed 2026-11-16
- [x] Phase 13: Region Flags for Every Region (2/2 plans) — completed 2026-11-16
- [x] Phase 14: Spec Points (2/2 plans) — completed 2026-11-16
- [x] Phase 15: Release Review (2/2 plans) — completed 2026-11-16

</details>

<details>
<summary>✅ v0.2.2 Small Improvements (Phases 16-17) — SHIPPED 2026-11-20</summary>

- [x] Phase 16: Small Improvements (2/2 plans) — completed 2026-11-19
- [x] Phase 17: Release Review (2/2 plans) — completed 2026-11-20

</details>

### 🚧 v0.3.0 Elite Quests finder and more inspect data (In Progress)

- [x] **Phase 18: Opt-in Defaults and Settings Sections** - only the finder's options on by default for new installs, existing players keep theirs, the page in its new order with the new keys (completed 2026-11-24)
- [x] **Phase 19: Elite Quest Eye** - an eye on tracked elite quests that opens the finder's Listing tab with a hint for that quest (completed 2026-11-24)
- [x] **Phase 20: Per-slot Gear Info** - item level and enchant (or "No enchant") on each slot of the character sheet and the Inspect window (completed 2026-11-24)
- [ ] **Phase 21: Release Review** - cleanup, docs, changelog draft, author review, tag `v0.3.0`

## Phase Details

### Phase 18: Opt-in Defaults and Settings Sections

**Goal**: The addon only changes the group finder until the player opts in to the extras; nothing changes for existing players; the Settings page is ordered by what matters most
**Depends on**: Nothing (first phase; every later feature is gated by its keys)
**Requirements**: OPT-01, OPT-02, OPT-03, OPT-04
**Success Criteria** (what must be TRUE):

1. A fresh install (no saved table) has Elite quest button, Dynamic refresh, Swipe animations and
   Region flags on and every other option off
2. A v0.2.2 saved table (any key, including only `schema = 3`) keeps the six v0.2.2-on options
   on unless saved off; a value the player saved is never changed; the new keys stay at their
   new defaults; a v0.2.1 table runs schema 3 then 4 correctly
3. The Settings page lists Group finder, Player inspection, Damage meter, Messages in that order,
   with `eliteQuestButton`, `slotItemLevel` and `slotEnchants` registered (inert until their
   phases) and settable from the page and `/tgf set`
4. CLAUDE.md's Core / Settings lines describe schema 4 and the new defaults

**Plans**: 1 plan

Plans:
- [x] 18-01-PLAN.md — explicit opt-in defaults and the new section order in the registry, Migrate schema 4 from the frozen v0.2.2 list, CLAUDE.md

### Phase 19: Elite Quest Eye

**Goal**: From a tracked elite quest, one click takes the player to Forever's Listing tab with what they need to post a group for it
**Depends on**: Phase 18 (`eliteQuestButton` key)
**Requirements**: QST-01, QST-02, QST-03, QST-04
**Approach**: built straight from the Blizzard source pattern with fallbacks (plain texture where
the eye atlas is missing, skip quests with a game eye, accept header overlap if the anchor move
fails); a `/tgf quest` debug command ships alongside (no probe-first step), live checks at the end; hook `EndLayout` on the Quest and Campaign tracker
instances, own button per pooled block (no `AddRightEdgeFrame`); `IP.ShowFinder(tab)` extracted
from `IP.OpenMessages`
**Success Criteria** (what must be TRUE):

1. Elite quests in the tracker show the eye in retail's style with a tooltip; non-elite quests
   and quests with a game eye show none; the eye follows its setting at once
2. Clicking it out of combat opens the finder on Listing with our hint (quest name, Quests &
   Zones, zone); in combat it says so; the hint clears on close / tab change / listing made
3. After using the eye, posting and searching by hand work with no taint (taint log clean)
4. The preview / stand-in path doesn't error where the tracker or finder is missing

**Plans**: TBD
**UI hint**: yes

### Phase 20: Per-slot Gear Info

**Goal**: The character sheet and the Inspect window show each slot's item level and enchant at a glance
**Depends on**: Phase 18 (`slotItemLevel`, `slotEnchants` keys); independent of Phase 19
**Requirements**: GEAR-01, GEAR-02, GEAR-03, GEAR-04
**Approach**: built straight away from the item link enchant field and the tooltip enchant line,
with Forever's enchantable slots (vanilla's plus neck and the other new slot, researched while
planning); a `/tgf gear` debug command ships alongside (no probe-first step), live checks at the end; hooks on
`PaperDollItemSlotButton_Update` / `InspectPaperDollItemSlotButton_Update` (Inspect is
load-on-demand); no inspects of our own, the quiet queue untouched
**Success Criteria** (what must be TRUE):

1. With Slot item level on, every equipped slot on both windows shows its item level
2. With Slot enchants on, enchanted slots show the enchant name and Forever-enchantable slots
   without one show "No enchant", at every level
3. On Inspect, nothing (and never "No enchant") shows for a slot until that player's data is
   known; switching inspected players never shows the previous player's values
4. Turning an option off clears open windows at once; the sheet and Inspect window stay
   untainted

**Plans**: TBD
**UI hint**: yes

### Phase 21: Release Review

**Goal**: v0.3.0 is clean, documented and approved by the author, ready to tag
**Depends on**: Phases 18-20
**Requirements**: REL-08
**Success Criteria** (what must be TRUE):

1. Code cleanup done (no in-milestone bug mentions, `stylua .`), CLAUDE.md lists
   `QuestButton.lua` and `GearSlots.lua` and the new rules
2. README print reminders raised (Settings page, tracker eye, slot info)
3. The v0.3.0 changelog section draft explains the opt-in defaults (existing players keep theirs)
4. The live checks from the probes pass, and the author approves README and CHANGELOG

**Plans**: TBD

## Progress

| Phase | Milestone | Plans Complete | Status | Completed |
|-------|-----------|----------------|--------|-----------|
| 1-5 (with 04.1) | v0.1 | 19/19 | Complete | 2026-11-12 |
| 6-11 | v0.2 | 15/15 | Complete | 2026-11-15 |
| 12-15 | v0.2.1 | 7/7 | Complete | 2026-11-16 |
| 16-17 | v0.2.2 | 4/4 | Complete | 2026-11-20 |
| 18. Opt-in Defaults and Settings Sections | v0.3.0 | 1/1 | Complete    | 2026-11-24 |
| 19. Elite Quest Eye | v0.3.0 | 2/2 | Complete    | 2026-11-24 |
| 20. Per-slot Gear Info | v0.3.0 | 2/2 | Complete    | 2026-11-24 |
| 21. Release Review | v0.3.0 | 0/? | Not started | - |

## Backlog

The v0.1-era backlog items went into v0.2: 999.1 (gear score) closed by Phase 6, 999.2 (item tooltips) into Phase 7, 999.4 (quiet refresh and swipes) into Phase 9, 999.3 (settings window) into Phase 10; their notes are folded into those phase details. 999.6 (region flags for every region) went into v0.2.1 Phase 13.

### Phase 999.5: Quest log LFG button for elite quests (BACKLOG — tracker eye in v0.3.0 Phase 19; the quest log placement stays here)

**Goal**: An LFG button in the quest log for elite (group) quests that opens the group finder for that quest, to search for groups doing it or list yourself / your group for it
**Source**: author request, 2026-11-14 (during v0.2 Phase 8)
**Notes**:

- Open questions: does Forever's finder have activities for quests (a quest / questing category, or only dungeons, raids, zones)? If not, the closest fit (the quest's zone activity, with the quest name in the comment) or a search-box prefill
- Search and create are restricted calls (`C_LFGList.Search` / `CreateListing` need a hardware event and stay Blizzard's): the button can open Browse with the category / activity picked (the game then searches on its own) and open the Listing tab prefilled where that is allowed; the listing description box is secure
- Elite detection: quest log entries flagged elite / group (`C_QuestLog` info: `suggestedGroup`, quest tag / `isElite`), checked against Forever's quest log UI (`wow-ui-source` branch `forever`)
- Placement: a small button on the quest log's quest details (native look), taint-safe (hooks only)

**Requirements**: TBD
**Plans**: 0 plans

Plans:

- [ ] TBD (promote with /gsd-review-backlog when ready)
