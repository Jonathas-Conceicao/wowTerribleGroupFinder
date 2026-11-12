---
phase: 03-rows-tooltip-and-own-listing
plan: 01
subsystem: listings-data
tags: [lfglist, voice-mode, playstyle, member-counts, needs-my-role]
requires: []
provides:
  - "ns.VOICE constant (Enum.LFGEntryVoiceMode or fallback)"
  - "Listing fields voiceMode, voice, playstyle, counts, remaining (game reader and preview)"
  - "Activity groupID"
  - "FitsMyRoles reads server remaining slots (UIP-15)"
affects: [03-02, 03-03, 03-04]
tech-stack:
  added: []
  patterns: ["optional undocumented API under pcall with per-field number and secret checks"]
key-files:
  created: []
  modified: [Core.lua, Listings.lua, Preview.lua, UI/Table.lua]
key-decisions:
  - "Own preview entry keeps its comment only if the stand-in stores one; the 'Your listing' placeholder is gone"
  - "A group with remaining all zero while not full falls back to the COMPOSITION estimate"
requirements-completed: [UIP-15]
duration: 25min
completed: 2026-11-11
---

# Phase 3 Plan 01: Listing data and Needs my role from server slots Summary

Every listing now carries voiceMode, playstyle, member counts and remaining slots (guarded against secret values and a missing or failing GetSearchResultMemberCounts), and Needs my role uses the server's remaining slots with the old estimate as fallback.

## Tasks

1. Harness stubs and red checks (outside the repo, not committed).
2. Listing fields in Core, Listings, Preview: commit 97e6f0c.
3. Needs my role from remaining slots in UI/Table.lua: commit d7b748b.

## Harness additions (smoke/harness.lua, tail.lua)

Stubs: Enum.LFGEntryVoiceMode / LFGEntryGeneralPlaystyle; tooltip globals and colour globals; CreateAtlasMarkup, CreateSimpleTextureMarkup, GetGeneralPlaystyleString; GameTooltip capture (log.tipLines, SetOwner/GetOwner/Hide/IsShown, log.tipShows); UIMenuButtonStretchTemplate in KNOWN with MiddleMiddle/Text parts; C_LFGList fixtures in every mode (merged under --attach) with switches log.countsMode (error / nil / secret), log.infoOverride, log.activeEntry; global SECRET marker; recorders log.encounterCalls, log.removed, log.forbidden (Tab1_OnClick, SearchEntryTooltip_UpdateAndShow, listing RemoveListing) and log.doSearch.
Probes: data-read, preview-data, needs-my-role, plus a final "restricted calls never invoked" check.

Final runs: default, --gs, --fallback, --attach each end `SUMMARY: 0 failed`. `stylua --check .` clean.

## Deviations from Plan

**1. [Rule 3 - Blocking] LFGBrowse_DoSearch is counted separately, not as forbidden.** The existing harness probes call `LFGBrowse_DoSearch()` themselves to simulate Blizzard searches, so counting it into `log.forbidden` failed in --attach. It is counted in `log.doSearch` instead; later plans compare before/after when they need to assert our code never calls it.

**2. [Rule 2 - Missing] Preview Add() derives `voice` from `voiceMode`** so the old `l.voice` readers (tooltip, name tag) keep working until plan 02 replaces them.

## Known Stubs

None.

## Threat Flags

None.

## Self-Check: PASSED
