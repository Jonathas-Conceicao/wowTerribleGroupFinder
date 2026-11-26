# Requirements: v0.3.1 Small fixes

**Defined:** 2026-11-26
**Milestone:** v0.3.1 Small fixes
**Core Value:** Finding the right players or group fast: the listing must be easy to read and
order (role, level, activity, location) and quick to act on, without leaving or replacing
Forever's own group finder.
**Research:** none (small fixes)

## v0.3.1 Requirements

### Elite quest eye (QST)

- [x] **QST-05**: Clicking or hovering the elite quest eye never raises a Lua error: every step
  of the click (the secure cover's placement and removal, its PreClick and PostClick, the two
  click delegates' PreClick, the hint and the description focus) is guarded (nil checks on the
  frames and APIs it reads, `pcall` where a call can fail); a failure prints one chat line,
  remembers it for `/tgf quest`, and leaves the eye usable on the next click. The secure-click route
  and its taint rules stay as they are (Post still works after using the eye)

### Invite outcome (INV)

- [x] **INV-01**: A row marked "invited" after a group invite (Group Invite button or
  Auto-invite) changes to "accepted" when the player joins the group, "declined" when they
  decline, and "expired" when the invite times out, read from the game's own messages for
  that player (matched by plain character name); whisper-only rows keep "sent"

- [x] **INV-02**: The outcome follows the listing through refreshes and re-sorts like the
  "invited" mark does; the colours fit the row (accepted green, declined red, expired grey;
  stock grey on greyed rows); the preview can show the three outcomes

### Search (SRCH)

- [x] **SRCH-01**: After a `/reload` or login, the first search after picking a category and
  activity in Forever's Browse tab lists that activity, not the category's general view, with
  no second refresh needed; Dynamic refresh still never calls `C_LFGList.Search` itself, and
  later searches and refreshes work as before. Shipped wider (author's report during the Release
  Review): the shown list also follows the activity picks at once, without Refresh

### Release (REL)

- [x] **REL-09**: Release Review for v0.3.1: code cleanup, CLAUDE.md entries, README print
  reminders, version `0.3.1`, changelog draft for the author's review, tag `v0.3.1`

## Future Requirements

- Quest log LFG button (backlog 999.5)
- Better quest-to-zone matching with `C_LFGList.GetActivityIDForQuestID`
- Deferred cleanup / audit tech debt (v0.1 cleanup list, v0.2 and v0.2.1 audits)

## Out of Scope

- Changing the eye's secure-click route or what it picks: this milestone only guards it
- Invite outcomes for invites sent outside the addon's buttons (from chat, the unit menu)
- Other invite refusals (already in a group, ignoring you, not found) as their own states:
  they show "declined" (author's choice, 2026-11-26)

## Traceability

| Requirement | Phase | Status |
|-------------|-------|--------|
| QST-05 | Phase 22 | Complete |
| INV-01 | Phase 22 | Complete |
| INV-02 | Phase 22 | Complete |
| SRCH-01 | Phase 22 | Complete |
| REL-09 | Phase 23 | Complete |

**Coverage:** 5/5 requirements mapped

---
*Requirements defined: 2026-11-26*
