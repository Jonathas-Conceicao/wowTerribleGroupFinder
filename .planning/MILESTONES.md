# Milestones

## v0.2 ILvL Info and Improved Refresh (Shipped: 2026-11-15)

**Delivered:** item level from the game's own data wherever players look (replacing gear
score), region flags, a refresh that keeps the list and updates it in place, tooltips on every
row icon, and a settings page to turn each extra on or off.

**Phases completed:** 6 phases (6-11), 15 plans
**Requirements:** 24/24 (GSR, ILV, SET, REF, REG, ICO, REL); REG-02 adjusted (region named by
the game's shard group, US1 / US2 / AU1, no West / East assumed)
**Git:** 116 commits on `milestone/v0.2-ilvl-info-and-improved-refresh`, 2026-11-12 →
2026-11-15; 22 shipped/source files changed (+3494 / −637, outside `.planning/`); ~8.0k lines of
Lua/XML shipped
**Tag:** `v0.2.0`

**Key accomplishments:**

- Gear score removed for good (code, UI, inspects; saved data cleared by a schema-2 migration)
  and a settings registry (`ns.Settings`) with seven toggles, all on by default
- Item level on friendly player tooltips (guarded quiet inspect), weapon and armor tooltips, a
  native-looking row under Movement Speed on the character sheet (taint-free: our own frame,
  Blizzard's rows' anchors moved only), and the Inspect window; `{ilvl}` whisper key
- Region flags from the listing's hidden shard (seeded and learned shards, own listing =
  leader's region), generic for any region group; a tooltip on every row icon; raid groups
  show role counts with icons
- Dynamic refresh: a same-filter refresh keeps the list, swipes rows out and in and slides the
  rest into place (`ns.Motion`), also simulated in the preview
- Settings page in the game's Settings (AddOns), `/tgf settings`, `/tgf set`, and a button to
  the Messages tab

**Audit:** [milestones/v0.2-MILESTONE-AUDIT.md](milestones/v0.2-MILESTONE-AUDIT.md), status
tech_debt (no blockers): unused `SP.ID()`, the `searchOut` reset edge case, tooltip spots
without change listeners.

**Known deferred items at close:** the v0.1 cleanup list stays deferred; README screenshots
kept from v0.1 (no flags, row icons or raid role counts shown); backlog 999.5 (quest log LFG
button).

---

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
