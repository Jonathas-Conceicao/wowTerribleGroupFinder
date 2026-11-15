---
phase: 04-messages-and-contact
plan: 03
subsystem: ui
tags: [lua, messages-panel, input-scroll-frame, key-buttons, auto-invite]
requires: [04-01, 04-02]
provides:
  - M.BuildPanel(panel): the one Messages panel builder (Who tab layers, multi-line boxes, key buttons, gated checkboxes)
  - W.Tooltip optional opts (gold title, grey note line)
affects: [04-04]
key-files:
  modified: [Messages.lua, UI/Widgets.lua, UI/MainFrame.lua, UI/InPlace.lua]
key-decisions:
  - "BuildPanel runs its refresher once at the end so the Auto-invite gating is correct before the first show"
  - "Focus lost always saves the normalised text (not only when it changed)"
requirements-completed: [UIP-11, MSG-03, MSG-04, MSG-05]
completed: 2026-11-11
---

# Phase 4 Plan 03: Messages panel Summary

The Messages panel is rebuilt by one function for the game's fourth side tab and the preview stand-in: Who tab layers, 410x56 multi-line preset boxes, seven key buttons per preset, and Auto-invite gated by Auto-send.

## Tasks

1. Harness (outside the repo, not committed): EditBox stubs (cursor, Insert, focus, max letters, SetText firing OnTextChanged), `InputScrollFrameTemplate` and `UICheckButtonTemplate` decorations, five probes (panel-layers, panel-box, panel-keys, panel-gating, panel-default). Ran red (5 FAIL).
2. `M.BuildPanel` rewrite plus `W.Tooltip` opts. Commit `69f1360`.
3. Both hosts reduced to `ns.Messages.BuildPanel(panel)`. Commit `f9d3e59`.

## Harness result (last line of each mode)

- default: `SUMMARY: 0 failed`
- `--gs`: `SUMMARY: 0 failed`
- `--fallback`: `SUMMARY: 0 failed`
- `--attach`: `SUMMARY: 0 failed`

`stylua --check .` passes.

## Deviations from Plan

**1. [Rule 1] Initial Auto-invite state.** The panel's refresher was only run by the host on show; BuildPanel now also runs it once at the end, so Auto-invite is disabled/greyed from the first frame.

**2. Harness only.** The layer-atlas probe asserts the atlases in `--attach` mode (the only mode whose client stub knows atlases) and asserts their absence elsewhere; the gating probe sets Auto-send off first because earlier probes leave saved state.

**3. Acceptance grep.** `groupfinder-background` still appears once in `UI/MainFrame.lua` (the Browse panel's art, line 243, unrelated to Messages); none in `UI/InPlace.lua`.

## Known Stubs

None.

## Threat Flags

None beyond the plan's model. T-04-11: maxLetters 255, newline replaced with a space, Format cut. T-04-12: non-secure box on our own frame, no writes to Blizzard frames. T-04-14: template probe with single-line fallback (probe "panel-box").

## Self-Check: PASSED

- Messages.lua, UI/Widgets.lua, UI/MainFrame.lua, UI/InPlace.lua committed (69f1360, f9d3e59); four harness modes at 0 failed.
