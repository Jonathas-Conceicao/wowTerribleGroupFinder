# TerribleGroupFinder — design notes (prototype, v0)

Started 2026-11-03. Blizzard source map: [FOREVER-GROUPFINDER.md](FOREVER-GROUPFINDER.md).
Conventions follow TerribleBuffTracker (`C:\Users\jonat\Repositories\TerribleBuffTracker`).

## Goal

A WoW Forever addon (prototype / proof of concept) that improves Forever's own group finder
in place, keeping its look and its model:

1. **Better listings**: a table of solo players and groups, sortable by role, level and gear
   score, in Forever's two sections.
2. **Quick contact**: one-click whispers from preset messages; Group Invite for solo players.
3. **Gear scores**: ours, cached between sessions, refreshed for the group on ready checks.

Not a goal for now: Retail support.

## Design (as of 2026-11-04)

- **In place.** In game the table replaces the result list and bottom buttons of
  `LFGBrowseFrame`; the parent widens to 620 while Browse shows. Forever's dropdowns,
  refresh and searching stay its own; its Listing and Who tabs are untouched. A fourth side
  tab (Messages) holds the whisper presets. For preview and development (or wherever the
  Blizzard finder is missing) a stand-in copy of LFGParentFrame's layout runs on sample data.
- **Forever's model.** Listings are solo players or groups; no applications. The list is your
  own listing, then collapsible dividers "Solo players" / "Groups" (groups first while solo,
  solo players first while leading); sorting applies within each section.
- **Never remove rows.** Hidden (X, until they make a new listing), delisted and, with Needs
  my role, no-slot-for-you listings are greyed and moved to the end of their section.
- **Columns.** Name, Lvl, Roles (T > H > D), GS (groups: best known), Activity, Listed.
  Layout guard: fixed columns from the left, Listed and the row buttons from the right,
  Activity flexible between; every cell width-bound.
- **Messages.** `invite` (to solo players) and `request` (to group leaders) presets with
  `{name} {activity} {role} {class} {level} {gs}`; Auto-send off by default (prefills the
  whisper box via `ChatFrameUtil.SendTellWithMessage`, Enter sends), on sends at once.
- **Gear score.** Ours: slot-weighted (GearScore's public slot weights), quality-scaled item
  level averaged over the gear slots. Cache `DB.gs` (name → gs, level, time; 60-day expiry);
  scores from an earlier session show in `W.GS_OUTDATED`. Ready check → inspect members
  without a fresh score (one at a time, 1.5 s apart, not in combat, not with InspectFrame
  open). Your own GS shows in the table's top band.
- **Friend marks.** `C_LFGList.GetSearchResultFriends` (Battle.net / character / guild, as
  the retail finder's tooltip) and `C_RecentAllies.IsRecentAllyByFullName`. Icons as chat
  marks whispers: recent allies `friendslist-recentallies-yellow`, Battle.net friends the
  person outline `Interface\ChatFrame\UI-ChatWhisperIcon` tinted in the `BN_WHISPER` colour. New player friendly and voice chat use the game's
  `newplayerchat-chaticon-newcomer` and `groupfinder-icon-voice` (retail finder's) icons.
- **Realms.** One mega-realm per ruleset; the finder lists only yours, so plain names work.

## To verify in game

- The in-place layout at 620 wide; Forever re-showing any part we hide.
- The Messages side tab sitting and switching cleanly next to Forever's three.
- `LFGBrowseFrame.searching` exists; listing comments (kstrings) display.
- Friend / recent-ally marks on real listings; `GetSearchResultFriends` return shape.
- Whisper prefill with Auto-send off.
- Ready-check inspects: range, timeouts; tune the GS quality factors against real gear.

## Ideas for later

- Share gear scores between TerribleGroupFinder users by addon whisper (listed players are
  rarely in inspect range): a versioned one-line message ≤ 255 bytes, a send queue within the
  addon message limits, drops for self / ignored / flooding / malformed senders, nothing during
  chat lockdown.
- CurseForge / Wago project IDs in the TOC and release workflow keys.

## Housekeeping

- TerribleBuffTracker's CLAUDE.md lists wow-ui-source as branch `live`; it's on `forever`
  now — don't change that repo.
