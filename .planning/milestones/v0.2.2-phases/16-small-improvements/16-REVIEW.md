---
phase: 16-small-improvements
reviewed: 2026-11-19T00:00:00Z
depth: standard
files_reviewed: 5
files_reviewed_list:
  - MeterReset.lua
  - UI/SettingsPanel.lua
  - Messages.lua
  - Core.lua
  - Settings.lua
findings:
  critical: 0
  warning: 4
  info: 5
  total: 9
status: issues_found
fixed: [WR-01, WR-02, WR-03, WR-04, IN-01, IN-02, IN-05]
---

# Phase 16: Code Review Report

> **Fixed after review (orchestrator, 2026-11-19):** WR-01 `SP.CloseThen` drops the action when
> the panel stays shown (unapplied game settings), so nothing pops up later; also covers IN-05.
> WR-02 activity menu entries check `Motion.Busy()` and that the listing is still in the tables
> (`T.CurrentKeys()` by `Listings.Key`), else print that it's gone. WR-03 `/tgf meter` says the
> prompt is being moved (`M.Moving()`). WR-04 a question showing when Move starts is asked again
> when the move ends. IN-01 comments / CLAUDE.md updated; IN-02 unused `kind` removed. IN-03
> accepted (CONTEXT rule), IN-04 kept (falls back to the first activity). Harness: 0 failed in
> all three modes, with new checks for WR-01 and WR-02.

**Reviewed:** 2026-11-19
**Depth:** standard
**Files Reviewed:** 5
**Status:** issues_found

## Summary

Scope: `git diff 3a7701d..HEAD -- '*.lua'` (movable meter prompt, Settings close-then-act,
activity menu for whispers, schema 3 migration for `meterResetOnGroup`). I checked the APIs against
the `forever` branch of wow-ui-source: `SettingsPanelMixin:Close`, `ExitWithCommit`, the
`GAME_SETTINGS_CONFIRM_DISCARD` popup, `CreateSettingsButtonInitializer`, `SharedButtonTemplate`
and `Settings.OpenToCategory`.

Closing the panel with `Close(true)` is the author's accepted choice. Blizzard wraps each
`setting.Commit` in `securecallfunction`, so I did not raise it as a taint finding. The
migration does what was asked: a fresh DB gets the new default (off), and any earlier DB with no
saved value gets `true` saved. No blockers. The main problems are pending actions:
`SP.AfterClose` keeps its callback armed when the panel refuses to close, and the activity
menu's callbacks skip the checks the Whisper button makes.

## Warnings

### WR-01: A refused close leaves the Move / Messages action armed, and it fires on a later close

**File:** `UI/SettingsPanel.lua:112-126` (with `SP.AfterClose` at 94-107)
**Issue:** `SP.CloseThen` arms `afterClose` before it calls `panel:Close(true)`. When the panel
has unapplied game settings, `SettingsPanelMixin:Close` does not hide. It only calls
`StaticPopup_Show("GAME_SETTINGS_CONFIRM_DISCARD")` (Blizzard_SettingsPanel.lua:256-262). The
`pcall` succeeds, so `afterClose` stays set.
- **Cancel** (button3): the panel stays open and the callback stays armed. When the player later
  closes Settings for any reason (Escape, the X, even much later in the session), the prompt
  suddenly shows in move mode, or the group finder opens on Messages.
- **Exit** / **Apply and exit** (button1/2): these call `ExitWithoutCommit()` /
  `ExitWithCommit()` without `skipTransitionBackToOpeningPanel`, so `TransitionBackOpeningPanel`
  opens the game menu. Our action then runs on top of it, which is the exact fallback `Close(true)`
  was meant to avoid.

**Failure scenario:** The player changes a graphics option without applying it, clicks
"Edit whisper messages", then Cancel on the discard prompt and keeps tuning settings. Ten minutes
later they press Escape to leave Settings, and the group finder pops open on the Messages tab.
**Fix:** Only keep the action when the close actually happened. Check right after `Close`, and
disarm if the panel is still shown (the popup path):
```lua
SP.AfterClose(fn)
local ok = pcall(panel.Close, panel, true)
if not ok then
	afterClose = nil
	return fn()
end
if panel:IsShown() then
	afterClose = nil -- the discard prompt is up; the player decides, we don't act later
	ns.Print("close Settings first (unapplied game settings), then try again.")
end
```

### WR-02: The activity menu's entries skip the Whisper button's checks (busy, listing gone)

**File:** `Messages.lua:236-257`
**Issue:** `Instance:Message` (UI/Table.lua:710-715) refuses while `ns.Motion.Busy()` and for
`l.mine`. The menu entries call `M.Send(l, preview, from, choice)` directly, with the `l` captured
when the menu opened. While the menu is open, a Dynamic refresh can swipe the listing out or turn
it delisted, and a new search can replace the whole list. Choosing an entry afterwards still
whispers (or with Auto-send and Auto-invite, whispers and invites) a listing that is no longer
shown. It also writes `ns.state.messaged[l.id]` for an id the new list may not carry, so the mark
is lost or lands on the wrong row. The click also lands during `Motion.Busy()`, which the button
path blocks on purpose.
**Failure scenario:** The player opens the menu on a group with three dungeons. A Dynamic refresh
answers and the group's delisted row swipes out. The player picks "Deadmines" and Auto-send
whispers a leader who has just closed their group.
**Fix:** Re-check when the entry is chosen. Bail out when the listing is no longer the shown one
for its key:
```lua
root:CreateButton(name, function()
	if ns.Motion.Busy() or l.delisted then return end
	-- optional: resolve l again by ns.Listings.Key from the current list; return when gone
	M.Send(l, preview, from, { activity = name })
	Redraw()
end)
```
Or route the entries through the caller's `Instance:Message` with the choice passed along, so
both paths share one set of checks.

### WR-03: `/tgf meter` during move mode says there's no damage meter

**File:** `MeterReset.lua:273-275`; `Core.lua:333-336`
**Issue:** `M.Ask` returns `not dialog.moving`, so it returns `false` while the dialog is being
moved. `/tgf meter` reads `false` as "no meter" and prints "no damage meter to reset: Details!
isn't loaded and the game's meter is off.", which is wrong while Details! is loaded.
**Failure scenario:** The player clicks Move, then types `/tgf meter` to preview the prompt and
is told Details! isn't loaded.
**Fix:** Tell the cases apart, for example return `false, "moving"` and have the slash command
print "the prompt is being moved; Lock or Default first.", or give the slash command its own
check of `dialog.moving` through an `M.IsMoving()` accessor.

### WR-04: Move takes over a question that is showing, and the question is lost

**File:** `MeterReset.lua:285-293`
**Issue:** `StartMove` reuses the shown dialog. It sets `target = nil`, replaces the text and
swaps Yes/No for Default/Lock without checking whether a reset question is open. The question is
gone with no answer, and after Lock / Default nothing asks again. Meanwhile `lastPromptAt`
(set when it was shown) suppresses the other trigger for 10 s.
**Failure scenario:** The player enters a dungeon and the "Reset Details! damage meter?" prompt
shows. Without answering it, they open Settings and click Move. After Lock the question never
comes back, and the meter keeps the previous run's data.
**Fix:** Either refuse while a question shows (`if dialog:IsShown() and not dialog.moving then
ns.Print("answer the damage meter prompt first.") return end`), or remember the pending target
and re-ask after `EndMove` (`local pending = dialog.target` ... `if pending then M.Ask() end`).

## Info

### IN-01: Comments still say we never close the Settings panel

**File:** `UI/SettingsPanel.lua:89-90`, `MeterReset.lua:295-296`
**Issue:** "we never close it" contradicts `SP.CloseThen`, which now closes the panel through
`Close(true)` (the file header at line 6 is already updated). CLAUDE.md's MeterReset entry
("never closed by us") has drifted the same way.
**Fix:** Change these to "closed only through its own Close, from our two buttons (SP.CloseThen)".

### IN-02: Unused parameter `kind` in `ChooseActivity`

**File:** `Messages.lua:236`
**Issue:** `kind` is passed in but never used. `M.Send` works out the kind again when the entry is
chosen.
**Fix:** Drop the parameter, or pass it through so the kind used for the text is the one checked
for `{activity}`.

### IN-03: Users from before v0.2.1 count as existing and get the group-join prompt on

**File:** `Core.lua:38-46`
**Issue:** `existing = next(db) ~= nil` is true for any saved table, including v0.1 / v0.2.0 data.
Those versions had no meter prompt (it arrived in v0.2.1), so these players never had the prompt
and still get `meterResetOnGroup = true` saved. This matches 16-CONTEXT's definition ("any key"),
so I am noting it, not treating it as a bug.
**Fix:** If the intent is "players who had the prompt", require `tonumber(db.schema) == 2` and the
presence of any meter key. Otherwise, leave it as decided.

### IN-04: Menu errors are swallowed without a trace

**File:** `Messages.lua:240-256`
**Issue:** `pcall(MenuUtil.CreateContextMenu, ...)` drops the error. If it fails, `M.Send` quietly
whispers with the first activity, which is the very case the menu exists to avoid, and nothing
says why.
**Fix:** On failure, print the error once (or `geterrorhandler()(err)`) before falling back.

### IN-05: When `Close` raises an error, the action may run twice

**File:** `UI/SettingsPanel.lua:121-125`
**Issue:** If `panel.Close` raises after `HideUIPanel` has already hidden the panel (for example
inside another OnHide handler), our OnHide hook has already scheduled `afterClose` on
`C_Timer.After(0, …)`. The `not ok` branch then calls `fn()` a second time. This is unlikely, and
`StartMove` / `OpenMessages` are mostly idempotent, but the assumption is not documented.
**Fix:** In the failure branch, only call `fn()` when the panel is still shown
(`if panel:IsShown() then afterClose = nil; fn() end`). The hook covers the hidden case.

---

_Reviewed: 2026-11-19_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
