---
status: complete
phase: 09-dynamic-refresh
source: [09-VERIFICATION.md, 09-REVIEW.md]
started: 2026-11-14T18:00:00Z
updated: 2026-11-15T12:00:00Z
---

## Current Test

[complete: the author passed every check in game, 2026-11-15]

## Tests

### 1. Dynamic refresh in game
expected: Browse with a category and activities, then the refresh button: no spinner, no blank list; new listings appear in their sorted place, delisted / gone ones swipe out and stay out (until a new search or they relist); selection and whispered / invited marks stay; a failed refresh keeps the list; changing the dropdowns is a normal new search (spinner)
result: pass

### 2. Animation feel
expected: Swipes (0.4 s) feel calmer than the prototype; rows below a removed one slide up (0.3 s) instead of jumping, also with the list scrolled and with a section collapsed; no stuck invisible rows after scrolling or a second refresh mid-swipe; no flash at the start of a swipe-in; tune `UI/Motion.lua` constants if needed
result: pass

### 3. Preview
expected: `/tgf preview`, then the refresh button repeatedly: 1–3 listings leave and 1–3 arrive with the same animations; delisted rows swipe out; `/tgf reset` restores the sample list
result: pass

### 4. Settings off (live)
expected: `/run TerribleGroupFinderDB.dynamicRefresh=false` → refresh is stock (spinner, new list); `/run TerribleGroupFinderDB.swipeAnimations=false` (Dynamic refresh on) → list updates in place without animation; both take effect without a reload (settings page in Phase 10)
result: pass

## Summary

total: 4
passed: 4
issues: 0
pending: 0
skipped: 0
blocked: 0

## Gaps
