-------------------------------------------------------------------------------
--  GearScore.lua -- gear scores (ns.GS): one number on the item level scale for a
--  character's gear, and a cache of every score we have seen.
--
--  The score: each gear slot's item level, scaled by its quality (an epic counts in full,
--  lower qualities less), weighted by the slot (GearScore's well known slot weights; a
--  two-hander takes both hands), averaged over every slot, an empty one counting 0. The
--  shirt and tabard do not count. Our own rule, to be tuned against Forever's items.
--
--  The cache (TerribleGroupFinderDB.gs) keeps each player's last score by name with its
--  level and time. A score learned this session is "fresh"; one only known from an earlier
--  session is "outdated" and is shown in its own colour. Scores come from your own gear,
--  and from your group's: a ready check inspects every member whose score isn't fresh, one
--  at a time, out of combat, never while the game's Inspect window is open.
-------------------------------------------------------------------------------
local _, ns = ...

local GS = {}
ns.GS = GS

-- Slot weights (GearScore's): head, neck, shoulder, chest, waist, legs, feet, wrist,
-- hands, rings, trinkets, back, main hand, off hand, ranged.
local SLOTS = {
	[1] = 1,
	[2] = 0.5625,
	[3] = 0.75,
	[5] = 1,
	[6] = 0.75,
	[7] = 1,
	[8] = 0.75,
	[9] = 0.5625,
	[10] = 0.75,
	[11] = 0.5625,
	[12] = 0.5625,
	[13] = 0.5625,
	[14] = 0.5625,
	[15] = 0.5625,
	[16] = 1,
	[17] = 1,
	[18] = 0.3164,
}
local ORDER = { 1, 2, 3, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18 }
local MAIN, OFF = 16, 17
local TOTAL = 0
for _, slot in ipairs(ORDER) do
	TOTAL = TOTAL + SLOTS[slot]
end
-- What an item of each quality counts for against an epic of the same level.
local QUALITY = { [0] = 0.5, [1] = 0.7, [2] = 0.85, [3] = 0.93, [4] = 1, [5] = 1.1, [6] = 1.1, [7] = 0.93 }

local INSPECT_GAP = 1.5 -- seconds between two inspects
local INSPECT_WAIT = 4 -- seconds an inspect is waited on
local ITEM_RETRIES = 3 -- tries (a second apart) for item data to load
local KEEP_DAYS = 60 -- cache entries older than this are dropped at login

local GetItemInfo = C_Item and C_Item.GetItemInfo or GetItemInfo
local GetItemInfoInstant = C_Item and C_Item.GetItemInfoInstant or GetItemInfoInstant
local GetItemLevel = C_Item and C_Item.GetDetailedItemLevelInfo or GetDetailedItemLevelInfo

local cache -- name -> { gs, level, at }
local fresh = {} -- name -> true once learned this session

local Short = ns.Short

-- An item link's level, its quality's factor (nil while not loaded), and two-handed.
local function Item(link)
	if not link then
		return nil
	end
	local level = GetItemLevel and GetItemLevel(link)
	local quality = GetItemInfo and select(3, GetItemInfo(link))
	local equip = GetItemInfoInstant and select(4, GetItemInfoInstant(link))
	return level or 0, quality and QUALITY[quality], equip == "INVTYPE_2HWEAPON"
end

--- A unit's score from the gear the client knows it wears (yours always; another player's
--- while inspected), and whether every item had loaded.
function GS.Unit(unit)
	local sum, complete, twoHand = 0, true, false
	for _, slot in ipairs(ORDER) do
		if not (slot == OFF and twoHand) then
			local weight = SLOTS[slot]
			local level, factor, two = Item(GetInventoryItemLink(unit, slot))
			if slot == MAIN and two then
				twoHand = true
				weight = weight + SLOTS[OFF]
			end
			if level then
				if not factor then
					complete = false
				end
				sum = sum + weight * level * (factor or 1)
			end
		end
	end
	return sum / TOTAL, complete
end

function GS.Store(name, gs, level)
	name = Short(name)
	if not (cache and name and gs) then
		return
	end
	cache[name] = { gs = math.floor(gs * 10 + 0.5) / 10, level = level, at = time() }
	fresh[name] = true
	if ns.UI and ns.UI.Refresh then
		ns.UI.Refresh()
	end
end

--- A player's last known score: gs, level, outdated (known only from an earlier session),
--- and when it was seen (time()).
function GS.Lookup(name)
	name = Short(name)
	local entry = cache and name and cache[name]
	if not entry then
		return nil
	end
	return entry.gs, entry.level, not fresh[name], entry.at
end

-- A listing member's score: the one the listing carries (preview), else the cache.
function GS.Of(member)
	if member.gs then
		return member.gs, member.gsStale == true
	end
	local gs, _, stale = GS.Lookup(member.name)
	return gs, stale
end

-- Stores your own score once your gear has loaded: up to ITEM_RETRIES more tries a second
-- apart, one chain at a time (selfPending) however many events ask for it.
local selfPending = false

local function StoreSelf(tries)
	local gs, complete = GS.Unit("player")
	if complete then
		selfPending = false
		return GS.Store(UnitName("player"), gs, UnitLevel("player"))
	end
	if tries >= ITEM_RETRIES then
		selfPending = false
		return
	end
	selfPending = true
	C_Timer.After(1, function()
		StoreSelf(tries + 1)
	end)
end

-- After an equipment change or a loading screen: one try a second later, unless a chain runs.
local function QueueStoreSelf()
	if selfPending then
		return
	end
	selfPending = true
	C_Timer.After(1, function()
		StoreSelf(0)
	end)
end

--- Your own score: worked out from your gear when it has loaded, else the last one kept.
function GS.Mine()
	local gs, complete = GS.Unit("player")
	if complete then
		return math.floor(gs * 10 + 0.5) / 10
	end
	return (GS.Lookup(UnitName("player")))
end

-------------------------------------------------------------------------------
--  Inspecting your group on a ready check
-------------------------------------------------------------------------------
local queue, current = {}, nil

local Next

local function Done()
	if ClearInspectPlayer then
		ClearInspectPlayer()
	end
	current = nil
	C_Timer.After(INSPECT_GAP, Next)
end

local function Read(tries)
	local c = current
	if not c then
		return
	end
	local gs, complete = GS.Unit(c.unit)
	if complete or tries >= ITEM_RETRIES then
		if complete then
			GS.Store(c.name, gs, UnitLevel(c.unit))
		end
		return Done()
	end
	C_Timer.After(1, function()
		if current == c then
			Read(tries + 1)
		end
	end)
end

local function Busy()
	return InCombatLockdown() or (InspectFrame and InspectFrame:IsShown())
end

function Next()
	if current then
		return
	end
	while #queue > 0 do
		if Busy() then
			return C_Timer.After(INSPECT_GAP * 2, Next)
		end
		local unit = table.remove(queue, 1)
		if UnitExists(unit) and UnitIsConnected(unit) and CanInspect(unit) then
			local c = { unit = unit, guid = UnitGUID(unit), name = UnitName(unit) }
			current = c
			NotifyInspect(unit)
			C_Timer.After(INSPECT_WAIT, function()
				if current == c then
					Done()
				end
			end)
			return
		end
	end
end

--- Queues an inspect of every group member whose score isn't fresh.
function GS.ScanGroup()
	if not selfPending then
		StoreSelf(0)
	end
	for i = #queue, 1, -1 do
		queue[i] = nil
	end
	local raid = IsInRaid()
	local count = raid and GetNumGroupMembers() or GetNumSubgroupMembers()
	for i = 1, count do
		local unit = (raid and "raid" or "party") .. i
		local name = UnitName(unit)
		if name and not UnitIsUnit(unit, "player") and not fresh[Short(name)] then
			queue[#queue + 1] = unit
		end
	end
	Next()
end

local frame

--- Called once the saved variables are loaded. Does nothing while gear score is switched off.
function GS.Init(db)
	if not ns.GEAR_SCORE then
		return
	end
	db.gs = db.gs or {}
	cache = db.gs
	local cutoff = time() - KEEP_DAYS * 86400
	for name, entry in pairs(cache) do
		if type(entry) ~= "table" or (entry.at or 0) < cutoff then
			cache[name] = nil
		end
	end
	if C_Timer and NotifyInspect then
		frame = CreateFrame("Frame")
		frame:SetScript("OnEvent", function(_, event, arg)
			if event == "INSPECT_READY" then
				if current and arg == current.guid then
					Read(0)
				end
			elseif event == "READY_CHECK" then
				GS.ScanGroup()
			elseif event == "PLAYER_EQUIPMENT_CHANGED" or event == "PLAYER_ENTERING_WORLD" then
				QueueStoreSelf()
			end
		end)
		frame:RegisterEvent("INSPECT_READY")
		frame:RegisterEvent("READY_CHECK")
		frame:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
		frame:RegisterEvent("PLAYER_ENTERING_WORLD")
	end
end
