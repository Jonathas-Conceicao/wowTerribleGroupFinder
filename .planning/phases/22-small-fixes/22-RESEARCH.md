# Phase 22: Small Fixes - Research

**Researched:** 2026-11-26
**Domain:** WoW Forever addon (Lua): secure-click guarding, group-invite outcome tracking, search-result narrowing
**Confidence:** HIGH for code paths and Blizzard source reads; MEDIUM for chat-message wording details (GlobalStrings come from a mirror, not the repo)

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

Taken at milestone kickoff and the autonomous run's up-front batch (2026-11-26), by the author.

**Elite quest eye guards (QST-05)**
- No error text was recorded: guard every step of the click rather than one known failure: `Q.Cover` / `Q.Recheck` / `Q.Uncover`, the cover's OnEnter / OnLeave / OnMouseDown / OnMouseUp, `Arm` (PreClick), `After` (PostClick), the two delegates' PreClick (`CategoryButton()`, `ActivityCheck()`), `FocusDescription`, `Q.ShowHint` and the outline, and the eye's own click (`Q.Click`)
- Guards: nil / type checks on every frame and method read from Blizzard's finder (`LFGListingFrame:GetCategorySelection`, `IsActivitySelected`, `ActivityView`, the ScrollBox, the tab and micro buttons), and `pcall` around steps that call into Blizzard code; never `pcall` around a secure attribute set in a way that would leave the cover armed with a stale macro: on failure, `Arm` clears `macrotext` so the click does nothing
- A failed step prints `[TGF] Quest eye: <what failed>` once (not on every hover; throttled per distinct message), keeps the error in `Q.lastError` for `/tgf quest`, and leaves the eye usable on the next click (the cover hides cleanly, highlight unlocked)
- The secure-click route, the macro's targets and the taint rules in CLAUDE.md stay exactly as they are; no new writes on Blizzard frames

**Invite outcome (INV-01, INV-02)**
- After the addon's Group Invite button or Auto-invite (the only places that set `ns.state.invited`), the row's Listed cell reads, by outcome:
  - "accepted" (green) when the player joins your group (`GROUP_ROSTER_UPDATE` with that name in the group, and/or the game's join system message `ERR_JOINED_GROUP_S` / `ERR_RAID_MEMBER_ADDED_S`)
  - "declined" (red) on `ERR_DECLINE_GROUP_S`; also on immediate refusals (already in a group `ERR_ALREADY_IN_GROUP_S`, ignoring you, player not found / offline): author's choice, they show "declined"
  - "expired" (grey) when the game says the invite expired (if Forever sends such a message); otherwise our own timer marks it expired 2 minutes after the invite with no answer
  - "invited" (green) while waiting, as now
- Messages are matched by plain character name (Forever's one mega-realm; strip any realm suffix before comparing), built from the game's global format strings (never hard-coded English) turned into patterns; `CHAT_MSG_SYSTEM` text guarded with `issecretvalue`
- Kept in `ns.state` by listing ID next to `invited` (the outcome follows its listing through Dynamic refresh, re-sort and `Listings.Key` remapping exactly as `invited` / `messaged` do); greyed rows show the word in stock grey; whisper-only rows keep "sent"
- A new invite to the same player resets the outcome to "invited"
- Preview: the preview's invite resolves after a few seconds to an outcome (random or cycled) so all three can be seen in `/tgf preview`

**First search after a reload (SRCH-01)**
- Root cause (read from `Blizzard_LFGVanilla_Browse.lua`): picking a category runs `LFGBrowse_DoSearch` for the whole category; the first search after a reload is slow, and picking the activity while it is out calls `LFGBrowse_DoSearch` again, which does nothing while `LFGBrowseFrame.searching` is true. The answer is the category's general view
- The addon must not search again itself (`C_LFGList.Search` is blocked from timers / events; CLAUDE.md taint rules)
- Fix (author's choice, "Show only picked"): when an answer arrives for a search wider than the activities now picked in the dropdown (same category; searched with no activities or a different set), the table narrows that answer to the listings with at least one picked activity, so it shows what an activity search would give. `shownFilter` then becomes the current filter, so the next refresh is a normal Dynamic refresh of it
- Narrowing applies only in that mismatch case; a normal answer is read unchanged. Selection, sections, sorting, greying and Needs my role work on the narrowed list as on any list
- Must also work with Dynamic refresh off and in the preview path (no regressions)

### Claude's Discretion
- Exact helper names, where the narrowing lives (`Listings.Read` filter argument vs the `source.listings` function), the expiry timer mechanism (one ticker vs `C_Timer.After` per invite), throttle details for the eye's chat line
- Whether join detection uses the roster, the system message, or both (both is safest)

### Deferred Ideas (OUT OF SCOPE)
- Outcomes for invites sent outside the addon's buttons (chat, unit menu)
- Distinct states for each kind of refusal
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| QST-05 | Eye hover/click never raises a Lua error | Error-source audit (below), `Try`/`Guarded` helper, Arm / delegate stale-attribute rule |
| INV-01 | Invited row shows accepted / declined / expired | Global strings, pattern helper, roster check, timer, the 60 s popup finding |
| INV-02 | Outcome follows the listing like `invited` / `messaged` | `state.invited[id]` becomes an outcome table, shared by reference through `Carry` |
| SRCH-01 | First search after reload shows the picked activity | Root cause confirmed; narrowing design in `InPlace.lua` + `Listings.Read(previous, only)` |
</phase_requirements>

## Summary

All three fixes are small, local edits in existing files; no new libraries, no new packages, no external tools. No file needs to be added to the TOC if the invite tracking lives in `Messages.lua` (it already owns both `invited` writers and a Redraw helper).

QST-05: the whole route is already mostly nil-checked, but there are four concrete weaknesses worth fixing, beyond adding `Try` wrappers. (1) `Pass` calls `Q.Recheck()` OUTSIDE its pcall (`QuestButton.lua:314`), and `Recheck` -> `Q.Cover` -> frame reads runs inside a `hooksecurefunc` post-hook on the tracker's `EndLayout`: any error there is raised from Blizzard's layout. (2) `Arm` returns early in combat, and on any error mid-way, leaving the previous `macrotext` set (stale macro); the same for the delegates' `clickbutton` (`QuestButton.lua:688-697`). (3) `BuildCover` assigns the module locals `pickCategory` / `pickActivity` / `cover` at different times and creates two NAMED frames: a failure midway then re-runs `CreateFrame` with the same global names on the next hover. (4) The pooled-eye / changed-block case is already safe at click time (Arm re-reads `c.eye:GetParent().id`), but nothing guards a `nil` parent.

INV: the decisive finding is in Blizzard's own source: the invitee's `PARTY_INVITE` popup has `timeout = StaticPopupTimeoutSec` (60 s) and its `OnHide` calls `DeclineGroup()` when not accepted (`Blizzard_StaticPopup_Game/GameDialogDefs.lua:1309-1332`, `Blizzard_StaticPopup/StaticPopup.lua:22`). So an ignored invite is turned by the invitee's client into a decline, and the inviter gets `ERR_DECLINE_GROUP_S` about 60 s later. There is no "invitation expired" string sent to the inviter in the modern GlobalStrings. The 2-minute timer from CONTEXT therefore fires only when no answer ever comes (invitee offline / logged out / client gone); a real timeout shows up as "declined" unless we treat a decline that arrives at about 60 s as expired (recommended, see Open Question 1).

SRCH-01: root cause confirmed in the Blizzard source. One more detail the CONTEXT does not mention: ticking a single activity checkbox does NOT call `LFGBrowse_DoSearch` at all (only the activity-GROUP checkbox, the Reset button, the category radio and the refresh button do); so the narrowing is for answers whose search was issued before the picks changed, exactly as designed, and the picks may be a subset of what was searched. Recommended: record the searched category and activity set in `OnSearch`, compute a `narrowTo` set when the answer arrives, pass it to `Listings.Read`, and keep it until the next answer.

**Primary recommendation:** Add one `Try`/`Guarded` pair at the top of the click-route section of `QuestButton.lua` and route every step through it; make `Arm` and both delegates clear their secure attribute first; store invite state as a per-invite table in `ns.state.invited[id]` (shared by reference through `Carry`); narrow in `Listings.Read(previous, only)` driven by a `narrowTo` set held in `InPlace.lua`.

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Eye click guarding | `QuestButton.lua` (addon UI) | - | All code is ours; only reads Blizzard frames |
| Invite outcome detection | `Messages.lua` event frame (addon logic) | `Core.lua` state | Messages owns both invite writers; `ns.state` holds per-id marks |
| Invite outcome display | `UI/Table.lua` Listed cell | - | The only reader of `state.invited` |
| Search narrowing | `UI/InPlace.lua` (knows searched vs picked) | `Listings.lua` (applies filter) | InPlace sees events and dropdowns; Listings builds items |

## Standard Stack

No new libraries. WoW API only (Lua 5.1 runtime, `C_Timer`, `CreateFrame`, events). Verified against the local Blizzard source (branch `forever`) and the Ketho BlizzardInterfaceResources GlobalStrings mirror.

### Package Legitimacy Audit
No external packages are installed in this phase. Packages removed: none. Packages flagged: none.

### Installation
None. After edits: `stylua .` from the repo root (CLAUDE.md), `./scripts/install.bat`, `/reload` in game.

## Architecture Patterns

### Flow: invite outcome

```
Group Invite button / Auto-invite
   -> Messages.MarkInvited(l)  : state.invited[l.id] = { name, at, outcome="pending" }; arm 120 s timer
   -> C_PartyInfo.InviteUnit(plain name)
CHAT_MSG_SYSTEM (text) ---- patterns from ERR_* ----> Resolve(name, outcome)
GROUP_ROSTER_UPDATE ------- UnitInParty/UnitInRaid(name) -> Resolve(name, "accepted")
timer (120 s) ------------- still pending -> Resolve("expired")
Resolve -> entry.outcome = x; redraw (deferred while Motion.Busy)
Listings.Read(previous) -> Carry(old.id, new.id): invited[new] = invited[old]  (same table reference)
Table Listed cell -> reads invited[l.id].outcome
```

### Flow: first search after reload

```
category radio -> LFGBrowse_DoSearch (searching=true)   -> OnSearch: issued cat + searched set ({} = whole category)
activity GROUP checkbox -> LFGBrowse_DoSearch            -> ignored by Blizzard (searching); OnSearch returns at searchOut
SEARCH_RESULTS_RECEIVED -> handler: narrowTo = NarrowSet(issuedCat, issuedSet) ; shownFilter = narrowTo and FilterKey() or issued
ReadSoon -> Read -> Listings.Read(previous, narrowTo) -> items keep only listings with >= 1 picked activity
```

### Pattern 1: guard helpers (QST-05)

Put near the top of the secure-click section (before `SecureButton`, `QuestButton.lua:~525`). `ns.Print` prefixes the addon name itself ("TerribleGroupFinder:", `Core.lua:87-90`); the literal `[TGF]` in CONTEXT is the whisper tag (`Messages.lua:16`). Use `ns.Print("Quest eye: " .. step .. " failed")` for consistency with the other chat lines, unless the author wants the literal `[TGF]`.

```lua
local reported = {} -- step -> true: one chat line per step per session

local function Fail(step, err)
	Q.lastError = step .. ": " .. tostring(err)
	if not reported[step] then
		reported[step] = true
		ns.Print("Quest eye: " .. step .. " failed")
	end
end

--- Runs fn(...) under pcall; returns its first two results, or nil after recording the failure.
local function Try(step, fn, ...)
	local ok, a, b = pcall(fn, ...)
	if not ok then
		Fail(step, a)
		return nil
	end
	return a, b
end

--- A script handler that can never raise.
local function Guarded(step, fn)
	return function(...)
		Try(step, fn, ...)
	end
end
```

Apply: `c:SetScript("OnEnter", Guarded("hover", ...))`, same for OnLeave / OnMouseDown / OnMouseUp / PreClick (`Arm`) / PostClick (`After`); the two delegates' PreClick; the eye's `OnEnter` (`:162-165`, split `ShowEyeTip` and `Q.Cover` into two separate Try calls so a tooltip failure does not stop the cover) and `OnClick` (`:171-173`); and `Q.Recheck()` inside `Pass` (`:314`).

### Pattern 2: clear the secure attribute before anything can fail

```lua
local function Arm(c)
	if InCombatLockdown() then return end          -- cover is gone in combat; attributes can't be set anyway
	c:SetAttribute("macrotext", nil)               -- FIRST: a failure below leaves a click that does nothing
	armed.quest, armed.activity, armed.activityName = nil, nil, nil
	local lines = Try("macro", function() ... build the lines (pure reads) ... return table.concat(lines, "\n") end)
	if lines then c:SetAttribute("macrotext", lines) end   -- the attribute set itself is outside Try
end
-- delegates
pickCategory:SetScript("PreClick", function(self)
	if InCombatLockdown() then return end
	self:SetAttribute("clickbutton", nil)
	self:SetAttribute("clickbutton", Try("category button", CategoryButton))
end)
```
`SetAttribute` on our own secure frames out of combat does not raise; keeping it outside `Try` honours "never pcall around a secure attribute set". In `Arm`, set `armed.quest` only after the lines were built, so `After` does not show a hint for a macro that was cleared.

### Anti-Patterns to Avoid
- **Early `return` that leaves the old attribute:** `Arm` at `QuestButton.lua:584-586` and both delegates (`:688-697`) return in combat without clearing; the clear must come before any branch that can return or fail (when not in combat).
- **Building named frames in several statements:** make `BuildCover` idempotent per piece (`pickCategory = pickCategory or SecureButton(...)`) and assign `cover` last, so a retry never calls `CreateFrame` for the same global name twice.
- **Comparing possibly-secret values:** `button.categoryID == QUEST_CATEGORY` (`:549`) and `frame:GetCategorySelection() == QUEST_CATEGORY` (`:541`, `:560`, `:616`, `:953`): these are plain Lua fields set by Blizzard code, not secret in practice, but cheap to route through `PlainNumber`.

## Error-source audit (QST-05)

Blizzard API names verified against `Blizzard_LFGVanilla_Listing.lua` (branch `forever`): `LFGListingMixin:GetCategorySelection()` (`:338`) returns `self.categorySelection`; `IsActivitySelected(activityID)` (`:383`) returns `self.activities[activityID]`; `self.activities` is set in `OnLoad` (`:41`) so it is never nil on a loaded frame; `CategoryView.CategoryButtons` is a `parentArray` (`Mainline/Blizzard_LFGVanilla_Listing.xml:520`) of buttons with `.categoryID` set in `LFGListingCategorySelection_AddButton` (`Listing.lua:787-795`); `ActivityView.ScrollBox` (`xml:590`) is a `WowScrollBoxList`; `ActivityView.Comment` is `LFGListingComment` with `.EditBox` (`xml:602`); `LFGParentFrameTab1` is a global named tab (`Browse.lua:174`).

| Location (QuestButton.lua) | Can raise / misbehave when | Fix |
|---|---|---|
| `Pass` `:314` `Q.Recheck()` | Unguarded, inside a post-hook on Blizzard's `EndLayout`; `Recheck` -> `Q.Cover` -> `eye:GetLeft`, `SetScale`, `SetPoint` on the protected cover | Wrap `Q.Recheck` in `Try("recheck")` (also record via `Q.lastError`) |
| eye `OnEnter` `:162-165` | `ShowEyeTip` error stops `Q.Cover` and vice versa | Two separate `Try` calls |
| `Q.Cover` `:711-730` | `BuildCover()` failure; `c.eye:UnlockHighlight` on a stale eye; `eye:GetEffectiveScale()` | Body inside `Try("cover")`; the early `InCombatLockdown` / `PlainNumber` returns stay |
| `BuildCover` `:647-707` | Partial build then re-run recreates NAMED frames (`TGFQuestCategory`, `TGFQuestActivity`); `events` frame created once but after a failure again | Idempotent per piece, `cover = c` assigned last, inside `Try("build")` |
| cover OnEnter `:654-659` | `self.eye` stale, `ShowEyeTip` | `Guarded` |
| cover OnLeave/OnMouseDown/OnMouseUp `:660-675` | `GameTooltip:GetOwner()`, `EyeDown(eye)` touches `eye.Icon` (nil if a foreign `eye` were ever set) | `Guarded`; in `EyeDown/EyeUp` return when `eye.Icon` is nil |
| `Q.Uncover` `:747-756` | `EyeUp`, `UnlockHighlight`, `cover:Hide()`; cover is PROTECTED: `Hide()` in combat is ADDON_ACTION_BLOCKED (not a Lua error) | Keep the `InCombatLockdown` early return; `Try("uncover")`; see combat note below |
| `Arm` `:583-608` | `c.eye:GetParent()` nil, `block.id` secret (already `PlainNumber`), `LFGParentFrame:IsShown()`, `Q.ActivityFor`; stale `macrotext` on early return/error | Pattern 2; `ActivityFor` inside `Try` |
| delegates PreClick `:688-697` | `CategoryButton()` / `ActivityCheck()` call Blizzard frames: `frame:GetCategorySelection()` on a non-mixin `LFGListingFrame`, `box:FindFrameByPredicate` predicate (`node:GetData()` on odd nodes), `check:IsEnabled()`; stale `clickbutton` | `Try` around the finder reads, `clickbutton` cleared first |
| `ActivityCheck` `:558-579` | `frame:IsActivitySelected` if `frame.activities` nil (not after OnLoad); predicate compares `data.activityID == activityID` (plain) | `type(frame.IsActivitySelected)=="function"` + Try |
| `FocusDescription` `:614-629` | `box:GetText()` secret (already guarded), `SetFocus` on a hidden/disabled box (checked) | Try |
| `After` `:632-645` | `ns.InPlace.ShowFinder` calls Blizzard's `LFGVanilla_ShowFrame` from addon code; errors there surface from our PostClick | `Try("after")`; keep `armed` reset |
| `PlaceOutline` `:774-825` | `CategoryButton()` errors; `CreateFrame` parent; `outline.pulse:Play()` | `Try("outline")`; failure must call `StopOutline()` |
| `PlaceHint` `:829-845` | `LFGListingFrame.ActivityView` nil, `LFGParentFrame:GetRight()` nil (handled by `PlainNumber`), `comment:GetRight()` | Try; method existence checks |
| `BuildHint` `:847-935` | `W.Create`/`DialogBorderTemplate` pcall'd already; `HookScript` calls after `hint = f` | whole `BuildHint` in `Try("hint")` from `ShowHint` |
| `Q.ShowHint` `:939-988` | `LFGListingFrame:GetCategorySelection()` / `IsActivitySelected` (`:953-956`), `fs:GetStringHeight()` nil on a hidden line | whole body `Try("hint")`; `fs:GetStringHeight() or 0` |
| `Q.Click` `:992-1013` | `eye:GetParent()` nil (`:993`), `ns.InPlace.ShowFinder` | `Try("click")`; nil-check `block` |

**Combat edge (verified in the wiki, MEDIUM):** combat lockdown begins AFTER `PLAYER_REGEN_DISABLED` fires, so `InCombatLockdown()` is still false inside the handler at `:700-704` and `Q.Uncover()` can hide the protected cover there. [CITED: warcraft.wiki.gg/wiki/API_InCombatLockdown; a forum reply says the same] Keep that handler, but wrap it in `Try` and make it independent of `cover:IsShown()` timing. If a click happens on a cover that is somehow still shown in combat, `Arm` cannot clear `macrotext` (protected frame in lockdown): the macro runs with the last armed lines. The only hard defence is to hide the cover at `PLAYER_REGEN_DISABLED` (already done) and never show it in combat (already done in `Q.Cover`).

**Which steps run inside secure PreClick handlers:** `Arm` (cover PreClick) and the two delegates' PreClick are plain insecure Lua running before the secure action; they may read Blizzard frames and set attributes on OUR secure frames out of combat only. `pcall` inside them is fine (taint is already ours). Nothing there may call a Blizzard restricted function or write a Blizzard field. `After` (PostClick) is also insecure; it may call `ns.InPlace.ShowFinder` only out of combat. `/click` targets that do not exist (a missing `LFDMicroButton`, `LFGParentFrameTab1`) are silently skipped by the macro; they are not a Lua error; `Q.Probe` already reports them.

**Probe:** `Q.Probe` (`:1072`) already prints `Q.lastError`; extend its output with the list of reported steps (`reported`), and clear `Q.lastError` only on `/reload`.

## Invite outcome (INV-01, INV-02)

### Global strings (modern client). Source: Ketho/BlizzardInterfaceResources `Resources/GlobalStrings/enUS.lua` (mainline) [CITED: github.com/Ketho/BlizzardInterfaceResources]; the strings are not in the wow-ui-source repo (grep found only `ERR_GROUP_FULL` / `ERR_RAID_MEMBER_ADDED_S` usages).

| Global | enUS value | Meaning for us |
|---|---|---|
| `ERR_INVITE_PLAYER_S` | "You have invited %s to join your group." | Sent OK; no state change (stays "invited") |
| `ERR_JOINED_GROUP_S` | "%s joins the party." | accepted (party) |
| `ERR_RAID_MEMBER_ADDED_S` | "%s has joined the raid group." | accepted (raid) |
| `ERR_DECLINE_GROUP_S` | "%s declines your group invitation." | declined (also what an invitee's 60 s popup timeout sends, see below) |
| `ERR_ALREADY_IN_GROUP_S` | "%s is already in a group." | declined (immediate refusal) |
| `ERR_IGNORING_YOU_S` | "%s is ignoring you." | declined |
| `ERR_BAD_PLAYER_NAME_S` | "Cannot find player '%s'." | declined (not found) [ASSUMED this is the invite-offline message] |
| `ERR_CHAT_PLAYER_NOT_FOUND_S` | "No player named '%s' is currently playing." | declined (the whisper that precedes an Auto-invite fails the same way) |
| `ERR_GROUP_FULL`, `ERR_NOT_LEADER`, `ERR_INVITE_PARTY_BUSY`, `ERR_INVITE_SELF` | no name | cannot be attributed to a row: ignore |
| any "invitation expired" string for the inviter | not present | none exists; `PARTY_INVITE_CANCEL` goes to the invitee only |

`ERR_DECLINE_GROUP_REQUEST_S` ("declines your group invitation request") is the request-to-join flow; out of scope.

### The 60-second finding
`StaticPopupDialogs["PARTY_INVITE"]` has `timeout = StaticPopupTimeoutSec` (= 60, `StaticPopup.lua:22`), and its `OnHide` calls `DeclineGroup()` whenever `inviteAccepted` is not set (`GameDialogDefs.lua:1309-1332`). [VERIFIED: wow-ui-source branch forever] An ignored invite is therefore declined by the invitee's own client after about 60 s, and the inviter sees `ERR_DECLINE_GROUP_S`. Consequences:
- A 120 s timer only fires for invitees whose client never answers (offline, disconnected, AFK-kicked). Keep it as the CONTEXT says.
- To make "expired" mean what the author expects, treat a decline whose elapsed time since the invite is at least `EXPIRE_AS_DECLINE = 55` s as expired. This is a small, defensible refinement (not "distinct states per kind of refusal", which is deferred): see Open Question 1 / Assumption A2.

### Pattern from a format string
```lua
-- Source: pattern style of Blizzard_ChatFrame/Mainline/BattlegroundChatFilters.lua (gsub "%%s" -> capture)
local function PatternOf(global)
	local fmt = _G[global]
	if type(fmt) ~= "string" or not fmt:find("%%s") then return nil end   -- positional (%1$s) strings: none in our list
	local escaped = (fmt:gsub("[%^%$%(%)%.%[%]%*%+%-%?%%]", "%%%0"))      -- escape magic characters; "%s" becomes "%%s"
	return "^" .. (escaped:gsub("%%%%s", "(.+)")) .. "$"
end
```
Build the pattern table once at `Init` from the global NAMES (never hard-coded text); skip names whose global is missing.

### Name handling
The captured `%s` may be a hyperlink in the modern client (`|Hplayer:Name-Realm:...|h[Name]|h`) [ASSUMED]; normalise both shapes, then reuse the existing `ns.Short` (`Core.lua:18-23`, `"^([^%-]+)"`, returns nil for a secret/non-string):
```lua
local function Plain(captured)
	local s = captured:match("|h%[(.-)%]|h") or captured
	s = s:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
	return ns.Short(s)
end
```
Compare with the row's `l.leader.name` (already short; `Listings.lua:70`). Guard the event text first: `if type(text) ~= "string" or (issecretvalue and issecretvalue(text)) then return end`; never run `find`/`match` on a secret.

### Roster check
On `GROUP_ROSTER_UPDATE`, for each pending entry: `UnitInParty(name) or UnitInRaid(name)` (both accept a character name), each under pcall and with `issecretvalue` on the result. [ASSUMED: name arguments work for same-realm players on Forever; the system message is the second path.] A player who was already in the group at invite time never resolves via the roster (the game answers `ERR_ALREADY_IN_GROUP_S` first).

### State shape (INV-02)
Today `state.invited[l.id] = true` is written in three places: `UI/Table.lua:750` (button), `Messages.lua:308` (preview Auto-invite) and `Messages.lua:332` (real Auto-invite). Read at `UI/Table.lua:1413`. `Listings.Carry` (`Listings.lua:224-234`) copies `marks[from]` to `marks[to]`, i.e. a REFERENCE for a table value. Therefore:
- Store a table per invite: `state.invited[id] = { name = l.leader.name, at = GetTime(), outcome = "pending" }`. `Carry` needs no change and the outcome follows the listing through Dynamic refresh and re-sort. Do not use a second parallel table keyed by id (it would need its own Carry).
- Resolving by name scans `pairs(ns.state.invited)` for `entry.name == name and entry.outcome == "pending"` and updates them (shared references are updated once).
- A new invite to the same player makes a NEW table (never mutate a resolved one), which resets the outcome to "invited" for that row.
- Table cell (`Table.lua:1413`): `local inv = ns.state.invited[l.id]`; `outcome = type(inv) == "table" and inv.outcome`; text per outcome: pending -> `invited` (green `|cff33ff33`), accepted -> `accepted` (green), declined -> `declined` (`|cffff3333`), expired -> `expired` (grey, e.g. `|cff9d9d9d`; stock `GRAY_FONT_COLOR`); greyed rows use the bare word (the code at `Table.lua:1414` already does for "invited"). `l.delisted` still wins (`:1411`), as now. Check the Listed column is wide enough for "declined" (8 chars, same as "delisted").
- Provide one writer, e.g. `M.MarkInvited(l, preview)` in `Messages.lua`, and call it from the three sites; `Table.lua:750` becomes `ns.Messages.MarkInvited(l, preview)` (the real `InviteUnit` call stays where it is).
- `ResetState` (`Core.lua:289-305`) recreates `invited = {}` on `/tgf reset`; pending timers must check `ns.state.invited[id] == entry` (or `entry.outcome == "pending"` on the captured table) before acting.

### Timer
One `C_Timer.After(120, ...)` per invite capturing the entry table (the same shape as `refresh.at` in `InPlace.lua:116-123`): on fire, `if entry.outcome == "pending" then Resolve(entry, "expired") end`. No ticker needed; no leak (closure holds one small table).

### Redraw
`Resolve` ends with `ns.Table.RefreshAll()` (`Table.lua:2020`). Note `Instance:Refresh` cancels a running swipe (`Table.lua:1603-1605`): when `ns.Motion.Busy()`, retry after 0.5 s (`C_Timer.After`) instead of calling `RefreshAll` at once, so a join message during a Dynamic refresh's swipe does not cut it short. Note the redraw is the existing `Redraw()` helper (`Messages.lua:229`).

### Event wiring
Create one frame in `M.Init` (`Messages.lua:45`): `RegisterEvent("CHAT_MSG_SYSTEM")` and `"GROUP_ROSTER_UPDATE"`. Ignore both while `ns.UsingPreview()` (preview entries must only be resolved by the preview timer). Do not add a new file (the TOC is the shipped file set; `Messages.lua` is already listed).

### Preview
At `Table.lua:751-753` and `Messages.lua:305-311` the preview branches already skip the real call: after `MarkInvited(l, true)`, schedule `C_Timer.After(random 2-4 s, ...)` that resolves the entry to the next of `{ "accepted", "declined", "expired" }` using a counter on `ns.state` (cycled, so all three are seen in a row), then redraw. Check `ns.state.invited[id] == entry` first.

## SRCH-01: first search after reload

### Root cause confirmed (Blizzard_LFGVanilla_Browse.lua)
- `LFGBrowse_DoSearch` (`:331-351`) does nothing while `LFGBrowseFrame.searching` is true; with no activities picked it searches `LFGUtil_GetFilteredActivities(category)` (the whole category).
- Category radio -> `SetSelected` -> `LFGBrowseCategoryButton_OnClick` (`:1065-1069`, `:1102-1105`): resets the activity dropdown and searches.
- Activity dropdown (`:1120-1186`): a single activity checkbox calls only `ValueToggleSelected` (NO search); the activity-GROUP checkbox (`SelectActivityGroup`, `:1134-1136`) and the Reset button (`:1262-1265`) call `LFGBrowse_DoSearch`; the search/refresh button too (`:327-329`). So with a slow first answer, the picked activities are in `ActivityDropdown.selectedValues` when the category answer arrives; the answer lists the whole category.
- `UpdateResultList` (`:178-182`) reads `C_LFGList.GetFilteredSearchResults()`; our `Listings.ReadResults` (`Listings.lua:292-312`) reads the same function, so narrowing must be ours.

### Current addon code (UI/InPlace.lua)
- `FilterKey()` (`:67-80`) returns nil with no activities, so a category-only search has `issued = nil` and `shownFilter = nil` (`:99`, `:343`) and a refresh of it is never "same" (`:111`); keep that behaviour.
- `OnSearch` (`:86-129`) returns at `searchOut` (`:87-89`) for the ignored second `DoSearch`: `issued` therefore still describes the FIRST (wide) search. That is exactly the information needed.
- Answer handler (`:336-359`): `shownFilter = issued` at `:343`; `refresh.pending` merge flag at `:348-354`; `ReadSoon` at `:358`.
- `Read` (`:140-161`) calls `ns.Listings.Read(previous)` (`:153`) for the game path; the preview path never calls it (`:151`).

### Design
1. In `OnSearch`, besides `issued = FilterKey()`, record `issuedCategory` (the dropdown's `GetValue()`) and `issuedSet` (set of selected activity IDs, `{}` for none). Do this in the same place (`:98-99`), after the `searchOut` guard.
2. A helper (new, `InPlace.lua`):
   ```lua
   -- The picked activities as a set when an answer for the search (category, searched) is wider than them.
   local function NarrowSet(category, searched)
   	local f = LFGBrowseFrame
   	local dd = f and f.ActivityDropdown
   	local picks = dd and dd.selectedValues
   	local cat = f and f.CategoryDropdown and f.CategoryDropdown.GetValue and f.CategoryDropdown:GetValue()
   	if type(picks) ~= "table" or #picks == 0 or cat ~= category then return nil end
   	local set, n = {}, 0
   	for _, id in ipairs(picks) do
   		if type(id) == "number" then
   			if next(searched) and not searched[id] then return nil end -- picked what was not searched: can't derive it
   			set[id] = true; n = n + 1
   		end
   	end
   	if n == 0 then return nil end
   	local m = 0
   	for _ in pairs(searched) do m = m + 1 end
   	if m == n then return nil end -- same set: a normal answer
   	return set
   end
   ```
3. In the answer handler, on `LFG_LIST_SEARCH_RESULTS_RECEIVED` and not `ns.UsingPreview()`: `narrowTo = NarrowSet(issuedCategory, issuedSet)`; `shownFilter = narrowTo and FilterKey() or issued`. On a failed non-refresh search set `narrowTo = nil`. Preview path: leave as is (`ns.PreviewListings(2)` is already independent of results).
4. `Read` (`:149-157`): `ns.Listings.Read(previous, narrowTo)`.
5. `Listings.Read(previous, only)` (`Listings.lua:262-290`): after `L.ReadResults(items)` and BEFORE the delisted/dropped loop, remove (backwards) every listing without an activity in `only`:
   ```lua
   if only then
   	for i = #items, 1, -1 do
   		local keep = false
   		for _, a in ipairs(items[i].acts) do
   			if only[a.key] then keep = true break end   -- a.key is the activityID (Listings.lua:35)
   		end
   		if not keep and not items[i].mine then table.remove(items, i) end
   	end
   end
   ```
   `l.acts` is built from `info.activityIDs` (`Listings.lua:165-170`). Your own listing (`l.mine`) is never removed.
6. Why this survives later reads: `ReadSoon` fires for `LFG_LIST_SEARCH_RESULT_UPDATED`, `GROUP_ROSTER_UPDATE`, `LFG_LIST_ACTIVE_ENTRY_UPDATE` and on Browse `OnShow` (`:315-319`, `:28-36`); all go through `Read`, so the held `narrowTo` keeps narrowing the same raw results. It is replaced on the next answer: after the user presses refresh (picks now equal the searched set) `NarrowSet` returns nil and the list reads unchanged. Because `shownFilter = FilterKey()` after narrowing, that refresh is `same` (`:111`) and runs as a normal Dynamic refresh; its snapshot (taken from the narrowed `Listings.items`) matches the new answer's keys.
7. Dynamic refresh off: no change; `narrowTo` does not depend on `dynamicRefresh`. A `refresh.pending` answer also gets narrowing (same code path) and merges against the narrowed snapshot.
8. Category changed while a search was out (`cat ~= category`): `NarrowSet` returns nil (the displayed list stays the old category's: stock behaviour, out of scope).
9. `ClearDropped` (`Listings.lua:253`): called from `Read(previous)` (`:268`) and on new non-refresh searches (`InPlace.lua:126`); narrowing before the drop logic means a narrowed-out delisted listing is never recorded as dropped; fine.

Edge not covered by CONTEXT (decision needed, Open Question 2): searched set `{A}` but picked `{B}` or `{A,B}` (picked something that was not searched). The recommended code returns nil (reads unchanged, `shownFilter = issued`) because the listings cannot be derived; narrowing to the intersection would show a partial list that looks complete.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---|---|---|---|
| Name from a join/decline message | English substrings | Patterns from `ERR_*` global names | Localisation; CONTEXT |
| Realm suffix strip | New parser | `ns.Short` (`Core.lua:18`) | Already guards secrets |
| Result-ID remap | Second Carry | Shared table reference in `state.invited[id]` | `Listings.Carry` already copies the reference |
| Timeout tracking | Ticker/OnUpdate | `C_Timer.After(120)` per invite capturing the entry | Same pattern as `refresh.at` |
| Searching again | `C_LFGList.Search` | Narrow the answer we already have | Blocked from timers/events (CLAUDE.md) |

## Common Pitfalls

### Pitfall 1: stale secure attributes
**What goes wrong:** an error or early return in `Arm` / a delegate leaves the last `macrotext` / `clickbutton`; the next click runs the old macro (e.g. a toggle of the finder).
**How to avoid:** clear first, set last (Pattern 2). **Warning signs:** the finder closes when the eye is clicked with it open.

### Pitfall 2: guarding with `pcall` around frame creation that has global names
`CreateFrame("Button", "TGFQuestCategory", ...)` twice yields a second frame under a duplicate name; make creation once-only (see audit).

### Pitfall 3: expiry never fires, or is wrong
The invitee's popup declines after 60 s (see finding), so a pure 120 s timer almost never shows "expired" for a real ignored invite. Treat a late decline as expired (A2) or accept that "declined" appears.

### Pitfall 4: marking the wrong listing when result IDs are reused
`invited` is keyed by result ID like `messaged`; IDs change with each search. Outcomes resolve by NAME over every entry, so a stale entry from an older search with the same name is updated too; harmless. Do not key by `Listings.Key` (a listing's key changes between solo/group).

### Pitfall 5: redraw cancels a swipe
`Instance:Refresh` cancels `Motion` when busy (`Table.lua:1603-1605`): defer outcome redraws while `ns.Motion.Busy()`.

### Pitfall 6: narrowing the preview
The in-place table in preview (`/tgf preview`) reads `ns.PreviewListings(2)`, not `Listings.items`; never set `narrowTo` while `ns.UsingPreview()`, and never feed `ns.Listings.Read` there.

### Pitfall 7: secret chat text
`CHAT_MSG_SYSTEM` text may be secret in restricted contexts; check type and `issecretvalue` before any string method.

## Code Examples

See Pattern 1, Pattern 2, the format-string helper, and `NarrowSet` / `Listings.Read(previous, only)` above.

Resolve (invite):
```lua
local function Resolve(name, outcome)
	local changed = false
	for _, entry in pairs(ns.state.invited) do
		if type(entry) == "table" and entry.name == name and entry.outcome == "pending" then
			if outcome == "declined" and GetTime() - entry.at >= EXPIRE_AS_DECLINE then outcome = "expired" end -- A2
			entry.outcome, changed = outcome, true
		end
	end
	if changed then Redraw() end   -- deferred while ns.Motion.Busy()
end
```

## State of the Art

| Old Approach | Current Approach | Impact |
|---|---|---|
| `invited[id] = true` | `invited[id] = { name, at, outcome }` | Table cell and three writers change; `Carry` is unchanged |
| Hard-coded English | `ERR_*` global names -> patterns | Locale safe |

## Runtime State Inventory
Not a rename/refactor/migration phase. Saved variables: none added (outcomes are `ns.state`, session only). Nothing to migrate; `Core.lua` schema stays 5.

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | The `%s` captured from join/decline system messages may be a player hyperlink (`\|Hplayer:...\|h[Name]\|h`); `Plain()` handles both | Name handling | Low: the helper handles plain names too |
| A2 | Treating an `ERR_DECLINE_GROUP_S` at >= 55 s after the invite as "expired" matches what the author means; derived from the 60 s popup timeout read in the Blizzard source (the source is verified; the author's intent is not) | Invite outcome | Medium: a real manual decline at 55-60 s shows "expired"; needs author confirmation (Open Question 1) |
| A3 | `ERR_BAD_PLAYER_NAME_S` is what an invite to an offline / unknown player prints; and `ERR_CHAT_PLAYER_NOT_FOUND_S` follows a failed whisper | Global strings | Low: if never matched, the 120 s timer marks the row expired instead of declined |
| A4 | `UnitInParty(name)` / `UnitInRaid(name)` accept a plain same-realm name on Forever | Roster check | Low: the join system message is the second path |
| A5 | The GlobalStrings mirror (Ketho, mainline enUS) matches Forever's client text for these names | Global strings | Low: the code reads the client's own globals at runtime; only the pattern shape is assumed |
| A6 | Stand-in (`UI/MainFrame.lua`) invites use the same `Table.lua:750` path | Preview | Low |

## Open Questions

1. **"Expired" vs the invitee's 60 s popup decline.** Known: the invitee's client sends a decline when its popup times out at 60 s (Blizzard source); no expiry string exists. Unclear: whether the author wants a decline at ~60 s to read "expired". Recommendation: implement `EXPIRE_AS_DECLINE = 55` as above, keep the 120 s fallback timer for non-answering clients, and mention both in the plan so the author can veto at UAT.
2. **Narrowing when picks are not a subset of the searched set** (A searched, B picked). Recommendation: do not narrow (cannot be derived); `shownFilter = issued`. The author may prefer an intersection/empty list.
3. **Chat line literal.** CONTEXT says `[TGF] Quest eye: ...`; `ns.Print` prefixes "TerribleGroupFinder:". Recommendation: `ns.Print("Quest eye: <step> failed")` (consistent with every other chat line).

## Environment Availability

Step 2.6: SKIPPED (no external dependencies beyond the in-game client; `stylua` already required by CLAUDE.md for every task). No automated Lua test infrastructure exists in the repo and `workflow.nyquist_validation` is `false`, so no Validation Architecture section; verification is `stylua .` plus in-game checks recorded in the phase's `*-HUMAN-UAT.md` (CLAUDE.md "Implement, don't probe"): hover/click the eye (finder open/closed, active listing, zone off screen, in combat, `/tgf quest` shows `lastError`); Group Invite to a friend who accepts / declines / ignores; `/reload`, pick category then activity group, search; Post still works after using the eye (taint log).

## Security Domain

No auth, session, crypto or network surface. Applicable ASVS: V5 input validation (chat text from `CHAT_MSG_SYSTEM`, treated as untrusted: type check, `issecretvalue`, anchored patterns, no `loadstring`); V4 not applicable. Taint (the real security boundary of this addon): no `C_LFGList.Search`; no writes on Blizzard frames; secure attributes only on our own frames, out of combat; narrowing and outcomes touch only addon data.

| Pattern | STRIDE | Mitigation |
|---|---|---|
| Chat message spoofing an outcome (a player whispering text that looks like a system line) | Spoofing | Only `CHAT_MSG_SYSTEM` is read (not whispers/say) |
| Secret value arithmetic/compare error | DoS (Lua error) | `issecretvalue` before any string/compare |
| Stale secure macro runs a wrong click | Tampering | Clear-before-set, cover hidden in combat |

## Sources

### Primary (HIGH)
- wow-ui-source, branch `forever`: `Blizzard_GroupFinder_VanillaStyle/Blizzard_LFGVanilla_Browse.lua` (`:139-182`, `:233-354`, `:1056-1190`, `:1224-1265`), `Blizzard_LFGVanilla_Listing.lua` (`:27-47`, `:338-400`, `:750-800`, `:1090-1130`), `Mainline/Blizzard_LFGVanilla_Listing.xml` (`:505-530`, `:580-612`), `Blizzard_LFGVanilla_ParentFrame.lua` (`:100-170`), `Blizzard_StaticPopup_Game/GameDialogDefs.lua:1309-1332`, `Blizzard_StaticPopup/StaticPopup.lua:22`, `Blizzard_ChatFrame/Mainline/BattlegroundChatFilters.lua`
- Repo: `QuestButton.lua`, `UI/InPlace.lua`, `Listings.lua`, `UI/Table.lua`, `Messages.lua`, `Core.lua`

### Secondary (MEDIUM)
- GitHub Ketho/BlizzardInterfaceResources `Resources/GlobalStrings/enUS.lua` (mainline) for the `ERR_*` texts
- warcraft.wiki.gg API InCombatLockdown (combat lockdown starts after `PLAYER_REGEN_DISABLED`)

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH (no new dependencies)
- Architecture: HIGH (all anchors read in the repo and the Blizzard source)
- Pitfalls: MEDIUM (message wording and `UnitInParty(name)` not exercised in game)

**Research date:** 2026-11-26
**Valid until:** 2026-12-26 (the Forever client changes; re-check the finder source if the build changes)
