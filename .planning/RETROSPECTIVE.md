# Project Retrospective

*A living document updated after each milestone. Lessons feed forward into future planning.*

## Milestone: v0.1 — Initial Release

**Shipped:** 2026-11-12
**Phases:** 6 (1, 2, 3, 4, 04.1 inserted, 5) | **Plans:** 19 | **Sessions:** 1 (long, with an AFK autonomous run)

### What Was Built
- Gear score switched off behind one flag, code and notes kept
- Browse table on Blizzard's ScrollBox with stock headers, selection, layout, row art, tooltip, own listing with delist, right-click menu and stock-style sort headers
- Messages tab: `[TGF]` presets with key buttons, Auto-send / Auto-invite, a 1 s anti-spam lock
- Player location on rows and in group tooltips
- Release plumbing: store IDs, icon, LICENSE in the zip, README with screenshots, changelog

### What Worked
- The autonomous run carried phases 1-4 through plan → execute → review → verify while the author was away; the author's review then focused on look and feel
- The fengari smoke harness (four modes: default, gear score, fallback, attach) caught regressions on every change, including stub-only surprises
- Reading wow-ui-source's `forever` branch for each stock behaviour (sort headers, row menu, search box) gave changes that matched the game the first time

### What Was Inefficient
- Layout values were tuned in code and stubs, but real font metrics and atlas sizes only showed in game: the sort-arrow fit took three rounds, and text clipping on the Messages tab surfaced late
- GSD tooling garbled STATE.md / REQUIREMENTS.md and its auto-extracted accomplishments; both needed hand fixes
- 45 in-game checks piled up until the end instead of being run per phase

### Patterns Established
- Follow the stock implementation for any UI element the game already has (template inset, arrow placement, menus) rather than inventing a variant
- Measure text at build time (`GetStringWidth`, atlas size) and size columns from it, with a fallback estimate
- Call Blizzard's own methods (e.g. `CreateSearchEntryMenu`) instead of rebuilding their UI, without writing fields on their frames
- Author decisions recorded in the phase HUMAN-UAT file and reflected in CLAUDE.md / PROJECT.md the same day

### Key Lessons
1. Send a build to the author for an in-game look after each UI phase, not only at the release review
2. Give every text element an explicit width bound and wrap / max-lines rule when it is created
3. Treat GSD SDK writes to STATE.md and REQUIREMENTS.md as drafts and review the diff before committing

### Cost Observations
- Model mix: Opus (main session and agents)
- Sessions: 1
- Notable: most rework came from in-game visual polish after the autonomous run, not from logic bugs

---

## Milestone: v0.2 — ILvL Info and Improved Refresh

**Shipped:** 2026-11-15
**Phases:** 6 | **Plans:** 15

### What Was Built
- Gear score removed; schema-2 migration; `ns.Settings` registry with seven toggles
- Item level on player and item tooltips, a character sheet row under Movement Speed, the Inspect window; `{ilvl}` key
- Region flags from listings' hidden shards, row icon tooltips, raid role counts with icons
- Dynamic refresh with `ns.Motion` swipes and slides, simulated in the preview
- Settings page in the game's Settings, `/tgf settings` / `set`

### What Worked
- Autonomous phases 6-11 with in-game checks deferred to the end; the author then tested everything in one pass
- Reading Blizzard's own source (`wow-ui-source`, branch `forever`) before each UI change: the stat row template, ScrollBox layout and the raid RoleCount template all came from there
- The fengari smoke harness caught regressions quickly across all modes after each late change

### What Was Inefficient
- The character sheet row took three designs (an entry in Blizzard's list tainted the sheet; a bottom strip; then our own row moving anchors)
- The US West / East mapping was planned as "confirm in game" but never had an independent signal; it was dropped at close for the game's own group names
- The release-review checklist sat untouched until close; the README missed `{ilvl}` until the diff review

### Patterns Established
- Outside the finder: only hooks and our own frames; moving a Blizzard frame's anchors is the most we do (writes no Lua values)
- Show the author a diff against the last release tag for README / changelog review
- Changelog for players, relative to the last release

### Key Lessons
1. Any write into Blizzard's data on a secure path taints, however small; plan for our own frame first
2. Don't ship a label resting on an unconfirmed assumption: use the game's own names
3. Re-check docs against new keys / features added after the release review drafts

### Cost Observations
- Model mix: Opus (main session and agents)
- Sessions: 1 (with context compactions)
- Notable: late in-game feedback (sheet look, flags, raids, regions) drove most of the work after the autonomous run, as in v0.1

---

## Cross-Milestone Trends

### Process Evolution

| Milestone | Sessions | Phases | Key Change |
|-----------|----------|--------|------------|
| v0.1 | 1 | 6 | First GSD milestone; autonomous run, then author polish in game |
| v0.2 | 1 | 6 | Autonomous run with all in-game checks deferred to one pass at the end |

### Cumulative Quality

| Milestone | Tests | Coverage | Zero-Dep Additions |
|-----------|-------|----------|-------------------|
| v0.1 | fengari smoke harness, 4 modes, all passing | stubbed client API | 0 |
| v0.2 | same harness, 3 modes, all passing (settings, item level, region, motion, raid probes added) | stubbed client API | 0 |

### Top Lessons (Verified Across Milestones)

1. In-game visual feedback after the autonomous run drives most late work (v0.1, v0.2): budget for it
2. Blizzard's own source is the reference for every native look (v0.1, v0.2)
