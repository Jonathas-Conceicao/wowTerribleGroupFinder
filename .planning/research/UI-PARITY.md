# UI parity review: our in-place finder vs Forever's stock finder

**Researched:** 2026-11-11 (milestone v0.1 Initial Release)
**Blizzard source:** `C:\Users\jonat\Repositories\wow-ui-source`, branch `forever` (read-only). Paths below
are relative to `Interface/AddOns/`. `VS/` = `Blizzard_GroupFinder_VanillaStyle/`, `SX/` = `Blizzard_SharedXML/`.
**Our code:** `C:\Users\jonat\Repositories\TerribleGroupFinder` at `e65a5f6`.
**Confidence:** HIGH for everything read from source (file:line cited). MEDIUM/LOW where an atlas's look or
size in the live client matters; those are listed under "Open questions for in-game check".

---

## Summary

The prototype already uses Forever's general look (finder atlases, `UIPanelButtonTemplate`, the bottom
buttons in the stock spots, the stock side-tab template). Up close it differs in about 30 ways. Most are
small, and a few are real bugs.

**Real bugs found while reviewing (must fix):**
1. **The Messages side tab starts out drawn as selected.** `LargeSideTabButtonTemplate`'s `SelectedTexture`
   is not hidden by default (`SX/Mainline/SharedUIPanelTemplates.xml:1036-1040`). Blizzard's three tabs are
   unchecked through `UpdateTabs()`, but we never call `SetChecked(false)` on ours (`UI/InPlace.lua:137-155`).
2. **The Messages tab icon is smaller than its neighbours.** Forever's tabs set `fillToInterior=true`
   (`VS/Mainline/Blizzard_LFGVanilla_ParentFrame.xml:21-24`), so each `SetChecked` resizes their icons to
   50x50 (`SX/Mainline/SharedUIPanelTemplates.lua:380-397`). Ours stays at 30x30 (`UI/InPlace.lua:139-143`).
3. **The tab check marks get out of sync.** On `LFG_LIST_ACTIVE_ENTRY_UPDATE`, `LFGParentFrame:UpdateTabs()`
   re-checks the tab for `selectedTab` (`VS/Blizzard_LFGVanilla_ParentFrame.lua:56-67`). If Messages is
   open at that moment, two tabs show as checked.
4. **Selection goes stale.** `ns.Listings.Read()` builds new tables on every read (`Listings.lua:120`,
   `:162-185`), but the selection is kept by table reference (`UI/Table.lua:548`, `:632`, `:699-704`). The
   yellow highlight disappears while Send Message / Group Invite stay enabled for the old listing, which
   may be delisted by then. Stock clears the selection on every result update
   (`VS/Blizzard_LFGVanilla_Browse.lua:185`) and on delist (`:287-295`).
5. **Our band crosses Forever's scroll line.** `LFGBrowseFrame.BarTop` sits 20 px below the top of the
   list area (`VS/Mainline/Blizzard_LFGVanilla_Browse.xml:445-450`). Our band covers 4 to 28 px below
   that top (`UI/Table.lua:718-721`), so the line probably shows through behind the checkbox and the
   search box. Needs an in-game check.
6. **Section headers use the row hover look** (the known bug). Stock has its own header template,
   `LFGBrowseSearchEntryGroupingTemplate` (`VS/Mainline/Blizzard_LFGVanilla_Browse.xml:277-315`): a
   `common-button-list-collapseExpand` background, the same atlas again as an ADD highlight, and
   `common-button-list-plus/minus` icons. It has no scripts, so our own frames can inherit it without taint.
7. **Double-click whispers** (`UI/Table.lua:551-555`). Stock has no double-click. Once Auto-send and
   Auto-invite exist, a double-click sends without the player meaning to, which is the exact case the
   anti-spam lock is meant to stop.

**Biggest look gaps (should match):**
- Scrolling: stock uses `WowScrollBoxList` + `MinimalScrollBar` with the bar hidden when not needed. Ours
  is a pooled list scrolled by row, with a 4 px gold bar you can't drag.
- Rows: stock rows are separate buttons with `common-button-list-mid2` backgrounds plus `-hover` and
  `-selected` ADD overlays. Ours are flat rows with a scroll line under each one.
- Our list sits in a second inset with a hand-made brown 1 px border, inside Forever's own
  `common-insideframe`.
- Text colours: stock colours activities grey, bright blue when they match your listing, and light green
  for "Your listing". Ours is always gold.
- Roles: solo players use the *micro* role atlases in stock. Large groups use a role-count display.
- Searching / no results: stock shows `LoadingSpinnerTemplate` with "Searching" and
  `LFG_LIST_NO_RESULTS_FOUND` / `LFG_LIST_SEARCH_FAILED`. Ours shows one centred grey line.
- Row tooltip: the content order differs from stock.

**Fine as it is:** class colours (`RAID_CLASS_COLORS`), bottom button sizes and anchors (111x28 at 21,16 and
109x28 at -21,16, same as `VS/Mainline/Blizzard_LFGVanilla_Browse.xml:601-618`), where the side tab sits
(TOPLEFT of the tab above, BOTTOMLEFT, y -2, same as `ParentFrame.xml:109,119`), the panel title
`LFG_TITLE`, ESC (still Blizzard's through `UIPanelWindows`), and the tab click sound (comes with the template).

**Freed space when GS is switched off:** the GS column (44 px plus a 6 px gap, `UI/Table.lua:49`) and the
"Your GS" band text (`UI/Table.lua:744-753`). Give the column's space to **Roles** (76 -> ~92 px, so the
compact role-count display fits) and **Activity**. With the band gone, the strip above `BarTop` can hold
the column headers (see D1).

---

## Gap table

Pri: **M** = must for v0.1 parity, **N** = nice to have, **L** = later. Effort: S < 1 h, M = a few hours,
L = a day or more.

| # | Area | Stock (file:line) | Ours (file:line) | Change | Eff | Pri |
|---|------|-------------------|------------------|--------|-----|-----|
| G1 | Side tab selected at start | `SelectedTexture` shown by default `SX/Mainline/SharedUIPanelTemplates.xml:1036`; tabs unchecked via `UpdateTabs` `VS/Blizzard_LFGVanilla_ParentFrame.lua:62-71` | never unchecked `UI/InPlace.lua:137-155` | `messagesTab:SetChecked(false)` right after creating it | S | M |
| G2 | Side tab icon size | `fillToInterior=true` `VS/Mainline/..._ParentFrame.xml:21-24`; `UpdateIconInterior` 50x50 `SX/Mainline/SharedUIPanelTemplates.lua:386-392` | 30x30, no fillToInterior `UI/InPlace.lua:139-143` | `messagesTab:SetFillToInterior(true)` (or set `fillToInterior=true` before the first `SetChecked`); keep the 30x30 + texcoord from `ParentFrame.lua:96-98` for the first frame | S | M |
| G3 | Tab check after entry update | `UpdateTabs` re-checks `selectedTab` `VS/Blizzard_LFGVanilla_ParentFrame.lua:56-67` | not handled `UI/InPlace.lua:89-114` | `hooksecurefunc(LFGParentFrame, "UpdateTabs", fn)`: if Messages is shown, `SetChecked(false)` the three tabs | S | M |
| G4 | Side tab tooltip | `tooltipText` only, `ANCHOR_RIGHT -4,-4` `SX/Mainline/SharedUIPanelTemplates.lua:404-419` | `tooltipText` plus a hooked title+body tooltip that replaces it `UI/InPlace.lua:144,155` | Drop `W.Tooltip` on the tab; `tooltipText = "Messages"` only, like `LFG_LIST_TAB_*` | S | M |
| G5 | Section header look/hover | `LFGBrowseSearchEntryGroupingTemplate` 36 tall; BG `common-button-list-collapseExpand` at (3,-8)/(-3,0); label `GameFontNormal` at LEFT 12,-4; `common-button-list-plus`/`-minus` at RIGHT -12,-5; HIGHLIGHT = same atlas, ADD, (3,-7)/(-3,-1) `VS/Mainline/Blizzard_LFGVanilla_Browse.xml:277-315` | header reuses row frame; row highlight `groupfinder-highlightbar-blue` over the whole row `UI/Table.lua:472,483-494,564-578`; "+"/"-" as text | Header gets its own frame. In game inherit `LFGBrowseSearchEntryGroupingTemplate` (no scripts, safe to inherit); in preview, copy it in Lua. Toggle `ExpandIcon`/`CollapseIcon` as `Browse.lua:84-93` does | M | M |
| G6 | Selection model | Click toggles select (Deselectable); delisted and own rows can't be selected; selection cleared on new results; `CHECKBOX_ON` sound `VS/Blizzard_LFGVanilla_Browse.lua:117-126,185,287-295,521-532` | Select by table reference, can't deselect, any row selectable, no sound `UI/Table.lua:543-550` | Store `selectedID` (resultID); clear it on `LFG_LIST_SEARCH_RESULTS_RECEIVED`/search start; drop it when that ID is delisted or gone; click on the selected row deselects; ignore delisted/own rows; `PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)` | S | M |
| G7 | Double-click | none | double-click whispers `UI/Table.lua:551-555` | Remove it | S | M |
| G8 | Bottom buttons enable | Send Message: any selection; Invite: solo, and you can invite `VS/Blizzard_LFGVanilla_Browse.lua:307-318,1462-1478` | same idea, but Send stays enabled for a delisted selection `UI/Table.lua:703` | Follows from G6 (delisted rows can't be selected) | S | M |
| G9 | Band vs BarTop | `BarTop` at BackgroundArt top -20 `Browse.xml:445-450`; list starts below it (ScrollBox top -112 from the frame, `:561-571` + `Browse.lua:107-115`) | band from -4 to -28 below the art top, crossing the line `UI/Table.lua:718-721` | Move the controls (D1): search box into the stone header band, Needs my role into the bottom bar; put column headers in the 20 px strip above `BarTop` | M | M |
| G10 | Second inset + custom border | Forever's `Inset` already draws `groupfinder-background` + `common-insideframe` `Browse.xml:466-489` | `W.Inset` draws another background plus brown 1 px lines `UI/Table.lua:756-761`, `UI/Widgets.lua:185-210` | `back` keeps `EnableMouse(true)` to block clicks but draws no textures | S | M |
| G11 | Scrolling | `WowScrollBoxList` + `MinimalScrollBar`; bar hidden when not needed (`AddManagedScrollBarVisibilityBehavior`); `RetainScrollPosition` `Browse.lua:71-115,227` | row-step pooled list, 4 px gold thumb, no drag `UI/Widgets.lua:445-515` | Switch to our own `WowScrollBoxList` + `MinimalScrollBar` with `CreateScrollBoxListLinearView` and a flat `CreateDataProvider` (headers are list items), or a TreeListView; keep `W.List` only as the fallback where the templates are missing | L | M |
| G12 | Row background/hover/selected | Section rows `LFGBrowseNestedSearchEntryTemplate`: BG `common-button-list-mid2` (3,-2)/(-3,0); hover `common-button-list-mid2-hover` ADD (3,-3)/(-3,-1); selected `common-button-list-mid2-selected` ADD OVERLAY `Browse.xml:240-275`. Own listing `LFGBrowseSearchEntryTemplate`: `groupfinder-highlightbar` BG, `-yellow` selected (ADD, OVERLAY), `-blue` hover `:211-238` | `-blue` HIGHLIGHT, `-yellow` in BACKGROUND (not ADD), scroll line under each row `UI/Table.lua:472-480`, `UI/Widgets.lua:529-536` | Section rows: mid2 / mid2-hover / mid2-selected with stock insets and blend modes. Own listing: the highlightbar trio. Drop the per-row line (stock rows are split by their background insets) | M | M |
| G13 | Row height | nested 72, own 52, header 36 `Browse.xml:140,241,278` | 32 for everything `UI/Table.lua:25` | Keep a table density: **40** for rows (two text lines at stock fonts), 36 for headers. A variable extent comes for free with ScrollBox (`SetElementExtentCalculator`) | S | M |
| G14 | Name font/colour | `GameFontNormalLarge`, class colour; delisted 0.3 grey `Browse.lua:6,440-458`, `Browse.xml:155` | `GameFontNormal` 12 `UI/Table.lua:506` | Keep `GameFontNormal` (table density), class colour; delisted/demoted text in `{0.3,0.3,0.3}` instead of alpha 0.4 (`UI/Table.lua:637-640`); `SetDesaturated(true)` on class/role/flag icons like stock | S | M |
| G15 | Activity text colour | Grey `GRAY_FONT_COLOR`; `BRIGHTBLUE_FONT_COLOR` when it matches your listing's activities; `LIGHTGREEN_FONT_COLOR` + `LFG_SELF_LISTING` for your own; "N activities" `LFGBROWSE_ACTIVITY_COUNT` / `LFGBROWSE_ACTIVITY_MATCHING_COUNT`; also greyed when it doesn't match the activity filter `Browse.lua:7-9,405-475` | always gold `\|cffffd100`, "+N" suffix `UI/Table.lua:231-238,619` | Use the stock colours and strings. Keep "+N" or use the stock count string (pick one; stock's is localized) | S | M |
| G16 | Level text | `LEVEL_ABBR .. " " .. level`, `GameFontDisableLeft`, grey `Browse.lua:382,444` | `GameFontHighlight` white `UI/Table.lua:512` | It's a column, so the number alone is fine; use `GameFontDisable` (grey) like stock | S | N |
| G17 | Solo role icons | `groupfinder-icon-role-micro-{tank,heal,dps}` (`SOLO_*`), 23 px `Browse.lua:17-20,1479-1499`, `Browse.xml:29-46` | `-large-` 14 px `UI/Widgets.lua:331`, `UI/Table.lua:409-424` | Solo players: micro atlases; groups: large | S | M |
| G18 | Group roles, big groups | `RoleCountLargeNoScriptsTemplate` (icons alpha 0.70, `GameFontHighlightLarge` counts) for RoleCount; `RoleEnumerate` icons 27 px; `PlayerCount` waitdot `Browse.lua:899-1003`, `Blizzard_UIPanelTemplates/Camelot/UIPanelTemplatesOverrides.xml:4-40` | text "n/size T1 H2 D3" `UI/Table.lua:443-449` | Compact copy of RoleCount: three large role icons (14 px, alpha 0.7) each followed by a `GameFontHighlightSmall` count, in the widened Roles column. The stock template itself is 160 px wide, too wide | M | N |
| G19 | Discord / voice icon | `UI-ChatIcon-Discord` 16 px, only for `voiceMode == Discord`; tooltip `VOICE_CHAT_MODE_FORMAT` + `VOICE_CHAT_MODE_*` `Browse.xml:162-167`, `Browse.lua:460-470,701-709`, `VS/Blizzard_LFGVanilla_VoiceChat.lua:3-8` | `groupfinder-icon-voice` for any mode `UI/Widgets.lua:98`, `Listings.lua:156` | Keep `voiceMode`; show the Discord icon for Discord; tooltip line in stock wording | S | M |
| G20 | Playstyle | Nested rows show `GetGeneralPlaystyleString(generalPlaystyle)` in green `Browse.xml:258-264`, `Browse.lua:477-479` | not read or shown | Read `generalPlaystyle`; show it in the tooltip (and optionally as green text after the activity) | S | N |
| G21 | Comment | Comment display type -> right-side text `LIGHTGRAY_FONT_COLOR` (`GameFontNormalLeftLightGrey`); tooltip `LFG_LIST_COMMENT_FORMAT` `Browse.lua:921-928,684-692` | always under the activity in `GameFontDisableSmall` `UI/Table.lua:527-529,620` | Keep it on the second line (useful), coloured `LIGHTGRAY_FONT_COLOR`; tooltip uses `LFG_LIST_COMMENT_FORMAT` | S | N |
| G22 | Own listing row | Activity `LFG_SELF_LISTING` light green; delist = `UIMenuButtonStretchTemplate` 24x22 + `groupfinder-icon-redx`, tooltip `LFG_LIST_UNLIST`, only if not grouped or leader; own row not selectable `Browse.xml:114-135`, `Browse.lua:916-918,1295-1302` | "Unlist" panel button for any member, "(you)" suffix `UI/Table.lua:609,635` | Copy the delist button exactly; hide it for non-leaders. Our click may call `C_LFGList.RemoveListing()` (unrestricted, `VS/Blizzard_LFGVanilla_Listing.lua:330-333`) but must **not** call `LFGBrowse_DoSearch`/`LFGParentFrameTab1_OnClick` (G-taint) | S | M |
| G23 | Hide button (X) look | stock row buttons: `UIMenuButtonStretchTemplate` + icon (delist), Who list: `common-button-tertiary-square-*` 36 px + icon `VS/Mainline/WhoList.xml:56-79` | `UIPanelButtonTemplate` 20x20 with "x"/"+" text `UI/Table.lua:533-536` | `UIMenuButtonStretchTemplate` 24x22 with an icon (not `groupfinder-icon-redx`, which means "unlist" in stock); icon to be chosen in game | S | N |
| G24 | Whisper button | no per-row button in stock | `UIPanelButtonTemplate` "Whisper" 66x20 `UI/Table.lua:537-540` | Keep (our core feature); 22 tall to match stock small buttons. Pressed lock: `SetButtonState("PUSHED", true)` for the 1 s, then `SetButtonState("NORMAL")` | S | M |
| G25 | Right-click menu | `MenuUtil.CreateContextMenu`: title leader name, Send Message, Group Invite, Report Group, Report Advertisement `Browse.lua:1008-1040` | none | Our own context menu on our rows: title, Send Message (preset), Group Invite (solo), Hide/Show. Leave out Report for v0.1 (see taint note) | S | N |
| G26 | Row tooltip | Custom `LFGBrowseSearchEntryTooltip` (TooltipBackdrop, min width 200) at row TOPRIGHT +8,+38; order: Delisted (red) / New player friendly (green + icon) / leader (leader icon if group, class colour name, "Lvl N" small grey, roles: micro if solo, assigned if group) / members ≤10 / comment / member count (`LFG_LIST_TOOLTIP_MEMBERS[_SIMPLE]`) / voice / activities by group (`LFG_LIST_INDENT`, grey or bright blue) / bosses defeated (`LFG_LIST_BOSSES_DEFEATED`, red, single activity only) `Browse.xml:316-424`, `Browse.lua:578-875` | GameTooltip, activity title first in gold, GS, "Can play:", "Looking for:", "Listed X ago" `UI/Table.lua:275-360` | Keep GameTooltip; switch to the stock order, strings and colours; inline role atlases; our extras (spec/area, friends in group, listed age, hidden note) go after stock's content. Copying the custom frame = L | M | M |
| G27 | Searching state | List cleared, `LoadingSpinnerTemplate` centred on BackgroundArt + `SEARCHING` `GameFontNormalLarge` above it `Browse.xml:579-592`, `Browse.lua:184-191` | old rows stay; text only when empty `UI/Table.lua:693-695` | Our own `LoadingSpinnerTemplate` + label at the same anchors; hide rows while `LFGBrowseFrame.searching` | S | M |
| G28 | No results / failed | `NoResultsFound` `GameFontDisable` 240 wide at BackgroundArt TOP -40; `LFG_LIST_NO_RESULTS_FOUND` or `LFG_LIST_SEARCH_FAILED` `Browse.xml:457-462`, `Browse.lua:193-195` | centred "Nothing listed here..." `UI/Table.lua:694`, `UI/Widgets.lua:457-458` | Same font/anchor/strings; read `LFGBrowseFrame.searchFailed` (read-only). Our own text only for "filtered out by your search box" | S | M |
| G29 | Column headers | stock has none; Blizzard's sortable headers: `ColumnDisplayButtonShortTemplate` (19 px, `WhoFrame-ColumnTabs`, `GameFontHighlightSmall`) `SX/Mainline/SharedUIPanelTemplates.xml:1180-1219`; sort arrow `auctionhouse-ui-sortarrow` flipped by texcoord `Blizzard_ProfessionsTemplates/Blizzard_ProfessionsTemplates.xml:265-279`, `.lua:213-225` | flat buttons, white 8% hover, "^"/"v" text `UI/Table.lua:763-806` | `ColumnDisplayButtonShortTemplate` per column + `auctionhouse-ui-sortarrow` (asc texcoord 0,1,1,0; desc 0,1,0,1), in the strip above `BarTop` | M | M |
| G30 | Checkbox | `UICheckButtonTemplate` 26x26 with its own `.Text` (`GameFontNormalSmall`, gold) `VS/Mainline/Blizzard_LFGVanilla_Listing.xml:564-585`, `SX/Shared/Button/CheckButtonTemplates.xml:50-61`; click sounds CHECKBOX_ON/OFF `VS/Blizzard_LFGVanilla_Listing.lua:648-654` | 24x24, template text blanked, own white `GameFontHighlightSmall` label, no sound `UI/Widgets.lua:266-285` | Use the template's `.Text`, 26x26, play ON/OFF sounds. Disabled: `Disable()` + label `GameFontDisableSmall` (the template has no disabled-unchecked art) | S | M |
| G31 | Preset text boxes | multi-line comment: `UIPanelInputScrollFrameTemplate` 394x47, instructions, `maxLetters` 255 `VS/Mainline/Blizzard_LFGVanilla_Listing.xml:602-633`; non-secure twin `InputScrollFrameTemplate` `SX/Shared/InputBox/InputBoxTemplates.xml:72-176` | single-line `InputBoxTemplate` 400 wide (≈60 chars visible of 255) `Messages.lua:146-149` | `InputScrollFrameTemplate`, ~2-3 lines tall, char count shown. Set the size first, then `EditBox:SetWidth(w-18)`, `SetMaxLetters(255)`, instructions (OnLoad ran at size 0). Enter = `ClearFocus` (no newlines; strip `\n` on paste) | M | M |
| G32 | Key-insert buttons | stock small buttons: `UIPanelButtonTemplate` 22 tall (`GameFontNormal`) e.g. RolePoll 120x22 `Listing.xml:413-414`; `UIPanelDynamicResizeButtonTemplate` fits text `SX/Shared/Button/UIPanelButtonTemplates.xml:12-22` | — (new) | One row of `UIPanelButtonTemplate` buttons, height 22, width = text width + 24, label `GameFontNormalSmall`; tooltip = what the key inserts | S | M |
| G33 | Messages panel frame | Who/Browse layout: stone header `groupfinder-Stat-StoneBG` (2,-21) to art top -7; art `groupfinder-background` (4,-80)/(-4,3); border `common-insideframe` (3,-78)/(-4,3); `groupfinder-ScrollLine` at art top -20 and bottom +42 `VS/Mainline/WhoList.xml:102-137` | `groupfinder-background` over the whole panel, no stone band, no inside frame `UI/InPlace.lua:124-132`; preview `UI/MainFrame.lua:319-327` | Rebuild with the Who list layers; intro text in the stone band (like Listing's role band); presets inside the inset | S | M |
| G34 | Sounds | row click / refresh / delist CHECKBOX_ON `Browse.lua:526,1296`, `Browse.xml:555`; tab IG_CHARACTER_INFO_TAB (template) `SX/Mainline/SharedUIPanelTemplates.lua:361-366`; checkbox ON/OFF | none on rows, checks, hide | Add: row select, hide/show, header? (stock header: none, `Browse.lua:84-93`), checks ON/OFF | S | M |
| G35 | Default order | `LFGBrowseUtil_SortSearchResults`: own first; matches your listing first; solo/group order; solo by role (adjusted for your party in dungeons); groups by slot for your role, size, tank/heal need; **older first**; then ID `Browse.lua:1342-1460` | default sort "role"; ties newest first `UI/Table.lua:61-64,225-228` | No column selected = stock order (call `LFGBrowseUtil_SortSearchResults` on *our own* ID array, or copy it); clicking a header switches to that column, clicking again flips it, a third click goes back to stock order. Ties: older first, as stock | M | N |
| G36 | Open slots | `*_REMAINING` from `GetSearchResultMemberCounts` `Browse.lua:1332-1340` | hard-coded `COMPOSITION` `UI/Table.lua:35-42,74-86` | Read the server's remaining counts where available (also fixes Needs my role) | S | N |
| G37 | Hovered row updates | updated row re-runs its OnEnter if hovered `Browse.lua:497-503` | tooltip goes stale until the mouse moves | after `Refresh`, re-show the tooltip of the hovered row | S | N |
| G38 | Preview stand-in | tabs `LargeSideTabButtonTemplate` at TOPRIGHT y -60, -2 gap; dropdowns 118 / 167 `WowStyle1DropdownTemplate`; refresh 32x32 `UI-SquareButton-*` `ParentFrame.xml:94-121`, `Browse.lua:1048,1114`, `Browse.xml:523-559` | spellbook-tab art at -48, 12 gap, 40 px; custom dropdowns 140/180; refresh 26x22 panel button `UI/MainFrame.lua:16,98-116,244-297` | Use the same templates where they exist (preview runs on the modern client too) | M | N |

---

## Details per dimension

### D1. Frame geometry, layout, fonts, colours

**Stock Browse geometry** (`VS/Mainline/Blizzard_LFGVanilla_Browse.xml`):
- `LFGParentFrame` 458x535 (`..._ParentFrame.xml:31`). `LFGBrowseFrame` = `PortraitFrameTemplateNoCloseButton`, set to all points (`:426`).
- Stone header `Bg` from (2,-21) down to 7 px below the art top (`:437-442`). Category dropdown at (70,-43), 118 wide
  (`:490-497`, `Browse.lua:1048`). Activity dropdown 15 px to its right, 167 wide (`:498-503`, `Browse.lua:1114`). Refresh
  32x32 9 px right of that (`:523-526`). Options gear at TOPRIGHT (-12,-32) (`:593-596`).
- List area `BackgroundArt` (4,-80)/(-4,3) (`:429-434`); `Inset` with `groupfinder-background` + `common-insideframe`
  (`:466-489`). `BarTop` line 20 px below the art top (`:445-450`); `BarMiddle` line 61 px above the frame bottom
  (`:451-456`), right above the bottom buttons.
- ScrollBox after `AddManagedScrollBarVisibilityBehavior`: TOPLEFT (7,-112), BOTTOMRIGHT (-22,40) with the bar or
  (-6,40) without (`:561-566`, `Browse.lua:107-115`). MinimalScrollBar 2 px right of the box (`:573-578`).

**Ours:** widened to 620 while Browse shows (`UI/InPlace.lua:25,173-182`). Our `back` ends 58 px above the art
bottom = 61 px above the frame bottom, right on `BarMiddle` (good, `UI/Table.lua:758`). Bottom buttons are in the stock spots.

**Width.** At 458 the stock list is about 429 px wide. A table with Name/Lvl/Roles plus Listed plus row buttons
needs about 390 px before Activity gets anything, so widening is needed. With GS gone, 620 gives Activity about
175 px. **Keep 620** (taint-safe: we only resize the parent, which CLAUDE.md allows) and give the GS space to
Roles (~92) and Activity. Narrowing to ~580 would also work; check in game (Q1).

**Recommended vertical layout (fixes G9):**
- Stone band (y -21..-73): Blizzard's dropdowns, refresh and options gear stay. **Our search box** (`SearchBoxTemplate`,
  like the Who tab's at (56,-40) `VS/Mainline/WhoList.xml:141-148`) goes right of the refresh button, about 150 px,
  ending before the options gear (at 620 wide that is about x 420..575). Check the fit in game (Q2).
- Strip from the art top to `BarTop` (-80..-100, 20 px): **column headers** (`ColumnDisplayButtonShortTemplate`,
  19 px), so they sit where the stock window has empty space.
- List from just below `BarTop` to `BarMiddle`.
- Bottom bar, between Send Message (ends x 132) and Group Invite (starts x 490): **Needs my role** checkbox
  plus the "N solo players, M groups" status. The Who tab puts its totals in the same place
  (`WhoList.xml:92-100`, `UserScaledFontGameNormalSmall`, BOTTOM 0,14); ours is at `UI/Table.lua:825-826`.
- Other option for Needs my role: a `WowStyle1FilterDropdownTemplate` "Filter" next to the search box, as the
  Who tab does (`WhoList.xml:184-188`). That needs about 90 px more in the stone band. The bottom bar is simpler.

**Fonts and colours** (stock -> recommendation):

| Element | Stock | Recommend |
|---|---|---|
| Leader name | `GameFontNormalLarge`, `RAID_CLASS_COLORS` (`Browse.xml:155`, `Browse.lua:440-458`) | `GameFontNormal` + class colour (table density) |
| Level | `GameFontDisableLeft`, `GRAY_FONT_COLOR` (`Browse.xml:168`, `Browse.lua:444`) | `GameFontDisable` |
| Activity | `GameFontDisableLeft` + grey / `BRIGHTBLUE` match / `LIGHTGREEN` self (`Browse.lua:7-9,445-475`) | `GameFontHighlightSmall` font, stock colours |
| Playstyle | `GameFontDisableLeft`, `GREEN_FONT_COLOR` (`Browse.xml:258-264`) | tooltip (+ optional inline) |
| Comment | `GameFontNormalLeftLightGrey`, `LIGHTGRAY_FONT_COLOR` (`Browse.xml:11`, `Browse.lua:926`) | small, `LIGHTGRAY_FONT_COLOR` |
| Delisted / greyed | `{0.3,0.3,0.3}` text, desaturated icons, role icons alpha 0.5 (`Browse.lua:6,931-1003`) | same, in place of cell alpha 0.4 (`UI/Table.lua:637-640`) |
| Section header | `GameFontNormal` (gold) (`Browse.xml:289`) | same; our count in `GRAY_FONT_COLOR` is fine |
| Column headers | (none) `ColumnDisplayButtonShortTemplate` uses `GameFontHighlightSmall` | that template |

Our own sort/greying rule (hidden / no slot for you, moved to the end) uses the same grey as stock's delisted
rows, which fits the CLAUDE.md "greyed" rule.

### D2. Stock result row and tooltip

**Row** (`LFGBrowseSearchEntryBaseTemplate`, `Browse.xml:139-209`; filled by `Browse.lua:364-504`):
- Solo: class icon (`groupfinder-icon-class-*`, 24 px), "Lvl N", name, new-player icon, activity, and on the right
  "Roles:" plus micro role icons (`DataDisplay.Solo`, `Browse.xml:20-49`).
- Group: leader-crown icon (`groupfinder-icon-leader`), leader name, Discord icon, new-player icon, activity,
  and on the right a display chosen by `displayType` priority Comment > RoleCount > PlayerCount > RoleEnumerate >
  ClassEnumerate > HideAll (`Browse.lua:32-39,880-919,1517-1538`).
- Section rows add a third line, playstyle (`Browse.xml:258-264`).
- No age shown on the row, and no row buttons except delist on your own listing.

**Ours** (`UI/Table.lua:580-641`): class icon (also on groups; stock shows the leader crown there), name +
friend marks + tags, sub-line spec/class or "n/size members", Lvl, Roles, GS, activity + comment, Listed, Whisper, X.
Recommendation: show `groupfinder-icon-leader` instead of the class icon on group rows, so a group can be
told from a solo player at a glance like in stock. Other changes are in G14-G22.

**Tooltip:** see G26. Strings to reuse: `LFG_LIST_ENTRY_DELISTED`, `LFG_LIST_NEW_PLAYER_FRIENDLY_HEADER`,
`LEVEL_ABBR`, `LFG_LIST_COMMENT_FORMAT`, `LFG_LIST_TOOLTIP_MEMBERS`, `LFG_LIST_TOOLTIP_MEMBERS_SIMPLE`,
`VOICE_CHAT_MODE_FORMAT`, `VOICE_CHAT_MODE_*`, `LFG_LIST_INDENT`, `LFG_LIST_BOSSES_DEFEATED`, `LFG_TOOLTIP_ROLES`.
Group activities by `GetActivityGroupInfo` as `Browse.lua:711-807` does. Bosses defeated come from
`C_LFGList.GetSearchResultEncounterInfo` (single-activity listings only, `:814-834`), which we don't read yet.
Stock places its tooltip at the row's TOPRIGHT +8,+38 (`Browse.lua:536`), so it opens to the right of the
window. Our `ANCHOR_RIGHT` on a full-width row does nearly the same.

### D3. Selection model

Stock is "select a row, then use the bottom buttons" (`Browse.lua:117-126,307-318`). Send Message just opens
`ChatFrameUtil.SendTell(leaderName)` with an empty whisper (`:1318-1327`). Group Invite is only enabled for
solo listings when you can invite (`:1462-1478`). There is no double-click, and right-click opens a menu.

We keep both: per-row Whisper (the point of the addon) and the stock bottom pair. Recommendation:
- The bottom **Send Message** uses the same preset path as the row button (one behaviour, one anti-spam lock).
  It then means "the selected row's Whisper". Keep the stock label `SEND_MESSAGE`.
- The anti-spam lock covers the bottom buttons too. The pressed look comes from `SetButtonState("PUSHED", true)`
  on the clicked button. Other buttons ignore clicks (early return) but keep their normal look, as the
  milestone asks.
- Selection fixes: G6/G7/G8.

### D4. Section headers (fixes the highlight bug)

Forever's own answer is `LFGBrowseSearchEntryGroupingTemplate` (`Browse.xml:277-315`): the background starts
8 px down, so there is a gap above each header; the ADD highlight is the same atlas, so hovering brightens the
bar instead of drawing a blue band. Forever's other collapsible lists use the same atlas with a softer
highlight, alpha 0.3 (`Blizzard_UIPanels_Game/Camelot/ReputationFrame.xml:3-11`, `.../Camelot/SkillsFrame.xml:7-10`,
`Blizzard_TokenUI/Camelot/Blizzard_TokenUI.xml:8-11`), and `ListHeaderVisualTemplate` uses alpha 0.4
(`SX/ListTemplates.xml:22-42`). **Use the finder's own template** (full-alpha ADD) to match the finder.

Implementation: a separate header frame type. With ScrollBox, the element factory picks
`"LFGBrowseSearchEntryGroupingTemplate"` for header items, as `Browse.lua:74-94` does. In the preview, where
that template doesn't exist, build a Lua copy. With the current pooled list, give each row both looks and
make sure the row highlight texture is hidden, not just covered, while it acts as a header. A separate frame
is cleaner.

### D5. Empty / searching / no results

G27, G28. Stock clears the list while searching. Keep `LFGBrowseFrame.searching` / `.searchFailed` as
read-only signals (`Browse.lua:61-64,147-154,347-349`). Our `LFG_LIST_SEARCH_FAILED` registration is already
there (`UI/InPlace.lua:31`).

### D6. Side tabs and the Messages panel

- Tab creation: G1-G4. The template plays `IG_CHARACTER_INFO_TAB` on mouse-up (`SX/Mainline/SharedUIPanelTemplates.lua:361-366`),
  and the custom mouse-up handler is set the same way stock does (`ParentFrame.lua:100-104` vs `UI/InPlace.lua:145-150`), so both are correct.
- Icon: `Interface\Icons\INV_Letter_15` is a plain item icon, while Forever's three are `INV_SideTab_*_c60` art
  made for side tabs (`ParentFrame.xml:97,106,116`). With fillToInterior the item icon's border is cropped by the
  mask (`SX/Mainline/SharedUIPanelTemplates.xml:1026-1033`); check the look in game (Q4).
- Panel: G33. Title `LFG_TITLE` matches `WhoList.lua:202` and `Listing.lua:80`. Forever's eye portrait
  (`LFGParentFramePortrait`, strata HIGH, `ParentFrame.xml:81-93`) covers every panel's portrait slot, ours included.
- `selectedTab` is not changed while Messages shows. Toggle and reopen then go back to the last Blizzard tab
  (`ParentFrame.lua:37-46,122-150`), and our `OnShow` hooks hide Messages (`UI/InPlace.lua:156-158`).
  Acceptable. Remembering Messages as the open tab would require writing `selectedTab` (not allowed).

### D7. Messages panel controls

- Text boxes: G31 (`InputScrollFrameTemplate`; it is the non-secure twin of Listing's comment box). Put the key
  buttons right under each box (G32); Auto-send / Auto-invite checkboxes (G30) under the buttons.
- Auto-invite enabled only when Auto-send is on: `Disable()` + `GameFontDisableSmall` label; also clear its
  check, or keep it and gray it (decide in REQ).
- The `[TGF]` key button inserts at the start (only once). The other key buttons insert at the cursor with
  `EditBox:Insert(text)`, then `SetFocus()`.
- Keep "Default" as `UIPanelButtonTemplate` 22 tall (`Messages.lua:164-168`).
- The example line (`Messages.lua:150-153`): `GameFontDisableSmall` is fine; the stock "instructions" grey is
  0.35 (`InputBoxTemplates.xml:158-163`).

### D8. Usability

- **ESC:** `LFGParentFrame` is in `UIPanelWindows` (`VS/Mainline/LFGVanilla_Constants.lua:4`), so ESC closes it.
  Our boxes clear focus on ESC (`UI/Widgets.lua:305`). Fine. Multi-line boxes: Enter must clear focus (G31).
- **Sounds:** G34. Names: `SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON/OFF`, `IG_CHARACTER_INFO_TAB`.
- **Tooltip delay:** stock shows its row tooltip at once on enter, with no delay (`Browse.lua:534-541`). Ours does the same.
- **Scrolling:** switch to ScrollBox (G11). This gets us the stock scrollbar look, drag and arrows, smooth wheel
  scrolling, bar hidden when the list fits, a kept scroll position across refreshes (`RetainScrollPosition`),
  and variable row heights (headers 36 / rows 40). Factory with frame types: `factory("Button", init)` works
  when the view has an explicit extent (`SetElementExtentCalculator`). Without one it errors
  (`SX/Shared/Scroll/ScrollBoxListView.lua:40-52`). Our own XML virtual templates are also fine.
- **Keyboard:** stock has no keyboard navigation; nothing to add.

### D9. Taint notes for these recommendations

All changes stay inside the CLAUDE.md rules. Specific points:
- **Inheriting** a Blizzard template for our own frames is fine when it has no scripts calling finder globals:
  `LFGBrowseSearchEntryGroupingTemplate`, `UIMenuButtonStretchTemplate`, `ColumnDisplayButtonShortTemplate`,
  `LoadingSpinnerTemplate`, `InputScrollFrameTemplate`, `WowScrollBoxList`, `MinimalScrollBar`,
  `UICheckButtonTemplate`, `SearchBoxTemplate`.
  **Do not** inherit `LFGBrowseSearchEntryTemplate`/`LFGBrowseNestedSearchEntryTemplate`. Their OnLoad/OnEvent/OnClick
  (`Browse.xml:202-208`) run `LFGBrowseFrame:ValidateSelection()` and `selectionBehavior:ToggleSelect` from
  our frames (`Browse.lua:511-532`), which writes Blizzard state from tainted code.
- **Don't call** `LFGBrowseSearchEntryTooltip_UpdateAndShow` (it writes into Blizzard's tooltip frame and
  pools), `LFGBrowse_DoSearch` (restricted `Search`), `LFGParentFrameTab1_OnClick` / `LFGParentFrame_SetActiveTab`
  (shows the secure Listing frame from tainted code), or `LFGBrowseUtil_Report*` / `ReportFrame` (unknown, see Q6).
- **May call:** `LFGBrowseUtil_SortSearchResults(ourOwnArray)` (it only reads the API and sorts the array it is
  given; `Browse.lua:1342-1460`). Copying it is safer still.
- `hooksecurefunc(LFGParentFrame, "UpdateTabs", ...)` (G3) is allowed by the rules.
- Calls on **our** tab only (`SetChecked`, `SetFillToInterior`): fine.
- Reading `LFGBrowseFrame.searching` / `.searchFailed`: reads only, fine.
- Adding to Blizzard's options gear menu through `Menu.ModifyMenu("MENU_LFG_LISTING_SETTINGS", cb)`
  (`Blizzard_Menu/Menu.lua:2767`, tag at `Browse.lua:1278`) is the official extension point. It doesn't
  write finder fields, but it changes a Blizzard menu. Not recommended for v0.1; noted as an option only.

---

## Recommended requirement list

Grouped for the roadmapper. IDs are suggestions (`UIP-*`).

**Must (v0.1 parity):**
- UIP-01 Messages side tab: unchecked at creation, `fillToInterior`, kept in sync with `UpdateTabs`, stock-style tooltip (G1-G4). S
- UIP-02 Section headers: the finder's grouping template look and hover, plus/minus atlases, 36 tall (G5, the known bug). M
- UIP-03 Selection like stock: by resultID, toggle off, not on delisted/own rows, cleared on new results, click sound; no double-click (G6-G8). S
- UIP-04 Layout: no second inset/border; search box in the stone band; column headers in the strip above `BarTop`; Needs my role + status in the bottom bar; GS space to Roles/Activity (G9, G10, G29). M
- UIP-05 ScrollBox + MinimalScrollBar list with separate header/row frames and variable heights (G11, G13). L
- UIP-06 Row look: mid2 background/hover/selected (own listing: highlightbar set), stock fonts and colours, greyed = 0.3 grey + desaturated icons, leader icon on groups (G12, G14, G15, D2). M
- UIP-07 Roles: micro icons for solo players (G17); Discord icon/voice wording (G19). S
- UIP-08 Own listing row: stock delist button, leader/solo only, "Your listing" in green (G22). S
- UIP-09 Row tooltip in stock order and wording, our extras after (G26). M
- UIP-10 Searching spinner, no-results / search-failed texts as stock; our own text for search-box filtering (G27, G28). S
- UIP-11 Messages panel: Who-list frame layers; multi-line preset boxes; key buttons; native checkboxes with sounds; Auto-invite disabled look (G30-G33). M
- UIP-12 Sounds on row select, hide, checks (G34). S
- UIP-13 Whisper button pressed-state lock with `SetButtonState` (G24); bottom Send Message shares the preset path and the lock (D3). S

**Nice:**
- UIP-14 Compact role-count display for groups above 5 players (G18). M
- UIP-15 Playstyle in the tooltip / row; comment in light grey (G20, G21). S
- UIP-16 Hide button as a stretch button with an icon (G23). S
- UIP-17 Right-click menu without Report (G25). S
- UIP-18 Default order = stock order; header click cycles asc / desc / stock (G35). M
- UIP-19 Server remaining-slot counts for Needs my role (G36). S
- UIP-20 Refresh the tooltip of a hovered row after updates (G37). S
- UIP-21 Preview stand-in uses the stock tab/dropdown/refresh templates and sizes (G38). M

**Later:** custom tooltip frame copied from `LFGBrowseSearchEntryTooltip`; Report entries in the context menu (needs a taint probe).

---

## Open questions for in-game check

- Q1 Is 620 still the right width without GS? Try 580-620 and check that Activity is readable with ~15-char short names.
- Q2 Does the search box fit between the refresh button (ends about x 411) and the options gear (TOPRIGHT -12,-32) at the chosen width?
- Q3 Does `BarTop` really show through our current band (G9)? Screenshot before/after.
- Q4 How does `INV_Letter_15` look under the side-tab mask at 50x50? Is there a better-fitting icon?
- Q5 Do `common-button-list-mid2(-hover|-selected)` stretch cleanly at 40 px (their native height is ~72)? If not, use the `groupfinder-highlightbar` set for every row.
- Q6 Can tainted code open the report dialog (`ReportFrame:InitiateReport`) without `ADDON_ACTION_BLOCKED`? Decides UIP-17's Report items.
- Q7 Do `auctionhouse-ui-sortarrow` and `ColumnDisplayButtonShortTemplate` (`WhoFrame-ColumnTabs`) exist and look right in the Forever client? The templates are in `SX/Mainline`, which loads on camelot through `[Family]`; atlas data is client-side.
- Q8 Does Forever re-show any hidden part (spinner, NoResultsFound) through calls other than `Show`/`SetShown`? `StayHidden` (`UI/InPlace.lua:75-83`) only hooks those two.
- Q9 What `displayType` do Forever's raid / battleground / custom activities use? It decides how much G18 matters.
- Q10 Hide icon for G23: pick an atlas in game (`common-icon-redx` exists in the source; it may read as "delete").
