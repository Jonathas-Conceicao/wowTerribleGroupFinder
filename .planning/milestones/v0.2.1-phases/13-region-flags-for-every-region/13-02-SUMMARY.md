---
phase: 13-region-flags-for-every-region
plan: 02
subsystem: region
tags: [region, flags, table, preview]
requires: [13-01]
provides:
  - Six flags drawn 10 px high at their own widths; two-letter text tag for other groups
  - Free-text shard groups (text between CAMWOW and Realm), sanitized
  - Preview-only region groups for every case
key-files:
  modified:
    - Region.lua
    - Preview.lua
    - UI/Table.lua
    - Settings.lua
    - CLAUDE.md
requirements-completed: [REG-05, REG-06, REG-07, REG-08]
completed: 2026-11-16
---

# Phase 13 Plan 02: Region rule Summary

Listings show a flag (US, AU, EU, CN, KR, TW) when the group is two letters plus an optional number with art, else the group's first two letters as grey text in the flag's slot; tooltips name the full group.

## Commits
- 1a6eb01: Region.lua rule (FLAG_ART with heights, SaneGroup, free-text R.Group, Tag, R.Of flag/tag/preview, R.Flag), Preview.lua `P.shardGroups` and six samples
- 935991f: UI/Table.lua text tag in the flag slot (`icon.obj`, hit frame re-anchored, guarded SetDesaturated)
- Task 3 commit: Settings.lua tooltip wording and CLAUDE.md lines

## Deviations from Plan
None. The plan was executed as written. `stylua .` was run; no Lua interpreter is available, so checks were source greps plus stylua.

## Known Stubs
None.

## HUMAN-UAT
1. `./scripts/install.bat`, restart the client, `/tgf preview`: Arugal shows the EU flag, Tess the KR flag, Remulos the CN flag, Saidan the TW flag, all 15x10; US rows 19x10, AU rows 20x10; all at one height and vertically aligned with the other icons.
2. Gryan Stoutmantle shows grey "EU" text and Archbishop Benedictus grey "BR" text after the name; hovering the text shows "Region: EU Paris" / "Region: BR1"; the row tooltip shows the same line.
3. Hovering a flag shows "Region: EU1" (and so on); a group row shows "Leader's region: ...".
4. Delas Moonfang shows neither flag nor text.
5. A greyed (delisted / hidden) row: the flag is desaturated and dimmed; the text tag turns the darker delisted grey; no Lua error.
6. Narrow name room (long names, many icons): the tag closes its gap and drops last, like the flag.
7. Settings -> Region flags off: no flags or tags, no region tooltip lines; on again: they return. Tooltip text reads "Show each listing's region after its name: a flag where there is one, else the region's letters."
8. Live (not preview): US and AU listings still show their flags; `/tgf region` still prints the probe.
9. Notes for the author: README.md and CHANGELOG.md still say "US or Oceania" (left for the Release Review); README screenshots may need retaking as flags changed look.

## Self-Check: PASSED
