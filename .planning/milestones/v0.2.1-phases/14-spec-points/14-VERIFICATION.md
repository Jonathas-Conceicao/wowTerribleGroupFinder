---
phase: 14-spec-points
verified: 2026-11-16T00:00:00Z
status: human_needed
score: 7/7 must-haves verified in source
overrides_applied: 0
human_verification:
  - test: "Run /tgf ilvl in a group; compare each member's 'C_Traits per tree' figure with their talent frame (menu 'Inspect Talents'); note what pointsSpent prints"
    expected: "C_Traits figures equal the talent frame's per-tree counts"
    why_human: "Needs live Forever client data (C_Traits inspect config)"
  - test: "Read the probe's 'after clear' line"
    expected: "Records whether ClearInspectPlayer empties the inspect config (the capture happens before the clear, so the tooltip is safe either way)"
    why_human: "Client behaviour"
  - test: "Hover yourself (also after a dual-spec switch, and with staged but unapplied talent clicks)"
    expected: "Gold 'Talents a/b/c' line right after the Item Level line, following the active spec; probe shows own config type CamelotCombat"
    why_human: "Live client; OwnConfigID candidates and config type cannot be checked outside the game"
  - test: "Open 'Inspect Talents' on a party member, then hover other players for 10 s"
    expected: "The inspected tree stays (no swap, no blank)"
    why_human: "Shared inspect slot behaviour in game"
  - test: "Hover a low-level player with no talent points, and an enemy/attackable player"
    expected: "No talents line either way; /tgf ilvl shows one inspect for the low-level player, no repeats"
    why_human: "Live inspect traffic"
  - test: "Settings -> AddOns -> TerribleGroupFinder; toggle 'Talent points' and '/tgf set specpoints off|on'"
    expected: "Section 'Item level and talents', 'Talent points' second and on; off removes only the talents line on the next hover, item level line unaffected, and vice versa"
    why_human: "Visual settings page and tooltip"
---

# Phase 14: Spec Points Verification Report

**Phase Goal:** A friendly player's tooltip shows their talent points per tree, from the game's own data, with a setting to turn it off
**Verified:** 2026-11-16
**Status:** human_needed
**Re-verification:** No, initial verification

The data call moved from `GetSpecializationInfo().pointsSpent` to the `C_Traits` group currency, as research found. CONTEXT delegated the exact call to research, so this satisfies "from the game's own data" and is not a gap.

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | Own talents read live from the active config, per tree in game order | VERIFIED | `ReadTalents` (ItemLevel.lua:180-243) uses `GetConfigInfo`, `GetGroupDisplayInfoByTreeID` and `GetGroupCurrencyInfo`, in `ipairs` group order. `OwnConfigID` (246-279) checks config type. `ILvl.TalentsOf` reads live for "player" (457-463). |
| 2 | Inspected talents are read from config -1 only on the first pass after the serial/lastTarget check | VERIFIED | `ReadCurrent` reads it at 778-781 (`tries == 0`, after the check at 773). The foreign `Try` reads it at 1021-1023. Both come before `Done`/`ClearInspectPlayer`. |
| 3 | Talents are cached per GUID, kept even when items are incomplete, and `false` records "answered, nothing" | VERIFIED | `Remember(unit, r, talents)` (383-413) stores talents when `~= nil`, and ilvl only when complete. Callers pass `c.talents` (791) and `talents` (1030). `TalentsKnown` is true for any non-nil value, so there are no repeat inspects. |
| 4 | Our inspect stays away from Forever's inspected talent view | VERIFIED | `TalentsInspecting()` (296-305) is a read-only pcall that fails closed. It is part of `Busy()` (713) and of the `Done` clear condition (749). There is no `SetInspectUnit` or `ClearInspectUnit`. |
| 5 | The tooltip shows "Talents 36/12/3" after the item level line for friendly players, yourself included, and nothing for enemies or unknown/secret/all-zero data | VERIFIED | `OnTooltipUnit` and `RefreshTooltip` (ItemLevelUI.lua:117-197) check `ns.ILvl.Hostile`. `Showable` returns nil for all-zero. `UI.TalentText` builds the string. The talents line is added last, and the ilvl line is never appended under it. |
| 6 | The talents line shows without the ilvl line, with no extra inspect | VERIFIED | The two lines are gated independently (`ilvlOn`, `specOn`). The single `RequestInspect` call fires when `wantIlvl or wantTalents`. `TalentsKnown` stops repeats. NotifyInspect call sites are unchanged at 11 compared with before 14-01. |
| 7 | The setting `specPoints` ("Talent points") is second in the section "Item level and talents", on by default, with no parent | VERIFIED | Settings.lua:123-133. All five entries carry the new section. `o.default = true` is still the only default loop. |

**Score:** 7/7 truths verified in source

### Required Artifacts

| Artifact | Status | Details |
|----------|--------|---------|
| ItemLevel.lua | VERIFIED | `ReadTalents`, `OwnConfigID`, `Showable`, `TalentsInspecting`, `TalentsOf`, `TalentsKnown`, `PrintTalents` and the "after clear" probe line exist and are wired. `ILvl.Inspected` is nil-safe (928). |
| ItemLevelUI.lua | VERIFIED | `UI.TalentText` and the two tracked lines are wired. `OnLearned` triggers `RefreshTooltip`. |
| Settings.lua | VERIFIED | `specPoints` entry present. `UI/SettingsPanel.lua` needs no change because it builds headers from `opt.section`. |
| CLAUDE.md | VERIFIED | `specPoints`, "Item level and talents" and `TalentsOf` are present on the Settings, ItemLevelUI, SettingsPanel and ItemLevel lines. |

### Key Links

| From | To | Status |
|------|----|--------|
| `ReadCurrent` | `ReadTalents(INSPECT_CONFIG)` | WIRED |
| `Remember` | `known[guid].talents` | WIRED |
| `Busy` / `Done` | `PlayerSpellsFrame:IsInspecting` | WIRED |
| `OnTooltipUnit` | `TalentsOf` / `TalentsKnown` / `Settings.Get("specPoints")` | WIRED |
| `RefreshTooltip` | `OnLearned` | WIRED |

### Requirements Coverage

| Requirement | Source Plan | Status | Evidence |
|-------------|-------------|--------|----------|
| SPC-01 | 14-01, 14-02 | SATISFIED in source; live check pending | Truths 1-6 |
| SPC-02 | 14-02 | SATISFIED in source; live check pending | Truth 7 |

Both IDs are declared in the plans and exist in REQUIREMENTS.md. No orphaned requirements. REQUIREMENTS.md still shows the checkboxes and table rows as Pending, so the orchestrator should update them after sign-off.

### Anti-Patterns

No TBD, FIXME or XXX markers in the modified files. `stylua --check .` passes. No stubs found. Data flows from the C_Traits reads to the tooltip text.

Minor note, not a blocker: in `RefreshTooltip`, if the talents line was added first (ilvl unknown at build) and an ilvl answer arrives later, the ilvl line is skipped on purpose to keep the order. Both values normally arrive in the same answer.

### Human Verification Required

See the frontmatter. These are live-client checks: C_Traits figures against the talent frame, own-config selection, the interaction with "Inspect Talents", the settings page, and tooltip appearance. A README or settings screenshot may need retaking, and the author does that.

### Gaps Summary

No gaps in source. The status is `human_needed` only because the data calls (`C_Traits` inspect config, `OwnConfigID`) can't be confirmed outside the live Forever client.

---

_Verified: 2026-11-16_
_Verifier: Claude (gsd-verifier)_
