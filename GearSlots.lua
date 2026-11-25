-------------------------------------------------------------------------------
--  GearSlots.lua -- per-slot gear data (ns.GearSlots): one equipped slot's item level and
--  enchant, for the character sheet and the Inspect window (slotItemLevel, slotEnchants).
--  The data half (down to /tgf gear) is stateless and draws nothing; the overlay half
--  below it draws one frame of ours per slot button, with per-kind state.
--
--  - the level comes from C_Item.GetDetailedItemLevelInfo(link), the same source
--    ILvl.Read uses, so a slot's level and the overall figure agree
--  - the enchant text is the tooltip data's ItemEnchantmentPermanent line with the game's
--    "Enchanted: " prefix stripped; whether an enchant exists at all comes from the item
--    string's second field (item:<id>:<enchantID>)
--  - whether Forever lets a slot be enchanted has no API: a static table (ENCHANTABLE),
--    the ranged slot only for bows, guns and crossbows
--  - a slot whose item data hasn't loaded reads as pending, never as "no enchant"
--
--  No inspects of its own (no NotifyInspect, no ClearInspectPlayer, no use of the quiet
--  queue), and no gear data is cached: every read asks the game.
-------------------------------------------------------------------------------
local _, ns = ...

local GS = {}
ns.GearSlots = GS

local function Secret(v)
	return issecretvalue ~= nil and issecretvalue(v)
end

--- A plain value, or nil when it is nil or secret.
local function Clear(v)
	if v == nil or Secret(v) then
		return nil
	end
	return v
end

local function EnumValue(group, key, default)
	local g = type(Enum) == "table" and Enum[group]
	local v = type(g) == "table" and g[key]
	return type(v) == "number" and v or default
end

local LINE_ENCHANT = EnumValue("TooltipDataLineType", "ItemEnchantmentPermanent", 15)
local WEAPON_CLASS = 2

-- Every slot but the shirt (4); the tabard (19) and ammo (0) never.
GS.SHOWN = { 1, 2, 3, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18 }
GS.SHOW = {}
for _, slot in ipairs(GS.SHOWN) do
	GS.SHOW[slot] = true
end

-- Slots Forever lets an enchanter enchant: vanilla's, plus Forever's neck and off-hand enchants
-- (any off-hand item: weapons, shields, held-in-off-hand). Never the belt, rings, trinkets,
-- shirt or tabard, nor the shoulders (their enchants come only from a reputation, so a missing
-- one isn't flagged; an enchanted shoulder still shows its enchant).
local ENCHANTABLE = {
	[1] = true,
	[2] = true,
	[5] = true,
	[7] = true,
	[8] = true,
	[9] = true,
	[10] = true,
	[15] = true,
	[16] = true,
	[17] = true,
}
-- Ranged weapon subclasses that take a scope: bows, guns, crossbows (not wands 19,
-- thrown 16, relics).
local RANGED_ENCHANTABLE = { [2] = true, [3] = true, [18] = true }

--- Whether Forever lets this slot be enchanted (the ranged slot by the item's subclass).
function GS.Enchantable(slot, link)
	if ENCHANTABLE[slot] then
		return true
	end
	if slot ~= 18 or link == nil or Secret(link) then
		return false
	end
	local fn = C_Item and C_Item.GetItemInfoInstant
	if not fn then
		return false
	end
	local ok, _, _, _, _, _, classID, subclassID = pcall(fn, link)
	if not ok then
		return false
	end
	classID, subclassID = Clear(classID), Clear(subclassID)
	return classID == WEAPON_CLASS and RANGED_ENCHANTABLE[subclassID] == true
end

--- The enchant ID in an item link's second field (0 when none).
local function EnchantID(link)
	if Secret(link) or type(link) ~= "string" then
		return 0
	end
	local ok, capture = pcall(string.match, link, "item:%-?%d+:(%-?%d*)")
	if not ok then
		return 0
	end
	return tonumber(Clear(capture)) or 0
end

local prefixPattern
local function EnchantPrefixPattern()
	if prefixPattern then
		return prefixPattern
	end
	local fmt = ENCHANTED_TOOLTIP_LINE
	if type(fmt) == "string" and not Secret(fmt) then
		local before, after = fmt:match("^(.-)%%s(.*)$")
		if before then
			local function Escape(s)
				return (s:gsub("[%^%$%(%)%%%.%[%]%*%+%-%?]", "%%%0"))
			end
			prefixPattern = "^" .. Escape(before) .. "(.+)" .. Escape(after) .. "$"
			return prefixPattern
		end
	end
	prefixPattern = "^Enchanted: (.+)$"
	return prefixPattern
end

--- The enchant line of a slot's item tooltip with the game's prefix stripped, else nil.
local function EnchantText(unit, slot)
	local fn = C_TooltipInfo and C_TooltipInfo.GetInventoryItem
	if not fn then
		return nil
	end
	local ok, data = pcall(fn, unit, slot)
	data = ok and Clear(data) or nil
	if type(data) ~= "table" then
		return nil
	end
	local lines = Clear(data.lines)
	if type(lines) ~= "table" then
		return nil
	end
	for _, line in ipairs(lines) do
		if type(line) == "table" and Clear(line.type) == LINE_ENCHANT then
			local text = Clear(line.leftText)
			if type(text) == "string" and text ~= "" then
				local stripped = text:match(EnchantPrefixPattern())
				return stripped or text
			end
		end
	end
	return nil
end

--- One slot of a unit: { slot, state, ... } with state "secret", "empty", "pending"
--- (item data not loaded yet: show nothing) or "known", which also has link, level,
--- quality, enchantID (0 = none), enchantText (or nil) and enchantable.
function GS.Read(unit, slot)
	local r = { slot = slot }
	local id = GetInventoryItemID and GetInventoryItemID(unit, slot)
	local link = GetInventoryItemLink(unit, slot)
	if Secret(id) or Secret(link) then
		r.state = "secret"
		return r
	end
	if not id and not link then
		r.state = "empty"
		return r
	end
	r.id = id
	local level
	if link then
		level = Clear((C_Item.GetDetailedItemLevelInfo(link)))
	end
	if type(level) ~= "number" then
		r.state = "pending"
		return r
	end
	r.state = "known"
	r.link = link
	r.level = level
	local quality = Clear(GetInventoryItemQuality and GetInventoryItemQuality(unit, slot))
	if quality == nil then
		quality = Clear(select(3, C_Item.GetItemInfo(link)))
	end
	r.quality = quality
	r.enchantID = EnchantID(link)
	r.enchantText = EnchantText(unit, slot)
	r.enchantable = GS.Enchantable(slot, link)
	return r
end

-------------------------------------------------------------------------------
--  /tgf gear: prints what the slot overlays read
-------------------------------------------------------------------------------
local function Print(...)
	ns.Print("|cffffd100gear|r", ...)
end

local function Present(name, v)
	return v and name or (name .. " |cffff6060(missing)|r")
end

local function ProbeUnit(unit, label)
	local header = label
	if not UnitIsUnit(unit, "player") then
		header = header .. " | inspect answered: " .. (ns.ILvl.InspectReadyFor(unit) and "yes" or "no")
	end
	Print(header)
	for _, slot in ipairs(GS.SHOWN) do
		local name = (ns.ILvl.SLOT_NAMES[slot] or "?") .. " (" .. slot .. ")"
		local ok, r = pcall(GS.Read, unit, slot)
		if not ok then
			Print("  " .. name .. ": error " .. tostring(r))
		elseif r.state == "secret" then
			Print("  " .. name .. ": secret")
		elseif r.state == "pending" then
			Print("  " .. name .. ": pending (item data not loaded)")
		elseif r.state == "known" then
			local sockets = "?"
			local fn = C_Item and C_Item.GetItemNumSockets
			if fn then
				local sok, n = pcall(fn, r.link)
				n = sok and Clear(n) or nil
				if n ~= nil then
					sockets = tostring(n)
				end
			end
			Print(
				string.format(
					'  %s: ilvl %d | q%s | enchant ID %d | line "%s" | sockets %s | enchantable %s',
					name,
					math.floor(r.level),
					tostring(r.quality or "?"),
					r.enchantID,
					r.enchantText or "none",
					sockets,
					r.enchantable and "yes" or "no"
				)
			)
		end
	end
end

--- /tgf gear: prints your slots, and the inspected player's while the Inspect window shows.
function GS.Probe()
	Print("APIs: " .. table.concat({
		Present("C_TooltipInfo.GetInventoryItem", C_TooltipInfo and C_TooltipInfo.GetInventoryItem),
		Present("C_Item.GetDetailedItemLevelInfo", C_Item and C_Item.GetDetailedItemLevelInfo),
		Present("C_Item.GetItemNumSockets", C_Item and C_Item.GetItemNumSockets),
		Present(
			"Enum.TooltipDataLineType.ItemEnchantmentPermanent",
			type(Enum) == "table"
				and type(Enum.TooltipDataLineType) == "table"
				and Enum.TooltipDataLineType.ItemEnchantmentPermanent
		),
	}, ", "))
	ProbeUnit("player", "You")
	local unit = InspectFrame and InspectFrame:IsShown() and Clear(InspectFrame.unit)
	if unit then
		local name = Clear(UnitName(unit)) or "?"
		ProbeUnit(unit, "Inspected: " .. name)
	else
		Print("Inspect window closed: open it on a player to probe their slots.")
	end
	local failed = ns.ILvlUI and ns.ILvlUI.failed
	if failed then
		for name, why in pairs(failed) do
			if tostring(name):sub(1, 5) == "slots" then
				Print("installer " .. name .. " failed: " .. tostring(why))
			end
		end
	end
end

-------------------------------------------------------------------------------
--  Overlays: one frame of ours per slot button, never a field on Blizzard's button
-------------------------------------------------------------------------------
-- Layout: offsets and widths of the slot text, in px.
local SIDE_GAP = 5 -- px between a column's icon and its text, toward the model
local ABOVE_GAP = 4 -- px between a weapon's icon and the text above it
local LINE_GAP = 1
local SIDE_WIDTH = 80 -- left and right columns
local ABOVE_WIDTH = 42 -- the weapons (main hand, off hand, ranged): text above the icon
local LEVEL_ABOVE = 5 -- our frame's level over the button's
local ITEM_RETRIES = 3

local LAYOUT = {
	[1] = "left",
	[2] = "left",
	[3] = "left",
	[15] = "left",
	[5] = "left",
	[9] = "left",
	[10] = "right",
	[6] = "right",
	[7] = "right",
	[8] = "right",
	[11] = "right",
	[12] = "right",
	[13] = "right",
	[14] = "right",
	[16] = "above",
	[17] = "above",
	[18] = "above",
}

local overlays = setmetatable({}, { __mode = "k" })
local kindOf = setmetatable({}, { __mode = "k" })
local shownGuid = {}
local retry = {
	player = { token = 0, count = 0, waiting = false },
	inspect = { token = 0, count = 0, waiting = false },
	-- the inspect answer not in yet: its own budget, so it never uses up the item-load retries
	inspectReady = { token = 0, count = 0, waiting = false },
}
-- Kinds with a slot waiting on item data: GET_ITEM_INFO_RECEIVED redraws only these.
local awaitingItems = { player = false, inspect = false }

local function NewString(frame)
	local fs = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	fs:SetWordWrap(false)
	if fs.SetMaxLines then
		fs:SetMaxLines(1)
	end
	return fs
end

local function Overlay(button)
	local o = overlays[button]
	if o then
		return o
	end
	o = CreateFrame("Frame", nil, button)
	o:SetAllPoints(button)
	o:SetFrameLevel(button:GetFrameLevel() + LEVEL_ABOVE)
	o:EnableMouse(false)
	local a, b = NewString(o), NewString(o)
	local side = LAYOUT[Clear(button:GetID())] or "left"
	if side == "left" then
		a:SetPoint("TOPLEFT", button, "TOPRIGHT", SIDE_GAP, -2)
		a:SetJustifyH("LEFT")
		a:SetWidth(SIDE_WIDTH)
		b:SetPoint("TOPLEFT", a, "BOTTOMLEFT", 0, -LINE_GAP)
		b:SetJustifyH("LEFT")
		b:SetWidth(SIDE_WIDTH)
	elseif side == "above" then
		a:SetPoint("BOTTOM", button, "TOP", 0, ABOVE_GAP)
		a:SetJustifyH("CENTER")
		a:SetWidth(ABOVE_WIDTH)
		b:SetPoint("BOTTOM", a, "TOP", 0, LINE_GAP)
		b:SetJustifyH("CENTER")
		b:SetWidth(ABOVE_WIDTH)
	else
		a:SetPoint("TOPRIGHT", button, "TOPLEFT", -SIDE_GAP, -2)
		a:SetJustifyH("RIGHT")
		a:SetWidth(SIDE_WIDTH)
		b:SetPoint("TOPRIGHT", a, "BOTTOMRIGHT", 0, -LINE_GAP)
		b:SetJustifyH("RIGHT")
		b:SetWidth(SIDE_WIDTH)
	end
	o.a, o.b = a, b
	o:Hide()
	overlays[button] = o
	return o
end

local function Blank(o)
	o.a:SetText("")
	o.b:SetText("")
	o:Hide()
end

local function ClearKind(kind)
	for button, o in pairs(overlays) do
		if kindOf[button] == kind then
			Blank(o)
		end
	end
end

local function QualityColor(q)
	if type(q) == "number" and C_Item and C_Item.GetItemQualityColor then
		local ok, r, g, b = pcall(C_Item.GetItemQualityColor, q)
		r, g, b = Clear(r), Clear(g), Clear(b)
		if ok and r and g and b then
			return r, g, b
		end
	end
	local c = type(q) == "number" and ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[q]
	if c then
		return c.r, c.g, c.b
	end
	return 1, 1, 1
end

local function Rgb(color, r, g, b)
	if color and color.GetRGB then
		return color:GetRGB()
	end
	return r, g, b
end

--- The lines a known slot shows, in order: item level, then enchant.
local function Lines(r)
	local list = {}
	if ns.Settings.Get("slotItemLevel") then
		local cr, cg, cb = QualityColor(r.quality)
		list[#list + 1] = { tostring(math.floor(r.level)), cr, cg, cb }
	end
	if ns.Settings.Get("slotEnchants") then
		if r.enchantText then
			list[#list + 1] = { r.enchantText, Rgb(GREEN_FONT_COLOR, 0.1, 1, 0.1) }
		elseif r.enchantID > 0 then
			list[#list + 1] = { "Enchanted", Rgb(GREEN_FONT_COLOR, 0.1, 1, 0.1) }
		elseif r.enchantable then
			list[#list + 1] = { "No enchant", Rgb(RED_FONT_COLOR, 1, 0.1, 0.1) }
		end
	end
	return list
end

local function SetLine(fs, entry)
	if entry then
		fs:SetText(entry[1])
		fs:SetTextColor(entry[2], entry[3], entry[4])
	else
		fs:SetText("")
	end
end

local function Show(o, button, list)
	if #list == 0 then
		Blank(o)
		return
	end
	local first, second = list[1], list[2]
	if second and LAYOUT[Clear(button:GetID())] == "above" then
		-- stacked upward: the enchant sits nearest the icon, the level on top
		first, second = second, first
	end
	SetLine(o.a, first)
	SetLine(o.b, second)
	o:Show()
end

local RedrawKind

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

local function Schedule(kind, key)
	key = key or kind
	local rt = retry[key]
	if rt.waiting or rt.count >= ITEM_RETRIES then
		return
	end
	rt.count = rt.count + 1
	rt.waiting = true
	rt.token = rt.token + 1
	local token = rt.token
	local guid = shownGuid[kind]
	C_Timer.After(1, function()
		pcall(function()
			if token ~= rt.token then
				return
			end
			rt.waiting = false
			-- a retry scheduled while the window had no GUID yet re-checks on fire
			if kind == "inspect" and guid ~= nil and WindowGuid() ~= guid then
				return
			end
			RedrawKind(kind)
		end)
	end)
end

local function Cancel(kind)
	for _, key in ipairs(kind == "inspect" and { "inspect", "inspectReady" } or { kind }) do
		local rt = retry[key]
		rt.token = rt.token + 1
		rt.waiting = false
		rt.count = 0
	end
end

--- Asks the game to load a pending slot's item data; the answer comes as
--- GET_ITEM_INFO_RECEIVED (no polling, no inspect).
local function RequestItem(r)
	local fn = C_Item and C_Item.RequestLoadItemDataByID
	local id = Clear(r.id)
	if fn and type(id) == "number" then
		pcall(fn, id)
	end
end

--- Draws one slot button's overlay (always called under pcall).
local function Draw(button)
	local o, kind = overlays[button], kindOf[button]
	if not o or not kind then
		return
	end
	if not (ns.Settings.Get("slotItemLevel") or ns.Settings.Get("slotEnchants")) then
		Blank(o)
		return
	end
	local slot = Clear(button:GetID())
	if not slot or not GS.SHOW[slot] then
		Blank(o)
		return
	end
	local unit = "player"
	if kind == "inspect" then
		unit = Clear(InspectFrame and InspectFrame.unit)
		if not unit or not InspectFrame:IsShown() then
			Blank(o)
			return
		end
		local guid = WindowGuid()
		if guid ~= shownGuid.inspect then
			ClearKind("inspect")
			Cancel("inspect")
			shownGuid.inspect = guid
		end
		if not ns.ILvl.InspectReadyFor(unit) then
			Blank(o)
			Schedule("inspect", "inspectReady")
			return
		end
	end
	local r = GS.Read(unit, slot)
	if r.state == "known" then
		Show(o, button, Lines(r))
	elseif r.state == "pending" then
		Blank(o)
		awaitingItems[kind] = true
		RequestItem(r)
		Schedule(kind)
	else
		Blank(o)
	end
end

function RedrawKind(kind)
	awaitingItems[kind] = false
	for button in pairs(overlays) do
		if kindOf[button] == kind then
			pcall(Draw, button)
		end
	end
end

local function RedrawAll()
	RedrawKind("player")
	RedrawKind("inspect")
end

local function OnSlotUpdate(button, kind, namePattern)
	pcall(function()
		local name = button.GetName and button:GetName()
		if type(name) ~= "string" or Secret(name) or not name:match(namePattern) then
			return
		end
		local slot = Clear(button:GetID())
		if not slot or not GS.SHOW[slot] then
			return
		end
		Overlay(button)
		kindOf[button] = kind
		if not retry[kind].waiting then
			retry[kind].count = 0
		end
		if kind == "inspect" and not retry.inspectReady.waiting then
			retry.inspectReady.count = 0
		end
		Draw(button)
	end)
end

-- A slow inspect answer: one redraw after the inspect guard has recorded it.
local readyFrame = CreateFrame("Frame")
readyFrame:RegisterEvent("INSPECT_READY")
readyFrame:RegisterEvent("GET_ITEM_INFO_RECEIVED")
local itemRedrawQueued = false
readyFrame:SetScript("OnEvent", function(_, event, guid)
	if event == "GET_ITEM_INFO_RECEIVED" then
		-- an item some shown slot waits on may have arrived: one coalesced redraw a frame later
		if itemRedrawQueued or not (awaitingItems.player or awaitingItems.inspect) then
			return
		end
		itemRedrawQueued = true
		C_Timer.After(0, function()
			itemRedrawQueued = false
			if awaitingItems.player then
				pcall(RedrawKind, "player")
			end
			if awaitingItems.inspect then
				pcall(RedrawKind, "inspect")
			end
		end)
		return
	end
	if guid ~= nil and not Secret(guid) and guid == WindowGuid() then
		C_Timer.After(0, function()
			pcall(RedrawKind, "inspect")
		end)
	end
end)

-------------------------------------------------------------------------------
--  Installers
-------------------------------------------------------------------------------
local function SheetSlots()
	if not hooksecurefunc or type(PaperDollItemSlotButton_Update) ~= "function" then
		return false
	end
	hooksecurefunc("PaperDollItemSlotButton_Update", function(button)
		OnSlotUpdate(button, "player", "^Character.+Slot$")
	end)
	return true
end

local inspectHooked = false

local function OnInspectLoaded()
	local ok, err = pcall(function()
		if inspectHooked then
			return
		end
		if type(InspectPaperDollItemSlotButton_Update) ~= "function" or not InspectFrame then
			ns.ILvlUI.failed.slotsInspect = "missing"
			return
		end
		hooksecurefunc("InspectPaperDollItemSlotButton_Update", function(button)
			OnSlotUpdate(button, "inspect", "^Inspect.+Slot$")
		end)
		InspectFrame:HookScript("OnHide", function()
			Cancel("inspect")
			shownGuid.inspect = nil
			ClearKind("inspect")
		end)
		inspectHooked = true
	end)
	if not ok then
		ns.ILvlUI.failed.slotsInspect = tostring(err)
	end
end

local function InspectSlots()
	if not (EventUtil and EventUtil.ContinueOnAddOnLoaded) then
		return false
	end
	EventUtil.ContinueOnAddOnLoaded("Blizzard_InspectUI", OnInspectLoaded)
	ns.ILvl.OnLearned(function(guid)
		if guid ~= nil and WindowGuid() == guid then
			RedrawKind("inspect")
		end
	end)
	return true
end

--- Installs the slot overlays and the redraw on both options' changes.
function GS.Init()
	ns.Settings.OnChange("slotItemLevel", RedrawAll)
	ns.Settings.OnChange("slotEnchants", RedrawAll)
	ns.ILvlUI.Install("slotsInspect", InspectSlots)
	if not ns.ILvlUI.Install("slotsSheet", SheetSlots) then
		local f = CreateFrame("Frame")
		f:RegisterEvent("PLAYER_LOGIN")
		f:SetScript("OnEvent", function(self)
			self:UnregisterEvent("PLAYER_LOGIN")
			ns.ILvlUI.Install("slotsSheet", SheetSlots)
		end)
	end
end
