---
status: complete
phase: 16-small-improvements
source: [16-01-SUMMARY.md, 16-02-SUMMARY.md]
started: 2026-11-19T12:00:00Z
updated: 2026-11-20T12:00:00Z
---

## Current Test

[testing complete]

## Tests

### 1. Settings > Damage meter > Move, then Lock / Default
expected: Settings closes and the prompt shows to drag with Default / Lock; Lock saves the spot and Default goes back to the automatic spot; both reopen the addon's Settings page
result: pass

### 2. The prompt at the saved spot after /reload
expected: After Lock and a /reload, `/tgf meter` (and the next real prompt) opens at the saved spot; after Default it opens below the game's popups / zone name again
result: pass

### 3. The prompt's look
expected: The addon's icon on the left; Yes / No (and Default / Lock) in the game menu's red button style
result: pass

### 4. Move and Edit whisper messages close Settings
expected: Both buttons close the Settings window first, then act; with an unapplied game setting the game still asks about it before closing
result: pass

### 5. In combat
expected: Move / Edit whisper messages close nothing in combat (Settings stays open)
result: pass

### 6. Activity menu on a listing with several activities (row Whisper and Send Message)
expected: A menu lists each activity and Edit; an activity sends (or prefills, per Auto-send) with that activity; Edit only prefills the whisper box with every activity; closing the menu sends nothing
result: pass

### 7. Listing with one activity
expected: Whisper sends as before, with no menu
result: pass

### 8. Ask to reset on joining a group: existing install vs fresh install
expected: On an existing install the option stays on and joining a group still asks; on a fresh install (rename the SavedVariables file `TerribleGroupFinder.lua` first) the option shows off and joining a group doesn't ask; entering an instance still asks on both
result: pass

## Summary

total: 8
passed: 8
issues: 0
pending: 0
skipped: 0
blocked: 0

## Gaps
