# Roadmap: TerribleGroupFinder

## Milestones

- ✅ **v0.1 Initial Release** — Phases 1-5 (shipped 2026-11-12, tag `v0.1.0`) — [archive](milestones/v0.1-ROADMAP.md)
- ✅ **v0.2 ILvL Info and Improved Refresh** — Phases 6-11 (shipped 2026-11-15, tag `v0.2.0`) — [archive](milestones/v0.2-ROADMAP.md)
- ✅ **v0.2.1 Reset Details reminder, more region flags and spec points** — Phases 12-15 (shipped 2026-11-16, tag `v0.2.1`) — [archive](milestones/v0.2.1-ROADMAP.md)
- ✅ **v0.2.2 Small Improvements** — Phases 16-17 (shipped 2026-11-20, tag `v0.2.2`) — [archive](milestones/v0.2.2-ROADMAP.md)

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

## Progress

| Phase | Milestone | Plans Complete | Status | Completed |
|-------|-----------|----------------|--------|-----------|
| 1-5 (with 04.1) | v0.1 | 19/19 | Complete | 2026-11-12 |
| 6-11 | v0.2 | 15/15 | Complete | 2026-11-15 |
| 12-15 | v0.2.1 | 7/7 | Complete | 2026-11-16 |
| 16-17 | v0.2.2 | 4/4 | Complete | 2026-11-20 |

## Backlog

The v0.1-era backlog items went into v0.2: 999.1 (gear score) closed by Phase 6, 999.2 (item tooltips) into Phase 7, 999.4 (quiet refresh and swipes) into Phase 9, 999.3 (settings window) into Phase 10; their notes are folded into those phase details. 999.6 (region flags for every region) went into v0.2.1 Phase 13.

### Phase 999.5: Quest log LFG button for elite quests (BACKLOG)

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
