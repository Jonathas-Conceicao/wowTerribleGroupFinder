---
status: partial
phase: 04-messages-and-contact
source: [04-VERIFICATION.md, 04-04-SUMMARY.md, 04-REVIEW-FIX.md, 04-REVIEW-FIX.iter2.md]
started: 2026-11-11T19:40:00Z
updated: 2026-11-11T19:40:00Z
---

## Current Test

[awaiting human testing — in game on Forever, after `./scripts/install.bat` and `/reload`]

## Tests

### 1. Auto-send + Auto-invite on a solo player
expected: With both boxes on (invite preset) and you solo or leading, one click on a solo player's Whisper sends `[TGF] Group for <activity> with <n> players` (n = your group size, 1 solo) by plain name, then the group invite. Without invite rights (group member, not assistant): whisper only.
result: [pending]

### 2. Request preset text
expected: On a group row, Whisper (Auto-send on) sends `[TGF] Level <your level> <your class>, for <activity>` to the leader.
result: [pending]

### 3. 1 s lock and pressed look
expected: After an auto-send the clicked Whisper (or bottom Send Message) looks pressed for about 1 s and does not flash back on mouse-up; a rapid double click sends once; every other Whisper, Send Message and Group Invite ignores clicks during that second; scrolling during the lock never shows another row pressed. Delist and hide stay usable.
result: [pending]

### 4. Chat lockdown and failed send
expected: During chat messaging lockdown a Whisper click only prefills the whisper box (no send, no invite, no lock). A send that errors prints "could not send the whisper to <name>." and starts no lock.
result: [pending]

### 5. Auto-invite gating look
expected: Auto-invite sits after Auto-send on the invite preset only; with Auto-send off it is unchecked, greyed (grey label) and still shows its tooltip with "Turn on Auto-send first."; checking Auto-send enables it unchecked. Checkbox clicks play the stock on/off sounds.
result: [pending]

### 6. Key buttons
expected: Two rows under each box (`[TGF] {name} {activity} {players}` / `{class} {level} {role}`), each under 410 px; a key button inserts at the cursor and keeps focus; `[TGF]` puts the key at the front once; `[TGF]` typed mid-text moves to the front when leaving the box.
result: [pending]

### 7. Preset boxes
expected: Multi-line boxes about 3 lines tall with the char count; Enter / Escape clear focus; pasting multi-line text strips newlines; Default replaces the text only (checkboxes kept).
result: [pending]

### 8. Messages panel layers
expected: Stone band with the intro text, inset art and border like the Who tab, divider between the two presets, nothing clipped at the bottom; same look in `/tgf` preview.
result: [pending]

### 9. Messages side tab
expected: Starts unchecked; icon fills like Forever's three tabs (check how `INV_Letter_15` looks under the mask, Q4); a listing update while Messages is open keeps only Messages checked; hover shows the template's "Messages" tooltip only.
result: [pending]

### 10. Preset migration
expected: A character that had the old default presets gets the new `[TGF]` defaults on first load; a custom preset is kept untouched; it happens once.
result: skipped — the migration was dropped (author: no compatibility with the dev build needed)

### 11. Taint
expected: With `/console taintLog 1`, using the Messages tab, Whisper, Send Message and Group Invite logs no taint against Blizzard's finder and no ADDON_ACTION_BLOCKED.
result: [pending]

## Summary

total: 11
passed: 0
issues: 0
pending: 11
skipped: 0
blocked: 0

## Gaps
