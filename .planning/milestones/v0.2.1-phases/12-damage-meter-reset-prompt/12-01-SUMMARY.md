---
phase: 12-damage-meter-reset-prompt
plan: 01
subsystem: meter-reset
tags: [meter, prompt, settings]
requires: []
provides: [MTR-01, MTR-02, MTR-03, MTR-04]
affects: [MeterReset.lua, CLAUDE.md]
key-files:
  modified: [MeterReset.lua, CLAUDE.md]
key-decisions:
  - "Prompt starts with the plain [TGF] tag (no colour code), same as the whispers"
metrics:
  completed: 2026-11-16
---

# Phase 12 Plan 01: Damage Meter Reset Prompt Summary

The damage meter reset prompt now asks "[TGF] Reset Details! damage meter?" or "[TGF] Reset the damage meter?", and the triggers, meter choice, settings and `/tgf meter` were confirmed in source.

## Tasks

1. MTR-03: `M.Ask()` text prefixed with `[TGF] `; header comment and CLAUDE.md (MeterReset line, settings sections list) updated. Commit 6ec43f0.
2. MTR-01/02/04: read-only source assertions all passed (triggers, meter choice, one dialog, single `M.Reset()` caller, settings section with both options default on, `/tgf meter`, TOC and Core wiring). No edits needed.

`stylua --check .` is clean; CHANGELOG.md and README.md untouched.

## Deviations from Plan

None - plan executed as written.

## HUMAN-UAT

1. Details! loaded, join a group: "[TGF] Reset Details! damage meter?" with Yes / No; Yes clears Details! and prints "Details! reset."; No leaves it.
2. Details! disabled, game meter on: join a group -> "[TGF] Reset the damage meter?"; Yes clears the game's meter. Game meter off and no Details!: nothing asked; `/tgf meter` prints "no damage meter to reset: ...".
3. Enter a dungeon / raid / battleground: asked once. `/reload` inside: not asked. Leave and enter another instance: asked.
4. Settings -> AddOns -> TerribleGroupFinder: "Damage meter" section with both options on; turn "Ask to reset on joining a group" off -> joining doesn't ask; turn "Ask to reset on entering an instance" off -> entering doesn't ask.
5. `/tgf meter` shows the prompt at any time; a second `/tgf meter` while it shows keeps one dialog.
6. Screenshot reminder: this is a new dialog; the author decides whether a README print is wanted.

## Self-Check: PASSED
