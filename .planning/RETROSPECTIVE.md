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

## Milestone: v0.2.1 — Reset Details reminder, more region flags and spec points

**Shipped:** 2026-11-16
**Phases:** 4 | **Plans:** 7

### What Was Built
- Damage meter reset prompt (Details! or the game's meter), two triggers with their own settings, `/tgf meter`
- Region flags for every region from the author's flagpedia.net PNGs, a two-letter fallback, the generated flags removed
- Talent points per tree on friendly players' tooltips from the guarded quiet inspect

### What Worked
- Autonomous phases 12-15 with the in-game checks in one pass at the end, again
- Research changed the talent source to what Forever's own talent frame reads before any code was written
- Code review caught real in-game issues ahead of testing (popup overlap, double prompts with Details! auto-erase, foreign inspects)

### What Was Inefficient
- The v0.2 flags had been drawn by a script, against the author's art rule; they had to be replaced here
- The meter prompt was placed against game popups but not the zone name text, found only in game
- A suspected sheet bug got a fix before the author confirmed it; it was reverted

### Patterns Established
- No art is ever generated; image work only re-encodes the author's own pixels, and only when asked
- Small in-game reports: confirm the bug with the author before changing code that already works

### Key Lessons
1. Check the screen spots the game itself uses at the moment a frame of ours appears (zone text on entering an instance)
2. A fix for something the author hasn't seen break waits for the author's call

### Cost Observations
- Model mix: Opus (main session and agents)
- Sessions: 1 (with context compactions)
- Notable: a short milestone; most review findings were fixed before the author's in-game pass

---

## Milestone: v0.2.2 — Small Improvements

**Shipped:** 2026-11-20
**Phases:** 2 | **Plans:** 4

### What Was Built
- A movable damage meter prompt with the addon's icon and the game menu's buttons
- Settings buttons that close the options window through its own Close and then act
- A whisper activity menu at the cursor, with Edit
- The group-join meter prompt off by default for new installs only (Migrate schema 3)

### What Worked
- Prototyping in a live session with the author, then wrapping it into a short milestone
- Code review found pending-action edge cases (a refused close, a listing gone before the menu pick) before release

### What Was Inefficient
- gsd-tools `commit` put planning commits on a stray branch; they had to be rebased back
- The installed build was overwritten once by the author's addon manager and had to be reinstalled

### Patterns Established
- Plain `git add` / `git commit` for planning commits on milestone branches
- New defaults reach new installs only, through a Migrate step for existing saved data

### Key Lessons
1. An action armed for "after the panel hides" must be dropped when the panel refuses to hide
2. A menu entry chosen later must re-check what it acts on

### Cost Observations
- Model mix: Opus (main session and agents)
- Sessions: 1 (with context compactions)
- Notable: no research and no audit; two phases on top of an already tested prototype

---

## Milestone: v0.3.0 — Elite Quests finder and more inspect data

**Shipped:** 2026-11-25
**Phases:** 4 | **Plans:** 7

### What Was Built
- Opt-in defaults (schema 4) and a sectioned Settings page, then NEW tags for new options (schema 5)
- The elite quest eye in the tracker, with a secure cover that picks Quests & Zones and the zone
- Per-slot item level and enchant on the character sheet and the Inspect window

### What Worked
- All questions up front, then an autonomous run to the author's review with no pauses
- Code review caught two real bugs (the eye never showing beside a quest item, uncached inspect items staying blank)
- Proving the description question with the author's own `/run` and `/api` tests settled it with evidence instead of argument

### What Was Inefficient
- The first eye design (open + hint, nothing picked, finder widened) didn't match what the author wanted; the secure-click design came only in the review
- Too confident too early that the description was impossible; the author rightly pushed for in-game proof, which took several rounds of tests
- A `sed -i` on a planning file and a `sed` that stripped CRLF from a Lua file, both against project rules

### Patterns Established
- Secure picks in Blizzard's UI: a SecureActionButton cover placed by screen coordinates (nothing protected in the tracker) plus `/click` delegates whose `clickbutton` is set in PreClick
- Feature-claim disputes get settled by a minimal in-game `/run` the author can paste, one step at a time

### Key Lessons
1. Before calling something impossible, show the exact evidence (API structure, the game's error text) and give the author the one-line test
2. Ask how the author wants a flow to feel (one click vs. guided) before the autonomous run, not after

### Cost Observations
- Model mix: Opus (main session and agents)
- Sessions: 1 (with context compactions)
- Notable: research up front; no milestone audit; no smoke harness (not kept in the repo), checked in game by the author

---

## Milestone: v0.3.1 — Small fixes

**Shipped:** 2026-11-26
**Phases:** 2 | **Plans:** 6

### What Was Built
- Guards on every step of the elite quest eye's hover and click, failures listed by `/tgf quest`
- The invite's outcome on its row (accepted / declined / expired) from the game's system messages
- A Browse list that follows the activity picks at once, filtered from the answer already shown

### What Worked
- One day from kickoff to release: questions up front, an autonomous run, the author's in-game pass
- Code review caught three real issues before the author's pass (a half-built cover, missing patterns, decline-as-expired scope)

### What Was Inefficient
- The search bug was misread at kickoff ("first search after a reload") and fixed for that reading; the real issue (ticking one activity starts no search) only surfaced in the author's test, so the fix was redone in the review
- The `requirements mark-complete` tool broke a requirement line; fixed by hand

### Patterns Established
- Narrow the shown answer client-side from post-hooks on Blizzard's dropdown instead of searching (searching from addon code is blocked)
- Invite results from the game's `ERR_*` format strings turned into patterns (`%s` and positional `%1$s`)

### Key Lessons
1. For a UI bug, get the exact click sequence from the author before planning; read the Blizzard handler for each click
2. Changelog wording for robustness work: "guarded", not "fixed", when it only failed in edge cases

### Cost Observations
- Model mix: Opus (main session and agents)
- Sessions: 1 (with context compactions)
- Notable: no research, no milestone audit; checked in game by the author

---

## Cross-Milestone Trends

### Process Evolution

| Milestone | Sessions | Phases | Key Change |
|-----------|----------|--------|------------|
| v0.1 | 1 | 6 | First GSD milestone; autonomous run, then author polish in game |
| v0.2 | 1 | 6 | Autonomous run with all in-game checks deferred to one pass at the end |
| v0.2.1 | 1 | 4 | Same flow; research before talents; no generated art |
| v0.2.2 | 1 | 2 | Live prototype first, then a short wrap-up milestone; no research, no audit |
| v0.3.0 | 1 | 4 | Questions batched up front, autonomous run to review; the review reworked the eye with the author's in-game tests |
| v0.3.1 | 1 | 2 | Small fixes in a day; the search fix was reworked after the author's in-game test |

### Cumulative Quality

| Milestone | Tests | Coverage | Zero-Dep Additions |
|-----------|-------|----------|-------------------|
| v0.1 | fengari smoke harness, 4 modes, all passing | stubbed client API | 0 |
| v0.2 | same harness, 3 modes, all passing (settings, item level, region, motion, raid probes added) | stubbed client API | 0 |
| v0.2.1 | same harness, 3 modes, all passing (meter, region tags, talents added) | stubbed client API | 0 |
| v0.2.2 | same harness, 3 modes, all passing (meter move, settings close, activity menu, migrate added) | stubbed client API | 0 |
| v0.3.0 | none (harness not in the repo); `stylua` parse, code review, author's in-game pass | in game | 0 |
| v0.3.1 | none; `stylua` parse, code review, author's in-game pass | in game | 0 |

### Top Lessons (Verified Across Milestones)

1. In-game visual feedback after the autonomous run drives most late work (v0.1, v0.2): budget for it
2. Blizzard's own source is the reference for every native look (v0.1, v0.2)
