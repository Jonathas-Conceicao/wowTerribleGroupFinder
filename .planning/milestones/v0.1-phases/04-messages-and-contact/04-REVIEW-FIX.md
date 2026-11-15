---
phase: 04-messages-and-contact
fixed_at: 2026-11-11T00:00:00Z
review_path: .planning/phases/04-messages-and-contact/04-REVIEW.md
iteration: 1
findings_in_scope: 3
fixed: 3
skipped: 0
status: all_fixed
---

# Phase 4: Code Review Fix Report

**Fixed at:** 2026-11-11
**Source review:** .planning/phases/04-messages-and-contact/04-REVIEW.md
**Iteration:** 1

**Summary:**
- Findings in scope: 3 (Info findings IN-01 to IN-04 out of scope)
- Fixed: 3
- Skipped: 0

The three fixes touch the same file and went into one commit (48f8444). The work ran directly on the
branch, not in a separate worktree, as the orchestrator's instructions directed. The smoke harness
ends `SUMMARY: 0 failed` in all four modes (default, `--gs`, `--fallback`, `--attach`).

## Fixed Issues

### WR-01: Byte-based truncation can cut a multi-byte character in half

**Files modified:** `Messages.lua`
**Commit:** 48f8444
**Applied fix:** Added `M.Clip(s)`, which cuts at 255 bytes and backs off while the first dropped byte is a UTF-8 continuation byte. `M.Set` and `M.Format` use it. New smoke probe `msg-clip-utf8` covers 2-byte and 3-byte splits, boundary cuts and short text.

### WR-02: `messaged` / `invited` marked after an unguarded send

**Files modified:** `Messages.lua`
**Commit:** 48f8444
**Applied fix:** The whisper send and `C_PartyInfo.InviteUnit` run in `pcall`. `messaged` and `invited` are set only when the call returned. A comment notes that a send the server later rejects still counts as attempted. Status: fixed, requires human verification (logic change).

### WR-03: Preview rows can open a real whisper to a sample name

**Files modified:** `Messages.lua`
**Commit:** 48f8444
**Applied fix:** With `preview` true and Auto-send off, `M.Send` prints `preview: would open a whisper to <name> with: <text>` and never calls `ChatFrameUtil.SendTellWithMessage`. Smoke probes updated (`lock-noprefill`) and a new check added in `msg-send-invite`. Status: fixed, requires human verification (logic change).

---

_Fixed: 2026-11-11_
_Fixer: Claude (gsd-code-fixer)_
_Iteration: 1_
