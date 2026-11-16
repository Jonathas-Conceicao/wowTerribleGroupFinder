---
phase: 13-region-flags-for-every-region
reviewed: 2026-11-16T00:00:00Z
depth: standard
files_reviewed: 5
files_reviewed_list:
  - Region.lua
  - Preview.lua
  - UI/Table.lua
  - Settings.lua
  - Media/Source/png2tga.js
findings:
  critical: 0
  warning: 1
  info: 6
  total: 7
status: issues_found
---

# Phase 13: Code Review Report

**Reviewed:** 2026-11-16
**Depth:** standard
**Files Reviewed:** 5 (diff `f51af12..2f62fbb`)
**Status:** issues_found

## Summary

I reviewed the region rule (`R.Group`, `SaneGroup`, `Tag`, `R.Of`, `R.Flag`, `Sane`), the preview groups, the text tag in the row icon loop, the Settings wording and the PNG-to-TGA converter.

**Binary assets:** all six `Media/Textures/flag_{us,au,eu,cn,kr,tw}.tga` are tracked by git (`git ls-files`). Each is 8210 bytes, which is 18 + 64x32x4. `install.ps1` / `package.ps1` ship every tracked texture under `Media/Textures`, and `.pkgmeta` leaves out `Media/Source`.

**Areas with no findings:**
- **Taint:** the new FontString and hit frame belong to our own `cells.name`. Nothing of Blizzard's is written.
- **Secret values:** `R.Group` and `R.Learn` still check `Plain()` first, and `R.Of` still checks it on the shard.
- **UI escape injection:** `SaneGroup` rejects `|` and control characters before free text reaches the tooltip or the FontString.
- **Saved data:** values saved under the old `^%u%u%d*$` rule still pass the new sanitizer.
- **Flag sizes and tex coords:** they match the decisions (US 19x10, AU 20x10, others 15x10; `{0, 40/64, 0, h/32}`).
- **Tag alignment:** the 12 px tag box at y -4 is centred on the same line (-10) as a 10 px flag at y -5.
- **Drop order and gap closing:** these now use `icon.obj` widths throughout.

There is one real layout bug. When a pooled row is reused, the text tag is measured with the width it was given for its last text.

## Warnings

### WR-01: The text tag is measured against its old width, so a reused row can cut it off

**File:** `UI/Table.lua:1300-1301`
**Issue:** `icon.tag:SetText(flag.text)` is followed by `icon.tag:SetSize(ceil(icon.tag:GetStringWidth()) + 1, 12)`. On the modern client, `FontString:GetStringWidth()` is limited by the width the FontString already has. That is why `GetUnboundedStringWidth` exists (see `SimpleFontStringAPIDocumentation.lua:398` in wow-ui-source). `W.Text` also calls `SetWordWrap(false)`.

A row frame that first showed a narrow tag (for example "EU", about 14 px) and is then reused for a wider one ("MW", "WW", or any wider pair) still has the old width when the new text is set. The text is cut with an ellipsis. `GetStringWidth()` then returns the cut width, and the tag is sized to that, so it stays cut on that frame.

ScrollBox pooling and sorting reuse frames constantly, so this shows up in practice once more than one tag pair is on screen. The preview already has two pairs, "EU" (EU Paris) and "BR" (BR1).
**Fix:** measure without the bound:
```lua
icon.tag:SetText(flag.text)
local tw = icon.tag.GetUnboundedStringWidth and icon.tag:GetUnboundedStringWidth()
if not tw then
	icon.tag:SetWidth(0) -- unconstrained, then measure
	tw = icon.tag:GetStringWidth()
end
icon.tag:SetSize(ceil(tw) + 1, 12)
```

## Info

### IN-01: A group longer than 32 bytes disappears completely, including from the tooltip

**File:** `Region.lua:62-64, 81-82`
**Issue:** `R.Group` runs `SaneGroup` on the parsed text, so a group over 32 bytes is never learned. Such a listing gets no tag and no "Region: ..." line, which goes against "the tooltip always shows the full group text".

The limit also counts bytes, not characters as the decision says ("up to 32 chars"). A non-ASCII group of 11 three-byte characters is already rejected.
**Fix:** keep the byte cap for what gets saved, but cut on a UTF-8 boundary instead of rejecting. Take the leading characters up to 32 bytes, using the same character pattern as `Tag`. Alternatively, change the wording in CONTEXT/CLAUDE.md to "bytes".

### IN-02: Flag geometry is stated twice, once in the PNGs and once in Region.lua

**File:** `Region.lua:34-41, 198-201`; `Media/Source/png2tga.js:37`
**Issue:** `FLAG_ART[cc].h` and the hard-coded source width `40` (`40 / 64`, `400 / h`) restate each PNG's size by hand. If the author re-supplies a flag at a different size, the converter accepts it silently (anything up to 64x32), and the row then shows a cropped or padded flag.
**Fix:** have `png2tga.js` print, or fail on, any size other than the expected 40xH. Alternatively, add a short comment next to `FLAG_ART` saying that the `h` values must match the PNGs the converter reports.

### IN-03: Possible soft edges at odd flag heights (21, 27) on a transparent canvas

**File:** `Media/Source/png2tga.js:93-103`
**Issue:** the flag is padded with fully transparent texels. At 1:1 bilinear sampling this is fine, because the last pixel centres fall inside the art. If the client filters through a lower mip level (40x21 shown at 19x10, 40x27 at 15x10), the bottom row (odd height) and the right column blend with transparent texels. That gives the "faded edge" that 13-01 HUMAN-UAT step 1 already asks about.
**Fix:** if the UAT shows it, have the converter repeat the flag's last row and column into the padding. This only copies the author's own edge texels and draws nothing new, so it stays within "no art generated".

### IN-04: Tag characters the font lacks give a zero-width slot

**File:** `Region.lua:86-91`; `UI/Table.lua:1301`
**Issue:** `Tag` is UTF-8 safe. However, a learned free-text group that starts with characters `GameFontNormalSmall` has no glyphs for (for example CJK on an enUS client) measures 0 px. The result is a 1 px tag and a hit frame that is nearly invisible. Bytes not handled by the character class (`\192`, `\193`, `\245`-`\255`) make `Tag` return nil, so no tag is drawn while the tooltip line still shows.
**Fix:** in `FillRow`, if the measured width is under about 4 px, treat the flag slot as not drawn (`ok = false`) so it hides cleanly. Alternatively, fall back to the ASCII letters of the group (`group:gsub("[^%w]", "")`) for the tag.

### IN-05: The region module reads preview data on the live path

**File:** `Region.lua:117-120`
**Issue:** `R.Of` reaches into `ns.Preview.shardGroups` on every call. It is gated by `ns.UsingPreview()`, so this is correct, but it couples Region to Preview's internals. It is also the only lookup that happens after the learned groups: a learned ID equal to a preview ID would hide the preview case. That is unlikely with IDs from 99101 up.
**Fix:** acceptable as is. A cleaner shape would be an `R.SetPreviewGroups(t)` that Preview calls, or a short comment that preview IDs must stay outside the real realm-ID range.

### IN-06: The CLAUDE.md Region line still says the flag is always a texture

**File:** `CLAUDE.md:29`
**Issue:** the end of the line still reads "The flag follows the name on rows, drawn as a texture by `UI/Table.lua` through `R.Flag(l)`". Earlier on the same line it says other groups show as text, and `R.Flag` now returns `{ text }` for those.
**Fix:** change it to "drawn as a texture, or the two-letter text in the same slot, by `UI/Table.lua` through `R.Flag(l)`".

---

_Reviewed: 2026-11-16_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
