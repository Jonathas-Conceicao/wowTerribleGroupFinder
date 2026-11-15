---
phase: 04-messages-and-contact
reviewed: 2026-11-11T00:00:00Z
depth: standard
iteration: 2
files_reviewed: 6
files_reviewed_list:
  - Core.lua
  - Messages.lua
  - UI/InPlace.lua
  - UI/MainFrame.lua
  - UI/Table.lua
  - UI/Widgets.lua
findings:
  critical: 0
  warning: 1
  info: 5
  total: 6
status: issues_found
---

# Phase 4: Code Review Report (re-review, iteration 2)

**Reviewed:** 2026-11-11
**Depth:** standard
**Status:** issues_found

## Summary

The fix commit `48f8444` resolves WR-01 (UTF-8 clip; `M.Clip` correct including the
all-continuation-byte case), WR-02 (pcall on send / invite) and WR-03 (preview never calls the chat
API; lockdown still prefills). No regressions; plain names, no field writes on Blizzard frames.
IN-01, IN-02, IN-03 from iteration 1 are still present (not escalated); IN-04 is intentional (D-01).

## Warnings

### WR-04: InviteUnit index outside the pcall; invite runs after a failed whisper

**File:** `Messages.lua:~246`

`pcall(C_PartyInfo.InviteUnit, target)` indexes `C_PartyInfo` before `pcall` runs, so a missing
`C_PartyInfo` throws outside the guard. Also the invite runs even when the whisper pcall failed, then
the lock starts and `Send` returns true, so a failed send looks like a success.

**Fix:** guard `C_PartyInfo and C_PartyInfo.InviteUnit` before the pcall; only invite when the whisper
call succeeded; keep the two outcomes separate.

## Info

### IN-05: Failed send is silent and still locks

**File:** `Messages.lua:~243-245`

When the send pcall fails the error is dropped; the user sees the lock but no whisper.

**Fix:** on failure, `ns.Print("could not send the whisper to <name>.")` and do not start the lock.

### IN-06: Box shows more than is stored for multi-byte text

**File:** `Messages.lua:~103, ~326, ~397-401`

`SetMaxLetters(255)` counts characters; `M.Clip` / `M.Set` cut at 255 bytes. After focus lost the box
can show longer text than the DB holds.

**Fix:** after `M.Set` in `OnEditFocusLost` and in the key-button handler, re-read `M.Get(kind)`; if it
differs from `e:GetText()`, `SetText` the stored value.

### IN-01, IN-02, IN-03

Unchanged from iteration 1 (`Messages.lua:~428`, `~377`, `~383-388`).

---

_Reviewed: 2026-11-11_
_Reviewer: gsd-code-reviewer (standard depth, iteration 2)_
