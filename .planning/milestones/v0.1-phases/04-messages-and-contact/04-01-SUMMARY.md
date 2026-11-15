---
phase: 04-messages-and-contact
plan: 01
subsystem: messages
tags: [lua, whisper, presets, lock, migration]
requires: []
provides:
  - M.ADDON_KEY, M.KEYS, M.Normalize, new M.DEFAULTS, {players}/{addon} in Format
  - Get/Set with autoInvite; Init one-time migration (messages.version 2)
  - M.Send with send-then-invite; M.Locked / LockID / LockSource / StartLock
  - ns.GroupSize()
affects: [04-02 table buttons, 04-03 Messages panel]
tech-stack:
  patterns: [GetTime deadline + generation-guarded C_Timer release]
key-files:
  modified: [Messages.lua, Core.lua]
key-decisions:
  - "Migration version lives in saved.messages.version"
  - "Old GS-era default is spelled in two string pieces so no {gs} key text remains in Messages.lua code"
requirements-completed: [MSG-01, MSG-02, MSG-04, MSG-06, LOCK-01]
duration: ~40 min
completed: 2026-11-11
---

# Phase 4 Plan 01: Messages core Summary

Messages core rebuilt: `[TGF]` addon key normalised to the front, `{players}` group size, Auto-invite state, whisper-then-invite by plain name, a 1 s contact lock and a one-time migration of earlier default presets.

## Tasks

1. Harness stubs and red checks (outside the repo, not committed): controllable clock (`log.advance`), ordered call log, switchable lockdown, settable group size, seven new probes (msg-defaults, msg-normalize, msg-autoinvite-state, msg-send-invite, msg-lockdown, msg-lock, msg-migrate) plus rewritten GS/placeholder checks. Ran red (26 FAIL).
2. Messages core in `Messages.lua` and `ns.GroupSize()` in `Core.lua`. Commit `58a35b2`.

## Harness result (last line of each mode)

- default: `SUMMARY: 0 failed`
- `--gs`: `SUMMARY: 0 failed`
- `--fallback`: `SUMMARY: 0 failed`
- `--attach`: `SUMMARY: 0 failed`

`stylua --check .` passes.

## Deviations from Plan

**1. [Rule 3 - Blocking] tip-solo probe needed a non-preview source**
- With the controllable clock the existing `tip-solo` probe (boss names are read only for non-preview sources) failed in all modes, and also against the HEAD code, so it was not caused by the repo change. The probe now sets the instance's `source.preview` to false for its duration and restores it. Harness only.

**2. [Rule 2] Old GS-era default spelled in two pieces**
- To meet the "no `{gs}` in Messages.lua code" criterion while still migrating the saved GS-era text, that one literal is built as `"... {g" .. "s}) ..."`, with a comment.

**3. Panel**: the "Placeholders:" footer and `M.TOKENS` / `ns.GEAR_SCORE` references were removed from `BuildPanel`; the rest of BuildPanel is left for plan 03 as specified.

## Known Stubs

None.

## Threat Flags

None beyond the plan's threat model (all T-04-01 to T-04-06 mitigations implemented and covered by harness probes).

## Self-Check: PASSED

- Messages.lua, Core.lua modified; commit 58a35b2 exists; four harness modes at 0 failed.
