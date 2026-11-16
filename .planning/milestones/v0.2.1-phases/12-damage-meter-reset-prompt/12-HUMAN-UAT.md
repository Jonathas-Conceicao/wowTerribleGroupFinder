---
status: partial
phase: 12-damage-meter-reset-prompt
source: [12-VERIFICATION.md]
started: 2026-11-16T12:00:00Z
updated: 2026-11-16T12:00:00Z
---

## Current Test

[awaiting human testing — deferred to the end of the autonomous run]

## Tests

### 1. Details! loaded, join a group
expected: Dialog reads "[TGF] Reset Details! damage meter?" with Yes / No; Yes clears Details! and prints "Details! reset."; No leaves it
result: [pending]

### 2. Details! off, game meter on, join a group; then the game meter off
expected: "[TGF] Reset the damage meter?" and Yes clears the game's meter; with neither meter nothing is asked and `/tgf meter` prints "no damage meter to reset: ..."
result: [pending]

### 3. Enter a dungeon / raid / battleground; /reload inside; leave and enter another instance
expected: Asked once on entry; not asked after /reload; asked on entering another instance
result: [pending]

### 4. Settings > AddOns > TerribleGroupFinder, Damage meter section
expected: Both options on by default; turning either off stops that trigger asking
result: [pending]

### 5. /tgf meter twice while the dialog shows
expected: Prompt shows at any time; a second call keeps a single dialog; the dialog looks native (dialog border, at the usual popup spot)
result: [pending]

### 6. README screenshot
expected: Author decides whether the new dialog needs a README screenshot
result: [pending]

### 7. Review fixes: the prompt and the game's popups (CR-01)
expected: Entering a raid / dungeon with an instance-lock popup ("You will be saved to ..."): our prompt opens below it, never over it, and the lock popup's buttons work; a summon or invite popup opening while ours shows can sit near it but ours is never raised above it
result: [pending]

### 8. Review fixes: same run, Details! own setting, merge (WR-01, WR-02, IN-02)
expected: Dying, releasing and running back into the same instance (within 15 min) doesn't ask; a different instance asks; with Details! set to ask or erase on new instance (its own option), our instance prompt doesn't show (the group prompt still does); joining a group and zoning in together give one prompt
result: [pending]

## Summary

total: 8
passed: 0
issues: 0
pending: 8
skipped: 0
blocked: 0

## Gaps
