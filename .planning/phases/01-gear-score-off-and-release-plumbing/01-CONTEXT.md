# Phase 1: Gear Score Off and Release Plumbing - Context

**Gathered:** 2026-11-11
**Status:** Ready for planning
**Mode:** `--auto` (author AFK; every grey area resolved with the recommended option, logged below)

<domain>
## Phase Boundary

Two independent strands, both small:

1. **Gear score off (GS-01, GS-02).** Nothing gear-score related shows or runs for the player:
   no GS column, no "Your GS" band text, no GS line in tooltips, no `{gs}` key in the Messages
   tab or rendered messages, no ready-check inspects, no events registered by `GearScore.lua`.
   The code stays in the repo behind ONE disabled switch. The design notes move to
   `.planning/research/GEARSCORE.md`. The backlog item 999.1 ("finish or drop") already exists
   in ROADMAP.md.
2. **Release plumbing (REL-01, REL-02, REL-03).** TOC store IDs, release workflow keys, the
   addon icon (sources under `Media/Source/`, in-game texture under `Media/Textures/`, TOC
   `IconTexture`), and packaging / install shipping only addon files plus the in-game texture.

Not in this phase: any other table / layout change (the freed GS width is redistributed
properly in Phase 2, UIP-04), new message presets (Phase 4), README / CHANGELOG edits.

</domain>

<decisions>
## Implementation Decisions

### Gear score switch
- **D-01:** One switch, `ns.GEAR_SCORE = false`, defined in `Core.lua` (loaded first, so every
  file sees it). A short comment there points to `.planning/research/GEARSCORE.md` for how to
  re-enable. No other flag, no saved-variable or slash-command toggle.
- **D-02:** `GearScore.lua` stays in the TOC load list (so flipping the one switch re-enables
  everything), but with the switch off it registers no events and creates no event frame at
  load: frame creation and event registration move inside `GS.Init`, which returns at once
  when `ns.GEAR_SCORE` is false. `GS.ScanGroup`, `StoreSelf` and the inspect queue are then
  unreachable.
- **D-03:** The name helper `GS.Short` (strip realm suffix) is not gear-score logic; it moves to
  `Core.lua` as `ns.Short` (GearScore.lua keeps a local alias / uses `ns.Short`). `Listings.lua`
  calls `ns.Short`. Nothing outside GearScore.lua references `ns.GS` when the switch is off.
- **D-04:** The saved cache `TerribleGroupFinderDB.gs` is left untouched while off (not read, not
  pruned, not wiped), so re-enabling keeps old scores.

### Table and preview with GS off
- **D-05:** The `gs` column is dropped from the column set when the switch is off (built from
  the column list filtered by the switch), together with its header, its sort key and the
  default-desc entry. Minimal shift: the columns right of GS move left by the GS width so no
  gap is left; the flexible Activity column absorbs the space. Phase 2 (UIP-04) owns the real
  re-layout.
- **D-06:** The "Your GS" text in the table's top band and its hover tooltip are not created when
  the switch is off. The `GS` line in the row tooltip is skipped.
- **D-07:** `ns.Me()` does not set `gs` when the switch is off (no `ns.GS.Mine()` call, no
  preview fake value).
- **D-08:** Preview sample data keeps its `gs` fields (inert data, `Preview.lua` untouched apart
  from what is needed); nothing displays them while off.

### Messages with GS off
- **D-09:** `{gs}` is removed from the key list shown in the Messages tab and from the values
  `M.Format` fills while off. The default request preset drops `, GS {gs}`:
  `Hi {name}! Level {level} {class} here ({role}), could I join you for {activity}?`
  (Phase 4 replaces the presets entirely; this is only the minimal GS removal.)
- **D-10:** A saved request preset exactly equal to the old GS default is reset to the new
  default in `M.Init` (one-line migration so the author's own saved text does not keep `{gs}`).
  Any other user-typed `{gs}` stays literal (unknown keys are left as typed).

### Store IDs and release workflow
- **D-11:** TOC gains `## X-Curse-Project-ID: 1798577` and `## X-Wago-ID: Q6aqvA6W`.
- **D-12:** `.github/workflows/release.yml` env enables `CF_API_KEY: ${{ secrets.CF_API_KEY }}`
  and `WAGO_API_TOKEN: ${{ secrets.WAGO_API_TOKEN }}` (uncommented; the author adds the secrets).

### Icon
- **D-13:** `baseicon.ase` and `baseicon.png` move (git mv after `git add`) to
  `Media/Source/baseicon.ase` and `Media/Source/baseicon.png`, mirroring TerribleBuffTracker's
  `Media/Source` + `Media/Textures` layout.
- **D-14:** In-game texture: `Media/Textures/tgf_icon_64x64.tga`, an uncompressed 32-bit
  (BGRA, 8-bit alpha, top-left origin flag set) TGA converted from the 64x64 PNG with a small
  node script (no BLP converter or ImageMagick on the machine; `C:\WINDOWS\system32\convert` is
  the Windows disk tool, never call it). The converter script lives in `tools/` only if it is
  small and dependency-free (node built-ins: `zlib` for PNG inflate); otherwise in the
  scratchpad. Recommended: `tools/png2tga.js` (tools/ is already ignored by `.pkgmeta` and not
  in the TOC, so it never ships).
- **D-15:** TOC line `## IconTexture: Interface\AddOns\TerribleGroupFinder\Media\Textures\tgf_icon_64x64`
  (no extension).

### Packaging
- **D-16:** `.pkgmeta` ignore gains `Media/Source`, `"*.ase"`, `dist` and `.release`
  (alongside the existing `"*.png"`, `tools`, `scripts`, `.planning`, ...).
- **D-17:** `scripts/install.ps1`'s IconTexture lookup only searches the repo root by leaf name;
  it is fixed to resolve the TOC path relative to the addon folder (strip
  `Interface\AddOns\TerribleGroupFinder\`) and add that file, erroring if the IconTexture
  names a file that does not exist as .blp/.tga. `scripts/package.ps1` scans all of `Media/`
  for .blp/.tga; it is narrowed to `Media/Textures` like install.ps1 so a stray texture in
  `Media/Source` can never ship. Both outputs must contain only the TOC, the Lua load list and
  the texture.

### Claude's Discretion
- Exact placement of the switch comment, whether GearScore.lua's `Short` becomes a local alias
  of `ns.Short`, the PNG decoder details (filter types 0-4, colour types 2/6, bit depth 8; fail
  loudly otherwise), and the precise column-shift arithmetic in `UI/Table.lua`.
- Verification: a fengari smoke harness in the session scratchpad (`scratchpad/smoke/`) loads
  the TOC files with WoW API stubs, fires ADDON_LOADED, runs preview mode and builds the table,
  asserting no GS column / band / tooltip line / `{gs}` key and no event registration by the GS
  frame. Plus `scripts/package.bat` zip listing and `scripts/install.bat`.

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Phase scope
- `.planning/ROADMAP.md` — Phase 1 goal and success criteria; backlog 999.1
- `.planning/REQUIREMENTS.md` — GS-01, GS-02, REL-01, REL-02, REL-03
- `CLAUDE.md` — project rules (taint, Forever-only, stylua, no sed on .md / .planning)

### Gear score design (source for GEARSCORE.md)
- `GearScore.lua` — formula, slot weights, quality factors, cache, inspect queue constants
- `.planning/research/DESIGN-NOTES.md` — "Gear score" design bullet, "To verify in game", and
  "Ideas for later" (sharing scores by addon whisper)
- `UI/Widgets.lua` — `W.GS` colouring and `W.GS_OUTDATED` (`|cffb08d57`) for outdated scores
- `UI/Table.lua` — GS column, `ListingGS` (group shows best known), `GSLine` tooltip, "Your GS" band

### Packaging / icon conventions
- `TerribleGroupFinder.toc`, `.pkgmeta`, `scripts/install.ps1`, `scripts/package.ps1`,
  `.github/workflows/release.yml`
- `C:\Users\jonat\Repositories\TerribleBuffTracker\.pkgmeta` and its `Media/Source`,
  `Media/Textures` folders (read-only sister addon) — layout to mirror

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `ns.GS.Short` (GearScore.lua) — realm-suffix stripper used by `Listings.lua`; becomes `ns.Short`.
- install.ps1 / package.ps1 already derive the file set from the TOC and add `.blp`/`.tga`
  textures under `Media` — only the scope and the IconTexture lookup need tightening.

### Established Patterns
- Files share the addon namespace `ns`; `Core.lua` loads first and owns `ns.state`, `ns.Me()`,
  saved-variable init (`GS.Init(ns.db)` is called from Core's ADDON_LOADED handler).
- Table columns are a static list `COLS` with x/w; sort keys in a table keyed by column key;
  `FIRST_DESC` lists columns sorted descending first.

### Integration Points
- `Core.lua` lines ~95-97 (`me.gs`), ~242 (`ns.GS.Init`).
- `Messages.lua` `DEFAULTS.request`, `TOKENS`, `MyGS`, `Format`.
- `UI/Table.lua` `COLS` (gs at x=268, w=44), sort map `gs`, `GSLine`/tooltip, row `gs` cell,
  `myGS` band text + hover, column header loop.
- `Listings.lua` lines ~56, ~81 (`ns.GS.Short`).

</code_context>

<specifics>
## Specific Ideas

- Author-locked: keep GearScore.lua behind a single disabled switch; GEARSCORE.md must preserve
  formula (GearScore public slot weights x quality factor x item level averaged over 17 slots),
  quality factors `[0]=.5,[1]=.7,[2]=.85,[3]=.93,[4]=1,[5]=1.1,[6]=1.1,[7]=.93`, cache
  `DB.gs` name -> gs, level, time with 60-day expiry, outdated colour `|cffb08d57` for scores
  from an earlier session, inspect queue (INSPECT_GAP 1.5 s, WAIT 4 s, 3 item retries, not in
  combat / InspectFrame open), ready-check trigger, group column shows best known GS, sharing
  by addon whisper idea, and how to re-enable.
- Author-locked: CurseForge 1798577, Wago Q6aqvA6W; .ase must never ship.

</specifics>

<deferred>
## Deferred Ideas

- Proper redistribution of the freed GS width to Roles / Activity — Phase 2 (UIP-04).
- New default presets and key buttons — Phase 4 (MSG-01..04).
- Finishing or dropping gear score — backlog 999.1.
- BLP instead of TGA for the icon — only if a converter becomes available; TGA is fine in game.

</deferred>

---

*Phase: 01-gear-score-off-and-release-plumbing*
*Context gathered: 2026-11-11*
