---
phase: 06-gear-score-removal-and-settings-foundation
reviewed: 2026-11-14T00:00:00Z
depth: standard
files_reviewed: 7
files_reviewed_list:
  - Core.lua
  - GearScore.lua
  - Preview.lua
  - Settings.lua
  - TerribleGroupFinder.toc
  - UI/Table.lua
  - UI/Widgets.lua
findings:
  critical: 0
  warning: 3
  info: 4
  total: 7
status: issues_found
---

# Phase 6: Code Review Report

**Reviewed:** 2026-11-14T00:00:00Z
**Depth:** standard
**Files Reviewed:** 7 (GearScore.lua reviewed as a deletion against `0fe0249`)
**Status:** issues_found

## Narrative Findings (AI reviewer)

## Summary

Reviewed `git diff 0fe0249..HEAD` for the listed files: gear score removal (Core, Preview,
Table, Widgets, TOC, deleted GearScore.lua) and the new schema-2 migration plus `ns.Settings`
registry.

Gear score removal is complete. No `ns.GS`, `ns.GEAR_SCORE`, `W.GS`, `W.GS_OUTDATED`,
`ListingGS`, `GSLine`, `row.gs`, `header.gs`, `self.myGS` or `gsStale` references remain in any
`.lua` file. The column layout is consistent: `LEFT` ends at Roles (x 190 + w 100), `ACTIVITY_X`
is 292 (the old non-GS value), `FitColumns` still shifts it, `FIRST_DESC`/`VALUES`/`CELL_KEYS`
have no `gs` key, and the status bar anchors straight to `fits.Label`. All Preview member strings
match the new patterns `^([^:]+):(%u+):(%d+):(%u+)(.*)$` (groups) and `^([^:]+):(%u+):(%d+)$`
(solo). Nothing left over carries a stray `:gs` suffix, which would have quietly dropped the zone
or the name. The TOC loads `Settings.lua` before anything calls `ns.Settings` (only from
`ADDON_LOADED`).

No blockers. The problems are in the migration and registry design. The migration is gated only
on the schema number, so a downgrade followed by an upgrade brings back the gear score cache. The
registry writes defaults into the saved table, so a default can never change later. Unknown keys
and invalid options are accepted silently.

## Warnings

### WR-01: Migration is gated only on `schema`, so a v0.1 downgrade brings back `db.gs` permanently

**File:** `Core.lua:31-37` (with `Core.lua:266-275`)
**Issue:** `ns.Migrate` clears `db.gs` / `db.autoRefresh` only when `schema < 2`. A player who
runs v0.2, goes back to v0.1.0 (for example to compare, or after a bad update), and then
upgrades again ends up with `schema = 2` still saved. v0.1.0's `DEFAULTS` loop never lowers an
existing schema, and its `GS.Init` recreates `db.gs = db.gs or {}` and fills it. On the next v0.2
load the gate is false, so the gear score cache (one entry per player name seen) stays in
SavedVariables forever and nothing reads it. Removing keys that nothing uses is idempotent and
needs no gate.
**Fix:** Clear obsolete keys every time, and keep the schema gate only for real data changes:
```lua
local OBSOLETE = { "gs", "autoRefresh" } -- v0.1 gear score cache; prototype key
function ns.Migrate(db)
	for _, key in ipairs(OBSOLETE) do
		db[key] = nil
	end
	if (tonumber(db.schema) or 0) < 2 then
		db.schema = 2
	end
end
```

### WR-02: Registry writes defaults into the saved table, so a default can never change and "turned off by the player" is indistinguishable from the default

**File:** `Settings.lua:17-21`, `Settings.lua:44-49`
**Issue:** `Fill` writes `opt.default` into `db[key]` for every registered option on `Init` (and
on a late `Register`). After the first load, every user's SavedVariables holds
`regionFlags = true`, `dynamicRefresh = true`, and so on. `Get` already falls back to
`opt.default` when the key is not a boolean, so filling is not needed for reads. But it freezes
the defaults: if a later version ships `regionFlags` (a prototype feature) or `swipeAnimations`
as default off, existing users keep the stored `true`. They are never moved to the new default,
because the code cannot tell a stored default from a player's explicit choice. This contradicts
the module's own contract ("on unless the player turned it off").
**Fix:** Store only explicit choices. Drop the write in `Fill`, keep the type clean-up, and let
`Get` fall back to the default:
```lua
local function Fill(opt)
	local v = db[opt.key]
	if v ~= nil and type(v) ~= "boolean" then
		db[opt.key] = nil -- corrupt value: back to "unset" (the default)
	end
end
```
In `Set`, the "nothing changed" check then becomes `if S.Get(key) == value then return true end`.
This also removes the redundant `db[key] == value` half of the current condition (line 93). If
"reset to default" is ever needed, `Set` can write `nil` when `value == opt.default`.

### WR-03: Flat option keys share `TerribleGroupFinderDB` with module data, and `Fill` overwrites any non-boolean value under a registered key

**File:** `Settings.lua:17-21`, `Settings.lua:25-36`
**Issue:** The options live as flat keys beside `schema`, `invite`, `request` (Messages) and
`shards` (Region). `Fill` replaces any value that is not a boolean, so a future `Register`
whose key matches one of those names (`S.Register{ key = "shards", ... }` or `"invite"`) would
overwrite the learned shard table or the whisper presets on the next load, with no error.
`Register` also does not validate its input. `opt.key == nil` raises "table index is nil" at file
load, which breaks every later module's load. A non-boolean `default` (for example a forgotten
`default`) makes `Get` return `nil`, which reads as "off" and contradicts "default on".
**Fix:** Validate in `Register` and reserve the module keys (or nest options under
`db.settings`):
```lua
local RESERVED = { schema = true, invite = true, request = true, shards = true }
function S.Register(opt)
	assert(type(opt.key) == "string" and not RESERVED[opt.key], "Settings: bad key")
	assert(type(opt.default) == "boolean", "Settings: default must be boolean")
	...
end
```

## Info

### IN-01: `OnChange` accepts unknown keys silently

**File:** `Settings.lua:65-72`
**Issue:** `S.OnChange("regionFlag", fn)` (a typo) registers a listener that never fires.
`Set` returns `false` for unknown keys, but `OnChange` gives no such signal. Later phases are
meant to wire redraws through this API, so a typo would show up only as a stale UI.
**Fix:** Return `false`, or raise an error, when `byKey[key]` is nil, to match `Set`.

### IN-02: Registered options have no consumers yet

**File:** `Settings.lua:104-117`
**Issue:** None of the seven keys is read anywhere (`grep Settings.Get` finds no callers). For
example, `regionFlags` is stored but `Region.lua` always draws flags. This matches the plan
(later phases wire them), but until then `Set` changes saved data with no effect. Make sure no
UI exposes these switches before each feature reads `S.Get` where it acts.
**Fix:** Track the wiring per key in the later phases. Optionally add a one-line comment above
`OPTIONS` saying which phase wires each key.

### IN-03: Header comment line far over the formatter width

**File:** `UI/Table.lua:15-16`
**Issue:** The edited comment's line 16 is 160 characters. The rest of the header wraps at
about 95, and stylua does not rewrap comments, so the line will stay this way.
**Fix:** Rewrap lines 15-16 to the file's usual width.

### IN-04: Migrate comment overstates the reference holder

**File:** `Core.lua:28-30`
**Issue:** The comment says the table is never replaced because "the settings API holds a
reference to it". `Migrate` runs before `ns.Settings.Init`, and Messages and Region also keep the
same table (`Region.lua:116`, `learned = db.shards`). The rule is right, but the stated reason is
narrower than the real one.
**Fix:** Change the reason to "modules hold references to it and its sub-tables (Settings,
Messages, Region)".

---

_Reviewed: 2026-11-14T00:00:00Z_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
