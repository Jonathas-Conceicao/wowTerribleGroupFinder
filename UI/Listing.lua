-------------------------------------------------------------------------------
--  UI/Listing.lua -- the Listing panel, as Forever's: list yourself (solo, with the roles
--  you can play) or list your group (as its leader, with Role Poll). Pick a category and
--  up to 16 of its activities, a playstyle, then List Self / List Group; once listed,
--  Update Listing or Unlist. The description stays in the game's own window, whose text
--  box Blizzard keeps secure. The preview can play either a solo player or a leader.
-------------------------------------------------------------------------------
local _, ns = ...
local W, P = ns.W, ns.Preview
local wipe = W.wipe

local format = string.format

local MAX_ACTIVITIES = 16
local ROW_HEIGHT = 22
local ROLES = { "TANK", "HEALER", "DAMAGER" }
local ROLE_KEY = { TANK = "tank", HEALER = "healer", DAMAGER = "dps" }

local panel, list, catButtons, playDrop, friendly, voice, post, unlist, count, listedText
local solo, group, asSolo, asLeader
local category = 2
local selected, nSelected = {}, 0
local playstyle = 2
local items = {}

local function Count()
	nSelected = 0
	for _ in pairs(selected) do
		nSelected = nSelected + 1
	end
end

local function LoadFromListing()
	local mine = ns.state.myListing
	if not mine then
		return
	end
	wipe(selected)
	for _, key in ipairs(mine.activities) do
		selected[key] = true
	end
	category = P.activities[mine.activities[1]].category
	playstyle = mine.playstyle or playstyle
	friendly:SetChecked(mine.newPlayerFriendly)
	voice:SetChecked(mine.voice)
	Count()
end

local function Items()
	wipe(items)
	for _, a in pairs(P.activities) do
		if a.category == category then
			items[#items + 1] = a
		end
	end
	table.sort(items, function(x, y)
		if x.minLevel ~= y.minLevel then
			return x.minLevel < y.minLevel
		end
		return x.name < y.name
	end)
	return items
end

local function RefreshRoles()
	local leader = ns.state.asLeader
	solo:SetShown(not leader)
	group:SetShown(leader)
	asSolo:SetEnabled(leader)
	asLeader:SetEnabled(not leader)
	local can = ns.CLASS_ROLES[ns.PlayerClass()]
	for _, role in ipairs(ROLES) do
		local b, key = solo.buttons[role], ROLE_KEY[role]
		local allowed = can[key] == true
		b.check:SetEnabled(allowed)
		b.check:SetChecked(allowed and ns.state.roles[key] == true)
		b.icon:SetAlpha(allowed and 1 or 0.3)
	end
	if leader then
		local names = {}
		for _, m in ipairs(ns.Party()) do
			names[#names + 1] = W.Colored(m.class, m.name) .. " |cff999999" .. W.ROLE_NAME[m.role] .. "|r"
		end
		group.members:SetText(table.concat(names, "   "))
	end
end

local function Refresh()
	if not panel then
		return
	end
	RefreshRoles()
	for id, b in pairs(catButtons) do
		b.selected:SetShown(id == category)
	end
	list:SetItems(Items())
	playDrop:SetLabel(P.playstyles[playstyle])
	local mine = ns.state.myListing
	if mine then
		post:SetText("Update Listing")
		local a = P.activities[mine.activities[1]]
		listedText:SetText(
			format(
				"|cff33ff33Listed|r %s %s%s",
				ns.state.asLeader and "your group for" or "yourself for",
				a.name,
				#mine.activities > 1 and format(" +%d", #mine.activities - 1) or ""
			)
		)
	else
		post:SetText(ns.state.asLeader and "List Group" or "List Self")
		listedText:SetText("|cff999999Not listed|r")
	end
	unlist:SetEnabled(mine ~= nil)
	local anyRole = ns.state.roles.tank or ns.state.roles.healer or ns.state.roles.dps
	post:SetEnabled(nSelected > 0 and nSelected <= MAX_ACTIVITIES and (ns.state.asLeader or anyRole))
	count:SetText(format("%d/%d activities", nSelected, MAX_ACTIVITIES))
end

local function MakeRow(parent)
	local row = CreateFrame("Button", nil, parent)
	W.RowHighlight(row)
	row.check = W.Check(row, "")
	row.check:SetPoint("LEFT", 2, 0)
	row.check:SetScript("OnClick", function(self)
		W.PlayCheckbox(self:GetChecked() and true or false)
		local key = self:GetParent().activity.key
		if self:GetChecked() then
			if nSelected >= MAX_ACTIVITIES then
				self:SetChecked(false)
				return ns.Print("at most " .. MAX_ACTIVITIES .. " activities per listing.")
			end
			selected[key] = true
		else
			selected[key] = nil
		end
		Count()
		Refresh()
	end)
	row.name = W.Text(row, "GameFontHighlightSmall", 11)
	row.name:SetPoint("LEFT", row.check, "RIGHT", 2, 0)
	row.range = W.Text(row, "GameFontDisableSmall", 10, "RIGHT")
	row.range:SetPoint("RIGHT", -6, 0)
	row:SetScript("OnClick", function(self)
		self.check:Click()
	end)
	return row
end

local function FillRow(row, a)
	row.activity = a
	row.check:SetChecked(selected[a.key] == true)
	local level = ns.PlayerLevel()
	local fits = level >= a.minLevel and level <= a.maxLevel
	row.name:SetText(fits and ("|cff33ff33" .. a.name .. "|r") or a.name)
	local range = a.minLevel == a.maxLevel and tostring(a.minLevel) or (a.minLevel .. "-" .. a.maxLevel)
	row.range:SetText(format("level %s, %d players", range, a.size))
end

local function Post()
	local keys = {}
	for key in pairs(selected) do
		keys[#keys + 1] = key
	end
	table.sort(keys, function(x, y)
		return P.activities[x].minLevel < P.activities[y].minLevel
	end)
	local isNew = ns.state.myListing == nil
	local mine = ns.state.myListing or { age = 0 }
	ns.state.myListing = mine
	mine.activities = keys
	mine.playstyle = playstyle
	mine.newPlayerFriendly = friendly:GetChecked() and true or false
	mine.voice = voice:GetChecked() and true or false
	ns.Print(
		format(
			"preview: %s %s with %d %s (C_LFGList.%s).",
			isNew and "listed" or "updated",
			ns.state.asLeader and "your group" or "yourself",
			#keys,
			#keys == 1 and "activity" or "activities",
			isNew and "CreateListing" or "UpdateListing"
		)
	)
	ns.UI.Show("browse")
end

local function RoleSection()
	local section = CreateFrame("Frame", nil, panel)
	section:SetPoint("TOPLEFT", 0, 0)
	section:SetPoint("TOPRIGHT", 0, 0)
	section:SetHeight(86)
	local stone = section:CreateTexture(nil, "BACKGROUND")
	stone:SetPoint("TOPLEFT", -2, 4)
	stone:SetPoint("BOTTOMRIGHT", 2, 0)
	if not W.Atlas(stone, "groupfinder-Stat-StoneBG") then
		stone:SetColorTexture(0.15, 0.13, 0.11, 0.9)
	end

	-- Solo: the roles you can play (C_LFGListRoles.SetRoles saves them for the game too).
	solo = CreateFrame("Frame", nil, section)
	solo:SetAllPoints()
	local label = W.Text(solo, "GameFontNormal", 12)
	label:SetPoint("TOPLEFT", 6, -4)
	label:SetText("Your roles")
	solo.buttons = {}
	for i, role in ipairs(ROLES) do
		local box = CreateFrame("Frame", nil, solo)
		box:SetSize(84, 64)
		box:SetPoint("TOPLEFT", 6 + (i - 1) * 90, -20)
		local band = box:CreateTexture(nil, "BACKGROUND")
		band:SetAllPoints()
		if not W.Atlas(band, "groupfinder-roles-background") then
			band:SetColorTexture(0.1, 0.1, 0.1, 0.7)
		end
		box.icon = W.RoleIcon(box, 36)
		box.icon:SetPoint("TOP", 0, -2)
		box.icon:SetRole(role)
		box.check = W.Check(box, W.ROLE_NAME[role], function(self)
			ns.state.roles[ROLE_KEY[role]] = self:GetChecked() and true or false
			Refresh()
		end)
		box.check:SetPoint("BOTTOMLEFT", 4, 0)
		solo.buttons[role] = box
	end

	-- Group: your party's roles and Role Poll, as Forever shows a leader.
	group = CreateFrame("Frame", nil, section)
	group:SetAllPoints()
	local glabel = W.Text(group, "GameFontNormal", 12)
	glabel:SetPoint("TOPLEFT", 6, -4)
	glabel:SetText("Your group")
	group.members = W.Text(group, "GameFontHighlightSmall", 11)
	group.members:SetPoint("TOPLEFT", 6, -26)
	group.members:SetPoint("RIGHT", -150, 0)
	local poll = W.Button(group, "Role Poll", 100, 22, function()
		ns.Print("preview: Role Poll asks your group for roles (InitiateRolePoll).")
	end)
	poll:SetPoint("TOPLEFT", 6, -50)

	friendly = W.Check(section, "New player friendly")
	friendly:SetPoint("BOTTOMRIGHT", -130, 4)

	-- The preview plays a solo player or a group leader.
	local playing = W.Text(section, "GameFontDisableSmall", 10, "RIGHT")
	playing:SetPoint("TOPRIGHT", -4, -4)
	playing:SetText("Preview as")
	asSolo = W.Button(section, "Solo", 60, 20, function()
		ns.state.asLeader = false
		ns.UI.Refresh()
	end)
	asSolo:SetPoint("TOPRIGHT", -68, -18)
	asLeader = W.Button(section, "Leader", 60, 20, function()
		ns.state.asLeader = true
		ns.UI.Refresh()
	end)
	asLeader:SetPoint("TOPRIGHT", -4, -18)
end

local function Build(parent)
	local outer = CreateFrame("Frame", nil, parent)
	panel = CreateFrame("Frame", nil, outer)
	panel:SetPoint("TOPLEFT", 10, -62)
	panel:SetPoint("BOTTOMRIGHT", -10, 10)
	RoleSection()

	catButtons = {}
	for i, c in ipairs(P.categories) do
		local b = CreateFrame("Button", nil, panel)
		b:SetSize(170, 52)
		b:SetPoint("TOPLEFT", 0, -94 - (i - 1) * 56)
		local art = b:CreateTexture(nil, "BACKGROUND")
		art:SetAllPoints()
		if not W.Atlas(art, c.atlas) then
			art:SetColorTexture(0.18, 0.15, 0.12, 1)
		end
		local cover = b:CreateTexture(nil, "BORDER")
		cover:SetAllPoints()
		if not W.Atlas(cover, "groupfinder-button-cover") then
			cover:SetColorTexture(0, 0, 0, 0)
		end
		local hl = b:CreateTexture(nil, "HIGHLIGHT")
		hl:SetAllPoints()
		if not W.Atlas(hl, "groupfinder-button-cover-hover") then
			hl:SetColorTexture(1, 1, 1, 0.12)
		end
		b.selected = b:CreateTexture(nil, "OVERLAY")
		b.selected:SetAllPoints()
		if not W.Atlas(b.selected, "groupfinder-button-down") then
			b.selected:SetColorTexture(1, 0.82, 0, 0.18)
		end
		local text = W.Text(b, "GameFontNormalLarge", 14)
		text:SetPoint("LEFT", 12, 0)
		text:SetText(c.name)
		b:SetScript("OnClick", function()
			category = c.id
			list.offset = 0
			Refresh()
		end)
		catButtons[c.id] = b
	end

	local inset = W.Inset(panel)
	inset:SetPoint("TOPLEFT", 178, -94)
	inset:SetPoint("BOTTOMRIGHT", 0, 96)
	list = W.List(inset, ROW_HEIGHT, MakeRow, FillRow)
	list:SetPoint("TOPLEFT", 4, -4)
	list:SetPoint("BOTTOMRIGHT", -4, 4)

	count = W.Text(panel, "GameFontDisableSmall", 10, "RIGHT")
	count:SetPoint("TOPRIGHT", inset, "BOTTOMRIGHT", 0, -4)
	local hint = W.Text(panel, "GameFontDisableSmall", 10)
	hint:SetPoint("TOPLEFT", inset, "BOTTOMLEFT", 2, -4)
	hint:SetText("|cff33ff33Green|r: suggested for your level")

	local playLabel = W.Text(panel, "GameFontNormal", 12)
	playLabel:SetPoint("TOPLEFT", inset, "BOTTOMLEFT", 2, -22)
	playLabel:SetText("Playstyle")
	playDrop = W.Dropdown(panel, 150, function()
		local options = {}
		for i, name in ipairs(P.playstyles) do
			options[#options + 1] = { text = name, value = i, checked = playstyle == i }
		end
		return options
	end, function(value)
		playstyle = value
		Refresh()
	end)
	playDrop:SetPoint("LEFT", playLabel, "RIGHT", 10, 0)
	voice = W.Check(panel, "Voice chat")
	voice:SetPoint("LEFT", playDrop, "RIGHT", 14, 0)

	local note = W.Text(panel, "GameFontDisableSmall", 10)
	note:SetPoint("TOPLEFT", inset, "BOTTOMLEFT", 2, -48)
	note:SetPoint("RIGHT", 0, 0)
	note:SetWordWrap(true)
	note:SetText(
		"In game this tab is Forever's own Listing tab, unchanged: its description box is secure, so addons can't fill it."
	)

	unlist = W.Button(panel, "Unlist", 100, 24, function()
		ns.state.myListing = nil
		ns.Print("preview: unlisted (C_LFGList.RemoveListing).")
		Refresh()
	end)
	unlist:SetPoint("BOTTOMLEFT", 0, 2)
	listedText = W.Text(panel, "GameFontHighlightSmall", 11, "CENTER")
	listedText:SetPoint("BOTTOM", 0, 9)
	post = W.Button(panel, "List Self", 130, 24, Post)
	post:SetPoint("BOTTOMRIGHT", 0, 2)

	LoadFromListing()
	return outer
end

local function OnShow()
	if panel then
		LoadFromListing()
	end
	Refresh()
end

ns.UI.AddPanel("listing", "Listing", "Interface\\Icons\\INV_Misc_Note_01", Build, OnShow, nil, 1)
