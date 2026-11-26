# Milestones

## v0.3.1 Small fixes (Shipped: 2026-11-26)

**Delivered:** the invite's outcome on its row (accepted / declined / expired), a Browse list
that follows the activities you pick at once without Refresh, and guards on every step of the
elite quest eye's hover and click.

**Phases completed:** 2 phases (22-23), 6 plans
**Requirements:** 5/5 (QST-05, INV-01..02, SRCH-01, REL-09)
**Git:** 32 commits on `milestone/v0.3.1-small-fixes` (plus 3 milestone setup commits on
`main`), 2026-11-26; 7 shipped/source files changed (+570 / −116, outside `.planning/`);
~11.7k lines of Lua/XML
**Tag:** `v0.3.1`

**Key accomplishments:**

- Eye guards (`QuestButton.lua`): `Try` / `Guarded` around every hover and click step, secure
  attributes cleared first so a failed step leaves a click that does nothing, the cover built
  once; a failure prints "Quest eye: <step> failed" once per step and `/tgf quest` lists them

- Invite outcomes (`Messages.lua`, `UI/Table.lua`): `M.MarkInvited` keeps `{ name, at, outcome }`
  per invite; `CHAT_MSG_SYSTEM` patterns from the game's `ERR_*` strings (positional `%1$s`
  too), `GROUP_ROSTER_UPDATE` and a 2-minute timer resolve it; a decline at 55 s or later reads
  expired; the Listed cell colours it; the preview cycles the three

- Activity picks narrow the list (`UI/InPlace.lua`, `Listings.lua`): `Listings.Read(previous,
  only)` filters to a set of activities; the answer is narrowed when it arrives and whenever the
  picks change (post-hooks on the activity dropdown's `ValueSetSelected` / `ValueReset`), with
  no search of ours; reworked in the review after the author's report

- Release Review: code comments tidied, CLAUDE.md updated, changelog drafted and reviewed
  ("guarded", not "fixed", for the eye); README and prints unchanged (author's call)

**Audit:** not run (closed on the author's in-game pass: all 13 checks of Phase 22 and the
review items of Phase 23 passed; the two author decisions kept as shipped).

---

## v0.3.0 Elite Quests finder and more inspect data (Shipped: 2026-11-25)

**Delivered:** an eye on tracked elite quests that opens Forever's Listing tab on Quests & Zones
with the quest's zone ticked and the cursor in the description box; each item's level and
enchant beside its slot on the character sheet and the Inspect window; only the group finder's
options on for new installs, with Settings sections and the game's NEW tags for new options.

**Phases completed:** 4 phases (18-21), 7 plans
**Requirements:** 13/13 (OPT, QST, GEAR, REL)
**Git:** 46 commits on `milestone/v0.3.0-elite-quests-finder-and-more-inspect-data` (plus 12
milestone setup commits on `main`), 2026-11-24 to 2026-11-25; 11 shipped/source files changed
(+2129 / −55, outside `.planning/`); ~11.2k lines of Lua/XML
**Tag:** `v0.3.0`

**Key accomplishments:**

- Opt-in defaults: `ns.Migrate` schema 4 keeps the six options that were on in v0.2.2 for
  players with saved data; new installs get only Elite quest button, Dynamic refresh, Swipe
  animations and Region flags; Settings in four sections (Group finder first)

- Elite quest eye (`QuestButton.lua`): retail's placement with the addon's purple eye; the click
  is a secure cover over the eye whose macro `/click`s the game's micro button, the Listing tab
  and two delegates that pick Quests & Zones and the zone's checkbox, so Post stays untainted;
  the cursor goes to the description box, which addons can't write (confirmed in game)

- Per-slot gear info (`GearSlots.lua`): item level and enchant beside each slot (weapons above
  their icons), "No enchant" only where an enchanter can enchant on Forever (neck and off-hand
  included; shoulders, rings and trinkets never), inspect-safe and item-load aware

- Settings NEW tags (schema 5, `settingsSeen`): the game's blue NEW on options newer than the
  player last saw, stacking across skipped versions, cleared when Settings closes after the page

- Release Review: author review round 2 in game (eye placement and secure click, no finder
  widening, slot text offsets, NEW tags); the description question settled with in-game tests
  (`CreateListing` has no text field; the box refuses `SetText` / `Insert`); README and the
  changelog reviewed and applied

**Audit:** not run (closed on the author's in-game pass: every UAT item of Phases 18-21 passed;
the open-artifact audit was clear).

**Known deferred items at close:** none new; the quest log LFG button stays backlog 999.5 (notes
updated with this milestone's findings).

---

## v0.2.2 Small Improvements (Shipped: 2026-11-20)

**Delivered:** a damage meter prompt the player can move, with the addon's icon and the game's
own buttons; Settings buttons that close the options window and act at once; an activity menu
when whispering a listing with several activities; and the group-join meter prompt off by
default for new installs.

**Phases completed:** 2 phases (16-17), 4 plans
**Requirements:** 8/8 (MTR, SET, MSG, REL)
**Git:** 25 commits on `milestone/v0.2.2-small-improvements` (from `topic/dev`), 2026-11-19 to
2026-11-20; 12 shipped/source files changed (+356 / −50, outside `.planning/`); ~9.2k lines of
Lua/XML shipped
**Tag:** `v0.2.2`

**Key accomplishments:**

- Damage meter prompt: Settings > Damage meter > Move shows it to drag, Lock saves the spot
  (`DB.meterPos`), Default goes back to the automatic one; the addon's icon on the left and
  Yes / No in the game menu's style (`SharedButtonTemplate`)

- `SP.CloseThen`: Move and Edit whisper messages close the Settings panel through its own
  `Close(true)` and act once it hides; unapplied game settings still ask (the action is dropped)

- Whisper activity menu at the cursor (`MenuUtil.CreateContextMenu`) for listings with several
  activities, with Edit (fills the whisper box with every activity, never sends)

- `ns.Migrate` schema 3: "Ask to reset on joining a group" off for new installs, kept on for
  players with saved data

- Release Review: the refresh gif leads the README; changelog drafted and approved as is

**Audit:** skipped at the author's call (reviewed and tested in game; all UAT passed).

**Known deferred items at close:** README wording proposals (17-HUMAN-UAT.md item 3) not applied,
the author's call; no new prints of the meter prompt or the activity menu.

---

## v0.2.1 Reset Details reminder, more region flags and spec points (Shipped: 2026-11-16)

**Delivered:** a damage meter reset prompt (Details! or the game's own meter) on joining a group
or entering an instance, region flags for every region from real flag art with a two-letter
fallback, and talent points per tree on friendly players' tooltips.

**Phases completed:** 4 phases (12-15), 7 plans
**Requirements:** 11/11 (MTR, REG, SPC, REL); MTR-02 adjusted (no prompt on a same-instance
run-back within 15 min, nor when Details! erases on its own)
**Git:** 59 commits on `milestone/v0.2.1-reset-details-reminder-more-region-flags-and-spec-points`
(from `topic/dev`), 2026-11-16; 26 shipped/source files changed (+1116 / −199, outside
`.planning/`); ~8.9k lines of Lua/XML shipped
**Tag:** `v0.2.1`

**Key accomplishments:**

- `MeterReset.lua`: a "[TGF] Reset …?" Yes / No prompt of our own (never a StaticPopup entry),
  Details! first, else the game's meter while it's on; two settings, `/tgf meter`; same-run,
  Details! auto-erase and 10 s merge rules; placed below game popups and the zone name text

- Region flags for US, AU, EU, CN, KR, TW from the author's flagpedia.net PNGs (converted by
  `png2tga.js`, no art generated; the script-drawn flags removed); groups like `EU` / `EU3` get the
  flag, any other shard text a two-letter tag, the full text in the tooltip

- Talent points per tree ("Talents 31/20/0") on friendly players' tooltips from the same guarded
  quiet inspect, read as Forever's talent frame does (`C_Traits` group currency `spent`), with
  its own setting; the inspect also stays away from Forever's Inspect Talents view

- Settings sections "Item level and talents" and "Damage meter" (ten options, all on by default)

**Audit:** [milestones/v0.2.1-MILESTONE-AUDIT.md](milestones/v0.2.1-MILESTONE-AUDIT.md), status
tech_debt (no blockers).

**Known deferred items at close:** README screenshots and wording kept from v0.2 (the author's
call); the audit's open items; v0.1 cleanup list, v0.2 audit tech debt, backlog 999.5.

---

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
