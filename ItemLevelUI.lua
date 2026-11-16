-------------------------------------------------------------------------------
--  ItemLevelUI.lua -- the item level spots (ns.ILvlUI): player tooltip, Inspect window,
--  character sheet, item tooltip. Each one is an independent installer (a failure in one
--  never stops the next), its hooks installed once and gated by its setting at the moment
--  it acts (ns.Settings.Get, read live). The data comes from ItemLevel.lua (ns.ILvl).
--  Nothing of Blizzard's data is written: every spot adds its own text or frames (the
--  sheet row also moves the stats rows' anchors to make room for itself).
-------------------------------------------------------------------------------
local _, ns = ...

local UI = {}
ns.ILvlUI = UI

UI.failed = {} -- spot name -> why it isn't installed
local installed = {}

local function Secret(v)
	return issecretvalue ~= nil and issecretvalue(v)
end

--- "Item Level N" as the game words it (its globals at runtime, a plain fallback).
function UI.Text(n)
	n = math.floor(n)
	if type(ITEM_LEVEL) == "string" and not Secret(ITEM_LEVEL) and ITEM_LEVEL:find("%d", 1, true) then
		return (ITEM_LEVEL:format(n))
	end
	if type(STAT_AVERAGE_ITEM_LEVEL) == "string" and not Secret(STAT_AVERAGE_ITEM_LEVEL) then
		return STAT_AVERAGE_ITEM_LEVEL .. " " .. n
	end
	return "Item Level " .. n
end

--- "Talents 36/12/3": the game's TALENTS label and the points per tree.
function UI.TalentText(list)
	local label = "Talents"
	if type(TALENTS) == "string" and not Secret(TALENTS) and not TALENTS:find("%", 1, true) then
		label = TALENTS
	end
	local parts = {}
	for i, n in ipairs(list) do
		parts[i] = tostring(math.floor(n))
	end
	return label .. " " .. table.concat(parts, "/")
end

--- The gold of the tooltip titles: r, g, b.
function UI.Gold()
	if type(NORMAL_FONT_COLOR) == "table" and type(NORMAL_FONT_COLOR.r) == "number" then
		return NORMAL_FONT_COLOR.r, NORMAL_FONT_COLOR.g, NORMAL_FONT_COLOR.b
	end
	return 1, 0.82, 0
end

--- Runs a spot's installer once. It returns false when a Blizzard hook point is missing;
--- an error is caught. Either way the failure is recorded and the next spot still installs.
function UI.Install(name, fn)
	if installed[name] then
		return true
	end
	local ok, result = pcall(fn)
	if not ok then
		UI.failed[name] = tostring(result)
		return false
	end
	if result == false then
		UI.failed[name] = "missing"
		return false
	end
	UI.failed[name] = nil
	installed[name] = true
	return true
end

-------------------------------------------------------------------------------
--  Player tooltip: a friendly player's gold "Item Level N" and "Talents a/b/c"
--  (yourself included), each line gated by its own setting
-------------------------------------------------------------------------------
local lineFor = nil -- the GUID GameTooltip got our lines for, in its current build
-- each line's text and its index (nil when unknown); ilvl first, talents last
local lines = { ilvl = {}, talents = {} }
local builds = 0 -- runs of our post-call (tells that a rebuild ran it)
local rebuilding = false -- inside our own RefreshData call

local function ResetLines()
	lineFor = nil
	lines.ilvl.text, lines.ilvl.index = nil, nil
	lines.talents.text, lines.talents.index = nil, nil
end

-- Adds one of our lines, once per build.
local function AddLine(tooltip, which, text)
	local l = lines[which]
	if l.text ~= nil then
		return
	end
	l.text = text
	tooltip:AddLine(text, UI.Gold())
	local n = tooltip.NumLines and tooltip:NumLines()
	l.index = type(n) == "number" and not Secret(n) and n or nil
end

-- A later inspect changed the value while our line shows: rewrite our own line in place
-- (only when that line still holds the text we put there).
local function UpdateLine(tooltip, which, text)
	local l = lines[which]
	if text == l.text or not l.index or not tooltip.GetName then
		return
	end
	local name = tooltip:GetName()
	local fs = type(name) == "string" and _G[name .. "TextLeft" .. l.index]
	if not (fs and fs.GetText and fs.SetText) then
		return
	end
	local current = fs:GetText()
	if Secret(current) or current ~= l.text then
		return
	end
	fs:SetText(text)
	l.text = text
	tooltip:Show()
end

local function OnTooltipUnit(tooltip)
	if tooltip ~= GameTooltip or not tooltip.GetUnit then
		return
	end
	builds = builds + 1
	ResetLines()
	local ilvlOn = ns.Settings.Get("ilvlPlayerTooltip")
	local specOn = ns.Settings.Get("specPoints")
	if not ilvlOn and not specOn then
		return
	end
	local _, unit = tooltip:GetUnit()
	if Secret(unit) or not unit or not ns.ILvl.Yes(UnitIsPlayer(unit)) or ns.ILvl.Hostile(unit) then
		return
	end
	local guid = UnitGUID(unit)
	lineFor = not Secret(guid) and guid or nil
	local ilvl = ilvlOn and ns.ILvl.Of(unit)
	if ilvl then
		AddLine(tooltip, "ilvl", UI.Text(ilvl))
	end
	local talents = specOn and ns.ILvl.TalentsOf(unit)
	if talents then
		AddLine(tooltip, "talents", UI.TalentText(talents))
	end
	local wantIlvl = ilvlOn and not ilvl
	local wantTalents = specOn and not ns.ILvl.TalentsKnown(unit)
	if wantIlvl or wantTalents then
		local me = UnitIsUnit(unit, "player")
		if not Secret(me) and not me then -- unreadable: no inspect
			ns.ILvl.RequestInspect(unit)
		end
	end
end

-- Rebuilds GameTooltip from its own data (the game's RefreshData), so our post-call adds both
-- lines in order, once. Out of combat only (a rebuild from our code can't handle secret line
-- data). True when our post-call ran.
local function Rebuild()
	local tip = GameTooltip
	if not (tip.RefreshData and tip.GetPrimaryTooltipInfo) or (InCombatLockdown and InCombatLockdown()) then
		return false
	end
	local okInfo, info = pcall(tip.GetPrimaryTooltipInfo, tip)
	if not okInfo or not info then
		return false -- nothing to rebuild from
	end
	local before = builds
	rebuilding = true
	local ok = pcall(tip.RefreshData, tip)
	rebuilding = false
	return ok and builds ~= before
end

-- The value came in after the tooltip was built and it still shows that player: rebuild it
-- (both lines in order), or where the game can't, add the lines (or update them, when a later
-- inspect changed a value). Fallback order rule: the talents line always goes last, and the
-- item level line is never added under it.
local function RefreshTooltip(guid)
	if rebuilding then
		return -- our own rebuild's post-call draws the lines
	end
	local ilvlOn = ns.Settings.Get("ilvlPlayerTooltip")
	local specOn = ns.Settings.Get("specPoints")
	if not ilvlOn and not specOn then
		return
	end
	if not (GameTooltip and GameTooltip:IsShown() and GameTooltip.GetUnit) then
		return
	end
	local _, unit = GameTooltip:GetUnit()
	if Secret(unit) or not unit then
		return
	end
	local g = UnitGUID(unit)
	if Secret(g) or not g or g ~= guid or ns.ILvl.Hostile(unit) then
		return
	end
	if lineFor ~= guid then
		ResetLines()
		lineFor = guid
	end
	local ilvl = ilvlOn and ns.ILvl.Of(unit)
	local talents = specOn and ns.ILvl.TalentsOf(unit)
	local ilvlText = ilvl and UI.Text(ilvl) or nil
	local talentText = talents and UI.TalentText(talents) or nil
	if ilvlText == lines.ilvl.text and talentText == lines.talents.text then
		return -- the tooltip already shows these
	end
	if Rebuild() then
		return
	end
	local added = false
	if ilvlText then
		if lines.ilvl.text then
			UpdateLine(GameTooltip, "ilvl", ilvlText)
		elseif not lines.talents.text then
			AddLine(GameTooltip, "ilvl", ilvlText)
			added = true
		end
	end
	if talentText then
		if lines.talents.text then
			UpdateLine(GameTooltip, "talents", talentText)
		else
			AddLine(GameTooltip, "talents", talentText)
			added = true
		end
	end
	if added then
		GameTooltip:Show()
	end
end

local function PlayerTooltip()
	if not (TooltipDataProcessor and Enum and Enum.TooltipDataType) then
		return false
	end
	TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Unit, OnTooltipUnit)
	ns.ILvl.OnLearned(function(guid)
		RefreshTooltip(guid)
	end)
	return true
end

-------------------------------------------------------------------------------
--  Inspect window: gold "Item Level N" at the top right, the game's own whole number
-------------------------------------------------------------------------------
-- Tuned in game: the strip between the title bar and the inset, top right. Never anchored
-- to or written on InspectLevelText.
local INSPECT_POINT = "BOTTOMRIGHT"
local INSPECT_REL = "TOPRIGHT"
local INSPECT_X = -6
local INSPECT_Y = 6
local ITEM_RETRIES = 3 -- 1 s apart, per GUID

local inspectText = nil
local retryGuid, retryToken, retryCount = nil, 0, 0

local UpdateInspect

local function WindowGuid()
	local unit = InspectFrame and InspectFrame.unit
	if Secret(unit) or not unit then
		return nil
	end
	local g = UnitGUID(unit)
	if Secret(g) or not g then
		return nil
	end
	return g
end

function UpdateInspect()
	if not inspectText then
		return
	end
	local unit = InspectFrame and InspectFrame.unit
	if not ns.Settings.Get("ilvlInspect") or Secret(unit) or not unit or not InspectFrame:IsShown() then
		inspectText:SetText("")
		return
	end
	local v = ns.ILvl.Inspected(unit)
	inspectText:SetText(v and UI.Text(v) or "")
	if v then
		return
	end
	local guid = WindowGuid()
	if not guid then
		return
	end
	if guid ~= retryGuid then
		retryGuid, retryCount = guid, 0
	end
	if retryCount >= ITEM_RETRIES then
		return
	end
	retryCount = retryCount + 1
	retryToken = retryToken + 1
	local token = retryToken
	C_Timer.After(1, function()
		if token == retryToken and WindowGuid() == guid then
			UpdateInspect()
		end
	end)
end

local function OnInspectHook()
	UpdateInspect()
	C_Timer.After(0, UpdateInspect) -- our INSPECT_READY listener may run after Blizzard's
end

local function OnInspectLoaded()
	local ok, err = pcall(function()
		if not (InspectPaperDollFrame and InspectFrame) or inspectText then
			return
		end
		local text = InspectPaperDollFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
		text:SetJustifyH("RIGHT")
		text:SetTextColor(UI.Gold())
		local rel = InspectFrame.Inset or InspectFrameInset
		if rel then
			text:SetPoint(INSPECT_POINT, rel, INSPECT_REL, INSPECT_X, INSPECT_Y)
		else
			text:SetPoint("TOPRIGHT", InspectFrame, "TOPRIGHT", -12, -32)
		end
		-- The hooks act only once inspectText is set (below, after they all went in).
		hooksecurefunc(InspectPaperDollFrame, "UpdateButtons", OnInspectHook)
		hooksecurefunc(InspectPaperDollFrame, "SetLevel", OnInspectHook)
		InspectFrame:HookScript("OnHide", function()
			retryGuid, retryCount = nil, 0
			retryToken = retryToken + 1
			if inspectText then
				inspectText:SetText("")
			end
		end)
		inspectText = text
	end)
	if not ok then
		-- The spot isn't installed after all: listed as failed only, its text never set.
		installed.inspect = nil
		UI.failed.inspect = tostring(err)
	end
end

local function InspectText()
	if not (EventUtil and EventUtil.ContinueOnAddOnLoaded) then
		return false
	end
	EventUtil.ContinueOnAddOnLoaded("Blizzard_InspectUI", OnInspectLoaded)
	ns.ILvl.OnLearned(function(guid)
		if WindowGuid() == guid then
			UpdateInspect()
		end
	end)
	ns.Settings.OnChange("ilvlInspect", UpdateInspect)
	return true
end

-------------------------------------------------------------------------------
--  Character sheet: our own "Item Level" row under Movement Speed
-------------------------------------------------------------------------------
-- Blizzard's stats list (elementData, data provider, the element tables) is read by
-- secure code, so nothing is added to it: an entry of ours there taints the sheet. Our row
-- is a frame of our own on the list's scroll target, made from Blizzard's stat row
-- template (same font, "Item Level:" label, striped background). After every update of
-- the list (each scroll and rebuild, a hooksecurefunc) we place it under Movement Speed
-- and move the rows' anchors to make room; their data is never touched. The list's scroll
-- range doesn't count our row, so the room is taken from below at the top of the list and
-- from above at its end, in proportion to the scroll position: every row stays reachable.
local ROW_EXTENT = 23 -- a stat row's height (CharacterStatFrameScrollBoxBaseElementTemplate)
local ROW_TEMPLATE = "CharacterStatFrameScrollBoxLabelElementTemplate"
local MOVESPEED = "MOVESPEED"

local sheetRow, sheetBox
local sheetRetry = false -- the one more try at login is queued
local sheetWanted = false -- the setting is on and the value known
local sheetMoved = false -- Blizzard's rows sit off their own spots (put back when the row goes)

local function Num(v, fallback)
	if type(v) ~= "number" or Secret(v) then
		return fallback
	end
	return v
end

local function SheetTooltip(self)
	local mine = ns.ILvl.Of("player")
	GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
	GameTooltip:SetText(mine and UI.Text(mine) or (STAT_AVERAGE_ITEM_LEVEL or "Item Level"), UI.Gold())
	local avg, equipped = nil, nil
	if GetAverageItemLevel then
		local ok, a, e = pcall(GetAverageItemLevel)
		if ok and type(a) == "number" and not Secret(a) and type(e) == "number" and not Secret(e) then
			avg, equipped = a, e
		end
	end
	if equipped then
		GameTooltip:AddLine(string.format("Equipped: %.1f", equipped), 1, 1, 1)
		GameTooltip:AddLine(string.format("Best you own (bags included): %.1f", avg), 0.65, 0.65, 0.65)
	end
	GameTooltip:Show()
end

-- Movement Speed's data index and its stripe number, read from Blizzard's list.
local function MoveSpeed(box)
	local dp = box.GetDataProvider and box:GetDataProvider()
	if not (dp and dp.FindByPredicate) then
		return nil
	end
	local index, data = dp:FindByPredicate(function(e)
		return type(e) == "table" and e.name == MOVESPEED
	end)
	return index, data and Num(data.statIndex, 0) or 0
end

-- Lays the shown rows out as the list does (from the scroll target's top, each row's own
-- height), with our row's room taken in; with no row, puts moved rows back once.
local function PlaceSheet()
	local box, row = sheetBox, sheetRow
	if not (box and row) then
		return
	end
	local view = box.GetView and box:GetView()
	local frames = view and view.GetFrames and view:GetFrames()
	local target = box.GetScrollTarget and box:GetScrollTarget()
	local moveIndex, stripe
	if sheetWanted and frames and target then
		moveIndex, stripe = MoveSpeed(box)
	end
	if not moveIndex then
		row:Hide()
		if not (sheetMoved and frames and target) then
			return
		end
	end
	local p = 0
	if moveIndex and box.GetScrollPercentage then
		p = math.min(1, math.max(0, Num(box:GetScrollPercentage(), 0)))
	end
	local up, down = ROW_EXTENT * p, ROW_EXTENT * (1 - p)
	local spacing = Num(view.GetSpacing and view:GetSpacing(), 0)
	local stretch = not (view.IsElementStretchDisabled and view:IsElementStretchDisabled())
	local offset, rowAt, lastIsMove = 0, nil, false
	for _, frame in ipairs(frames) do
		local index = frame.GetElementDataIndex and frame:GetElementDataIndex()
		local shift = 0
		if moveIndex and type(index) == "number" then
			if index > moveIndex then
				rowAt = rowAt or (offset - up)
				shift = down
			else
				shift = -up
				lastIsMove = index == moveIndex
			end
		end
		frame:ClearAllPoints()
		frame:SetPoint("TOPLEFT", target, "TOPLEFT", 0, -(offset + shift))
		if stretch then
			frame:SetPoint("TOPRIGHT", target, "TOPRIGHT", 0, -(offset + shift))
		end
		offset = offset + Num(frame.GetHeight and frame:GetHeight(), ROW_EXTENT) + spacing
	end
	if moveIndex and not rowAt and lastIsMove then
		rowAt = offset - up -- Movement Speed is the last row shown
	end
	sheetMoved = moveIndex ~= nil
	if not rowAt then
		row:Hide()
		return
	end
	row:ClearAllPoints()
	row:SetPoint("TOPLEFT", target, "TOPLEFT", 0, -rowAt)
	row:SetPoint("TOPRIGHT", target, "TOPRIGHT", 0, -rowAt)
	if row.Background then
		row.Background:SetShown((stripe + 1) % 2 == 1) -- the list's stripes: odd rows
	end
	row:Show()
end

local function UpdateSheet()
	if not sheetRow then
		return
	end
	local mine = ns.Settings.Get("ilvlCharacterSheet") and ns.ILvl.Of("player")
	sheetWanted = mine and true or false
	if mine then
		sheetRow.value:SetText(tostring(math.floor(mine)))
	end
	PlaceSheet()
end

-- Our row from Blizzard's stat row template; built by hand where the template is missing.
local function NewSheetRow(target)
	local ok, row = pcall(CreateFrame, "Frame", nil, target, ROW_TEMPLATE)
	if not (ok and row and row.Label and row.Value) then
		row = CreateFrame("Frame", nil, target)
		row:SetHeight(ROW_EXTENT)
		row.Background = row:CreateTexture(nil, "BACKGROUND")
		row.Background:SetPoint("CENTER")
		if row.Background.SetAtlas then
			pcall(row.Background.SetAtlas, row.Background, "UI-Character-Info-Line-Bounce2", true)
		end
		row.Label = row:CreateFontString(nil, "ARTWORK", "GameFontNormal")
		row.Label:SetPoint("LEFT", 11, 0)
		row.Value = row:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
		row.Value:SetPoint("RIGHT", -8, 0)
	end
	local label = type(STAT_AVERAGE_ITEM_LEVEL) == "string" and STAT_AVERAGE_ITEM_LEVEL or "Item Level"
	local fmt = type(STAT_FORMAT) == "string" and STAT_FORMAT or "%s:"
	row.Label:SetText(string.format(fmt, label))
	row.value = row.Value
	row:EnableMouse(true)
	row:SetScript("OnEnter", SheetTooltip)
	row:SetScript("OnLeave", function()
		GameTooltip:Hide()
	end)
	row:Hide()
	return row
end

local function CharacterSheet()
	local pane = CharacterStatsPaneScrollBox
	local box = pane and pane.ScrollBox
	if not (pane and pane.HookScript and box and box.GetScrollTarget and box.GetView) then
		-- Not defined yet at our load: one more try at login.
		if not sheetRetry and CreateFrame and not box then
			sheetRetry = true
			local f = CreateFrame("Frame")
			f:RegisterEvent("PLAYER_LOGIN")
			f:SetScript("OnEvent", function(self)
				self:UnregisterAllEvents()
				UI.Install("sheet", CharacterSheet)
			end)
		end
		return false
	end
	local target = box:GetScrollTarget()
	if not target then
		return false
	end
	sheetBox = box
	sheetRow = NewSheetRow(target)
	UI.sheetRow = sheetRow -- read by the smoke tests
	hooksecurefunc(box, "Update", function()
		pcall(PlaceSheet) -- never breaks Blizzard's update
	end)
	pane:HookScript("OnShow", UpdateSheet)
	local events = CreateFrame("Frame")
	for _, event in ipairs({ "PLAYER_EQUIPMENT_CHANGED", "PLAYER_AVERAGE_ITEM_LEVEL_UPDATE" }) do
		pcall(events.RegisterEvent, events, event)
	end
	events:SetScript("OnEvent", UpdateSheet)
	ns.Settings.OnChange("ilvlCharacterSheet", UpdateSheet)
	if pane.IsVisible and pane:IsVisible() then
		pcall(UpdateSheet) -- already open (a retry at login): drawn now, not at the next change
	end
	return true
end

-------------------------------------------------------------------------------
--  Item tooltips: gold "Item Level N" right under the name of gear, once per build
-------------------------------------------------------------------------------
local function EnumValue(group, key, default)
	local g = type(Enum) == "table" and Enum[group]
	local v = type(g) == "table" and g[key]
	return type(v) == "number" and v or default
end

local ITEM_DATA = EnumValue("TooltipDataType", "Item", 0)
local LINE_LEVEL = EnumValue("TooltipDataLineType", "ItemLevel", 31)
local WEAPON = EnumValue("ItemClass", "Weapon", 2)
local ARMOR = EnumValue("ItemClass", "Armor", 4)
local NO_LEVEL_SLOTS = {
	INVTYPE_BODY = true,
	INVTYPE_TABARD = true,
	INVTYPE_BAG = true,
	INVTYPE_QUIVER = true,
	INVTYPE_AMMO = true,
	INVTYPE_NON_EQUIP_IGNORE = true,
	[""] = true,
}

--- A plain value, or nil when it is secret.
local function Clear(v)
	if v == nil or Secret(v) then
		return nil
	end
	return v
end

--- The item level to show for a tooltip's item data: a whole number above 1, else nil.
local function ItemLevelFor(data)
	if Clear(data.type) ~= ITEM_DATA then
		return nil
	end
	local lines = Clear(data.lines)
	if type(lines) == "table" then
		for _, line in ipairs(lines) do
			if type(line) == "table" and Clear(line.type) == LINE_LEVEL then
				return nil
			end
		end
	end
	local item
	local guid = Clear(data.guid)
	if guid and C_Item and C_Item.GetItemLinkByGUID then
		item = Clear(C_Item.GetItemLinkByGUID(guid))
	end
	item = item or Clear(data.hyperlink) or Clear(data.id)
	if not item then
		return nil
	end
	local _, _, _, equipLoc, _, classID = C_Item.GetItemInfoInstant(item)
	if Clear(classID) ~= WEAPON and Clear(classID) ~= ARMOR then
		return nil
	end
	equipLoc = Clear(equipLoc)
	if type(equipLoc) ~= "string" or NO_LEVEL_SLOTS[equipLoc] then
		return nil
	end
	local level = Clear(data.overrideItemLevel)
	if type(level) ~= "number" then
		level = Clear((C_Item.GetDetailedItemLevelInfo(item)))
	end
	if type(level) == "number" and level > 1 then
		return math.floor(level)
	end
	return nil
end

local lastAdd = setmetatable({}, { __mode = "k" }) -- tooltip -> { info, index } of our last add

local function OnItemName(tooltip, lineData)
	pcall(function()
		if not ns.Settings.Get("ilvlItemTooltip") then
			return
		end
		if tooltip.IsForbidden and tooltip:IsForbidden() then
			return
		end
		if not tooltip.GetProcessingTooltipInfo then
			return
		end
		local info = tooltip:GetProcessingTooltipInfo()
		local data = info and info.tooltipData
		if type(data) ~= "table" then
			return
		end
		local index = type(lineData) == "table" and lineData.lineIndex or nil
		local last = lastAdd[tooltip]
		if last and last.info == info and last.index ~= index then
			return -- a second name line in the same build
		end
		local level = ItemLevelFor(data)
		if level then
			tooltip:AddLine(UI.Text(level), UI.Gold())
			lastAdd[tooltip] = { info = info, index = index }
		end
	end)
end

local function ItemTooltip()
	if
		not (
			TooltipDataProcessor
			and TooltipDataProcessor.AddLinePostCall
			and Enum
			and Enum.TooltipDataLineType
			and Enum.TooltipDataLineType.ItemName
		)
	then
		return false
	end
	TooltipDataProcessor.AddLinePostCall(Enum.TooltipDataLineType.ItemName, OnItemName)
	return true
end

function UI.Init()
	UI.Install("player", PlayerTooltip)
	UI.Install("inspect", InspectText)
	UI.Install("sheet", CharacterSheet)
	UI.Install("item", ItemTooltip)
end
