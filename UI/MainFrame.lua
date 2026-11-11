-------------------------------------------------------------------------------
--  UI/MainFrame.lua -- the preview stand-in (ns.UI), for development and for clients
--  without Forever's group finder: a copy of LFGParentFrame's layout (PortraitFrameTemplate, 458 wide,
--  right-side tabs Listing and Browse), whose Browse tab has the same header (Category and
--  Activity dropdowns, refresh) and list area (BackgroundArt at 4,-80) as LFGBrowseFrame,
--  so the table sits in it exactly as it does in game. It shows the sample listings.
-------------------------------------------------------------------------------
local _, ns = ...
local W, P = ns.W, ns.Preview
local wipe = W.wipe

local UI = { panels = {} }
ns.UI = UI

local WIDTH, HEIGHT, WIDE = 458, 535, 620
local TAB_SIZE, TAB_GAP = 40, 12
local PORTRAIT = "Interface\\LFGFrame\\UI-LFG-PORTRAIT"

local frame

-- key, title, icon, build(frame) -> panel frame, refresh(panel) on show, width, and the
-- tab's place (Forever's order: Listing, then Browse).
function UI.AddPanel(key, title, icon, build, refresh, width, order)
	UI.panels[#UI.panels + 1] =
		{ key = key, title = title, icon = icon, build = build, refresh = refresh, width = width, order = order or 2 }
	table.sort(UI.panels, function(a, b)
		return a.order < b.order
	end)
end

local function SetTitle(text)
	if frame.SetTitle then
		frame:SetTitle(text)
	elseif frame.TitleContainer and frame.TitleContainer.TitleText then
		frame.TitleContainer.TitleText:SetText(text)
	elseif frame.title then
		frame.title:SetText(text)
	end
end

local function SetPortrait()
	if frame.SetPortraitToAsset then
		frame:SetPortraitToAsset(PORTRAIT)
		return
	end
	local portrait = frame.PortraitContainer and frame.PortraitContainer.portrait or frame.portrait
	if portrait then
		portrait:SetTexture(PORTRAIT)
	end
end

-- Where the template is missing: a plain dark window with a title and a close button.
local function Fallback()
	local bg = frame:CreateTexture(nil, "BACKGROUND")
	bg:SetAllPoints()
	bg:SetColorTexture(0.08, 0.07, 0.06, 0.97)
	local border = W.Inset(frame)
	border:SetAllPoints()
	frame.title = W.Text(frame, "GameFontNormal", 13, "CENTER")
	frame.title:SetPoint("TOP", 0, -6)
	local close = W.Create("Button", frame, "UIPanelCloseButton")
	if not close:GetNormalTexture() then
		close:SetNormalTexture("Interface\\Buttons\\UI-Panel-MinimizeButton-Up")
		close:SetPushedTexture("Interface\\Buttons\\UI-Panel-MinimizeButton-Down")
		close:SetHighlightTexture("Interface\\Buttons\\UI-Panel-MinimizeButton-Highlight", "ADD")
	end
	close:SetSize(28, 28)
	close:SetPoint("TOPRIGHT", 2, 2)
	close:SetScript("OnClick", function()
		frame:Hide()
	end)
end

local function Select(index)
	W.CloseMenus()
	local p = UI.panels[index]
	frame:SetWidth(p.width or WIDTH)
	for i, other in ipairs(UI.panels) do
		local on = i == index
		if on and not other.frame then
			other.frame = other.build(frame)
			other.frame:SetAllPoints(frame)
		end
		if other.frame then
			other.frame:SetShown(on)
		end
		if other.tab then
			other.tab:SetChecked(on)
		end
	end
	UI.current = p.key
	SetTitle(LFG_TITLE or "Group Finder")
	if p.key == "browse" then
		ns.Table.ClearSelection() -- as Forever clears it whenever Browse is shown
	end
	if p.refresh then
		p.refresh(p.frame)
	end
end

local function MakeTab(i, p)
	local tab = CreateFrame("CheckButton", nil, frame)
	tab:SetSize(TAB_SIZE, TAB_SIZE)
	tab:SetPoint("TOPLEFT", frame, "TOPRIGHT", 0, -48 - (i - 1) * (TAB_SIZE + TAB_GAP))
	local back = tab:CreateTexture(nil, "BACKGROUND")
	back:SetTexture("Interface\\SpellBook\\SpellBook-SkillLineTab")
	back:SetSize(TAB_SIZE * 1.6, TAB_SIZE * 1.6)
	back:SetPoint("TOPLEFT", -3, TAB_SIZE * 0.3)
	local icon = tab:CreateTexture(nil, "ARTWORK")
	icon:SetAllPoints()
	icon:SetTexture(p.icon)
	tab:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
	tab:SetCheckedTexture("Interface\\Buttons\\CheckButtonHilight", "ADD")
	tab:SetScript("OnClick", function()
		Select(i)
	end)
	W.Tooltip(tab, p.title)
	p.tab = tab
end

local function Build()
	frame = W.Create("Frame", UIParent, "PortraitFrameTemplate")
	_G.TerribleGroupFinderFrame = frame
	frame:SetSize(WIDTH, HEIGHT)
	frame:SetPoint("TOPLEFT", 40, -110)
	frame:SetFrameStrata("HIGH")
	frame:SetToplevel(true)
	frame:SetClampedToScreen(true)
	frame:EnableMouse(true)
	frame:SetMovable(true)
	frame:RegisterForDrag("LeftButton")
	frame:SetScript("OnDragStart", frame.StartMoving)
	frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
	frame:HookScript("OnHide", W.CloseMenus)
	if not (frame.NineSlice or frame.TitleContainer or frame.CloseButton) then
		Fallback()
	else
		SetPortrait()
	end
	if UISpecialFrames then
		table.insert(UISpecialFrames, "TerribleGroupFinderFrame")
	end

	local banner = W.Text(frame, "GameFontNormalSmall", 10, "RIGHT")
	banner:SetPoint("TOPRIGHT", -30, -6)
	banner:SetText("|cffff8000PREVIEW|r |cff999999stand-in for the game's Group Finder|r")

	for i, p in ipairs(UI.panels) do
		MakeTab(i, p)
	end
	frame:Hide()
end

function UI.Show(key)
	if not frame then
		Build()
	end
	local index = 1
	for i, p in ipairs(UI.panels) do
		if p.key == key then
			index = i
		end
	end
	frame:Show()
	Select(index)
end

function UI.Toggle(key)
	if frame and frame:IsShown() and UI.current == key then
		frame:Hide()
	else
		UI.Show(key)
	end
end

function UI.Refresh()
	ns.Table.RefreshAll()
	if not (frame and frame:IsShown()) then
		return
	end
	for _, p in ipairs(UI.panels) do
		if p.key == UI.current and p.refresh then
			p.refresh(p.frame)
		end
	end
end

-------------------------------------------------------------------------------
--  The stand-in's Browse tab: LFGBrowseFrame's header over the table
-------------------------------------------------------------------------------
local category = 2
local activities = {}
local tbl, categoryDrop, activityDrop

local function CategoryName(id)
	for _, c in ipairs(P.categories) do
		if c.id == id then
			return c.name
		end
	end
	return "?"
end

local function ActivityLabel()
	local n, only = 0, nil
	for key in pairs(activities) do
		n, only = n + 1, key
	end
	if n == 0 then
		return "All activities"
	end
	if n == 1 then
		return P.activities[only].name
	end
	return n .. " activities"
end

local function RefreshBrowse()
	if not tbl then
		return
	end
	categoryDrop:SetLabel(CategoryName(category))
	activityDrop:SetLabel(ActivityLabel())
	tbl:Refresh()
end

local function BuildBrowse(parent)
	local panel = CreateFrame("Frame", nil, parent)

	local stone = panel:CreateTexture(nil, "BACKGROUND")
	stone:SetPoint("TOPLEFT", 2, -21)
	stone:SetPoint("TOPRIGHT", -2, -21)
	stone:SetHeight(52)
	if not W.Atlas(stone, "groupfinder-Stat-StoneBG") then
		stone:SetColorTexture(0.15, 0.13, 0.11, 0.9)
	end

	local art = CreateFrame("Frame", nil, panel)
	art:SetPoint("TOPLEFT", 4, -80)
	art:SetPoint("BOTTOMRIGHT", -4, 3)
	local artTex = art:CreateTexture(nil, "BACKGROUND")
	artTex:SetAllPoints()
	if not W.Atlas(artTex, "groupfinder-background") then
		artTex:SetColorTexture(0.05, 0.05, 0.05, 0.6)
	end
	-- Forever's border (common-insideframe) and the two lines: BarTop under the column
	-- headers, BarMiddle above the bottom bar.
	local border = art:CreateTexture(nil, "BORDER")
	if W.Atlas(border, "common-insideframe") then
		border:SetPoint("TOPLEFT", 0, 2)
		border:SetPoint("BOTTOMRIGHT", 0, 0)
	end
	local barTop = art:CreateTexture(nil, "OVERLAY")
	if not W.Atlas(barTop, "groupfinder-ScrollLine") then
		barTop:SetColorTexture(0.35, 0.3, 0.2, 0.8)
		barTop:SetHeight(1)
	end
	barTop:SetPoint("LEFT", art, "TOPLEFT", 0, -20)
	barTop:SetPoint("RIGHT", art, "TOPRIGHT", 0, -20)
	local barMiddle = art:CreateTexture(nil, "OVERLAY")
	if not W.Atlas(barMiddle, "groupfinder-ScrollLine") then
		barMiddle:SetColorTexture(0.35, 0.3, 0.2, 0.8)
		barMiddle:SetHeight(1)
	end
	barMiddle:SetPoint("LEFT", panel, "BOTTOMLEFT", 0, 61)
	barMiddle:SetPoint("RIGHT", panel, "BOTTOMRIGHT", 0, 61)

	categoryDrop = W.Dropdown(panel, 140, function()
		local items = {}
		for _, c in ipairs(P.categories) do
			items[#items + 1] = { text = c.name, value = c.id, checked = category == c.id }
		end
		return items
	end, function(value)
		if category ~= value then
			wipe(activities)
		end
		category = value
		RefreshBrowse()
	end)
	categoryDrop:SetPoint("TOPLEFT", 70, -43)

	activityDrop = W.Dropdown(panel, 180, function()
		local acts = {}
		for _, a in pairs(P.activities) do
			if a.category == category then
				acts[#acts + 1] = a
			end
		end
		table.sort(acts, function(x, y)
			if x.minLevel ~= y.minLevel then
				return x.minLevel < y.minLevel
			end
			return x.name < y.name
		end)
		local items = { { text = "All activities", value = false, checked = next(activities) == nil } }
		for _, a in ipairs(acts) do
			items[#items + 1] = { text = a.name, value = a.key, checked = activities[a.key] == true, multi = true }
		end
		return items
	end, function(value)
		if value then
			activities[value] = not activities[value] or nil
		else
			wipe(activities)
		end
		RefreshBrowse()
	end)
	activityDrop:SetPoint("LEFT", categoryDrop, "RIGHT", 15, 0)

	local refresh = W.Button(panel, "", 26, 22, function()
		ns.Table.RelistOneHidden(ns.state.listings)
		ns.Table.ClearSelection()
		ns.Print("preview: in game this is Forever's own refresh button, which searches again.")
		RefreshBrowse()
	end)
	refresh:SetPoint("LEFT", activityDrop, "RIGHT", 9, 0)
	local icon = refresh:CreateTexture(nil, "OVERLAY")
	icon:SetSize(16, 16)
	icon:SetPoint("CENTER")
	icon:SetTexture("Interface\\Buttons\\UI-RefreshButton")
	W.Tooltip(refresh, "Refresh", "Search again.")

	tbl = ns.Table.Attach(panel, art, {
		listings = function()
			return ns.PreviewListings(category, activities)
		end,
		preview = function()
			return true
		end,
		failed = function()
			return false
		end,
		refreshAnchor = refresh,
	})
	return panel
end

UI.AddPanel("browse", "Browse", "Interface\\Icons\\INV_Misc_Spyglass_02", BuildBrowse, RefreshBrowse, WIDE)

-------------------------------------------------------------------------------
--  The stand-in's Messages tab (in game it is a fourth side tab on Forever's window)
-------------------------------------------------------------------------------
local refreshMessages

local function BuildMessages(parent)
	local panel = CreateFrame("Frame", nil, parent)
	local back = panel:CreateTexture(nil, "BACKGROUND")
	back:SetPoint("TOPLEFT", 4, -60)
	back:SetPoint("BOTTOMRIGHT", -4, 3)
	if not W.Atlas(back, "groupfinder-background") then
		back:SetColorTexture(0.05, 0.05, 0.05, 0.6)
	end
	local content = CreateFrame("Frame", nil, panel)
	content:SetPoint("TOPLEFT", 16, -70)
	content:SetPoint("BOTTOMRIGHT", -16, 16)
	refreshMessages = ns.Messages.BuildPanel(content)
	return panel
end

UI.AddPanel("messages", "Messages", "Interface\\Icons\\INV_Letter_15", BuildMessages, function()
	if refreshMessages then
		refreshMessages()
	end
end, nil, 3)
