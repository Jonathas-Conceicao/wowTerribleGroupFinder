---
phase: 15-release-review
plan: 02
subsystem: release
tags: [changelog, readme, uat]
requirements-completed: [REL-06]
key-files:
  modified: [CHANGELOG.md]
  created: [.planning/phases/15-release-review/15-HUMAN-UAT.md]
metrics:
  completed: 2026-11-16
---

# Phase 15 Plan 02: Changelog draft and author review Summary

The `## v0.2.1` changelog section is drafted above `## v0.2.0` (insert only, CRLF kept), README proposals and the author's review items are in 15-HUMAN-UAT.md, and README.md is untouched.

## Commits
- aa6817e docs(15-02): draft the v0.2.1 changelog section (CHANGELOG.md)
- UAT file and this summary: committed together in the following docs commit

## Changelog
Added: damage meter reset prompt, `/tgf meter`, talent points, EU / China / Korea / Taiwan flags with two-letter tags. Changed: new US / Oceania flag art, section renamed "Item level and talents". No Fixed heading. The diff is 16 insertions, 0 deletions.

## Inspect guard (14 WR-02) against v0.2.0
`git show v0.2.0:ItemLevel.lua` already had the Inspect window shown / pending guard and a 2 s `OTHERS_BUSY` gap after an inspect that isn't ours. The v0.2.1 wait (until the other inspect answers or 4 s pass) tightens that, so v0.2.0 could plausibly have disturbed the game's Inspect Talents, but this was not confirmed as a real v0.2.0 bug. So no Fixed line in the draft; the proposed line ("Item level lookups no longer get in the way of the game's Inspect Talents") is in 15-HUMAN-UAT item 1 as the author's keep-or-drop decision.

## 15-HUMAN-UAT.md
Six pending items: changelog review (with the Fixed proposal), five README before / after pairs (Region flags, Item level, new damage meter bullet, `/tgf meter` in Usage, Settings page; "Before" quoted verbatim from README.md), screenshot reminder, version, pointers to 12 / 13 / 14-HUMAN-UAT.md, phase confirmation.

## Deviations
None.

## Self-Check: PASSED
