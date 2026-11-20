---
phase: 17-release-review
plan: 02
subsystem: release
tags: [changelog, readme, screenshots, uat, v0.2.2]
requires: [17-01]
provides: [v0.2.2 changelog draft, README refresh gif, committed prints, 17-HUMAN-UAT.md]
affects: [CHANGELOG.md, README.md, .gitattributes, Media/Screenshots]
tech-stack:
  added: []
  patterns: []
key-files:
  created: [Media/Screenshots/tgf_refresh.gif, Media/Screenshots/tgf_tooltip_info.png, .planning/phases/17-release-review/17-HUMAN-UAT.md]
  modified: [CHANGELOG.md, README.md, .gitattributes]
decisions:
  - "No Fixed heading in v0.2.2: the only fix commit since main (1151ce6) fixes review findings on v0.2.2's own code, none a v0.2.1 bug"
  - "README proposals d/e fold in v0.2.1's still-unapplied Settings page and /tgf meter proposals; Region flags and Item level v0.2.1 proposals listed as a reminder"
metrics:
  duration: ~6 min
  completed: 2026-11-19
requirements: [REL-07]
---

# Phase 17 Plan 02: Changelog, README prints and author review Summary

The `## v0.2.2` changelog draft (Added: movable meter prompt, activity choice with Edit; Changed: icon and game buttons, Settings buttons closing the window, group-join prompt off for new installs), the author's two prints committed byte for byte with the refresh gif as the README's first image, and 17-HUMAN-UAT.md with seven pending review items.

## Tasks

| Task | Name | Commit | Files |
| ---- | ---- | ------ | ----- |
| 1 | Draft the CHANGELOG v0.2.2 section | 20eadba | CHANGELOG.md |
| 2 | Commit the prints; README first image is the gif | 9bbe3d7 | .gitattributes, README.md, Media/Screenshots/tgf_refresh.gif, Media/Screenshots/tgf_tooltip_info.png |
| 3 | Author review checklist | da72825 | .planning/phases/17-release-review/17-HUMAN-UAT.md |

## Verification

- `grep -n "^## " CHANGELOG.md`: v0.2.2, v0.2.1, v0.2.0, v0.1.0; the commit's diff has no removed lines; no keys / API names / review IDs
- README diff: 2 added, 2 removed (the two `<img>` lines); no reference to `tgf_lfg_window` or `tgf_tooltip_info`
- Prints tracked, `git status --short Media/Screenshots` empty; gif 32240667 bytes, same SHA-1 before and after commit (~32 MB, under GitHub's 50 MB warning; `*.gif binary` added)
- 17-HUMAN-UAT.md: 5 Before / 5 After, `/tgf meter`, `tgf_refresh.gif`, `16-HUMAN-UAT.md`, `status: partial`; README unchanged by Task 3
- `stylua --check .` clean; `./scripts/install.bat` deployed 26 files (v0.2.1-23-gda72825-dev) for the author's in-game checks

## Deviations from Plan

None - plan executed exactly as written. (The Settings page and Usage proposals combine the v0.2.2 additions with v0.2.1's unapplied wording, so the author reviews one text per line.)

## Self-Check: PASSED
- Commits 20eadba, 9bbe3d7, da72825 exist; CHANGELOG.md, README.md, both prints and 17-HUMAN-UAT.md present.
