---
phase: 16-small-improvements
verified: 2026-11-19T18:00:00Z
status: passed
score: 5/5 roadmap success criteria verified in code (12/12 plan truths); in-game behaviour pending human checks
overrides_applied: 0
human_verification:
  - test: "Settings > Damage meter > Move, then Lock / Default"
    expected: "Settings closes and the prompt shows to drag with Default / Lock; Lock saves the spot, Default goes back to the automatic spot; both reopen the addon's Settings page"
    why_human: "Needs the live Settings panel, dragging and SettingsPanel:Close in the client"
  - test: "The prompt at the saved spot after /reload"
    expected: "After Lock and /reload, /tgf meter (and the next real prompt) opens at the saved spot; after Default it opens below the game's popups / zone name again"
    why_human: "SavedVariables round trip and on-screen placement"
  - test: "The prompt's look"
    expected: "The addon's purple-eye icon on the left at about the prompt's height; Yes / No (and Default / Lock) in the game menu's red button style"
    why_human: "Visual: SharedButtonTemplate and icon size can only be judged on screen"
  - test: "Move and Edit whisper messages close Settings"
    expected: "Both close the Settings window first, then act; with an unapplied game setting the game still asks about it before closing"
    why_human: "Depends on Blizzard's SettingsPanel Close / discard popup at runtime (and taint behaviour)"
  - test: "In combat"
    expected: "Move / Edit whisper messages close nothing in combat (Settings stays open); the action waits or refuses as before"
    why_human: "InCombatLockdown only in the live client"
  - test: "Activity menu on a listing with several activities (row Whisper and Send Message)"
    expected: "A menu at the cursor lists each activity and Edit; an activity sends (or prefills, per Auto-send) with that activity; Edit only prefills the whisper box with every activity; closing the menu sends nothing"
    why_human: "MenuUtil context menu, chat send and invite need the live client"
  - test: "Listing with one activity"
    expected: "Whisper sends as before, with no menu"
    why_human: "Live group finder data"
  - test: "Ask to reset on joining a group: existing install vs fresh install"
    expected: "Existing install: option stays on and joining a group asks; fresh install (SavedVariables file renamed first): option shows off and joining a group doesn't ask; entering an instance still asks on both"
    why_human: "Real SavedVariables load and group join events"
---

# Phase 16: Small Improvements Verification Report

**Phase Goal:** The damage meter prompt can be placed where the player wants and looks like the game's own menus, the Settings page's buttons act at once, whispers to multi-activity listings name the right activity, and new installs aren't asked to reset the meter on every group join
**Verified:** 2026-11-19
**Status:** human_needed
**Re-verification:** No (initial verification)

## Goal Achievement

### Observable Truths (ROADMAP success criteria)

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | Settings > Damage meter > Move closes Settings and shows the prompt to drag; Lock saves, Default returns to the automatic spot, both reopen Settings; next prompt opens at the saved spot; a bad saved spot is dropped on load | VERIFIED (code) | Move button `UI/SettingsPanel.lua:69-79` -> `SP.CloseThen(ns.MeterReset.Move)`; `M.Move` `MeterReset.lua:297-304` -> `StartMove` `:285-293` (moving flag, Default/Lock shown, drag only while moving `:181-190`); Default clears `db.meterPos` `:236-242`; Lock saves `{ left, top }` when finite `:243-250`; `M.EndMove` hides and calls `ns.SettingsPanel.Open()` `:307-318`; `Place` uses `SavedPos()` first `:123-129`, else below zone text / lowest StaticPopup `:130-157`; `M.Init` drops a non-finite spot `:399-403` (`Finite` `:110-112`); `meterPos` reserved `Settings.lua:21`; `ns.MeterReset.Init(ns.db)` `Core.lua:300`; a prompt never shows during a move `MeterReset.lua:273-275` |
| 2 | The prompt shows the purple-eye icon on its left at about its height, the question and Yes/No (Lock/Default) beside it, in `SharedButtonTemplate` (panel button fallback) | VERIFIED (code; look needs human) | `MenuButton` pcall `SharedButtonTemplate` 120x26, fallback `ns.W.Button` `MeterReset.lua:162-171`; all four buttons use it `:222-250`; icon `tgf_icon_64x64` (exists in `Media/Textures/`) 76x76 at LEFT in a 380x112 frame `:103,176,209-213`; body (text top, buttons bottom) right of the icon `:214-232` |
| 3 | Fresh install: "Reset when joining a group" off; earlier saved data keeps it on unless turned off | VERIFIED | `default = false` `Settings.lua:176`, others default true `:186-189`; `DEFAULTS.schema = 3` `Core.lua:26`; `ns.Migrate` reads `existing = next(db) ~= nil` first `:38`, saves `meterResetOnGroup = true` only for an existing table with a non-boolean value, schema < 3 `:41-46`; Migrate runs before DEFAULTS are filled `:289-294`; trigger reads `ns.Settings.Get("meterResetOnGroup")` where it acts `MeterReset.lua:393`. A v0.2.1 user always has `schema = 2` saved, so `next(db)` is non-nil for them |
| 4 | Move and Edit whisper messages close Settings through its own `Close` (unapplied settings still ask), act once closed; in combat nothing closes and the action waits as before | VERIFIED (code; runtime needs human) | `SP.CloseThen` `UI/SettingsPanel.lua:112-126`: in combat / no panel / no Close -> fn now; else `SP.AfterClose(fn)` then `pcall(panel.Close, panel, true)`; on failure runs fn. `SP.AfterClose` one-time `HookScript("OnHide")`, runs on the next frame `:94-107`. Blizzard `SettingsPanelMixin:Close(skipTransition)` shows `GAME_SETTINGS_CONFIRM_DISCARD` when settings are unapplied (wow-ui-source `forever`, `Blizzard_SettingsPanel.lua:256-262`). Both buttons wired `:74`, `:81-83`. In combat: `M.Move` defers to AfterClose `MeterReset.lua:298-301`; `IP.OpenMessages` refuses as before `UI/InPlace.lua:438-440` |
| 5 | Multi-activity listing + `{activity}` preset: menu at cursor; pick whispers (per Auto-send); closing sends nothing; Edit only fills the box with every activity; one activity or no `{activity}` as before | VERIFIED (code; runtime needs human) | `ActivityChoices` needs `{activity}` in the normalized preset and 2+ named activities `Messages.lua:213-228`; `ChooseActivity` `MenuUtil.CreateContextMenu` with one button per activity + divider + Edit `:239-257`; `M.Send` opens the menu only without a `choice` and returns without sending `:265-275`; Edit passes `table.concat(names, ", ")` with `edit = true`, which forces `auto, autoInvite = false` `:253,280-282`; no MenuUtil / pcall failure -> first activity (`M.Format` default `:148`). Both entry points go through `Instance:Message` -> `ns.Messages.Send` `UI/Table.lua:710-716` (row `:1080`, Send Message `:1932`) |

**Score:** 5/5 truths verified in code. All 7 plan-level truths of 16-01 and 5 of 16-02 also hold (prototype committed in 036453d / 05ee8fe / 4b30da4, MTR-08 in 51512b2; the two `Media/Screenshots` files are still untracked).

### Required Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `MeterReset.lua` | Movable prompt, icon, SharedButtonTemplate | VERIFIED | 408 lines, contains `SharedButtonTemplate`, `M.Move`, `M.EndMove`, `db.meterPos = { left = left, top = top }` |
| `UI/SettingsPanel.lua` | Move button, `SP.AfterClose`, `SP.CloseThen` | VERIFIED | `function SP.CloseThen` at :112 |
| `Messages.lua` | Activity menu with Edit | VERIFIED | `CreateContextMenu` at :243 |
| `Settings.lua` | `meterPos` reserved; `meterResetOnGroup` default false | VERIFIED | :21, :176 |
| `Core.lua` | schema 3 Migrate, `ns.MeterReset.Init(ns.db)` | VERIFIED | :26, :37-47, :300 |
| `CLAUDE.md` | Updated module lines | VERIFIED | schema 3, meter prompt move / CloseThen, new default described (lines 24, 25, 30, 38) |

### Key Link Verification

| From | To | Via | Status |
|------|----|-----|--------|
| Settings Move button | `ns.MeterReset.Move` | `SP.CloseThen(ns.MeterReset.Move)` `UI/SettingsPanel.lua:74` | WIRED |
| Settings Edit whisper messages | `ns.InPlace.OpenMessages` | `SP.CloseThen(ns.InPlace.OpenMessages)` `:82` | WIRED |
| MeterReset Lock | `DB.meterPos` | `db.meterPos = { left = left, top = top }` `MeterReset.lua:246` | WIRED |
| Lock / Default | Settings page | `M.EndMove` -> `ns.SettingsPanel.Open()` `:317` | WIRED |
| `ns.Migrate` | `db.meterResetOnGroup` | `next(db)` read first `Core.lua:38` | WIRED |
| ADDON_LOADED | Migrate before DEFAULTS | `Core.lua:289-294` | WIRED |
| Group trigger | `ns.Settings.Get("meterResetOnGroup")` | `MeterReset.lua:393` | WIRED |
| Row Whisper / Send Message | activity menu | `Instance:Message` -> `ns.Messages.Send` `UI/Table.lua:714` | WIRED |

### Data-Flow Trace (Level 4)

| Artifact | Data | Source | Real data | Status |
|----------|------|--------|-----------|--------|
| Prompt position | `db.meterPos` | Lock -> `f:GetLeft()/GetTop()`; read by `Place` | Yes | FLOWING |
| Activity menu | `names` | `l.acts` from `ns.Listings` (live results) | Yes | FLOWING |
| Group-join default | `Settings.Get` | saved boolean or option default | Yes | FLOWING |

### Behavioral Spot-Checks

| Behavior | Command | Result | Status |
|----------|---------|--------|--------|
| Formatting | `stylua --check .` | exit 0 | PASS |
| Smoke harness (default) | `node .../smoke/run.js .` | `SUMMARY: 0 failed` | PASS |
| Smoke harness (attach) | `node .../smoke/run.js . --attach` | `SUMMARY: 0 failed` | PASS |
| Smoke harness (fallback) | `node .../smoke/run.js . --fallback` | `SUMMARY: 0 failed` | PASS |

The harness has phase-specific checks: activity menu (entries, nothing sent before a choice, chosen activity, Edit prefill with every activity, no-MenuUtil fallback, one activity no menu), meter move (bad spot dropped on load, good spot kept), `CloseThen`, settings layout order (Move under Damage meter, Edit whisper messages under Messages), and the schema 3 / `meterResetOnGroup` cases (21 references).

### Probe Execution

Not applicable: no `scripts/*/tests/probe-*.sh` declared or present for this phase.

### Requirements Coverage

| Requirement | Source Plan | Status | Evidence |
|-------------|-------------|--------|----------|
| MTR-05 | 16-01 | SATISFIED (code) | `UI/SettingsPanel.lua:69-79`; `MeterReset.lua:115-129, 236-250, 297-318, 399-403` |
| MTR-06 | 16-01 | SATISFIED (code) | `MeterReset.lua:162-171, 222-250` |
| MTR-07 | 16-01 | SATISFIED (code) | `MeterReset.lua:103, 176, 209-232` |
| MTR-08 | 16-02 | SATISFIED | `Settings.lua:176, 186-189`; `Core.lua:26, 37-47, 289-294`; `MeterReset.lua:393` |
| SET-01 | 16-01 | SATISFIED (code) | `UI/SettingsPanel.lua:74, 81-83, 94-126` |
| MSG-01 | 16-01 | SATISFIED (code) | `Messages.lua:213-228, 239-275`; `UI/Table.lua:710-716` |
| MSG-02 | 16-01 | SATISFIED (code) | `Messages.lua:252-255, 280-282` |

No orphaned requirements: all seven Phase 16 IDs in REQUIREMENTS.md are claimed by a plan.

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
|------|------|---------|----------|--------|
| (none) | - | No TBD / FIXME / XXX / TODO / HACK in the five modified Lua files | - | - |
| `UI/SettingsPanel.lua` | 120 | If Close shows the discard popup and the player cancels it, the pending `afterClose` stays set and runs on the panel's next hide (a later close would show the meter prompt or the Messages tab) | Info | Edge case; the requirement only asks that unapplied settings still ask. Worth trying during human check 4 |
| `UI/SettingsPanel.lua` | 121 | Choosing discard in that popup goes through Blizzard's `ExitWithoutCommit`, which transitions back to the game menu (the `true` flag only applies to the commit path), so the game menu may show with the prompt | Info | Blizzard behaviour; cosmetic |

No `StaticPopupDialogs[` writes in the three prompt / settings / messages files.

### Human Verification Required

The eight checks in `16-HUMAN-UAT.md` (all pending), repeated in the frontmatter:

1. Settings > Damage meter > Move, then Lock / Default
2. The prompt at the saved spot after /reload
3. The prompt's look (icon, red game-menu buttons)
4. Move and Edit whisper messages close Settings (incl. an unapplied game setting; also try cancelling the discard popup, see Info above)
5. In combat: nothing closes
6. Activity menu on a multi-activity listing (row Whisper and Send Message; pick, Edit, close)
7. One-activity listing: no menu
8. Group-join reset: existing vs fresh install; instance prompt unchanged

### Gaps Summary

No gaps. Every success criterion is implemented, wired and covered by the smoke harness. `stylua` is clean and the harness reports 0 failures in all three modes. What remains is in-game behaviour and look (8 UAT items). This project expects those checks, and they don't block the phase.

---

_Verified: 2026-11-19_
_Verifier: Claude (gsd-verifier)_
