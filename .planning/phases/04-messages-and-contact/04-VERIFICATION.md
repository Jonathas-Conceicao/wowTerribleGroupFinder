---
phase: 04-messages-and-contact
verified: 2026-11-11T00:00:00Z
status: human_needed
score: 5/5 must-haves verified (automatable parts)
overrides_applied: 0
human_verification:
  - test: "Click Whisper on a solo player's row with Auto-send and Auto-invite on, in the game"
    expected: "The whisper goes out, then the group invite; the button stays pressed for 1 s; every whisper / invite button, including Send Message, ignores clicks until it ends"
    why_human: "Real whisper / invite and chat lockdown behaviour need the live client"
  - test: "Look at the pressed look on a row's Whisper button and on the bottom Send Message button during the 1 s lock, including after scrolling (recycled rows)"
    expected: "Clicked button looks pressed, no other row looks pressed"
    why_human: "Visual"
  - test: "Open the Messages side tab in Forever's finder"
    expected: "Starts unchecked, never checked with another tab, icon fills like the stock tabs, stock-style tooltip"
    why_human: "Visual, template behaviour in the real client"
  - test: "Inspect the Messages panel"
    expected: "Who-tab layers, multi-line preset boxes, key buttons laid out in two rows, native checkboxes with sounds, Auto-invite greyed with Auto-send off"
    why_human: "Panel layout and look cannot be judged without the client"
---

# Phase 4: Messages and Contact Verification Report

**Phase Goal:** Players contact others in one click from sensible default presets, with Auto-send and Auto-invite, and cannot spam
**Status:** human_needed
**Re-verification:** No, initial verification

## Observable Truths

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | Default request renders `[TGF] Level 23 Warrior, for The Deadmines`; invite renders `[TGF] Group for <activity> with <n> players`, n = group size | VERIFIED | `Messages.lua` DEFAULTS use `{addon}` and `{players}`; `Format` fills `addon=[TGF]` and `players=ns.GroupSize()` (Core.lua:90); smoke `panel-default: request` passes |
| 2 | A button per key inserts it at the cursor; addon key first and at most once | VERIFIED | `M.KEYS` (7 keys); key buttons in `BuildPanel` use `edit:Insert`; `{addon}` button prepends via `Normalize`, which strips duplicates and literal `[TGF]` and puts one `{addon}` first; `Format` also normalises |
| 3 | Invite preset has Auto-send then Auto-invite; Auto-invite greyed unless Auto-send, unchecks with it; both on: one click whispers then invites | VERIFIED | `M.Set` clears `autoInvite` when auto goes false; `M.Get` returns autoInvite only with auto; `SyncAutoInvite` disables, unchecks and greys the label; `M.Send` sends the whisper, then `C_PartyInfo.InviteUnit(target)` by plain name, only if `ns.CanInvite()`; request preset has no autoInvite |
| 4 | After an auto-send the clicked button stays pressed 1 s and all whisper / invite buttons, including Send Message, ignore clicks | VERIFIED (code) | `M.StartLock` (GetTime deadline plus 1 s timer, generation guard); `Instance:Message` and `Instance:Invite` return early on `Locked()`; the row button and Send Message both go through `Instance:Message` (Table.lua:868, 1587); `W.SetPressed` applied per row from `LockSource/LockID` (Table.lua:1123) and on the send button (1321). Visual result is human-checked |
| 5 | Messages side tab: unchecked at start, never checked with another tab, icon fill, stock tooltip; panel with Who layers, multi-line boxes, native checkboxes | VERIFIED (code) / human for looks | `InPlace.lua` `AddMessagesTab`: `SetChecked(false)`, `SetFillToInterior`, `hooksecurefunc(LFGParentFrame, "UpdateTabs")` unchecks stock tabs, `HideMessages` on stock frames' OnShow, `tooltipText`; `BuildPanel` has `BuildLayers`, `InputScrollFrameTemplate` boxes, `W.Check`; one builder shared by the game and the preview (InPlace:142, MainFrame:355); smoke `tab-uip01` passes |

**Score:** 5/5 verified from code and harness

## Automated Checks

| Check | Result |
|-------|--------|
| smoke harness `run.js` | SUMMARY: 0 failed |
| `--gs` | SUMMARY: 0 failed |
| `--fallback` | SUMMARY: 0 failed |
| `--attach` | SUMMARY: 0 failed; restricted calls never invoked (0) |
| `stylua --check .` | clean |
| TBD / FIXME / XXX markers in `*.lua`, `UI/*.lua` | none |

## Requirements Coverage

| Requirement | Status | Evidence |
|-------------|--------|----------|
| MSG-01 | SATISFIED | DEFAULTS.request, `Format` |
| MSG-02 | SATISFIED | DEFAULTS.invite, `{players}` from `ns.GroupSize()` |
| MSG-03 | SATISFIED | key buttons in `BuildPanel` |
| MSG-04 | SATISFIED | `Normalize`, `{addon}` button |
| MSG-05 | SATISFIED | `M.Set` / `M.Get` / `SyncAutoInvite` |
| MSG-06 | SATISFIED (code); live send is human-checked | `M.Send` whisper then invite |
| LOCK-01 | SATISFIED | `Locked()` guards in `Instance:Message` and `Instance:Invite`, `M.Send` |
| LOCK-02 | SATISFIED (code); look is human-checked | `W.SetPressed`, `LockSource` / `LockID` |
| LOCK-03 | SATISFIED | Send Message calls `Instance:Message(..., "send")` |
| UIP-01 | SATISFIED (code); look is human-checked | `AddMessagesTab` |
| UIP-11 | SATISFIED (code); look is human-checked | `BuildLayers`, `PresetBox`, `W.Check`, disabled look |

All 11 IDs in the ROADMAP are accounted for in REQUIREMENTS.md; none orphaned. Boxes remain unticked on purpose.

## Anti-Patterns

None found. Chat lockdown is respected (`InChatMessagingLockdown` falls back to prefilling the whisper box); restricted calls are never invoked; Blizzard's frames are hooked, not written to.

## Human Verification Required

1. **Live auto-send plus auto-invite.** Whisper on a solo row with both options on. Expect whisper, then invite, a 1 s pressed button, and all contact buttons inert for that second.
2. **Pressed look.** Row Whisper and bottom Send Message during the lock, including recycled rows after scrolling.
3. **Messages side tab.** Unchecked at start, never checked with another tab, icon fill, tooltip.
4. **Messages panel.** Who-tab layers, multi-line boxes, key button rows, checkbox sounds, Auto-invite greyed look.

## Gaps Summary

No gaps. Everything automatable passes; the remaining items need the live client.

---

_Verified: 2026-11-11_
_Verifier: Claude (gsd-verifier)_
