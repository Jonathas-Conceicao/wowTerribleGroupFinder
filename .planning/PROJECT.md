# TerribleGroupFinder

## What This Is

A WoW Forever addon that improves the game's own group finder in place. Forever's Browse
tab becomes a table of solo players and groups (in the game's two sections) that players
can sort by role, level and gear score, with one-click whispers from preset messages, gear
scores remembered between sessions, and friend / recent ally marks. It is for Forever
players looking for groups or members who find the stock bulletin board hard to scan.

## Core Value

Finding the right players or group fast: the listing must be easy to read and order (role,
level, gear score) without leaving or replacing Forever's own group finder.

## Next Milestone

None planned yet. The repository holds a working prototype; start the next milestone with
`/gsd-new-milestone`. Candidates are under Requirements → Deferred.

## Current State

Prototype (initial commit on `main`, 2026-11-04), checked with a preview stand-in on sample
data and stubbed smoke tests, not yet in the live client. Design notes:
[research/DESIGN-NOTES.md](research/DESIGN-NOTES.md); Blizzard source map:
[research/FOREVER-GROUPFINDER.md](research/FOREVER-GROUPFINDER.md).

## Requirements

### Validated

<!-- Built in the prototype and confirmed in preview; still to be confirmed in the live client. -->

- ✓ In-place table inside Forever's `LFGBrowseFrame` (its list and bottom buttons replaced; dropdowns, refresh and search stay Blizzard's; window widens while Browse shows) — prototype
- ✓ One list like Forever's: own listing first, collapsible "Solo players" / "Groups" sections ordered by solo vs leader — prototype
- ✓ Sorting within sections by Roles (tank > healer > damage), Lvl, GS (groups: best known), Activity, Listed — prototype
- ✓ Hide until relisted, and Needs my role, grey and move rows to the end of their section — prototype
- ✓ Whisper per row from presets (invite / request, placeholders, Auto-send off by default) in a Messages side tab — prototype
- ✓ Send Message and Group Invite (solo players) bottom buttons — prototype
- ✓ Gear score: ours, cached between sessions, outdated colour, ready-check inspect of the group, own GS shown — prototype
- ✓ Battle.net friend, friend and recent ally marks on names; "Friends in group" tooltip — prototype
- ✓ Preview stand-in and sample data for development (`/tgf preview` in game) — prototype

### Active

<!-- Current scope. Empty until the next milestone is defined. -->

(None — no milestone in progress)

### Deferred (next-milestone candidates)

- Live-client validation of the prototype and fixes (layout at 620 wide, hidden parts staying hidden, Messages tab, friend marks, whisper prefill, ready-check inspects)
- Gear score tuning against real gear, and sharing scores between TerribleGroupFinder users by addon whisper
- Settings panel, remembered sort / filters, localization-ready strings
- First public release (CurseForge / Wago IDs, release workflow keys, README screenshots)

### Out of Scope

- Retail support — the addon targets Forever's Vanilla-style finder only (one TOC, interface 16001)
- Applications / apply flow — Forever's finder has listings only; contact is by whisper and invite
- A separate group finder window in game — the addon changes Forever's own finder in place
- Writing the listing description — Blizzard's comment box is secure; the Listing tab stays Blizzard's

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
- **Tooling**: Lua formatted with `stylua .`; deploy with `scripts/install.bat`; releases by tag through the BigWigs packager

## Key Decisions

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| Improve Forever's finder in place, not a new window | Players keep the game's flow; search and listing stay Blizzard's | ✓ Good |
| Follow Forever's model: solo players or groups, no applications | That is how Forever's finder works; "apply" is a retail concept | ✓ Good |
| Never remove rows: hidden / no-slot listings greyed at the end | Players keep the whole picture while focusing on what fits | ✓ Good |
| Our own gear score (slot weights, quality-scaled item level) | Readable on the item level scale; tunable to Forever's items | — Pending (tune in game) |
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
*Last updated: 2026-11-04 after initialization (GSD config only, no milestone)*
