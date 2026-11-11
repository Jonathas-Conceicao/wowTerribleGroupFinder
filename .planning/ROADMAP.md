# Roadmap: TerribleGroupFinder

## Milestones

- [ ] **v0.1 Initial Release** - Phases 1-5 (in progress)

## Overview

v0.1 ships the first public release: Forever's own group finder, improved in place, looking and working as close as possible to the stock one, with our table, sorting, hiding and quick contact on top. Gear score is switched off. The work moves from switching gear score off and getting release plumbing in place, to the list foundation (ScrollBox, headers, selection, layout), to the rows and tooltip, to messages and the contact lock, and ends with the mandatory Release Review.

## Phases

- [ ] **Phase 1: Gear Score Off and Release Plumbing** - Gear score disappears from the player's view; store IDs, icon and packaging ready
- [ ] **Phase 2: List Foundation** - ScrollBox list with stock-style section headers, selection, layout, row look and search states
- [ ] **Phase 3: Rows, Tooltip and Own Listing** - Stock-faithful role icons, own-listing row, tooltip and row details
- [ ] **Phase 4: Messages and Contact** - New presets, key buttons, Auto-send / Auto-invite, 1 s lock, Messages tab and panel
- [ ] **Phase 5: Release Review** - Code cleanup, version, changelog draft, author review

## Phase Details

### Phase 1: Gear Score Off and Release Plumbing
**Goal**: Players see no gear score anywhere and the addon is ready to be packaged and published with its IDs and icon
**Depends on**: Nothing (first phase)
**Requirements**: GS-01, GS-02, REL-01, REL-02, REL-03
**Success Criteria** (what must be TRUE):
  1. In the Browse table and the preview there is no GS column, no "Your GS", no GS in tooltips and no `{gs}` key in the Messages tab
  2. A ready check starts no inspects; GearScore.lua is still in the repo behind a single disabled switch
  3. `.planning/research/GEARSCORE.md` holds the gear score design notes and the backlog has the "finish or drop" item
  4. The TOC carries the CurseForge and Wago IDs and an `IconTexture`; the icon sources sit under `Media/Source/` and the in-game texture under `Media/Textures/`
  5. The package zip from `scripts/package` and the install output contain only the addon files and the in-game texture
**Plans**: 3 plans

Plans:
- [x] 01-01-PLAN.md — Gear score off behind `ns.GEAR_SCORE` (Core, GearScore, Messages, Listings, Table) + smoke harness checks (wave 1)
- [x] 01-02-PLAN.md — `.planning/research/GEARSCORE.md` design notes and backlog 999.1 check (wave 1)
- [x] 01-03-PLAN.md — Store IDs, upload keys, icon (Media/Source, png2tga, TGA), packaging / install fixes and checks (wave 2)

### Phase 2: List Foundation
**Goal**: The Browse list is built like the stock one: it scrolls with Blizzard's ScrollBox, and headers, selection, layout and row look match Forever's finder
**Depends on**: Phase 1
**Requirements**: UIP-02, UIP-03, UIP-04, UIP-05, UIP-06, UIP-10, UIP-12
**Success Criteria** (what must be TRUE):
  1. The list scrolls with Blizzard's scroll bar; section headers (Solo players / Groups) collapse and expand with the stock atlas and plus/minus, and hovering a header shows the header look, not the row highlight
  2. Clicking a row selects it (click again clears; delisted and own rows are not selectable); selection survives a re-sort and clears on new results, with the click sound
  3. The Browse frame shows a single inset with the search box in the stone band, column headers above the bar, and Needs my role and the status text in the bottom bar
  4. Rows use the stock background, hover and selected art, fonts and colours; greyed rows use stock grey with desaturated icons; groups show the leader icon
  5. Searching shows the stock spinner; empty results, a failed search and our own filter each show their text; hide and checkboxes play the stock sounds
**Plans**: TBD
**UI hint**: yes

### Phase 3: Rows, Tooltip and Own Listing
**Goal**: Each row and its tooltip read like Forever's own: solo players with role icons, your own listing with its delist button, and a tooltip in the stock order
**Depends on**: Phase 2
**Requirements**: UIP-07, UIP-08, UIP-09, UIP-13, UIP-14, UIP-15, UIP-16
**Success Criteria** (what must be TRUE):
  1. Solo players show the stock micro role icons, and the voice chat icon and wording match the stock finder
  2. Your own listing row shows "Your listing" in green and, as solo or leader, the stock delist button
  3. Hovering a row shows a tooltip in the stock order and wording, with playstyle and the comment in light grey, followed by our friends in group and hidden note; it refreshes when results update while hovered
  4. The hide button is a small stock-style button with an icon
  5. With Needs my role on, listings the server reports as having no slot for your role are greyed and moved to the end of their section
**Plans**: TBD
**UI hint**: yes

### Phase 4: Messages and Contact
**Goal**: Players contact others in one click from sensible default presets, with Auto-send and Auto-invite, and cannot spam
**Depends on**: Phase 3
**Requirements**: MSG-01, MSG-02, MSG-03, MSG-04, MSG-05, MSG-06, LOCK-01, LOCK-02, LOCK-03, UIP-01, UIP-11
**Success Criteria** (what must be TRUE):
  1. The default request preset renders `[TGF] Level 23 Warrior, for The Deadmines` and the default invite preset renders `[TGF] Group for <activity> with <n> players`, with n your current group size
  2. Under each preset's text box a button per key inserts that key at the cursor; the addon key always sits at the start and appears at most once
  3. The invite preset has Auto-send and then Auto-invite; Auto-invite is greyed unless Auto-send is checked and unchecks with it; with both on, one click on a solo player whispers and then sends the group invite
  4. After an auto-send, the clicked button stays pressed for 1 s and every whisper / invite button, including the bottom Send Message, ignores clicks until it ends
  5. The Messages side tab starts unchecked, never shows checked with another tab, fills its icon like Forever's tabs and has a stock-style tooltip; its panel uses the Who tab's frame layers, multi-line preset boxes and native checkboxes with sounds
**Plans**: TBD
**UI hint**: yes

### Phase 5: Release Review
**Goal**: The milestone is clean, versioned and documented, and the author has reviewed the README and changelog
**Depends on**: Phase 4
**Requirements**: REL-04
**Success Criteria** (what must be TRUE):
  1. Duplication and leftover scaffolding from the milestone are removed, no in-milestone bug is mentioned outside `.planning/`, and `stylua .` is clean with behaviour unchanged
  2. The milestone version `X.Y.Z` is confirmed against the TOC's `@project-version@` and the tag `vX.Y.Z`
  3. `CHANGELOG.md` has a drafted `## vX.Y.Z` section at the top built from the milestone's net changes
  4. The author has reviewed `README.md` and the `CHANGELOG.md` draft and confirmed the phase
**Plans**: TBD

## Progress

| Phase | Plans Complete | Status | Completed |
|-------|----------------|--------|-----------|
| 1. Gear Score Off and Release Plumbing | 3/3 | Executed | - |
| 2. List Foundation | 0/TBD | Not started | - |
| 3. Rows, Tooltip and Own Listing | 0/TBD | Not started | - |
| 4. Messages and Contact | 0/TBD | Not started | - |
| 5. Release Review | 0/TBD | Not started | - |

## Backlog

### Phase 999.1: Gear score: finish or drop (BACKLOG)

**Goal**: Decide whether to finish gear score (tuning against real gear, sharing scores between TerribleGroupFinder users by addon whisper) or drop it fully; the code stays switched off until then
**Source**: GS-02
**Requirements**: TBD
**Plans**: 0 plans

Plans:
- [ ] TBD (promote with /gsd-review-backlog when ready)
