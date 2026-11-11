---
phase: 01-gear-score-off-and-release-plumbing
reviewed: 2026-11-11T17:30:00Z
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
  warning: 0
  info: 6
  total: 6
status: clean
---

# Phase 1: Code Review Report (re-review after fix pass)

**Reviewed:** 2026-11-11
**Depth:** standard
**Files Reviewed:** 12
**Status:** clean (no critical or warning findings remain; Info items only)

## Summary

This re-review covers the phase diff (`166251b..HEAD`), with a close look at the fix commits (`b0008ec..HEAD`: 7721376, 2c08725, b869e80). I checked the code with `ns.GEAR_SCORE` both off (as shipped) and on. `stylua --check .` passes.

Already decided, so not reported again:
- WR-01 (LICENSE left out of the release zip): author convention, deferred to the Phase 5 Release Review.
- The D-10 one-time preset migration: author decision.

**Fix verification:**

- **WR-02 (fixed).** The help text in `Messages.lua:200-206` now adds ", gear score" only when the switch is on, and reads the same as before when it is off. The `Core.lua:13-16` comment and `GEARSCORE.md` no longer promise that the switch restores the preset. They now say that the default has no `{gs}` and that the migrated saved text is not restored. `M.DEFAULTS` and the migration are unchanged, as the author decided.
- **WR-03 (fixed).** `StoreSelf(tries)` makes at most `ITEM_RETRIES + 1` = 4 attempts and clears `selfPending` on every exit path: when complete (`GearScore.lua:142-145`) and when giving up (`:146-149`). `QueueStoreSelf` (`:157-165`) sets `selfPending` before it schedules, so a burst of `PLAYER_EQUIPMENT_CHANGED` events queues only one timer. `GS.ScanGroup` (`:247-249`) makes its immediate attempt only when no chain is pending, so it never starts a second chain. None of the paths can leave `selfPending` stuck at `true`. One remaining edge case, below Warning level, is listed as IN-06.
- **WR-04 (fixed).**
  - `ns.Short` (`Core.lua:21-26`) now returns nil for anything that is not a string, and for secret values.
  - Every caller handles the nil:
    - `GS.Store` (`:105-108`) and `GS.Lookup` (`:119-120`) already check for a nil name.
    - `GS.ScanGroup` (`:257-258`) checks `short` before it indexes `fresh`.
    - `Listings.lua:56` runs only after `Secret(p.name)` has been checked at `:49`.
    - `Listings.lua:81` runs only after `type == "string" and not Secret`.
  - `Next()` (`:223-231`) reads the GUID and name first and skips a unit that has no GUID, or a secret GUID or name. The `while` loop then moves on to the next queued unit, so a skipped unit does not stall the queue.
  - `INSPECT_READY` (`:284`) checks `Secret(arg)` before the `==` comparison.
  - The order of the checks in `ns.Short` is safe: `type()` on a secret value is allowed, and `issecretvalue` runs before any string method.

**No regressions found** in the fix diff. With the switch off, none of the changed `GearScore.lua` code runs (`GS.Init` returns at once), and the help text is unchanged.

The five Info items from the previous review are still in the code and are kept below as IN-01 to IN-05. IN-06 is new and comes from the WR-03 fix.

## Info

### IN-01: The IconTexture lookup is copied into both scripts and can ship a file from anywhere

**File:** `scripts/install.ps1:55-68`, `scripts/package.ps1:34-47`
**Issue:** The same IconTexture block and git-tracked warning block live in both scripts, so they can drift apart. The resolved `$iconRel` is also never checked to stay under `Media\Textures`. A TOC IconTexture pointing at `Media\Source\...` or at a `..\` path would be deployed and zipped locally, while the release (which excludes `Media/Source` per `.pkgmeta`) would leave it out, and nothing would warn about the difference.
**Fix:** Move the file-set logic into a shared, dot-sourced `scripts/FileSet.ps1`, and reject any `$iconRel` that does not start with `Media\Textures\` or that contains `..`.

### IN-02: png2tga skips chunk CRCs and silently ignores tRNS for RGB images

**File:** `tools/png2tga.js:35`, `tools/png2tga.js:38`, `tools/png2tga.js:97-99`
**Issue:** Chunk CRCs are not checked. For colour type 2, a `tRNS` colour key is read but never applied, so those pixels come out opaque. The current icon is palette type 3 and converts correctly.
**Fix:** Throw `if (ctype === 2 && trns)`, or apply the colour key. Optionally verify each chunk's CRC with `zlib.crc32`.

### IN-03: Store tokens are exposed to every workflow step, and any tag publishes

**File:** `.github/workflows/release.yml:5-11`
**Issue:** `CF_API_KEY` and `WAGO_API_TOKEN` are set in the workflow-level `env`, so every step can read them. The trigger `tags: "**"` also uploads on any pushed tag.
**Fix:** Move both secrets into the packager step's `env:`, and narrow the trigger to `tags: ["v*"]`.

### IN-04: Table header comment lines now exceed the file's width

**File:** `UI/Table.lua:8`, `UI/Table.lua:11`
**Issue:** These two lines are 124 and 119 characters long, while the rest of the block wraps at about 90.
**Fix:** Re-wrap both paragraphs to the width of the rest of the block.

### IN-05: `ACTIVITY_X` is hand-computed instead of derived from `LEFT`

**File:** `UI/Table.lua:51-53`
**Issue:** `268`, `318` and the GS column's `x = 268` are magic numbers, and they must agree with the Roles column (`190 + 76 + 2`).
**Fix:** Derive the value from the last left column: `local last = LEFT[#LEFT]; local ACTIVITY_X = last.x + last.w + 2`.

### IN-06 (switch on): An equipment change that arrives while a chain is pending can get only one try, or none

**File:** `GearScore.lua:146-149`, `GearScore.lua:157-160`
**Issue:** `QueueStoreSelf` ignores any request while a chain is pending, and does not reset that chain's try count. Two cases follow:
- A `PLAYER_EQUIPMENT_CHANGED` that lands just before a chain's last attempt (`tries == ITEM_RETRIES`) gets that one attempt. If the new item's quality has not loaded by then, the chain stops, and the new gear's score is never cached until the next equipment change or ready check.
- At login, the cap gives item data about 4 seconds to load, with nothing listening for `GET_ITEM_INFO_RECEIVED`. On a cold item cache this may not be enough.

The impact is small: `GS.Mine()` computes your score live, so "Your GS" stays correct. Only the cached entry is affected, which is what `GS.Of`/`GS.Lookup` return for you as a listing member (`UI/Table.lua:124-128`, `:263-269`).
**Fix:** Let a new request restart the count of the pending chain instead of being dropped. Keep a module-level `selfTries` that `QueueStoreSelf` resets to 0 when a chain is pending, and have `StoreSelf` read and increment it rather than take a `tries` parameter.

---

_Reviewed: 2026-11-11T17:30:00Z_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
