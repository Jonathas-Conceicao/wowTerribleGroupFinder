# Phase 1: Gear Score Off and Release Plumbing - Research

**Researched:** 2026-11-11
**Domain:** WoW Forever addon (Lua 5.1 client) - feature switch-off, node tooling (PNG to TGA), BigWigs packager / PowerShell packaging scripts
**Confidence:** HIGH (codebase facts, packager source), MEDIUM (WoW's TGA acceptance details, fengari stub fidelity)

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

**Gear score switch**
- **D-01:** One switch, `ns.GEAR_SCORE = false`, defined in `Core.lua` (loaded first, so every file sees it). A short comment there points to `.planning/research/GEARSCORE.md` for how to re-enable. No other flag, no saved-variable or slash-command toggle.
- **D-02:** `GearScore.lua` stays in the TOC load list (so flipping the one switch re-enables everything), but with the switch off it registers no events and creates no event frame at load: frame creation and event registration move inside `GS.Init`, which returns at once when `ns.GEAR_SCORE` is false. `GS.ScanGroup`, `StoreSelf` and the inspect queue are then unreachable.
- **D-03:** The name helper `GS.Short` (strip realm suffix) is not gear-score logic; it moves to `Core.lua` as `ns.Short` (GearScore.lua keeps a local alias / uses `ns.Short`). `Listings.lua` calls `ns.Short`. Nothing outside GearScore.lua references `ns.GS` when the switch is off.
- **D-04:** The saved cache `TerribleGroupFinderDB.gs` is left untouched while off (not read, not pruned, not wiped), so re-enabling keeps old scores.

**Table and preview with GS off**
- **D-05:** The `gs` column is dropped from the column set when the switch is off (built from the column list filtered by the switch), together with its header, its sort key and the default-desc entry. Minimal shift: the columns right of GS move left by the GS width so no gap is left; the flexible Activity column absorbs the space. Phase 2 (UIP-04) owns the real re-layout.
- **D-06:** The "Your GS" text in the table's top band and its hover tooltip are not created when the switch is off. The `GS` line in the row tooltip is skipped.
- **D-07:** `ns.Me()` does not set `gs` when the switch is off (no `ns.GS.Mine()` call, no preview fake value).
- **D-08:** Preview sample data keeps its `gs` fields (inert data, `Preview.lua` untouched apart from what is needed); nothing displays them while off.

**Messages with GS off**
- **D-09:** `{gs}` is removed from the key list shown in the Messages tab and from the values `M.Format` fills while off. The default request preset drops `, GS {gs}`: `Hi {name}! Level {level} {class} here ({role}), could I join you for {activity}?` (Phase 4 replaces the presets entirely; this is only the minimal GS removal.)
- **D-10:** A saved request preset exactly equal to the old GS default is reset to the new default in `M.Init` (one-line migration so the author's own saved text does not keep `{gs}`). Any other user-typed `{gs}` stays literal (unknown keys are left as typed).

**Store IDs and release workflow**
- **D-11:** TOC gains `## X-Curse-Project-ID: 1798577` and `## X-Wago-ID: Q6aqvA6W`.
- **D-12:** `.github/workflows/release.yml` env enables `CF_API_KEY: ${{ secrets.CF_API_KEY }}` and `WAGO_API_TOKEN: ${{ secrets.WAGO_API_TOKEN }}` (uncommented; the author adds the secrets).

**Icon**
- **D-13:** `baseicon.ase` and `baseicon.png` move (git mv after `git add`) to `Media/Source/baseicon.ase` and `Media/Source/baseicon.png`, mirroring TerribleBuffTracker's `Media/Source` + `Media/Textures` layout.
- **D-14:** In-game texture: `Media/Textures/tgf_icon_64x64.tga`, an uncompressed 32-bit (BGRA, 8-bit alpha, top-left origin flag set) TGA converted from the 64x64 PNG with a small node script (no BLP converter or ImageMagick on the machine; `C:\WINDOWS\system32\convert` is the Windows disk tool, never call it). The converter script lives in `tools/` only if it is small and dependency-free (node built-ins: `zlib` for PNG inflate); otherwise in the scratchpad. Recommended: `tools/png2tga.js` (tools/ is already ignored by `.pkgmeta` and not in the TOC, so it never ships).
- **D-15:** TOC line `## IconTexture: Interface\AddOns\TerribleGroupFinder\Media\Textures\tgf_icon_64x64` (no extension).

**Packaging**
- **D-16:** `.pkgmeta` ignore gains `Media/Source`, `"*.ase"`, `dist` and `.release` (alongside the existing `"*.png"`, `tools`, `scripts`, `.planning`, ...).
- **D-17:** `scripts/install.ps1`'s IconTexture lookup only searches the repo root by leaf name; it is fixed to resolve the TOC path relative to the addon folder (strip `Interface\AddOns\TerribleGroupFinder\`) and add that file, erroring if the IconTexture names a file that does not exist as .blp/.tga. `scripts/package.ps1` scans all of `Media/` for .blp/.tga; it is narrowed to `Media/Textures` like install.ps1 so a stray texture in `Media/Source` can never ship. Both outputs must contain only the TOC, the Lua load list and the texture.

### Claude's Discretion
- Exact placement of the switch comment, whether GearScore.lua's `Short` becomes a local alias of `ns.Short`, the PNG decoder details (filter types 0-4, colour types 2/6, bit depth 8; fail loudly otherwise), and the precise column-shift arithmetic in `UI/Table.lua`.
- Verification: a fengari smoke harness in the session scratchpad (`scratchpad/smoke/`) loads the TOC files with WoW API stubs, fires ADDON_LOADED, runs preview mode and builds the table, asserting no GS column / band / tooltip line / `{gs}` key and no event registration by the GS frame. Plus `scripts/package.bat` zip listing and `scripts/install.bat`.

### Deferred Ideas (OUT OF SCOPE)
- Proper redistribution of the freed GS width to Roles / Activity - Phase 2 (UIP-04).
- New default presets and key buttons - Phase 4 (MSG-01..04).
- Finishing or dropping gear score - backlog 999.1.
- BLP instead of TGA for the icon - only if a converter becomes available; TGA is fine in game.
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| GS-01 | No gear score anywhere; no inspects on ready check; GearScore.lua behind one disabled switch | Section "GS touchpoint inventory" lists every site; D-02 event/frame move; harness asserts |
| GS-02 | Design notes in `.planning/research/GEARSCORE.md`; backlog item records finish-or-drop | Backlog 999.1 already exists in ROADMAP.md (lines 95-98); GEARSCORE.md content sources listed below |
| REL-01 | TOC carries both store IDs; workflow enables upload keys | Packager reads exactly these TOC fields and env names (verified in `release.sh`) |
| REL-02 | Icon sources under `Media/Source/`; in-game texture under `Media/Textures/` as `IconTexture` | PNG is palette-type (see Icon section) - decoder must handle colour type 3 |
| REL-03 | Packaging ships only addon files + the texture | install.ps1 / package.ps1 defects pinpointed; packager ignore semantics verified |
</phase_requirements>

## Summary

The phase is two independent strands and both are small and well-bounded. The gear score strand is a set of about 25 guarded edits across five files (`Core.lua`, `GearScore.lua`, `Messages.lua`, `Listings.lua`, `UI/Table.lua`); nothing else touches GS. The cleanest shape is a single `ns.GEAR_SCORE` boolean read at the few sites that create or show GS output, with the table's column set built by filtering. The release strand is TOC lines, a workflow edit, a file move, a one-off node PNG-to-TGA converter, and two PowerShell fixes.

Two findings change the locked plan's details. First, `baseicon.png` is a **palette PNG (colour type 3, 8-bit, PLTE + tRNS, non-interlaced)**, not RGB/RGBA, so the converter must handle colour type 3 with a `tRNS` alpha table (D-14's "types 2/6" list is insufficient; a types-2/6-only decoder would fail loudly on this very file). Second, `install.ps1`'s IconTexture lookup is silently ineffective today (it searches the repo root by leaf name, finds nothing, and only the unrelated `Media\Textures` scan happens to add the file), and `package.ps1` has no IconTexture handling at all and scans all of `Media\`.

A fengari-based smoke harness was prototyped and works: it loads all 10 TOC Lua files with a generic frame stub, fires ADDON_LOADED, runs `/tgf` (preview) and builds the whole table. Against today's code it gives a correct red baseline (4 GS events registered at load/init, a "GS" header text), so it is a usable pass/fail gate for GS-01.

**Primary recommendation:** Implement GS-off by guarding at the creation sites (column list, band text, tooltip line, `Me().gs`, `Format` values, `Init`), keep `GearScore.lua` loaded, and gate on the fengari harness plus a zip/deploy file listing.

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| GS switch | Addon namespace (`Core.lua`) | - | Loaded first; single boolean read by all files |
| Table column set / band / tooltip | UI (`UI/Table.lua`) | - | Pure presentation |
| Message keys and default text | Messages (`Messages.lua`) | Saved variables | Format + migration of saved text |
| Event registration (inspects) | `GearScore.lua` `GS.Init` | `Core.lua` ADDON_LOADED | Must not exist when off |
| Store IDs | TOC | Packager / CI | Packager reads TOC fields; env keys come from GitHub secrets |
| Icon texture | TOC `IconTexture` + `Media/Textures` | Packaging scripts | Client resolves the path at addon-list time |
| File-set rules | `.pkgmeta`, `scripts/*.ps1` | - | Three independent implementations of "what ships" must agree |

## Standard Stack

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| Lua 5.1 (WoW client) | n/a | Addon code | Existing project |
| node built-ins `fs`, `zlib` | node v24.14.0 (installed) | `tools/png2tga.js` PNG inflate, TGA write | D-14: dependency-free |
| stylua | 2.3.1 (installed at `~/.cargo/bin/stylua`) | Format Lua (`stylua .` from repo root) | CLAUDE.md |
| BigWigs packager | `BigWigsMods/packager@v2` (already in workflow) | Release zip, CurseForge/Wago upload | Existing |

### Supporting (verification only, outside the repo)
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| fengari | 0.1.5 (installed in scratchpad `smoke/node_modules`) | Lua VM in node for the smoke harness | Validation only; never in the repo |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| TGA | BLP via `TerribleBuffTracker/scripts/png2blp.js` | Sister addon already has a PNG-to-BLP script; the deferred list says BLP only if a converter becomes available. Not in scope; TGA is locked |

**Installation (harness only):**
```bash
cd C:/Users/jonat/AppData/Local/Temp/claude/3a677a53f55271b6/8039163f-18e8-4930-88a2-d8efcca63b25/scratchpad/smoke
npm install fengari
```

**Version verification:** `npm view fengari version` returned `0.1.5`, created 2017-05-14, no `scripts.postinstall`. [ASSUMED: package name originates from training knowledge; slopcheck unavailable (no python on machine); registry existence alone does not make it VERIFIED]. It is scratchpad-only, so risk to the repo is nil.

## Package Legitimacy Audit

| Package | Registry | Age | Downloads | Source Repo | slopcheck | Disposition |
|---------|----------|-----|-----------|-------------|-----------|-------------|
| fengari | npm | ~9 yrs (2017-05-14) | not checked | github.com/fengari-lua/fengari | unavailable (no python) | Approved for scratchpad only; tagged [ASSUMED]; not a repo dependency |

**Packages removed due to slopcheck [SLOP] verdict:** none
**Packages flagged as suspicious [SUS]:** none. No package is installed into the repo; the planner needs no `checkpoint:human-verify` for repo installs. The harness install happens in the scratchpad and was already done during this research (0 vulnerabilities reported by npm).

## Architecture Patterns

### System Architecture Diagram

```
Game loads TOC (Core.lua first)
  Core.lua: ns.GEAR_SCORE=false, ns.Short, ns.Me() (no .gs)
        |
        +--> GearScore.lua  (defines GS.* only; NO CreateFrame, NO events at load)
        |        GS.Init(db): if not ns.GEAR_SCORE then return  --> frame/events/cache untouched
        |
        +--> Messages.lua   M.DEFAULTS (no GS), M.TOKENS (no {gs}), M.Format (no gs value)
        |        M.Init: old GS default saved text --> new default
        |
        +--> Listings.lua   ns.Short(...)  (no ns.GS)
        |
        +--> UI/Table.lua   COLS = filter(ALL_COLS, gs unless ns.GEAR_SCORE)
                 |  header loop / row cells / Layout / sort map / FIRST_DESC all derived from COLS
                 |  band: myGS text + hover only if ns.GEAR_SCORE
                 |  tooltip: AddLine (no right-hand GS) when off
                 v
        Browse table (LFGBrowseFrame in game / MainFrame stand-in in preview)

Release strand (independent):
  Media/Source/baseicon.{ase,png} --(tools/png2tga.js)--> Media/Textures/tgf_icon_64x64.tga
  TOC: X-Curse-Project-ID, X-Wago-ID, IconTexture --> install.ps1 / package.ps1 / BigWigs packager
  .pkgmeta ignore: Media/Source, *.ase, dist, .release
```

### Recommended Project Structure (changes only)
```
Media/
  Source/baseicon.ase, baseicon.png   # sources, never ship
  Textures/tgf_icon_64x64.tga         # ships, TOC IconTexture
tools/png2tga.js                      # not shipped (.pkgmeta ignores tools)
.planning/research/GEARSCORE.md       # new design notes (GS-02)
```

### GS touchpoint inventory (exhaustive; line numbers are current pre-edit)

**Core.lua**
| Line | What | Change with switch off |
|------|------|------------------------|
| 12-14 (near `DEFAULTS`) | place `ns.GEAR_SCORE = false` + comment (D-01) and `ns.Short` (D-03) near the top, before `ns.Me` | add |
| 95-97 | `ns.Me()`: preview sets `me.gs = me.level + 1.5`, game sets `ns.GS.Mine()` | wrap both in `if ns.GEAR_SCORE then ... end` (D-07) |
| 242 | `ns.GS.Init(ns.db)` in `ns:ADDON_LOADED` | keep the call (GS table always exists because GearScore.lua is loaded); `Init` returns at once. Do not add a second flag |

`ns.Short(name)`: `return name and (name:match("^([^%-]+)") or name)` (copy of GearScore.lua 66-69).

**GearScore.lua**
| Line | What | Change |
|------|------|--------|
| 66-69 | local `Short`, `GS.Short = Short` | replace with `local Short = ns.Short` (drop `GS.Short`, nothing outside uses it after Listings change) |
| 109-111 | `GS.Store` calls `ns.UI.Refresh` | unchanged (unreachable when off) |
| ~246-257 | `local frame = CreateFrame("Frame")` + `frame:SetScript("OnEvent", ...)` run at load | move into `GS.Init` after the early return (`if not ns.GEAR_SCORE then return end` must be the first statement, before `db.gs = db.gs or {}`) |
| 259-276 | `GS.Init`: `db.gs = db.gs or {}`, 60-day prune, `RegisterEvent` x4 (INSPECT_READY, READY_CHECK, PLAYER_EQUIPMENT_CHANGED, PLAYER_ENTERING_WORLD) | early return first (D-04: no `db.gs` creation, no prune) |

Load-time locals (`GetItemInfo`, `C_Item...` lookups, constants) are harmless and stay.

**Listings.lua**: line 56 `name = ns.GS.Short(p.name)` and line 81 `set[ns.GS.Short(name)] = true` -> `ns.Short`.

**Messages.lua**
| Line | What | Change |
|------|------|--------|
| 16 | `request` default contains `({role}, GS {gs})` | new text `Hi {name}! Level {level} {class} here ({role}), could I join you for {activity}?` |
| 18 | `M.TOKENS = "{name} {activity} {role} {class} {level} {gs}"` | drop `{gs}` (build conditionally on the switch if the author wants re-enable parity: `ns.GEAR_SCORE and " {gs}" or ""`) |
| 20-26 `M.Init` | | add migration: if `db.request.text == OLD_REQUEST` (exact old default string) then set new default (D-10). Define `OLD_REQUEST` locally as the exact pre-edit string. Do it unconditionally or only when off - planner choice; conditional on `not ns.GEAR_SCORE` is the safer reading of D-10 |
| 64-67 | `MyGS()` reads `ns.Me().gs` | keep function; only used when on |
| 77 | `gs = MyGS()` in `values` | build `values` without `gs`, then `if ns.GEAR_SCORE then values.gs = MyGS() end`. A typed `{gs}` then stays literal because the gsub callback returns nil (keeps the match) |
| 196 | help text "...(your roles, class, level, gear score)" | drop "gear score" (this is a UI string; the harness text scan would flag it) |

**Preview.lua**: lines 5, 71-90, 132-140, 273 carry `gs` data (inert, D-08). No code change. Optional: none.

**UI/Table.lua** (line numbers pre-edit)
| Line | What | Change |
|------|------|--------|
| 7, 11 | header comment mentions GS | update wording (comment only) |
| 45-50 `LEFT` | name x=4 w=150; level x=156 w=30; role x=190 w=76; **gs x=268 w=44** | build `LEFT` by filtering: define the gs entry conditionally (`if ns.GEAR_SCORE then LEFT[#LEFT+1] = {...} end`) |
| 51 `ACTIVITY_X = 318` | | `ns.GEAR_SCORE and 318 or 268` (see arithmetic below) |
| 52 `FIRST_DESC = { level = true, gs = true }` | | harmless extra key, but D-05 says drop it: `gs = ns.GEAR_SCORE or nil` |
| 112-125 `ListingGS` | uses `ns.GS.Of` | untouched; only called from guarded sites |
| 190-192 `VALUES.gs` | sort accessor | guard assignment (`if ns.GEAR_SCORE then VALUES.gs = ... end`) or leave: it can't be selected once the header is gone. D-05 says remove sort key: guard it |
| 251-262 `GSLine` | uses `ns.GS.Of/Lookup` | untouched; call sites guarded |
| 303-305 | solo tooltip `AddDoubleLine(left, "GS " .. GSLine(who))` | off: `AddLine(left)` |
| 321-329 | member tooltip `AddDoubleLine(left, GSLine(m))` | off: `AddLine(left)` |
| 453-467 `Layout` | loops `LEFT` for fixed cells; Listed right-anchored; Activity LEFT=ACTIVITY_X, RIGHT = Listed LEFT - GAP | no change needed once `LEFT` and `ACTIVITY_X` are right. `cells.gs` is never touched by Layout |
| 498-502 | row `cells` loop over `{ "name","level","role","gs","activity","listed" }` | drop `"gs"` from the key list when off (build list from `LEFT` order + activity + listed) |
| 522-523 | `row.gs = W.Text(cells.gs, ...)` | guard (`cells.gs` is nil when off) |
| 615-616 | FillRow: `ListingGS(l)` + `row.gs:SetText(...)` | guard both lines |
| 688-689 | Refresh header text loop over `LEFT` | no change (gs gone from `LEFT`) |
| 697-698 | Refresh: `ns.GS.Of(ns.Me())` + `self.myGS:SetText` | guard both lines (`self.myGS` is nil when off) |
| 744-753 | band: `self.myGS` FontString, `gsHover` frame, tooltip | wrap all in `if ns.GEAR_SCORE then ... end` |
| 770-771 | header `justify` map and loop `{ "name","level","role","gs","activity","listed" }` | same key list as rows (shared helper); `justify.gs` harmless |
| 796-806 | `Layout(header,...)` then `W.Tooltip(header.gs, "Gear score", ...)` | guard the tooltip; `header.gs` is nil when off and `W.Tooltip` on nil would error |

**UI/Widgets.lua**: lines 55-72 `W.GS`, and `W.GS_OUTDATED`. Only called from guarded sites; leave (needed for re-enable, referenced by GEARSCORE.md).
**UI/InPlace.lua, UI/MainFrame.lua, UI/Listing.lua**: no GS references (grep-verified). `ns.UI.Refresh` is referenced only from `GS.Store` and `UI/Listing.lua`.

Recommended implementation shape: define `local ALL_COLS` / `local COL_KEYS` once at the top of `UI/Table.lua` (a `cellKeys` list: LEFT keys, then `activity`, `listed`) and use it for both the row-cell loop (498) and the header loop (770) so the two cannot drift.

### Column layout arithmetic (UI/Table.lua)

Current: `name x=4 w=150` (ends 154), `level x=156 w=30` (186), `role x=190 w=76` (266), `gs x=268 w=44` (312), `ACTIVITY_X=318`. Gaps: 2, 4, 2, 6. Role needs 5 slot icons x 15 px = 75 <= 76 (`row.slots` at `(i-1)*15`).
Right side: Listed `w=LISTED_W=44` anchored `RIGHT` of the row's actions: `ACTIONS_W = HIDE_W(20) + 3 + MSG_W(66) + 2 = 91`, header uses offset `-(ACTIONS_W + GAP)` = -97; rows anchor Listed `LEFT` of the Whisper button with offset `-GAP`. Activity: `SetPoint("LEFT", owner, "LEFT", ACTIVITY_X, 0)` and `SetPoint("RIGHT", cells.listed, "LEFT", -GAP, 0)` - width is therefore *derived* from the row width; nothing is computed by hand. Total row width in the 620 wide frame is whatever the `W.List` provides.
With GS off: set `ACTIVITY_X = 268` (role ends 266, plus the same 2 px gap GS had). That is a left shift of 50 px (44 col + 6 gap), all absorbed by Activity (which also lengthens the flexible cell by 50). The "columns to the right" are only Activity (fixed from the right: Listed, buttons), so nothing else moves. Planner may pick 270 to mirror the level-to-role 4 px gap; either is fine until Phase 2 re-layouts.

### Anti-Patterns to Avoid
- **Do not delete `GearScore.lua` from the TOC** (D-02) and do not add a saved-variable toggle (D-01).
- **Do not leave `CreateFrame` at GearScore.lua file scope**: that frame would exist (harmless) but D-02 says none is created; the harness asserts frame delta 0 for that file.
- **Do not touch `db.gs`** when off (no prune, no `db.gs = {}`).
- **Do not use `gsub` returning `""` for unknown keys** - `Format` relies on returning nil to leave unknown `{keys}` literal.
- **Taint (CLAUDE.md):** none of the GS edits touch Blizzard frames. The only Blizzard-adjacent behaviour removed is `NotifyInspect`/`ClearInspectPlayer` (own calls). Do not add any write to `LFGBrowseFrame`/`LFGParentFrame` fields while editing `UI/Table.lua`.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| zlib inflate for PNG IDAT | custom inflate | node `zlib.inflateSync` | built-in, correct |
| Zip creation | custom zip | existing `package.ps1` (System.IO.Compression) | already handles forward-slash entry names |
| Release packaging | custom release script | BigWigs packager (existing workflow) | handles TOC fields, ignores, uploads |
| Lua VM for tests | writing an interpreter | fengari (scratchpad) | proven loadable (see Validation) |
| Paeth/Sub/Up/Avg unfilter | n/a - small enough to write | ~25 lines | no dependency allowed (D-14), the one thing that must be hand-written |

**Key insight:** every "big" part already exists; the only hand-written code is the ~60-line PNG decoder + TGA writer and the guards.

## Icon: PNG and TGA details

### baseicon.png (verified via node IHDR read)
64 x 64, **bit depth 8, colour type 3 (indexed/palette), compression 0, filter 0, interlace 0**. Chunks: IHDR(13), **PLTE(768 bytes = 256 entries)**, **tRNS(256 bytes = per-entry alpha)**, IDAT(936), IEND. [VERIFIED: node IHDR/chunk read of baseicon.png in this session]. 2041 bytes. The `.ase` is 3420 bytes.

So `png2tga.js` MUST support colour type 3: each filtered scanline has 1 byte per pixel (palette index); output pixel = `PLTE[idx]` RGB with alpha `tRNS[idx]` (default 255 if tRNS shorter/absent). It should also support colour types 6 (RGBA) and 2 (RGB, alpha 255) for future icons, bit depth 8 only, non-interlaced only, and `throw` on anything else ("fail loudly").

### PNG decoder outline (node, no dependencies)
```js
// Source: PNG spec (W3C PNG 2nd ed.) filter algorithms; zlib built-in
const fs = require('fs'), zlib = require('zlib');
function decodePng(buf) {
  if (buf.readUInt32BE(0) !== 0x89504e47) throw new Error('not a PNG');
  let p = 8, ihdr, plte, trns; const idat = [];
  while (p < buf.length) {
    const len = buf.readUInt32BE(p), type = buf.toString('latin1', p + 4, p + 8);
    const data = buf.subarray(p + 8, p + 8 + len);
    if (type === 'IHDR') ihdr = { w: data.readUInt32BE(0), h: data.readUInt32BE(4), depth: data[8], ctype: data[9], interlace: data[12] };
    else if (type === 'PLTE') plte = data; else if (type === 'tRNS') trns = data;
    else if (type === 'IDAT') idat.push(data);
    p += 12 + len;                      // length + type + data + crc
  }
  if (ihdr.depth !== 8 || ihdr.interlace !== 0) throw new Error('only 8-bit non-interlaced');
  const bpp = { 3: 1, 2: 3, 6: 4 }[ihdr.ctype]; if (!bpp) throw new Error('unsupported colour type ' + ihdr.ctype);
  const raw = zlib.inflateSync(Buffer.concat(idat)), stride = ihdr.w * bpp;
  const out = Buffer.alloc(ihdr.h * stride); let prev = Buffer.alloc(stride);
  for (let y = 0; y < ihdr.h; y++) {
    const f = raw[y * (stride + 1)], line = raw.subarray(y * (stride + 1) + 1, (y + 1) * (stride + 1)), cur = out.subarray(y * stride, (y + 1) * stride);
    for (let i = 0; i < stride; i++) {
      const a = i >= bpp ? cur[i - bpp] : 0, b = prev[i], c = i >= bpp ? prev[i - bpp] : 0;
      let v = line[i];
      if (f === 1) v += a; else if (f === 2) v += b; else if (f === 3) v += (a + b) >> 1;
      else if (f === 4) { const pa = Math.abs(b - c), pb = Math.abs(a - c), pc = Math.abs(a + b - 2 * c); v += (pa <= pb && pa <= pc) ? a : (pb <= pc ? b : c); }
      else if (f !== 0) throw new Error('bad filter ' + f);
      cur[i] = v & 255;
    }
    prev = cur;
  }
  // -> RGBA array
  const rgba = Buffer.alloc(ihdr.w * ihdr.h * 4);
  for (let i = 0, n = ihdr.w * ihdr.h; i < n; i++) {
    let r, g, b, a = 255;
    if (ihdr.ctype === 3) { const k = out[i]; r = plte[k * 3]; g = plte[k * 3 + 1]; b = plte[k * 3 + 2]; a = trns && k < trns.length ? trns[k] : 255; }
    else { r = out[i * bpp]; g = out[i * bpp + 1]; b = out[i * bpp + 2]; if (bpp === 4) a = out[i * bpp + 3]; }
    rgba[i * 4] = r; rgba[i * 4 + 1] = g; rgba[i * 4 + 2] = b; rgba[i * 4 + 3] = a;
  }
  return { w: ihdr.w, h: ihdr.h, rgba };
}
```
Filter notes: filter byte per scanline; `a`=left, `b`=up, `c`=up-left, all as the *reconstructed* values; bpp is bytes per pixel (1 for palette). Paeth tie order is a, b, c.

### TGA writer
Uncompressed true-colour (image type 2), 32 bpp, 18-byte header then BGRA pixels, no footer needed:
```
byte 0  id length = 0        byte 1  colour map type = 0     byte 2  image type = 2
bytes 3-7 colour map spec = 0 (5 bytes)
bytes 8-9 x-origin = 0   bytes 10-11 y-origin = 0
bytes 12-13 width (LE)   bytes 14-15 height (LE)
byte 16 bits per pixel = 32
byte 17 image descriptor = 0x28   (bit 5 = top-left origin, low 4 bits = 8 alpha bits)
```
Pixel rows are written top to bottom when bit 5 is set (so no row flip); each pixel is B, G, R, A. File size for 64x64: 18 + 64*64*4 = **16402 bytes**. WoW accepts uncompressed 32-bit TGA with power-of-two dimensions [ASSUMED: from Wowpedia/training knowledge, not re-verified here; D-14 and the deferred note both rely on it. Two safe alternatives if top-left is a concern: write bottom-up with descriptor 0x08 and flip rows. The in-game check is "icon shows in the AddOn list"]. Premultiplication: PNG alpha is straight; write straight alpha.

### Files
- `git add baseicon.ase baseicon.png` then `git mv` to `Media/Source/` (they are currently untracked: `?? baseicon.ase`, `?? baseicon.png`; `git mv` on untracked files fails, hence "add first" in D-13).
- Add `*.ase binary` to `.gitattributes` (it currently only lists png/blp/tga as binary; `* text=auto` heuristics probably treat the `.ase` as binary because of NUL bytes, but declaring it removes the risk of CRLF conversion corrupting it). [ASSUMED: git's text=auto detection]
- `tools/` exists and is empty (untracked, so git does not see it); `tools/png2tga.js` is the first file there.
- TOC: add (order is free, mirror the sister addon) `## X-Curse-Project-ID: 1798577`, `## X-Wago-ID: Q6aqvA6W`, `## IconTexture: Interface\AddOns\TerribleGroupFinder\Media\Textures\tgf_icon_64x64`. The sister addon's TOC keeps these lines between `## Category:` and `## SavedVariables:`. The TOC is CRLF (`.gitattributes: *.toc text eol=crlf`); the Edit tool preserves line endings of an existing file, but verify with `file TerribleGroupFinder.toc` after editing.

## Packaging

### BigWigs packager facts [VERIFIED: release.sh from github.com/BigWigsMods/packager master, read this session]
- TOC fields are read by `awk` on `^## X-Curse-Project-ID:` (line ~1351) and `^## X-Wago-ID:` (line ~1357). Whitespace stripped. Both fields in the TOC are all that is needed (no `-p`/`-a` flags in the workflow).
- Env tokens (lines ~506-512): `cf_token=$CF_API_TOKEN`, then `cf_token=$CF_API_KEY # deprecated`; `wago_token=$WAGO_API_TOKEN`; `github_token=$GH_API_TOKEN` then `$GITHUB_OAUTH # deprecated`. So D-12's `CF_API_KEY` still works but is the deprecated name; the current name is `CF_API_TOKEN`. D-12 is locked as written; flag this to the author as an optional rename (secret name is theirs to choose, the env name on the left is what the packager reads). The existing `GITHUB_OAUTH` line is also the deprecated name and works.
- `16???` interface values map to game type `forever` (lines ~212, ~228), so `## Interface: 16001` is a recognised Forever TOC. Whether CurseForge/Wago accept that game type for upload is not verifiable offline (see Open Questions).
- Ignore semantics (`parse_ignore`, lines ~975-1000, and `copy_directory_tree`): each `.pkgmeta` ignore entry that is an existing directory becomes pattern `<path>/*`; an entry that does not exist matches both the file and `<path>/*`; patterns are bash `case`-style globs against the path relative to the repo root, where `*` also matches `/`. Therefore `"*.png"` matches `Media/Source/baseicon.png` at any depth, `Media/Source` ignores the directory, and `dist` / `.release` as entries are valid even when absent (and `.release` is a dotfile, which the packager prunes anyway).
- **The packager also auto-ignores everything git does not track** (`vcs_addignore` of `git ls-files --others --directory`, lines ~1133-1154). So `Media/Textures/tgf_icon_64x64.tga` must be **committed** or it silently is not in the release. install.ps1 already prints a warning for untracked textures; package.ps1 does not.
- `.pkgmeta` currently ignores: .gitignore, .gitattributes, .pkgmeta, .github, .planning, CHANGELOG.md, CLAUDE.md, README.md, LICENSE, RELEASE_NOTES.md, stylua.toml, scripts, tools, "*.png", "*.org". `*.tga` is not ignored (correct). Add per D-16: `Media/Source`, `"*.ase"`, `dist`, `.release`. Sister addon `.pkgmeta` uses `Media/Source` plus `"*.png"` the same way. `.pkgmeta` is LF.

### install.ps1 defects (D-17)
- Lines ~54-61: `$iconBase = Split-Path -Leaf (<IconTexture value>)` gives `tgf_icon_64x64`; `Get-ChildItem -LiteralPath $source -Filter "$iconBase.*" -File` lists **only the repo root, non-recursive**, so `$icon` is `$null` for a `Media\Textures` path; and even when found it adds `$icon.Name` (a bare leaf), not the relative path. The sister addon's icon lives at the addon root, which is why the lookup was written this way.
- Today the file still deploys because the separate `Media\Textures` scan (lines ~64-90) adds every `.blp/.tga` there. That is accidental: nothing verifies that the TOC's IconTexture is what ships, and a typo in the TOC passes silently.
- Fix shape: `$iconRel = ($value -replace '^Interface\\AddOns\\TerribleGroupFinder\\', '').Trim()`; probe `"$iconRel.blp"` then `"$iconRel.tga"` under `$source`; if neither exists -> `Write-Host "ERROR: ..."; exit 1`; else add the relative path (backslashes, same form `$texRel` uses so the prune loop does not treat it as stale) if not already in `$files`. Keep the Media\Textures scan (it is already correctly scoped to `Media\Textures`).

### package.ps1 defects (D-17)
- Line ~40: `$texDir = Join-Path $source 'Media'` then `Get-ChildItem -Recurse` for `.blp/.tga` -> change to `'Media\Textures'` (so a `.tga` placed in `Media\Source` can never ship).
- It has no IconTexture handling at all: add the same validation (error if the TOC's IconTexture file is missing). Share the logic by copy (the two scripts do not share code today; keep it a small duplicated block rather than introducing a dot-sourced helper).
- Optional parity: print the install.ps1-style untracked-texture warning (`git ls-files -- Media/Textures`).
- Acceptance: list the zip (`[System.IO.Compression.ZipFile]::OpenRead($zip).Entries.FullName`) and expect exactly 12 entries: `TerribleGroupFinder/TerribleGroupFinder.toc`, 10 Lua files (Core, Preview, GearScore, Messages, Listings, UI/Widgets, UI/Table, UI/MainFrame, UI/InPlace, UI/Listing), and `TerribleGroupFinder/Media/Textures/tgf_icon_64x64.tga`. (package.ps1 prints `$files.Count + 1` which counts the TOC twice-ish: TOC line is not in `$files` so the "+ 1" is the TOC; expect "Packaged 12 files".) No `.ase`, no `.png`, no `Media/Source`.

### release.yml (D-12)
Current env block has `GITHUB_OAUTH` and two commented lines. Uncomment the two lines in place (`CF_API_KEY`, `WAGO_API_TOKEN`) and drop the "Uncomment these when API keys are available" comment. `.yml` is LF. The `-n "{package-name}-{project-version}"` arg stays.

## Common Pitfalls

### Pitfall 1: palette PNG
**What goes wrong:** A decoder written for colour types 2/6 (as written in D-14) throws on `baseicon.png` (type 3), or silently reads indices as RGB.
**How to avoid:** implement type 3 + `tRNS`; verify by decoding and comparing alpha/transparent pixel count against the PNG (e.g. corner pixel alpha, number of pixels with alpha 0).
**Warning signs:** converter output of ~12 KB instead of 16402 bytes, or an all-opaque icon.

### Pitfall 2: untracked texture not released
**What goes wrong:** deploy works (install.ps1 copies the file) but the tagged release lacks the icon since the packager ignores untracked files.
**How to avoid:** `git add` the TGA in the same commit as the TOC `IconTexture`; keep install.ps1's warning.

### Pitfall 3: CRLF
`.lua`, `.toc`, `.bat`, `.ps1` are CRLF in the worktree; `stylua.toml` has `line_endings = "Windows"`. Run `stylua .` from the repo root after Lua edits. Run `stylua --check .` before to see the baseline (not run in this research). Edits to `.pkgmeta` / `release.yml` are LF.

### Pitfall 4: nil header / row fields after dropping the column
`self.header.gs`, `row.gs`, `cells.gs`, `self.myGS` become nil. Every use must be guarded: Table.lua 522-523, 615-616, 697-698, 744-753, 799-806 (see inventory). `W.Tooltip(nil, ...)` or `nil:SetText` errors only at runtime in game/preview - this is exactly what the smoke harness catches because it builds the table.

### Pitfall 5: saved-variable compatibility
- `TerribleGroupFinderDB.gs` must remain untouched (D-04). Do not add it to `DEFAULTS`.
- `messages.request.text` migration: compare to the exact old default (copy the string byte-for-byte from the current line 16 before editing it). The user's `messages.invite` is unaffected. `auto` flags untouched.
- No schema bump needed (`DEFAULTS.schema = 1`, not read elsewhere in the paths touched).

### Pitfall 6: ns.Short load order
`GearScore.lua` (3rd in TOC) must reference `ns.Short` only at call time or as a local alias evaluated after Core.lua ran; Core.lua is first, so `local Short = ns.Short` at the top of GearScore.lua is safe.

### Pitfall 7: README mentions GS
`README.md` lines 7 and 12 still advertise gear score sorting and remembered scores. CONTEXT says no README/CHANGELOG edits in this phase; record it as input for the Phase 5 Release Review (do not edit now; CLAUDE.md: never rewrite CHANGELOG, agents do not add entries mid-milestone).

## Code Examples

### Switch + helper in Core.lua
```lua
-- Gear score is switched off for v0.1. Flip to true to bring back the GS column, "Your GS",
-- tooltip lines, the {gs} message key and ready-check inspects. Design notes:
-- .planning/research/GEARSCORE.md
ns.GEAR_SCORE = false

--- A character name without its realm suffix.
function ns.Short(name)
	return name and (name:match("^([^%-]+)") or name)
end
```

### GS.Init early return (GearScore.lua)
```lua
local frame

--- Called once the saved variables are loaded.
function GS.Init(db)
	if not ns.GEAR_SCORE then
		return
	end
	db.gs = db.gs or {}
	cache = db.gs
	-- ... prune as before ...
	frame = CreateFrame("Frame")
	frame:SetScript("OnEvent", function(_, event, arg) --[[ unchanged body ]] end)
	if C_Timer and NotifyInspect then
		frame:RegisterEvent("INSPECT_READY") -- plus the other three, unchanged
	end
end
```

### Column filter (Table.lua)
```lua
local LEFT = {
	{ key = "name", label = "Name", x = 4, w = 150 },
	{ key = "level", label = "Lvl", x = 156, w = 30, justify = "CENTER" },
	{ key = "role", label = "Roles", x = 190, w = 76 },
}
if ns.GEAR_SCORE then
	LEFT[#LEFT + 1] = { key = "gs", label = "GS", x = 268, w = 44, justify = "CENTER" }
end
local ACTIVITY_X = ns.GEAR_SCORE and 318 or 268
local CELL_KEYS = {}
for _, col in ipairs(LEFT) do CELL_KEYS[#CELL_KEYS + 1] = col.key end
CELL_KEYS[#CELL_KEYS + 1] = "activity"
CELL_KEYS[#CELL_KEYS + 1] = "listed"
-- use CELL_KEYS in MakeRow's cell loop and in the header loop
```

### Format without gs (Messages.lua)
```lua
local values = { name = ..., activity = ..., role = ..., class = ..., level = ... }
if ns.GEAR_SCORE then
	values.gs = MyGS()
end
return ((text or db[kind].text):gsub("{(%a+)}", function(key)
	return values[key] -- nil leaves an unknown {key} as typed
end))
```

### TGA header (node)
```js
const hdr = Buffer.alloc(18);
hdr[2] = 2; hdr.writeUInt16LE(w, 12); hdr.writeUInt16LE(h, 14); hdr[16] = 32; hdr[17] = 0x28;
const px = Buffer.alloc(w * h * 4);
for (let i = 0; i < w * h; i++) { px[i*4] = rgba[i*4+2]; px[i*4+1] = rgba[i*4+1]; px[i*4+2] = rgba[i*4]; px[i*4+3] = rgba[i*4+3]; }
fs.writeFileSync(out, Buffer.concat([hdr, px]));
```

## GEARSCORE.md content (GS-02)

New file `.planning/research/GEARSCORE.md` (Write tool; never shell redirect). Content sources, all in the repo: formula, slot weights (`SLOTS` table: slots 1,2,3,5..15 per GearScore weights, 16/17 = 1, 18 = 0.3164; two-hander takes both hands; shirt and tabard excluded; empty slot counts 0), `QUALITY` factors `[0]=.5,[1]=.7,[2]=.85,[3]=.93,[4]=1,[5]=1.1,[6]=1.1,[7]=.93`, average over total weight; cache `DB.gs` name -> `{gs, level, at}` with 60-day expiry; fresh vs outdated per session, outdated colour `|cffb08d57` (`W.GS_OUTDATED`); colour tiers in `W.GS` (share = gs / (level+5): >=1.05 epic purple, >=0.95 blue, >=0.8 green, else white); inspect queue (INSPECT_GAP 1.5 s, INSPECT_WAIT 4 s, ITEM_RETRIES 3 a second apart, not in combat, not while InspectFrame shown, ready check trigger); group column = best known GS; sharing idea (`DESIGN-NOTES.md` lines 59-60: versioned one-line addon whisper <= 255 bytes within the send queue); "to verify in game" items (DESIGN-NOTES line 55); and a "How to re-enable" section: set `ns.GEAR_SCORE = true` in Core.lua, nothing else (plus README/CHANGELOG are separate). The ROADMAP backlog item 999.1 already exists (ROADMAP.md lines 95-98), so GS-02's second half needs no new item; verify it still reads "finish or drop".

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| `CF_API_KEY` env | `CF_API_TOKEN` | packager marks old name deprecated | Locked D-12 still works; optional rename |
| `GITHUB_OAUTH` | `GH_API_TOKEN` | same | still works |

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | WoW loads uncompressed 32-bit TGA with descriptor 0x28 (top-left origin) for addon icons | Icon / TGA writer | Icon blank or flipped in game; mitigation: bottom-up 0x08 with row flip |
| A2 | `* text=auto` already treats `.ase` as binary; adding `*.ase binary` is harmless | Files | Corrupt `.ase` if misdetected (low) |
| A3 | fengari package name/legitimacy (slopcheck unavailable) | Standard Stack | Scratchpad-only; nil repo risk |
| A4 | CurseForge/Wago accept the `forever` game type for upload | Packaging / Open Questions | Release upload step fails after packaging; not testable offline |

## Open Questions

1. **CurseForge/Wago upload for game type `forever`**
   - What we know: packager maps `16???` to `forever`; the sister addon already lists `16001` alongside retail and has project IDs.
   - Unclear: whether the CF project at 1798577 has a Forever game version registered, so the upload could be rejected on the first tag.
   - Recommendation: planner notes it as a first-release watch item for Phase 5; not a Phase 1 blocker.
2. **`CF_API_KEY` vs `CF_API_TOKEN`**
   - D-12 locks `CF_API_KEY`; it is deprecated but accepted. Recommendation: implement as locked; mention in summary.
3. **Migration scope (D-10)** - apply only when the switch is off or always? Recommendation: only when off, so flipping the switch on later does not strand an old default.

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| node | png2tga.js, harness | yes | v24.14.0 | - |
| stylua | `stylua .` | yes | 2.3.1 | - |
| PowerShell + git | install/package scripts | yes | - | - |
| WoW Forever client (`_forever_`) | `install.bat` target | not probed | - | `install.ps1` exits 1 with a message if absent; use `package.bat` and inspect the zip |
| python / slopcheck | package audit | no | - | all external packages tagged [ASSUMED] (only fengari, scratchpad) |
| ImageMagick / BLP converter | n/a | no (by design) | - | node script |
| fengari | harness | yes (scratchpad) | 0.1.5 | - |

**Missing with no fallback:** none.

## Validation Architecture

> `.planning/config.json` has `workflow.nyquist_validation: false`; this section is included at the orchestrator's explicit request.

### Test Framework
| Property | Value |
|----------|-------|
| Framework | none in repo; scratchpad fengari 0.1.5 harness (Lua 5.3 VM in node) |
| Config file | none - harness lives in `C:\Users\jonat\AppData\Local\Temp\claude\3a677a53f55271b6\8039163f-18e8-4930-88a2-d8efcca63b25\scratchpad\smoke\` (`run.js`, `harness.lua`) |
| Quick run command | `node run.js "C:/Users/jonat/Repositories/TerribleGroupFinder"` from the smoke dir (exits 0 pass / 1 fail) |
| Full suite command | harness + `stylua --check .` + `scripts\package.bat` zip listing + TGA readback script |

The prototype exists and runs (see next section). It prints per-file `frames+N events+N` and PASS/FAIL lines.

### Phase Requirements to Test Map
| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| GS-01 | `ns.GEAR_SCORE == false`; GearScore.lua load creates 0 frames; no GS events (INSPECT_READY, READY_CHECK, PLAYER_EQUIPMENT_CHANGED, PLAYER_ENTERING_WORLD) after ADDON_LOADED; `NotifyInspect` never called | smoke | `node run.js <repo>` | prototype yes (red baseline today) |
| GS-01 | no UI text containing `GS` / `gear score` / `{gs}` after `/tgf` builds the table; `Table.instances[1].header.gs == nil` and `myGS == nil`; `TOKENS`/default request free of GS | smoke | same | prototype covers text scan, TOKENS, default; add header/myGS asserts |
| GS-01 | saved `request` text equal to old default migrates; other text with `{gs}` stays; `db.gs` entry untouched after init | smoke | seed `TerribleGroupFinderDB` before firing ADDON_LOADED | add |
| GS-01 | `M.Format("request", nil)` has no `GS` and keeps typed `{gs}` literal | smoke | call from harness | add |
| GS-02 | `.planning/research/GEARSCORE.md` exists with the locked constants; ROADMAP 999.1 present | grep | `grep -c "0.3164\|b08d57\|INSPECT_GAP" GEARSCORE.md` | after phase |
| REL-01 | TOC contains both IDs; workflow has both env lines uncommented | grep | `grep -E "X-Curse-Project-ID: 1798577\|X-Wago-ID: Q6aqvA6W" *.toc`; `grep -E "^\s+(CF_API_KEY\|WAGO_API_TOKEN):" .github/workflows/release.yml` | after phase |
| REL-02 | `Media/Source/baseicon.{ase,png}` tracked; TGA is 16402 bytes, header bytes `[2]=2,[16]=32,[17]=0x28`, w=h=64, pixels equal decoded PNG | script | node readback script (decode TGA, compare with decoded PNG RGBA) | create alongside png2tga.js verification |
| REL-03 | `package.bat` zip has exactly the 12 expected entries; `install.ps1` file list shows TOC + 10 Lua + TGA and no Media/Source; IconTexture of a bogus name errors | script | `.\scripts\package.bat`; list entries | scripts exist |

### Stub layer: what the TOC files touch (derived from grep of all sources)
- **Frames:** `CreateFrame` (33 call sites, many templates: `SearchBoxTemplate`, `UIPanelButtonTemplate`, check buttons, `BackdropTemplate`, ...); widget methods used: `SetPoint/ClearAllPoints/SetAllPoints/SetSize/SetWidth/SetHeight/GetWidth/GetHeight/Show/Hide/IsShown/IsVisible/SetScript/GetScript/HookScript/RegisterEvent/UnregisterEvent/SetText/GetText/SetChecked/GetChecked/SetEnabled/EnableMouse/SetFrameLevel/GetFrameLevel/CreateTexture/CreateFontString/SetTexture/SetColorTexture/SetAtlas/SetNormalTexture/GetNormalTexture/SetFont/GetFont/SetJustifyH/SetWordWrap/SetMaxLetters/SetCursorPosition/GetParent`. The prototype uses an `__index` fallback that returns a chainable no-op for methods whose names start with Set/Get/Is/Enable/Disable/Clear/Register/Hook/Create/Add/Show/Hide/Update/... and returns `nil` for capitalised *fields* (`.Text`, `.Label`, `.Instructions`, ...). Fields must be nil, not functions, or `if c.Text then c.Text:SetText` style code breaks (this was hit and fixed during prototyping).
- **Fonts/objects:** `GameFontNormal/Highlight/HighlightSmall/DisableSmall/NormalSmall/Disable/NormalLarge`, `UIParent`, `GameTooltip`, `LFGParentFrame`/`LFGBrowseFrame` (absent = preview mode via `ns.Listings.HasAPI()` false).
- **Functions:** `hooksecurefunc`, `SlashCmdList`, `C_Timer.After` (queue and flush manually), `time/date/GetTime`, `UnitName/UnitLevel/UnitClass/UnitExists/UnitGUID/UnitIsUnit/UnitIsConnected/UnitIsGroupLeader/UnitIsGroupAssistant/UnitGroupRolesAssigned`, `IsInGroup/IsInRaid/GetNumGroupMembers/GetNumSubgroupMembers`, `InCombatLockdown`, `issecretvalue`, `PlaySound`, `GetInventoryItemLink`, `C_AddOns.GetAddOnMetadata/IsAddOnLoaded`, `C_PartyInfo.InviteUnit`, `C_ChatInfo.SendChatMessage/InChatMessagingLockdown`, `C_RecentAllies`, `C_Texture.GetAtlasInfo`, `C_Item`, `C_LFGList` and `C_LFGListRoles` (leave nil for preview), `ChatFrameUtil`, `NotifyInspect` (stub that records calls).
- **Record in stubs:** every `RegisterEvent` (frame, event), every `SetText` string, frame count per file. These three give the GS-01 assertions.

### Lua 5.1 vs fengari (5.3) differences that matter
- `unpack` is `table.unpack` in 5.3 (alias in harness); `table.getn`, `loadstring`, `setfenv` absent (alias/avoid; no source file uses getn/loadstring/setfenv; none uses `unpack` either - grep clean).
- `tostring(3.0)` is `"3.0"` in 5.3, `"3"` in 5.1; `/` always returns a float; `math.floor` returns an integer; `string.format("%d", 3.5)` errors in 5.3 (it truncated in 5.1). Relevant only if a text assertion compares numbers (`"%d/%d members"` is fed integers; `"%.1f"` is unaffected).
- `string.gsub` returns (string, count) in both; the code already wraps it in extra parentheses. `#` on tables with holes and `table.sort` comparator strictness ("invalid order function") may differ; the sort comparators are the likely place for a harness-only error if a comparator is inconsistent.
- `string.find`/`match` with `%f`, `%b` fine in both. Strings are byte strings; read files as latin1 (done) to keep UTF-8 bytes intact.
- Not representable: secret values (`issecretvalue` stubbed false), real layout (widths are stored, never computed), taint. The harness proves "no nil index / no GS text / no events", not visual correctness - the in-game check remains the author's job.

### Sampling Rate
- **Per task commit:** harness quick run (seconds)
- **Per wave merge:** harness + `stylua --check .` + package listing
- **Phase gate:** all of the above plus a manual in-game look at the Browse table, Messages tab and AddOn-list icon after `./scripts/install.bat` and `/reload`

### Wave 0 Gaps
- [ ] Extend `harness.lua` with: header/`myGS` nil asserts, saved-variable seeding (old default request text, `db.gs` sample), `M.Format` literal-`{gs}` check, frame-count-per-file assert for GearScore.lua (currently prints `frames+1`; expected `frames+0` after the change)
- [ ] `tgacheck.js` readback script (scratchpad): decode PNG with the same `decodePng` and compare to the TGA
- [ ] Optionally a `--gs` run mode (flip `ns.GEAR_SCORE = true` through a pre-load hook) to prove the switch re-enables the column and events; the prototype accepts `--gs` but does not yet apply it

## Security Domain

| ASVS Category | Applies | Standard Control |
|---------------|---------|------------------|
| V2/V3/V4 | no | local addon, no auth/session/access control |
| V5 Input Validation | yes (small) | the converter validates PNG signature, bit depth, interlace, colour type and throws; Messages `Format` keeps unknown keys literal |
| V6 Cryptography | no | none |
| Supply chain | yes | no new repo dependencies; secrets are GitHub Actions secrets referenced by name only (`CF_API_KEY`, `WAGO_API_TOKEN`), never committed |

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| Malformed PNG to converter | Tampering/DoS | strict header checks, bounded by 64x64 input; script is dev-only (`tools/`, not shipped) |
| Secret exposure in workflow | Information disclosure | only `${{ secrets.* }}` references; no echo of env |
| Taint of Blizzard frames | Tampering | CLAUDE.md rules; the GS edits add no writes to Blizzard frames |

## Sources

### Primary (HIGH confidence)
- Repository sources read in this session: `Core.lua`, `GearScore.lua`, `Messages.lua`, `Listings.lua`, `UI/Table.lua`, `UI/Widgets.lua`, `UI/InPlace.lua`, `UI/MainFrame.lua`, `scripts/*`, `.pkgmeta`, `.gitattributes`, `.github/workflows/release.yml`, `TerribleGroupFinder.toc`
- Sister addon `C:\Users\jonat\Repositories\TerribleBuffTracker`: `.pkgmeta`, TOC, `Media/` layout (read-only)
- BigWigs packager `release.sh` (raw.githubusercontent.com/BigWigsMods/packager/master/release.sh): env tokens, TOC fields, ignore handling, forever game type, untracked-file auto-ignore
- Node IHDR/chunk read of `baseicon.png`; fengari prototype run against the repo

### Secondary (MEDIUM confidence)
- BigWigs packager README (github.com/BigWigsMods/packager) - documents `X-Curse-Project-ID`, `X-Wago-ID`, `CF_API_TOKEN`, `WAGO_API_TOKEN`, `GH_API_TOKEN`

### Tertiary (LOW confidence)
- WoW TGA acceptance details (descriptor flag) - training knowledge, tagged [ASSUMED]

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH - no new libraries; tooling confirmed installed
- Architecture / GS inventory: HIGH - grep plus reading every site
- Packaging: HIGH - packager source read; MEDIUM on CurseForge accepting the `forever` type
- TGA details: MEDIUM - format is standard; WoW-specific acceptance assumed
- Harness: MEDIUM-HIGH - prototyped and running; fidelity limited to what stubs model

**Research date:** 2026-11-11
**Valid until:** 2026-12-11 (stable; the packager is the only moving part)
