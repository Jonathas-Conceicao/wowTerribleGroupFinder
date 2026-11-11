# Requirements — Milestone v0.1 Initial Release

**Goal:** first public release; Forever's finder looks and works as close as possible to the
stock one, with our table, sorting, hiding and quick contact on top. Gear score switched off.

Sources: the author's milestone brief (2026-11-11) and `research/UI-PARITY.md` (gap IDs G*,
suggested IDs UIP-*). Scoped autonomously at the author's request (AFK run); the author
reviews before the milestone closes.

## v0.1 Requirements

### Gear score on hold (GS)

- [x] **GS-01
**: The player sees no gear score anywhere (no GS column, no "Your GS", no GS in tooltips, no `{gs}` key) and no inspects run on ready checks; GearScore.lua stays in the repo behind a single disabled switch
- [x] **GS-02
**: The gear score design notes (formula, slot weights, quality factors, cache, inspect queue, sharing idea) are kept in `.planning/research/GEARSCORE.md` and a backlog item records the choice: finish gear score or drop it

### Messages (MSG)

- [ ] **MSG-01**: The default request preset is `{addon} Level {level} {class}, for {activity}` (rendered `[TGF] Level 23 Warrior, for The Deadmines`)
- [ ] **MSG-02**: The default invite preset is `{addon} Group for {activity} with {players} players`, where `{players}` is the player's current group size
- [ ] **MSG-03**: Under each preset's text box the player sees one button per key; clicking it inserts the key at the cursor
- [ ] **MSG-04**: The addon key renders `[TGF]`, is always at the start of the message and at most once; its button puts it at the front
- [ ] **MSG-05**: The invite preset has Auto-send and, after it, Auto-invite; Auto-invite is disabled (greyed) unless Auto-send is checked, and unchecks when Auto-send is unchecked
- [ ] **MSG-06**: With Auto-send and Auto-invite on, one click on a solo player whispers the preset and then sends the group invite

### Contact lock (LOCK)

- [ ] **LOCK-01**: After a click that auto-sends, every whisper / invite button ignores clicks for 1 s
- [ ] **LOCK-02**: During that second the clicked button stays visibly pressed ("sending"); the send itself is instant
- [ ] **LOCK-03**: The bottom Send Message button uses the same preset path and the same lock as the row button

### UI parity (UIP) — from research/UI-PARITY.md

- [ ] **UIP-01**: The Messages side tab starts unchecked, fills its icon like Forever's tabs, never shows checked together with another tab, and has a stock-style tooltip
- [x] **UIP-02
**: Section headers look and hover like Forever's own grouping header (collapse/expand atlas, plus/minus), not the row highlight (fixes the header hover bug)
- [x] **UIP-03
**: Selection works like stock: by result ID, click again to clear, not on delisted / own rows, cleared on new results, with the click sound; no double-click whisper
- [ ] **UIP-04**: Layout: no second inset/border; search box in the stone band; column headers in the strip above `BarTop`; Needs my role and status in the bottom bar; the freed GS width goes to Roles / Activity
- [x] **UIP-05
**: The list scrolls with Blizzard's ScrollBox and MinimalScrollBar, with separate header / row frames and their own heights
- [ ] **UIP-06**: Rows look like stock: mid2 background / hover / selected art, stock fonts and colours, greyed rows in stock grey with desaturated icons, leader icon on groups
- [ ] **UIP-07**: Solo players show the stock micro role icons; voice chat icon and wording match stock
- [ ] **UIP-08**: Your own listing row has the stock delist button (leader / solo only) and "Your listing" in green
- [ ] **UIP-09**: The row tooltip follows the stock order and wording, with our extras (friends in group, hidden note) after
- [ ] **UIP-10**: Searching shows the stock spinner; no results and search failed show the stock texts; filtering by our search box has its own text
- [ ] **UIP-11**: The Messages panel uses the Who tab's frame layers, multi-line preset boxes, native checkboxes with sounds, and the Auto-invite disabled look
- [x] **UIP-12
**: Row select, hide and checkboxes play the stock sounds
- [ ] **UIP-13**: Playstyle shows in the tooltip and the listing comment in light grey
- [ ] **UIP-14**: The hide button is a stock-style small button with an icon
- [ ] **UIP-15**: Needs my role uses the server's remaining-slot counts when available
- [ ] **UIP-16**: A hovered row's tooltip refreshes when results update

### Release (REL)

- [x] **REL-01**: The TOC carries `X-Curse-Project-ID: 1798577` and `X-Wago-ID: Q6aqvA6W`; the release workflow enables the CurseForge / Wago upload keys
- [x] **REL-02**: The icon sources (`baseicon.ase`, `baseicon.png`) live under `Media/Source/`; an in-game texture under `Media/Textures/` is the TOC's `IconTexture`
- [x] **REL-03**: Packaging ships only the addon files and the in-game texture (`.pkgmeta`, `scripts/install`, `scripts/package` checked)
- [ ] **REL-04**: Release Review: code cleanup, version confirmed, changelog draft, author review of README.md / CHANGELOG.md

## Future Requirements (deferred)

- Gear score: finish (tuning, sharing by addon whisper) or drop (see GS-02 backlog item)
- Compact role-count display for groups above 5 players (UIP research G18)
- Right-click menu without Report (G25)
- Default order = stock order; header click cycles asc / desc / stock (G35)
- Preview stand-in uses the stock tab / dropdown / refresh templates (G38)
- Custom tooltip frame copied from `LFGBrowseSearchEntryTooltip`; Report entries (needs a taint probe)
- Settings panel, remembered sort / filters, localization-ready strings
- README screenshots once tested in game

## Out of Scope

- Retail support — Forever's Vanilla-style finder only
- Applications / apply flow — Forever has listings only
- A separate window in game — in place only
- Writing the listing description — Blizzard's comment box is secure

## Traceability

| Requirement | Phase | Status |
|-------------|-------|--------|
| GS-01 | Phase 1 | Complete |
| GS-02 | Phase 1 | Complete |
| REL-01 | Phase 1 | Complete |
| REL-02 | Phase 1 | Complete |
| REL-03 | Phase 1 | Complete |
| UIP-02 | Phase 2 | Pending |
| UIP-03 | Phase 2 | Pending |
| UIP-04 | Phase 2 | Pending |
| UIP-05 | Phase 2 | Pending |
| UIP-06 | Phase 2 | Pending |
| UIP-10 | Phase 2 | Pending |
| UIP-12 | Phase 2 | Pending |
| UIP-07 | Phase 3 | Pending |
| UIP-08 | Phase 3 | Pending |
| UIP-09 | Phase 3 | Pending |
| UIP-13 | Phase 3 | Pending |
| UIP-14 | Phase 3 | Pending |
| UIP-15 | Phase 3 | Pending |
| UIP-16 | Phase 3 | Pending |
| MSG-01 | Phase 4 | Pending |
| MSG-02 | Phase 4 | Pending |
| MSG-03 | Phase 4 | Pending |
| MSG-04 | Phase 4 | Pending |
| MSG-05 | Phase 4 | Pending |
| MSG-06 | Phase 4 | Pending |
| LOCK-01 | Phase 4 | Pending |
| LOCK-02 | Phase 4 | Pending |
| LOCK-03 | Phase 4 | Pending |
| UIP-01 | Phase 4 | Pending |
| UIP-11 | Phase 4 | Pending |
| REL-04 | Phase 5 | Pending |

**Coverage:** 31/31 v0.1 requirements mapped, none duplicated.
