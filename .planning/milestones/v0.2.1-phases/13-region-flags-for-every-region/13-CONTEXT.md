# Phase 13: Region Flags for Every Region - Context

**Gathered:** 2026-11-16
**Status:** Ready for planning
**Mode:** Smart discuss, recommended answers auto-picked (author's standing rule for /gsd-autonomous: no pauses; decisions reported at the end)

<domain>
## Phase Boundary

Every listing whose shard group is known shows its region: the author's flagpedia.net flag where
the group is a country code with an optional number and we have that country's flag, else the
group's first two letters as text; the tooltip always shows the full group text as the game
names it. The script-drawn flags and their generator are removed. No new shard seeding (EU /
Asia IDs come later from player reports).

</domain>

<decisions>
## Implementation Decisions

### Flag art (REG-05, REG-08) — author decisions
- Source: the author's PNGs from flagpedia.net, now untracked in the repo root: `flag_au.png` 40x20, `flag_us.png` 40x21, `flag_cn.png` / `flag_eu.png` / `flag_kr.png` / `flag_tw.png` 40x27 (all 8-bit palette PNGs). NO art is generated or redrawn; converting the author's images is allowed
- Move the PNGs to `Media/Source/flags/` (not shipped; `Media/Source/` is outside the TOC file set) and record the source in an internal note `Media/Source/flags/SOURCE.md` ("Flags from flagpedia.net (flagcdn.com), w40 PNGs, public domain; supplied by the author 2026-11-16") and in CLAUDE.md's Region / Media lines. Nothing in README.md
- Conversion: a dev-only Node script `Media/Source/png2tga.js` (no npm deps: decode PNG with zlib, handle palette + tRNS) writes `Media/Textures/flag_<cc>.tga` for each PNG: 32-bit uncompressed TGA, top-left origin, a 64x32 power-of-two canvas with the flag copied 1:1 at the top-left and the rest transparent. It only converts pixels the author supplied; it draws nothing
- Delete `Media/Source/flags.js` (the generator); the old `flag_us.tga` / `flag_au.tga` are overwritten by the converted ones (same file names, so the install/package scripts and paths keep working)
- Drawn at one height on rows: 10 px (as today), width from each flag's aspect: US 19x10, AU 20x10, CN / EU / KR / TW 15x10 (rounded from 40/H*10); tex coords {0, 40/64, 0, H/32} per flag

### Region rule (REG-06, REG-07) — author decisions
- Shard name parsing: the text between `CAMWOW` and `Realm` in the shard name, trimmed, spacing kept (`CAMWOW US2 Realm 8 PvP` → `US2`; `CAMWOW EU Paris Realm 3 PvE` → `EU Paris`); names not starting with `CAMWOW` stay unknown (no region)
- Flag when the group, spaces removed and upper-cased, matches two letters plus an optional number (`AU`, `EU`, `EU1`..`EU9`, `US2`, `KR1`; `%d*` so a two-digit number works too) AND `FLAG_ART` has its first two letters: `US, AU, EU, CN, KR, TW`
- Otherwise (any other text, or a country with no art such as `BR1`): a text tag on the row, the group's first two letters upper-cased (e.g. `EU`), drawn in the flag's slot as a small FontString in the row's grey/name colour, same gap rules and drop order as the flag (flag last)
- Tooltip: the row tooltip's line keeps "Region: <full text>" / "Leader's region: <full text>"; the flag / text-tag hover tooltip (row icon tooltips, Phase 8) shows the same full text
- Seeded `KNOWN` IDs stay (US1, US2, AU1); learned groups keep working; the saved-shard sanitizer (`Sane`) accepts the new free text (a non-empty string up to 32 chars, printable) instead of only `^%u%u%d*$`

### Preview (testability) — Claude's pick
- `/tgf preview` shows every case so the author can see them without other regions' players: sample listings get shards for EU1, KR1, CN, TW1 and one odd name (`EU Paris`) via preview-only learned groups (never saved to `DB.shards`)

### Claude's Discretion
- Whether the text tag is a FontString per row icon slot or reuses an existing helper; exact font object (a small game font such as GameFontNormalSmall / GameFontHighlightSmall)
- Smoke-harness updates in the session scratchpad

</decisions>

<code_context>
## Existing Code Insights

### Reusable Assets
- `Region.lua`: `FLAG_ART`, `KNOWN`, `R.Group(name)` (parser, today `^CAMWOW(%a%a%d*)REALM` on the whitespace-stripped upper-cased name), `R.Of(shard)` → `{ flag, label, group, source }`, `R.Flag(l)` → `{ file, coords, width, height, place }`, `R.Line(l)`, `Sane()` in `R.Init`
- `UI/Table.lua` ~1268: the name-cell icons loop (`NAME_ICONS`, `row.tgfIcons[kind]`, `wanted.flag`), flag drawn with `SetTexture` / `SetTexCoord` / `SetSize`; icon tooltips through hit frames (`tgfKind`)
- `Media/Source/flags.js`: shows the TGA writer format used today (to be deleted; its TGA header logic can be mirrored in the converter)

### Established Patterns
- Settings gate `regionFlags` read where it acts; toggling redraws the table
- Name-cell icons drop least informative first; the flag last

### Integration Points
- `scripts/install.ps1` / `package.ps1` derive the shipped files from the TOC plus `Media/Textures/` (check that new `flag_*.tga` files ship)
- `Preview.lua` sample listings carry `shard` IDs

</code_context>

<specifics>
## Specific Ideas

- Author: "for now I assume regions like EU which I expected to have 3 physical locations will show as EU1 EU2 and EU3, let's assume other regions, taiwan, korea and china will be similar to that US1 and US2 ... use flag if I'm right and have the actual text (be it EU1 or EU Paris) in the tooltip, and show just first 2 characters as text (and the full text on tooltip if possible) if it's any text different than this"
- Author: "keep in mind that data might be without number too, as I think AU shows rn, so EU, EU{1-9} shows the EU flag and so on"
- Author: "any code we currently have to generate flag icons should be removed ... the flag files are from flagpedia.net have some internal note about it, but no need to add it to the README"

</specifics>

<deferred>
## Deferred Ideas

- Seeding EU / Asia shard IDs once players send `/tgf region` output
- README wording for region flags (Release Review, author-directed)

</deferred>
