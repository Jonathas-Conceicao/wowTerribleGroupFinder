---
phase: 04-messages-and-contact
fixed_at: 2026-11-11T00:00:00Z
review_path: .planning/phases/04-messages-and-contact/04-REVIEW.iter2.md
iteration: 2
findings_in_scope: 3
fixed: 3
skipped: 0
status: all_fixed
---

# Phase 4: Code Review Fix Report (iteration 2)

**Source review:** .planning/phases/04-messages-and-contact/04-REVIEW.iter2.md
**Scope:** WR-04, IN-05, IN-06 (IN-01..IN-04 left as instructed)

## Fixed Issues

All three share one commit (same function and file), made directly on the branch
`milestone/v0.1-milestone` rather than in a separate worktree, because the smoke harness reads the repo path.

### WR-04: InviteUnit index outside the pcall; invite runs after a failed whisper

**Files modified:** `Messages.lua`
**Applied fix:** the invite now requires `C_PartyInfo and C_PartyInfo.InviteUnit` before the pcall, and only runs after the whisper call succeeded.
Status: fixed (logic change; worth a quick human look).

### IN-05: Failed send is silent and still locks

**Files modified:** `Messages.lua`
**Applied fix:** on a failed send `ns.Print("could not send the whisper to <name>.")`, nothing is marked, no lock starts, `Send` returns false.

### IN-06: Box shows more than is stored for multi-byte text

**Files modified:** `Messages.lua`
**Applied fix:** after `M.Set` in `OnEditFocusLost` and in the key-button handler, `M.Get(kind)` is re-read and the box is reset with `SetText` when it differs.

Commit: see `git log` ("fix(04): WR-04 IN-05 IN-06 ..."). `stylua .` run.

## Verification

Smoke harness in all four modes (default, `--gs`, `--fallback`, `--attach`): each ends `SUMMARY: 0 failed`.
New probe `msg-send-fails` (in the harness `tail.lua`): a failing SendChatMessage stub gives no invite call, no mark, no lock and a printed notice.

---

_Fixer: Claude (gsd-code-fixer)_
_Iteration: 2_
