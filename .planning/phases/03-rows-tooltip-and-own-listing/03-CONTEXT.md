# Phase 3: Rows, Tooltip and Own Listing - Context

**Gathered:** 2026-11-11
**Status:** Ready for planning
**Mode:** `--auto` (author AFK; every gray area auto-resolved with the recommended option, see `03-DISCUSSION-LOG.md`)

<domain>
## Phase Boundary

Each Browse row and its tooltip read like Forever's own finder: solo players with the stock
micro role icons, the voice icon and wording as stock, your own listing marked "Your listing"
in green with the stock delist button (solo or leader only), a row tooltip in the stock order and
wording with playstyle, the comment in light grey and our extras after it, a tooltip that
refreshes while hovered, a small stock-style hide button with an icon, and Needs my role reading
the server's remaining-slot counts.

Requirements: UIP-07, UIP-08, UIP-09, UIP-13, UIP-14, UIP-15, UIP-16.
(REQUIREMENTS.md IDs; in `research/UI-PARITY.md` they are G17/G19, G22, G26, G20/G21, G23, G36, G37.)

Not in this phase: messages, key buttons, Auto-send / Auto-invite, the 1 s contact lock and the
Messages tab / panel (Phase 4); compact role counts for big groups (G18), the right-click menu
(G25), stock default order (G35), preview stock templates (G38) — all deferred.

</domain>

<decisions>
## Implementation Decisions

### Listing data (Listings.lua / Preview.lua) — feeds everything below
- **D-01:** `Listings.lua` keeps the raw `voiceMode` (`l.voiceMode`, nil/secret-guarded) next to
  the existing boolean `l.voice` (kept for the search box / old callers, true when the mode is not
  None). Also read `generalPlaystyle` (`l.playstyle`, the enum value, secret-guarded).
- **D-02:** `Listings.lua` reads `C_LFGList.GetSearchResultMemberCounts(id)` inside a `pcall`
  into `l.counts = { TANK, HEALER, DAMAGER }` and `l.remaining = { TANK, HEALER, DAMAGER }` from
  the `*_REMAINING` fields. Any secret or non-number field → that table is nil (fallback below).
  Note: `GetSearchResultMemberCounts` / `GetSearchResultEncounterInfo` are not in
  `Blizzard_APIDocumentationGenerated` (stock calls them anyway), so nil-check the function too.
- **D-03:** Bosses defeated: `C_LFGList.GetSearchResultEncounterInfo(id)` is read **on tooltip
  show only** (not per read), single-activity listings only, pcall + secret guard, as stock
  (`Browse.lua:814-834`).
- **D-04:** `Preview.lua` sample listings gain `voiceMode` (some Discord, some Legacy/None),
  `playstyle` (a few) and `remaining` on some groups (so both the server path and the
  composition fallback are exercised); the existing `voice = true` samples map to a voice mode.

### Role icons and voice (UIP-07)
- **D-05:** Solo players: `groupfinder-icon-role-micro-{tank,heal,dps}` (stock `SOLO_*`), in
  T > H > D order packed from the left of the Roles cell (stock `MapRoleStatesToRoleIcons`,
  `useSimple`). Size: the UI-SPEC sets it (stock is 23 px at row height 72; ours must fit the 40 px
  row and the 92 px Roles column). Groups keep the `-large-` icons (G18 deferred).
  Fallback where the micro atlas is missing: the current large icon / letter square.
- **D-06:** Group rows: open slots (empty role icons for size ≤ 5) come from `l.remaining`
  when present, else the existing `COMPOSITION` fallback.
- **D-07:** The row shows `UI-ChatIcon-Discord` (16 px) after the name **only** when
  `voiceMode == Enum.LFGEntryVoiceMode.Discord` (stock `Browse.lua:460-470`), desaturated on
  greyed rows. No icon for Legacy / Custom / None. Fallback where the atlas is missing: the
  existing `W.Icon("voice")` text tag. `W.Icon`'s generic `groupfinder-icon-voice` tag is no
  longer used on rows.
- **D-08:** Tooltip voice line in stock wording: `VOICE_CHAT_MODE_FORMAT` with the label for the
  listing's mode (`VOICE_CHAT_MODE_NONE/LEGACY/DISCORD/CUSTOM`, mapped like
  `Blizzard_LFGVanilla_VoiceChat.lua`). Shown whenever a label exists, as stock does; skipped when
  the globals / enum are missing (preview fallback: English "Voice chat: <mode>").

### Own listing row (UIP-08)
- **D-09:** The own row's Activity cell shows `LFG_SELF_LISTING` ("Your listing") in
  `LIGHTGREEN_FONT_COLOR` (stock `Browse.lua:405-475`); the " (you)" name suffix goes. Name,
  level and roles still show as on any row.
- **D-10:** The own row shows **no** Whisper and **no** hide button. Instead the stock delist
  button: our own Button inheriting `UIMenuButtonStretchTemplate` (no finder scripts — allowed by
  UI-PARITY D9), 24x22, anchored RIGHT -8, `groupfinder-icon-redx` icon at atlas size, centred,
  `UI-Common-MouseHilight` ADD highlight, tooltip `LFG_LIST_UNLIST`. Fallback where the template is
  missing: `W.Button` 24x22 with the redx atlas or "x" text.
- **D-11:** Shown only when you are solo or the group's leader (`CanUnlist`); hidden (not
  disabled) for other group members, as stock.
- **D-12:** Click: `PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)`, then — only if
  `C_LFGList.HasActiveEntryInfo()` — `C_LFGList.RemoveListing()` (unrestricted). It must NOT call
  `LFGBrowse_DoSearch`, `LFGListingFrame:RemoveListing` or `LFGParentFrameTab1_OnClick` (taint,
  UI-PARITY D9). Preview: clears `ns.state.myListing` and prints, as today.
- **D-13:** After a delist the own row disappears without a new search: in game the own row is only
  shown while `C_LFGList.HasActiveEntryInfo()` is true (the table already refreshes on
  `LFG_LIST_ACTIVE_ENTRY_UPDATE`). Preview: only while `ns.state.myListing` exists.
- **D-14:** The old "Unlist" text on the row's message button is removed (`Instance:Message`
  keeps only the whisper path; the unlist path moves to the delist button's handler).

### Row tooltip (UIP-09, UIP-13)
- **D-15:** Keep `GameTooltip` (the custom `LFGBrowseSearchEntryTooltip` frame copy stays
  deferred); anchor `ANCHOR_RIGHT` as today. Never call `LFGBrowseSearchEntryTooltip_UpdateAndShow`.
- **D-16:** Stock order and wording (`Browse.lua:578-875`):
  1. `LFG_LIST_ENTRY_DELISTED` in red (if delisted)
  2. new-player icon + `LFG_LIST_NEW_PLAYER_FRIENDLY_HEADER` in green (only if not delisted)
  3. leader line: leader icon (`groupfinder-icon-leader`, groups only), name in class colour
     (+ our friend marks), `LEVEL_ABBR .. " " .. level` in grey, then inline role atlases —
     solo: micro icons for every role they can play; group: the leader's assigned role (large)
  4. members (non-leaders), only when the listing has ≤ 10 members: class-coloured name,
     `LEVEL_ABBR` level grey, assigned role icon (large)
  5. the comment via `LFG_LIST_COMMENT_FORMAT`, in `LIGHTGRAY_FONT_COLOR`, wrapped
  6. member count: solo `LFG_LIST_TOOLTIP_MEMBERS_SIMPLE`; group `LFG_LIST_TOOLTIP_MEMBERS` with
     the server's `counts` (fallback: our counts from members)
  7. voice line (D-08)
  8. activities grouped by activity group (`C_LFGList.GetActivityGroupInfo`, groupless ones first
     on their own, each grouped one indented with `LFG_LIST_INDENT`), each in
     `BRIGHTBLUE_FONT_COLOR` when it is one of your active listing's activities, else
     `GRAY_FONT_COLOR`; a group name is bright blue if any of its activities matches. Fallback
     (no group info / preview): the flat list of activity names, same colours.
  9. bosses defeated (`LFG_LIST_BOSSES_DEFEATED` header, names in red) — single-activity only (D-03)
- **D-17:** Our extras after the stock content, separated by a blank line, in this order:
  playstyle (UIP-13: `GetGeneralPlaystyleString(l.playstyle)` in `GREEN_FONT_COLOR` as stock's
  row `PlaystyleLabel`, `Browse.xml:258-264`;
  fallback: the preview's playstyle text), solo spec / area (grey), "Friends in group:" block
  (`LFG_LIST_TOOLTIP_FRIENDS_IN_GROUP`), "Listed X ago" (grey), and the hidden note last. The
  title-line activity name and "Can play:" / "Looking for:" lines are dropped (stock covers them).
  No GS anywhere (`ns.GEAR_SCORE` off; keep GS lines behind the switch).
- **D-18:** Comment on the row (second line of the Activity cell) moves to
  `LIGHTGRAY_FONT_COLOR` (stock `GameFontNormalLeftLightGrey`); greyed rows still take the
  delisted grey.

### Tooltip refresh (UIP-16)
- **D-19:** After every `Refresh` (list re-filled), if `GameTooltip` is shown and owned by one of
  this table's rows: if that row frame is still under the mouse and holds a listing, re-run
  `ShowTooltip(row)` with the row's current listing (ScrollBox may have re-bound the frame to a
  different listing — the tooltip follows what's under the mouse, as stock `Browse.lua:497-503`);
  else hide it. Same in the `W.List` fallback.

### Hide button (UIP-14)
- **D-20:** The hide button becomes our own Button inheriting `UIMenuButtonStretchTemplate`,
  24x22 (stock row-button size), with a centred icon texture: `transmog-icon-hidden` (eye struck
  through) to hide, `socialqueuing-icon-eye` (open eye) to show again on a hidden row; not
  `groupfinder-icon-redx` (stock's "unlist"). Tooltip "Hide" / "Show" with the existing
  explanation lines. Fallback: the `W.Button` with "x" / "+" text where the template or atlas is
  missing. The icon choice is an in-game check (UI-PARITY Q10).
- **D-21:** The right-hand action area grows to fit the 24 px button (`ACTIONS_W` recomputed);
  header and rows still share `Layout`, so columns stay aligned. Activity absorbs the 4 px.
  Width stays 620 (Q1 remains an in-game check).

### Needs my role (UIP-15)
- **D-22:** `FitsMyRoles` for a **group** uses the server's `l.remaining` with `ns.MyRoles()`
  (stock `HasRemainingSlotsForLocalPlayerRole`, `Browse.lua:1332-1340`); when `l.remaining` is nil
  it falls back to today's `COMPOSITION` estimate. Solo listings (you lead) keep today's rule
  (your party's open slots vs their roles). The sort value for groups uses the same function, so
  sort and greying agree.
- **D-23:** Greyed / moved-to-end behaviour stays exactly as Phase 2 (never removed).

### Testing
- **D-24:** The fengari smoke harness gets stubs for `GetSearchResultMemberCounts`,
  `GetSearchResultEncounterInfo`, `GetActivityGroupInfo`, `GetGeneralPlaystyleString`,
  `Enum.LFGEntryVoiceMode`, `VOICE_CHAT_MODE_*`, `LFG_SELF_LISTING`, `LIGHTGREEN_FONT_COLOR`,
  `LIGHTGRAY_FONT_COLOR`, `UIMenuButtonStretchTemplate` known/unknown, `HasActiveEntryInfo`,
  `RemoveListing`, and `GameTooltip` line capture. Assertions: micro atlases on solo rows,
  Discord icon only for Discord, own row text + delist shown/hidden by leader state and no
  Whisper/hide on it, delist calls `RemoveListing` and not `LFGBrowse_DoSearch`, tooltip line
  order, comment colour, playstyle line, tooltip refresh after Refresh, hide button icon swap,
  Needs my role greying from `remaining`. All modes end with 0 failed.

### Claude's Discretion
- Exact micro icon size / spacing and the delist / hide icon sizes (UI-SPEC decides within the
  stock values above).
- Whether tooltip lines with inline atlases use `|A:...|a` markup or `CreateAtlasMarkup`.
- How `ShowTooltip` is split into stock / extras helpers.
- Whether the delist and hide buttons share one small-button builder in `UI/Widgets.lua`.
- Discuss step did not chain into plan-phase automatically: the orchestrating run executes
  ui-phase before plan-phase, as instructed.

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Project rules and research
- `CLAUDE.md` — Forever-only, in place, taint rules, preview stand-in, stylua, no sed on .md
- `.planning/research/UI-PARITY.md` — G17, G19, G20, G21, G22, G23, G26, G36, G37; D2 (row and tooltip), D9 (taint notes); open questions Q5, Q10
- `.planning/REQUIREMENTS.md` — UIP-07, -08, -09, -13, -14, -15, -16
- `.planning/phases/02-list-foundation/02-CONTEXT.md` — Phase 2 decisions (row frames, layout, greyed rows, selection, sounds)
- `.planning/phases/02-list-foundation/02-UI-SPEC.md` — Phase 2 UI conventions to reuse
- `.planning/phases/02-list-foundation/02-REVIEW.md` — IN-06 (Unlist → stock delist button)
- `.planning/STATE.md` — Phase 3 inputs under Blockers/Concerns

### Blizzard source (C:\Users\jonat\Repositories\wow-ui-source, branch forever, read-only)
- `Interface/AddOns/Blizzard_GroupFinder_VanillaStyle/Blizzard_LFGVanilla_Browse.lua` — constants and atlases :1-45; row fill :364-504 (Discord icon :460-470, playstyle :477); tooltip :578-875; delist mixin :1290-1302; remaining slots :1332-1340; `MapRoleStatesToRoleIcons` :1479-1499
- `Interface/AddOns/Blizzard_GroupFinder_VanillaStyle/Mainline/Blizzard_LFGVanilla_Browse.xml` — Solo role icons :20-49; DelistButton :114-135; row base template :139-209; tooltip frame :316-424
- `Interface/AddOns/Blizzard_GroupFinder_VanillaStyle/Blizzard_LFGVanilla_VoiceChat.lua` — voice mode labels
- `Interface/AddOns/Blizzard_SharedXML/Mainline/SharedUIPanelTemplates.xml:772` — `UIMenuButtonStretchTemplate`
- `Interface/AddOns/Blizzard_APIDocumentationGenerated/LFGListInfoDocumentation.lua` — `GetSearchResultMemberCounts`, `GetSearchResultEncounterInfo`, `GetActivityGroupInfo`, search result fields

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `UI/Table.lua` `ShowTooltip` (≈ line 306) — rewrite in stock order; `FriendsLine`, `W.Marks`, `W.Colored`, `W.Age` stay for the extras
- `UI/Table.lua` `SetRoles` (≈ 490) — solo branch switches to micro atlases; group branch reads `l.remaining`
- `UI/Table.lua` `BuildRow` / `FillRow` (≈ 551 / 739) — hide button, message button, own row art already built here
- `UI/Table.lua` `CanUnlist`, `Instance:Message` (≈ 445-474) — the unlist path moves to the delist button
- `UI/Table.lua` `FitsMyRoles` / `Fill` / `COMPOSITION` (≈ 100-167) — server-count path in front of the estimate
- `UI/Widgets.lua` `W.RoleIcon` (≈ 342), `W.Icon` / `ICONS` (≈ 106), `W.Button`, `W.Tooltip`, `W.Atlas`, `W.HasAtlas`, `W.SetColor`, `W.PlayCheckbox`
- `UI/Table.lua` `TemplateKnown(name)` — `C_XMLUtil.GetTemplateInfo` probe for inheriting `UIMenuButtonStretchTemplate`

### Established Patterns
- Every Blizzard template / atlas is probed and has a fallback so the preview renders anywhere
- Secret values (`issecretvalue`) skip a listing or a field; API reads in `pcall`
- Greyed rows: `W.DELISTED` text, desaturated icons, role icons alpha 0.5
- Frames are reused by the ScrollBox: every `FillRow` sets every visible state (show/hide, text, colour)

### Integration Points
- `UI/InPlace.lua` refreshes on `LFG_LIST_SEARCH_RESULT_UPDATED` / `LFG_LIST_ACTIVE_ENTRY_UPDATE` (ReadSoon) — tooltip refresh hooks into `Instance:Refresh`
- `Listings.lua` `Read` — new fields (voiceMode, playstyle, counts, remaining)
- `Preview.lua` sample listings — same shape
- Phase 4 will add the contact lock on `row.message` and the bottom Send Message; keep `row.message` a plain whisper button

</code_context>

<specifics>
## Specific Ideas

- "Your listing" text and the delist button are exactly stock (string, colour, size, icon, tooltip, sound)
- The hide button must not use the red X (that means "unlist" in stock)
- Our tooltip extras always come after stock's content

</specifics>

<deferred>
## Deferred Ideas

- Custom tooltip frame copied from `LFGBrowseSearchEntryTooltip` (G26 L-size option)
- Compact role-count display for groups above 5 players (G18)
- Right-click menu without Report (G25)
- Hardcoded English labels (column headers, status, hide tooltips) → future localization item (Phase 2 UI review)
- Activity width at 620 vs 580 → in-game check Q1

</deferred>

---

*Phase: 03-rows-tooltip-and-own-listing*
*Context gathered: 2026-11-11*
