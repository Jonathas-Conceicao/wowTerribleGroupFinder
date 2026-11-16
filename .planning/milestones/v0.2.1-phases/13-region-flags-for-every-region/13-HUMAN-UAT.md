---
status: partial
phase: 13-region-flags-for-every-region
source: [13-VERIFICATION.md, 13-01-SUMMARY.md, 13-02-SUMMARY.md, 13-REVIEW.md]
started: 2026-11-16T12:00:00Z
updated: 2026-11-16T12:00:00Z
---

## Current Test

[awaiting human testing — deferred to the end of the autonomous run]

## Tests

### 1. Flags look right (install, then fully restart the client: a /reload may keep the old cached US/AU textures)
expected: In `/tgf preview`, US rows 19x10, AU 20x10, EU / KR / CN / TW 15x10 (Arugal EU, Tess KR, Remulos CN, Saidan TW); sharp, upright, cantons top-left, one height, aligned with the other icons; no faded right or bottom edge (if one shows, a half-texel coord inset in Region.lua is the fix — no art change)
result: [pending]

### 2. Two-letter text tags
expected: Gryan Stoutmantle shows grey "EU" and Archbishop Benedictus grey "BR" after the name; hovering the text shows "Region: EU Paris" / "Region: BR1"; the row tooltip the same; group rows read "Leader's region: ..."; after scrolling / sorting a tag is never cut to "…" (review WR-01 fix)
result: [pending]

### 3. Unknown shard, greyed rows, narrow rows
expected: Delas Moonfang shows neither flag nor text; greyed (delisted / hidden) rows: flag desaturated and dimmed, tag in the darker delisted grey, no Lua error; with little name room the tag closes its gap and drops last, like the flag
result: [pending]

### 4. Setting and live data
expected: Settings > Region flags off: no flags, tags or region tooltip lines; on: they return; its tooltip reads the new wording (no "US or Oceania"); live (not preview) US and AU listings still show their flags; `/tgf region` prints the probe
result: [pending]

### 5. README / changelog wording and screenshots
expected: README.md and CHANGELOG.md still say "US or Oceania" (Release Review, author-directed); the author decides whether README prints need retaking since the flags changed look
result: [pending]

## Summary

total: 5
passed: 0
issues: 0
pending: 5
skipped: 0
blocked: 0

## Gaps
