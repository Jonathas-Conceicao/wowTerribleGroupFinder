---
status: pending
phase: 22-small-fixes
source: [22-01-SUMMARY.md, 22-02-SUMMARY.md, 22-03-SUMMARY.md]
started: 2026-11-26
updated: 2026-11-26
---

## Current Test

[awaiting the author's in-game pass at the end of the phase]

## Tests

### 1. Eye with the finder closed, then open
expected: hover and click the Elite quest eye with the finder closed, then again with it open; no Lua error; the finder opens on the Listing tab with Quests & Zones and the quest's zone picked
result: pending

### 2. Eye with an active listing
expected: with a listing active, clicking the eye prints one chat line and raises no error
result: pending

### 3. Eye for a quest whose zone row is off screen
expected: no error; the zone is not ticked; the hint says so
result: pending

### 4. Eye in combat
expected: a chat line and no error; after combat the next hover covers the eye again
result: pending

### 5. /tgf quest after the above
expected: `/tgf quest` shows the last error and the failed steps, or none when nothing failed
result: pending

### 6. Post after using the eye (taint)
expected: with `/console taintLog 1`, use the eye, type a description and press Post; the listing is created; `Logs/taint.log` has no TerribleGroupFinder entry
result: pending

### 7. Invite accepted
expected: Group Invite a solo player who accepts; the Listed cell reads "invited", then "accepted" (green)
result: pending

### 8. Invite declined
expected: invite a player who declines: "declined" (red); an offline player and one already in a group also read "declined"
result: pending

### 9. Invite expired
expected: invite a player who ignores the popup; the cell reads "expired" (grey) after about 60 s
result: pending

### 10. Outcome persists
expected: the outcome stays on its row through a Dynamic refresh and a re-sort; whisper-only rows still read "sent"
result: pending

### 11. Preview invites
expected: `/tgf preview`, Group Invite on three solo rows: accepted, declined, expired in turn
result: pending

### 12. First search after a reload
expected: after `/reload`, pick a category, pick an activity (or an activity group checkbox) and press Refresh while the first search may still be out; the first answer lists only that activity, not the general view; the next refresh is a normal Dynamic refresh (no spinner, rows swipe)
result: pending

### 13. No regression in other searches
expected: later searches of other categories and activities, and Dynamic refresh off, behave as before
result: pending

## Summary

total: 13
passed: 0
issues: 0
pending: 13
skipped: 0
blocked: 0

## Gaps
