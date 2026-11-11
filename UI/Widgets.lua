-------------------------------------------------------------------------------
--  UI/Widgets.lua -- small widget helpers (ns.W). Each one prefers Forever's own templates
--  and atlases (Blizzard_GroupFinder_VanillaStyle's look) and falls back to plain textures
--  and font strings when a client lacks them, so the preview renders anywhere.
-------------------------------------------------------------------------------
local _, ns = ...

local W = {}
ns.W = W

local floor, max, min = math.floor, math.max, math.min

-- CreateFrame with a template, falling back to no template where the client lacks it
-- (the real client only warns; other environments may throw).
local function Create(frameType, parent, template)
	if template then
		local ok, f = pcall(CreateFrame, frameType, nil, parent, template)
		if ok and f then
			return f
		end
	end
	return CreateFrame(frameType, nil, parent)
end
W.Create = Create

W.wipe = wipe or function(t)
	for k in pairs(t) do
		t[k] = nil
	end
	return t
end

local WHITE = { 1, 1, 1 }
local CLASS_COLORS = {
	WARRIOR = { 0.78, 0.61, 0.43 },
	PALADIN = { 0.96, 0.55, 0.73 },
	HUNTER = { 0.67, 0.83, 0.45 },
	ROGUE = { 1, 0.96, 0.41 },
	PRIEST = { 1, 1, 1 },
	SHAMAN = { 0, 0.44, 0.87 },
	MAGE = { 0.25, 0.78, 0.92 },
	WARLOCK = { 0.53, 0.53, 0.93 },
	DRUID = { 1, 0.49, 0.04 },
}

function W.ClassColor(class)
	local c = RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]
	if c then
		return c.r, c.g, c.b
	end
	c = CLASS_COLORS[class] or WHITE
	return c[1], c[2], c[3]
end

-- Forever's row colours: level and activity grey (BRIGHTBLUE_FONT_COLOR when the activity is
-- one of your active listing's), and the stock grey of delisted / filtered rows.
W.GRAY = GRAY_FONT_COLOR or { r = 0.5, g = 0.5, b = 0.5 }
W.BRIGHTBLUE = BRIGHTBLUE_FONT_COLOR or { r = 0.4, g = 0.73, b = 1 }
W.DELISTED = { r = 0.3, g = 0.3, b = 0.3 }

function W.SetColor(fs, c)
	fs:SetTextColor(c.r, c.g, c.b)
end

-- A gear score on the item level scale ("23.1"), coloured like item quality by how it
-- compares with a well geared player of that level (blues about five levels above it).
-- An outdated one (only known from an earlier session) takes its own dusty colour; an
-- unknown one reads as a grey dash.
W.GS_OUTDATED = "|cffb08d57"
function W.GS(gs, level, outdated)
	if not gs then
		return "|cff666666-|r"
	end
	if outdated then
		return W.GS_OUTDATED .. string.format("%.1f", gs) .. "|r"
	end
	local share = gs / ((level or 60) + 5)
	local code = share >= 1.05 and "|cffa335ee"
		or share >= 0.95 and "|cff0070dd"
		or share >= 0.8 and "|cff1eff00"
		or "|cffffffff"
	return code .. string.format("%.1f", gs) .. "|r"
end

-- Inline icons: the game's atlas or texture markup in the real client; short coloured
-- words where atlases are missing, so a row never shows raw markup.
local RICH
function W.Rich()
	if RICH == nil then
		RICH = W.HasAtlas("groupfinder-icon-class-warrior")
	end
	return RICH
end

-- Battle.net friends: the person outline chat puts on a Battle.net whisper's tab
-- (UI-ChatWhisperIcon, tinted in the BN_WHISPER chat colour), as recent allies get theirs.
local function BnetIcon()
	local c = ChatTypeInfo and ChatTypeInfo.BN_WHISPER
	local r, g, b = 0, 255, 246
	if c and c.r then
		r, g, b = floor(c.r * 255 + 0.5), floor(c.g * 255 + 0.5), floor(c.b * 255 + 0.5)
	end
	return string.format("|TInterface\\ChatFrame\\UI-ChatWhisperIcon:12:12:0:0:16:16:0:16:0:16:%d:%d:%d|t", r, g, b)
end

local ICONS = {
	newPlayer = { "|A:newplayerchat-chaticon-newcomer:14:14|a", "|cff66ccffnew|r" },
	voice = { "|A:groupfinder-icon-voice:14:14|a", "|cffcc99ffvoice|r" },
	bnet = { BnetIcon, "|cff82c5ffbnet|r" },
	friend = { "|A:friends-icon-friendsAvailable:13:13|a", "|cff96ff82friend|r" },
	recent = { "|A:friendslist-recentallies-yellow:11:11|a", "|cffffd100ally|r" },
	friendsIn = { "|A:friends-icon-friendsInGroup:14:14|a", "|cff82c5fffriends|r" },
}
function W.Icon(key)
	local icon = ICONS[key]
	if not W.Rich() then
		return icon[2]
	end
	local rich = icon[1]
	return type(rich) == "function" and rich() or rich
end

-- The marks after a member's name: Battle.net friend, character friend, recent ally
-- (guildmates show by colour in the tooltip, as the retail finder lists them).
function W.Marks(m)
	local s = ""
	if m.bnet then
		s = s .. " " .. W.Icon("bnet")
	end
	if m.friend then
		s = s .. " " .. W.Icon("friend")
	end
	if m.recent then
		s = s .. " " .. W.Icon("recent")
	end
	return s
end

-- Name colours for the "Friends in group" tooltip line, as the retail finder colours them.
function W.FriendColor(m)
	if m.bnet then
		return FRIENDS_BNET_NAME_COLOR_CODE or "|cff82c5ff"
	end
	if m.friend then
		return FRIENDS_WOW_NAME_COLOR_CODE or "|cfffde05c"
	end
	if m.guild then
		return "|cff40ff40"
	end
end

-- A name in its class colour.
function W.Colored(class, name)
	local r, g, b = W.ClassColor(class)
	return string.format("|cff%02x%02x%02x%s|r", floor(r * 255 + 0.5), floor(g * 255 + 0.5), floor(b * 255 + 0.5), name)
end

function W.ClassName(class)
	local names = LOCALIZED_CLASS_NAMES_MALE
	if names and names[class] then
		return names[class]
	end
	return class:sub(1, 1) .. class:sub(2):lower()
end

local function HasAtlas(atlas)
	return C_Texture ~= nil and C_Texture.GetAtlasInfo ~= nil and C_Texture.GetAtlasInfo(atlas) ~= nil
end
W.HasAtlas = HasAtlas

-- Sets an atlas when the client knows it; otherwise a flat colour (when given).
function W.Atlas(tex, atlas, r, g, b, a)
	if tex.SetAtlas and HasAtlas(atlas) then
		tex:SetAtlas(atlas)
		tex:SetVertexColor(1, 1, 1, 1)
		return true
	end
	if r then
		tex:SetColorTexture(r, g, b, a or 1)
	end
	return false
end

function W.Text(parent, font, size, justify)
	local fs = parent:CreateFontString(nil, "OVERLAY", font or "GameFontHighlight")
	if not fs:GetFont() then
		fs:SetFont("Fonts\\FRIZQT__.TTF", size or 12, "")
	end
	fs:SetJustifyH(justify or "LEFT")
	fs:SetWordWrap(false)
	return fs
end

-- A dark inset with a thin border, standing in for common-insideframe where it is missing.
function W.Inset(parent)
	local f = CreateFrame("Frame", nil, parent)
	local bg = f:CreateTexture(nil, "BACKGROUND")
	bg:SetAllPoints()
	if not W.Atlas(bg, "groupfinder-background") then
		bg:SetColorTexture(0.05, 0.05, 0.05, 0.85)
	end
	local edges = {
		{ "TOPLEFT", "TOPRIGHT", 0, 1 },
		{ "BOTTOMLEFT", "BOTTOMRIGHT", 0, 1 },
		{ "TOPLEFT", "BOTTOMLEFT", 1, 0 },
		{ "TOPRIGHT", "BOTTOMRIGHT", 1, 0 },
	}
	for _, e in ipairs(edges) do
		local t = f:CreateTexture(nil, "BORDER")
		t:SetColorTexture(0.35, 0.3, 0.2, 1)
		t:SetPoint(e[1])
		t:SetPoint(e[2])
		if e[3] == 1 then
			t:SetWidth(1)
		else
			t:SetHeight(1)
		end
	end
	return f
end

function W.Line(parent)
	local t = parent:CreateTexture(nil, "ARTWORK")
	if not W.Atlas(t, "groupfinder-ScrollLine") then
		t:SetColorTexture(0.35, 0.3, 0.2, 0.8)
	end
	t:SetHeight(1)
	return t
end

local function Tooltip(f, title, body)
	if not title then
		return
	end
	f:HookScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
		GameTooltip:SetText(title, 1, 1, 1)
		if body then
			GameTooltip:AddLine(body, nil, nil, nil, true)
		end
		GameTooltip:Show()
	end)
	f:HookScript("OnLeave", function()
		GameTooltip:Hide()
	end)
end
W.Tooltip = Tooltip

-- UIPanelButtonTemplate, or a flat button with the same size and font.
function W.Button(parent, text, width, height, onClick)
	local b = Create("Button", parent, "UIPanelButtonTemplate")
	b:SetSize(width or 100, height or 22)
	if not b:GetNormalTexture() then
		local bg = b:CreateTexture(nil, "BACKGROUND")
		bg:SetAllPoints()
		bg:SetColorTexture(0.45, 0.08, 0.05, 1)
		b:SetNormalTexture(bg)
		local hl = b:CreateTexture(nil, "HIGHLIGHT")
		hl:SetAllPoints()
		hl:SetColorTexture(1, 1, 1, 0.15)
		b:SetHighlightTexture(hl)
	end
	if not b:GetFontString() then
		b:SetFontString(W.Text(b, "GameFontNormal", 12, "CENTER"))
	end
	b:SetNormalFontObject("GameFontNormal")
	b:SetDisabledFontObject("GameFontDisable")
	b:SetText(text)
	if onClick then
		b:SetScript("OnClick", onClick)
	end
	return b
end

-- Forever's checkbox sound: on when checked (or a row is picked), off when unchecked.
function W.PlayCheckbox(on)
	if PlaySound and SOUNDKIT then
		PlaySound(on and SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON or SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_OFF)
	end
end

-- UICheckButtonTemplate, 26x26, with the template's own label (GameFontNormalSmall) where it
-- has one, else a label of our own. Every click plays the checkbox sound first.
function W.Check(parent, label, onClick)
	local c = Create("CheckButton", parent, "UICheckButtonTemplate")
	c:SetSize(26, 26)
	if not c:GetNormalTexture() then
		c:SetNormalTexture("Interface\\Buttons\\UI-CheckBox-Up")
		c:SetPushedTexture("Interface\\Buttons\\UI-CheckBox-Down")
		c:SetHighlightTexture("Interface\\Buttons\\UI-CheckBox-Highlight", "ADD")
		c:SetCheckedTexture("Interface\\Buttons\\UI-CheckBox-Check")
	end
	if c.Text then
		c.Text:SetText(label or "")
		c.Label = c.Text
	else
		c.Label = W.Text(c, "GameFontHighlightSmall", 11)
		c.Label:SetPoint("LEFT", c, "RIGHT", 2, 1)
		c.Label:SetText(label or "")
	end
	c:SetScript("OnClick", function(b, ...)
		W.PlayCheckbox(b:GetChecked() and true or false)
		if onClick then
			onClick(b, ...)
		end
	end)
	return c
end

-- InputBoxTemplate (or SearchBoxTemplate) with a fallback background.
function W.EditBox(parent, width, template)
	local e = Create("EditBox", parent, template or "InputBoxTemplate")
	e:SetSize(width, 20)
	e:SetAutoFocus(false)
	if not e:GetFontObject() then
		e:SetFontObject("ChatFontNormal")
	end
	if not e:GetFont() then
		e:SetFont("Fonts\\FRIZQT__.TTF", 12, "")
	end
	if not (e.Left or e.Middle) then
		local bg = e:CreateTexture(nil, "BACKGROUND")
		bg:SetPoint("TOPLEFT", -4, 2)
		bg:SetPoint("BOTTOMRIGHT", 4, -2)
		bg:SetColorTexture(0, 0, 0, 0.6)
	end
	-- SearchBoxTemplate keeps its own insets: they leave room for its magnifier and clear button.
	if not e.searchIcon then
		e:SetTextInsets(2, 2, 0, 0)
	end
	e:SetScript("OnEscapePressed", e.ClearFocus)
	e:SetScript("OnEnterPressed", e.ClearFocus)
	return e
end

-- A role icon: groupfinder-icon-role-large-*, or a coloured square with a letter.
local ROLE_ATLAS = { TANK = "tank", HEALER = "heal", DAMAGER = "dps" }
local ROLE_COLOR = { TANK = { 0.2, 0.45, 0.9 }, HEALER = { 0.2, 0.75, 0.3 }, DAMAGER = { 0.8, 0.25, 0.2 } }
local ROLE_LETTER = { TANK = "T", HEALER = "H", DAMAGER = "D" }
W.ROLE_NAME = { TANK = "Tank", HEALER = "Healer", DAMAGER = "Damage" }

function W.RoleIcon(parent, size)
	local f = CreateFrame("Frame", nil, parent)
	f:SetSize(size, size)
	f.tex = f:CreateTexture(nil, "ARTWORK")
	f.tex:SetAllPoints()
	f.letter = W.Text(f, "GameFontHighlightSmall", 10, "CENTER")
	f.letter:SetPoint("CENTER", 0, 0)
	function f:SetRole(role)
		self.letter:SetText("")
		if not role then
			if not W.Atlas(self.tex, "groupfinder-icon-emptyslot") then
				self.tex:SetColorTexture(0.2, 0.2, 0.2, 0.8)
			end
			return
		end
		if not W.Atlas(self.tex, "groupfinder-icon-role-large-" .. ROLE_ATLAS[role]) then
			local c = ROLE_COLOR[role]
			self.tex:SetColorTexture(c[1], c[2], c[3], 1)
			self.letter:SetText(ROLE_LETTER[role])
		end
	end
	return f
end

-- A class icon: groupfinder-icon-class-<class>, or a class-coloured square.
function W.ClassIcon(parent, size)
	local t = parent:CreateTexture(nil, "ARTWORK")
	t:SetSize(size, size)
	function t:SetClass(class)
		if not W.Atlas(self, "groupfinder-icon-class-" .. class:lower()) then
			local r, g, b = W.ClassColor(class)
			self:SetColorTexture(r, g, b, 1)
		end
	end
	return t
end

-- A minimal dropdown: a button showing the current choice, and a shared popup list.
local popup
local function Popup()
	if popup then
		return popup
	end
	popup = CreateFrame("Frame", nil, UIParent)
	popup:SetFrameStrata("FULLSCREEN_DIALOG")
	popup:SetClampedToScreen(true)
	popup:EnableMouse(true)
	local bg = popup:CreateTexture(nil, "BACKGROUND")
	bg:SetAllPoints()
	bg:SetColorTexture(0.06, 0.06, 0.06, 0.96)
	local edge = W.Inset(popup)
	edge:SetAllPoints()
	edge:SetFrameLevel(popup:GetFrameLevel())
	popup.buttons = {}
	popup:Hide()
	return popup
end

function W.CloseMenus()
	if popup then
		popup:Hide()
	end
end

function W.Dropdown(parent, width, getItems, onPick)
	local d = W.Button(parent, "", width, 22)
	d.arrow = W.Text(d, "GameFontHighlightSmall", 10, "RIGHT")
	d.arrow:SetPoint("RIGHT", -8, 0)
	d.arrow:SetText("v")
	function d:SetLabel(text)
		self:SetText(text)
	end
	-- Items: { text, value, checked, multi }. A multi item toggles and keeps the list open
	-- (Forever's activity filter works that way); any other closes it.
	local function Render(self)
		local p = Popup()
		p.owner = self
		local items = getItems()
		local rowH = 18
		for i, item in ipairs(items) do
			local b = p.buttons[i]
			if not b then
				b = CreateFrame("Button", nil, p)
				b:SetHeight(rowH)
				b.text = W.Text(b, "GameFontHighlightSmall", 11)
				b.text:SetPoint("LEFT", 8, 0)
				b.text:SetPoint("RIGHT", -8, 0)
				local hl = b:CreateTexture(nil, "HIGHLIGHT")
				hl:SetAllPoints()
				if not W.Atlas(hl, "groupfinder-highlightbar-blue") then
					hl:SetColorTexture(0.3, 0.5, 1, 0.25)
				end
				p.buttons[i] = b
			end
			b:SetPoint("TOPLEFT", 2, -2 - (i - 1) * rowH)
			b:SetPoint("RIGHT", -2, 0)
			local mark = item.multi and (item.checked and "|cffffd100[x]|r " or "[  ] ")
				or (item.checked and "|cffffd100> |r" or "   ")
			b.text:SetText(mark .. item.text)
			b:SetScript("OnClick", function()
				if not item.multi then
					p:Hide()
				end
				onPick(item.value, item)
				if item.multi then
					Render(self)
				end
			end)
			b:Show()
		end
		for i = #items + 1, #p.buttons do
			p.buttons[i]:Hide()
		end
		p:SetSize(max(width, 180), #items * rowH + 4)
		p:ClearAllPoints()
		p:SetPoint("TOPLEFT", self, "BOTTOMLEFT", 0, -2)
		p:Show()
	end
	d:SetScript("OnClick", function(self)
		local p = Popup()
		if p:IsShown() and p.owner == self then
			return p:Hide()
		end
		Render(self)
	end)
	return d
end

-- A pooled, mouse-wheel scrolled list: the fallback where the ScrollBox API or our
-- templates are missing. Two forms:
--   W.List(parent, rowHeight, makeRow, fillRow)         one kind of fixed-height row
--   W.List(parent, kinds, kindOf, fillItem)             several kinds, one pool each
--     kinds   = { header = { height = 36, make = fn(list) -> frame }, row = { ... } }
--     kindOf  = fn(item) -> kind;  fillItem = fn(frame, item)
-- list.pools[kind] holds that kind's frames (and its height); the wheel scrolls one item.
function W.List(parent, kinds, kindOf, fillItem)
	if type(kinds) == "number" then
		local makeRow, fillRow = kindOf, fillItem
		kinds = { row = { height = kinds, make = makeRow } }
		kindOf = function()
			return "row"
		end
		fillItem = fillRow
	end
	local list = CreateFrame("Frame", nil, parent)
	list.items, list.offset, list.pools, list.shown = {}, 0, {}, {}
	for kind, def in pairs(kinds) do
		list.pools[kind] = { height = def.height }
	end
	list:EnableMouseWheel(true)
	local track = list:CreateTexture(nil, "BACKGROUND")
	track:SetPoint("TOPRIGHT", 0, 0)
	track:SetPoint("BOTTOMRIGHT", 0, 0)
	track:SetWidth(4)
	track:SetColorTexture(0, 0, 0, 0.4)
	local thumb = list:CreateTexture(nil, "ARTWORK")
	thumb:SetWidth(4)
	thumb:SetColorTexture(0.8, 0.65, 0.2, 0.8)
	list.empty = W.Text(list, "GameFontDisable", 12, "CENTER")
	list.empty:SetPoint("CENTER")

	local function Height(item)
		return kinds[kindOf(item)].height
	end

	function list:SetItems(items, emptyText)
		self.items = items
		self.empty:SetText(#items == 0 and (emptyText or "") or "")
		self:Refresh()
	end

	function list:Refresh()
		local items, total = self.items, #self.items
		local room = self:GetHeight() or 0
		-- The furthest offset that still fills the list (no empty gap below the last item).
		local first, used = total, 0
		while first > 0 do
			local h = Height(items[first])
			if used + h > room then
				break
			end
			used, first = used + h, first - 1
		end
		self.offset = max(0, min(self.offset, first))

		local taken, shown = {}, self.shown
		for i = #shown, 1, -1 do
			shown[i] = nil
		end
		local y, count = 0, 0
		for i = self.offset + 1, total do
			local item = items[i]
			local kind = kindOf(item)
			local pool = self.pools[kind]
			local h = pool.height
			if count > 0 and y + h > room then
				break
			end
			taken[kind] = (taken[kind] or 0) + 1
			local frame = pool[taken[kind]]
			if not frame then
				frame = kinds[kind].make(self)
				pool[taken[kind]] = frame
			end
			frame:ClearAllPoints()
			frame:SetPoint("TOPLEFT", 0, -y)
			frame:SetPoint("RIGHT", self, "RIGHT", -8, 0)
			frame:SetHeight(h)
			fillItem(frame, item)
			frame:Show()
			shown[#shown + 1] = { frame, item }
			y, count = y + h, count + 1
		end
		for kind, pool in pairs(self.pools) do
			for i = (taken[kind] or 0) + 1, #pool do
				pool[i]:Hide()
			end
		end
		if total > count then
			local size = max(20, room * count / total)
			thumb:SetHeight(size)
			thumb:ClearAllPoints()
			thumb:SetPoint("TOPRIGHT", 0, -(room - size) * self.offset / max(1, total - count))
			thumb:Show()
			track:Show()
		else
			thumb:Hide()
			track:Hide()
		end
	end

	-- Refills the shown frames (the ScrollBox's ReinitializeFrames).
	function list:Reinitialize()
		self:Refresh()
	end

	function list:ForEachFrame(fn)
		for _, entry in ipairs(self.shown) do
			fn(entry[1], entry[2])
		end
	end

	function list:Clear()
		self:SetItems({}, "")
	end

	list:SetScript("OnMouseWheel", function(self, delta)
		self.offset = self.offset - delta
		self:Refresh()
	end)
	list:SetScript("OnSizeChanged", list.Refresh)
	list:SetScript("OnShow", list.Refresh)
	return list
end

-- "5m", "1h 10m"
function W.Age(seconds)
	local m = floor(seconds / 60)
	if m < 1 then
		return "now"
	end
	if m < 60 then
		return m .. "m"
	end
	return floor(m / 60) .. "h " .. (m % 60) .. "m"
end

function W.RowHighlight(row)
	local hl = row:CreateTexture(nil, "HIGHLIGHT")
	hl:SetAllPoints()
	if not W.Atlas(hl, "groupfinder-highlightbar-blue") then
		hl:SetColorTexture(0.3, 0.5, 1, 0.12)
	end
	return hl
end
