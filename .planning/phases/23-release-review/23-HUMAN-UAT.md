---
status: partial
phase: 23-release-review
source: [23-CONTEXT.md, 23-01-SUMMARY.md, 23-02-SUMMARY.md, 22-HUMAN-UAT.md, 22-REVIEW.md]
started: 2026-11-26
updated: 2026-11-26
---

## Current Test

[awaiting the author's review and in-game pass: the autonomous run stopped here]

## Tests

### 1. CHANGELOG review
expected: the `## v0.3.1` section at the top of CHANGELOG.md (the first `## ` heading, the one the release workflow publishes) is a draft: a one-line summary, Added (the invite outcome on rows), Changed (picking an activity narrows the list at once, without Refresh; reworded 2026-11-26 after the author's report that ticking one dungeon after picking Dungeons didn't narrow until Refresh) and Fixed (the elite quest button's Lua errors, which existed in v0.3.0). Review and rewrite as wished. `## v0.3.0` and everything below it are unchanged.
result: passed (author, 2026-11-26: the quest button item says "guarded" rather than "fixed", since it only failed in edge cases; it moved from Fixed to Changed and the summary reads "guards on the elite quest button"; the rest approved as drafted)

### 2. README wording proposals
README.md is not edited until approved; only approved lines get applied.

**a. Auto-send and Auto-invite bullet (lines 32-34)**

Before:
```
- **Auto-send and Auto-invite** - send the message at once instead of opening the
  whisper box, and invite the solo player right after; the contact buttons then rest for
  a second, so no one gets messaged twice
```
After:
```
- **Auto-send and Auto-invite** - send the message at once instead of opening the
  whisper box, and invite the solo player right after; the contact buttons then rest for
  a second, so no one gets messaged twice. After an invite from the addon's buttons, the
  row says whether the player accepted, declined, or the invite expired
```

**b. Alternative, Results table bullet (lines 17-20)** (pick a or b)

Before:
```
- **Results table** - the Browse tab lists solo players and groups in the game's two
  collapsible sections (groups first while you're on your own, solo players first while
  you lead), with class-coloured names, level, roles (a group's open slots), activity,
  zone and how long they've been listed
```
After:
```
- **Results table** - the Browse tab lists solo players and groups in the game's two
  collapsible sections (groups first while you're on your own, solo players first while
  you lead), with class-coloured names, level, roles (a group's open slots), activity,
  zone, how long they've been listed and how your invite ended
```

**Reminder only (decide again): Usage commands (lines 77-82)**, still without `/tgf quest`, `/tgf gear` and `/tgf meter` (proposed in v0.3.0, not applied)

Before:
```
- `/tgf ilvl` prints the item level figures the game gives for you and your group;
  `/tgf region` prints the region the addon reads for listings
```
After:
```
- `/tgf ilvl` prints the item level figures the game gives for you and your group;
  `/tgf region` prints the region the addon reads for listings
- `/tgf gear` prints each slot's item level and enchant reading; `/tgf quest` prints
  what the Elite quest eye reads for your tracked quests; `/tgf meter` shows the damage
  meter prompt now
```
result: skipped (author, 2026-11-26: no README changes for now)

### 3. Screenshot reminder
expected: the author retakes prints; agents make no images. Optional: a row showing accepted / declined / expired. `tgf_refresh.gif` shows the list refreshing but no invite, so it stays valid; `tgf_lfg_message_config.png` is unchanged by v0.3.1.
result: skipped (author, 2026-11-26: no new prints for now)

### 4. Version
expected: v0.3.1. The TOC keeps `## Version: @project-version@`; tag `v0.3.1` on `main` after the squash merge, by the author's `/gsd-complete-milestone`. The squash-merge message lists only what players get (the invite outcome, the two fixes), none of the in-milestone fixes the branch commits name. The local zip (23-01) holds 28 files: the TOC, the Lua and XML files, the seven textures (icon and six flags) and LICENSE; nothing from Media/Source, Media/Screenshots or .planning.
result: [pending]

### 5. Deferred in-game checks (all 13 of 22-HUMAN-UAT.md)
Deploy first: `./scripts/install.bat`, then `/reload` in game. Use `/console taintLog 1` for the taint check (22-6). The release waits on these. Results can be filled in 22-HUMAN-UAT.md or here.

- (22-1) Eye with the finder closed, then open: hover and click the Elite quest eye with the finder closed, then again with it open; no Lua error; the finder opens on the Listing tab with Quests & Zones and the quest's zone picked
- (22-2) Eye with an active listing: clicking the eye prints one chat line and raises no error
- (22-3) Eye for a quest whose zone row is off screen: no error; the zone is not ticked; the hint says so
- (22-4) Eye in combat: a chat line and no error; after combat the next hover covers the eye again
- (22-5) `/tgf quest` after the above: shows the last error and the failed steps, or none when nothing failed
- (22-6) Post after using the eye (taint): with `/console taintLog 1`, use the eye, type a description and press Post; the listing is created; `Logs/taint.log` has no TerribleGroupFinder entry
- (22-7) Invite accepted: Group Invite a solo player who accepts; the Listed cell reads "invited", then "accepted" (green)
- (22-8) Invite declined: invite a player who declines: "declined" (red); an offline player and one already in a group also read "declined"
- (22-9) Invite expired: invite a player who ignores the popup; the cell reads "expired" (grey) after about 60 s
- (22-10) Outcome persists: the outcome stays on its row through a Dynamic refresh and a re-sort; whisper-only rows still read "sent"
- (22-11) Preview invites: `/tgf preview`, Group Invite on three solo rows: accepted, declined, expired in turn
- (22-12) Picks narrow the list at once (reworked 2026-11-26 after the author's report: picking Dungeons searches every dungeon, and ticking one dungeon starts no search in Forever's finder, so the list stayed whole until Refresh): after `/reload`, pick Dungeons, then tick one dungeon (right away, and again after waiting for the list); the list shows only that dungeon's listings at once, without Refresh; tick a second dungeon: both show; untick all: every dungeon shows again; then press Refresh: a normal Dynamic refresh of the picked dungeons (no spinner, rows swipe); an activity group checkbox still searches as stock. **Passed (author, 2026-11-26: "works great now")**
- (22-13) No regression in other searches: later searches of other categories and activities, and Dynamic refresh off, behave as before

result: [pending]

### 6. Author decisions
Each with the default the code ships now:
- (a) IN-02 (22-REVIEW): an answer is also narrowed when the picks changed to a subset of the searched activities while the search was out. Default: narrowed; the alternative is showing the full answer
- (b) The 55 s rule: the player's own decline arriving 55 s or more after the invite reads "expired" (the invitee's 60 s popup timeout), while other refusals (offline, already in a group, ignoring you, not found) stay "declined" at any time, and no answer at all reads "expired" after 2 minutes. Default: as shipped
result: [pending]

### 7. Phase confirmation
expected: the author's confirmation closes Phase 23; then `/gsd-complete-milestone` (push, squash-merge into `main`, tag `v0.3.1`). Nothing of this was done by the autonomous run.
result: [pending]

## Summary

total: 7
passed: 0
issues: 0
pending: 7
skipped: 0
blocked: 0

## Gaps
