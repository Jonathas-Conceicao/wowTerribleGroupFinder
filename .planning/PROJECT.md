# TerribleGroupFinder

## What This Is

A WoW Forever addon that improves the game's own group finder in place. Forever's Browse
tab becomes a table of solo players and groups (in the game's two sections) that players
can sort by role, level, activity and listed time, showing where each player or leader is,
with one-click whispers (and invites) from preset messages, friend / recent ally marks and
region flags, while looking and behaving like the stock finder; the list refreshes in place.
Beyond the finder it shows item level, from the game's own data, on player and item tooltips,
the character sheet and the Inspect window, talent points on player tooltips, and asks to reset
the damage meter on joining a group or entering an instance, with a settings page for every extra. It is for
Forever players looking for groups or members who find the stock bulletin board hard to scan.

## Core Value

Finding the right players or group fast: the listing must be easy to read and order (role,
level, activity, location) and quick to act on, without leaving or replacing Forever's own
group finder.

## Current State

**Shipped v0.2.2 "Small Improvements" (2026-11-20)**, after v0.2.1 "Reset Details reminder,
more region flags and spec points" (2026-11-16), v0.2.0 "ILvL Info and Improved Refresh" (2026-11-15) and v0.1.0 "Initial Release"
(2026-11-12); see [MILESTONES.md](MILESTONES.md) and the archives in
[milestones/](milestones/). ~9.2k lines of Lua/XML; checked in the live Forever client by the
author. Releases are tagged on `main`; the release workflow builds the zip and the author
uploads it to CurseForge / Wago by hand.

## Current Milestone: v0.3.0 Elite Quests finder and more inspect data

**Goal:** One click from an elite quest to a group for it, fuller gear info (item level,
enchants, sockets per slot) on the character sheet and the Inspect window, and every extra that
isn't the group finder made opt-in so the addon doesn't clash with similar addons.

**Target features:**
- Opt-in defaults: on by default only the Elite quest button, Dynamic refresh, Swipe animations
  and Region flags; every other option (item level spots, talents, the new gear info, both meter
  prompts) off by default. New installs only: existing players keep what they have (an
  `ns.Migrate` schema-4 step, as v0.2.2 did for the group meter prompt)
- Elite quest eye button: in the objective tracker only, beside tracked elite (group) quests,
  looking like retail's tracker find-group button (checked against the reference UI source);
  it opens Forever's finder ready to create a group for that quest: the Quests & Zones category
  (ID 116), the quest's map / activity selected and the quest name as the description, as far
  as the secure description box and restricted calls allow (research decides the route); folds
  in backlog 999.5
- Per-slot gear info on the character sheet and the Inspect window: each gear slot shows its
  item level, its enchant (or a missing-enchant mark) and its socket gems; the existing overall
  Item Level row and Inspect text stay
- Settings page in sections, in this order: Group finder, Player inspection (item level,
  talents, enchants, sockets), Damage meter, Messages
- Release Review phase, tag `v0.3.0`

**Key context:** Forever's finder has a "Quests & Zones" category (116) and the LFGList API
takes quest IDs (`CanCreateQuestGroup`, `SetSearchToQuestID`, `questID` on listings); the
Listing tab's description box is secure, so writing the quest name there must go through the
game's own path or be dropped. Taint rules from CLAUDE.md apply to the tracker, the character
sheet and the Inspect window (hooks and our own frames only).

## Next Milestone Goals (candidates)

The README wording proposals left out of v0.2.2
(`milestones/v0.2.2-phases/17-release-review/17-HUMAN-UAT.md` item 3), the deferred v0.1
cleanup list, the v0.2 and v0.2.1 audits' tech debt, EU / Asia shard IDs from players'
`/tgf region` output, remembered sort / filters, localization-ready strings.

<details>
<summary>v0.2.2 Small Improvements — milestone brief (archived)</summary>

**Goal:** Wrap up the small improvements prototyped on `topic/dev` after v0.2.1 into a release.

**Target features:**
- Damage meter prompt: movable from Settings (Damage meter > Move: the prompt shows to drag;
  Lock saves the spot, Default goes back to the automatic one; both reopen Settings), Yes / No
  in the game menu's button style, the addon's purple-eye icon on its left with the question and
  buttons beside it
- The Settings page's Move and Edit whisper messages buttons close the options window themselves
  (its own `Close`, never in combat) so their action happens at once
- Whisper activity picker: where the preset uses `{activity}` and the listing has several, a
  menu at the cursor picks one (sent as Auto-send says), or Edit (fills the whisper box only)
- "Reset on joining a group" off by default for new installs; existing users keep it as it was

**Key context:** all of it is prototyped and harness-tested, uncommitted, on the milestone branch
(from `topic/dev`); no research. Two phases: the prototype work, then the Release Review.

</details>

<details>
<summary>v0.2.1 Reset Details reminder, more region flags and spec points — milestone brief (archived)</summary>

**Goal:** Ship the damage meter reset prompt as a feature, give every region a flag (from real
flag art, with a readable fallback for shard names we don't expect), and show friendly players'
talent points on their tooltip.

**Target features:**
- Damage meter reset prompt (built on `topic/dev`: `MeterReset.lua`, two settings, `/tgf meter`)
  ships; the popup text starts with `[TGF]` so players know where it comes from (and where to
  turn it off)
- Region flags for US, AU, EU, CN, KR and TW from the author's flagpedia.net PNGs (40 px wide,
  each its own height), converted to the game's texture format; no art generated
- Region rule: a shard group of two letters with an optional number (`AU`, `EU`, `EU1`..`EU9`,
  `US2`, `KR1`) whose country has a flag shows that flag, the full group in the tooltip; any other
  shard text (e.g. `EU Paris`) shows its first two letters as text on the row, the full text in
  the tooltip
- The flag-drawing script (`Media/Source/flags.js`) and its generated textures removed; an
  internal note records that the flags come from flagpedia.net (not in the README)
- Spec points: friendly players' tooltips show talent points per tree ("36/12/3") on a line
  under the item level line, from the same quiet inspect (`C_SpecializationInfo.
  GetSpecializationInfo(i, isInspect)` → `pointsSpent`); its own setting, on by default
- Release Review phase, tag `v0.2.1`

**Starting point:** branched from `topic/dev` (`6d2fe02`): the meter reset prompt and backlog
999.6 (folded into this milestone).

**Adjusted at close:** talent points come from `C_Traits` group currency `spent` per tree (as
Forever's talent frame), not `pointsSpent`; the line reads "Talents 31/20/0". The meter prompt
skips a same-instance run-back within 15 min and instances Details! erases on its own.

</details>

<details>
<summary>v0.2 ILvL Info and Improved Refresh — milestone brief (archived)</summary>

**Goal:** Item level shown wherever players look, from the game's own data (replacing gear
score), a settings window to turn each extra on or off, the finder's refresh made seamless with
animations, and a region flag on every listing.

**Target features:**
- Gear score dropped: its code removed (switch, column, sort, tooltip lines, inspects, saved
  data); the design notes stay in `research/GEARSCORE.md`; backlog 999.1 closed
- Item level on friendly players' tooltips (quiet inspect, prototyped), on item tooltips (retail
  look: "Item Level N" under the name; backlog 999.2), a line on the character sheet's stats
  (General, under Movement Speed) and raw text at the top right of the Inspect window
- Settings window: each item level spot on or off on its own (player tooltip, item tooltip,
  character sheet, Inspect), Dynamic refresh, the swipe animations, region flags, and a button
  that opens the finder on the Messages tab; the finder changes themselves are not optional
  (disable the addon instead)
- Dynamic refresh (the quiet refresh, prototyped): finished and tuned: slower swipes, rows
  sliding up when one leaves, the swipes playable in the preview for testing (backlog 999.4)
- Region flags (prototyped): US East / US West / Oceania on rows and in the tooltip; the
  US1 = West, US2 = East mapping confirmed in game
- Release Review phase (code cleanup, version, changelog draft, author review)

**Starting point:** branched from `topic/dev`, which already holds working prototypes of the
player tooltip item level (`ItemLevel.lua`, `/tgf ilvl`), the quiet refresh with swipes
(`UI/InPlace.lua`, `T.SwipeOut` / `T.SwipeIn`), region flags (`Region.lua`, `/tgf region`) and
the Needs my role fix; most work is tweaks, fixes and the new spots (sheet, Inspect, item
tooltips, settings).

**Adjusted at close:** region labels name the game's shard group (US1 / US2 / AU1); the
West / East mapping was never confirmed, so it is not assumed.

</details>

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
- ✓ Gear score removed: code, UI, ready-check inspects and saved data (schema-2 migration); settings registry `ns.Settings` with the seven v0.2 toggles (GSR-01) — v0.2
- ✓ Item level on friendly player tooltips, item tooltips, the character sheet (our own Item Level row under Movement Speed, native look) and the Inspect window, with a guarded quiet inspect; `{ilvl}` whisper key (ILV-01..05) — v0.2
- ✓ Region flags (one US flag, Oceania; tooltip names the shard group, US1 / US2 / AU1; own listing = leader's region; learned servers saved) and a tooltip on every row icon; raid role counts with icons (REG-01..04, ICO-01..02) — v0.2
- ✓ Dynamic refresh: same-filter refresh updates the list in place, swipes, rows slide up, dropped listings stay out until a new search; simulated in the preview (REF-01..04) — v0.2
- ✓ Settings page in the game's Settings (item level spots, Dynamic refresh, swipes, region flags, "Edit whisper messages"), `/tgf settings` / `set` (SET-01..07) — v0.2
- ✓ Release Review for v0.2.0 (REL-05) — v0.2
- ✓ Damage meter reset prompt on joining a group / entering an instance, "[TGF]" text, two settings, `/tgf meter` (MTR-01..04) — v0.2.1
- ✓ Region flags for US, AU, EU, CN, KR, TW from flagpedia.net art, a two-letter tag otherwise, the full group in the tooltip; generated flags removed (REG-05..08) — v0.2.1
- ✓ Talent points per tree on friendly players' tooltips with its own setting (SPC-01..02) — v0.2.1
- ✓ Release Review for v0.2.1 (REL-06) — v0.2.1
- ✓ Movable damage meter prompt (Move / Lock / Default), the addon's icon, the game menu's buttons (MTR-05..07) — v0.2.2
- ✓ "Ask to reset on joining a group" off for new installs, kept for existing players (MTR-08) — v0.2.2
- ✓ Settings' Move and Edit whisper messages close the options window and act at once (SET-01) — v0.2.2
- ✓ Whisper activity menu for listings with several activities, with Edit (MSG-01..02) — v0.2.2
- ✓ Release Review for v0.2.2 (REL-07) — v0.2.2

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

v0.3.0 requirements: see [REQUIREMENTS.md](REQUIREMENTS.md) (opt-in defaults, elite quest
eye button, per-slot gear info, Settings sections, Release Review). Archived:
[v0.1](milestones/v0.1-REQUIREMENTS.md), [v0.2](milestones/v0.2-REQUIREMENTS.md),
[v0.2.1](milestones/v0.2.1-REQUIREMENTS.md), [v0.2.2](milestones/v0.2.2-REQUIREMENTS.md).

### Deferred (next-milestone candidates)

- v0.2.1 audit open items (talents need valid inspect data, a later game popup can overlap the meter prompt, possible soft flag edges, region groups over 32 bytes): `milestones/v0.2.1-MILESTONE-AUDIT.md`
- v0.2 audit tech debt (unused `SP.ID()`, `searchOut` reset edge case, tooltip spots without change listeners): `milestones/v0.2-MILESTONE-AUDIT.md`
- v0.1 release-review cleanup list (tooltip blank lines, raw status colours, feedback for clicks during the lock, header label width, and more: `milestones/v0.1-phases/05-release-review/05-HUMAN-UAT.md` item 11)
- Remembered sort / filters, localization-ready strings

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
| Our own gear score (slot weights, quality-scaled item level) | Readable on the item level scale; tunable to Forever's items | ✗ Dropped in v0.2 for item level |
| Item level from the game's own data instead of gear score | Blizzard's figures (`GetAverageItemLevel`, `C_PaperDollInfo.GetInspectItemLevel`) are what players know; more natural than a score of ours | ✓ Good (v0.2) |
| Settings never turn off the finder changes themselves | The table in the finder is the addon; to go without it, disable the addon | ✓ Good (v0.2) |
| Region tooltip names the game's shard group (US1 / US2 / AU1), no West / East | The mapping could not be confirmed; a confidently wrong label is worse than the game's own name; generic for any region | ✓ Good (v0.2) |
| Raid-sized groups show the game's role count (count + role icon) | Matches Forever's own and retail's raid display; slot icons can't fit 40 | ✓ Good (v0.2) |
| Changelog written for players, against the last release | Players read it; nothing they never saw (e.g. gear score) | ✓ Good (v0.2) |
| No art is generated (code or AI); the author draws or sources every image | The v0.2 flags were drawn by a script, contradicting the README's art note; v0.2.1 replaced them with flagpedia.net flags | ✓ Good (v0.2.1) |
| The Settings page's Move and Edit whisper messages buttons close the game's Settings panel through its own `Close(true)` | Their action (drag the prompt, the Messages tab) needs the panel gone; the panel's own Close keeps the unapplied-settings prompt and writes nothing on it | ✓ Good (v0.2.2) |
| A new default reaches new installs only (`ns.Migrate` saves the old value for existing players) | Players who had the prompt keep what they knew; settings saved only once set would otherwise flip silently | ✓ Good (v0.2.2) |
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
| Character sheet Item Level row: our own frame from Blizzard's stat row template on the stats list's scroll target, placed under Movement Speed by moving the shown rows' anchors; never an entry in Blizzard's stats list | Inserting Blizzard's `ITEMLEVEL` element into the pane's `elementData` tainted the sheet in game (secure code then failed comparing secret values, "execution tainted by TerribleGroupFinder"); writing `PAPERDOLL_STATCATEGORIES` taints the same path. Moving anchors writes no Lua values | ✓ Good (v0.2) |

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
*Last updated: 2026-11-24 at the start of the v0.3.0 milestone*
