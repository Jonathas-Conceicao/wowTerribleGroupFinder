---
phase: 03-rows-tooltip-and-own-listing
plan: 04
subsystem: ui-tooltip
tags: [tooltip, refresh, phase-close]
requires: ["03-03"]
provides:
  - "Instance:HoveredRow / Instance:RefreshTooltip wired into every exit of Instance:Refresh"
affects: []
tech-stack:
  added: []
  patterns: ["capture hovered state before the list is re-filled (ScrollBox resetter hides the tooltip), re-show for the frame under the mouse after"]
key-files:
  created: []
  modified: [UI/Table.lua, CLAUDE.md]
key-decisions:
  - "Event-driven only: rides on Refresh, no timers, no OnUpdate"
  - "Only tooltips owned by one of our row frames are touched"
requirements-completed: [UIP-16]
duration: 25min
completed: 2026-11-11
---

# Phase 3 Plan 04: Tooltip refresh and phase close Summary

A hovered row's tooltip now follows the listing under the mouse after each results update, in both list hosts; CLAUDE.md describes the phase 3 table; everything is deployed.

## Tasks

1. Harness probe "tip-refresh" (outside the repo): re-bind, nothing under the mouse, foreign tooltip, searching exit, no timers. Red first (3 failures per host).
2. HoveredRow / RefreshTooltip in UI/Table.lua: commit 2b9d876. The row's hide / message / delist parts under the mouse count as "not the row" and hide the tooltip as stock does.
3. CLAUDE.md bullets (Table, Widgets with W.IconButton, Listings): commit 4fdcf4c.

## Final harness output

- default: SUMMARY: 0 failed
- --gs: SUMMARY: 0 failed
- --fallback: SUMMARY: 0 failed
- --attach: SUMMARY: 0 failed
- `stylua --check .` clean.

## Install output

`powershell .\scripts\install.bat`: "Deploying 13 files derived from TerribleGroupFinder.toc ... Deployed version: 4fdcf4c-dev ... Installed to ...\_forever_\Interface\AddOns\TerribleGroupFinder", exit 0, no missing file.

## Deviations from Plan

1. **[Harness]** The default `IsMouseOver` stub now consults a global `__mouseFn` and the timer stubs count calls (both outside the repo).
2. **Install invocation:** `cmd //c scripts\\install.bat` failed from Git Bash (path mangling); ran through PowerShell instead.
3. **W.List.ForEachFrame** already matched the ScrollBox signature `(frame, item)` over shown frames; no change to Widgets.lua.
4. REQUIREMENTS.md UIP-16 and the ROADMAP plan line ticked by hand.

## Known Stubs

None.

## Threat Flags

None. Only GameTooltip methods are used, and only when our own row owns the tooltip.

## human_needed (in-game, not blocking)

- Delist click from our button raises no ADDON_ACTION_BLOCKED and the own row disappears; delist hidden for a non-leader group member
- Hide icon legibility (`transmog-icon-hidden` / `socialqueuing-icon-eye` at 16 px in 24x22, else the x / + fallback ships; never a red X)
- Micro role icons 18 px legible and square
- Discord icon level with the name; name truncation
- Tooltip order and wording against the stock tooltip on the same listing; playstyle shows (function or global fallback)
- Tooltip refresh while hovering during a results update and while scrolling
- Needs my role on a quest / custom-activity group (remaining-slot semantics)
- Atlas existence: `UI-ChatIcon-Discord`, `groupfinder-icon-role-micro-*`, `newplayerchat-chaticon-newcomer`, `groupfinder-icon-leader`
- No taint messages with `/console taintLog 1` while hovering rows and clicking delist / hide
- Q1 620 width with Activity readable
- Then `/reload` in game

## Self-Check: PASSED

Commits 2b9d876 and 4fdcf4c present; UI/Table.lua and CLAUDE.md modified.
