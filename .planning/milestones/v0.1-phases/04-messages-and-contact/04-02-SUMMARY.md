---
phase: 04-messages-and-contact
plan: 02
subsystem: ui
tags: [lua, lock, pressed-look, buttons]
requires: [04-01]
provides:
  - W.SetPressed(button, on) with re-apply hooks; pushed texture on the flat fallback button
  - Lock guards in Instance:Message / Instance:Invite; from = "row" / "send"
  - Pressed look derived in FillRow and RefreshButtons
affects: [04-03]
key-files:
  modified: [UI/Widgets.lua, UI/Table.lua]
key-decisions:
  - "Pressed state is derived from LockSource()/LockID() on every row fill, never stored per listing on a frame"
  - "Group Invite is never pressed and starts no lock"
requirements-completed: [LOCK-01, LOCK-02, LOCK-03, MSG-06]
duration: ~30 min
completed: 2026-11-11
---

# Phase 4 Plan 02: Lock on the table buttons Summary

Row Whisper, bottom Send Message and Group Invite ignore clicks while the 1 s contact lock runs; the clicked Whisper or Send Message shows the pressed art for that second, following the listing id across recycled row frames.

## Tasks

1. Harness (outside the repo, not committed): `HookScript` chaining with `__hooks`, `log.fire`, `HasScript`, `SetButtonState`/`GetButtonState`, `UIPanelButtonTemplate` with Left/Middle/Right textures, and six probes (lock-row, lock-recycle, lock-send, lock-invite-solo, lock-noprefill, lock-outside).
2. `W.SetPressed` plus table wiring. Commit `f7e5836`.

## Harness result (last line of each mode)

- default: `SUMMARY: 0 failed`
- `--gs`: `SUMMARY: 0 failed`
- `--fallback`: `SUMMARY: 0 failed`
- `--attach`: `SUMMARY: 0 failed`

`stylua --check .` passes.

## Deviations from Plan

**1. Red phase skipped.** The harness probes were written after the implementation (both in one sitting), so no red run was recorded; the probes were validated by first-run failures from stub gaps and probe bugs (stale frame references, missing `HasScript`), all harness-side.

**2. [Rule 3] Harness stub added:** `HasScript` (real frames always have it); probes re-fetch row frames after refresh because the stub ScrollBox recreates frames, and read `GetButtonState()` for released buttons.

**3. Probes build their own Attach instance** (preview source, fixed listings) so they behave the same in all four modes.

## Known Stubs

None.

## Threat Flags

None. `W.SetPressed` touches only our own buttons.

## Self-Check: PASSED

- UI/Widgets.lua, UI/Table.lua modified and committed; four harness modes at 0 failed.
