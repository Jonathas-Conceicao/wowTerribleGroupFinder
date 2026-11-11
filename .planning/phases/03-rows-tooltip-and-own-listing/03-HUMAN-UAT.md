---
status: partial
phase: 03-rows-tooltip-and-own-listing
source: [03-VERIFICATION.md, 03-04-SUMMARY.md, 03-REVIEW-FIX.md]
started: 2026-11-11T18:40:00Z
updated: 2026-11-11T18:40:00Z
---

## Current Test

[awaiting human testing — in game on Forever, after `./scripts/install.bat` and `/reload`]

## Tests

### 1. Delist from your own row
expected: As solo or leader, your own row shows "Your listing" in green and the stock delist button (red X, tooltip "Unlist"); clicking it plays the click sound, removes your listing and the row disappears without a new search; no ADDON_ACTION_BLOCKED. As a non-leader group member the button is not shown. No Whisper or hide button on your own row.
result: [pending]

### 2. Hide button
expected: A small 24x22 stock-style button with an eye-struck-through icon (`transmog-icon-hidden`) hides a listing (greyed, moved to the end); on a hidden row it shows an open eye (`socialqueuing-icon-eye`) and shows it again. Where the atlases are missing: "x" / "+" text. Never the red X.
result: [pending]

### 3. Micro role icons on solo rows
expected: Solo players show `groupfinder-icon-role-micro-*` at 18 px in T > H > D order, legible; groups keep the large 14 px icons with open slots from the server's remaining counts.
result: [pending]

### 4. Discord icon and voice wording
expected: The Discord icon (16 px) sits right after the name only for Discord listings; long names are cut before it. The tooltip voice line reads like stock ("Voice chat: <mode>").
result: [pending]

### 5. Tooltip order and wording
expected: Compared side by side with the stock tooltip on the same listing: delisted / new player friendly, leader (and members up to 10) with level and role icons, comment in light grey, member counts, voice, activities (bright blue when matching your listing), bosses defeated; then our extras: playstyle, spec / area, friends in group, listed age, hidden note.
result: [pending]

### 6. Playstyle colour (author decision)
expected: ROADMAP success criterion 3 reads "with playstyle and the comment in light grey"; the build follows UI-SPEC / CONTEXT D-17: playstyle in green as the stock row's playstyle label, comment in light grey. Confirm green, or ask for light grey.
result: [pending]

### 7. Tooltip refresh while hovered
expected: Hovering a row while results update (or while scrolling) keeps the tooltip on the listing now under the mouse; it hides when no row is under the mouse.
result: [pending]

### 8. Needs my role with real server data
expected: With Needs my role on, groups the server reports as having no slot for your role are greyed and moved to the end of their section; quest / custom groups that report 0 for every role fall back to the composition estimate (not all greyed).
result: [pending]

### 9. Atlases exist
expected: `UI-ChatIcon-Discord`, `groupfinder-icon-role-micro-*`, the new-player icon, `groupfinder-icon-leader` / `UI-Group-LeaderIcon` render; otherwise the coded fallbacks show.
result: [pending]

### 10. Taint log
expected: `/console taintLog 1`, then hover rows, click delist and hide, open Listing: no taint lines for TerribleGroupFinder.
result: [pending]

### 11. Width (Q1)
expected: At the 620 px widened frame the Activity column (4 px narrower than in phase 2) is still readable.
result: [pending]

## Summary

total: 11
passed: 0
issues: 0
pending: 11
skipped: 0
blocked: 0

## Gaps
