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

## Cross-Milestone Trends

### Process Evolution

| Milestone | Sessions | Phases | Key Change |
|-----------|----------|--------|------------|
| v0.1 | 1 | 6 | First GSD milestone; autonomous run, then author polish in game |

### Cumulative Quality

| Milestone | Tests | Coverage | Zero-Dep Additions |
|-----------|-------|----------|-------------------|
| v0.1 | fengari smoke harness, 4 modes, all passing | stubbed client API | 0 |

### Top Lessons (Verified Across Milestones)

1. (to be filled as later milestones confirm v0.1's lessons)
