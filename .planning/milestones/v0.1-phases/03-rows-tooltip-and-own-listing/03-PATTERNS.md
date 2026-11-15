# Phase 3: Rows, Tooltip and Own Listing - Pattern Map

**Mapped:** 2026-11-11
**Files analyzed:** 8 (7 repo files modified, 1 external test harness modified; no new repo files)
**Analogs found:** 8 / 8 (every change extends an existing function; the "analog" is the code being replaced or its nearest sibling)

All paths relative to `C:\Users\jonat\Repositories\TerribleGroupFinder` unless absolute. Line numbers are from the working tree at mapping time (before Phase 3 edits). Smoke harness dir (outside repo): `C:\Users\jonat\AppData\Local\Temp\claude\3a677a53f55271b6\8039163f-18e8-4930-88a2-d8efcca63b25\scratchpad\smoke\` (`harness.lua` stubs, `tail.lua` assertions, `splice.js`, `run.js`).

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|-------------------|------|-----------|----------------|---------------|
| `Listings.lua` (+voiceMode, playstyle, counts, remaining, Act.groupID) | service (API reader) | transform | itself: `Read` (112-160), `L.Social` (88-110, pcall-guarded optional API) | exact |
| `Preview.lua` (+voiceMode, playstyle, remaining on samples) | model (sample data) | batch | itself: `Group(..., extra)` calls with `{ voice = true }` (169, 203, 228, 234), `P.playstyles` (278) | exact |
| `Core.lua` (`ns.VOICE`, `MyEntry` fields) | utility / config | transform | itself: `MyEntry` (166-189), `ns.MyRoles` (88-96) | exact |
| `UI/Widgets.lua` (`W.IconButton`, colours, `W.AtlasMarkup`, `W.Playstyle`, micro mode in `W.RoleIcon`, function titles in `W.Tooltip`) | component helper | request-response | `W.Button` (250-274), `W.RoleIcon` (342-365), `W.Tooltip` (231-248), `W.Icon`/`ICONS` (106-123), `W.GRAY/BRIGHTBLUE/DELISTED` (57-59) | exact |
| `UI/Table.lua` row/tooltip/refresh/FitsMyRoles | component | event-driven + request-response | itself: `ShowTooltip` (306-397), `SetRoles` (490-531), `BuildRow` (551-641), `FillRow` (739-845), `Collect` (848-892), `Refresh` (894-956), `FitsMyRoles` (153-167), `BuildList` resetter (1016-1020) | exact |
| `UI/InPlace.lua` (`source.hasListing`) | provider (source table) | request-response | itself: `source` (60-72) | exact |
| `UI/MainFrame.lua` (`source.hasListing` for the stand-in) | provider | request-response | itself: source at 329-335 | exact |
| Smoke harness `harness.lua` / `tail.lua` | test | request-response | `rowlook` probe (`tail.lua:464-513`), `GameTooltip` stub (`harness.lua:91-100`), `KNOWN`/`decorate` (`harness.lua:101-145`) | exact |

## Pattern Assignments

### `Listings.lua` (service, transform)

**Analog:** `Listings.lua` itself. New reads copy `L.Social`'s "optional API under pcall, fields type-checked and secret-guarded" shape and `Read`'s field list.

**Secret guard + optional-API pcall to copy** (lines 16-18, 88-99):
```lua
local function Secret(v)
	return v ~= nil and issecretvalue ~= nil and issecretvalue(v)
end
...
	if C_LFGList.GetSearchResultFriends then
		local ok, bnet, chars, guild = pcall(C_LFGList.GetSearchResultFriends, id)
		if ok then
```
New `ReadCounts(id)` goes above `Read`, same style: nil-check `C_LFGList.GetSearchResultMemberCounts` (not in API docs), `pcall`, `type(c) == "table"`, per-field `type(n) == "number" and not Secret(n)`; keys `TANK/HEALER/DAMAGER` and `*_REMAINING` (RESEARCH Pattern 1, lines 117-136 there). Any bad field makes that table nil.

**Where fields land** (lines 152-158, replace the `l.voice` line):
```lua
	l.comment = not Secret(info.comment) and info.comment or nil
	l.age = info.age or 0
	l.listedAt = now - l.age
	l.delisted = info.isDelisted == true
	l.mine = info.hasSelf == true or nil
	l.voice = info.voiceMode ~= nil and info.voiceMode ~= 0   -- becomes: voiceMode guarded, voice derived
	l.newPlayerFriendly = info.newPlayerFriendly == true
```
Note: `Read` runs under `pcall(Read, id, now)` per listing (line 180), so an error never drops the batch. Do NOT read `GetSearchResultEncounterInfo` here (D-03: tooltip show only).

**`Act()` addition** (lines 30-38): add `groupID = info.groupFinderActivityGroupID` to the table literal (preview activities have none, so the tooltip falls back to a flat list).

---

### `Preview.lua` (model, batch)

**Analog:** the `extra` table argument of `Group`/`Solo` (lines 119-127, 130-149).

**Pattern** (lines 164-170, 198-204, 229-235):
```lua
Group(
	{ "SMGY", "SMLIB" },
	{ "Kaelthorn:PALADIN:34:TANK:36.2", "Mirabelle:MAGE:33:DAMAGER:~31.8" },
	"GY then Lib, need healer + 2",
	11,
	{ voice = true }
)
```
Replace `voice = true` with `voiceMode = ns.VOICE.Discord` etc. (mix Discord / Legacy / None), add `playstyle = 1..4` to a few, and `remaining = { TANK = n, HEALER = n, DAMAGER = n }` to some groups, leaving others nil so the `COMPOSITION` fallback stays exercised. Solo samples pass `extra` as the 8th arg (line 257, 276). Preview.lua loads after Core.lua per the TOC, so `ns.VOICE` is available at file scope (verify TOC order). `P.playstyles` (line 278) is the preview name fallback for `W.Playstyle`.

---

### `Core.lua` (utility)

**Analog:** `Core.lua` `MyEntry` (166-189) and `ns.MyRoles` (88-96).

**`MyEntry` edit points** (lines 183, 187): drop `comment = "Your listing"` (Pitfall 7, the Activity cell now shows `LFG_SELF_LISTING`); replace `voice = mine.voice` with `voiceMode = mine.voice and ns.VOICE.Discord or ns.VOICE.None` (or map a real `mine.voiceMode`), add `playstyle = mine.playstyle`.

**New constant** (near the top of Core.lua, before first use; RESEARCH Pitfall 4):
```lua
ns.VOICE = (Enum and Enum.LFGEntryVoiceMode) or { None = 0, Legacy = 1, Discord = 2, Custom = 3 }
```

---

### `UI/Widgets.lua` (component helper, request-response)

**Analog 1 for `W.IconButton`: `W.Button`** (lines 250-274): template via the swallowing `Create`, flat fallback, `SetSize`, optional `onClick`.
```lua
function W.Button(parent, text, width, height, onClick)
	local b = Create("Button", parent, "UIPanelButtonTemplate")
	b:SetSize(width or 100, height or 22)
	if not b:GetNormalTexture() then
		...flat bg/highlight textures...
	end
	...
	b:SetText(text)
	if onClick then
		b:SetScript("OnClick", onClick)
	end
	return b
end
```
`W.IconButton(parent, w, h)`: `Create("Button", parent, "UIMenuButtonStretchTemplate")`; detect real application via `b.MiddleMiddle ~= nil` (because `Create` swallows failures, lines 15-24); if not styled fall back to `W.Button(parent, "", w, h)`; add `b.Icon` texture (name `Icon` gets the template's pressed offset), HIGHLIGHT `UI-Common-MouseHilight` ADD texture; record `b.styled`. Full sketch in RESEARCH Pattern 2. Re-set the icon size after every `SetAtlas` on a reused frame (Pitfall 9).

**Analog 2 for tooltips on stateful buttons: `W.Tooltip`** (lines 231-248):
```lua
local function Tooltip(f, title, body)
	if not title then return end
	f:HookScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
		GameTooltip:SetText(title, 1, 1, 1)
		if body then
			GameTooltip:AddLine(body, nil, nil, nil, true)
		end
		GameTooltip:Show()
	end)
	f:HookScript("OnLeave", function() GameTooltip:Hide() end)
end
```
Change: let `title`/`body` be functions (`type(title) == "function" and title(self) or title`) so the hide button reads Hide/Show per row state (Pitfall 8). Keep `HookScript` (taint rule, and existing harness keeps only the first hook).

**Analog 3 for micro icons: `W.RoleIcon`** (lines 342-365). `SetRole(role)` picks `groupfinder-icon-role-large-<tank|heal|dps>` via `W.Atlas(tex, atlas)` with a coloured-square plus letter fallback (the `ROLE_COLOR/ROLE_LETTER` tables). Add a mode (`SetRole(role, micro)` or `SetMicro`) that uses `groupfinder-icon-role-micro-*`, sets size 18 (groups: 14), and falls back to the same letter square. `W.Atlas` returns false when the atlas is missing, which is the fallback trigger:
```lua
if not W.Atlas(self.tex, "groupfinder-icon-role-large-" .. ROLE_ATLAS[role]) then
	local c = ROLE_COLOR[role]
	self.tex:SetColorTexture(c[1], c[2], c[3], 1)
	self.letter:SetText(ROLE_LETTER[role])
end
```

**Analog 4 for colour tables: lines 57-59**
```lua
W.GRAY = GRAY_FONT_COLOR or { r = 0.5, g = 0.5, b = 0.5 }
W.BRIGHTBLUE = BRIGHTBLUE_FONT_COLOR or { r = 0.4, g = 0.73, b = 1 }
W.DELISTED = { r = 0.3, g = 0.3, b = 0.3 }
```
Add `W.LIGHTGREEN`, `W.LIGHTGRAY`, `W.GREEN`, `W.NORMAL`, `W.RED` the same way (values in RESEARCH "Row text colours"). Apply with existing `W.SetColor(fs, c)` (line 61).

**Analog 5 for `W.AtlasMarkup` / voice-tag removal: `W.Icon` + `ICONS`** (106-123): rich string if `W.Rich()` else a text tag. `W.AtlasMarkup(atlas, size)` returns `""` when `not W.HasAtlas(atlas)`, else `CreateAtlasMarkup` if defined, else `"|A:name:size:size|a"`. `W.Icon("voice")` entry stays only as the Discord fallback tag (D-07).

---

### `UI/Table.lua` (component, event-driven + request-response)

#### Header constants (lines 37-38, D-21)
```lua
local HIDE_W, MSG_W = 20, 66
local ACTIONS_W = HIDE_W + 3 + MSG_W + 2 -- the buttons at a row's right edge
```
Becomes `HIDE_W = 24` (ACTIONS_W 95 per research). `Layout(header, header, header, -(ACTIONS_W + GAP))` (line 1217) and `Layout(row, cells, row.message, -GAP)` (619) both derive from it, so header and rows stay aligned with no other edit.

#### `FitsMyRoles` (lines 153-167, UIP-15)
**Analog:** existing function; put the server path in front of the estimate.
```lua
local function FitsMyRoles(l)
	if l.solo then
		local t, h, d = MyOpen()
		local r = l.leader.roles or {}
		return (r.tank and t > 0) or (r.healer and h > 0) or (r.dps and d > 0) or false
	end
	RoleCounts(l)            -- estimate: fills module-level `counts`/`open` (no allocation, keep it so)
	local mine = ns.MyRoles()
	for _, role in ipairs(ROLES) do
		if mine[ROLE_KEY[role]] and open[role] > 0 then
			return true
		end
	end
	return false
end
```
Insert after the `l.solo` branch: if `l.remaining` and not (all three 0 and `#l.members < Size(l)`; Pitfall 2) then loop `ROLES` with `mine[ROLE_KEY[role]] and l.remaining[role] > 0`. No per-call table allocation (Pitfall 10). `VALUES.role` (213-218) and `Demoted` (202-204) already call `FitsMyRoles`, so sort and greying agree automatically.

#### `SetRoles` (lines 490-531, UIP-07, D-05/D-06)
**Analog:** existing; solo branch (495-505) switches to micro with explicit per-fill sizing and anchors; group branch (506-531) keeps large icons but takes open slots from `l.remaining` when present.
```lua
if l.solo then
	local n = 0
	for _, role in ipairs(ROLES) do
		if l.leader.roles and l.leader.roles[ROLE_KEY[role]] then
			n = n + 1
			row.slots[n]:SetRole(role)
			row.slots[n]:Show()
		end
	end
	return
end
```
Slots are created once in `BuildRow` at `SetPoint("LEFT", (i-1)*15, 0)` size 14 (lines 587-591). Because frames are reused, `SetRoles` must `ClearAllPoints`/`SetPoint("LEFT", (n-1)*20, 0)`/`SetSize(18,18)` for solo and restore step 15 / size 14 for groups on every fill (Pitfall 9, regression case: solo row then group row on the same frame). Greyed handling (slot desaturate and alpha 0.5) stays in `FillRow` 828-831.

#### `BuildRow` (lines 551-641)
**Name cell** (576-580): replace the `row.name:SetPoint("RIGHT", 0, 0)` anchor with an explicit width and add `row.discord` texture (16 px, parented to `cells.name`) for Pitfall 5:
```lua
row.name = W.Text(cells.name, "GameFontNormal", 12)
row.name:SetPoint("TOPLEFT", 20, -4)
row.name:SetPoint("RIGHT", 0, 0)
```
**Buttons** (611-619): replace with the new builders; keep `row.hide` and `row.message` field names (existing probes use `fr.hide.__scripts.OnClick`; Phase 4 attaches the contact lock to `row.message`). Add `row.delist` (IconButton 24x22, `SetPoint("RIGHT", -8, 0)` per D-10).
```lua
row.hide = W.Button(row, "x", HIDE_W, 20, function(b)
	Hide(b:GetParent().listing)
end)
row.hide:SetPoint("RIGHT", -2, 0)
row.message = W.Button(row, "Whisper", MSG_W, 20, function(b)
	inst:Message(b:GetParent().listing)
end)
row.message:SetPoint("RIGHT", row.hide, "LEFT", -3, 0)
Layout(row, cells, row.message, -GAP)
```
For the own row the listed cell must still anchor sensibly when `message` is hidden: anchor `Layout` to the delist button's left edge or keep `row.message` as the layout anchor while hidden (the hidden frame keeps its anchor geometry; verify no overlap with the delist at RIGHT -8). Delist click, copy from RESEARCH "Delist handler" (uses `W.PlayCheckbox(true)`, `inst.source.preview()`, `C_LFGList.HasActiveEntryInfo()`, `C_LFGList.RemoveListing()`; never `LFGBrowse_DoSearch`).

**Tooltip wiring** (636-640): keep `row:SetScript("OnEnter", ShowTooltip)` and the `OnLeave` hide; `W.Tooltip(row.hide, "Hide", ...)` becomes the function-title form.

**Comment colour** (606-609): `row.comment` is in the `__tgfColor` list (restore-on-fill). Remove it from that list and set `W.LIGHTGRAY` explicitly in `FillRow` (D-18), delisted grey still wins when greyed.

#### `FillRow` (lines 739-845)
Every visible state is set on every fill (header comment line 809 "Colours, set on every fill: the frames are reused"). New/changed items, following the existing blocks:
- Tags (765-775): remove the `W.Icon("voice")` tag and the `" |cff33ff33(you)|r"` suffix; compute `showDiscord = l.voiceMode == ns.VOICE.Discord`; `maxW = 130 - (showDiscord and 20 or 0)`; `row.name:SetWidth(maxW)`; place `row.discord` at `LEFT` x = `20 + min(row.name:GetStringWidth(), maxW) + 4`; `SetDesaturated(greyed)`; atlas `UI-ChatIcon-Discord` via `W.Atlas`, else fall back to the text tag `W.Icon("voice")` appended to the name.
- Activity (792-794): own row: `row.activity:SetText(LFG_SELF_LISTING or "Your listing")` coloured `W.LIGHTGREEN`. Colour block at 817-826 currently sets activity to `MatchesActive and BRIGHTBLUE or GRAY`; the own row branch must override and the next normal row on the same frame must reset (regression in UI-SPEC).
- Buttons (836-844):
```lua
row.selected:SetShown(IsSelected(self, l))
row.hide:SetShown(not l.mine)
row.hide:SetText(hidden and "+" or "x")
row.message:SetText(l.mine and "Unlist" or "Whisper")
if l.mine then
	row.message:SetEnabled(CanUnlist(self))
else
	row.message:SetEnabled(not l.delisted)
end
```
becomes: `row.message:SetShown(not l.mine)`, `row.hide:SetShown(not l.mine)`, `row.delist:SetShown(l.mine and CanUnlist(self))`, hide icon atlas swapped by `hidden` (`transmog-icon-hidden` / `socialqueuing-icon-eye`, 16 px, text "x"/"+" when `not row.hide.styled`), message text always "Whisper", `SetEnabled(not l.delisted)`.

#### `Instance:Message` and `CanUnlist` (lines 443-473, D-14)
`CanUnlist(inst)` (445-450) stays and is reused for the delist visibility. In `Instance:Message` delete the `l.mine` branch (459-468) so only `ns.Messages.Send(l, preview)` + `T.RefreshAll()` remain.

#### `ShowTooltip` (lines 306-397, UIP-09/13)
**Analog:** existing function for the ownership/Show skeleton; rewrite the body into `StockTooltip(l)` then `ExtrasTooltip(l)` helpers using the pending-blank writer (RESEARCH Pattern 3). Skeleton to keep:
```lua
local function ShowTooltip(row)
	local l = row.listing
	if not l then return end
	GameTooltip:SetOwner(row, "ANCHOR_RIGHT")
	...lines...
	GameTooltip:Show()   -- exactly once
end
```
Reusable pieces to keep for extras: `FriendsLine(l)` (295-304) with `LFG_LIST_TOOLTIP_FRIENDS_IN_GROUP`, `W.Marks`, `W.Colored(class, name)`, `W.Age`, `IsHidden(l)`, solo `spec/area` expression (341), GS lines behind `ns.GEAR_SCORE` (336-338, 362-366). Existing comment line uses wrap flag `true` as 5th arg (328), keep with `W.LIGHTGRAY`. Drop: title-line activity name (312-315), "Can play:" (351), "Looking for:" (371-379), "level %d %s" format (335), the `voice chat` flag (389-391). `GameTooltip:AddLine` always gets explicit RGB (existing code already does). Activity colour test reuses `inst.activeIDs[a.key]` (built per refresh by `ActiveActivityIDs`, 696-719; `MatchesActive` 726-737 is the per-listing equivalent). Because `ShowTooltip` is a module-local that does not receive `inst`, pass the active set via a module upvalue or make `OnEnter` a closure over `inst` (`row:SetScript("OnEnter", function(r) ShowTooltip(r, inst) end)`).
Bosses defeated: `pcall(C_LFGList.GetSearchResultEncounterInfo, l.id)` at show time only, single-activity only, `Secret` guard (local `issecretvalue` check as at 706/714).

#### `Instance:Refresh` + resetter (lines 894-956, 1016-1020, UIP-16)
**Resetter that hides the tooltip first** (must stay):
```lua
view:SetElementResetter(function(frame)
	if GameTooltip:GetOwner() == frame then
		GameTooltip:Hide()
	end
end)
```
Therefore capture hovered state at the top of `Refresh` before `self.list:SetItems(...)` (line 936) and re-show after; call the re-show on every exit path (searching 915-921, failed 924-931, normal tail 955). Hosts already expose `ForEachFrame(fn)`: ScrollBox host (1052-1054) and `W.List` (check `W.List:ForEachFrame` exists in Widgets 477-596; add it if missing, sharing the same `(frame, item)` signature). Code: RESEARCH Pattern 4 (`HoveredRow`, `RefreshTooltip`, uses `frame:IsMouseOver()`).

#### `Instance:Collect` (lines 848-892, D-13)
Own row today:
```lua
if l.mine then
	mine = l
elseif Matches(l) then
```
and later `if mine then mine.demoted = false; items[1] = mine end`. In game, ignore `mine` when `not self.source.hasListing()`. Add `hasListing` to the source tables.

---

### `UI/InPlace.lua` and `UI/MainFrame.lua` (provider)

**Analog:** the `source` table (`UI/InPlace.lua:60-72`, `UI/MainFrame.lua:329-335`):
```lua
local source = {
	listings = function() ... end,
	preview = function() ... end,
	searching = function()
		return LFGBrowseFrame and LFGBrowseFrame.searching == true
	end,
```
Add `hasListing = function() ... end`: InPlace: `ns.UsingPreview() and ns.state.myListing ~= nil or (C_LFGList and C_LFGList.HasActiveEntryInfo and C_LFGList.HasActiveEntryInfo() == true)` (guard `issecretvalue`); MainFrame: `ns.state.myListing ~= nil`. InPlace already calls `tbl:Refresh()` after `ReadSoon` (lines 40-58) and refreshes on `LFG_LIST_ACTIVE_ENTRY_UPDATE`, so the own row drops after delist with no new hook.

---

### Smoke harness (test)

**Analog for stubs:** `harness.lua:91-106` (GameTooltip capture, `KNOWN`, `GetTemplateInfo`):
```lua
G.GameTooltip = newFrame("GameTooltip", "GameTooltip")
for _, n in ipairs({ "AddLine", "AddDoubleLine", "SetText" }) do
  rawset(G.GameTooltip, n, function(self, ...)
    for i = 1, select("#", ...) do
      local v = select(i, ...)
      if type(v) == "string" then log.tips[#log.tips + 1] = v end
    end
    return self
  end)
end
local KNOWN = { TerribleGroupFinderListHeaderTemplate = {...}, TerribleGroupFinderListRowTemplate = {...} }
```
Edits: keep pushing strings to `log.tips`, additionally push `{text, r, g, b, wrap}` to `log.tipLines`; make `SetOwner` store `__owner` and clear `tipLines`, `GetOwner` return it, count `Show` into `log.tipShows`; add `UIMenuButtonStretchTemplate` to `KNOWN` (toggle) and to `decorate(f, tmpl)` (`harness.lua:~138`) setting `f.MiddleMiddle = newFrame("Texture")`. `releaseAll` (108-118) already runs the ScrollBox resetter, which is what makes the Pitfall 1 test meaningful. Remaining stubs listed in RESEARCH "Stubs to add" (Enum, globals, colour globals, `C_LFGList.*` recorders, `LFGBrowse_DoSearch` etc. recorders).

**Analog for assertions:** `tail.lua` `rowlook` probe (464-513): `probe(name, fn)`, `check(cond, msg)`, `Frames(inst)`, `ItemOf(fr)`, local `find(inst, pred)` and `eq(color, r, g, b)`, with `C_Texture.GetAtlasInfo = function() return {} end` to exercise atlas branches. Copy this structure for each new probe (micro atlases/sizes, Discord, own row, delist click recorders, tooltip order via `log.tipLines`, refresh with `fr.IsMouseOver = function() return true end`, hide icon swap, Needs-my-role greying). Existing assertions to keep green: `fr.slots[1].__alpha == 1` (494), `fr.name.__color` class colour (496), own row art atlases (500), group row `icon.__atlas == "groupfinder-icon-leader"` (503). Edit flow: stubs at top of `harness.lua`, assertions in `tail.lua`, then `node splice.js`; run `node run.js "C:/Users/jonat/Repositories/TerribleGroupFinder" [--gs] [--fallback] [--attach]`, all four modes `SUMMARY: 0 failed`.

## Shared Patterns

### Probe-and-fallback for every Blizzard template or atlas
**Source:** `UI/Widgets.lua:15-24` (`Create`), `166-181` (`HasAtlas`, `W.Atlas`); `UI/Table.lua:430-432` (`TemplateKnown`)
**Apply to:** delist button, hide button, micro icons, Discord icon, tooltip atlas markup.
```lua
local function Create(frameType, parent, template)
	if template then
		local ok, f = pcall(CreateFrame, frameType, nil, parent, template)
		if ok and f then return f end
	end
	return CreateFrame(frameType, nil, parent)
end
```
`W.Create` swallows template failures, so detect success by a template part (`MiddleMiddle`), not by the return value.

### Secret-value and optional-API guards
**Source:** `Listings.lua:16-18`, `UI/Table.lua:705-717`
**Apply to:** counts/remaining reads, voiceMode/playstyle, encounter info, `HasActiveEntryInfo`, `GetActivityGroupInfo`.
```lua
local info = C_LFGList and C_LFGList.GetActiveEntryInfo and C_LFGList.GetActiveEntryInfo()
if type(info) ~= "table" or (issecretvalue and issecretvalue(info)) then
	return ids
end
```

### Reused-frame discipline
**Source:** `UI/Table.lua:739-845` (`FillRow` sets every state each time; colour block 809-831)
**Apply to:** every new texture/button/field (discord, delist, hide icon, slot size/anchor, name width, activity and comment colours).

### Taint rules for new buttons and the delist path
**Source:** CLAUDE.md "Taint", `UI/Table.lua:443-473`, `W.Tooltip` (`HookScript` only)
**Apply to:** delist/hide buttons: our own Button inheriting only `UIMenuButtonStretchTemplate`; handlers call only `C_LFGList.RemoveListing()` (after `HasActiveEntryInfo()`); never `LFGBrowse_DoSearch`, `LFGListingFrame:RemoveListing`, `LFGParentFrameTab1_OnClick`, `LFGBrowseSearchEntryTooltip_UpdateAndShow`; no writes to Blizzard frames.

### Sounds
**Source:** `UI/Widgets.lua:276-281` `W.PlayCheckbox(on)`; `UI/Table.lua:406` (hide) and `632` (select)
**Apply to:** delist click (`W.PlayCheckbox(true)` equals `IG_MAINMENU_OPTION_CHECKBOX_ON`).

### Whole-table redraw
**Source:** `UI/Table.lua:408` `T.RefreshAll()` after state changes (`Hide`, `Message`, `Invite`)
**Apply to:** delist click in preview (clear `ns.state.myListing`, `ns.Print(...)`, `T.RefreshAll()`).

### Style
`stylua .` from the repo root after each task (tabs, as in all files above). Edit `.md`/`.planning` files with the Edit tool only.

## No Analog Found

No file lacks an analog. Sub-pieces without a direct in-repo precedent (planner uses RESEARCH.md code):

| Piece | Role | Data Flow | Reason |
|-------|------|-----------|--------|
| Pending-blank tooltip line writer (`Tip`) | utility | transform | `ShowTooltip` adds blanks inline with `AddLine(" ")`; RESEARCH Pattern 3 supplies the writer |
| Activity grouping helper (by `groupID`, order via `GetActivityGroupInfo`) | utility | transform | No grouped list exists yet; RESEARCH "Activities grouped" supplies it |
| `W.Playstyle(value)` fallback chain | utility | transform | `P.playstyles` exists only for the preview; chain in RESEARCH Pitfall 3 |
| Tooltip hovered-row capture and re-show | service | event-driven | Only the resetter hide exists today; RESEARCH Pattern 4 |

## Metadata

**Analog search scope:** `Core.lua`, `Listings.lua`, `Preview.lua`, `UI/Table.lua`, `UI/Widgets.lua`, `UI/InPlace.lua`, `UI/MainFrame.lua`, smoke harness (`harness.lua`, `tail.lua`, `run.js`)
**Files scanned:** 10
**Pattern extraction date:** 2026-11-11
