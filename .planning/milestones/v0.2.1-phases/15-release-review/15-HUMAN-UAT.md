---
status: partial
phase: 15-release-review
source: [15-CONTEXT.md, 15-01-SUMMARY.md, 15-02-SUMMARY.md]
started: 2026-11-16T12:00:00Z
updated: 2026-11-16T12:00:00Z
---

## Current Test

[awaiting the author's review — deferred to the end of the autonomous run]

## Tests

### 1. CHANGELOG review
expected: The `## v0.2.1` section at the top of CHANGELOG.md (first `## ` heading, published by the release workflow) is a draft. Review and rewrite as wished.
Decision for the author (keep or drop): the quiet inspect now waits for an inspect that isn't ours (for example the game's "Inspect Talents") until it answers or 4 s pass. v0.2.0 already guarded only with a 2 s gap after such an inspect (plus the Inspect window being open or pending), so v0.2.0 may have disturbed Inspect Talents; this was not confirmed as a v0.2.0 bug, so the draft has no Fixed section. If you want it, add under `## v0.2.1`:

```
### Fixed

- Item level lookups no longer get in the way of the game's Inspect Talents
```
result: [pending]

### 2. README proposals
expected: README.md is not edited until you approve; the orchestrator applies only the approved lines. There is no flagpedia credit in any of them.

a. Region flags bullet
Before:
```
- **Region flags** - a US or Oceania flag after each name, your own listing included,
  with the region in the row tooltip
```
After:
```
- **Region flags** - a flag (US, Oceania, EU, China, Korea or Taiwan) after each name,
  your own listing included; other regions show their first two letters, and the row
  tooltip names the region
```

b. Item level bullet
Before:
```
- **Item level** - shown on friendly players' tooltips, on weapon and armor tooltips, as
  a row under Movement Speed on the character sheet, and on the Inspect window
```
After:
```
- **Item level** - shown on friendly players' tooltips (with their talent points per
  tree), on weapon and armor tooltips, as a row under Movement Speed on the character
  sheet, and on the Inspect window
```

c. New bullet (after the **Item level** bullet, or after **Settings page**: your pick)
Before: goes after the line `  a row under Movement Speed on the character sheet, and on the Inspect window` (the Item level bullet).
After:
```
- **Damage meter reset** - joining a group or entering a dungeon, raid or battleground
  asks whether to reset Details! (or the game's own damage meter); once per run, and
  each prompt can be turned off
```

d. Usage: `/tgf meter`
Before:
```
- `/tgf ilvl` prints the item level figures the game gives for you and your group;
  `/tgf region` prints the region the addon reads for listings
```
After:
```
- `/tgf ilvl` prints the item level figures the game gives for you and your group;
  `/tgf region` prints the region the addon reads for listings; `/tgf meter` asks to
  reset the damage meter now
```

e. Settings page bullet
Before:
```
- **Settings page** - in Settings > AddOns: turn each item level spot, Dynamic refresh,
  the animations and region flags on or off, and open the Messages tab from a button
```
After:
```
- **Settings page** - in Settings > AddOns: turn each item level spot, talent points,
  Dynamic refresh, the animations, region flags and the two damage meter prompts on or
  off, and open the Messages tab from a button
```
result: [pending]

### 3. Screenshot reminder
expected: You retake the prints (agents never make images). `Media/Screenshots/tgf_lfg_window.png` may be outdated: rows with the new US / Oceania flag art, the new flags and two-letter tags. A player tooltip print would now show the talents line. The meter reset dialog is new. The settings page has a renamed section ("Item level and talents") and a Damage meter section. `tgf_lfg_message_config.png` is unchanged by v0.2.1.
result: [pending]

### 4. Version
expected: Confirm v0.2.1 (TOC keeps `## Version: @project-version@`; tag `v0.2.1` on `main` after the squash merge at milestone completion, per PROJECT.md Git Workflow). Not done by agents.
result: [pending]

### 5. Deferred in-game checks
expected: Run these in the same session; the release waits on them.
- `.planning/phases/12-damage-meter-reset-prompt/12-HUMAN-UAT.md` (8 items): the damage meter reset prompt, its triggers, Details! and the game's meter, `/tgf meter`
- `.planning/phases/13-region-flags-for-every-region/13-HUMAN-UAT.md` (5 items): flags for more regions, two-letter tags, new flag art, tooltip region names
- `.planning/phases/14-spec-points/14-HUMAN-UAT.md` (8 items): talent points on tooltips, the setting, the inspect queue
result: [pending]

### 6. Phase confirmation
expected: The author's confirmation closes Phase 15 and starts the milestone close-out (push, squash-merge, tag).
result: [pending]

## Summary

total: 6
passed: 0
issues: 0
pending: 6
skipped: 0
blocked: 0

## Gaps
