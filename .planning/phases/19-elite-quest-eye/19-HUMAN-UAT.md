---
status: complete
phase: 19-elite-quest-eye
source: [19-VERIFICATION.md, 19-REVIEW.md]
started: 2026-11-24
updated: 2026-11-24
---

## Current Test

[awaiting the author's in-game pass at the end of the milestone]

## Tests

### 1. The eye in the tracker
expected: tracked elite quests (and elite campaign quests) show the eye at the block's top right, left of a quest item button when there is one; non-elite quests show none; a long title isn't squeezed into a wrap (it may run under the eye); the eye keeps up as quests are tracked / untracked / completed
result: passed (author, 2026-11-25; with round 2's changes, 21-HUMAN-UAT item 5)

### 2. Tooltip
expected: hovering shows "Find a group for this quest" (gold) and the note line
result: passed (author, 2026-11-25; with round 2's changes, 21-HUMAN-UAT item 5)

### 3. Click out of combat
expected: the finder opens on Listing, widened, with the hint box (quest name + Elite, Category: Quests & Zones, Zone, Description) in the added strip and a pulsing outline on Quests & Zones; how the widened Listing tab looks is the author's call (the content stretches with the frame)
result: passed (author, 2026-11-25; with round 2's changes, 21-HUMAN-UAT item 5)

### 4. Post and Search still work
expected: after using the eye, picking the category / activity, typing the description and posting works; searching on Browse works; `/console taintLog 1` shows nothing from TerribleGroupFinder, no ADDON_ACTION_BLOCKED
result: passed (author, 2026-11-25; with round 2's changes, 21-HUMAN-UAT item 5)

### 5. Hint clears
expected: the hint and outline go away (and the width comes back) on finder close, tab change, a listing made, the close button, and combat start (width restored after combat)
result: passed (author, 2026-11-25; with round 2's changes, 21-HUMAN-UAT item 5)

### 6. In combat and with a listing
expected: clicking in combat prints "can't open the group finder in combat." and opens nothing; clicking while you already have a listing opens Listing and prints the hint as a chat line
result: passed (author, 2026-11-25; with round 2's changes, 21-HUMAN-UAT item 5)

### 7. No double eye; setting; probe
expected: a quest the game gives its own eye shows no second eye; `eliteQuestButton` off (Settings or `/tgf set`) hides every eye at once; `/tgf quest` lists the tracked quests (elite, tag, game eye, our eye, zone sources) and the Quests & Zones activities — check which zone source is right
result: passed (author, 2026-11-25; with round 2's changes, 21-HUMAN-UAT item 5)

### 8. README prints
expected: the author decides whether prints of the tracker eye and the Listing hint are wanted
result: passed (author, 2026-11-25; with round 2's changes, 21-HUMAN-UAT item 5)

## Summary

total: 8
passed: 8
issues: 0
pending: 0
skipped: 0
blocked: 0

## Gaps
