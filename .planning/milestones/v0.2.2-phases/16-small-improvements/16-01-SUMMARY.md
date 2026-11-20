---
phase: 16-small-improvements
plan: 01
subsystem: meter-prompt, settings-panel, messages
tags: [prototype, meter-reset, settings, whisper]
requires: []
provides:
  - Movable damage meter prompt (M.Move / M.EndMove, DB.meterPos), icon left, SharedButtonTemplate buttons
  - SP.AfterClose / SP.CloseThen (Settings closes through its own Close(true))
  - Whisper activity menu with Edit (M.Send(l, preview, from, choice))
affects: [MeterReset.lua, UI/SettingsPanel.lua, Messages.lua, Settings.lua, Core.lua, CLAUDE.md]
tech-stack:
  added: []
  patterns: [MenuUtil.CreateContextMenu with pcall + first-activity fallback, one-time HookScript OnHide]
key-files:
  created: []
  modified: [MeterReset.lua, UI/SettingsPanel.lua, Messages.lua, Settings.lua, Core.lua, CLAUDE.md]
decisions:
  - Prototype committed as is; review found no gaps
metrics:
  completed: 2026-11-19
  tasks: 2
  files: 6
requirements: [MTR-05, MTR-06, MTR-07, SET-01, MSG-01, MSG-02]
---

# Phase 16 Plan 01: Prototype commit Summary

The prototype from after v0.2.1 is now committed unchanged: a movable damage meter prompt with the addon's icon and game-menu buttons, Settings buttons that close the options window first, and an activity menu with Edit when whispering a listing that has several activities.

## Review checklist

| Item | Result | Notes |
|------|--------|-------|
| MTR-05 | OK | `M.Move` defers to `SP.AfterClose` while the panel shows. `StartMove` shows Default / Lock. Lock saves `db.meterPos = { left = left, top = top }` (finite only). Default clears it. `M.EndMove` calls `ns.SettingsPanel.Open()`. `Place` tries `SavedPos()` first. `M.Init(saved)` drops a bad spot. `M.Ask` returns `not dialog.moving` and shows nothing while the prompt is being moved |
| MTR-06 | OK | `MenuButton`: pcall `SharedButtonTemplate`, 120x26, falls back to `ns.W.Button`. All four buttons use it |
| MTR-07 | OK | Uses the existing `tgf_icon_64x64.tga`, 76x76 at LEFT (18, 0). The body frame holds the text (top) and the buttons (bottom, centered). Frame is 380x112 |
| SET-01 | OK | `SP.CloseThen`: in combat or without the panel / Close, it runs fn at once. Otherwise it calls `AfterClose` and then `pcall(panel.Close, panel, true)`, and on failure clears the pending fn and runs it. `AfterClose`: a one-time HookScript, the latest call wins, runs on the next frame. No field is written on the panel |
| MSG-01 | OK | `ActivityChoices` needs the normalized preset to contain `{activity}` and the listing to have 2+ named activities, for solo players and groups alike. `MenuUtil.CreateContextMenu` at the cursor, one entry per activity, which sends as Auto-send says. Without MenuUtil the code falls through to the first activity. Row Whisper and Send Message both go through `Instance:Message` and then `ns.Messages.Send` |
| MSG-02 | OK | Edit passes every activity comma-separated with `edit = true`, which forces auto and autoInvite off: it only prefills the whisper box |
| Taint | OK | No `StaticPopupDialogs[` in any of the three files. SettingsPanel is only hooked and closed through its own Close |

## Commits

- 036453d feat(16): movable damage meter prompt with the addon's icon and game-menu buttons
- 05ee8fe feat(16): pick the activity when whispering a listing with several
- 4b30da4 docs(16): CLAUDE.md for the meter prompt, Settings close and activity menu

## Verification

- `stylua --check .` passes
- Smoke harness: `SUMMARY: 0 failed` in the default, `--attach` and `--fallback` modes
- The two Media/Screenshots files are still untracked

## Deviations from Plan

None. The plan was executed as written, with no gap fixes.

## Self-Check: PASSED
