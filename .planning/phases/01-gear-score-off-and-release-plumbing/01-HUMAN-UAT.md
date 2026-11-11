---
status: partial
phase: 01-gear-score-off-and-release-plumbing
source: [01-VERIFICATION.md]
started: 2026-11-11T17:00:00Z
updated: 2026-11-11T17:00:00Z
---

## Current Test

[awaiting human testing — deferred to the author's in-game test (author AFK during the autonomous run)]

## Tests

### 1. Browse tab on real Forever results
expected: No GS column, no "Your GS" in the top band, no GS line in row tooltips; the columns right of the old GS column sit 50 px further left with no overlap and Activity takes the freed width.
result: [pending]

### 2. Messages tab
expected: The key list shows no `{gs}`; the default request preset reads "Hi {name}! Level {level} {class} here ({role}), could I join you for {activity}?" (a previously saved old GS default is reset to it).
result: [pending]

### 3. Ready check in a party
expected: No inspects start (no InspectFrame flicker, no inspect traffic); nothing from TerribleGroupFinder reacts to READY_CHECK.
result: [pending]

### 4. Addon icon
expected: After `./scripts/install.bat` and `/reload`, the AddOns list shows the TerribleGroupFinder icon from `Media\Textures\tgf_icon_64x64.tga` (64x64, 32-bit TGA, top-left origin). If it shows blank or upside down, switch png2tga to a bottom-up (descriptor 0x08) TGA or convert to BLP.
result: [pending]

## Summary

total: 4
passed: 0
issues: 0
pending: 4
skipped: 0
blocked: 0

## Gaps
