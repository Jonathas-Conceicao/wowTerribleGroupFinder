# Forever's built-in group finder: technical map

Source: `C:\Users\jonat\Repositories\wow-ui-source`, branch `forever`, build 1.60.1.70755
(game type `camelot`). Paths relative to `Interface\AddOns\`. Researched 2026-11-03.

## TL;DR

- Forever's finder (`Blizzard_GroupFinder_VanillaStyle`) is a **bulletin board**: list, browse,
  whisper, invite. **No apply flow.** Invite is only enabled on *solo* listings.
- `C_PartyInfo.RequestInviteFromUnit(name, tank, healer, dps)` exists (used by `/requestinvite`
  and the unit popup) and is **not** used by the finder: a ready-made "apply" primitive.
- Retail apply APIs (`C_LFGList.ApplyToGroup`, `GetApplicants`, …) exist in the client
  (`QueueStatusFrame` calls `GetApplications()`), but the server may not honour them: **probe**.
- Listing **comment can't be set** from addon code (secure edit box, not a `CreateListing` arg),
  and search-result `name/comment/voiceChat` are `kstringLfgListSearch`: **probably unreadable
  for string ops** (display via `SetText` only). That blocks keyword filtering: **probe**.
- `Search`, `CreateListing`, `UpdateListing`, `SendWho` are `HasRestrictions`: call only from a
  user click. No auto-refresh loops.

## 0. Load conditions

| AddOn | TOC | On Forever? |
|---|---|---|
| `Blizzard_GroupFinder_VanillaStyle` | `AllowLoadGameType: classic, camelot`, `LoadOnDemand: 1`, `Secure: 1`, deps `Blizzard_LFGUtil` | yes, on demand |
| `Blizzard_GroupFinder` (retail PVEFrame/LFGList) | `ExcludeLoadGameType: camelot` | **no** |
| `Blizzard_LFGUtil` | Shared + Mainline + `Camelot/LFGUtil.lua` | yes |

- `[Family]` = `Mainline\` on camelot. `Templates.*`, `WhoList.*` load; `LFGVanillaTabTemplates.xml`
  doesn't; `Blizzard_LFGVanilla_Minimap.lua` isn't in the TOC (dead code).
- Load chain: `Blizzard_Game/Camelot/EventImplementation.lua:12,95` →
  `SetLookingForGroupUIAvailable(C_LFGInfo.IsGroupFinderEnabled())` (`Blizzard_LFGUtil/Camelot/LFGUtil.lua:1-14`)
  → if `C_LFGList.GetPremadeGroupFinderStyle() == Enum.PremadeGroupFinderStyle.Vanilla` (2) →
  `GroupFinderVanillaStyle_LoadUI()` (`..._Bootstrap.lua:3-5`).
- For us: check style == 2; wait for `ADDON_LOADED("Blizzard_GroupFinder_VanillaStyle")` before
  touching `LFGParentFrame`. Don't load it ourselves.

## 1. How it works

### Frames
| Global | Template | Where |
|---|---|---|
| `LFGParentFrame` | Frame 458x535, toplevel, `LFGParentFrameMixin` | `Mainline/Blizzard_LFGVanilla_ParentFrame.xml:30` |
| `.ListingTab` / `.BrowsingTab` / `.WhoListingTab` | `LargeSideTabButtonTemplate` + `SidePanelTabButtonMixin` (right side tabs) | `:94-121` |
| `LFGParentFrameTab1..3` | bottom `PanelTabButtonTemplate`, hidden in modern style | `:41-79` |
| `LFGParentFramePortrait` | `LFGEyeBigTemplate`, animates while listed | `:81` |
| `LFGListingFrame` (tab 1) | `PortraitFrameTemplateNoCloseButton` | `Mainline/Blizzard_LFGVanilla_Listing.xml:278` |
| `LFGBrowseFrame` (tab 2) | `PortraitFrameTemplateNoCloseButton` | `Mainline/Blizzard_LFGVanilla_Browse.xml:426` |
| `LFGWhoListFrame` (tab 3) | `PortraitFrameTemplateNoCloseButton` | `Mainline/WhoList.xml:89` |
| `LFGListingComment` | `UIPanelInputScrollFrameTemplate`, secure edit box | `Listing.xml:602-633` |

- `UIPanelWindows["LFGParentFrame"] = { area="left", pushable=7, whileDead=1 }` (`Mainline/LFGVanilla_Constants.lua:4`).
- Tabs: `LFGPARENT_LISTING_TAB_INDEX=1`, `LFGPARENT_BROWSING_TAB_INDEX=2`, `LFG_TAB_WHO=3`.

### Opening
- `LFGVanilla_ToggleFrame(tab)` (`ParentFrame.lua:122-150`), `LFGVanilla_ShowFrame(tab)` (`:107-120`).
- `ToggleGroupFinderFrame()` (`Blizzard_Game/Shared/Game.lua:74-89`) → Vanilla toggle.
- Micro button `LFDMicroButton` → `ToggleGroupFinderFrame()`; gated by `C_LFGInfo.CanPlayerUsePremadeGroup()`.
- Bindings: `TOGGLEGROUPFINDER`, `TOGGLEWHOTAB` (`Blizzard_FrameXML/Bindings_Camelot.xml:1253`).
- Queue status eye: "View group" / "Unlist" (`Blizzard_QueueStatusFrame/Camelot/QueueStatusFrameOverrides.lua`).
- No slash command of its own. Related: `/invite`, `/requestinvite` (`SlashCommandsOverrides.lua:157-170`), `/who`.

### Browse
- `LFGBrowse_DoSearch()` (`Browse.lua:331-352`):
  `C_LFGList.Search(categoryID, 0, 0, nil, false, nil, activityIDs)`; activityIDs = dropdown
  multi-select, else `LFGUtil_GetFilteredActivities(categoryID)`. No throttle beyond a `searching` flag.
- Category dropdown: `C_LFGList.GetAvailableCategories()` + `GetLfgCategoryInfo(id).name`, plus "Your listing".
- Activity dropdown: grouped by `groupFinderActivityGroupID` (`GetActivityGroupInfo`), submenus if >1 group.
- Level filter (`ParentFrame.lua:246-268`): drops activities outside `minLevelSuggestion..maxLevelSuggestion`
  unless CVar `disableSuggestedLevelActivityFilter`.
- Results: `LFG_LIST_SEARCH_RESULTS_RECEIVED` → `C_LFGList.GetFilteredSearchResults()` →
  `LFGBrowseUtil_SortSearchResults` (`Browse.lua:1342-1460`). Sort: own listing; matching your
  active activities; solo-first if grouped / groups-first if solo; solo by role (T>H>D, roles your
  party already has go last); groups with an open slot for your roles, larger, tank-needed,
  heal-needed; then age, resultID.
- Tree list with collapsible "Solo players" / "Groups" headers.
- Row: class-coloured leader, level+class icon (solo) or party icon; Discord / new-player icons;
  activity text ("N activities"); right side by display type priority
  (Comment > RoleCount > PlayerCount > RoleEnumerate > ClassEnumerate > HideAll). Delisted greyed.
- Tooltip (`:578-875`): leader name/level/roles (`lfgRoles` solo, `assignedRole` grouped), members
  if ≤10, comment, member counts, voice, activities, bosses defeated
  (`GetSearchResultEncounterInfo`, single-activity only).
- Actions: Send Message (`ChatFrameUtil.SendTell`), Group Invite (only `numMembers==1` and you
  solo/leader/assistant → `C_PartyInfo.InviteUnit`), right-click report, delist own row,
  options gear ("Show all level ranges").
- `LFG_LIST_SHOW_SEARCH(activityIDs, showAllLevelRanges)` opens browse preselected.

### Listing (create / update / delist)
- Views: Category → Activity (checkbox tree, playstyle dropdown, level checkbox, comment, voice) / Locked (grouped non-leader).
- Roles: solo → `C_LFGListRoles.SetRoles` on every click (revert on false); grouped → `InitiateRolePoll()`, `UnitSetRole`.
- `C_LFGList.CreateListing({activityIDs, newPlayerFriendly, generalPlaystyle, voiceMode})`,
  `UpdateListing({activityIDs, newPlayerFriendly, voiceMode})`, `RemoveListing()`.
- Comment: secure ref `LFGListingComment` (`SetSecurityDisableSetText/Paste`), read in C. Max 255.
  `ClearCreationTextFields()`, `CopyActiveEntryInfoToCreationFields()`.
- Validation: can edit; ≤16 activities (`GROUP_FINDER_MAX_ACTIVITY_CAPACITY`); playstyle required
  (Learning/FunRelaxed/FunSerious/Expert); dirty; `autoChooseActivity` categories (Custom) need a
  comment; group size < `maxNumPlayers`; comment needs `IsPlayerAuthenticatedForLFG(categoryID)`.
- Blizzard bug candidate: `LoadActiveEntry` doesn't restore playstyle; `UpdateListing` doesn't send it.
- CVars `lfgNewPlayerFriendly`, `voiceProvider`. Instance lock warning via `GetSavedInstanceInfo`.
- `LFG_LIST_ACTIVE_ENTRY_UPDATE(created)` → sound + switch to browse. Expiry popups.

### Who list (tab 3)
- `C_FriendList.SendWho(text, Enum.SocialWhoOrigin.Social, {classIDs, raceIDs, uiMapIDs})` (**R**),
  `SortWho`, `GetNumWhoResults`, `GetWhoInfo(i)` → `fullName, level, raceStr, classStr, filename,
  area, fullGuildName`, max 50.
- **Gotcha:** `UpdateWhoList` calls `ShowUIPanel(LFGParentFrame)` on every `WHO_LIST_UPDATE`
  (registered while hidden). `SetWhoToUi(true/false)` on show/hide.

## 2. API inventory

Flags: **R** = `HasRestrictions`; SA-U = `SecretArguments AllowedWhenUntainted`;
**SL** = secret during chat messaging lockdown. Doc = `Blizzard_APIDocumentationGenerated/LFGListInfoDocumentation.lua`.

| Function | Signature | Flags |
|---|---|---|
| `Search` | `(categoryID, filter, preferredFilters, languageFilter?, crossFaction, advancedFilter?, activityIDs?)` | **R**, SA-U |
| `GetFilteredSearchResults` / `GetSearchResults` | `() → total, ids[]` | — |
| `GetSearchResultInfo(id)` | `LfgSearchResultData` | **SL** |
| `GetSearchResultLeaderInfo(id)` / `GetSearchResultPlayerInfo(id, i)` | `LfgSearchResultPlayerInfo` | **SL** |
| `HasSearchResultInfo(id)` | bool | SA-U |
| `GetActivityInfoTable(activityID, questID?, showWarmode?)` | `GroupFinderActivityInfo` | SA-U |
| `GetActivityGroupInfo(groupID)` | `name, orderIndex` | SA-U |
| `GetAvailableActivityGroups(categoryID, filter)` | ids[] | SA-U |
| `GetLfgCategoryInfo(categoryID)` | `{name, separateRecommended, autoChooseActivity, preferCurrentArea, showPlaystyleDropdown, allowCrossFaction}` | SA-U |
| `GetActiveEntryInfo()` / `HasActiveEntryInfo()` | `LfgEntryData` / bool | **SL** / — |
| `CreateListing(data)` / `UpdateListing(data)` | success | **R** |
| `IsPlayerAuthenticatedForLFG(categoryID?)` | bool | |
| `GetPremadeGroupFinderStyle()` | 0 Disabled, 1 Mainline, 2 Vanilla | |
| `C_LFGListRoles.GetRoles/GetSavedRoles()` | `{tank, healer, dps}` | |
| `C_LFGListRoles.SetRoles(roles, limitToClassRoles)` | success | SA-U |
| `C_LFGInfo.CanPlayerUsePremadeGroup()` / `IsGroupFinderEnabled()` | | |

Undocumented legacy (from call sites): `GetAvailableCategories([filters])`,
`GetAvailableActivities(cat[, groupID][, filters][, searchText])`,
`GetSearchResultMemberCounts(id)` (keys `TANK, HEALER, DAMAGER, NOROLE, *_REMAINING,
LEADER_ROLE_*`, class filenames), `GetSearchResultEncounterInfo(id) → string[]`,
`RemoveListing()`, `RequestAvailableActivities()`.

Present but unused by Forever's finder (server support unknown):
- Apply flow: `ApplyToGroup(resultID, tank, healer, dps)`, `GetApplications`, `GetApplicationInfo`,
  `CancelApplication`, `AcceptInvite/DeclineInvite(resultID)`; leader side `GetApplicants`,
  `GetApplicantMemberInfo`, `InviteApplicant`, `DeclineApplicant`, `RefreshApplicants`,
  `GetNumApplicants`; events `LFG_LIST_APPLICATION_STATUS_UPDATED`,
  `LFG_LIST_APPLICANT_LIST_UPDATED`, `LFG_LIST_APPLICANT_UPDATED`, `LFG_LIST_JOINED_GROUP`.
- `GetSearchResultFriends(id)`, advanced filter save/get, `SetEntryTitle` (**R**).
- Party (`PartyInfoDocumentation.lua`): `C_PartyInfo.InviteUnit(name)`,
  **`RequestInviteFromUnit(name, tank?, healer?, dps?)`** (519-532), `CanInvite()`; events
  `PARTY_INVITE_REQUEST(name, isTank, isHealer, isDamage, …)`, `REQUEST_INVITE_CONFIRMATION`.
- Chat (`ChatInfoDocumentation.lua`): `RegisterAddonMessagePrefix`, `SendAddonMessage`
  (secret args NotAllowed), `AreOutgoingAddonChatMessagesRestricted()`,
  `InChatMessagingLockdown()`, `CHAT_MSG_ADDON(prefix, text, channel, sender, …)`.

Events used by the finder: `LFG_LIST_ACTIVE_ENTRY_UPDATE`, `LFG_LIST_AVAILABILITY_UPDATE`,
`LFG_LIST_SEARCH_RESULTS_RECEIVED`, `LFG_LIST_SEARCH_FAILED`, `LFG_LIST_SEARCH_RESULT_UPDATED(id)`,
`LFG_LIST_SHOW_SEARCH`, `LFG_LIST_ENTRY_EXPIRED_TIMEOUT/_TOO_MANY_PLAYERS`, `LFG_LIST_ROLE_UPDATE`,
`GROUP_ROSTER_UPDATE`, `GROUP_LEFT`, `PARTY_LEADER_CHANGED`, `PLAYER_ROLES_ASSIGNED`,
`UPDATE_INSTANCE_INFO`, `PLAYER_LEVEL_UP`, `WHO_LIST_UPDATE`, `CVAR_UPDATE`.

## 3. Data available

**Search result** (`LfgSearchResultData`): `searchResultID, activityIDs[], leaderName, name*,
comment*, voiceChat*, voiceMode, requiredItemLevel, hasSelf, numMembers, numBNetFriends,
numCharFriends, numGuildMates, isDelisted, autoAccept, age, questID, generalPlaystyle,
newPlayerFriendly, partyGUID` (+ retail score/pvp fields). `*` = kstring.

**Player** (`LfgSearchResultPlayerInfo`): `name, level, areaName, className, classFilename,
specName, assignedRole, lfgRoles{tank,healer,dps}, isLeader, isLeaver`.

**Activity** (`GroupFinderActivityInfo`): `fullName, shortName, categoryID,
groupFinderActivityGroupID, ilvlSuggestion, filters, minLevel, minLevelSuggestion,
maxLevelSuggestion, maxNumPlayers, displayType, orderIndex, mapID, difficultyID, is*Activity`.

**Create data** (`LfgListingCreateData`): `activityIDs, questID, isAutoAccept, isPrivateGroup,
newPlayerFriendly, playstyle, generalPlaystyle, requiredItemLevel, voiceMode, …` — **no comment**.

Notable for "better listings": `areaName`/`specName` per member, `lfgRoles` of solo players,
friends/guild counts, `questID`, level suggestions per activity — all things the built-in UI
underuses.

## 4. Categories

| ID | Category | Atlas |
|---|---|---|
| 2 | Dungeons | `groupfinder-button-dungeons` |
| 114 | Raids | `groupfinder-button-raids-warlords` |
| 116 | Quests & Zones (default) | `groupfinder-button-questing` |
| 118 | Battlegrounds | `groupfinder-button-battlegrounds` |
| 120 | Custom (comment required) | `groupfinder-button-custom-pve` |

Activities: enumerate at runtime (`GetAvailableCategories` → `GetAvailableActivityGroups` /
`GetAvailableActivities` → `GetActivityInfoTable`). Enums: `LFGListDisplayType` (RoleCount 0 …
Comment 5), `LFGEntryGeneralPlaystyle` (0–4), `LFGEntryVoiceMode` (None/Legacy/Discord/Custom).

## 5. Forever-native visual vocabulary

- Frame: `PortraitFrameTemplateNoCloseButton` (title via `TitleContainer.TitleText`), 458x535,
  `UIPanelCloseButtonDefaultAnchors`, portrait `LFGEyeBigTemplate`.
- Nav: right side tabs `LargeSideTabButtonTemplate` + `SidePanelTabButtonMixin`, icons
  `Interface\ICONS\INV_SideTab_GroupFinder_c60`, `INV_SideTab_GroupBrowsing_c60`, `INV_SideTab_WhoList_c60`.
- Backgrounds: header `groupfinder-Stat-StoneBG`; content `groupfinder-background` in
  `common-insideframe`; lines `groupfinder-ScrollLine`, `common-framedivider`; roles band
  `groupfinder-roles-background`.
- Controls: `WowStyle1DropdownTemplate`, `WowStyle1FilterDropdownTemplate` (`SetupMenu`,
  `MenuUtil.CreateContextMenu`), options `DropdownButton`+`MenuStyle2Mixin`+`OptionsIcon-Brown`,
  `WowScrollBoxList` + `MinimalScrollBar` (`CreateScrollBoxListTreeListView`,
  `ScrollUtil.InitScrollBoxListWithScrollBar`), `UIPanelButtonTemplate`, `SearchBoxTemplate`,
  `LoadingSpinnerTemplate`, `UICheckButtonTemplate`, `TooltipBackdropTemplate`, `RoleCountLargeNoScriptsTemplate`.
- Rows: `groupfinder-highlightbar(-yellow|-blue)`; nested `common-button-list-mid2(-hover|-selected)`;
  headers `common-button-list-collapseExpand/plus/minus`; large `common-button-list-large`.
- Icons: `groupfinder-icon-role-large-{tank,heal,dps}`, `groupfinder-icon-role-micro-*`,
  `UI-LFG-RoleIcon-*`, `groupfinder-icon-class-<classfile>`, `groupfinder-icon-leader`,
  `groupfinder-icon-emptyslot`, `groupfinder-icon-redx`, `groupfinder-waitdot`,
  `newplayerchat-chaticon-newcomer`, `UI-ChatIcon-Discord`, `friends-icon-friendsInGroup`.
- Fonts: `GameFontNormalLarge`, `GameFontDisableLeft`, `GameFontNormalLeftLightGrey`,
  `GameFontHighlight`, `LFGActivityHeader/Entry/EntryTrivial/EntryDifficult`.
- Colours: `RAID_CLASS_COLORS`, delisted 0.3 grey, `BRIGHTBLUE_FONT_COLOR` matching,
  `LIGHTGREEN_FONT_COLOR` self. Sounds `SOUNDKIT.IG_CHARACTER_INFO_*`, `PVP_ENTER_QUEUE`.

## 6. Taint / security rules for us

1. No comment set from code; either list without one or send the user to Blizzard's Listing tab.
2. Treat kstrings as display-only until probed; nothing SL-flagged compared/concatenated in lockdown.
3. Restricted calls (`Search`, `CreateListing`, `UpdateListing`, `SendWho`) only from OnClick.
4. One shared result set per client: Blizzard's browse redraws on our searches (harmless).
5. `/who` from us pops `LFGParentFrame` via its `WHO_LIST_UPDATE` handler — design around it.
6. Never replace Blizzard globals/mixins (`LFGVanilla_ToggleFrame`, `ToggleGroupFinderFrame`,
   `LFGBrowse_DoSearch`). Use `hooksecurefunc` / `HookScript`. Our own window: `UISpecialFrames`
   for ESC, not `UIPanelWindows` from tainted code.
7. Don't call `GroupFinderVanillaStyle_LoadUI()`; listen for `ADDON_LOADED`.
8. Invite gate: `not IsInGroup() or UnitIsGroupLeader("player") or UnitIsGroupAssistant("player")`.
   Pass plain non-secret names.
9. `SetRoles` may return false.
10. `SendAddonMessage` refuses secret args; check `AreOutgoingAddonChatMessagesRestricted()`.

## 7. Reusable Blizzard helpers (exist only after the finder loads; copying logic is safer)

`LFGUtil_GetFilteredActivities`, `LFGUtil_SortActivityIDs`, `LFGUtil_OrganizeActivitiesByActivityGroup`,
`LFGUtil_GetActivityInfoName`, `LFGBrowseUtil_SortSearchResults`,
`LFGBrowseUtil_GetBestDisplayTypeForActivityIDs`, `LFGListingUtil_CanEditListing`,
`GetGroupMemberCounts`, `GetGeneralPlaystyleString`. Plenty of localized globals exist
(`LFG_TITLE`, `LFG_LIST_CATEGORY_SOLO_PLAYERS`, `SEND_MESSAGE`, `GROUP_INVITE`, …) — use them.

## Classic/ folder

Not loaded on Forever (static portrait art, bottom tabs, no Who tab). Ignore.
