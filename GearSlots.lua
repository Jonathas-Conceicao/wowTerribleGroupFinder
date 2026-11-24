-------------------------------------------------------------------------------
--  GearSlots.lua -- per-slot gear data (ns.GearSlots): one equipped slot's item level and
--  enchant, for the character sheet and the Inspect window (slotItemLevel, slotEnchants).
--  Nothing here draws.
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
--  queue), and nothing is cached: every read asks the game.
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

-- Slots Forever lets you enchant: vanilla's, plus Forever's neck and off-hand enchants (any
-- off-hand item: weapons, shields, held-in-off-hand). Never the belt, rings, trinkets,
-- shirt or tabard. Rings are left out on one low-confidence source: for the author's
-- in-game check.
local ENCHANTABLE = {
	[1] = true,
	[2] = true,
	[3] = true,
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
