---
phase: 21-release-review
plan: 02
subsystem: release
tags: [changelog, release-review, uat]
requires: [21-01]
provides: [v0.3.0 changelog draft, author review checklist]
affects: [CHANGELOG.md]
key-files:
  modified: [CHANGELOG.md]
  created: [.planning/phases/21-release-review/21-HUMAN-UAT.md]
metrics:
  completed: 2026-11-24
---

# Phase 21 Plan 02: Changelog draft and author review Summary

A `## v0.3.0` changelog section (Added, Changed; explains the opt-in defaults and that existing settings are kept) prepended above `## v0.2.2`, and 21-HUMAN-UAT.md holding the author's seven pending review items.

## Commits
- 73d90ca docs(21-02): draft v0.3.0 changelog (CHANGELOG.md, added lines only)
- docs(21-02): author review checklist for v0.3.0 (21-HUMAN-UAT.md)

## Decisions
- `/tgf quest` and `/tgf gear` bullet kept (v0.2.0 precedent).
- No `### Fixed` heading: every fix(19) / fix(20) commit fixes code written in this milestone.

## UAT file
Seven pending items: changelog review, README proposals (six Before / After pairs plus a reminder block), screenshot reminders, version, the 17 deferred in-game checks (18-1..4, 19-1..7, 20-1..6), open decisions, phase confirmation. README.md untouched (identical to main). The one "flagpedia" match in the UAT is the line stating there is no flagpedia credit.

## Deploy
`./scripts/install.bat` ran: 28 files installed to the _forever_ client, version v0.2.2-52-g73d90ca-dev.

## Deviations
None. The run stops here: no push, merge or tag; STATE.md and ROADMAP.md not touched, as instructed.

## Self-Check: PASSED
