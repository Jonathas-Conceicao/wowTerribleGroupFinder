# Milestones

## v0.1 Initial Release (Shipped: 2026-11-12)

**Delivered:** the first public release: Forever's own group finder, improved in place, with a
sortable table of solo players and groups, player location, and one-click whisper presets.

**Phases completed:** 6 phases (1, 2, 3, 4, 04.1 inserted, 5), 19 plans
**Requirements:** 33/33 (GS, MSG, LOCK, UIP, LOC, REL)
**Git:** 159 commits on `milestone/v0.1-milestone`, 2026-11-11 → 2026-11-12; 26 shipped/source
files changed (+2623 / −600, outside `.planning/`); ~5.3k lines of Lua/XML
**Tag:** `v0.1.0` (project convention: `vX.Y.Z`)

**Key accomplishments:**

- Gear score switched off behind one flag (`ns.GEAR_SCORE`), code and notes kept for a later
  decision (backlog 999.1)
- Browse list rebuilt on Blizzard's ScrollBox with stock section headers, selection, layout,
  row art and search states; stock-style sort headers sized to fit their arrow
- Rows and tooltip like Forever's own: role icons, your listing with its delist button, the
  stock tooltip order, friend marks, Discord icon, and the game's own right-click menu
- Messages tab: `[TGF]` presets with key buttons, Auto-send / Auto-invite, a 1 s contact lock
  against spam; the invite preset is used whenever you're in a group
- Player location (inserted phase 04.1): the solo player's or leader's zone on each row and
  each member's zone in a group's tooltip
- Release plumbing: CurseForge / Wago IDs in the TOC, the in-game icon, LICENSE in the zip,
  README with screenshots and an AI usage section, the v0.1.0 changelog

**Adjusted at close:** REL-01's store upload keys are not set; the author uploads the release
zip to CurseForge / Wago by hand (the packager skips uploads without the secrets).

**Known deferred items at close:** 0 open artifacts; later cleanup ideas are listed in
`phases/05-release-review/05-HUMAN-UAT.md` item 11; gear score finish-or-drop is backlog 999.1.

---
