---
status: complete
phase: 17-release-review
source: [17-CONTEXT.md, 17-01-SUMMARY.md, 17-02-SUMMARY.md]
started: 2026-11-19T12:00:00Z
updated: 2026-11-20T12:00:00Z
---

## Current Test

[testing complete]

## Tests

### 1. CHANGELOG review
expected: The `## v0.2.2` section at the top of CHANGELOG.md (first `## ` heading, published by the release workflow as the release notes) is a draft. Review and rewrite as wished. It has Added and Changed only: no bug that existed in v0.2.1 is known fixed, so there is no Fixed heading. `## v0.2.1` and everything below are unchanged.
result: pass

### 2. README image layout
expected: The top image block now shows `Media/Screenshots/tgf_refresh.gif` first (`width="64%"`) and `tgf_lfg_message_config.png` beside it (`width="34%"`, was 42%). Check on GitHub that both show at about the same height side by side and the gif plays (it is ~32 MB, under GitHub's 50 MB warning). `tgf_lfg_window.png` stays in the repo but is no longer shown; `tgf_tooltip_info.png` is committed but not placed in the README (your call). `.gitattributes` now marks `*.gif` binary.
result: pass

### 3. README wording proposals
expected: README.md is not edited until you approve; the orchestrator applies only the approved lines. There is no flagpedia credit in any of them.

a. New damage meter bullet (README has none yet; goes after the **Item level** bullet, or after **Settings page**: your pick)
Before: goes after the line `  a row under Movement Speed on the character sheet, and on the Inspect window` (the Item level bullet).
After:
```
- **Damage meter reset** - joining a group or entering a dungeon, raid or battleground
  asks whether to reset Details! (or the game's own damage meter); once per run, and
  each prompt can be turned off. The prompt can be moved from Settings, and the
  joining-a-group prompt is off by default
```

b. Whisper presets bullet
Before:
```
- **Whisper presets** - a Whisper button on every row sends a preset message:
  - **Inviting a player**: used while you're in a group, or to a solo player
  - **Asking a group for an invite**: used on a group's row while you're on your own
```
After:
```
- **Whisper presets** - a Whisper button on every row sends a preset message:
  - **Inviting a player**: used while you're in a group, or to a solo player
  - **Asking a group for an invite**: used on a group's row while you're on your own
  - When a listing has several activities, Whisper asks which one to name, or **Edit**
    to write it yourself
```

c. Keys table, `{activity}` row
Before:
```
  | `{activity}` | the first activity of their listing |
```
After:
```
  | `{activity}` | the activity of their listing (you pick one when it lists several) |
```

d. Settings page bullet (also folds in v0.2.1's still-open proposal: talent points and the damage meter prompts)
Before:
```
- **Settings page** - in Settings > AddOns: turn each item level spot, Dynamic refresh,
  the animations and region flags on or off, and open the Messages tab from a button
```
After:
```
- **Settings page** - in Settings > AddOns: turn each item level spot, talent points,
  Dynamic refresh, the animations, region flags and the two damage meter prompts on or
  off, move the damage meter prompt, and open the Messages tab from a button
```

e. Usage: `/tgf meter`
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

Reminder only (decide again): of 15-HUMAN-UAT.md item 2's v0.2.1 proposals, none is in README.md yet. Besides the ones folded in above (a: damage meter bullet, d: Settings page, e: `/tgf meter`), these two lines are still as in v0.2.0:
```
- **Region flags** - a US or Oceania flag after each name, your own listing included,
  with the region in the row tooltip
```
(v0.2.1 proposal: a flag for US, Oceania, EU, China, Korea or Taiwan; other regions show their first two letters; the row tooltip names the region)
```
- **Item level** - shown on friendly players' tooltips, on weapon and armor tooltips, as
  a row under Movement Speed on the character sheet, and on the Inspect window
```
(v0.2.1 proposal: "on friendly players' tooltips (with their talent points per tree)")
result: pass (author: none applied; README wording stays as is, only the gif swap ships)

### 4. Screenshot reminder
expected: You retake the prints (agents never make images). `tgf_lfg_message_config.png` predates the activity menu (the Messages tab itself is unchanged; only the `{activity}` key's tooltip text changed, check it if it shows). There is no print of the damage meter prompt (new icon and the game's buttons) or of the activity menu at the cursor. Any print of the Settings page would now show the Move button and the Damage meter section.
result: pass

### 5. Version
expected: Confirm v0.2.2 (TOC keeps `## Version: @project-version@`; tag `v0.2.2` on `main` after the squash merge at milestone completion, per PROJECT.md Git Workflow). Not done by agents.
result: pass

### 6. Deferred in-game checks
expected: Run these in the same session; the release waits on them.
- `.planning/phases/16-small-improvements/16-HUMAN-UAT.md` (8 items): Settings > Damage meter > Move, then Lock / Default; the prompt at the saved spot after /reload; the prompt's look; Move and Edit whisper messages closing Settings; in combat; the activity menu on a listing with several activities (row Whisper and Send Message); a listing with one activity; Ask to reset on joining a group on an existing vs a fresh install
result: pass

### 7. Phase confirmation
expected: The author's confirmation closes Phase 17 and starts the milestone close-out (push, squash-merge, tag).
result: pass

## Summary

total: 7
passed: 7
issues: 0
pending: 0
skipped: 0
blocked: 0

## Gaps
