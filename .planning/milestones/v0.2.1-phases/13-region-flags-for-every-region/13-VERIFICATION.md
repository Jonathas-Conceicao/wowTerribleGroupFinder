---
phase: 13-region-flags-for-every-region
verified: 2026-11-16T00:00:00Z
status: human_needed
score: 7/7 must-haves verified (code level); live-client rendering pending
human_verification:
  - test: "Install, fully restart the client, /tgf preview. Check US 19x10, AU 20x10, EU/KR/CN/TW 15x10 flags (Arugal EU, Tess KR, Remulos CN, Saidan TW) are sharp, upright, one height, aligned with other icons"
    expected: "No faded right or bottom edge; cantons top-left; if an edge is soft, a half-texel coord inset in Region.lua is the fix"
    why_human: "Texture rendering and alignment are visual"
  - test: "In preview, Gryan Stoutmantle and Archbishop Benedictus; hover the text and the row"
    expected: "Grey 'EU' and 'BR' text after the name; tooltips read 'Region: EU Paris' / 'Region: BR1'; group rows read 'Leader's region: ...'"
    why_human: "Tooltip and FontString rendering in the client"
  - test: "Delas Moonfang row; greyed (delisted/hidden) rows; narrow name room"
    expected: "No flag or tag for the unknown shard; greyed flag desaturated and dimmed, tag in delisted grey, no Lua error; the tag closes its gap and drops last, like the flag"
    why_human: "Runtime layout and error-free behaviour in the client"
  - test: "Settings -> Region flags off, then on; live (not preview) US and AU listings; /tgf region"
    expected: "Flags and tags and tooltip lines vanish and return; live US/AU flags still show; probe prints; tooltip text matches the new wording"
    why_human: "Needs the live Forever client"
---

# Phase 13: Region flags for every region - Verification Report

**Phase Goal:** Every listing whose shard group is known shows its region, as a real flag where there is one and as two letters otherwise, with the game's full text in the tooltip
**Status:** human_needed (all code-level checks pass; in-client rendering unverified)
**Re-verification:** No, initial

## Observable Truths

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | Flags at 10 px high, own width (US 19, AU 20, others 15), coords {0, 40/64, 0, h/32} (REG-05) | VERIFIED | `Region.lua` `R.Flag`: `coords = { 0, 40 / 64, 0, h / 32 }`, `width = floor(400 / h + 0.5)`, `height = 10`; FLAG_ART h: US 21, AU 20, EU/CN/KR/TW 27 (400/21=19, 400/20=20, 400/27=15) |
| 2 | Two letters + optional number with art shows the flag (REG-06) | VERIFIED | `R.Of`: key = spaces stripped, upper-cased; `^(%a%a)%d*$` against FLAG_ART (US, AU, EU, CN, KR, TW) |
| 3 | Other known group shows first two letters as grey text in flag slot, same gap/drop rules (REG-07) | VERIFIED | `Tag()` (UTF-8 safe); `R.Flag` returns `{ text }`; `UI/Table.lua` 1008-1009 FontString, 1299-1307 fill, `icon.obj` used for width sums, drop and placement; ICON_DROP unchanged (flag last); `W.DELISTED or W.GRAY` colouring |
| 4 | Tooltip reads "Region:" / "Leader's region:" plus full group (REG-06/07) | VERIFIED | `label = group` in `R.Of`; `Table.lua:615 title = ns.Region.Line(l)` shared by flag and tag hit frame (hit re-anchored via `SetAllPoints(icon.obj)`) |
| 5 | Shard names parsed as text between CAMWOW and Realm; non-CAMWOW unknown; saved shards free text (<=32 bytes, no control chars or `|`) | VERIFIED | `R.Group` (`^%s*CAMWOW`, plain `REALM` find, trim, `SaneGroup`); `SaneGroup` `[%c|]`, `#g <= 32`; `Sane` used in `R.Init` |
| 6 | Preview shows EU1, KR1, CN, TW1, EU Paris, BR1 from preview-only groups, never in DB.shards | VERIFIED | `Preview.lua:108 P.shardGroups`; samples use shard 99101-99106; Delas keeps 9999; `R.Of` reads it only under `ns.UsingPreview()` with source "preview", never written to `learned` |
| 7 | flags.js gone, nothing in Lua refers to it; CLAUDE.md names flagpedia.net/png2tga.js; README/CHANGELOG unchanged (REG-08) | VERIFIED | `Media/Source/flags.js` absent and untracked; no `flags.js` hits anywhere outside `.planning`; CLAUDE.md lines 29/41 name flagpedia.net and png2tga.js; `grep flagpedia README.md` empty; no diff to README/CHANGELOG; `git status` clean |

**Score:** 7/7 code-level truths verified

### Required Artifacts

| Artifact | Status | Details |
|----------|--------|---------|
| `Media/Textures/flag_{us,au,eu,cn,kr,tw}.tga` | VERIFIED | All six tracked, 8210 bytes, header `00000200000000000000000040002000 2028`, pixel (40,0) alpha 0, pixel (0,0) alpha 255 |
| `Media/Source/flags/` six PNGs + SOURCE.md | VERIFIED | Tracked; SOURCE.md names flagpedia.net |
| `Media/Source/png2tga.js` | VERIFIED | Present, tracked |
| `Region.lua`, `UI/Table.lua`, `Preview.lua`, `Settings.lua` | VERIFIED | Substantive and wired as above; Settings tooltip is the new wording, no "Oceania" in Lua |
| `stylua --check .` | PASS | exit 0 |

### Key Links

| From | To | Status |
|------|----|--------|
| `R.Flag` | `Table.lua` FillRow (`flag.file` / `flag.text`) | WIRED |
| `R.Of` | `Preview.shardGroups` | WIRED (preview-gated) |
| `R.Group` / `R.Init` | `SaneGroup` | WIRED |
| flag/tag hit frame | `Region.Line` | WIRED |

### Requirements Coverage

| Requirement | Source Plan | Status | Evidence |
|-------------|-------------|--------|----------|
| REG-05 | 13-01, 13-02 | SATISFIED (rendering needs human) | Six TGAs, sizes and coords as above |
| REG-06 | 13-02 | SATISFIED | Rule in `R.Of`, tooltip via `R.Line` |
| REG-07 | 13-02 | SATISFIED | Tag path in `R.Flag` and `Table.lua` |
| REG-08 | 13-01, 13-02 | SATISFIED | Generator removed, CLAUDE.md origin lines, README clean |

No orphaned requirements: REQUIREMENTS.md maps REG-05..08 to Phase 13 and both plans claim them. The checkbox/status rows in REQUIREMENTS.md still read Pending, which the orchestrator should update.

### Anti-Patterns

No TBD/FIXME/XXX found in the touched code that matters. `SetDesaturated` is guarded (`if obj.SetDesaturated`). No blockers.

### Behavioural Spot-Checks and Probes

No Lua interpreter is available; checks were source reads, TGA byte checks and `stylua --check`. No probes declared.

### Notes

- README.md and CHANGELOG.md still carry the old "US or Oceania" wording by design (left for the Release Review). README screenshots may need retaking.
- Live rendering, tooltips, greyed rows and drop order can only be confirmed in the Forever client (see `human_verification`).

---
_Verified: 2026-11-16_
_Verifier: Claude (gsd-verifier)_
