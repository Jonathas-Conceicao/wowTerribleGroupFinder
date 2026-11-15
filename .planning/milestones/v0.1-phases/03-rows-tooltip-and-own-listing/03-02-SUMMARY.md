---
phase: 03-rows-tooltip-and-own-listing
plan: 02
subsystem: ui-rows
tags: [rows, role-icons, discord, own-row, delist, hide-button]
requires: ["03-01"]
provides:
  - "W.IconButton, colour fallbacks (LIGHTGREEN, LIGHTGRAY, GREEN, NORMAL, RED), micro mode in W.RoleIcon, function titles in W.Tooltip"
  - "Micro role icons for solo rows, Discord icon after the name, light grey comment"
  - "Own row: Your listing in green, stock delist button, source.hasListing"
  - "Hide button as a 24x22 icon button"
affects: [03-03, 03-04]
tech-stack:
  added: []
  patterns: ["one icon-button builder for delist and hide, template swallowed by Create with a text fallback"]
key-files:
  created: []
  modified: [UI/Widgets.lua, UI/Table.lua, UI/InPlace.lua, UI/MainFrame.lua]
key-decisions:
  - "Instance:Delist is its own method (preview clears myListing; game calls RemoveListing only behind HasActiveEntryInfo, secret treated as no listing)"
  - "Delist and hide icon atlases are set on every fill (not at build), so the text fallback and the atlas branch both follow the client at fill time"
requirements-completed: [UIP-08, UIP-14]
duration: 40min
completed: 2026-11-11
---

# Phase 3 Plan 02: Rows, own listing and icon buttons Summary

Rows now match Forever's own: 18 px micro role icons for solo players (large icons kept for groups, open slots from the server's remaining slots), the Discord icon after the name only for Discord listings, the comment in light grey, the own row reading "Your listing" in green with the stock delist button, and the hide button as a small icon button.

## Tasks

1. Harness checks (outside the repo, not committed): probes micro-roles, discord, own-row, delist-click, hide-button, comment-colour. Red first (14 failures).
2. Widgets helpers, micro icons, Discord icon, comment colour: commit a0550f4.
3. Own row, delist button, icon hide button, source.hasListing: commit 92652df.

## Harness results (final)

- default: SUMMARY: 0 failed
- --gs: SUMMARY: 0 failed
- --fallback: SUMMARY: 0 failed
- --attach: SUMMARY: 0 failed
- `stylua --check .` clean; grep gates (no LFGBrowse_DoSearch / LFGParentFrameTab1_OnClick / LFGListingFrame in Table.lua; one "Unlist" fallback only) pass.

## Deviations from Plan

**1. [Rule 3 - Blocking] Harness colour globals needed r/g/b fields.** Plan 01's stubs for LIGHTGREEN/LIGHTGRAY/GREEN/NORMAL/RED_FONT_COLOR were arrays; `W.SetColor` reads `.r`. Added both forms in the harness (outside the repo).

**2. [Rule 1 - Design] Delist and hide atlases are set in FillRow instead of BuildRow.** The plan set the delist atlas at build time; doing it per fill keeps the text fallback correct when atlases appear later and lets the harness exercise both branches.

**3. [Rule 2 - Missing] The hide tooltip line in the row tooltip said "+ to show"**, which is no longer a button label; it now points at the eye button.

**4. Requirements:** only UIP-08 and UIP-14 are marked complete. UIP-07 (voice wording in the tooltip) and UIP-13 (playstyle in the tooltip) have tooltip halves still to come in plan 03.

## Known Stubs

None.

## Threat Flags

None. Delist calls only `C_LFGList.RemoveListing()` behind a non-secret `HasActiveEntryInfo() == true`; buttons inherit only `UIMenuButtonStretchTemplate`; no field written on a Blizzard frame.

## Self-Check: PASSED

Files modified exist; commits a0550f4 and 92652df present.
