---
status: complete
phase: 08-region-flags-and-row-icon-tooltips
source: [08-VERIFICATION.md, 08-REVIEW.md]
started: 2026-11-14T16:00:00Z
updated: 2026-11-15T12:00:00Z
---

## Current Test

[complete: the author passed the checks in game, 2026-11-15 (the flag is now dropped last on crowded rows; raid groups show role counts with icons); the mapping check was superseded]

## Tests

### 1. Flags on rows
expected: US rows (both US server groups) show the US flag after the name, Oceania rows the Australian flag, unknown servers none; art and placement look right; `/tgf region` lists unknown server IDs
result: pass

### 2. US East / US West mapping
expected: The row tooltip reads "Region: US East" / "US West" / "Oceania" ("Leader's region: …" for groups). Confirm with a player who knows their datacenter that US1 = West and US2 = East (swap two lines in `Region.lua` if reversed)
result: skipped
reason: superseded 2026-11-15 by the author's choice not to assume the mapping: the tooltip names the group as the game does ("Region: US1" / "US2" / "AU1"), generic for other regions (commit c1dca07)

### 3. Own listing
expected: Your row shows your flag when solo or leading, and the leader's flag when you're a member of someone else's group
result: pass

### 4. Learned servers persist
expected: A Battle.net friend online on a server not in the seeded list makes it known (flag appears on matching rows without a new search); after `/reload` it is still known; a seeded server is never changed
result: pass

### 5. Icon tooltips
expected: Hovering each icon (flag, role icons, open slots, new player friendly murloc, Discord, leader crown, class icon, Battle.net friend / friend / recent ally marks, friends in group) shows its own tooltip; hover highlight, click-select and right-click menu still work over every icon, including one at the very edge of a row; scrolling with a tooltip open never leaves a stale one; long names drop icons in the documented order (Discord last)
result: pass

### 6. Region flags off (live)
expected: `/run TerribleGroupFinderDB.regionFlags=false` then reopening Browse hides flags and region lines (toggle page arrives in Phase 10)
result: pass

## Summary

total: 6
passed: 5
issues: 0
pending: 0
skipped: 1
blocked: 0

## Gaps
