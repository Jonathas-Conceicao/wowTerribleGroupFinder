---
phase: 12-damage-meter-reset-prompt
reviewed: 2026-11-16T00:00:00Z
depth: standard
files_reviewed: 4
files_reviewed_list:
  - MeterReset.lua
  - Core.lua
  - Settings.lua
  - TerribleGroupFinder.toc
findings:
  critical: 1
  warning: 3
  info: 3
  total: 7
status: issues_found
---

# Phase 12: Code Review Report

**Reviewed:** 2026-11-16
**Depth:** standard
**Files Reviewed:** 4
**Status:** issues_found

## Summary

Reviewed the damage meter reset prompt (`MeterReset.lua`, new), its wiring in `Core.lua`
(`ns.MeterReset.Init()`, `/tgf meter`), the two `meterResetOn*` options in `Settings.lua` and
the TOC load order, against `git diff f4aa854`. Checked against the Blizzard `forever`
branch (`Blizzard_DamageMeter`, `DialogTemplates.xml`, `GameDialog.xml`, `GameDialogDefs.lua`)
and the installed Details! (`container_segments.lua`, `core/control.lua`).

What holds up:
- **Taint:** nothing of Blizzard's is written. The dialog is our own frame, `YES` / `NO` are
  only read, nothing goes into `StaticPopupDialogs`, and `C_DamageMeter.ResetAllCombatSessions`
  has no restriction flag in its documentation (Blizzard calls it from an ordinary menu
  callback).
- **Secret values:** `IsInGroup`, `IsInInstance`, `GetInstanceInfo`, `C_CVar.GetCVarBool` and
  `IsDamageMeterAvailable` don't return secrets in the documentation. No `issecretvalue`
  guard is needed here.
- **Layering:** `DialogBorderTemplate` inherits `useParentLevel="true"`, so its `Bg` does not
  cover the parent's text.
- **Load order:** `MeterReset.lua` loads after `Core.lua` and `Settings.lua`. It uses `ns.W`
  only lazily, in `Build()`, so loading before `UI\Widgets.lua` is safe.
- **Details! API:** `Details:ResetSegmentData()` exists and clears every segment.

The problems are in where the dialog sits on screen, in how the instance trigger behaves
during a dungeon run, and in how it works alongside Details!' own erase prompt.

## Critical Issues

### CR-01: The dialog sits exactly on StaticPopup1, covering the instance-lock and summon dialogs at the moment it shows

**File:** `MeterReset.lua:82-86` (also `121-133`)
**Issue:** The frame is 320 wide, anchored `TOP, UIParent, TOP, 0, -135`, with strata
`DIALOG` and `SetToplevel(true)`. That is the same spot, width, strata and toplevel flag as
`StaticPopup1` (`Blizzard_StaticPopup_Game/GameDialog.xml:350`). The instance trigger fires on
`PLAYER_ENTERING_WORLD` inside an instance. That is the same moment the game shows
`INSTANCE_LOCK` ("You will be saved to …"; `GameDialogDefs.lua:2309`). That popup has a
countdown, and you are removed from the instance when it runs out. Our frame covers the
popup's text and the top of its body. Whichever frame was shown or clicked last draws on
top, so the player may not see the lock warning at all, or may click our Yes / No when they
meant to click the game's buttons. The dialog has no timeout and no Escape (by design), so
it stays on that spot until it is answered. Any later StaticPopup1 then collides with it
too: `CONFIRM_SUMMON`, `PARTY_INVITE`, resurrect, and so on. The addon's own UI then hides
time-critical game dialogs.
**Fix:** Don't share StaticPopup1's spot. Either use a fixed spot clear of the popup stack,
or place the dialog under the shown popups each time it opens (this only reads
Blizzard's frames). For example:
```lua
local function Place(f)
	f:ClearAllPoints()
	local below
	for i = 1, (STATICPOPUP_NUMDIALOGS or 4) do
		local p = _G["StaticPopup" .. i]
		if p and p:IsShown() then
			below = p
		end
	end
	if below then
		f:SetPoint("TOP", below, "BOTTOM", 0, -8)
	else
		f:SetPoint("TOP", UIParent, "TOP", 0, -135 - 160) -- below the popup stack's first slots
	end
end
-- in M.Ask, before dialog:Show():
Place(dialog)
```
Also drop `SetToplevel(true)`, or use strata `HIGH`, so the game's dialogs always draw
over ours.

## Warnings

### WR-01: Each wipe-and-run-back re-asks mid-dungeon

**File:** `MeterReset.lua:152-164` (`instance` reset to `nil` at line 156 when outside)
**Issue:** `instance` becomes `nil` on every loading screen outside. In vanilla-style
dungeons on Forever, releasing after a death puts you at a graveyard outside, and running
back in fires `PLAYER_ENTERING_WORLD` with `now ~= instance`. The trigger then asks to reset
the meter mid-run, after every wipe. Clicking Yes out of habit loses the run's data. Hearthing
out to repair, or stepping out to drop a sick member, does the same. Details!' own
`CheckForAutoErase` (`core/control.lua:1990-2015`) avoids this. It remembers the last
instance's map ID across visits outside, and only asks again for a different instance or
after 6 hours.
**Fix:** Keep the last entered instance through visits outside, and only treat a different
instance, or a long gap, as "entered":
```lua
local lastInstance, lastEnteredAt -- not cleared outside
...
local now = InstanceNow()
local entered = now ~= nil and (now ~= lastInstance or (GetTime() - (lastEnteredAt or 0)) > 3600)
if now ~= nil then
	lastInstance, lastEnteredAt = now, GetTime()
end
```
Optionally, also clear `lastInstance` when the group trigger fires, so that a new group
running the same dungeon is still asked.

### WR-02: Duplicates Details!' own erase prompt or auto-erase on entering an instance

**File:** `MeterReset.lua:162-164`, `MeterReset.lua:46-54`
**Issue:** Details! has its own setting, `Details.segments_auto_erase`: 1 keep, 2 ask,
3 erase (`core/control.lua:1994-2009`). It runs on entering a new instance. With "ask", the
player gets two Yes / No dialogs for the same thing: Details!' after 1 s, and ours. With
"erase", Details! has already wiped the data (after 2 s), and our dialog then asks whether
to reset a meter that is already empty.
**Fix:** Defer to Details!' own choice for the instance trigger. Reading another addon's
field doesn't taint anything:
```lua
local function DetailsHandlesInstances()
	local d = Details()
	local mode = d and tonumber(d.segments_auto_erase)
	return mode == 2 or mode == 3
end
-- in OnEvent:
if entered and ns.Settings.Get("meterResetOnInstance")
	and not (M.Target() == "details" and DetailsHandlesInstances()) then
	M.Ask()
end
```
Or mention it in the `meterResetOnInstance` tooltip.

### WR-03: Yes can do nothing without a word

**File:** `MeterReset.lua:59-72`, `107-110`
**Issue:** `M.Reset()` works out the target again when Yes is clicked. In two cases, nothing
happens and nothing is printed:
- The meter was turned off (`damageMeterEnabled` off) or became unavailable after the
  question was asked. The target is then `nil` and `ok` is `false`.
- The reset call raised an error. `pcall` returns `false`, and the error message is thrown
  away.

Either way the player clicked Yes and the data is still there, with no feedback.
**Fix:** Remember the target the question named, and report a failure:
```lua
function M.Reset(target)
	target = target or M.Target()
	local ok, err = false, "no damage meter to reset"
	if target == "details" and Details() then
		ok, err = pcall(Details().ResetSegmentData, Details())
	elseif target == "blizzard" and C_DamageMeter and C_DamageMeter.ResetAllCombatSessions then
		ok, err = pcall(C_DamageMeter.ResetAllCombatSessions)
	end
	ns.Print(ok and ((target == "details" and "Details!" or "Damage meter") .. " reset.")
		or ("couldn't reset the damage meter: " .. tostring(err)))
	return ok
end
-- M.Ask: dialog.target = target; Yes: M.Reset(f.target)
```

## Info

### IN-01: Yes mid-fight ends Details!' current combat

**File:** `MeterReset.lua:107-110`, `64`
**Issue:** The group trigger can fire in combat, for example when you're invited while
fighting. `segmentClass:ResetAllCombatData()` calls `Details:EndCombat()` when Details! is in
combat (`container_segments.lua:1051-1053`). A Yes click mid-pull throws away the fight in
progress. Without Escape, the dialog also can't be dismissed by keyboard during that fight.
This is by design, but worth knowing.
**Fix:** Optionally, wait for `PLAYER_REGEN_ENABLED` before showing the dialog from the
group trigger, or make Yes do nothing while `InCombatLockdown()`.

### IN-02: The group and instance triggers can ask twice for one event

**File:** `MeterReset.lua:162-171`
**Issue:** Argument-less `IsInGroup()` counts instance groups too. Entering a battleground
solo fires both triggers: `GROUP_ROSTER_UPDATE` for the instance group, and
`PLAYER_ENTERING_WORLD`. They are only merged while the first dialog is still on screen. If
the player answers the first, and the second event comes after (event order differs by
content), they are asked again.
**Fix:** After any answer, ignore the other trigger for a few seconds, for example by
storing `lastAnsweredAt = GetTime()` and skipping `Ask` within 5 s.

### IN-03: CLAUDE.md's SettingsPanel line lists the old sections

**File:** `CLAUDE.md` (the `UI/SettingsPanel.lua` entry), from `Settings.lua:165-176`
**Issue:** The page now has a "Damage meter" section between Group finder and Messages. The
architecture note still says "sections Item level / Group finder / Messages".
**Fix:** Change it to "sections Item level / Group finder / Damage meter / Messages".

---

_Reviewed: 2026-11-16_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
