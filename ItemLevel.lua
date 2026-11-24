-------------------------------------------------------------------------------
--  ItemLevel.lua -- item level data (ns.ILvl): what the client tells us about item levels,
--  the quiet inspect queue and its guard, and the probe. Nothing here draws: the display
--  spots (player tooltip, Inspect window, character sheet, item tooltip) live in
--  ItemLevelUI.lua and learn of new values through ILvl.OnLearned.
--
--  /tgf ilvl prints everything the client gives about your own item level, then
--  inspects each group member in turn (out of combat, never while the game's Inspect
--  window is open) and prints theirs as each inspect answers.
--
--  An item level is known this session (nothing while unknown or incomplete; enemies, and
--  anyone you can attack, never looked up):
--  - yours: the game's own equipped average (GetAverageItemLevel), as the character
--    sheet shows it (raised to C_PaperDollInfo.GetMinItemLevel where one applies,
--    rounded down)
--  - another player's: the first time their tooltip shows, we inspect them quietly (one
--    inspect at a time, 1.5 s apart, out of combat) and tell the spots when it answers.
--    The guard: never while the Inspect window is shown or pending, nor within 2 s of an
--    inspect that isn't ours or while it awaits its answer (at most 4 s); ours is dropped (stores nothing, clears nothing) when
--    another one starts after it; a value is stored only for the GUID of the latest
--    inspect, checked when it answers and again when it is read; ClearInspectPlayer only
--    when no later inspect started and the window is closed. One that brings nothing
--    waits 30 s to be tried again; talents with nothing to show (none readable, no points
--    yet) are read again after 10 minutes. A known value is kept for the session, never looked up again, and only
--    updated by a later inspect (the probe's, or the game's Inspect window). The value:
--    the game's figure (C_PaperDollInfo.GetInspectItemLevel, a whole number), else our
--    own average by the same rule, rounded
--
--  The game's rule, worked out from live samples on Forever (your own figure exact, nine
--  players' inspect figures, every class's weapon setup: one-handers with an off hand,
--  two-handers, wands, a bow, relics): 16 slots (shirt and tabard don't count, an empty
--  slot counts 0); the weapons count as the better of two sets, melee (main hand + off
--  hand, a two-hander counting twice when the off hand is empty) or ranged (the ranged
--  slot's item + off hand). A low relic so never counts; a wand above a one-hander does.
--  An inspected player's figure is rounded (47.5 -> 48, 47.94 -> 48), yours is exact.
-------------------------------------------------------------------------------
local _, ns = ...

local ILvl = {}
ns.ILvl = ILvl

local SLOT_NAMES = {
	[1] = "Head",
	[2] = "Neck",
	[3] = "Shoulder",
	[4] = "Shirt",
	[5] = "Chest",
	[6] = "Waist",
	[7] = "Legs",
	[8] = "Feet",
	[9] = "Wrist",
	[10] = "Hands",
	[11] = "Ring 1",
	[12] = "Ring 2",
	[13] = "Trinket 1",
	[14] = "Trinket 2",
	[15] = "Back",
	[16] = "Main hand",
	[17] = "Off hand",
	[18] = "Ranged",
	[19] = "Tabard",
}
-- Shared with GearSlots.lua (exported rather than copied).
ILvl.SLOT_NAMES = SLOT_NAMES
-- Every slot but the shirt, tabard, weapons and ranged. Ammo (slot 0) is never read.
local ARMOR = { 1, 2, 3, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15 }
local MAIN, OFF, RANGED = 16, 17, 18

-- What a slot holds, from its equip location (and the weapon subclass for wands).
local KIND = {
	INVTYPE_2HWEAPON = "2h",
	INVTYPE_WEAPON = "1h",
	INVTYPE_WEAPONMAINHAND = "1h",
	INVTYPE_WEAPONOFFHAND = "1h",
	INVTYPE_SHIELD = "shield",
	INVTYPE_HOLDABLE = "held",
	INVTYPE_RANGED = "bow", -- bows (and crossbows on some clients)
	INVTYPE_RANGEDRIGHT = "gun", -- guns, crossbows, wands (told apart below)
	INVTYPE_THROWN = "thrown",
	INVTYPE_RELIC = "relic", -- idols, librams, totems
}
local WEAPON_CLASS, WAND_SUBCLASS = 2, 19
local HEIRLOOM = 7

local INSPECT_GAP = 1.5 -- seconds between two inspects
local INSPECT_WAIT = 4 -- seconds an inspect is waited on
local ITEM_RETRIES = 3 -- tries (a second apart) for item data to load
local RETRY_AFTER = 30 -- seconds before a tooltip inspect that brought nothing is tried again
local NOTHING_KEPT = 600 -- seconds a talents answer with nothing to show counts as known
local MATCH = 0.001 -- how close our average must come to your exact figure
local SLOTS = 16

local GetItemLevel = C_Item and C_Item.GetDetailedItemLevelInfo or GetDetailedItemLevelInfo
local GetItemInfoInstant = C_Item and C_Item.GetItemInfoInstant or GetItemInfoInstant
local GetItemInfo = C_Item and C_Item.GetItemInfo or GetItemInfo

-- guid -> { ilvl, source, talents, talentsAt, name, at }, this session only. talents is a
-- list of points per tree, or false (an inspect answered, nothing readable); ilvl may be
-- missing when only the talents were stored.
local known = {}

local function Print(...)
	ns.Print("|cffffd100ilvl|r", ...)
end

-- Asked before anything else looks at the value (no comparison, no truth test first).
local function Secret(v)
	return issecretvalue ~= nil and issecretvalue(v)
end

--- A unit query's answer as a plain yes: true only when readable and true. A secret
--- answer is never tested for truth and counts as no (callers fail closed with it).
function ILvl.Yes(v)
	if Secret(v) then
		return false
	end
	return v and true or false
end
local Yes = ILvl.Yes

local function Round(v)
	return math.floor(v * 1000 + 0.5) / 1000
end

local function Has(name, fn)
	return fn and name or (name .. " |cffff6060(missing)|r")
end

local function Number(v)
	return type(v) == "number" and not Secret(v) and v or nil
end

-- The item level the game itself reports for a unit's equipped gear (nil if none).
local function GameInspectLevel(unit)
	local api = C_PaperDollInfo and C_PaperDollInfo.GetInspectItemLevel
	if not api then
		return nil
	end
	local ok, v = pcall(api, unit)
	v = ok and Number(v)
	return v and v > 0 and v or nil
end

-- The game's equipped average for you (nil if it gives none).
local function GameMine()
	if not GetAverageItemLevel then
		return nil
	end
	local _, equipped = GetAverageItemLevel()
	equipped = Number(equipped)
	return equipped and equipped > 0 and equipped or nil
end

-- Your figure as the character sheet shows it: the equipped average, raised to the
-- game's minimum item level where one applies (nil if the game gives none).
local function ShownMine()
	local equipped = GameMine()
	if not equipped then
		return nil
	end
	local api = C_PaperDollInfo and C_PaperDollInfo.GetMinItemLevel
	local ok, least = false, nil
	if api then
		ok, least = pcall(api)
	end
	least = ok and Number(least) or 0
	return math.max(least, equipped)
end

-------------------------------------------------------------------------------
--  Talent points per tree, as Forever's own talent frame counts them: the config's
--  tree, its groups in the game's order, each group's currency `spent`.
-------------------------------------------------------------------------------
local INSPECT_CONFIG = -1 -- the config of whoever the latest inspect answered
do
	local id = Constants and Constants.TraitConsts and Constants.TraitConsts.INSPECT_TRAIT_CONFIG_ID
	if type(id) == "number" then
		INSPECT_CONFIG = id
	end
end

-- Points spent per tree in the game's order, or nil when the config can't be read (any
-- secret value fails closed).
local function ReadTalents(configID)
	if
		Secret(configID)
		or type(configID) ~= "number"
		or not (
			C_Traits
			and C_Traits.GetConfigInfo
			and C_Traits.GetGroupDisplayInfoByTreeID
			and C_Traits.GetGroupCurrencyInfo
		)
	then
		return nil
	end
	local ok, info = pcall(C_Traits.GetConfigInfo, configID)
	if not ok or Secret(info) or type(info) ~= "table" or Secret(info.treeIDs) or type(info.treeIDs) ~= "table" then
		return nil
	end
	local treeID = info.treeIDs[1]
	if Secret(treeID) or type(treeID) ~= "number" then
		return nil
	end
	local ok2, groups = pcall(C_Traits.GetGroupDisplayInfoByTreeID, treeID)
	if not ok2 or Secret(groups) or type(groups) ~= "table" or #groups == 0 then
		return nil
	end
	local ids = {}
	for i, g in ipairs(groups) do
		if Secret(g) or type(g) ~= "table" or Secret(g.groupID) then
			return nil
		end
		ids[i] = g.groupID
	end
	local ok3, currency = pcall(C_Traits.GetGroupCurrencyInfo, configID, ids)
	if not ok3 or Secret(currency) or type(currency) ~= "table" then
		return nil
	end
	local out = {}
	for i, id in ipairs(ids) do
		local spent = 0 -- a group with no currency entry counts 0, as the game's header shows
		for _, c in ipairs(currency) do
			if Secret(c) or type(c) ~= "table" or Secret(c.traitNodeGroupID) then
				return nil
			end
			if c.traitNodeGroupID == id then
				local infos = c.currencyInfos
				if Secret(infos) then
					return nil
				end
				local first = type(infos) == "table" and infos[1] or nil
				if Secret(first) then
					return nil
				end
				local v = type(first) == "table" and first.spent or nil
				if Secret(v) then
					return nil
				end
				spent = type(v) == "number" and math.floor(v) or 0
				break
			end
		end
		out[i] = spent
	end
	return out
end

-- The inspected player's points per tree when the game says the inspect config holds valid
-- data (C_Traits.HasValidInspectData, where the client has it): a list, or false (valid,
-- nothing readable). nil = not valid or unreadable: unknown, so a later inspect can fill it.
local function ReadInspectTalents()
	if C_Traits and C_Traits.HasValidInspectData then
		local ok, valid = pcall(C_Traits.HasValidInspectData)
		if not ok or Secret(valid) or not valid then
			return nil
		end
	end
	return ReadTalents(INSPECT_CONFIG) or false
end

-- Your own active talent config, or nil: a candidate whose type reads CamelotCombat; one whose
-- type can't be read only when it is the only candidate.
local function OwnConfigID()
	local candidates, seen = {}, {}
	local function Add(id)
		if not seen[id] then
			seen[id] = true
			candidates[#candidates + 1] = id
		end
	end
	local S = C_SpecializationInfo
	if S and S.GetCombatConfigIDForSpecGroup and S.GetActiveSpecGroup then
		local ok, group = pcall(S.GetActiveSpecGroup)
		if ok and not Secret(group) and group then
			local ok2, id = pcall(S.GetCombatConfigIDForSpecGroup, group)
			if ok2 and not Secret(id) and type(id) == "number" then
				Add(id)
			end
		end
	end
	if C_ClassTalents and C_ClassTalents.GetActiveConfigID then
		local ok, id = pcall(C_ClassTalents.GetActiveConfigID)
		if ok and not Secret(id) and type(id) == "number" then
			Add(id)
		end
	end
	local want = Enum and Enum.TraitConfigType and Enum.TraitConfigType.CamelotCombat
	if want == nil or not (C_Traits and C_Traits.GetConfigInfo) then
		return candidates[1] -- no type to check against
	end
	for _, id in ipairs(candidates) do
		local ok, info = pcall(C_Traits.GetConfigInfo, id)
		local t = ok and not Secret(info) and type(info) == "table" and info.type or nil
		if not Secret(t) and type(t) == "number" then
			if t == want then
				return id
			end
		elseif #candidates == 1 then
			return id -- its type can't be read, but there is nothing else to choose
		end
	end
	return nil
end

-- The list when there is something to show (some tree above 0), else nil.
local function Showable(t)
	if Secret(t) or type(t) ~= "table" or #t == 0 then
		return nil
	end
	for _, n in ipairs(t) do
		if type(n) == "number" and n > 0 then
			return t
		end
	end
	return nil
end

-- Forever's talent frame shows an inspected player: its view is the inspect config, so
-- we neither inspect nor clear. Read only; unreadable counts as busy.
local function TalentsInspecting()
	if PlayerSpellsFrame == nil or type(PlayerSpellsFrame.IsInspecting) ~= "function" then
		return false
	end
	local ok, v = pcall(PlayerSpellsFrame.IsInspecting, PlayerSpellsFrame)
	if not ok or Secret(v) then
		return true
	end
	return v and true or false
end

--- Reads a unit's equipped items as the client knows them now: slots[slot] = { level,
--- kind, heirloom }; complete is false while any equipped item's data hasn't loaded
--- (an item ID with no link or no level yet), or nothing at all is known.
function ILvl.Read(unit)
	local r = { items = 0, slots = {}, complete = true, pending = 0 }
	for slot = 1, 19 do
		local id = GetInventoryItemID and GetInventoryItemID(unit, slot)
		local link = GetInventoryItemLink(unit, slot)
		if Secret(id) or Secret(link) then
			r.complete = false
		elseif link or id then
			r.items = r.items + 1
			local level = link and Number(GetItemLevel and GetItemLevel(link))
			if level then
				local s = { level = level }
				if GetItemInfoInstant then
					local _, _, _, loc, _, classID, subclassID = GetItemInfoInstant(link)
					s.kind = loc and KIND[loc]
					if s.kind == "gun" and classID == WEAPON_CLASS and subclassID == WAND_SUBCLASS then
						s.kind = "wand"
					end
				end
				local quality = GetItemInfo and select(3, GetItemInfo(link))
				s.heirloom = quality == HEIRLOOM
				r.slots[slot] = s
			else
				r.pending = r.pending + 1
				r.complete = false
			end
		end
	end
	if r.items == 0 then
		r.complete = false
	end
	r.game = GameInspectLevel(unit)
	return r
end

-------------------------------------------------------------------------------
--  Our own average, by the game's rule (see the top); empty slots count 0
-------------------------------------------------------------------------------
local function Level(r, slot)
	local s = r.slots[slot]
	return s and s.level or 0
end

local function Kind(r, slot)
	local s = r.slots[slot]
	return s and s.kind
end

--- The average for a read: 16 slots, the weapons as the better of the melee set and
--- the ranged set.
function ILvl.Average(r)
	local sum = 0
	for _, slot in ipairs(ARMOR) do
		sum = sum + Level(r, slot)
	end
	local main, off = Level(r, MAIN), Level(r, OFF)
	local melee = main + ((Kind(r, MAIN) == "2h" and not r.slots[OFF]) and main or off)
	local ranged = Level(r, RANGED) + off
	return (sum + math.max(melee, ranged)) / SLOTS
end

local learned = {} -- observers of a stored value: fn(guid, ilvl)

--- Calls fn(guid, ilvl) whenever a value is stored for a player.
function ILvl.OnLearned(fn)
	if type(fn) == "function" then
		learned[#learned + 1] = fn
	end
end

-- Stores what an inspect brought: the item level when the items are complete, the talents
-- (a list, or false for "answered, nothing readable") whenever given; nil talents (the game
-- said the inspect data isn't valid) store nothing for them. Returns ilvl, source only when
-- the item level is known now.
local function Remember(unit, r, talents)
	local guid, name = UnitGUID(unit), UnitName(unit)
	if Secret(guid) or not guid then
		return nil
	end
	if not r.complete and talents == nil then
		return nil -- nothing to store
	end
	local entry = known[guid] or {}
	known[guid] = entry
	local ilvl, source
	if r.complete then
		ilvl, source = r.game, "game"
		if not ilvl then
			ilvl, source = math.floor(ILvl.Average(r) + 0.5), "ours" -- whole, as the game's
		end
		entry.ilvl, entry.source = ilvl, source
	end
	if talents ~= nil then
		entry.talents, entry.talentsAt = talents, GetTime()
	end
	entry.name = not Secret(name) and name or nil
	entry.at = time()
	for _, fn in ipairs(learned) do
		local ok, err = pcall(fn, guid, entry.ilvl)
		if not ok and geterrorhandler then
			geterrorhandler()(err)
		end
	end
	return ilvl, source
end

--- A unit's item level if known in full this session, else nil.
function ILvl.Of(unit)
	if Secret(unit) or not unit or not Yes(UnitIsPlayer(unit)) then
		return nil
	end
	local me = UnitIsUnit(unit, "player")
	if Secret(me) then
		return nil
	end
	if me then
		return ShownMine()
	end
	local guid = UnitGUID(unit)
	if Secret(guid) or not guid then
		return nil
	end
	local entry = known[guid]
	return entry and entry.ilvl
end

-- The player's cache entry, or nil; isMe tells it is you (never cached).
local function PlayerEntry(unit)
	if Secret(unit) or not unit or not Yes(UnitIsPlayer(unit)) then
		return nil, false
	end
	local me = UnitIsUnit(unit, "player")
	if Secret(me) then
		return nil, false
	end
	if me then
		return nil, true
	end
	local guid = UnitGUID(unit)
	if Secret(guid) or not guid then
		return nil, false
	end
	return known[guid], false
end

--- A unit's talent points per tree (whole numbers, the game's order) when there is
--- something to show (some tree above 0), else nil. Yours are read live; another
--- player's are what an inspect answered this session.
function ILvl.TalentsOf(unit)
	local entry, me = PlayerEntry(unit)
	if me then
		return Showable(ReadTalents(OwnConfigID()))
	end
	return entry and Showable(entry.talents) or nil
end

--- True for you; for another player once an inspect answer recorded talents (a list or
--- false), so the tooltip doesn't ask for another inspect for it. An answer with nothing to
--- show (false, or no points yet) counts for NOTHING_KEPT only: a low-level player is read again.
function ILvl.TalentsKnown(unit)
	local entry, me = PlayerEntry(unit)
	if me then
		return true
	end
	if entry == nil or entry.talents == nil then
		return false
	end
	if not Showable(entry.talents) then
		return GetTime() - (entry.talentsAt or -math.huge) < NOTHING_KEPT
	end
	return true
end

-------------------------------------------------------------------------------
--  Probe
-------------------------------------------------------------------------------
local function SlotLine(r)
	local parts = {}
	for slot = 1, 19 do
		local s = r.slots[slot]
		if s then
			local tags = {}
			if s.kind and slot >= MAIN and slot <= RANGED then
				tags[#tags + 1] = s.kind
			end
			if s.heirloom then
				tags[#tags + 1] = "|cffe6cc80heirloom|r"
			end
			parts[#parts + 1] = SLOT_NAMES[slot]
				.. " "
				.. s.level
				.. (#tags > 0 and (" (" .. table.concat(tags, ", ") .. ")") or "")
		end
	end
	return #parts > 0 and table.concat(parts, ", ") or "none"
end

local function PrintRead(r, game)
	Print(
		("  items: %d equipped%s"):format(
			r.items,
			r.complete and "" or (" |cffff6060(incomplete: %d not loaded)|r"):format(r.pending)
		)
	)
	Print("  slots: " .. SlotLine(r))
	Print("  C_PaperDollInfo.GetInspectItemLevel: " .. tostring(r.game))
	-- Your figure is exact; an inspected player's is a whole number, rounded.
	local v = ILvl.Average(r)
	local mark = ""
	if game then
		mark = math.abs(v - game) < MATCH and "  |cff40ff40= game|r" or "  |cffff6060~= game|r"
	elseif r.game then
		mark = math.floor(v + 0.5) == r.game and "  |cff40ff40rounds to game|r" or "  |cffff6060~= game|r"
	end
	Print(("  our average: %s%s"):format(Round(v), mark))
end

-- Everything the client gives for a talent config, and GetSpecializationInfo's
-- pointsSpent for comparison. May error on odd data: call it through SafePrintTalents.
local function PrintTalents(configID, isInspect)
	local function Str(v)
		return Secret(v) and "secret" or tostring(v)
	end
	Print("  talent config " .. Str(configID) .. ":")
	local info
	if C_Traits and C_Traits.GetConfigInfo then
		local ok, got = pcall(C_Traits.GetConfigInfo, configID)
		info = ok and not Secret(got) and type(got) == "table" and got or nil
	else
		Print("  " .. Has("C_Traits.GetConfigInfo", nil))
	end
	if info then
		local want = Enum and Enum.TraitConfigType and Enum.TraitConfigType.CamelotCombat
		local mark = ""
		if want ~= nil and not Secret(info.type) then
			mark = info.type == want and " = CamelotCombat" or " ~= CamelotCombat"
		end
		local trees = not Secret(info.treeIDs) and type(info.treeIDs) == "table" and info.treeIDs or nil
		Print(("  config type %s%s, tree %s"):format(Str(info.type), mark, Str(trees and trees[1])))
		if trees and trees[1] and not Secret(trees[1]) and C_Traits.GetGroupDisplayInfoByTreeID then
			local ok, groups = pcall(C_Traits.GetGroupDisplayInfoByTreeID, trees[1])
			if ok and not Secret(groups) and type(groups) == "table" then
				local ids = {}
				for i, g in ipairs(groups) do
					ids[i] = type(g) == "table" and g.groupID or nil
				end
				local currency
				if C_Traits.GetGroupCurrencyInfo then
					local ok2, got = pcall(C_Traits.GetGroupCurrencyInfo, configID, ids)
					currency = ok2 and not Secret(got) and type(got) == "table" and got or nil
				end
				for _, g in ipairs(groups) do
					local spent
					for _, c in ipairs(currency or {}) do
						if type(c) == "table" and c.traitNodeGroupID == g.groupID then
							local first = type(c.currencyInfos) == "table" and c.currencyInfos[1] or nil
							spent = type(first) == "table" and first.spent or nil
						end
					end
					Print(
						("  group %s order %s %s: spent %s"):format(
							Str(g.groupID),
							Str(g.orderIndex),
							Str(g.displayName),
							Str(spent)
						)
					)
				end
			end
		end
	end
	local read = ReadTalents(configID)
	Print("  C_Traits per tree: " .. (read and table.concat(read, "/") or "nothing"))
	local S = C_SpecializationInfo
	if S and S.GetSpecializationInfo then
		local parts = {}
		for i = 1, 3 do
			local ok, _, name, _, _, _, _, spent = pcall(S.GetSpecializationInfo, i, isInspect, false, nil, nil, nil)
			parts[#parts + 1] = ok and (Str(name) .. " " .. Str(spent)) or "error"
		end
		Print("  GetSpecializationInfo pointsSpent: " .. table.concat(parts, ", "))
	else
		Print("  " .. Has("C_SpecializationInfo.GetSpecializationInfo", nil))
	end
end

-- The talent printout under one pcall: a failure prints a line and never stops the caller
-- (the inspect clean-up, the probe's group queue).
local function SafePrintTalents(configID, isInspect)
	local ok, err = pcall(PrintTalents, configID, isInspect)
	if not ok then
		Print("  talents probe failed: " .. tostring(err))
	end
end

local function ProbeSelf()
	local _, class = UnitClass("player")
	Print(
		("you (%s, level %s, %s):"):format(tostring(UnitName("player")), tostring(UnitLevel("player")), tostring(class))
	)
	if GetAverageItemLevel then
		local avg, equipped, pvp = GetAverageItemLevel()
		Print(
			("  GetAverageItemLevel: avg %s (best you own, bags too), equipped %s, pvp %s"):format(
				tostring(avg),
				tostring(equipped),
				tostring(pvp)
			)
		)
	else
		Print("  " .. Has("GetAverageItemLevel", nil))
	end
	local minApi = C_PaperDollInfo and C_PaperDollInfo.GetMinItemLevel
	if minApi then
		local ok, v = pcall(minApi)
		Print("  C_PaperDollInfo.GetMinItemLevel: " .. tostring(ok and v or "error"))
	end
	PrintRead(ILvl.Read("player"), GameMine())
	local mine = ShownMine()
	Print("  tooltip shows: " .. (mine and tostring(math.floor(mine)) or "nothing"))
	local S = C_SpecializationInfo
	local function Call(fn, ...)
		if not fn then
			return "missing"
		end
		local ok, v = pcall(fn, ...)
		return ok and (Secret(v) and "secret" or tostring(v)) or "error"
	end
	local group = S and S.GetActiveSpecGroup and select(2, pcall(S.GetActiveSpecGroup))
	Print(
		("  GetActiveSpecGroup %s, GetCombatConfigIDForSpecGroup %s, GetActiveConfigID %s, GetSpecialization %s"):format(
			Call(S and S.GetActiveSpecGroup),
			Call(S and S.GetCombatConfigIDForSpecGroup, group),
			Call(C_ClassTalents and C_ClassTalents.GetActiveConfigID),
			Call(S and S.GetSpecialization)
		)
	)
	local own = OwnConfigID()
	Print("  chosen config: " .. tostring(own))
	SafePrintTalents(own, false)
	local t = ILvl.TalentsOf("player")
	Print("  talents tooltip shows: " .. (t and ("Talents " .. table.concat(t, "/")) or "nothing"))
end

-------------------------------------------------------------------------------
--  Inspecting: one at a time, INSPECT_GAP apart; the probe's queue, and a quiet one
--  for a friendly player's tooltip whose item level isn't known yet.
--
--  The guard (the game has one inspect slot, shared with its Inspect window and other
--  addons): we stay away while the window is shown or pending (InspectFrame.unit set
--  before it shows, for at most INSPECT_WAIT after InspectUnit: the game never clears a
--  unit whose answer didn't come), for OTHERS_BUSY seconds after an inspect that isn't ours, and
--  while that inspect is pending (until its INSPECT_READY, at most INSPECT_WAIT: Forever's
--  "Inspect Talents" opens its view only when the answer comes); ours is dropped when another
--  starts after it. We also stay away (no inspect, no clear) while
--  Forever's talent frame shows an inspected player. serial counts every NotifyInspect, lastTarget
--  is the latest one's GUID, readyGUID / readySerial the latest answer to it.
-------------------------------------------------------------------------------
local OTHERS_BUSY = 2 -- seconds an inspect that is not ours keeps us away
local queue, current, probing = {}, nil, false
local lastInspect = -math.huge
local tried = {} -- guid -> GetTime() of a quiet inspect that brought nothing
local serial = 0 -- bumped on every NotifyInspect, ours or not
local lastTarget = nil -- GUID of the latest NotifyInspect target (nil when unreadable)
local othersAt = -math.huge -- GetTime() of the latest inspect that is not ours
local othersPendingAt = -math.huge -- GetTime() of an inspect not ours that awaits its answer
local othersGUID = nil -- its GUID (nil when unreadable: pending until INSPECT_WAIT)
local inspectUnitAt = -math.huge -- GetTime() of the latest InspectUnit (the Inspect window)
local sending = false -- true while our own NotifyInspect runs
local readyGUID, readySerial = nil, nil -- the latest INSPECT_READY that answered the latest inspect
local Next
local nextPending = false -- one Next timer at a time

-- Runs Next after delay, unless a Next is already waiting to run.
local function ScheduleNext(delay)
	if nextPending then
		return
	end
	nextPending = true
	C_Timer.After(delay, function()
		nextPending = false
		Next()
	end)
end

-- The unit token a GUID can be found under now (the hint first), or nil.
local function FindUnit(guid, hint)
	local function Is(unit)
		local g = Yes(UnitExists(unit)) and UnitGUID(unit)
		return not Secret(g) and g and g == guid
	end
	if not Secret(hint) and hint and Is(hint) then
		return hint
	end
	for _, unit in ipairs({ "mouseover", "target", "focus" }) do
		if Is(unit) then
			return unit
		end
	end
	local raid = IsInRaid()
	local count = raid and GetNumGroupMembers() or GetNumSubgroupMembers()
	for i = 1, count do
		local unit = (raid and "raid" or "party") .. i
		if Is(unit) then
			return unit
		end
	end
	return nil
end

-- The game's Inspect window is shown, or about to be: InspectFrame_Show sets its unit and
-- waits for the answer before it shows. The game never clears that unit when the answer
-- doesn't come, so it counts as pending only up to INSPECT_WAIT after the InspectUnit call.
local function InspectOpen()
	if InspectFrame == nil then
		return false
	end
	if InspectFrame:IsShown() then
		return true
	end
	return InspectFrame.unit ~= nil and GetTime() - inspectUnitAt < INSPECT_WAIT
end

-- An inspect that isn't ours hasn't answered yet (for at most INSPECT_WAIT).
local function OthersPending()
	return GetTime() - othersPendingAt < INSPECT_WAIT
end

local function Busy()
	return InCombatLockdown()
		or InspectOpen()
		or TalentsInspecting()
		or OthersPending()
		or GetTime() - othersAt < OTHERS_BUSY
end

-- Another inspect started after ours: ours stores nothing and clears nothing.
local function Displaced(c)
	if current ~= c then
		return
	end
	current = nil
	if not c.quiet then
		Print(("%s: another inspect started; skipped."):format(c.name))
	end
	ScheduleNext(INSPECT_GAP)
end

local function OnNotify(unit)
	serial = serial + 1
	local guid = not Secret(unit) and unit and UnitGUID(unit) or nil
	lastTarget = not Secret(guid) and guid or nil
	if not sending then
		othersAt = GetTime()
		othersPendingAt, othersGUID = othersAt, lastTarget
		if current then
			Displaced(current)
		end
	end
end

local function OnInspectUnit()
	othersAt = GetTime() -- the window may load first and CanInspect may refuse: busy either way
	inspectUnitAt = othersAt
end

local function Done(c, gotValue)
	if
		ClearInspectPlayer
		and not InspectOpen()
		and not TalentsInspecting()
		and not OthersPending()
		and serial == c.serial
		and othersAt < c.sentAt
	then
		ClearInspectPlayer()
		if not c.quiet then
			local after = ReadTalents(INSPECT_CONFIG)
			Print("  after clear: " .. (after and table.concat(after, "/") or "nothing"))
		end
		-- Ours is over and cleared: a late answer to it is stale, never "someone else's".
		lastTarget, readyGUID = nil, nil
	end
	if c.quiet and not gotValue then
		tried[c.guid] = GetTime()
	end
	current = nil
	ScheduleNext(INSPECT_GAP)
end

local function ReadCurrent(tries)
	local c = current
	if not c then
		return
	end
	if serial ~= c.serial or lastTarget ~= c.guid then
		return Displaced(c)
	end
	-- The inspect config is whoever the latest inspect answered: read it here, in the first
	-- pass of this answer, never on a retry. false = answered, nothing readable; nil = the
	-- game says the data isn't valid (unknown, a later inspect may fill it).
	if tries == 0 and not c.talentsRead then
		c.talents = ReadInspectTalents()
		c.talentsRead = true
	end
	local unit = FindUnit(c.guid, c.unit)
	if not unit then
		if not c.quiet then
			Print(("%s: out of sight before the inspect could be read."):format(c.name))
		end
		return Done(c, false)
	end
	local r = ILvl.Read(unit)
	if r.complete or tries >= ITEM_RETRIES then
		local ilvl, source = Remember(unit, r, c.talents)
		if not c.quiet then
			local _, class = UnitClass(unit)
			Print(
				("%s (%s, %s) inspect answered%s:"):format(
					c.name,
					unit,
					tostring(class),
					tries > 0 and (" after " .. tries .. " retries") or ""
				)
			)
			PrintRead(r)
			Print("  tooltip shows: " .. (ilvl and (math.floor(ilvl) .. " (" .. source .. ")") or "nothing"))
			SafePrintTalents(INSPECT_CONFIG, true)
			Print("  talents captured: " .. (c.talents and table.concat(c.talents, "/") or "nothing"))
		end
		-- Got a value: an item level that wasn't known, or talents when the item level was
		-- already known. Items still missing wait RETRY_AFTER even when talents came, so a
		-- player whose gear doesn't load isn't inspected again on every hover.
		local gotIlvl = ilvl ~= nil and not c.hadIlvl
		return Done(c, gotIlvl or (c.hadIlvl and type(c.talents) == "table"))
	end
	C_Timer.After(1, function()
		if current == c then
			ReadCurrent(tries + 1)
		end
	end)
end

-- Sends one inspect; its answer (INSPECT_READY) or INSPECT_WAIT ends it.
local function Inspect(unit, guid, name, quiet)
	local c = { unit = unit, guid = guid, name = name, quiet = quiet }
	c.hadIlvl = known[guid] ~= nil and known[guid].ilvl ~= nil
	current = c
	sending = true
	pcall(NotifyInspect, unit)
	sending = false
	c.serial = serial
	c.sentAt = GetTime()
	lastTarget = guid
	lastInspect = c.sentAt
	C_Timer.After(INSPECT_WAIT, function()
		if current == c then
			if not quiet then
				Print(("%s (%s): no inspect answer in %ds."):format(name, unit, INSPECT_WAIT))
			end
			Done(c, false)
		end
	end)
end

function Next()
	if current then
		return
	end
	while #queue > 0 do
		if Busy() then
			Print("waiting: in combat, another inspect is out, or the Inspect window or inspected talents are open.")
			return ScheduleNext(INSPECT_GAP * 2)
		end
		local unit = table.remove(queue, 1)
		local guid, name = UnitGUID(unit), UnitName(unit)
		if not Secret(guid) and guid and not Secret(name) and Yes(UnitExists(unit)) then
			if not Yes(UnitIsConnected(unit)) then
				Print(("%s (%s): offline, skipped."):format(name, unit))
			elseif not (CanInspect and Yes(CanInspect(unit))) then
				Print(("%s (%s): CanInspect is false (out of range?), skipped."):format(name, unit))
			else
				return Inspect(unit, guid, name, false)
			end
		else
			Print(unit .. ": name or GUID unreadable (secret), skipped.")
		end
	end
	if probing then
		probing = false
		Print("probe done.")
	end
end

--- A player whose item level we never look up or show: an enemy, or anyone you can attack.
--- An answer we can't read (secret) counts as hostile: never looked up, never shown.
function ILvl.Hostile(unit)
	local enemy = UnitIsEnemy and UnitIsEnemy("player", unit)
	local attackable = UnitCanAttack and UnitCanAttack("player", unit)
	if Secret(enemy) or Secret(attackable) then
		return true
	end
	return (enemy or attackable) and true or false
end

-- An unknown item level: inspect the player quietly, when nothing else is inspecting and
-- they haven't been tried in the last RETRY_AFTER seconds.
function ILvl.RequestInspect(unit)
	if Secret(unit) or not unit then
		return
	end
	if current or #queue > 0 or not NotifyInspect or Busy() then
		return
	end
	if GetTime() - lastInspect < INSPECT_GAP then
		return
	end
	local guid, name = UnitGUID(unit), UnitName(unit)
	if Secret(guid) or not guid or Secret(name) then
		return
	end
	if tried[guid] and GetTime() - tried[guid] < RETRY_AFTER then
		return
	end
	if not (Yes(UnitIsConnected(unit)) and CanInspect and Yes(CanInspect(unit))) then
		return
	end
	Inspect(unit, guid, name, true)
end

--- A unit's item level as the Inspect window shows it: yours equipped (rounded down);
--- another player's the game's own whole number while the latest inspect answered for them,
--- else what we kept for that GUID this session (rounded); nil while unknown.
function ILvl.Inspected(unit)
	if Secret(unit) or not unit then
		return nil
	end
	local guid = UnitGUID(unit)
	if Secret(guid) or not guid then
		return nil
	end
	local me = UnitIsUnit(unit, "player")
	if Secret(me) then
		return nil
	end
	if me then
		local mine = ShownMine()
		return mine and math.floor(mine) or nil
	end
	if readyGUID == guid and readySerial == serial then
		local v = GameInspectLevel(unit)
		if v then
			return math.floor(v + 0.5)
		end
	end
	local entry = known[guid]
	return entry and entry.ilvl and math.floor(entry.ilvl + 0.5) or nil
end

--- True when a unit's gear can be read now: you, or a unit the latest inspect answered
--- for (its GUID matches and no inspect started since). Reads the guard's state only;
--- never inspects and never clears.
function ILvl.InspectReadyFor(unit)
	if Secret(unit) or not unit then
		return false
	end
	local guid = UnitGUID(unit)
	if Secret(guid) or not guid then
		return false
	end
	local me = UnitIsUnit(unit, "player")
	if Secret(me) then
		return false
	end
	if me then
		return true
	end
	return readyGUID == guid and readySerial == serial
end

--- /tgf ilvl: prints what we know about your item level, then inspects your group.
function ILvl.Probe()
	Print("APIs: " .. table.concat({
		Has("GetAverageItemLevel", GetAverageItemLevel),
		Has("C_PaperDollInfo.GetInspectItemLevel", C_PaperDollInfo and C_PaperDollInfo.GetInspectItemLevel),
		Has("GetDetailedItemLevelInfo", GetItemLevel),
		Has("GetInventoryItemID", GetInventoryItemID),
		Has("NotifyInspect", NotifyInspect),
		Has("CanInspect", CanInspect),
		Has("C_Traits.GetGroupCurrencyInfo", C_Traits and C_Traits.GetGroupCurrencyInfo),
		Has(
			"C_SpecializationInfo.GetCombatConfigIDForSpecGroup",
			C_SpecializationInfo and C_SpecializationInfo.GetCombatConfigIDForSpecGroup
		),
	}, ", "))
	if ns.ILvlUI and ns.ILvlUI.failed then
		for name, err in pairs(ns.ILvlUI.failed) do
			Print(("spot %s failed: %s"):format(name, tostring(err)))
		end
	end
	ProbeSelf()
	for i = #queue, 1, -1 do
		queue[i] = nil
	end
	local raid = IsInRaid()
	local count = raid and GetNumGroupMembers() or GetNumSubgroupMembers()
	for i = 1, count do
		local unit = (raid and "raid" or "party") .. i
		if Yes(UnitExists(unit)) and not Yes(UnitIsUnit(unit, "player")) then
			queue[#queue + 1] = unit
			local r = ILvl.Read(unit)
			local ilvl = ILvl.Of(unit)
			Print(
				("%s (%s) before inspect: %d items seen; game figure %s; known %s"):format(
					tostring(UnitName(unit)),
					unit,
					r.items,
					tostring(r.game),
					ilvl and tostring(math.floor(ilvl)) or "no"
				)
			)
		end
	end
	if #queue == 0 then
		return Print("not in a group: nothing to inspect.")
	end
	if not NotifyInspect then
		return Print("NotifyInspect is missing: can't inspect.")
	end
	probing = true
	if current then
		return Print("an inspect is running; your group follows it.")
	end
	Next()
end

-------------------------------------------------------------------------------
--  Inspects from elsewhere (the game's Inspect window, other addons)
-------------------------------------------------------------------------------
local function OnInspectReady(guid)
	if Secret(guid) then
		return
	end
	if othersGUID ~= nil and guid == othersGUID then
		othersPendingAt = -math.huge -- the other inspect answered
	end
	if guid == lastTarget then
		readyGUID, readySerial = guid, serial
	else
		readyGUID = nil
	end
	if current and guid == current.guid then
		return ReadCurrent(0)
	end
	-- An answer that isn't to the latest inspect is stale: store nothing.
	if guid ~= lastTarget then
		return
	end
	if current then
		Displaced(current)
	end
	-- Someone else's inspect: learn from it (or update what we knew) if we can find them.
	local hint = InspectFrame and InspectFrame.unit or nil
	local unit = FindUnit(guid, hint)
	if not unit then
		return
	end
	local s, tries = serial, 0
	local talents -- read once, on the first pass; false = answered, nothing readable; nil = not valid
	local function Try()
		if serial ~= s or lastTarget ~= guid then
			return
		end
		if tries == 0 then
			talents = ReadInspectTalents()
		end
		local u = FindUnit(guid, unit)
		if not u then
			return
		end
		local r = ILvl.Read(u)
		if r.complete or tries >= ITEM_RETRIES then
			return Remember(u, r, talents)
		end
		tries = tries + 1
		C_Timer.After(1, Try)
	end
	Try()
end

function ILvl.Init()
	if not (CreateFrame and C_Timer) then
		return
	end
	local frame = CreateFrame("Frame")
	frame:SetScript("OnEvent", function(_, event, arg)
		if event == "INSPECT_READY" then
			OnInspectReady(arg)
		end
	end)
	frame:RegisterEvent("INSPECT_READY")
	if type(NotifyInspect) == "function" then
		hooksecurefunc("NotifyInspect", OnNotify)
	end
	if type(InspectUnit) == "function" then
		hooksecurefunc("InspectUnit", OnInspectUnit)
	end
end
