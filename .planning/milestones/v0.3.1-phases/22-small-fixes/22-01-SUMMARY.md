---
phase: 22-small-fixes
plan: 01
subsystem: quest-eye
tags: [lua, taint, error-guards]
requires: []
provides:
  - "Elite quest eye hover and click steps guarded (QST-05)"
affects: [QuestButton.lua]
tech-stack:
  added: []
  patterns: ["Fail / Try / Guarded helpers", "clear secure attribute before any read that can fail"]
key-files:
  modified: [QuestButton.lua]
decisions:
  - "Try returns up to four results so Arm's macro build can return text, quest and activity"
  - "After always resets the armed state after its guarded body"
metrics:
  completed: 2026-11-26
---

# Phase 22 Plan 01: Elite quest eye guards Summary

Every hover, leave, press, layout recheck, cover build, click, hint and outline step of the elite quest eye now runs under `Try` / `Guarded`, with secure attributes cleared first so a failure leaves no stale macro.

## What changed

- `Fail` / `Try` / `Guarded` helpers: the error goes to `Q.lastError`, one `Quest eye: <step> failed` chat line per distinct step per session.
- `Pass`, eye scripts (tooltip and cover independent), cover scripts and the combat-start handler guarded; `EyeDown` / `EyeUp` nil-safe.
- `BuildCover` idempotent: delegates and the events frame built once; `cover = c` assigned last. `Q.Cover` / `Q.Recheck` / `Q.Uncover` nil-check the cover, the eye and its methods.
- `Arm` clears `macrotext` first and sets it only from a successful build; both delegates clear `clickbutton` first.
- `CategoryButton` / `ActivityCheck` / `FocusDescription` / hint / outline use type checks and `PlainNumber`; `After` guarded and always resets `armed`; `Q.ShowHint` guarded, outline stopped on failure; `Q.Click` nil-checked.
- `/tgf quest` appends `failed steps: ...`.

Route unchanged: same macro lines, `/click` targets and delegates; no new writes on Blizzard frames.

## Deviations from Plan

None beyond `Try` returning four results instead of two (needed by Arm's build).

## Verification

`stylua --check .` clean. Grep assertions hold. In-game checks go to 22-HUMAN-UAT.md (Plan 04); no Lua interpreter was available for a syntax check.

## Commits

- c3459a9: guard hover, cover build and removal
- 795219e: clear-first attributes, guarded click steps, probe

## Self-Check: PASSED
