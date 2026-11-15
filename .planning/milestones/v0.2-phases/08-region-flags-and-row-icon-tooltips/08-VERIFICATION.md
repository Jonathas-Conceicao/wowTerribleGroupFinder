---
phase: 08-region-flags-and-row-icon-tooltips
verified: 2026-11-14T00:00:00Z
status: human_needed
score: 5/5 must-haves verified (code level); in-client checks deferred
overrides_applied: 0
human_verification:
  - test: "Open Browse on live Forever and look at rows from US and Oceania players"
    expected: "US flag after the name for US East/West listings, Oceania flag for AU, none for an unknown server"
    why_human: "Flag art, placement and real shard IDs only show in the real client"
  - test: "Check which coast each US shard is. KNOWN maps US1=West, US2=East (assumed in Region.lua header)"
    expected: "Tooltip coast names match the real servers (WR-02 wording intentionally kept by author)"
    why_human: "Mapping is an unconfirmed assumption"
  - test: "Hover each row icon (flag, roles, class/leader, new player friendly, Discord, friend marks, friends in group), then click-select and right-click over them"
    expected: "Each shows its tooltip; hover, select and Forever's row menu still work over the icons"
    why_human: "SetPropagateMouseMotion/Clicks behaviour is only observable in the client"
  - test: "Play, add Battle.net friends on other servers, /reload"
    expected: "Newly known servers get flags and keep them after /reload; a seeded server is never changed"
    why_human: "Needs live BN friend game accounts and real SavedVariables"
  - test: "Check your own row while in a group you don't lead"
    expected: "Flag and tooltip show the leader's region"
    why_human: "Needs a real party"
---

# Phase 8: Region flags and row icon tooltips Verification Report

**Phase Goal:** Every listing shows where its player is, and every icon on a finder row says what it is when hovered
**Status:** human_needed (no code gaps found)
**Re-verification:** No, initial verification

## Observable Truths

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | Flag after the name: one US flag for US East/West, an Oceania flag, none for an unknown server | VERIFIED | `Region.lua` PLACES maps US1 and US2 to flag "us" and AU1 to "au". `R.Of` returns nil for an unknown shard, so `R.Flag` returns nil. `Table.lua` ~1234-1255 draws the flag as the first name icon, only when `wanted.flag`. `Media/Textures/flag_us.tga` and `flag_au.tga` exist. |
| 2 | Row tooltip names the region | VERIFIED | `ExtrasTooltip` adds `ns.Region.Line(l)`, which gives "Region: <label>" or "Leader's region: <label>". Labels are US East, US West and Oceania. |
| 3 | Own listing shows the group leader's region (own when solo or leading) | VERIFIED | `R.ForListing` (Region.lua 96-127): solo or leading uses `GetRealmID` or the player GUID. A non-leader walks the units for the leader's GUID. An unreadable leader flag falls back to `l.shard` (review fix WR-01). |
| 4 | Known servers grow (own, BN friends'), survive `/reload`, and a learned server never overrides a known one | VERIFIED (code) | `LearnAround` scans your own realm and BN friends' game accounts on PLAYER_LOGIN and BN events. `R.Learn` skips `KNOWN` IDs. `R.Of` checks KNOWN first. `R.Init` adopts and sanitizes `DB.shards` by reference, so it is saved. `Core.lua:283` calls `Init`. A new shard triggers `RefreshAll`. Real persistence needs the client. |
| 5 | Every row icon has a tooltip; hover, click and right-click still work | VERIFIED (code) | `IconTooltip` covers flag, bnet, friend, recent, newPlayer, friendsIn, discord, leader, class and role (incl. open slot). Hit frames come from `W.HitFrame` and `W.Propagate` (EnableMouse plus PropagateMouseMotion and PropagateMouseClicks, no click scripts). Row tooltip ownership is handled via `tgfRow`. Dropped icons also hide their hit frames. |

**Score:** 5/5 truths verified in code.

## Requirements Coverage

| Requirement | Source plan | Status | Evidence |
|-------------|-------------|--------|----------|
| REG-01 | 08-01, 08-02 | SATISFIED | Truth 1 |
| REG-02 | 08-01 | SATISFIED | Truth 2 |
| REG-03 | 08-01 | SATISFIED | Truth 3 |
| REG-04 | 08-01 | SATISFIED (live check pending) | Truth 4 |
| ICO-01 | 08-02, 08-03 | SATISFIED | Truth 5 |
| ICO-02 | 08-02, 08-03 | SATISFIED (live check pending) | Truth 5 |

All six IDs appear in plan frontmatter and in REQUIREMENTS.md (still ticked "Pending" there; the checkboxes need updating). No orphaned requirements.

## Behavioral Spot-Checks

The smoke harness ran in all three modes (default, `--fallback`, `--attach`). Each reported `SUMMARY: 0 failed`.

## Anti-Patterns

No TBD, FIXME or XXX markers in Region.lua, UI/Table.lua, UI/Widgets.lua or Core.lua. The review's warnings were fixed except WR-02, which the author keeps on purpose. No stubs found.

## Notes

- `KNOWN` is seeded from live observation on 2026-11-14, but the coast assignment (US1=West, US2=East) is an assumption.
- The "Your listing" flag in the preview uses `l.shard`, by design.

## Gaps Summary

No code gaps. Status is `human_needed` because the in-client behaviours listed in the frontmatter can't be checked here. The author defers them to the milestone end.

_Verifier: Claude (gsd-verifier)_
