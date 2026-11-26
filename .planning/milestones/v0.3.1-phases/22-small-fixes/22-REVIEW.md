---
phase: 22-small-fixes
depth: standard
status: issues_found
critical: 0
warning: 3
info: 3
files_reviewed: [QuestButton.lua, Messages.lua, UI/Table.lua, UI/InPlace.lua, Listings.lua]
diff_base: 4a8e053
fixed: [WR-01, WR-02, WR-03]
---

# Phase 22 Code Review

No Lua interpreter was available; static review only.

## Warnings

### WR-01: A failed cover build leaks a frame on every hover (QuestButton.lua `BuildCover`)
`cover = c` was assigned last; a failure after `SecureButton(nil, "macro")` left `cover` nil, so
each hover built another secure button.
**Fix (applied):** the frame is kept in `coverFrame` and reused by a retry.

### WR-02: Positional format strings silently disable outcome tracking (Messages.lua `PatternOf` / `StartTracking`)
A nil pattern (a missing global or a `%1$s` string) left a hole in the list, so `ipairs` stopped at it.
**Fix (applied):** nil patterns are skipped; `%N$s` is turned into `(.+)` like `%s`.

### WR-03: Any late refusal reads "expired" (Messages.lua `Resolve`)
The 55 s rule applied to every "declined" outcome, not only the player's own decline.
**Fix (applied):** only `ERR_DECLINE_GROUP_S` carries the "decline" outcome that becomes
"expired" at 55 s or later; other refusals stay "declined".

## Info

- IN-01: `Listings.Carry` shares one outcome entry between two result IDs: intended (the outcome follows its listing); `Resolve` matches by name.
- IN-02: Narrowing also applies when picks changed (to a subset) while the search was out: matches the CONTEXT design; confirm in game (22-HUMAN-UAT).
- IN-03: `armed` is cleared at the end of `After`; no caller relies on it afterwards.

## Checked and sound

`PatternOf` escaping; narrowing never drops your own row; `narrowTo` reset on failure and in the
preview; secure attribute writes behind `InCombatLockdown()`; `CHAT_MSG_SYSTEM` secret guard;
the `ns.state.invited` table shape handled by its only reader.
