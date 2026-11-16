---
phase: 12-damage-meter-reset-prompt
verified: 2026-11-16T00:00:00Z
status: human_needed
score: 6/6 must-haves verified
overrides_applied: 0
human_verification:
  - test: "Details! loaded, join a group"
    expected: "Dialog reads '[TGF] Reset Details! damage meter?' with Yes / No; Yes clears Details! and prints 'Details! reset.'; No leaves it"
    why_human: "Needs the live Forever client and Details!"
  - test: "Details! off, game meter on, join a group; then game meter off"
    expected: "'[TGF] Reset the damage meter?' and Yes clears the game's meter; with neither meter nothing is asked and /tgf meter prints 'no damage meter to reset: ...'"
    why_human: "Depends on C_DamageMeter and the damageMeterEnabled CVar in the live client"
  - test: "Enter a dungeon / raid / battleground; /reload inside; leave and enter another instance"
    expected: "Asked once on entry; not asked after /reload; asked on entering another instance"
    why_human: "Real PLAYER_ENTERING_WORLD / GROUP_ROSTER_UPDATE behaviour"
  - test: "Settings -> AddOns -> TerribleGroupFinder, Damage meter section"
    expected: "Both options on by default; turning either off stops that trigger asking"
    why_human: "Settings UI rendering and live triggers"
  - test: "/tgf meter twice while the dialog shows"
    expected: "Prompt shows at any time; a second call keeps a single dialog"
    why_human: "Visual dialog look (DialogBorderTemplate, placement); README screenshot decision for the author"
---

# Phase 12: Damage Meter Reset Prompt Verification Report

**Phase Goal:** Joining a group or entering an instance asks, with a clearly labelled prompt, whether to reset the damage meter, and each trigger can be turned off
**Verified:** 2026-11-16
**Status:** human_needed
**Re-verification:** No, initial verification

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | Details! loaded: prompt "[TGF] Reset Details! damage meter?" with Yes / No | VERIFIED | `MeterReset.lua:130` `SetText("[TGF] Reset " .. NAMES[target] .. "?")`; `NAMES.details = "Details! damage meter"`; buttons `YES or "Yes"` / `NO or "No"` (107, 112); no `|c` colour code |
| 2 | Game's meter only: "[TGF] Reset the damage meter?"; neither meter: nothing asked | VERIFIED | `NAMES.blizzard`; `Target()` returns nil unless Details! has `ResetSegmentData` or `BlizzardOn()` (CVar `damageMeterEnabled` and `IsDamageMeterAvailable`); `Ask()` returns false on `not target` |
| 3 | Group join (not grouped -> grouped) asks, gated by `meterResetOnGroup` | VERIFIED | `MeterReset.lua:165-171`, `ready` guard; setting read via `ns.Settings.Get` where it acts |
| 4 | Instance entry (outside or other instance) asks, gated by `meterResetOnInstance`; login / reload only records | VERIFIED | `MeterReset.lua:153-164`: `entered = now ~= nil and now ~= instance`; `isInitialLogin or isReloadingUi or not ready` returns early; Init registers both events |
| 5 | Settings "Damage meter" section, both on by default; `/tgf meter` shows prompt or prints why | VERIFIED | `Settings.lua:165-176` section "Damage meter", labels as specified, `o.default = true` loop (179); `SettingsPanel.lua:39` section header from `opt.section`; `Core.lua:325-328` `/tgf meter` |
| 6 | Nothing resets without Yes; own frame, never `StaticPopupDialogs` | VERIFIED | `M.Reset()` has a single caller (Yes handler, line 109); `grep -c StaticPopupDialogs MeterReset.lua` = 0; frame built with `DialogBorderTemplate`; Reset wraps calls in `pcall` |

**Score:** 6/6 truths verified (static source evidence)

### Required Artifacts

| Artifact | Status | Details |
|----------|--------|---------|
| `MeterReset.lua` | VERIFIED | Substantive (181 lines), wired: `Core.lua:292` `ns.MeterReset.Init()`, TOC line 20 |
| `Settings.lua` options | VERIFIED | Both keys registered, default true |
| `Core.lua` | VERIFIED | Init call and `meter` command |
| `CLAUDE.md` | VERIFIED | MeterReset line states both [TGF] wordings; settings sections list reads "Item level / Group finder / Damage meter / Messages" |

### Key Link Verification

| From | To | Status |
|------|----|--------|
| `M.Ask` -> `dialog.text:SetText` with `[TGF] Reset ` .. `NAMES[target]` | WIRED |
| `OnEvent` -> `ns.Settings.Get("meterResetOnGroup"/"meterResetOnInstance")` | WIRED |
| Core slash `command == "meter"` -> `ns.MeterReset.Ask` | WIRED |

### Behavioral Spot-Checks

`stylua --check .` exits 0. Runtime behaviour needs the live client (SKIPPED, see human verification).

### Requirements Coverage

| Requirement | Source Plan | Status | Evidence |
|-------------|-------------|--------|----------|
| MTR-01 | 12-01 | SATISFIED (source) | Group trigger, meter choice, nothing asked with neither |
| MTR-02 | 12-01 | SATISFIED (source) | Instance trigger, login / reload only records |
| MTR-03 | 12-01 | SATISFIED | Text starts with plain `[TGF]` |
| MTR-04 | 12-01 | SATISFIED (source) | Settings section, defaults on, `/tgf meter` |

All four IDs appear in REQUIREMENTS.md. No orphaned requirements. Note: the traceability table in REQUIREMENTS.md still shows "Pending" for MTR-01..04 while the checklist is ticked; the orchestrator should update it at phase close.

### Anti-Patterns Found

None. No TBD / FIXME / XXX / TODO in MeterReset.lua. CHANGELOG.md and README.md untouched. Untracked `flag_*.png` files in the repo root are unrelated to this phase.

### Human Verification Required

See the frontmatter list: the dialog, triggers and settings need the live Forever client (the author tests later).

### Gaps Summary

No gaps in the code. Remaining items are live-client confirmation only.

---

_Verified: 2026-11-16_
_Verifier: Claude (gsd-verifier)_
