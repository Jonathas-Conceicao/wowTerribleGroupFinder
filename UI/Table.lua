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
--  Columns can't overlap: Name, Lvl, Roles (and GS, while ns.GEAR_SCORE is on) have fixed widths from the left, Listed
--  and the row's buttons are anchored to the right, and Activity takes what is left
--  between them; every cell is width-bound, so long text is cut, not drawn over a neighbour.
-------------------------------------------------------------------------------
local _, ns = ...
local W = ns.W
local wipe = W.wipe

local lower, find, format = string.lower, string.find, string.format
local max, min = math.max, math.min

local T = { instances = {} }
ns.Table = T

local ROW_HEIGHT = 32
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
	{ key = "role", label = "Roles", x = 190, w = 76 },
}
if ns.GEAR_SCORE then
	LEFT[#LEFT + 1] = { key = "gs", label = "GS", x = 268, w = 44, justify = "CENTER" }
end
local ACTIVITY_X = ns.GEAR_SCORE and 318 or 268
local FIRST_DESC = { level = true, gs = ns.GEAR_SCORE or nil }
-- Every cell of a row and of the header, in order.
local CELL_KEYS = {}
for _, col in ipairs(LEFT) do
	CELL_KEYS[#CELL_KEYS + 1] = col.key
end
CELL_KEYS[#CELL_KEYS + 1] = "activity"
CELL_KEYS[#CELL_KEYS + 1] = "listed"

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
	T.RefreshAll()
end

local Instance = {}
Instance.__index = Instance

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

function Instance:MakeRow(parent)
	local inst = self
	local row = CreateFrame("Button", nil, parent)
	W.RowHighlight(row)
	row.selected = row:CreateTexture(nil, "BACKGROUND")
	row.selected:SetAllPoints()
	if not W.Atlas(row.selected, "groupfinder-highlightbar-yellow") then
		row.selected:SetColorTexture(1, 0.82, 0, 0.12)
	end
	row.line = W.Line(row)
	row.line:SetPoint("BOTTOMLEFT", 0, 0)
	row.line:SetPoint("BOTTOMRIGHT", 0, 0)

	-- The section divider look (shown on header items).
	row.divider = row:CreateTexture(nil, "BACKGROUND")
	row.divider:SetPoint("TOPLEFT", 0, -6)
	row.divider:SetPoint("BOTTOMRIGHT", 0, 0)
	if not W.Atlas(row.divider, "common-button-list-collapseExpand") then
		row.divider:SetColorTexture(0.2, 0.17, 0.12, 0.9)
	end
	row.dividerLabel = W.Text(row, "GameFontNormal", 12)
	row.dividerLabel:SetPoint("LEFT", 12, -3)
	row.dividerLabel:SetWidth(300)
	row.fold = W.Text(row, "GameFontNormal", 14, "RIGHT")
	row.fold:SetPoint("RIGHT", -12, -3)
	row.fold:SetWidth(30)

	-- Each cell holds its texts; Layout anchors the cells.
	local cells = {}
	for _, key in ipairs(CELL_KEYS) do
		local cell = CreateFrame("Frame", nil, row)
		cell:SetHeight(ROW_HEIGHT)
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
	row.level = W.Text(cells.level, "GameFontHighlight", 12, "CENTER")
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

	row.hide = W.Button(row, "x", HIDE_W, 20, function(b)
		Hide(b:GetParent().listing)
	end)
	row.hide:SetPoint("RIGHT", -2, 0)
	row.message = W.Button(row, "Whisper", MSG_W, 20, function(b)
		inst:Message(b:GetParent().listing)
	end)
	row.message:SetPoint("RIGHT", row.hide, "LEFT", -3, 0)
	Layout(row, cells, row.message, -GAP)

	row:SetScript("OnClick", function(r)
		if r.item and r.item.header then
			view.collapsed[r.item.key] = not view.collapsed[r.item.key] or nil
			return T.RefreshAll()
		end
		inst.selected = r.listing
		inst:Refresh()
	end)
	row:SetScript("OnDoubleClick", function(r)
		if r.listing then
			inst:Message(r.listing)
		end
	end)
	row:SetScript("OnEnter", ShowTooltip)
	row:SetScript("OnLeave", function()
		GameTooltip:Hide()
	end)
	W.Tooltip(row.hide, "Hide", "Greys this player and moves them to the end until they make a new listing.")
	return row
end

function Instance:FillHeader(row, item)
	row.listing = nil
	for _, cell in pairs(row.cells) do
		cell:Hide()
	end
	row.hide:Hide()
	row.message:Hide()
	row.selected:Hide()
	row.line:Hide()
	row.divider:Show()
	row.dividerLabel:Show()
	row.fold:Show()
	row.dividerLabel:SetText(format("%s |cff999999(%d)|r", SECTION_LABEL[item.key], item.count))
	row.fold:SetText(view.collapsed[item.key] and "+" or "-")
end

function Instance:FillRow(row, item)
	row.item = item
	if item.header then
		return self:FillHeader(row, item)
	end
	local l = item
	row.listing = l
	for _, cell in pairs(row.cells) do
		cell:Show()
	end
	row.divider:Hide()
	row.dividerLabel:Hide()
	row.fold:Hide()
	row.line:Show()
	row.hide:Show()
	row.message:Show()

	local who = l.leader
	row.icon:SetClass(who.class)
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
	row.name:SetText(W.Colored(who.class, who.name) .. W.Marks(who) .. (l.mine and " |cff33ff33(you)|r" or "") .. tags)
	if l.solo then
		row.sub:SetText(who.spec or W.ClassName(who.class))
	else
		row.sub:SetText(format("%d/%d members", #l.members, Size(l)))
	end
	if row.gs then
		local gs, stale = ListingGS(l)
		row.gs:SetText(W.GS(gs, who.level, stale))
	end
	row.level:SetText(who.level)
	SetRoles(row, l)
	row.activity:SetText("|cffffd100" .. ActivityText(l) .. "|r")
	row.comment:SetText(l.comment or "")

	local hidden = IsHidden(l)
	if l.delisted then
		row.listed:SetText("|cffff3333delisted|r")
	elseif ns.state.invited[l.id] then
		row.listed:SetText("|cff33ff33invited|r")
	elseif ns.state.messaged[l.id] then
		row.listed:SetText("|cff33ff33sent|r")
	else
		row.listed:SetText(W.Age(l.age))
	end
	row.selected:SetShown(self.selected == l)
	row.hide:SetShown(not l.mine)
	row.hide:SetText(hidden and "+" or "x")
	row.message:SetText(l.mine and "Unlist" or "Whisper")
	row.message:SetEnabled(l.mine or not l.delisted)
	local alpha = l.demoted and 0.4 or 1
	for _, cell in pairs(row.cells) do
		cell:SetAlpha(alpha)
	end
end

local sections = { solo = {}, groups = {} }
function Instance:Collect()
	local items = self.items
	wipe(items)
	wipe(sections.solo)
	wipe(sections.groups)
	local mine
	for _, l in ipairs(self.source.listings()) do
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
	local solo, groups = self:Collect()
	self.fits:SetChecked(view.fitsRoles)
	for _, col in ipairs(LEFT) do
		self.header[col.key]:SetText(col.label .. (view.sort == col.key and (view.desc and " v" or " ^") or ""))
	end
	self.header.activity:SetText("Activity" .. (view.sort == "activity" and (view.desc and " v" or " ^") or ""))
	self.header.listed:SetText("Listed" .. (view.sort == "listed" and (view.desc and " v" or " ^") or ""))
	local empty = self.source.searching and self.source.searching() and (SEARCHING or "Searching...")
		or "Nothing listed here. Pick activities and search, or clear the search box."
	self.list:SetItems(self.items, empty)
	self.status:SetText(format("%d solo players, %d groups", solo, groups))
	if self.myGS then
		local gs, stale = ns.GS.Of(ns.Me())
		self.myGS:SetText("Your GS " .. W.GS(gs, ns.PlayerLevel(), stale))
	end
	local sel = self.selected
	if sel and not sel.leader then
		sel = nil
	end
	self.send:SetEnabled(sel ~= nil and not sel.mine)
	self.invite:SetEnabled(sel ~= nil and sel.solo and not sel.mine and ns.CanInvite())
end

--- Builds a table filling `area` (the Browse frame's list area), with its bottom buttons on
--- `host`. source: listings() -> the listings to show; preview() -> true for sample data;
--- searching() -> true while a search runs.
function T.Attach(host, area, source)
	local self = setmetatable({
		host = host,
		source = source,
		items = {},
		headers = { solo = { header = true, key = "solo" }, groups = { header = true, key = "groups" } },
	}, Instance)

	local band = CreateFrame("Frame", nil, host)
	band:SetPoint("TOPLEFT", area, "TOPLEFT", 6, -4)
	band:SetPoint("TOPRIGHT", area, "TOPRIGHT", -6, -4)
	band:SetHeight(24)
	band:EnableMouse(true)
	self.band = band

	self.fits = W.Check(band, "Needs my role", function(b)
		view.fitsRoles = b:GetChecked() and true or false
		T.RefreshAll()
	end)
	self.fits:SetPoint("LEFT", 0, 0)
	W.Tooltip(
		self.fits,
		"Needs my role",
		"Moves to the end (greyed) groups with no open slot for a role you play, and solo players who can't fill a slot your group has open."
	)
	local search = W.EditBox(band, 150, "SearchBoxTemplate")
	search:SetPoint("LEFT", self.fits.Label, "RIGHT", 18, 0)
	if search.Instructions then
		search.Instructions:SetText("Name, activity or note")
	end
	search:HookScript("OnTextChanged", function(b)
		view.search = lower(b:GetText() or "")
		T.RefreshAll()
	end)
	if ns.GEAR_SCORE then
		self.myGS = W.Text(band, "GameFontNormal", 12, "RIGHT")
		self.myGS:SetPoint("RIGHT", -4, 0)
		local gsHover = CreateFrame("Frame", nil, band)
		gsHover:SetAllPoints(self.myGS)
		gsHover:EnableMouse(true)
		W.Tooltip(
			gsHover,
			"Your gear score",
			"Item level of your gear, adjusted for quality, on the same scale as the GS column."
		)
	end

	-- A dark backing so nothing of the frame's own list shows or takes the mouse through.
	local back = CreateFrame("Frame", nil, host)
	back:SetPoint("TOPLEFT", band, "BOTTOMLEFT", -2, -2)
	back:SetPoint("BOTTOMRIGHT", area, "BOTTOMRIGHT", -4, 58)
	back:EnableMouse(true)
	local inset = W.Inset(back)
	inset:SetAllPoints()

	local header = CreateFrame("Frame", nil, back)
	header:SetPoint("TOPLEFT", 4, -2)
	header:SetPoint("TOPRIGHT", -12, -2)
	header:SetHeight(18)
	local headLine = W.Line(header)
	headLine:SetPoint("BOTTOMLEFT", 0, 0)
	headLine:SetPoint("BOTTOMRIGHT", 0, 0)
	local justify = { level = "CENTER", gs = "CENTER", listed = "RIGHT" }
	for _, key in ipairs(CELL_KEYS) do
		local b = CreateFrame("Button", nil, header)
		b:SetHeight(18)
		local text = W.Text(b, "GameFontNormalSmall", 11, justify[key])
		text:SetAllPoints()
		local hl = b:CreateTexture(nil, "HIGHLIGHT")
		hl:SetAllPoints()
		hl:SetColorTexture(1, 1, 1, 0.08)
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

	self.list = W.List(back, ROW_HEIGHT, function(parent)
		return self:MakeRow(parent)
	end, function(row, item)
		self:FillRow(row, item)
	end)
	self.list:SetPoint("TOPLEFT", 4, -22)
	self.list:SetPoint("BOTTOMRIGHT", -4, 4)

	-- Forever's own bottom buttons sit at these spots.
	self.send = W.Button(host, SEND_MESSAGE or "Send Message", 111, 28, function()
		self:Message(self.selected)
	end)
	self.send:SetPoint("BOTTOMLEFT", 21, 16)
	self.invite = W.Button(host, GROUP_INVITE or "Group Invite", 109, 28, function()
		self:Invite(self.selected)
	end)
	self.invite:SetPoint("BOTTOMRIGHT", -21, 16)
	self.status = W.Text(host, "GameFontHighlightSmall", 11, "CENTER")
	self.status:SetPoint("BOTTOM", 0, 26)

	band:SetScript("OnShow", function()
		self:Refresh()
	end)
	T.instances[#T.instances + 1] = self
	return self
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
