---
phase: 08-region-flags-and-row-icon-tooltips
reviewed: 2026-11-14T12:59:37Z
depth: standard
files_reviewed: 4
files_reviewed_list:
  - Region.lua
  - UI/Table.lua
  - UI/Widgets.lua
  - Core.lua
findings:
  critical: 0
  warning: 4
  info: 6
  total: 10
status: issues_found
fixed_at: 2026-11-14
fix_scope: WR-01, WR-03, WR-04, IN-02, IN-03, IN-04, IN-05, IN-06
fixed: 8
skipped: 2
fix_status: partial
---

# Phase 08: Code Review Report

**Reviewed:** 2026-11-14T12:59:37Z
**Depth:** standard
**Files Reviewed:** 4
**Status:** issues_found

## Narrative Findings (AI reviewer)

## Summary

Scope: `git diff a1bd770..HEAD` for Region.lua, UI/Table.lua, UI/Widgets.lua and Core.lua. That covers the region flag lookup (seeded table first, learned shards second, DB.shards sanitizing, the own-listing rule, secret guards, the regionFlags gate and redraw), the name-cell icon textures with hit frames in pooled rows, role and open-slot tooltips, and the name-cell layout.

Checked and found sound:
- The seeded table wins over learned shards. `Learn` and `Sane` keep seeded IDs out of DB.shards, and the saved table is held by reference.
- The regionFlags listener is registered once (`hooked`) and redraws through `T.RefreshAll`.
- GUID reads are guarded with `issecretvalue` (`Server`, `Plain`, `PlainIs`).
- The ScrollBox resetter and `HoveredRow` know about tooltips owned by hit frames (`owner.tgfRow`).
- Per-kind textures keep the flag's tex coords from leaking onto atlas icons.
- Hidden or overflowed icons also hide their hit frames.
- `SetPropagateMouseMotion` / `SetPropagateMouseClicks` exist on the forever client (SimpleScriptRegionAPIDocumentation). They are marked protected only in the same way as `EnableMouse`/`Show`, so calling them on our own unprotected row frames is not a combat-lockdown risk.
- Name-cell width math adds up: the icons end exactly at `20 + NAME_W` when the name fills `nameW`.

No blockers. The warnings are about information shown to the player: one own-listing fallback branch that is wrong, region and role labels that state guesses as facts, and icons dropped without notice when the name cell overflows.

## Warnings

### WR-01: Secret leader flag sends a party member's own listing down the "yours" branch

**File:** `Region.lua:96-110`
**Issue:** `PlainIs(UnitIsGroupLeader("player"), false)` is false both when you lead and when the value is secret or nil. A non-leader whose leader flag reads as secret goes to the `else` branch and gets their own realm (`GetRealmID` / player GUID). The tooltip then says "Leader's region: <your region>", which breaks the stated rule ("your own listing shows the group leader's region"). The correct fallback when leadership can't be read is the listing's own `l.shard` (the partyGUID shard), which every other row already uses.
**Fix:**
```lua
if IsInGroup and IsInGroup() then
	local lead = UnitIsGroupLeader("player")
	if not Plain(lead) then
		return R.Of(l.shard) -- can't tell who leads: the party's own shard
	end
	if lead == false then
		-- walk the units for the leader, as now
	else
		-- GetRealmID / player GUID, as now
	end
else
	-- solo: GetRealmID / player GUID
end
```

### WR-02: "US East" / "US West" shown to players as fact while the mapping is unconfirmed

**File:** `Region.lua:21,25-26` (shown via `R.Line` in `UI/Table.lua:565-568` and `UI/Table.lua:604-605`)
**Issue:** The header says "Assumed, to confirm in game: US1 = West, US2 = East". Even so, `R.Line` prints "Region: US East" / "Leader's region: US West" in both the row tooltip and the flag tooltip. If the guess is backwards, every US row tooltip names the wrong coast. The flag art is the same for both US groups, so only the text carries the unconfirmed claim.
**Fix:** Until it is confirmed, label both US groups "US" (or "US (US1)" / "US (US2)") and keep the coast names out of the label:
```lua
US1 = { flag = "us", label = "US" },
US2 = { flag = "us", label = "US" },
```
Restore the East / West labels once a live check confirms them.

### WR-03: Name-cell icons that overflow are dropped with no text tag, Discord first

**File:** `UI/Table.lua:1261-1277`
**Issue:** `nameW` is clamped at `NAME_MIN` (50), so the icons get at most `NAME_W - NAME_MIN = 80` px. The full set can need more: flag 16 + bnet 12 + friend 13 + recent 11 + newPlayer 14 + discord 16, plus 6 gaps of 3, is 100 px. Any icon that doesn't fit is hidden (`icon.tex:Hide(); icon.hit:Hide()`) with no fallback. The trailing Discord icon goes first, and before this phase it was always shown (the name shrank for it). Missing art falls back to a text tag, but overflow falls back to nothing, so the row loses the information without any sign.
**Fix:** Either reserve room so the last icons always fit (narrow the name further, down to a smaller floor), or append the dropped icons as compact text tags. Both options are below; use one:
```lua
if x + w > 20 + NAME_W then
	icon.tex:Hide(); icon.hit:Hide()
	overflow = true
end
-- Option 1: a "+" marker after the last icon that fits, so the player knows to check the tooltip.
-- Option 2: fold the dropped kinds into `tags` and set the name text again.
```

### WR-04: Open-slot tooltip names a role from the estimate as if the server said so

**File:** `UI/Table.lua:822-832` (and `UI/Table.lua:633-634`)
**Issue:** When the server gives no remaining counts (`remaining == 0`), `openRoles` comes from the module-level `open` estimate (COMPOSITION minus member roles). The slot tooltip then reads "Open Healer slot" as a definite statement. The estimate is a guess: a 5-player group with 2 tanks makes COMPOSITION disagree with the real group, and leaders often fill slots with any role. The table's own comments describe the estimate as a guess ("our estimate"), but the tooltip shows it as a fact.
The code also reads the shared `open` upvalue that `Fill` mutates. It works today only because `RoleCounts(l)` runs a few lines earlier in the same function. Any later call to `Fill`/`MyOpen` between those lines would silently swap in the player's own party numbers.
**Fix:** Keep the source with the slot and say when it's an estimate. Also copy `open` into a local right after `RoleCounts`:
```lua
local _, est = RoleCounts(l)
local fromServer = remaining > 0
local source = fromServer and l.remaining or { TANK = est.TANK, HEALER = est.HEALER, DAMAGER = est.DAMAGER }
...
row.slots[j]:SetRole(nil, nil, openRoles[j - i])
row.slots[j].tgfOpenGuess = not fromServer
-- IconTooltip: body = hit.tgfOpenGuess and "Estimated from the members' roles" or nil
```

## Info

### IN-01: Without mouse propagation, hit frames swallow clicks and can leave the row tooltip stuck

**File:** `UI/Widgets.lua:167-176`, `UI/Table.lua:957-960`, `UI/Table.lua:1067-1072`
**Issue:** `W.Propagate` calls `EnableMouse(true)` whether or not `SetPropagateMouseMotion/Clicks` exist. Where they are missing (the web simulator / stand-in environments):
(a) clicks and right-clicks on any icon or role slot never reach the row, so selection and the context menu stop working over them;
(b) entering a hit fires the row's OnLeave, which returns early because the hit is moused over. If `IconTooltip` returned false there (e.g. `class` with no class), the row tooltip stays up. The hit's OnLeave then returns because `owner ~= h`, so moving off the row from the icon leaves the row tooltip open.
The forever client has both APIs, so this only affects the fallback environments.
**Fix:** Only enable mouse when motion propagation exists (no icon tooltips in the fallback), or have the hit's OnLeave also hide when `owner == row` and the row is no longer moused over.

### IN-02: The W.List fallback has no element resetter, so a hit-owned tooltip goes stale on wheel scroll

**File:** `UI/Widgets.lua:698-756` (used by `UI/Table.lua` where the ScrollBox API is missing)
**Issue:** Only the ScrollBox path hides tooltips owned by `owner.tgfRow == frame` when frames are re-filled. If the same icon kind stays shown on a re-filled frame, the flag or role tooltip keeps describing the previous listing. Row tooltips already had this problem before the phase; it now applies to icon tooltips too.
**Fix:** After `fillItem` in `list:Refresh`, if `GameTooltip:GetOwner()` is the frame or has `tgfRow == frame`, re-run the owner's OnEnter or hide the tooltip.

### IN-03: Newly learned shards don't redraw the table

**File:** `Region.lua:159-191`
**Issue:** `LearnAround` (run by `ScanSoon` on PLAYER_LOGIN / BN events) can add shards to `learned`, but nothing refreshes the visible rows. Flags for newly learned shards only appear on the next search or redraw.
**Fix:** In `LearnAround`, record whether any `R.Learn` added a new ID. If one did, call `ns.Table.RefreshAll()` (guarded by `ns.Table and ns.Table.RefreshAll`).

### IN-04: Fallback text tags render before the flag, against the stated visual order

**File:** `UI/Table.lua:1245-1263`
**Issue:** Kinds whose art is missing are appended to the name string (`tags`), while drawn icons, the flag included, are placed after the string. A missing-art "bnet"/"friend" tag therefore shows before the flag, although `NAME_ICONS` puts the flag first.
**Fix:** Accept and document it, or place the flag before the tags (anchor it right after `who.name`'s width and the text tags after it).

### IN-05: Probe's Battle.net loop is unguarded, while LearnAround guards the same calls

**File:** `Region.lua:305-306`
**Issue:** `BNGetNumFriends()` and `BN.GetFriendNumGameAccounts(f)` are called bare and used as loop bounds. A secret or erroring return breaks `/tgf region`. `LearnAround` (lines 169-172) already wraps the same calls in `pcall` and `Plain`.
**Fix:** Reuse the guarded pattern:
```lua
local ok, n = pcall(BNGetNumFriends)
for f = 1, (ok and Plain(n) and tonumber(n)) or 0 do
	local okA, accounts = pcall(BN.GetFriendNumGameAccounts, f)
	for a = 1, (okA and Plain(accounts) and tonumber(accounts)) or 0 do
```

### IN-06: Doc comments for `Tooltip` and `ShowTip` are merged above `ShowTip`

**File:** `UI/Widgets.lua:300-305`
**Issue:** The block describing `W.Tooltip`'s `title / body` (functions of the frame) and `opts.note` (a function) now sits directly above `W.ShowTip`, where `note` is a string. The two descriptions contradict each other, and `Tooltip` is left with no comment.
**Fix:** Move lines 300-302 down to sit above `local function Tooltip`, and keep only the ShowTip lines above `W.ShowTip`.

## Fix Notes

Fixed 2026-11-14 (gsd-code-fixer). Smoke harness: 0 failed in the default, `--fallback` and `--attach` modes, with new checks for WR-01, WR-03, WR-04, IN-02, IN-03 and IN-05. `stylua .` clean; deployed with `scripts/install.ps1`.

| Finding | Status | Commit | Notes |
|---|---|---|---|
| WR-01 | fixed | 2464d8f | In a group, a secret or nil `UnitIsGroupLeader("player")` returns `R.Of(l.shard)`; your realm is used only when solo or leading |
| WR-02 | skipped | - | Author's choice: "US East / US West" wording stays; the mapping is on the deferred in-game check list |
| WR-03 | fixed | ad332b5 | Overflow closes the gaps to 1 px first, then drops icons in `ICON_DROP` order (recent, friendsIn, friend, bnet, newPlayer, flag, discord last); kept icons keep `NAME_ICONS` order. The edge check stays as a safety net |
| WR-04 | fixed | 30523de | `SetRoles` copies the member and open counts right after `RoleCounts`; `SetRole(..., guess)` sets `tgfOpenGuess`; the open-slot tooltip adds "Estimated from the members' roles" when the server gave no counts. Logic change: confirm in game |
| IN-01 | skipped | - | Simulator / stand-in only (the forever client has both propagation APIs) |
| IN-02 | fixed | 9424540 | `W.List:Refresh` re-runs a re-filled frame's OnEnter when a tooltip it or its hit owns is open and the mouse is over it, else hides the tooltip |
| IN-03 | fixed | 76d0b22 | `R.Learn` returns true for a new shard; `LearnAround` calls `ns.Table.RefreshAll()` when one was learned |
| IN-04 | fixed (documented) | 1c846ee | Accepted and documented in `FillRow`: text tags only show where the atlases are missing; moving the flag ahead of them needs a second font string, not worth the risk |
| IN-05 | fixed | 76d0b22 | The probe's Battle.net loop uses `pcall` + `Plain` like `LearnAround` |
| IN-06 | fixed | 3c2d238 | The `Tooltip` comment moved above `local function Tooltip`; `W.ShowTip` keeps its own |

CLAUDE.md updated for the changed behaviour (Region, Widgets list fallback, Table open-slot note and icon drop order).

---

_Reviewed: 2026-11-14T12:59:37Z_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
