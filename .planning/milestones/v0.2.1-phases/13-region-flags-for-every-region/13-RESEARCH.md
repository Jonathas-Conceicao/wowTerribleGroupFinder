# Phase 13: Region Flags for Every Region - Research

**Researched:** 2026-11-16
**Domain:** WoW addon Lua (name-cell icon in `UI/Table.lua`, shard parsing in `Region.lua`) + a dev-only Node PNG→TGA converter
**Confidence:** HIGH (everything below was read from the repo or measured from the author's PNGs this session; nothing depends on outside libraries)

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

#### Flag art (REG-05, REG-08) — author decisions
- Source: the author's PNGs from flagpedia.net, now untracked in the repo root: `flag_au.png` 40x20, `flag_us.png` 40x21, `flag_cn.png` / `flag_eu.png` / `flag_kr.png` / `flag_tw.png` 40x27 (all 8-bit palette PNGs). NO art is generated or redrawn; converting the author's images is allowed
- Move the PNGs to `Media/Source/flags/` (not shipped; `Media/Source/` is outside the TOC file set) and record the source in an internal note `Media/Source/flags/SOURCE.md` ("Flags from flagpedia.net (flagcdn.com), w40 PNGs, public domain; supplied by the author 2026-11-16") and in CLAUDE.md's Region / Media lines. Nothing in README.md
- Conversion: a dev-only Node script `Media/Source/png2tga.js` (no npm deps: decode PNG with zlib, handle palette + tRNS) writes `Media/Textures/flag_<cc>.tga` for each PNG: 32-bit uncompressed TGA, top-left origin, a 64x32 power-of-two canvas with the flag copied 1:1 at the top-left and the rest transparent. It only converts pixels the author supplied; it draws nothing
- Delete `Media/Source/flags.js` (the generator); the old `flag_us.tga` / `flag_au.tga` are overwritten by the converted ones (same file names, so the install/package scripts and paths keep working)
- Drawn at one height on rows: 10 px (as today), width from each flag's aspect: US 19x10, AU 20x10, CN / EU / KR / TW 15x10 (rounded from 40/H*10); tex coords {0, 40/64, 0, H/32} per flag

#### Region rule (REG-06, REG-07) — author decisions
- Shard name parsing: the text between `CAMWOW` and `Realm` in the shard name, trimmed, spacing kept (`CAMWOW US2 Realm 8 PvP` → `US2`; `CAMWOW EU Paris Realm 3 PvE` → `EU Paris`); names not starting with `CAMWOW` stay unknown (no region)
- Flag when the group, spaces removed and upper-cased, matches two letters plus an optional number (`AU`, `EU`, `EU1`..`EU9`, `US2`, `KR1`; `%d*` so a two-digit number works too) AND `FLAG_ART` has its first two letters: `US, AU, EU, CN, KR, TW`
- Otherwise (any other text, or a country with no art such as `BR1`): a text tag on the row, the group's first two letters upper-cased (e.g. `EU`), drawn in the flag's slot as a small FontString in the row's grey/name colour, same gap rules and drop order as the flag (flag last)
- Tooltip: the row tooltip's line keeps "Region: <full text>" / "Leader's region: <full text>"; the flag / text-tag hover tooltip (row icon tooltips, Phase 8) shows the same full text
- Seeded `KNOWN` IDs stay (US1, US2, AU1); learned groups keep working; the saved-shard sanitizer (`Sane`) accepts the new free text (a non-empty string up to 32 chars, printable) instead of only `^%u%u%d*$`

#### Preview (testability) — Claude's pick
- `/tgf preview` shows every case so the author can see them without other regions' players: sample listings get shards for EU1, KR1, CN, TW1 and one odd name (`EU Paris`) via preview-only learned groups (never saved to `DB.shards`)

### Claude's Discretion
- Whether the text tag is a FontString per row icon slot or reuses an existing helper; exact font object (a small game font such as GameFontNormalSmall / GameFontHighlightSmall)
- Smoke-harness updates in the session scratchpad

### Deferred Ideas (OUT OF SCOPE)
- Seeding EU / Asia shard IDs once players send `/tgf region` output
- README wording for region flags (Release Review, author-directed)
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| REG-05 | Flags for US, AU, EU, CN, KR, TW from the author's PNGs, one height, each flag's own width, converted (no art generated) | PNG chunk audit + verified converter prototype (§PNG→TGA); per-flag sizes / coords table; `FLAG_ART` reshape in `Region.lua:29` |
| REG-06 | Two letters + optional number with a flag → flag; tooltip names the full group | New `R.Group` parser and `R.Of` flag rule (§Region rule); tooltip lines already print `place.label` (`Region.lua:139`, `UI/Table.lua:573,613`) |
| REG-07 | Any other text → first two letters as text on the row, full text in tooltip | Text-tag FontString in the flag slot (§Table touch points); `R.Flag` returns `text` instead of `file` |
| REG-08 | `flags.js` and its generated textures removed; internal note names flagpedia.net, not README | `git rm Media/Source/flags.js`; old TGAs overwritten in place; `Media/Source/flags/SOURCE.md`; CLAUDE.md lines 29 and the Media line |
</phase_requirements>

## Project Constraints (from CLAUDE.md)

- Taint: only our own frames/textures/font strings on rows; nothing of Blizzard's is written. This phase touches only our own row widgets and our own data, so no taint surface changes.
- Guard secret values with `issecretvalue()` (already in `Plain()` in `Region.lua:35`); realm names from `GetRealmName` / BN friend info pass through `R.Group`, which must keep that guard.
- Native look: Blizzard fonts (`GameFontNormalSmall` / `GameFontDisableSmall`), no custom skin.
- Run `stylua .` from the repo root after each task (stylua is installed: `~/.cargo/bin/stylua`).
- Never `sed -i` / shell redirects on `.md` files or anything in `.planning/` — use Edit/Write.
- Never touch `CHANGELOG.md`; README untouched (deferred to Release Review).
- NO generated art: the converter copies the author's pixels only.
- A bug introduced and fixed inside the milestone is never mentioned outside `.planning/`.
- Deploy: `./scripts/install.bat`, `/reload`.
- Memory note: flag a README screenshot reminder (the row icons change look) at the end; the author retakes prints.

## Summary

The phase is small and fully local. Three pieces: (1) a dependency-free Node converter turns the author's six palette PNGs into 64x32 32-bit TGAs in the exact header format the current textures use; (2) `Region.lua` changes its shard-name parser from a strict `%a%a%d*` match to "text between CAMWOW and Realm", decides flag vs. text tag, and loosens `Sane`; (3) `UI/Table.lua` gains a FontString in the flag's icon slot so a text tag takes part in the existing width-fitting / drop-order loop.

The PNG audit found one surprise: `flag_us.png` is **4-bit** palette (bit depth 4, 15 colours), not 8-bit as CONTEXT says; the other five are 8-bit. None has a `tRNS` chunk (all fully opaque), none is interlaced, and every scanline uses filter 0. The converter must still unpack sub-byte depths (1/2/4) and should implement filters 1-4 and tRNS anyway so a re-exported PNG doesn't silently break it. A prototype of exactly that (in the scratchpad) decoded all six correctly and produced 8210-byte TGAs (18-byte header + 64·32·4).

The tooltip side needs no change: both the row tooltip (`Table.lua:573`) and the flag's icon tooltip (`Table.lua:613`) already print `ns.Region.Line(l)`, which is `"Region: " .. place.label`; once `label` is the free text (`EU Paris`), REG-06/07 tooltips are done. The main Table work is that the icon loop assumes every icon is a Texture (`SetDesaturated`, hit frame `SetAllPoints(tex)` made once at build).

**Primary recommendation:** Two plans in one wave: Plan 01 art pipeline (move PNGs, `png2tga.js`, regenerate 6 TGAs, delete `flags.js`, `SOURCE.md`, `git add` the TGAs); Plan 02 code (Region.lua parser + flag/text decision + preview groups, Table.lua text tag, Preview samples, Settings tooltip text, CLAUDE.md). Plan 02 only depends on the TGA file names, which are fixed, so both can run in parallel; keep the CLAUDE.md edit in Plan 02 only to avoid a conflict.

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| PNG→TGA conversion | Dev tooling (Node, `Media/Source/`) | — | Runs once on the author's machine; never shipped (`.pkgmeta` ignores `Media/Source`, `*.png`) |
| Shard name → group text | `Region.lua` (`R.Group`) | — | Single parser used by `R.Learn` for own realm and BN friends |
| Group → flag or text tag | `Region.lua` (`R.Of`, `R.Flag`) | — | Region owns the rule; Table only draws what `R.Flag` returns |
| Drawing flag / text in the name cell | `UI/Table.lua` (`FillRow`) | `UI/Widgets.lua` (`W.Text`, `W.SetColor`) | Existing icon slot, width fitting, drop order |
| Tooltip text | `Region.lua` (`R.Line`) | `UI/Table.lua` (callers) | Unchanged callers |
| Preview cases | `Preview.lua` (sample shards + preview groups) | `Region.lua` (lookup when `ns.UsingPreview()`) | Preview owns sample data; never written to `DB.shards` |
| Shipping new TGAs | `scripts/install.ps1`, `package.ps1`, BigWigs packager | git | Every `.tga` under `Media/Textures` ships; packager ships only git-tracked files |

## Standard Stack

No external packages. Node built-ins only for the converter.

| Tool | Version | Purpose |
|------|---------|---------|
| Node.js | v24.14.0 (verified locally) | runs `Media/Source/png2tga.js` |
| `zlib` (Node built-in) | — | `inflateSync` on concatenated IDAT |
| `fs`, `path` (Node built-in) | — | I/O |
| stylua | installed (`~/.cargo/bin/stylua`) | Lua formatting after each task |

## Package Legitimacy Audit

No external packages are installed by this phase (Node built-ins only). slopcheck not needed.

**Packages removed due to slopcheck [SLOP] verdict:** none
**Packages flagged as suspicious [SUS]:** none

## PNG audit (measured this session) [VERIFIED: node one-off over the repo-root PNGs]

| File | W x H | Bit depth | Colour type | PLTE entries | tRNS | Interlace | Filters used |
|------|-------|-----------|-------------|--------------|------|-----------|--------------|
| flag_us.png | 40x21 | **4** | 3 (palette) | 15 | none | 0 | all 0 |
| flag_au.png | 40x20 | 8 | 3 | 39 | none | 0 | all 0 |
| flag_cn.png | 40x27 | 8 | 3 | 19 | none | 0 | all 0 |
| flag_eu.png | 40x27 | 8 | 3 | 18 | none | 0 | all 0 |
| flag_kr.png | 40x27 | 8 | 3 | 63 | none | 0 | all 0 |
| flag_tw.png | 40x27 | 8 | 3 | 20 | none | 0 | all 0 |

Chunks present: `IHDR PLTE IDAT IEND` only (single IDAT each; concatenating all IDATs is still the correct general approach).

Current TGAs (`flag_us.tga`, `flag_au.tga`, `tgf_icon_64x64.tga`) header bytes:
`00 00 02 00 00 00 00 00 00 00 00 00 40 00 40 00 20 28`, file size 16402 = 18 + 64·64·4, **no TGA footer, no image ID, no colour map**. The new flags keep everything but the height: `... 40 00 20 00 20 28` (64 x 32), file size 8210.

## PNG→TGA conversion details

Converter: `Media/Source/png2tga.js`, run `node Media/Source/png2tga.js` from the repo root; reads `Media/Source/flags/flag_<cc>.png`, writes `Media/Textures/flag_<cc>.tga`. Throws (non-zero exit) on anything it doesn't support rather than writing a wrong file.

1. **Signature**: first 8 bytes `89 50 4E 47 0D 0A 1A 0A`.
2. **Chunks**: loop `len(u32 BE) type(4) data crc(4)`; collect `IHDR`, `PLTE`, `tRNS`, all `IDAT`; stop at `IEND`. CRC check optional.
3. **IHDR**: width, height (u32 BE), bit depth, colour type, compression (0), filter method (0), interlace. Accept colour type 3 only (all six are palette), bit depths 1/2/4/8, interlace 0; throw otherwise. Also reject width > 64 or height > 32 (the canvas).
4. **Inflate**: `zlib.inflateSync(Buffer.concat(idats))`. Expected length = `h * (1 + stride)` with `stride = ceil(w * bitDepth / 8)` (US: 21·(1+20)=441 ✓; others 40+1 per row ✓).
5. **Unfilter** per scanline, `bpp = 1` (bytes per complete pixel, rounded up to 1 for sub-byte depths — PNG spec rule): filter 0 None, 1 Sub (`a` = left byte), 2 Up (`b` = byte above), 3 Average (`floor((a+b)/2)`), 4 Paeth (`p=a+b-c`, pick nearest of a,b,c with ties a→b→c). Previous line starts as zeros. Work on the filtered bytes, not the expanded pixels.
6. **Unpack indices**: for depth < 8, pixel x's index = `(byte[x*bd>>3] >> (8 - bd - (x*bd & 7))) & ((1<<bd)-1)` (MSB first). Ignore padding bits at the row end.
7. **Palette expansion**: RGB = `PLTE[i*3..i*3+2]`; alpha = `tRNS[i]` when `tRNS` exists and `i < tRNS.length`, else 255. (No file has tRNS today; all pixels end up alpha 255.)
8. **Canvas**: 64x32 BGRA buffer of zeros (transparent black); copy the flag 1:1 at x 0..w-1, y 0..h-1 with byte order **B, G, R, A**.
9. **TGA header** (18 bytes, mirrors `flags.js:30-38`): `[2]=2` (uncompressed true colour), `writeUInt16LE(64, 12)`, `writeUInt16LE(32, 14)`, `[16]=32`, `[17]=0x28` (bit 5 = top-left origin, low nibble 8 = alpha bits). Then the pixel buffer, no footer.

Prototype result (scratchpad only, same algorithm): all six decoded, sizes 8210; sample pixels sane (US bottom stripe `179,26,67`, EU field `0,51,153`, CN `238,28,37`, KR field white). [VERIFIED: prototype run]

## Per-flag draw sizes and tex coords

All at height 10; canvas 64x32; tex coords `{ left, right, top, bottom } = { 0, 40/64, 0, H/32 }`.

| Key | File | Source W x H | Draw W x H | Coords |
|-----|------|--------------|------------|--------|
| US | flag_us | 40x21 | 19 x 10 | `{0, 40/64, 0, 21/32}` |
| AU | flag_au | 40x20 | 20 x 10 | `{0, 40/64, 0, 20/32}` |
| EU | flag_eu | 40x27 | 15 x 10 | `{0, 40/64, 0, 27/32}` |
| CN | flag_cn | 40x27 | 15 x 10 | `{0, 40/64, 0, 27/32}` |
| KR | flag_kr | 40x27 | 15 x 10 | `{0, 40/64, 0, 27/32}` |
| TW | flag_tw | 40x27 | 15 x 10 | `{0, 40/64, 0, 27/32}` |

Recommended shape in `Region.lua` (replacing `FLAG_ART` at line 29):
```lua
-- The flag art each country has: Media/Textures/flag_<file>.tga, the author's flagpedia.net
-- PNG (40 px wide, h tall) at the top-left of a 64x32 canvas; drawn 10 px high.
local FLAG_ART = {
	US = { file = "us", h = 21 },
	AU = { file = "au", h = 20 },
	EU = { file = "eu", h = 27 },
	CN = { file = "cn", h = 27 },
	KR = { file = "kr", h = 27 },
	TW = { file = "tw", h = 27 },
}
-- width = floor(40 / h * 10 + 0.5): 19, 20, 15 ...; coords = { 0, 40 / 64, 0, h / 32 }
```
Computing the width (`floor(400 / h + 0.5)`) gives exactly the locked 19/20/15.

## Region rule (code-level)

### `R.Group(name)` (`Region.lua:49-54`)
Replace the whitespace-stripping match with position search on an upper-cased copy (ASCII `upper` keeps byte length, so positions line up with the original and the group keeps its own case and spacing):
```lua
function R.Group(name)
	if type(name) ~= "string" or not Plain(name) then
		return nil
	end
	local up = name:upper()
	local _, stop = up:find("^%s*CAMWOW")
	local realm = stop and up:find("REALM", stop + 1, true)
	if not realm then
		return nil
	end
	local group = name:sub(stop + 1, realm - 1):match("^%s*(.-)%s*$")
	return Sane(group) and group or nil -- non-empty, ≤ 32 bytes, no control chars or "|"
end
```
`CAMWOW US2 Realm 8 PvP` → `US2`; `CAMWOW EU Paris Realm 3 PvE` → `EU Paris`; `CAMWOWUS2Realm8` → `US2` (old behaviour kept). The first `REALM` after `CAMWOW` ends the group. [ASSUMED: real EU/Asia names follow `CAMWOW <group> Realm …`; flagged in STATE.md blockers]

### Text sanity (shared by `R.Group` and `Sane`)
```lua
local function SaneGroup(g)
	return type(g) == "string" and g ~= "" and #g <= 32 and not g:find("[%c|]")
end
local function Sane(id, group) -- Region.lua:201
	return type(id) == "number" and SaneGroup(group) and not KNOWN[id]
end
```
Rejecting `|` matters: the text goes into `FontString:SetText` and tooltip lines, where `|c`, `|T`, `|H` are escape sequences. `Sane` must be defined above `R.Group` now (it is at line 201 today).

### Flag vs. text tag (`R.Of`, `Region.lua:69-84`)
```lua
local key = group:gsub("%s", ""):upper()
local cc = key:match("^(%a%a)%d*$")
local art = cc and FLAG_ART[cc] or nil
return { flag = art, tag = not art and Tag(group) or nil, label = group, group = group, source = source }
```
`Tag(group)` = the first two characters of the group with spaces removed, upper-cased. Use UTF-8-safe slicing so a non-ASCII first letter isn't cut mid-byte (WoW Lua 5.1 has no `utf8` lib):
```lua
local function Tag(group)
	local s = group:gsub("%s", "")
	local a, rest = s:match("^([%z\1-\127\194-\244][\128-\191]*)(.*)$")
	local b = rest and rest:match("^([%z\1-\127\194-\244][\128-\191]*)") or ""
	return a and (a .. b):upper() or nil
end
```
Cases: `US2`→flag US; `AU`→flag AU; `EU`, `EU1`, `EU12`→flag EU; `BR1`→tag `BR`; `EU Paris`→ key `EUPARIS` fails `%d*$` → tag `EU`; `CN`→flag CN.

### `R.Flag(l)` (`Region.lua:143-158`)
Return either art or text, never nil for a known place (when enabled):
```lua
if place.flag then
	local h = place.flag.h
	return { file = FLAGS .. place.flag.file, coords = { 0, 40 / 64, 0, h / 32 }, width = floor(400 / h + 0.5), height = 10, place = place }
end
return { text = place.tag, place = place }
```

### Preview-only groups
`Preview.lua` loads before `Region.lua` (TOC order) but lookups happen at call time, so `R.Of` can read a preview table:
```lua
if not group and ns.UsingPreview() and ns.Preview and ns.Preview.shardGroups then
	group, source = ns.Preview.shardGroups[id], "preview"
end
```
In `Preview.lua` (near `SHARDS`, line 102-104): `P.shardGroups = { [99101] = "EU1", [99102] = "KR1", [99103] = "CN", [99104] = "TW1", [99105] = "EU Paris" }` and give five chosen main-list samples an explicit `{ shard = 991xx }` extra (as Delas Moonfang has `{ shard = 9999 }` at line 294), so each case shows deterministically rather than via the `nextId` rotation. IDs never touch `learned`/`DB.shards`. Optionally one more `BR1` sample to show "country without art" (text `BR`) — Claude's pick; CONTEXT lists only the five. Update the comment at Preview.lua:102-103.

## Architecture Patterns

### Data flow
```
partyGUID "Party-<id>-…" ─► Listings.lua:207 l.shard ─► R.ForListing(l) ─► R.Of(id)
                                                                      │
   KNOWN[id] ──(seeded)──┐                                            ▼
   learned[id] (DB.shards, R.Learn ◄─ R.Group(realm name)) ──► group text ──► flag art? ──yes─► {file, coords, w=19/20/15, h=10}
   Preview.shardGroups[id] (preview only) ──┘                          └──no──► {text = "EU"}
                                                                                     │
                       R.Line(l) ─► "Region: <group>" ─► row tooltip / icon tooltip  ▼
                                                    Table FillRow: flag slot = Texture or FontString
                                                    ─► width fit / ICON_DROP (flag last) ─► hit frame
```

### Table touch points (`UI/Table.lua`)

| Line(s) | Today | Change |
|---------|-------|--------|
| 17-19 (header comment) | "icons … are textures" | mention the region text tag |
| 53, 57 | `NAME_ICONS` / `ICON_DROP` with `flag` | unchanged (tag lives in the `flag` slot, so gap rules and drop order are automatically the flag's) |
| 573-576 | `tip.line(ns.Region.Line(l), W.GRAY)` | unchanged (label now full text) |
| 612-613 | icon tooltip `title = ns.Region.Line(l)` | unchanged; works for the tag too because the tag uses the `flag` hit frame (`tgfKind = "flag"`) |
| 998-1005 (Build) | per kind: texture + `W.HitFrame(cells.name, tex, row)` | for `flag` also create `tag = W.Text(cells.name, "GameFontNormalSmall", 10)`, `tag:Hide()`; store `{ tex, tag, hit, obj = tex }`. Set `obj = tex` for every kind so the loops can use `icon.obj` |
| 1268-1289 (FillRow, flag branch) | `SetTexture/SetTexCoord/SetSize` | if `flag.file`: as today, `obj = tex`, hide `tag`. If `flag.text`: `tag:SetText(flag.text)`, `tag:SetSize(ceil(tag:GetStringWidth()) + 1, 12)`, `obj = tag`, hide `tex`. Then `hit:ClearAllPoints(); hit:SetAllPoints(icon.obj)` (the hit was anchored once to `tex` at build) |
| 1296-1300, 1321-1327, 1333-1346 | use `icon.tex` for width / height / point / show / hide / `SetDesaturated` / `SetAlpha` | use `icon.obj`; `if icon.obj.SetDesaturated then …` (FontStrings have no `SetDesaturated`); hide both `tex` and `tag` in the not-wanted / dropped paths |
| 1339 | y offset `h >= 16 and -3 or (-4 - floor((12 - h) / 2))` | with tag height 12 this gives `-4`, the name's own top; flag (h 10) keeps `-5` |
| 1389-1413 (colours) | greyed → `W.DELISTED` on texts | tag colour: `W.SetColor(tag, greyed and W.DELISTED or W.GRAY)`; alpha 1 (text greys by colour like the other texts, not by the 0.5 icon alpha) |

### Anti-Patterns to Avoid
- **Putting the region tag into the name text** (like `W.IconTag` fallbacks at `Table.lua:1293`): it would sit before the other icons, be outside the drop order and get cut with the name. Use the flag slot.
- **Calling `SetDesaturated` on the FontString**: Lua error on every greyed row.
- **Leaving the hit frame anchored to the hidden texture**: the tag's tooltip area would be the texture's old 19x10 box at a stale position.
- **Re-deriving region text in Table**: keep the rule in `Region.lua`; Table only draws `R.Flag(l)`.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Deflate | a custom inflater | Node `zlib.inflateSync` | built in, exact |
| npm PNG decoders (pngjs, sharp) | adding a dependency | ~60 lines with zlib | CONTEXT locks "no npm deps"; the subset needed (palette, non-interlaced) is small |
| Flag art | redrawing / resampling flags | the author's pixels copied 1:1; the GPU scales 40→19/20/15 | locked: no generated art |
| Width fitting / drop order for the tag | a new loop | the existing `flag` slot in `NAME_ICONS` / `ICON_DROP` | gap and drop rules come for free |

## Runtime State Inventory

Not a rename phase, but saved data is touched:

| Category | Items Found | Action Required |
|----------|-------------|------------------|
| Stored data | `TerribleGroupFinderDB.shards` (id → group, today only `^%u%u%d*$`) | Code edit only: the looser `Sane` keeps old entries valid; no migration. A realm learned before this phase with a free-text name was never stored (old parser returned nil), so it simply gets learned on next scan |
| Live service config | None — verified (no server-side config) | none |
| OS-registered state | None | none |
| Secrets/env vars | None | none |
| Build artifacts | Deployed addon folder holds old `flag_us.tga` / `flag_au.tga` (64x64) | `install.bat` overwrites them; new four TGAs are added automatically (it ships every `.tga` under `Media/Textures`). Clients cache textures by path: a `/reload` may still show the old 64x64 US/AU art until a full client restart [ASSUMED from common WoW addon experience] |

## Shipping (verified from scripts)

- `scripts/install.ps1:73-79` and `scripts/package.ps1:50-55`: every `.blp`/`.tga` under `Media\Textures` is added to the file set; then both warn `"... is not tracked by git - it will not be in a release"` for untracked ones (install.ps1:81-97, package.ps1:57-70). → The four new TGAs must be `git add`-ed in Plan 01.
- `.pkgmeta` ignores `Media/Source`, `*.png`, `scripts` → PNGs, `SOURCE.md`, `png2tga.js` never ship. Nothing to change.
- `install.ps1` prunes deployed files the repo no longer has — no stale files expected (names unchanged).

## Common Pitfalls

### Pitfall 1: US PNG is 4-bit
**What goes wrong:** treating every scanline byte as an index gives a 20-px-wide garbage flag.
**How to avoid:** unpack sub-byte depths (step 6); verify stride = `ceil(w*bd/8)`.
**Warning signs:** inflated length ≠ `h*(1+stride)`.

### Pitfall 2: TGA byte order / origin
**What goes wrong:** RGB order or bottom-up origin gives blue-red swapped or upside-down flags (US flag upside down is easy to miss on canton-less flags like CN/TW? no — TW's canton is top-left, a good check).
**How to avoid:** BGRA, descriptor `0x28`. Check AU/TW/US cantons sit top-left in game.

### Pitfall 3: Edge bleed at the tex-coord boundary
**What goes wrong:** bilinear sampling at `40/64` and `H/32` blends with the transparent neighbours; at 2x minification the right/bottom pixel column may look slightly faded.
**How to avoid:** accept (the old art had transparent rows next to the coords too); if visible, inset by half a texel (`39.5/64`, `(H-0.5)/32`). In-game check item for the author. [ASSUMED]

### Pitfall 4: FontString sizing in the icon slot
**What goes wrong:** `GetWidth()` of a FontString without explicit width can be 0 or the anchored width; a height below the font's line height hides the text.
**How to avoid:** set text first, then `SetSize(ceil(GetStringWidth()) + 1, 12)` with a 10 pt font; `SetWordWrap(false)` already set by `W.Text`.

### Pitfall 5: `FontString:SetDesaturated` doesn't exist
Guard with `if obj.SetDesaturated`; grey via `W.DELISTED` colour instead.

### Pitfall 6: Hit frame anchored once
`W.HitFrame` (`Widgets.lua:180-187`) does `SetAllPoints(region)` at build. Re-anchor the flag's hit frame to the shown object on every fill.

### Pitfall 7: Escape codes and odd names
A shard name with `|` would inject markup into the row and tooltip; `SaneGroup` rejects it. Truncating multibyte text at byte 2 renders garbage; use the UTF-8-aware `Tag`.

### Pitfall 8: Secret values
`R.Group` keeps `Plain(name)`; `partyGUID` is never secret per CLAUDE.md, and `Server()` already guards. The preview lookup takes numeric IDs only. No new secret surface.

### Pitfall 9: Untracked TGAs
New `flag_cn/eu/kr/tw.tga` ship locally but not in a release unless committed (the scripts only warn).

### Pitfall 10: Stale wording elsewhere
`Settings.lua:163` tooltip says "US or Oceania" — update to e.g. "Show a region flag (or the region's letters) after each listing's name." `Region.lua:2,17-25` header comments mention Oceania / "a country we have no art for (no flag)" — rewrite. `README.md:39` and `CHANGELOG.md:10` also say "US or Oceania" but are out of scope (Release Review / never touch); note in the summary for the author.

## Code Examples

Converter skeleton (validated as a prototype this session):
```js
// Media/Source/png2tga.js -- converts the author's flag PNGs (Media/Source/flags/flag_<cc>.png,
// flagpedia.net) to Media/Textures/flag_<cc>.tga: 32-bit, top-left origin, 64x32 canvas, the
// flag copied 1:1 at the top-left, the rest transparent. Converts pixels only; draws nothing.
// Run from the repo root: node Media/Source/png2tga.js
const fs = require('fs'), path = require('path'), zlib = require('zlib');
const W = 64, H = 32;
function decode(buf) { /* signature, chunks, IHDR checks (ct 3, il 0, bd 1/2/4/8, w<=64, h<=32),
  inflate, unfilter 0-4 with bpp 1, unpack indices MSB-first, PLTE + tRNS → RGBA */ }
function tga(img) {
  const head = Buffer.alloc(18);
  head[2] = 2; head.writeUInt16LE(W, 12); head.writeUInt16LE(H, 14); head[16] = 32; head[17] = 0x28;
  const px = Buffer.alloc(W * H * 4);
  for (let y = 0; y < img.h; y++) for (let x = 0; x < img.w; x++) {
    const s = (y * img.w + x) * 4, d = (y * W + x) * 4;
    px[d] = img.rgba[s + 2]; px[d + 1] = img.rgba[s + 1]; px[d + 2] = img.rgba[s]; px[d + 3] = img.rgba[s + 3];
  }
  return Buffer.concat([head, px]);
}
// for each Media/Source/flags/flag_*.png → Media/Textures/flag_<cc>.tga; print "<cc> WxH"
```
The full working prototype is at `C:\Users\jonat\AppData\Local\Temp\claude\3a677a53f55271b6\8039163f-18e8-4930-88a2-d8efcca63b25\scratchpad\proto.js` (scratch, not for commit; reformat for the repo).

Verification one-liner after conversion: each `Media/Textures/flag_*.tga` is 8210 bytes and starts with `00 00 02 00 00 00 00 00 00 00 00 00 40 00 20 00 20 28`.

## State of the Art

| Old Approach | Current Approach | Impact |
|--------------|------------------|--------|
| `flags.js` draws US/AU at 64x40 on a 64x64 canvas, shown 16x10, coords `{0,1,12/64,52/64}` | author's PNGs converted to 64x32, shown 19/20/15 x 10 | US / AU look changes; README screenshot reminder |
| `R.Group`: `^CAMWOW(%a%a%d*)REALM` on stripped text | free text between CAMWOW and Realm | EU/Asia/odd names get a region |
| No flag → nothing on row (tooltip only) | No flag → two-letter text tag | REG-07 |

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | Non-US/AU shard names follow `CAMWOW <group> Realm …` | Region rule | No region shown for those shards (same as today); fixed from `/tgf region` reports |
| A2 | Edge bleed at the tex-coord boundary is negligible | Pitfall 3 | Slightly soft right/bottom edge; half-texel inset fixes it |
| A3 | `/reload` may keep cached old US/AU textures until a client restart | Runtime State | Author sees old art after deploy; restart the client |
| A4 | `GameFontNormalSmall` at height 12 reads well beside the 12 pt name | Table touch points | Cosmetic; adjust in-game |

## Open Questions (RESOLVED)

1. **Tag font colour** — RESOLVED: `W.GRAY` (matches level / zone), `W.DELISTED` when greyed (13-02 Task 2). Class colour would compete with the name.
2. **`BR1` preview sample** — RESOLVED: added as preview sample 99106 to show the "country without art" path (13-02 Task 1; Claude's discretion on preview).

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| Node.js | png2tga.js | ✓ | v24.14.0 | — |
| stylua | formatting | ✓ | (cargo install) | — |
| git | tracking new TGAs | ✓ | — | — |
| WoW Forever client | in-game check | author's machine | — | preview mode via `/tgf preview` |

No blocking gaps.

## Validation Architecture

Skipped: `workflow.nyquist_validation` is `false` in `.planning/config.json`. Verification for the planner: (a) TGA header/size check above; (b) `stylua --check .`; (c) a pure-Lua check of `R.Group` / flag-vs-tag cases is possible by loading `Region.lua` with stubbed `ns` in a scratch Lua run if a Lua interpreter is available (the out-of-repo smoke harness is not to be planned around); (d) in-game `/tgf preview` checks deferred to the end of the autonomous run per the author's rule.

## Security Domain

| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V5 Input Validation | yes | `SaneGroup`: non-empty, ≤ 32 bytes, no control chars or `|`, applied to parsed realm names and to `DB.shards` on load |
| V2/V3/V4/V6 | no | — |

| Pattern | STRIDE | Mitigation |
|---------|--------|------------|
| UI escape-sequence injection via realm name / saved variables | Tampering | reject `|` and control chars in `SaneGroup` |
| Oversized saved strings | DoS (minor) | 32-byte cap |
| Taint | — | only our own Texture/FontString/Frame on our rows; no Blizzard writes |

## Suggested plan split

**Wave 1 (parallel):**

- **Plan 13-01 — Flag art (REG-05 art, REG-08)**
  1. `mkdir Media/Source/flags`; move the six repo-root PNGs there (untracked → plain `mv`, then `git add`; `.pkgmeta` keeps them out of releases).
  2. Write `Media/Source/png2tga.js` (§conversion); run it; verify six 8210-byte TGAs with the expected header.
  3. `git rm Media/Source/flags.js`.
  4. Write `Media/Source/flags/SOURCE.md` with the locked sentence (Write tool).
  5. `git add Media/Textures/flag_*.tga` (four new + two overwritten).

- **Plan 13-02 — Region rule and row tag (REG-05 sizes, REG-06, REG-07)**
  1. `Region.lua`: `SaneGroup`/`Sane` moved up and loosened; new `R.Group`; `FLAG_ART` table with heights; `Tag`; `R.Of` returns `flag`/`tag`; `R.Flag` returns art or `{ text }`; preview lookup; header comments rewritten (no "Oceania").
  2. `UI/Table.lua`: flag-slot FontString, `icon.obj`, hit re-anchor, `SetDesaturated` guard, tag colour (§Table touch points).
  3. `Preview.lua`: `P.shardGroups` + explicit shards on five (or six with `BR1`) samples; comment update.
  4. `Settings.lua:163` tooltip wording.
  5. `CLAUDE.md`: Region line (free-text groups, six flags from flagpedia.net via `Media/Source/png2tga.js`, text tag, preview groups) and the `Media/Textures/` line (flags + `Media/Source/flags/`); drop the `flags.js` mention.
  6. `stylua .`.

End-of-run notes for the author: README screenshot may need retaking (flags changed); README / CHANGELOG still say "US or Oceania" (Release Review).

## Sources

### Primary (HIGH confidence)
- Repo files read this session: `Region.lua`, `UI/Table.lua` (1-70, 560-660, 960-1030, 1220-1420), `UI/Widgets.lua` (HitFrame, Text, IconTag, SetIcon, colours), `Preview.lua` (95-150, 294), `Core.lua:205`, `Listings.lua:207`, `Settings.lua:155-168`, `scripts/install.ps1`, `scripts/package.ps1`, `.pkgmeta`, `TerribleGroupFinder.toc`, `Media/Source/flags.js`
- Node one-off over the six PNGs (chunks, IHDR, filters) and the three current TGAs (headers, sizes); converter prototype run
- PNG specification (filters, sub-byte packing, tRNS for palette) [CITED: w3.org/TR/png/] — from training knowledge, consistent with the prototype's correct output
- TGA header layout [ASSUMED: training knowledge], matched byte-for-byte against the shipping TGAs that load in game today

## Metadata

**Confidence breakdown:**
- Conversion: HIGH — measured inputs, prototype output, header matches files known to load
- Region rule: HIGH for code; MEDIUM for real-world shard names (A1)
- Table changes: HIGH — read the exact loop; FontString sizing details MEDIUM until seen in game

**Research date:** 2026-11-16
**Valid until:** stable (local code) — until Table.lua's icon loop changes
