---
phase: 04-messages-and-contact
reviewed: 2026-11-11T00:00:00Z
depth: standard
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
  warning: 3
  info: 4
  total: 7
status: issues_found
---

# Phase 4: Code Review Report

**Reviewed:** 2026-11-11
**Depth:** standard
**Files Reviewed:** 6 (CLAUDE.md is documentation and was only read for conventions)
**Status:** issues_found

## Summary

No blockers. The CLAUDE.md rules hold in the phase 4 changes: the `UpdateTabs` hook uses
`hooksecurefunc` and `fillToInterior` is written on our own tab frame only; `M.Send` checks
`InChatMessagingLockdown` before any auto-send or auto-invite; whispers and invites use the plain
`l.leader.name`; `ns.GroupSize` guards `GetNumGroupMembers` with `issecretvalue`; the migration only
replaces a saved text equal to an old default, once; the panel fits `LFGParentFrame`'s 535 px height
(about 516 used); dropping `W.Tooltip` on the side tab is safe since `SidePanelTabButtonMixin:OnEnter`
shows `tooltipText`.

## Warnings

### WR-01: Byte-based truncation can cut a multi-byte character in half

**Files:** `Messages.lua` `M.Set` (~85) and `M.Format` (~146); box limit `SetMaxLetters(255)` (~301, ~313)

`SetMaxLetters(255)` counts characters but `text:sub(1, MAX)` counts bytes. A preset with non-ASCII
text is cut shorter than the box shows and can end mid-character (invalid UTF-8). `Format` has the
same problem: `{class}` expands to a localised class name, so on ruRU / zhCN the rendered text can
pass 255 bytes and be cut mid-character before it is whispered.

**Fix:** a `Clip(s)` helper that cuts at `MAX` bytes and then backs off while the next byte is a UTF-8
continuation byte (0x80-0xBF); use it in `Set` and `Format`. Keep `SetMaxLetters` as the UI limit.

### WR-02: `messaged` / `invited` marked after an unguarded send

**File:** `Messages.lua` `M.Send` (~217-226)

`ns.state.messaged[l.id]` and `invited[l.id]` are set right after the send / `C_PartyInfo.InviteUnit`
call with no guard. If a call errors, the row still shows as contacted.

**Fix:** call the send and the invite in `pcall`; mark `messaged` / `invited` only when the call
returned without error. (A successful call that the server later rejects — offline, throttled — still
counts as "attempted"; document that in the comment.)

### WR-03: Preview rows can open a real whisper to a sample name

**File:** `Messages.lua` `M.Send` (~203-234)

The preview branch is taken only when `auto and preview`. With Auto-send off in the preview, the code
falls through to `ChatFrameUtil.SendTellWithMessage(target, text)` and opens a real whisper box to a
sample character.

**Fix:** when `preview` is true, never call the chat API: print
`preview: would open a whisper to <name> with: <text>` instead (as the auto branch prints).

## Info

### IN-01: Key-button wrap can make a third row over Auto-send

**File:** `Messages.lua` (~403)

The wrap uses a hard-coded `i == 5` plus a width test. If the width test already wrapped earlier, the
`i == 5` rule wraps again: a third row at y -134 overlaps the checkbox row at -138 (only with unusually
wide labels).

**Fix:** only force the break at `i == 5` while still on the first row (or rely on the width test alone
and never start a third row).

### IN-02: Example listing picked by position

**File:** `Messages.lua` (~352)

`ns.Preview.listings[#ns.Preview.listings]` stands in for a solo player. If the sample data changes
order, the invite example shows a group.

**Fix:** pick the first sample with `l.solo` for invite and the first without for request.

### IN-03: Pasted newlines move the cursor

**File:** `Messages.lua` (~356-365)

Stripping newlines with `e:SetText(text)` during user input resets the cursor.

**Fix:** keep the cursor: read `GetCursorPosition()` before, subtract the removed characters before it,
`SetCursorPosition` after.

### IN-04: Unknown keys are whispered literally

**File:** `Messages.lua` `M.Format` (~143-145)

A custom preset containing `{gs}` or a typo like `{Name}` is whispered with the braces.
**Intentional (CONTEXT D-01):** unknown keys render literally so the player sees them in the example
line. No change.

---

_Reviewed: 2026-11-11_
_Reviewer: gsd-code-reviewer (standard depth)_
