---
phase: 22-small-fixes
plan: 02
subsystem: invites
tags: [lua, invite-outcome]
requires: []
provides:
  - "Invite outcome on the row's Listed cell (INV-01, INV-02)"
affects: [Messages.lua, UI/Table.lua]
key-files:
  modified: [Messages.lua, UI/Table.lua]
decisions:
  - "ns.state.invited[id] is now a table {name, at, outcome}; M.MarkInvited is the only writer"
metrics:
  completed: 2026-11-26
---

# Phase 22 Plan 02: Invite outcome Summary

An invited row now reads invited, accepted, declined or expired in the Listed cell, resolved from the game's system messages, the roster and a timer.

## What changed

- Messages.lua: `M.MarkInvited(l, preview)` (new table per invite, 120 s expiry timer, preview cycle accepted / declined / expired after 2-4 s). Patterns built from the `ERR_*` globals; `CHAT_MSG_SYSTEM` guarded with `issecretvalue`; `GROUP_ROSTER_UPDATE` checks `UnitInParty` / `UnitInRaid` under pcall; a decline 55 s or more after the invite reads expired; redraw waits while `Motion.Busy()`.
- UI/Table.lua: `Instance:Invite` uses `M.MarkInvited`; the Listed cell shows the word per outcome (green, red, grey; bare word on greyed rows). Delisted still wins, whisper-only keeps "sent".
- Listings.lua unchanged (Carry shares the table by reference).

## Deviations from Plan

None.

## Verification

`stylua --check .` clean; grep checks hold (no remaining `invited[l.id] = true`). In-game checks go to 22-HUMAN-UAT.md (Plan 04).

## Commits

- Messages.lua outcome tracking
- UI/Table.lua Listed cell and Group Invite

## Self-Check: PASSED
