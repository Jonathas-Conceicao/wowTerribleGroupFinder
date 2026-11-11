-------------------------------------------------------------------------------
--  UI/Table.lua -- the listings table (ns.Table), placed inside a Browse frame: Forever's
--  own LFGBrowseFrame in game (UI/InPlace.lua), or the preview stand-in (UI/MainFrame.lua).
--
--  As Forever's list: your own listing first, then two collapsible sections, Solo players
--  and Groups (groups first while you're solo, solo players first while you lead). Within
--  each, rows sort by the clicked column: Roles (tank > healer > damage), Lvl, GS (a group's
--  best known; only while ns.GEAR_SCORE is on), Activity, Listed. Hidden players (X) and, with Needs my role, listings with
--  no slot for you are greyed and moved to the end of their section, never removed.
--
--  The list is Blizzard's own ScrollBox (WowScrollBoxList + MinimalScrollBar) with separate
--  header and row frames; where the ScrollBox API or our templates (UI/Templates.xml) are
--  missing, W.List draws the same items.
--
--  Columns can't overlap: Name, Lvl, Roles (and GS, while ns.GEAR_SCORE is on) have fixed widths from the left, Listed
--  and the row's buttons are anchored to the right, and Activity takes what is left
--  between them; every cell is width-bound, so long text is cut, not drawn over a neighbour.
-------------------------------------------------------------------------------
local _, ns = ...
local W = ns.W
local wipe = W.wipe

local lower, find, format = string.lower, string.find, string.format
local max, min, floor = math.max, math.min, math.floor

local T = { instances = {} }
ns.Table = T

local ROW_TEMPLATE = "TerribleGroupFinderListRowTemplate"
local HEADER_TEMPLATE = "TerribleGroupFinderListHeaderTemplate"
local STOCK_HEADER = "LFGBrowseSearchEntryGroupingTemplate"
local HEADER_H, ROW_H = 36, 40 -- the finder's section header and result row heights
local CELL_H = 32 -- a cell's height, centred in the row
local SLOTS = 5
local RELIST_SLACK = 30 -- seconds: a listing read again later keeps its time within this
local GAP = 6
local HIDE_W, MSG_W = 20, 66
local ACTIONS_W = HIDE_W + 3 + MSG_W + 2 -- the buttons at a row's right edge
local LISTED_W = 44
local ROLES = { "TANK", "HEALER", "DAMAGER" }
local ROLE_KEY = { TANK = "tank", HEALER = "healer", DAMAGER = "dps" }
local ROLE_SHORT = { TANK = "T", HEALER = "H", DAMAGER = "D" }
local COMPOSITION = {
	[5] = { 1, 1, 3 },
	[10] = { 2, 3, 5 },
	[15] = { 2, 4, 9 },
	[20] = { 2, 5, 13 },
	[25] = { 2, 6, 17 },
	[40] = { 4, 10, 26 },
}

-- Fixed columns from the left; Activity starts after them and runs to Listed.
local LEFT = {
	{ key = "name", label = "Name", x = 4, w = 150 },
	{ key = "level", label = "Lvl", x = 156, w = 30, justify = "CENTER" },
	{ key = "role", label = "Roles", x = 190, w = 92 },
}
if ns.GEAR_SCORE then
	LEFT[#LEFT + 1] = { key = "gs", label = "GS", x = 284, w = 44, justify = "CENTER" }
end
local ACTIVITY_X = ns.GEAR_SCORE and 334 or 284
local FIRST_DESC = { level = true, gs = ns.GEAR_SCORE or nil }
-- Every cell of a row and of the header, in order.
local CELL_KEYS = {}
for _, col in ipairs(LEFT) do
	CELL_KEYS[#CELL_KEYS + 1] = col.key
end
CELL_KEYS[#CELL_KEYS + 1] = "activity"
CELL_KEYS[#CELL_KEYS + 1] = "listed"
-- Every sortable column, in header order, with its label.
local COLUMNS = {}
for _, col in ipairs(LEFT) do
	COLUMNS[#COLUMNS + 1] = col
end
COLUMNS[#COLUMNS + 1] = { key = "activity", label = "Activity" }
COLUMNS[#COLUMNS + 1] = { key = "listed", label = "Listed" }
local SORT_ARROW = "auctionhouse-ui-sortarrow"
local HEADER_BUTTON = "ColumnDisplayButtonShortTemplate"

local SECTION_LABEL = {
	solo = LFG_LIST_CATEGORY_SOLO_PLAYERS or "Solo players",
	groups = LFG_LIST_CATEGORY_GROUPS or "Groups",
}

-- Shared by every table: filters, sort and which sections are folded.
local view = {
	search = "",
	fitsRoles = false,
	sort = "role",
	desc = false,
	collapsed = {},
}

local function Size(l)
	local a = l.acts[1]
	return a and a.size or 5
end

local counts, open = {}, {}
local function Fill(members, size)
	counts.TANK, counts.HEALER, counts.DAMAGER = 0, 0, 0
	for _, m in ipairs(members) do
		if counts[m.role] then
			counts[m.role] = counts[m.role] + 1
		end
	end
	local comp = COMPOSITION[size] or COMPOSITION[size <= 5 and 5 or 40]
	for i, role in ipairs(ROLES) do
		open[role] = max(0, comp[i] - counts[role])
	end
	return counts, open
end
local function RoleCounts(l)
	return Fill(l.members, Size(l))
end

local function MyOpen()
	local _, o = Fill(ns.Party(), ns.MyListingSize())
	return o.TANK, o.HEALER, o.DAMAGER
end

local function BestRole(roles)
	if not roles then
		return 4
	end
	if roles.tank then
		return 1
	end
	if roles.healer then
		return 2
	end
	if roles.dps then
		return 3
	end
	return 4
end

-- A listing's GS: a solo player's own; a group's highest known (with whether it is outdated).
local function ListingGS(l)
	if l.solo then
		return ns.GS.Of(l.leader)
	end
	local best, stale
	for _, m in ipairs(l.members) do
		local gs, old = ns.GS.Of(m)
		if gs and (not best or gs > best) then
			best, stale = gs, old
		end
	end
	return best, stale
end

local function FitsMyRoles(l)
	if l.solo then
		local t, h, d = MyOpen()
		local r = l.leader.roles or {}
		return (r.tank and t > 0) or (r.healer and h > 0) or (r.dps and d > 0) or false
	end
	RoleCounts(l)
	local mine = ns.MyRoles()
	for _, role in ipairs(ROLES) do
		if mine[ROLE_KEY[role]] and open[role] > 0 then
			return true
		end
	end
	return false
end

local function Matches(l)
	local text = view.search
	if text == "" then
		return true
	end
	for _, m in ipairs(l.members) do
		if find(lower(m.name), text, 1, true) then
			return true
		end
	end
	if l.comment and type(l.comment) == "string" then
		local ok, hit = pcall(find, lower(l.comment), text, 1, true)
		if ok and hit then
			return true
		end
	end
	for _, a in ipairs(l.acts) do
		if find(lower(a.name), text, 1, true) then
			return true
		end
	end
	return false
end

local function IsHidden(l)
	local at = ns.state.hidden[l.leader.name]
	return at ~= nil and l.listedAt <= at + RELIST_SLACK
end

-- Greyed and moved to the end of its section: hidden, delisted, or no slot for you.
local function Demoted(l)
	return IsHidden(l) or l.delisted or (view.fitsRoles and not FitsMyRoles(l)) or false
end

local VALUES = {
	name = function(l)
		return lower(l.leader.name)
	end,
	level = function(l)
		return l.leader.level
	end,
	role = function(l)
		if l.solo then
			return BestRole(l.leader.roles)
		end
		return (FitsMyRoles(l) and 0 or 100) - #l.members
	end,
	activity = function(l)
		return l.acts[1] and lower(l.acts[1].name) or ""
	end,
	listed = function(l)
		return l.age
	end,
}
if ns.GEAR_SCORE then
	VALUES.gs = function(l)
		return (ListingGS(l))
	end
end

local function Compare(a, b)
	if a.demoted ~= b.demoted then
		return b.demoted
	end
	local f = VALUES[view.sort]
	local va, vb = f(a), f(b)
	if va ~= vb then
		if va == nil then
			return false
		end
		if vb == nil then
			return true
		end
		if view.desc then
			return va > vb
		end
		return va < vb
	end
	if view.sort ~= "role" and a.solo then
		local ra, rb = BestRole(a.leader.roles), BestRole(b.leader.roles)
		if ra ~= rb then
			return ra < rb
		end
	end
	if a.leader.level ~= b.leader.level then
		return a.leader.level > b.leader.level
	end
	return a.age < b.age
end

local function ActivityText(l)
	local a = l.acts[1]
	local text = a and a.name or "?"
	if #l.acts > 1 then
		text = text .. format(" |cff999999+%d|r", #l.acts - 1)
	end
	return text
end

local function Ago(at)
	if not at then
		return ""
	end
	local days = math.floor((time() - at) / 86400)
	if days < 1 then
		return "earlier today"
	end
	return days == 1 and "a day ago" or (days .. " days ago")
end

local function GSLine(m)
	local gs, stale = ns.GS.Of(m)
	if not gs then
		return W.GS(nil)
	end
	local text = W.GS(gs, m.level, stale)
	if stale then
		local _, _, _, at = ns.GS.Lookup(m.name)
		text = text .. (at and (" |cff999999(" .. Ago(at) .. ")|r") or " |cff999999(outdated)|r")
	end
	return text
end

local function FriendsLine(l)
	local names = {}
	for _, m in ipairs(l.members) do
		local color = W.FriendColor(m)
		if color then
			names[#names + 1] = color .. m.name .. "|r"
		end
	end
	return #names > 0 and table.concat(names, ", ") or nil
end

local function ShowTooltip(row)
	local l = row.listing
	if not l then
		return
	end
	GameTooltip:SetOwner(row, "ANCHOR_RIGHT")
	GameTooltip:SetText(l.acts[1] and l.acts[1].name or "?", 1, 0.82, 0)
	for i = 2, #l.acts do
		GameTooltip:AddLine("  " .. l.acts[i].name, 0.8, 0.8, 0.8)
	end
	if l.delisted then
		GameTooltip:AddLine(LFG_LIST_ENTRY_DELISTED or "Delisted", 1, 0.2, 0.2)
	end
	if l.newPlayerFriendly then
		GameTooltip:AddLine(
			W.Icon("newPlayer") .. " " .. (LFG_LIST_NEW_PLAYER_FRIENDLY_HEADER or "New player friendly"),
			0.3,
			1,
			0.3
		)
	end
	if l.comment then
		GameTooltip:AddLine(l.comment, 0.6, 0.6, 0.6, true)
	end
	GameTooltip:AddLine(" ")
	if l.solo then
		local who = l.leader
		local left = W.Colored(who.class, who.name)
			.. W.Marks(who)
			.. format("  level %d %s", who.level, W.ClassName(who.class))
		if ns.GEAR_SCORE then
			GameTooltip:AddDoubleLine(left, "GS " .. GSLine(who))
		else
			GameTooltip:AddLine(left)
		end
		local where = (who.spec and (who.spec .. (who.area and ", " or "")) or "") .. (who.area or "")
		if where ~= "" then
			GameTooltip:AddLine(where, 0.8, 0.8, 0.8)
		end
		local roles = {}
		for _, role in ipairs(ROLES) do
			if who.roles and who.roles[ROLE_KEY[role]] then
				roles[#roles + 1] = W.ROLE_NAME[role]
			end
		end
		GameTooltip:AddLine("Can play: " .. table.concat(roles, ", "), 0.8, 0.8, 0.8)
	else
		RoleCounts(l)
		GameTooltip:AddLine(format("Members: %d/%d", #l.members, Size(l)), 1, 1, 1)
		local limit = min(#l.members, 12)
		for i = 1, limit do
			local m = l.members[i]
			local left = (m.leader and "* " or "  ")
				.. W.Colored(m.class, m.name)
				.. W.Marks(m)
				.. format(" |cff999999%d %s|r", m.level, W.ROLE_NAME[m.role])
			if ns.GEAR_SCORE then
				GameTooltip:AddDoubleLine(left, GSLine(m))
			else
				GameTooltip:AddLine(left)
			end
		end
		if #l.members > limit then
			GameTooltip:AddLine(format("  ... and %d more", #l.members - limit), 0.6, 0.6, 0.6)
		end
		local needs = {}
		for _, role in ipairs(ROLES) do
			if open[role] > 0 then
				needs[#needs + 1] = open[role] .. " " .. W.ROLE_NAME[role]
			end
		end
		if #needs > 0 then
			GameTooltip:AddLine("Looking for: " .. table.concat(needs, ", "), 0.3, 1, 0.3)
		end
	end
	local friends = FriendsLine(l)
	if friends then
		GameTooltip:AddLine(" ")
		GameTooltip:AddLine(LFG_LIST_TOOLTIP_FRIENDS_IN_GROUP or "Friends in group:")
		GameTooltip:AddLine(friends, 1, 1, 1, true)
	end
	GameTooltip:AddLine(" ")
	local flags = { "Listed " .. W.Age(l.age) .. " ago" }
	if l.voice then
		flags[#flags + 1] = W.Icon("voice") .. " voice chat"
	end
	GameTooltip:AddLine(table.concat(flags, ", "), 0.6, 0.6, 0.6)
	if IsHidden(l) then
		GameTooltip:AddLine("Hidden until they make a new listing (+ to show).", 0.6, 0.6, 0.6, true)
	end
	GameTooltip:Show()
end

local function Hide(l)
	local hidden = ns.state.hidden
	if IsHidden(l) then
		hidden[l.leader.name] = nil
	else
		hidden[l.leader.name] = l.listedAt
	end
	W.PlayCheckbox(true)
	T.RefreshAll()
end

local Instance = {}
Instance.__index = Instance

-- Selection is the listing's id, never a table: it survives re-sorts and re-reads.
local function IsSelected(inst, item)
	return inst.selectedID ~= nil and item.id == inst.selectedID
end

-- The read's listing with this id (folded away or filtered out ones too), else nil.
local function FindByID(inst, id)
	return id ~= nil and inst.byID[id] or nil
end

-- The selected listing while its row is shown, else nil: a selection folded away or
-- filtered out is kept, but nothing acts on a listing you can't see.
local function ShownSelection(inst)
	local id = inst.selectedID
	return id ~= nil and inst.shownIDs[id] and FindByID(inst, id) or nil
end

local function TemplateKnown(name)
	return C_XMLUtil ~= nil and C_XMLUtil.GetTemplateInfo ~= nil and C_XMLUtil.GetTemplateInfo(name) ~= nil
end

local function Gray(text)
	local c = GRAY_FONT_COLOR
	if c and c.WrapTextInColorCode then
		return c:WrapTextInColorCode(text)
	end
	c = c or { r = 0.5, g = 0.5, b = 0.5 }
	return format("|cff%02x%02x%02x%s|r", floor(c.r * 255 + 0.5), floor(c.g * 255 + 0.5), floor(c.b * 255 + 0.5), text)
end

-- The row's message button: whisper the player or the group's leader (Messages.lua), or
-- unlist your own listing.
function Instance:Message(l)
	if not l then
		return
	end
	local preview = self.source.preview()
	if l.mine then
		if preview then
			ns.state.myListing = nil
			ns.Print("preview: unlisted (C_LFGList.RemoveListing).")
		else
			C_LFGList.RemoveListing()
		end
	else
		ns.Messages.Send(l, preview)
	end
	T.RefreshAll()
end

-- Forever's Group Invite: solo players only.
function Instance:Invite(l)
	if not (l and l.solo and not l.mine) then
		return
	end
	ns.state.invited[l.id] = true
	if self.source.preview() then
		ns.Print(format("preview: would invite %s (C_PartyInfo.InviteUnit).", l.leader.name))
	else
		C_PartyInfo.InviteUnit(l.leader.fullName or l.leader.name)
	end
	T.RefreshAll()
end

local function SetRoles(row, l)
	for _, s in ipairs(row.slots) do
		s:Hide()
	end
	row.count:SetText("")
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
	RoleCounts(l)
	local size = Size(l)
	if size <= SLOTS then
		local i = 0
		for _, role in ipairs(ROLES) do
			for _ = 1, counts[role] do
				i = i + 1
				if row.slots[i] then
					row.slots[i]:SetRole(role)
				end
			end
		end
		for j = i + 1, size do
			row.slots[j]:SetRole(nil)
		end
		for j = 1, size do
			row.slots[j]:Show()
		end
	else
		local parts = {}
		for _, role in ipairs(ROLES) do
			parts[#parts + 1] = ROLE_SHORT[role] .. counts[role]
		end
		row.count:SetText(format("%d/%d |cff999999%s|r", #l.members, size, table.concat(parts, " ")))
	end
end

-- Lays out the cells of a row (or the header): fixed ones from the left, Listed against
-- the right-hand buttons (or the spot they take), Activity between.
local function Layout(owner, cells, rightAnchor, rightOffset)
	for _, col in ipairs(LEFT) do
		local cell = cells[col.key]
		cell:ClearAllPoints()
		cell:SetPoint("LEFT", owner, "LEFT", col.x, 0)
		cell:SetWidth(col.w)
	end
	cells.listed:ClearAllPoints()
	cells.listed:SetPoint("RIGHT", rightAnchor, rightAnchor == owner and "RIGHT" or "LEFT", rightOffset, 0)
	cells.listed:SetWidth(LISTED_W)
	cells.activity:ClearAllPoints()
	cells.activity:SetPoint("LEFT", owner, "LEFT", ACTIVITY_X, 0)
	cells.activity:SetPoint("RIGHT", cells.listed, "LEFT", -GAP, 0)
end

-- Builds a result row once, on a frame the list gave us.
function Instance:BuildRow(row)
	local inst = self
	-- Forever's row art: mid2 background, additive hover, additive selected on top. FillRow
	-- picks the atlases (your own listing has its own pair).
	row.bg = row:CreateTexture(nil, "BACKGROUND")
	row.bg:SetPoint("TOPLEFT", 3, -2)
	row.bg:SetPoint("BOTTOMRIGHT", -3, 0)
	row.hover = row:CreateTexture(nil, "HIGHLIGHT")
	row.hover:SetPoint("TOPLEFT", 3, -3)
	row.hover:SetPoint("BOTTOMRIGHT", -3, -1)
	row.hover:SetBlendMode("ADD")
	row.selected = row:CreateTexture(nil, "OVERLAY")
	row.selected:SetPoint("TOPLEFT", 3, -3)
	row.selected:SetPoint("BOTTOMRIGHT", -3, -1)
	row.selected:SetBlendMode("ADD")
	row.selected:Hide()

	-- Each cell holds its texts; Layout anchors the cells.
	local cells = {}
	for _, key in ipairs(CELL_KEYS) do
		local cell = CreateFrame("Frame", nil, row)
		cell:SetHeight(CELL_H)
		cells[key] = cell
	end
	row.cells = cells
	row.icon = W.ClassIcon(cells.name, 16)
	row.icon:SetPoint("TOPLEFT", 0, -3)
	row.name = W.Text(cells.name, "GameFontNormal", 12)
	row.name:SetPoint("TOPLEFT", 20, -4)
	row.name:SetPoint("RIGHT", 0, 0)
	row.sub = W.Text(cells.name, "GameFontDisableSmall", 10)
	row.sub:SetPoint("TOPLEFT", 0, -19)
	row.sub:SetPoint("RIGHT", 0, 0)
	row.level = W.Text(cells.level, "GameFontDisable", 12, "CENTER")
	row.level:SetAllPoints()
	row.slots = {}
	for i = 1, SLOTS do
		local slot = W.RoleIcon(cells.role, 14)
		slot:SetPoint("LEFT", (i - 1) * 15, 0)
		row.slots[i] = slot
	end
	row.count = W.Text(cells.role, "GameFontHighlightSmall", 11)
	row.count:SetAllPoints()
	if cells.gs then
		row.gs = W.Text(cells.gs, "GameFontHighlight", 12, "CENTER")
		row.gs:SetAllPoints()
	end
	row.activity = W.Text(cells.activity, "GameFontHighlightSmall", 11)
	row.activity:SetPoint("TOPLEFT", 0, -4)
	row.activity:SetPoint("RIGHT", 0, 0)
	row.comment = W.Text(cells.activity, "GameFontDisableSmall", 10)
	row.comment:SetPoint("TOPLEFT", 0, -19)
	row.comment:SetPoint("RIGHT", 0, 0)
	row.listed = W.Text(cells.listed, "GameFontDisableSmall", 10, "RIGHT")
	row.listed:SetAllPoints()
	-- What these texts look like on a normal row, put back on every fill.
	for _, fs in ipairs({ row.sub, row.count, row.comment, row.listed, row.gs or row.count }) do
		fs.__tgfColor = { fs:GetTextColor() }
	end

	row.hide = W.Button(row, "x", HIDE_W, 20, function(b)
		Hide(b:GetParent().listing)
	end)
	row.hide:SetPoint("RIGHT", -2, 0)
	row.message = W.Button(row, "Whisper", MSG_W, 20, function(b)
		inst:Message(b:GetParent().listing)
	end)
	row.message:SetPoint("RIGHT", row.hide, "LEFT", -3, 0)
	Layout(row, cells, row.message, -GAP)

	row:RegisterForClicks("LeftButtonUp")
	row:SetScript("OnClick", function(r)
		local l = r.listing
		if not l or l.mine or l.delisted then
			return
		end
		if inst.selectedID == l.id then
			inst.selectedID = nil
		else
			inst.selectedID = l.id
		end
		W.PlayCheckbox(true)
		inst:RefreshButtons()
		inst.list:Reinitialize()
	end)
	row:SetScript("OnEnter", ShowTooltip)
	row:SetScript("OnLeave", function()
		GameTooltip:Hide()
	end)
	W.Tooltip(row.hide, "Hide", "Greys this player and moves them to the end until they make a new listing.")
end

-- Builds a section header once. Forever's grouping template brings its own parts; otherwise
-- the same ones are built here. Hovering brightens only the header's own atlas: no row
-- highlight, no selected texture.
local function HeaderIcon(frame, atlas, text)
	if W.HasAtlas(atlas) then
		local tex = frame:CreateTexture(nil, "ARTWORK")
		tex:SetAtlas(atlas, true)
		tex:SetPoint("RIGHT", -12, -5)
		return tex
	end
	local fs = W.Text(frame, "GameFontNormal", 14, "RIGHT")
	fs:SetWidth(20)
	fs:SetPoint("RIGHT", -12, -5)
	fs:SetText(text)
	return fs
end

function Instance:BuildHeader(frame)
	if not frame.ResultBG then
		frame.ResultBG = frame:CreateTexture(nil, "BACKGROUND")
		frame.ResultBG:SetPoint("TOPLEFT", 3, -8)
		frame.ResultBG:SetPoint("BOTTOMRIGHT", -3, 0)
		W.Atlas(frame.ResultBG, "common-button-list-collapseExpand", 0.2, 0.17, 0.12, 0.9)
		frame.CategoryLabel = W.Text(frame, "GameFontNormal", 12)
		frame.CategoryLabel:SetWidth(300)
		frame.CategoryLabel:SetPoint("LEFT", 12, -4)
		frame.ExpandIcon = HeaderIcon(frame, "common-button-list-plus", "+")
		frame.CollapseIcon = HeaderIcon(frame, "common-button-list-minus", "-")
		frame.Highlight = frame:CreateTexture(nil, "HIGHLIGHT")
		frame.Highlight:SetPoint("TOPLEFT", 3, -7)
		frame.Highlight:SetPoint("BOTTOMRIGHT", -3, -1)
		W.Atlas(frame.Highlight, "common-button-list-collapseExpand", 1, 1, 1, 0.08)
		frame.Highlight:SetBlendMode("ADD")
	end
	frame:SetScript("OnClick", function(f)
		local key = f.item and f.item.key
		if key then
			view.collapsed[key] = not view.collapsed[key] or nil
			T.RefreshAll()
		end
	end)
end

function Instance:FillHeader(frame, item)
	frame.item = item
	frame.CategoryLabel:SetText(format("%s %s", SECTION_LABEL[item.key], Gray("(" .. item.count .. ")")))
	local collapsed = view.collapsed[item.key] == true
	frame.ExpandIcon:SetShown(collapsed)
	frame.CollapseIcon:SetShown(not collapsed)
end

-- The activity ids of your active listing (a set), read once per refresh: in the game from
-- C_LFGList (nil or secret under lockdown reads as none), in the preview from the sample one.
local function ActiveActivityIDs(inst)
	local ids = {}
	if inst.source.preview() then
		local mine = ns.state.myListing
		for _, key in ipairs(mine and mine.activities or {}) do
			ids[key] = true
		end
		return ids
	end
	local info = C_LFGList and C_LFGList.GetActiveEntryInfo and C_LFGList.GetActiveEntryInfo()
	if type(info) ~= "table" or (issecretvalue and issecretvalue(info)) then
		return ids
	end
	local list = info.activityIDs
	if type(list) ~= "table" or (issecretvalue and issecretvalue(list)) then
		return ids
	end
	for _, id in ipairs(list) do
		if not (issecretvalue and issecretvalue(id)) then
			ids[id] = true
		end
	end
	return ids
end

-- Text without colour codes, so a greyed row's own colour shows through.
local function Plain(text)
	return (text:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""))
end

local function MatchesActive(inst, l)
	local ids = inst.activeIDs
	if not ids then
		return false
	end
	for _, a in ipairs(l.acts) do
		if ids[a.key] then
			return true
		end
	end
	return false
end

function Instance:FillRow(row, item)
	row.item = item
	local l = item
	row.listing = l
	local greyed = l.demoted == true

	-- Art: your own listing has the highlight bar pair, the others Forever's list buttons.
	if l.mine then
		W.Atlas(row.bg, "groupfinder-highlightbar", 0.1, 0.1, 0.1, 0.5)
		W.Atlas(row.hover, "groupfinder-highlightbar-blue", 0.3, 0.5, 1, 0.12)
	else
		W.Atlas(row.bg, "common-button-list-mid2", 0.1, 0.1, 0.1, 0.5)
		W.Atlas(row.hover, "common-button-list-mid2-hover", 0.3, 0.5, 1, 0.12)
	end
	W.Atlas(row.selected, "common-button-list-mid2-selected", 1, 0.82, 0, 0.12)

	-- The icon: groups show the leader icon at its atlas size, solo players their class.
	local who = l.leader
	if not l.solo and W.HasAtlas("groupfinder-icon-leader") then
		row.icon:SetAtlas("groupfinder-icon-leader", true)
		row.icon:SetVertexColor(1, 1, 1, 1)
	else
		row.icon:SetSize(16, 16)
		row.icon:SetClass(who.class)
	end
	row.icon:SetDesaturated(greyed)
	local tags = ""
	if l.newPlayerFriendly then
		tags = tags .. " " .. W.Icon("newPlayer")
	end
	if l.voice then
		tags = tags .. " " .. W.Icon("voice")
	end
	if not l.solo and FriendsLine(l) and not (who.bnet or who.friend or who.recent) then
		tags = tags .. " " .. W.Icon("friendsIn")
	end
	row.name:SetText(who.name .. W.Marks(who) .. (l.mine and " |cff33ff33(you)|r" or "") .. tags)
	if l.solo then
		row.sub:SetText(who.spec or W.ClassName(who.class))
	else
		row.sub:SetText(format("%d/%d members", #l.members, Size(l)))
	end
	if row.gs then
		local gs, stale = ListingGS(l)
		local text = W.GS(gs, who.level, stale)
		row.gs:SetText(greyed and Plain(text) or text)
	end
	row.level:SetText(who.level)
	SetRoles(row, l)
	if greyed then
		row.count:SetText(Plain(row.count:GetText() or ""))
	end
	row.activity:SetText(ActivityText(l))
	row.comment:SetText(l.comment or "")

	local hidden = IsHidden(l)
	local listed
	if l.delisted then
		listed = greyed and "delisted" or "|cffff3333delisted|r"
	elseif ns.state.invited[l.id] then
		listed = greyed and "invited" or "|cff33ff33invited|r"
	elseif ns.state.messaged[l.id] then
		listed = greyed and "sent" or "|cff33ff33sent|r"
	else
		listed = W.Age(l.age)
	end
	row.listed:SetText(listed)

	-- Colours, set on every fill: the frames are reused. Greyed rows take Forever's delisted
	-- grey on all text (class-coloured name included) and desaturated icons.
	local texts = { row.name, row.level, row.activity, row.sub, row.count, row.comment, row.listed, row.gs }
	if greyed then
		for _, fs in pairs(texts) do
			W.SetColor(fs, W.DELISTED)
		end
	else
		local r, g, b = W.ClassColor(who.class)
		row.name:SetTextColor(r, g, b)
		W.SetColor(row.level, W.GRAY)
		W.SetColor(row.activity, MatchesActive(self, l) and W.BRIGHTBLUE or W.GRAY)
		for _, fs in ipairs({ row.sub, row.count, row.comment, row.listed, row.gs or row.count }) do
			local c = fs.__tgfColor
			if c and c[1] then
				fs:SetTextColor(c[1], c[2], c[3])
			end
		end
	end
	for _, slot in ipairs(row.slots) do
		slot.tex:SetDesaturated(greyed)
		slot:SetAlpha(greyed and 0.5 or 1)
	end
	for _, cell in pairs(row.cells) do
		cell:SetAlpha(1)
	end

	row.selected:SetShown(IsSelected(self, l))
	row.hide:SetShown(not l.mine)
	row.hide:SetText(hidden and "+" or "x")
	row.message:SetText(l.mine and "Unlist" or "Whisper")
	row.message:SetEnabled(l.mine or not l.delisted)
end

local sections = { solo = {}, groups = {} }
function Instance:Collect()
	local items = self.items
	wipe(items)
	wipe(sections.solo)
	wipe(sections.groups)
	local mine
	wipe(self.byID)
	wipe(self.shownIDs)
	for _, l in ipairs(self.source.listings()) do
		if l.id ~= nil and not l.mine then
			self.byID[l.id] = l
		end
		if l.mine then
			mine = l
		elseif Matches(l) then
			l.demoted = Demoted(l)
			local list = sections[l.solo and "solo" or "groups"]
			list[#list + 1] = l
		end
	end
	if mine then
		mine.demoted = false
		items[1] = mine
	end
	-- Forever's order: groups first while you're solo, solo players first while you lead.
	local order = ns.IsLeader() and { "solo", "groups" } or { "groups", "solo" }
	for _, key in ipairs(order) do
		local list = sections[key]
		table.sort(list, Compare)
		if #list > 0 then
			local header = self.headers[key]
			header.count = #list
			items[#items + 1] = header
			if not view.collapsed[key] then
				for _, l in ipairs(list) do
					items[#items + 1] = l
					if l.id ~= nil then
						self.shownIDs[l.id] = true
					end
				end
			end
		end
	end
	return #sections.solo, #sections.groups
end

function Instance:Refresh()
	if not self.band:IsVisible() then
		return
	end
	self.fits:SetChecked(view.fitsRoles)
	local useArrow = W.HasAtlas(SORT_ARROW)
	for _, col in ipairs(COLUMNS) do
		local b = self.header[col.key]
		local sorted = view.sort == col.key
		b:SetText(col.label .. (sorted and not useArrow and (view.desc and " v" or " ^") or ""))
		if b.arrow then
			b.arrow:SetShown(sorted)
			if sorted then
				if view.desc then
					b.arrow:SetTexCoord(0, 1, 0, 1)
				else
					b.arrow:SetTexCoord(0, 1, 1, 0)
				end
			end
		end
	end
	if self.source.searching and self.source.searching() then
		self.list:Clear()
		self.spinner:Show()
		self.stateText:SetText("")
		self:RefreshButtons()
		return
	end
	self.spinner:Hide()
	-- A failed search shows only its text, as Forever's list does: no rows, no selection.
	if self.source.failed and self.source.failed() then
		self.list:Clear()
		self.selectedID = nil
		self.stateText:SetText(LFG_LIST_SEARCH_FAILED or "Search failed.")
		self.status:SetText("")
		self:RefreshButtons()
		return
	end
	self.activeIDs = ActiveActivityIDs(self)
	local solo, groups = self:Collect()
	-- Drop a gone or delisted selection before the rows are filled, so no row draws it.
	self:ValidateSelection()
	self.list:SetItems(self.items)
	local found = 0
	for _, l in ipairs(self.source.listings()) do
		if not l.mine then
			found = found + 1
		end
	end
	local state = ""
	if found == 0 then
		state = LFG_LIST_NO_RESULTS_FOUND or "No results found."
	elseif view.search ~= "" and solo + groups == 0 then
		state = "No listings match your search."
	end
	self.stateText:SetText(state)
	self.status:SetText(format("%d solo players, %d groups", solo, groups))
	if self.myGS then
		local gs, stale = ns.GS.Of(ns.Me())
		self.myGS:SetText("Your GS " .. W.GS(gs, ns.PlayerLevel(), stale))
	end
	self:RefreshButtons()
end

-- Drops a selection whose listing is gone or delisted; returns the selected listing, if any.
function Instance:ValidateSelection()
	local sel = FindByID(self, self.selectedID)
	if self.selectedID and (not sel or sel.delisted) then
		self.selectedID, sel = nil, nil
	end
	return sel
end

-- The bottom buttons act on the listing the selected id resolves to, while its row is shown.
function Instance:RefreshButtons()
	self:ValidateSelection()
	local sel = ShownSelection(self)
	self.send:SetEnabled(sel ~= nil)
	self.invite:SetEnabled(sel ~= nil and sel.solo == true and ns.CanInvite())
end

-- The list host: Blizzard's ScrollBox (our scriptless templates keep header and row frames in
-- separate pools) where the API and the templates exist, else W.List with the same items.
function Instance:BuildList(back, placeStrip)
	local headerTemplate = TemplateKnown(STOCK_HEADER) and STOCK_HEADER or HEADER_TEMPLATE
	local function Init(frame, item)
		if item.header then
			if not frame.tgfBuilt then
				self:BuildHeader(frame)
				frame.tgfBuilt = true
			end
			self:FillHeader(frame, item)
		else
			if not frame.tgfBuilt then
				self:BuildRow(frame)
				frame.tgfBuilt = true
			end
			self:FillRow(frame, item)
		end
	end

	if
		CreateScrollBoxListLinearView
		and CreateDataProvider
		and CreateAnchor
		and ScrollUtil
		and ScrollUtil.InitScrollBoxListWithScrollBar
		and ScrollUtil.AddManagedScrollBarVisibilityBehavior
		and ScrollBoxConstants
		and TemplateKnown(ROW_TEMPLATE)
		and TemplateKnown(HEADER_TEMPLATE)
	then
		local box = W.Create("Frame", back, "WowScrollBoxList")
		local bar = W.Create("EventFrame", back, "MinimalScrollBar")
		if box.SetDataProvider and bar.Init then
			local view = CreateScrollBoxListLinearView()
			view:SetElementFactory(function(factory, item)
				factory(item.header and headerTemplate or ROW_TEMPLATE, Init)
			end)
			view:SetElementExtentCalculator(function(_, item)
				return item.header and HEADER_H or ROW_H
			end)
			view:SetElementResetter(function(frame)
				if GameTooltip:GetOwner() == frame then
					GameTooltip:Hide()
				end
			end)
			box:SetPoint("TOPLEFT", back, "TOPLEFT", 3, -6)
			box:SetPoint("BOTTOMRIGHT", back, "BOTTOMRIGHT", -22, 2)
			bar:SetPoint("TOPLEFT", box, "TOPRIGHT", 2, -4)
			bar:SetPoint("BOTTOMLEFT", box, "BOTTOMRIGHT", 0, 2)
			ScrollUtil.InitScrollBoxListWithScrollBar(box, bar, view)
			local topLeft = CreateAnchor("TOPLEFT", back, "TOPLEFT", 3, -6)
			local withBar = { topLeft, CreateAnchor("BOTTOMRIGHT", back, "BOTTOMRIGHT", -22, 2) }
			local withoutBar = { topLeft, CreateAnchor("BOTTOMRIGHT", back, "BOTTOMRIGHT", -6, 2) }
			local behavior = ScrollUtil.AddManagedScrollBarVisibilityBehavior(box, bar, withBar, withoutBar)
			-- The column header strip keeps lining up with the rows when the bar shows.
			local event = ManagedScrollBarVisibilityBehaviorMixin
				and ManagedScrollBarVisibilityBehaviorMixin.Event
				and ManagedScrollBarVisibilityBehaviorMixin.Event.OnVisibilityChanged
			if behavior and behavior.RegisterCallback and event then
				behavior:RegisterCallback(event, function(_, visible)
					placeStrip(visible)
				end, self)
			end

			local host = { box = box, bar = bar }
			function host:SetItems(items)
				local dp = CreateDataProvider()
				dp:InsertTable(items)
				box:SetDataProvider(dp, ScrollBoxConstants.RetainScrollPosition)
			end
			function host:Clear()
				box:RemoveDataProvider()
			end
			function host:Reinitialize()
				box:ReinitializeFrames()
			end
			function host:ForEachFrame(fn)
				box:ForEachFrame(fn)
			end
			return host
		end
		box:Hide()
		bar:Hide()
	end

	local list = W.List(back, {
		header = {
			height = HEADER_H,
			make = function(l)
				local frame = CreateFrame("Button", nil, l)
				self:BuildHeader(frame)
				return frame
			end,
		},
		row = {
			height = ROW_H,
			make = function(l)
				local frame = CreateFrame("Button", nil, l)
				self:BuildRow(frame)
				return frame
			end,
		},
	}, function(item)
		return item.header and "header" or "row"
	end, function(frame, item)
		if item.header then
			self:FillHeader(frame, item)
		else
			self:FillRow(frame, item)
		end
	end)
	list:SetPoint("TOPLEFT", back, "TOPLEFT", 3, -6)
	list:SetPoint("BOTTOMRIGHT", back, "BOTTOMRIGHT", -6, 2)
	-- W.List's frames end 8 px in from its right edge (room for its thumb): the header strip
	-- ends there too.
	placeStrip(false, -14)
	return list
end

--- Builds a table filling `area` (the Browse frame's list area), with its bottom buttons on
--- `host`. source: listings() -> the listings to show; preview() -> true for sample data;
--- searching() -> true while a search runs.
function T.Attach(host, area, source)
	local self = setmetatable({
		host = host,
		source = source,
		items = {},
		byID = {},
		shownIDs = {},
		headers = { solo = { header = true, key = "solo" }, groups = { header = true, key = "groups" } },
	}, Instance)

	-- A one pixel helper at the top of the list area: it only tells us when Browse shows, and
	-- never takes the mouse (Blizzard's dropdowns sit above it).
	local band = CreateFrame("Frame", nil, host)
	band:SetPoint("TOPLEFT", area, "TOPLEFT", 0, 0)
	band:SetPoint("TOPRIGHT", area, "TOPRIGHT", 0, 0)
	band:SetHeight(1)
	self.band = band

	-- Needs my role sits in the bottom bar, just right of Send Message (placed below).
	self.fits = W.Check(host, "Needs my role", function(b)
		view.fitsRoles = b:GetChecked() and true or false
		T.RefreshAll()
	end)
	W.Tooltip(
		self.fits,
		"Needs my role",
		"Moves to the end (greyed) groups with no open slot for a role you play, and solo players who can't fill a slot your group has open."
	)
	-- The search box sits in the stone band, right of the refresh button and before the
	-- options gear; without the button it hangs at the host's top right, leaving room for it.
	local search = W.EditBox(host, 150, "SearchBoxTemplate")
	if source.refreshAnchor then
		search:SetPoint("LEFT", source.refreshAnchor, "RIGHT", 10, 0)
	else
		search:SetPoint("TOPRIGHT", host, "TOPRIGHT", -48, -38)
	end
	if search.Instructions then
		search.Instructions:SetText("Name, activity or note")
	end
	search:HookScript("OnTextChanged", function(b)
		view.search = lower(b:GetText() or "")
		T.RefreshAll()
	end)
	self.search = search
	if ns.GEAR_SCORE then
		self.myGS = W.Text(host, "GameFontNormal", 12, "RIGHT")
		local gsHover = CreateFrame("Frame", nil, host)
		gsHover:SetAllPoints(self.myGS)
		gsHover:EnableMouse(true)
		W.Tooltip(
			gsHover,
			"Your gear score",
			"Item level of your gear, adjusted for quality, on the same scale as the GS column."
		)
	end

	-- A backing for the list so nothing of the frame's own list takes the mouse through; it
	-- draws nothing (the frame's art is behind it) and starts just below BarTop (art top -20).
	local back = CreateFrame("Frame", nil, host)
	back:SetPoint("TOPLEFT", area, "TOPLEFT", 0, -20)
	back:SetPoint("BOTTOMRIGHT", area, "BOTTOMRIGHT", 0, 60)
	back:EnableMouse(true)

	-- The column header strip: the 20 px from the art top down to BarTop. Its right edge
	-- follows the rows' (-22 with the scroll bar, -6 without; the fallback list passes its own).
	local header = CreateFrame("Frame", nil, host)
	header:SetHeight(20)
	local function PlaceStrip(barShown, inset)
		header:ClearAllPoints()
		header:SetPoint("TOPLEFT", area, "TOPLEFT", 3, 0)
		header:SetPoint("TOPRIGHT", area, "TOPRIGHT", inset or (barShown and -22 or -6), 0)
	end
	PlaceStrip(false)
	local justify = { level = "CENTER", gs = "CENTER", listed = "RIGHT" }
	for _, key in ipairs(CELL_KEYS) do
		local b = W.Create("Button", header, HEADER_BUTTON)
		b:SetHeight(19)
		local j = justify[key] or "LEFT"
		local text = b.Text
		if text then
			-- Inset 4 px from the edge the text is justified to, so it stays inside its column.
			text:ClearAllPoints()
			text:SetPoint(j, b, j, (j == "CENTER" and 0) or (j == "RIGHT" and -4) or 4, 0)
			text:SetJustifyH(j)
		else
			text = W.Text(b, "GameFontNormalSmall", 11, justify[key])
			text:SetAllPoints()
			local hl = b:CreateTexture(nil, "HIGHLIGHT")
			hl:SetAllPoints()
			hl:SetColorTexture(1, 1, 1, 0.08)
		end
		if W.HasAtlas(SORT_ARROW) then
			local arrow = b:CreateTexture(nil, "OVERLAY")
			arrow:SetAtlas(SORT_ARROW, true)
			if b.Text and j == "RIGHT" then
				-- Right-justified labels end at the column's edge: the arrow goes before them.
				arrow:SetPoint("RIGHT", text, "LEFT", -3, 0)
			elseif b.Text then
				arrow:SetPoint("LEFT", text, "RIGHT", 3, 0)
			else
				arrow:SetPoint("RIGHT", b, "RIGHT", -2, 0)
			end
			arrow:Hide()
			b.arrow = arrow
		end
		b:SetScript("OnClick", function()
			if view.sort == key then
				view.desc = not view.desc
			else
				view.sort, view.desc = key, FIRST_DESC[key] == true
			end
			T.RefreshAll()
		end)
		function b:SetText(t)
			text:SetText(t)
		end
		header[key] = b
	end
	-- The header's columns line up with the rows': the rows' buttons take ACTIONS_W.
	Layout(header, header, header, -(ACTIONS_W + GAP))
	W.Tooltip(
		header.role,
		"Roles",
		"Solo players: tank, then healer, then damage. Groups: open slots for your roles first."
	)
	if header.gs then
		W.Tooltip(
			header.gs,
			"Gear score",
			"Item level of the gear, adjusted for quality. Groups show their best known. "
				.. W.GS_OUTDATED
				.. "This colour|r: known from an earlier session; a ready check refreshes your group's."
		)
	end
	self.header = header

	self.list = self:BuildList(back, PlaceStrip)

	-- Forever's own bottom buttons sit at these spots.
	self.send = W.Button(host, SEND_MESSAGE or "Send Message", 111, 28, function()
		self:Message(ShownSelection(self))
	end)
	self.send:SetPoint("BOTTOMLEFT", 21, 16)
	self.invite = W.Button(host, GROUP_INVITE or "Group Invite", 109, 28, function()
		self:Invite(ShownSelection(self))
	end)
	self.invite:SetPoint("BOTTOMRIGHT", -21, 16)
	self.fits:SetPoint("LEFT", self.send, "RIGHT", 8, 0)
	self.status = W.Text(host, "GameFontHighlightSmall", 11, "RIGHT")
	self.status:SetPoint("RIGHT", self.invite, "LEFT", -8, 0)
	self.status:SetPoint("LEFT", self.fits.Label, "RIGHT", 8, 0)
	if self.myGS then
		self.myGS:SetPoint("RIGHT", self.status, "LEFT", -12, 0)
	end

	-- What the list can't show: the spinner while searching, and the no-results, failed and
	-- nothing-matches texts (stock puts them at the art's top, 240 wide).
	self.stateText = W.Text(host, "GameFontDisable", 12, "CENTER")
	self.stateText:SetWidth(240)
	self.stateText:SetWordWrap(true)
	self.stateText:SetPoint("TOP", area, "TOP", 0, -40)
	self.spinner = W.Create("Frame", host, "LoadingSpinnerTemplate")
	self.spinner:SetSize(48, 48)
	self.spinner:SetPoint("CENTER", area, "CENTER", 0, 0)
	self.spinner:Hide()
	self.spinnerLabel = self.spinner:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
	self.spinnerLabel:SetPoint("BOTTOM", self.spinner, "TOP", 0, 6)
	self.spinnerLabel:SetText(SEARCHING or "Searching")

	band:SetScript("OnShow", function()
		self:Refresh()
	end)
	T.instances[#T.instances + 1] = self
	return self
end

--- Drops every table's selection (new results, a new search, Browse shown again) and redraws.
function T.ClearSelection()
	for _, inst in ipairs(T.instances) do
		inst.selectedID = nil
	end
	T.RefreshAll()
end

function T.RefreshAll()
	for _, inst in ipairs(T.instances) do
		inst:Refresh()
	end
end

--- Preview only: the first hidden player makes a new listing, and so shows again.
function T.RelistOneHidden(listings)
	for _, l in ipairs(listings) do
		if IsHidden(l) then
			l.listedAt, l.age = time(), 0
			ns.Print(format("preview: %s made a new listing, so they show again.", l.leader.name))
			return true
		end
	end
	return false
end
