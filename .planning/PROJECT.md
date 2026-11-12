# TerribleGroupFinder

## What This Is

A WoW Forever addon that improves the game's own group finder in place. Forever's Browse
tab becomes a table of solo players and groups (in the game's two sections) that players
can sort by role, level, activity and listed time, showing where each player or leader is,
with one-click whispers (and invites) from preset messages and friend / recent ally marks,
while looking and behaving like the stock finder. It is for Forever players looking for
groups or members who find the stock bulletin board hard to scan.

## Core Value

Finding the right players or group fast: the listing must be easy to read and order (role,
level, activity, location) and quick to act on, without leaving or replacing Forever's own
group finder.

## Current State

**Shipped v0.1.0 "Initial Release" (2026-11-12)** — the first public release; see
[MILESTONES.md](MILESTONES.md) and the archives in [milestones/](milestones/). ~5.3k lines of
Lua/XML; checked in the live Forever client by the author. Releases are tagged on `main`; the
release workflow builds the zip and the author uploads it to CurseForge / Wago by hand.

## Next Milestone Goals

Not planned yet (start with `/gsd-new-milestone`). Candidates: the gear score finish-or-drop
decision (backlog 999.1), the cleanup list from the v0.1 release review
(`phases/05-release-review/05-HUMAN-UAT.md` item 11), settings, remembered sort / filters,
localisation.

<details>
<summary>v0.1 Initial Release — milestone brief (archived)</summary>

**Goal:** Ship the first public release: Forever's finder looks and works as close as possible
to the stock one, with our table, sorting, hiding and quick contact on top; gear score is
switched off for now.

**Target features:**
- Gear score switched off (no column, no own GS, no inspects, no `{gs}`); code kept behind a
  disabled switch; a backlog item decides between finishing it and dropping it
- New preset defaults: request `[TGF] Level {level} {class}, for {activity}`, invite
  `[TGF] Group for {activity} with {players} players` (`{players}` = your group's size)
- Key buttons under each preset's text box that insert a key; the addon key (`[TGF]`) always
  sits at the start, at most once
- Invite preset: Auto-send, then Auto-invite (enabled only with Auto-send) that also sends the
  group invite after the whisper
- 1 s anti-spam lock after an automatic send: the clicked button stays pressed ("sending"),
  every whisper / invite button ignores clicks until it ends
- Fix: section headers (Solo players / Groups) get their own hover look, not the row highlight
- UI parity with Forever's stock finder (look and usability), from a fresh review of
  wow-ui-source `forever` (see `research/UI-PARITY.md`)
- Release readiness: CurseForge `1798577` / Wago `Q6aqvA6W` IDs, release workflow upload keys,
  addon icon (sources under `Media/Source/`, in-game texture as the TOC `IconTexture`),
  packaging checked
- Release Review phase (code cleanup, version, changelog draft, author review)

### Progress log during v0.1

Prototype (initial commit on `main`, 2026-11-04), checked with a preview stand-in on sample
data and stubbed smoke tests, not yet in the live client. Design notes:
[research/DESIGN-NOTES.md](research/DESIGN-NOTES.md); Blizzard source map:
[research/FOREVER-GROUPFINDER.md](research/FOREVER-GROUPFINDER.md).

Milestone v0.1: Phase 1 complete (2026-11-11) — gear score switched off behind
`ns.GEAR_SCORE = false` (design kept in [research/GEARSCORE.md](research/GEARSCORE.md)); TOC
carries the CurseForge / Wago IDs and the `Media/Textures` icon; packaging ships only the addon
files and the texture. In-game checks pending (Phase 1 HUMAN-UAT).

Phase 2 complete (2026-11-11) — the Browse list scrolls with our own `WowScrollBoxList` +
`MinimalScrollBar` (separate header / row templates in `UI/Templates.xml`, `W.List` fallback);
section headers use the finder's grouping look; selection by result ID like stock; single inset,
search box in the stone band, stock column headers above BarTop, Needs my role and status in the
bottom bar; stock row art, fonts, colours and greyed rows; stock spinner and search-state texts;
stock sounds. In-game checks pending (Phase 2 HUMAN-UAT).

Phase 3 complete (2026-11-11) — solo players show the stock micro role icons and groups take open
slots from the server's remaining counts; Discord icon and voice wording as stock; your own row
shows "Your listing" in green with the stock delist button (solo / leader only); the row tooltip
follows Forever's order and wording with our extras after (playstyle, spec / area, friends, listed
age, hidden note) and refreshes while hovered; the hide button is a small icon button; Needs my
role reads the server's remaining-slot counts. In-game checks pending (Phase 3 HUMAN-UAT).

Phase 4 complete (2026-11-11) — new default presets with the `[TGF]` key (`[TGF] Level 23 Warrior,
for The Deadmines`; `[TGF] Group for <activity> with <n> players`), one button per key under each
preset box (`[TGF]` always first, once), Auto-send then Auto-invite on the invite preset (Auto-invite
only with Auto-send), a 1 s contact lock with a pressed "sending" look after any auto-send, a one-time
migration of saved old defaults, the Messages side tab made stock-correct and its panel rebuilt with
the Who tab's layers and multi-line boxes (one builder for game and preview). In-game checks pending
(Phase 4 HUMAN-UAT).

Phases 04.1 (player location, inserted) and 5 (release review) complete 2026-11-12; the
migration was later dropped, and all in-game checks passed at close.

</details>

## Requirements

### Validated

- ✓ Gear score switched off behind `ns.GEAR_SCORE`, code and notes kept (GS-01, GS-02) — v0.1
- ✓ `[TGF]` presets with key buttons; the invite preset for every whisper while in a group, the request preset to groups while on your own (MSG-01..06) — v0.1
- ✓ Auto-send / Auto-invite and the 1 s contact lock with the pressed look (LOCK-01..03) — v0.1
- ✓ UI parity with the stock finder: ScrollBox list, section headers, selection, layout, row art, role icons, own listing with delist, stock tooltip, search states, sounds, sort headers, the stock right-click menu (UIP-01..16) — v0.1
- ✓ Player location on rows and in group tooltips (LOC-01, LOC-02) — v0.1
- ✓ Release plumbing: store IDs, icon, packaging with LICENSE, README, changelog (REL-01..04; uploads are manual) — v0.1

<!-- Built in the prototype; confirmed in the live client with v0.1. -->

- ✓ In-place table inside Forever's `LFGBrowseFrame` (its list and bottom buttons replaced; dropdowns, refresh and search stay Blizzard's; window widens while Browse shows) — prototype
- ✓ One list like Forever's: own listing first, collapsible "Solo players" / "Groups" sections ordered by solo vs leader — prototype
- ✓ Sorting within sections by Roles (tank > healer > damage), Lvl, Activity, Listed (the GS sort is off with gear score) — prototype
- ✓ Hide until relisted, and Needs my role, grey and move rows to the end of their section — prototype
- ✓ Whisper per row from presets (invite / request, placeholders, Auto-send off by default) in a Messages side tab — prototype
- ✓ Send Message and Group Invite (solo players) bottom buttons — prototype
- ✓ Gear score: ours, cached between sessions, outdated colour, ready-check inspect of the group, own GS shown — prototype (switched off in v0.1, code kept; see Deferred)
- ✓ Battle.net friend, friend and recent ally marks on names; "Friends in group" tooltip — prototype
- ✓ Preview stand-in and sample data for development (`/tgf preview` in game) — prototype

### Active

None — v0.1 shipped; the next milestone defines its requirements (`/gsd-new-milestone`).
v0.1's requirements are archived in [milestones/v0.1-REQUIREMENTS.md](milestones/v0.1-REQUIREMENTS.md).

### Deferred (next-milestone candidates)

- Gear score: decide between finishing it (tuning against real gear, sharing scores between TerribleGroupFinder users by addon whisper) and dropping it fully (code switched off in v0.1; backlog 999.1)
- v0.1 release-review cleanup list (tooltip blank lines, raw status colours, feedback for clicks during the lock, header label width, and more: `phases/05-release-review/05-HUMAN-UAT.md` item 11)
- Settings panel, remembered sort / filters, localization-ready strings

### Out of Scope

- Retail support — the addon targets Forever's Vanilla-style finder only (one TOC, interface 16001)
- Applications / apply flow — Forever's finder has listings only; contact is by whisper and invite
- A separate group finder window in game — the addon changes Forever's own finder in place
- Writing the listing description — Blizzard's comment box is secure; the Listing tab stays Blizzard's (delisting from your own row is the one deliberate exception)

## Context

- WoW Forever runs on the modern client (secret values, chat messaging lockdown, restricted
  calls such as `C_LFGList.Search` / `CreateListing` that need a hardware event).
- Forever is one mega-realm per ruleset (PvP, PvE, RP-PvP, RP-PvE); the finder lists only your
  own, so whispers and invites use plain character names.
- Blizzard UI reference: `C:\Users\jonat\Repositories\wow-ui-source`, branch `forever`
  (`Blizzard_GroupFinder_VanillaStyle`); retail's finder on the same repo for icons and patterns.
- Sister addon with the same conventions: TerribleBuffTracker.

## Constraints

- **Compatibility**: Forever only, `## Interface: 16001`, no flavour-forked files — one TOC
- **Taint**: never replace or write fields on Blizzard's finder; only Hide()/HookScript/hooksecurefunc, resize the parent, parent our frames to it — keeps the game's restricted calls working
- **Look**: native to Forever (Blizzard templates, atlases, icons) — the addon should feel like the game's own finder
- **Tooling**: Lua formatted with `stylua .`; deploy with `scripts/install.bat`; releases by tag through the BigWigs packager, zip uploaded to CurseForge / Wago by hand

## Key Decisions

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| Improve Forever's finder in place, not a new window | Players keep the game's flow; search and listing stay Blizzard's | ✓ Good |
| Follow Forever's model: solo players or groups, no applications | That is how Forever's finder works; "apply" is a retail concept | ✓ Good |
| Never remove rows: hidden / no-slot listings greyed at the end | Players keep the whole picture while focusing on what fits | ✓ Good |
| Our own gear score (slot weights, quality-scaled item level) | Readable on the item level scale; tunable to Forever's items | — On hold (switched off in v0.1) |
| Auto-sends lock all contact buttons for 1 s | Keeps the addon from being used to spam whispers / invites | ✓ Good (v0.1) |
| Auto-invite only after a real auto-send, never during chat lockdown | The invite always follows a sent whisper; lockdown only prefills | ✓ Good (v0.1) |
| The preset follows your group state: in a group always the invite preset; on your own, request to groups and invite to solo players | You offer your group when you have one; you ask for a spot when you don't | ✓ Good (v0.1) |
| Delist from your own row calls `C_LFGList.RemoveListing()` | Delisting is important enough to have on Browse; the one exception to "listing stays Blizzard's" | ✓ Good (v0.1) |
| Right-click opens the finder's own row menu (`CreateSearchEntryMenu`) | Same menu and reports as the stock rows | ✓ Good (v0.1) |
| Stock-style sort headers: label left at the template inset, arrow after it, columns widened to fit | Matches the stock sortable headers; nothing spills over | ✓ Good (v0.1) |
| No preset migration from the dev build | No compatibility needed before the first release | ✓ Good (v0.1) |
| Manual CurseForge / Wago uploads from the release zip | The author prefers it; no store keys in the repo secrets | — For now |
| Whisper presets with Auto-send off by default | Prefill keeps the player in control; Auto-send is opt-in | ✓ Good |
| License GPL-3.0 | Open source, share-alike | ✓ Good |

## Git Workflow

`git.branching_strategy = "milestone"` (config.json). Per-milestone flow:

1. **Start of milestone** → work happens on a dedicated branch `milestone/{milestone}-{slug}`
   (GSD creates it at the milestone's first `execute-phase`).
2. **On `complete-milestone`**, in this exact order:
   1. **Push the milestone branch to remote** (preserves full development history).
   2. **Squash-merge** the branch into `main` with a single clean commit message summarizing
      the milestone.
   3. **Tag** the resulting merge commit on `main` (annotated `vX.Y.Z`), then push the tag.
      Pushing the tag runs `.github/workflows/release.yml` (BigWigs packager), which publishes
      the release.

GSD's `complete-milestone` natively does the squash-merge and tag; the branch push and
tag-on-main ordering are enforced as this project convention.

## Milestone Close-out

**Milestones are atomic.** What ships is the net difference from the previous release. A bug
that is introduced and fixed inside the same milestone never existed as far as anything outside
`.planning/` is concerned: it is not mentioned in `CHANGELOG.md`, `README.md`, `CLAUDE.md`, code
or doc comments, or the squash-merge commit message on `main`. Only internal planning files
(phase SUMMARY / REVIEW / UAT files, STATE.md) record it. A bug in an already *released* version
that the milestone fixes is changelog material as usual.

**Every milestone ends with a Release Review phase.** `/gsd-new-milestone` adds it as the last
phase of the roadmap, and `/gsd-complete-milestone` does not start until it is complete. Its
steps, in order:

1. **Code cleanup.** Remove duplication added during the milestone (merge near-identical
   helpers, drop dead code and leftover scaffolding) and strip every mention of in-milestone bugs
   from code and doc comments, README.md and CLAUDE.md. No behaviour change. Run `stylua .`.
2. **README screenshots.** Re-take any screenshot whose screen changed (once the README has any).
3. **Version.** The TOC keeps `## Version: @project-version@` (the packager fills it in from the
   tag); confirm the milestone's version `X.Y.Z` for the tag `vX.Y.Z`.
4. **Changelog draft.** Write the new `## vX.Y.Z` section at the top of `CHANGELOG.md` from the
   milestone's net changes against the previous tag (the release workflow publishes the first
   `## ` section as the release notes), folding in anything landed between milestones: a
   one-line summary, then Added / Changed / Removed / Fixed, user-facing and short. Fixed lists
   only bugs that existed in a released version. This is a draft for the author.
5. **Author review (the phase's UAT, last step).** The author reviews and, as they see fit,
   rewrites `README.md` and the drafted `CHANGELOG.md` section. Agents change these two files
   only as the author directs. The author's confirmation closes the phase.

During a milestone, agents do not add `CHANGELOG.md` entries; step 4 writes them once.

## Evolution

This document evolves at phase transitions and milestone boundaries.

**After each phase transition** (via `/gsd-transition`):
1. Requirements invalidated? → Move to Out of Scope with reason
2. Requirements validated? → Move to Validated with phase reference
3. New requirements emerged? → Add to Active
4. Decisions to log? → Add to Key Decisions
5. "What This Is" still accurate? → Update if drifted

**After each milestone** (via `/gsd-complete-milestone`):
1. Full review of all sections
2. Core Value check — still the right priority?
3. Audit Out of Scope — reasons still valid?
4. Update Context with current state

---
*Last updated: 2026-11-12 after v0.1 milestone*
