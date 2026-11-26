# Roadmap: TerribleGroupFinder

## Milestones

- ✅ **v0.1 Initial Release** — Phases 1-5 (shipped 2026-11-12, tag `v0.1.0`) — [archive](milestones/v0.1-ROADMAP.md)
- ✅ **v0.2 ILvL Info and Improved Refresh** — Phases 6-11 (shipped 2026-11-15, tag `v0.2.0`) — [archive](milestones/v0.2-ROADMAP.md)
- ✅ **v0.2.1 Reset Details reminder, more region flags and spec points** — Phases 12-15 (shipped 2026-11-16, tag `v0.2.1`) — [archive](milestones/v0.2.1-ROADMAP.md)
- ✅ **v0.2.2 Small Improvements** — Phases 16-17 (shipped 2026-11-20, tag `v0.2.2`) — [archive](milestones/v0.2.2-ROADMAP.md)
- ✅ **v0.3.0 Elite Quests finder and more inspect data** — Phases 18-21 (shipped 2026-11-25, tag `v0.3.0`) — [archive](milestones/v0.3.0-ROADMAP.md)
- 🚧 **v0.3.1 Small fixes** — Phases 22-23 (in progress)

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

<details>
<summary>✅ v0.3.0 Elite Quests finder and more inspect data (Phases 18-21) — SHIPPED 2026-11-25</summary>

- [x] Phase 18: Opt-in Defaults and Settings Sections (1/1 plan) — completed 2026-11-24
- [x] Phase 19: Elite Quest Eye (2/2 plans) — completed 2026-11-24
- [x] Phase 20: Per-slot Gear Info (2/2 plans) — completed 2026-11-24
- [x] Phase 21: Release Review (2/2 plans) — completed 2026-11-25

</details>

### 🚧 v0.3.1 Small fixes (In Progress)

- [x] **Phase 22: Small Fixes** - the elite quest eye's click guarded against Lua errors, invite outcomes on rows, the first search after a reload lists the picked activity (completed 2026-11-26)
- [x] **Phase 23: Release Review** - cleanup, docs, changelog draft, author review, tag `v0.3.1` (completed 2026-11-26)

## Phase Details

### Phase 22: Small Fixes

**Goal**: The eye's click never errors, an invite's row says how it ended, and the first search after a reload shows what the player picked
**Depends on**: Nothing (first phase)
**Requirements**: QST-05, INV-01, INV-02, SRCH-01
**Approach**: fix in place, no probe-first step; guards around each step of the eye's click in `QuestButton.lua` (`Q.Cover` / `Q.Recheck` / `Q.Uncover`, the cover's PreClick / PostClick, the delegates' PreClick, the hint), errors kept for `/tgf quest`; invite outcomes from the game's system messages for the invited name (`CHAT_MSG_SYSTEM` with the game's own format strings, joining seen on `GROUP_ROSTER_UPDATE`), shown where `ns.state.invited` is read in `UI/Table.lua`; the search fix in `UI/InPlace.lua` / the Browse dropdown flow, found by reading Blizzard's `Blizzard_GroupFinder_VanillaStyle` search path (the v0.2 audit's `searchOut` reset edge case is a lead); in-game checks at the end of the phase
**Success Criteria** (what must be TRUE):

1. Clicking and hovering the eye (out of combat, in combat, with the finder open or closed, with an active listing, with the quest's zone off screen) raises no Lua error; a failed step prints one chat line and `/tgf quest` shows it; Post still works after using the eye (taint log clean)
2. After a Group Invite or Auto-invite, the row's "invited" turns "accepted" when the player joins, "declined" when they decline, "expired" when the invite runs out; whisper-only rows still say "sent"; the outcome stays on its listing through refreshes and sorting
3. After a `/reload` or login, picking a category and an activity and searching lists that activity on the first search; later searches and Dynamic refresh work as before, and the addon never calls `C_LFGList.Search` itself
4. The preview shows the invite outcomes; nothing errors where the finder or tracker is missing

**Plans**: 4 plans

Plans:

- [x] 22-01-PLAN.md — guard every step of the elite quest eye's hover and click (Try / Guarded, clear-first secure attributes, idempotent cover build, failed steps in `/tgf quest`)
- [x] 22-02-PLAN.md — invite outcomes: `M.MarkInvited`, system-message / roster / timer / preview resolution, Listed cell accepted / declined / expired
- [x] 22-03-PLAN.md — first search after a reload: narrow a wider answer to the picked activities (`Listings.Read(previous, only)`, `NarrowSet` in InPlace)
- [x] 22-04-PLAN.md — CLAUDE.md entries for the three fixes, 22-HUMAN-UAT.md in-game checks, `stylua .`

### Phase 23: Release Review

**Goal**: v0.3.1 is cleaned up, documented and tagged after the author's review
**Depends on**: Phase 22
**Requirements**: REL-09
**Success Criteria** (what must be TRUE):

1. Code cleanup done (unused code removed, `stylua .` clean); CLAUDE.md entries describe the changes
2. Version `0.3.1` in the TOC; the changelog's v0.3.1 section drafted for players and reviewed by the author, with the README reviewed (print reminders flagged)
3. The milestone branch squash-merged into `main` and tagged `v0.3.1`

**Plans**: 2 plans

Plans:

- [x] 23-01-PLAN.md — code cleanup of the v0.3.1 files (no behaviour change, `stylua .`), CLAUDE.md for v0.3.1, TOC / package check
- [x] 23-02-PLAN.md — `## v0.3.1` changelog draft, 23-HUMAN-UAT.md (README proposals, print reminder, Phase 22 in-game checks, author decisions); the run stops before the author's review

## Progress

| Phase | Milestone | Plans Complete | Status | Completed |
|-------|-----------|----------------|--------|-----------|
| 1-5 (with 04.1) | v0.1 | 19/19 | Complete | 2026-11-12 |
| 6-11 | v0.2 | 15/15 | Complete | 2026-11-15 |
| 12-15 | v0.2.1 | 7/7 | Complete | 2026-11-16 |
| 16-17 | v0.2.2 | 4/4 | Complete | 2026-11-20 |
| 18-21 | v0.3.0 | 7/7 | Complete | 2026-11-25 |
| 22. Small Fixes | v0.3.1 | 4/4 | Complete    | 2026-11-26 |
| 23. Release Review | v0.3.1 | 2/2 | Complete   | 2026-11-26 |

## Backlog

The v0.1-era backlog items went into v0.2: 999.1 (gear score) closed by Phase 6, 999.2 (item tooltips) into Phase 7, 999.4 (quiet refresh and swipes) into Phase 9, 999.3 (settings window) into Phase 10; their notes are folded into those phase details. 999.6 (region flags for every region) went into v0.2.1 Phase 13.

### Phase 999.5: Quest log LFG button for elite quests (BACKLOG — tracker eye in v0.3.0 Phase 19; the quest log placement stays here)

**Goal**: An LFG button in the quest log for elite (group) quests that opens the group finder for that quest, to search for groups doing it or list yourself / your group for it
**Source**: author request, 2026-11-14 (during v0.2 Phase 8)
**Notes**:

- Answered in v0.3.0 (Phase 19 and its review): Forever's Quests & Zones category (116) has one activity per zone, matched by the quest's zone name (`Q.ActivityFor`); `C_LFGList.GetActivityIDForQuestID` (undocumented, present in game) may match better. The tracker eye picks the category and zone through a secure cover and `/click` delegates (`QuestButton.lua`), which a quest log button can reuse
- The description can't be written by addons: `LFGListingComment.EditBox` refuses `SetText` / `Insert` / paste ("Call is illegal when disabled by security settings"), `LfgListingCreateData` has no text field; `CreateListing` from addon code on a key press works (no description unless typed), a `questID` is refused for quests without `CanCreateQuestGroup`
- Elite detection: `C_QuestLog.IsEliteQuest` (tag ID fallback), as the eye does
- Placement: a small button on the quest log's quest details (native look), taint-safe (hooks only)

**Requirements**: TBD
**Plans**: 0 plans

Plans:

- [ ] TBD (promote with /gsd-review-backlog when ready)
