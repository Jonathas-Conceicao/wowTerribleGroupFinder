---
phase: 01-gear-score-off-and-release-plumbing
reviewed: 2026-11-11T00:00:00Z
depth: standard
files_reviewed: 12
files_reviewed_list:
  - .gitattributes
  - .github/workflows/release.yml
  - .pkgmeta
  - Core.lua
  - GearScore.lua
  - Listings.lua
  - Messages.lua
  - TerribleGroupFinder.toc
  - UI/Table.lua
  - scripts/install.ps1
  - scripts/package.ps1
  - tools/png2tga.js
findings:
  critical: 0
  warning: 4
  info: 5
  total: 9
status: issues_found
---

# Phase 1: Code Review Report

**Reviewed:** 2026-11-11
**Depth:** standard
**Files Reviewed:** 12
**Status:** issues_found

## Summary

I reviewed the phase diff (`166251b..HEAD`) and the code it touches, with `ns.GEAR_SCORE` both off (as shipped) and on.

**Gear score off (D-01..D-10).** This part works. When the switch is off:
- Nothing reaches `ns.GS` except `GS.Init`, which returns at once.
- The GearScore frame is never created.
- The GS column, sort key, `FIRST_DESC` entry, header tooltip, "Your GS" band and tooltip GS lines are all skipped.
- `{gs}` is gone from `M.TOKENS` and from `M.Format`'s values.

Every module-level read of `ns.GEAR_SCORE` (`Messages.lua:18`, `UI/Table.lua:50-61`) runs after `Core.lua` sets it, because `Core.lua` is first in the TOC. `stylua --check .` passes.

**Release plumbing (D-11..D-17).** `tools/png2tga.js` rebuilds the committed `Media/Textures/tgf_icon_64x64.tga` from `Media/Source/baseicon.png` byte for byte (64x64, header `type 2 / 32 bpp / 0x28`). The TOC IDs, IconTexture, `.pkgmeta` ignores and the narrowing to `Media\Textures` match the decisions.

**Main concerns:**
1. The release zip leaves out `LICENSE` while this phase turns on public CurseForge/Wago uploads.
2. The switch is not fully reversible: the `{gs}` preset was rewritten and the default changed for good.
3. The switched-off gear score code has robustness gaps that come back when it is turned on: unbounded retry chains and no secret-value guards.

## Warnings

### WR-01: Public store releases ship without the GPL licence text

**File:** `.pkgmeta:17` (with `.github/workflows/release.yml:10-11`)
**Issue:** `LICENSE` is in the packager's ignore list, so the release zip has no copy of the licence. Until now nothing was uploaded anywhere. This phase enables `CF_API_KEY` / `WAGO_API_TOKEN` and the TOC store IDs, so the next tag pushes a GPL-3.0 program to CurseForge and Wago without the licence text. GPL-3.0 section 4 requires giving recipients a copy of the licence, and the Lua files carry no licence header to make up for it.
**Fix:** Remove `LICENSE` from the ignore list in `.pkgmeta`. The packager then ships it at the root of `TerribleGroupFinder/`, which WoW ignores. Optionally add it to the package.ps1 file set too, so the local zip matches.
```yaml
ignore:
  - .gitignore
  ...
  - README.md
  # - LICENSE   <- removed: GPL-3.0 must travel with the release
```

### WR-02: The switch is not fully reversible (default preset and saved text lose `{gs}` for good)

**File:** `Messages.lua:16`, `Messages.lua:37-39`, `Messages.lua:203`, `Core.lua:13-15`
**Issue:** The `Core.lua` comment says that setting `ns.GEAR_SCORE = true` "brings back ... the {gs} message key". D-02 likewise says one switch re-enables everything. With the switch on, though:
- (a) `M.DEFAULTS.request` still has no `{gs}`, so a fresh install or a "Default" click gives a preset without it.
- (b) The `OLD_REQUEST` migration has already overwritten the player's saved request text on disk, the first time they logged in with the switch off. Flipping the switch back does not restore it.
- (c) The Messages tab help text (line 203) lists `{gs}` among the placeholders when on, but describes the rest as "your roles, class, level" and no longer mentions gear score.

So re-enabling brings back the key but not the GS message behaviour.
**Fix:** Make the default and the help text depend on the switch, and say in the comment that the migration cannot be undone:
```lua
M.DEFAULTS = {
	invite = "...",
	request = ns.GEAR_SCORE
		and "Hi {name}! Level {level} {class} here ({role}, GS {gs}), could I join you for {activity}?"
		or "Hi {name}! Level {level} {class} here ({role}), could I join you for {activity}?",
}
...
.. ". {name} is who you whisper, {activity} their listing's; the rest are you (your roles, class, level"
.. (ns.GEAR_SCORE and ", gear score" or "") .. ")."
```
Alternatively, narrow the `Core.lua` comment and record in `GEARSCORE.md` that the preset has to be restored by hand.

### WR-03 (switch on): `StoreSelf` retries forever, and each equipment change starts another chain

**File:** `GearScore.lua:130-137`, `GearScore.lua:251-253`
**Issue:** `StoreSelf` reschedules itself every second for as long as `GS.Unit("player")` reports incomplete. There is no retry cap, unlike `Read`, which stops after `ITEM_RETRIES`. An item whose `GetItemInfo` quality never resolves, or a client where `C_Item.GetItemInfo` returns nil for a slot item, keeps the timer running all session. Worse, every `PLAYER_EQUIPMENT_CHANGED` (fired once per slot on a gear-set swap) and every `PLAYER_ENTERING_WORLD` adds a new `C_Timer.After(1, StoreSelf)` chain. While items are loading, N parallel chains each call `GS.Store`, and each call runs `ns.UI.Refresh()`, which redraws every table. This code is dead while the switch is off, but it comes back exactly as written when the switch is flipped.
**Fix:** Collapse the chains into one pending timer and bound the retries:
```lua
local selfPending = false
local function StoreSelf(tries)
	tries = tries or 0
	local gs, complete = GS.Unit("player")
	if complete then
		selfPending = false
		return GS.Store(UnitName("player"), gs, UnitLevel("player"))
	end
	if tries >= ITEM_RETRIES * 3 then
		selfPending = false
		return
	end
	C_Timer.After(1, function() StoreSelf(tries + 1) end)
end
local function QueueStoreSelf()
	if not selfPending then
		selfPending = true
		C_Timer.After(1, StoreSelf)
	end
end
```
Use `QueueStoreSelf` in the event handler and in `GS.ScanGroup`.

### WR-04 (switch on): No `issecretvalue` guards on unit names and GUIDs in the inspect path

**File:** `GearScore.lua:98-99`, `GearScore.lua:195-196`, `GearScore.lua:220`, `GearScore.lua:245-246`
**Issue:** CLAUDE.md requires guarding reads with `issecretvalue()` where values may be secret, and `Listings.lua` does so for every name. `GearScore.lua` does not:
- `UnitName(unit)` / `UnitGUID(unit)` from party/raid units go straight into `ns.Short(name)` (`name:match(...)`) and table indexing (`fresh[Short(name)]`, `cache[name]`).
- The `INSPECT_READY` argument is compared with `arg == current.guid`.

On the modern client, string methods or table keys on a secret value raise an error inside the event handler. `ns.Short` is now shared from `Core.lua`, so it has no guard of its own either. This is unreachable while the switch is off, but it is part of the "flip to true" contract.
**Fix:** Guard at the edges, and make `ns.Short` safe for every caller:
```lua
-- Core.lua
function ns.Short(name)
	if type(name) ~= "string" or (issecretvalue and issecretvalue(name)) then
		return nil
	end
	return name:match("^([^%-]+)") or name
end
-- GearScore.lua, ScanGroup / Next / INSPECT_READY
local function Secret(v) return v ~= nil and issecretvalue ~= nil and issecretvalue(v) end
if name and not Secret(name) and not UnitIsUnit(unit, "player") and not fresh[Short(name)] then
...
if current and not Secret(arg) and arg == current.guid then
```

## Info

### IN-01: The IconTexture lookup is copied into both scripts and can ship a file from anywhere

**File:** `scripts/install.ps1:55-68`, `scripts/package.ps1:34-47`
**Issue:** The same 14-line IconTexture block, and the git-tracked warning block, now live in both scripts, so the two can drift. The resolved `$iconRel` is also never checked to stay under `Media\Textures`. A TOC IconTexture pointing at `Media\Source\x.tga`, or at a `..\` path, would be deployed and zipped locally. The BigWigs release would then leave out `Media/Source` (per `.pkgmeta`), so the local zip and the release would differ without any warning.
**Fix:** Move the file-set logic into a shared `scripts/FileSet.ps1` that is dot-sourced by both scripts. In it, reject an `$iconRel` that does not start with `Media\Textures\` or that contains `..`.

### IN-02: png2tga skips chunk CRCs and silently ignores tRNS for RGB images

**File:** `tools/png2tga.js:35`, `tools/png2tga.js:38`, `tools/png2tga.js:98-99`
**Issue:** D-14 asks the converter to fail loudly on anything it does not support, but two inputs get through:
- Chunk CRCs are skipped (`pos = start + len + 4`), so a corrupted file that still inflates converts without complaint.
- For colour type 2, a `tRNS` chunk (a single transparent colour key) is read but never applied, so its transparent pixels come out opaque (`a = 255`).

The current icon is palette type 3, so the shipped output is correct (I checked that it reproduces byte for byte).
**Fix:** Throw `if (ctype === 2 && trns)`, or apply the colour key: `a = (trns && r === trns.readUInt16BE(0) && g === trns.readUInt16BE(2) && b === trns.readUInt16BE(4)) ? 0 : 255`. Optionally check each chunk's CRC with `zlib.crc32` (Node 20.15+).

### IN-03: Store tokens are exposed to every workflow step, and any tag publishes

**File:** `.github/workflows/release.yml:6`, `.github/workflows/release.yml:10-11`
**Issue:** `CF_API_KEY` and `WAGO_API_TOKEN` are set in workflow-level `env`, so `actions/checkout` and the `awk` step get them as well. The trigger `tags: "**"` also means any pushed tag, for example a stray test tag, now uploads to both stores. `release.bat` only guards the branch, not the tag form.
**Fix:** Move the two secrets into the `BigWigsMods/packager@v2` step's `env:`. Narrow the trigger to `tags: ["v*"]` to match `release.bat`'s `v%VERSION%`.

### IN-04: Table header comment lines now exceed the file's width

**File:** `UI/Table.lua:8`, `UI/Table.lua:11`
**Issue:** The edited comment lines were not re-wrapped: line 8 is 124 characters, and line 11 runs well past the block's existing ~95-character width. stylua does not re-wrap comments, so the header block now has ragged line lengths.
**Fix:** Re-wrap both paragraphs to the block's width.

### IN-05: `ACTIVITY_X` is hand-computed instead of derived from `LEFT`

**File:** `UI/Table.lua:50-53`
**Issue:** `268`, `318` and the gs `x = 268` are three magic numbers that must agree with the Roles column (`190 + 76 + 2`). If Phase 2 (UIP-04) or a later edit changes a left column's width, Activity can overlap or leave a gap without anyone noticing.
**Fix:** Derive it from the last left column:
```lua
local last = LEFT[#LEFT]
local ACTIVITY_X = last.x + last.w + GAP
```
`GAP` is 6, which gives 318 when GS is on and 272 when off. Alternatively, use an explicit constant gap of 2 to keep today's 268.

---

_Reviewed: 2026-11-11_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
