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
--    inspect that isn't ours; ours is dropped (stores nothing, clears nothing) when
--    another one starts after it; a value is stored only for the GUID of the latest
--    inspect, checked when it answers and again when it is read; ClearInspectPlayer only
--    when no later inspect started and the window is closed. One that brings nothing
--    waits 30 s to be tried again. A known value is kept for the session, never looked up again, and only
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
local MATCH = 0.001 -- how close our average must come to your exact figure
local SLOTS = 16

local GetItemLevel = C_Item and C_Item.GetDetailedItemLevelInfo or GetDetailedItemLevelInfo
local GetItemInfoInstant = C_Item and C_Item.GetItemInfoInstant or GetItemInfoInstant
local GetItemInfo = C_Item and C_Item.GetItemInfo or GetItemInfo

local known = {} -- guid -> { ilvl, source, name, at }, this session only

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

local function Remember(unit, r)
	local guid, name = UnitGUID(unit), UnitName(unit)
	if Secret(guid) or not guid or not r.complete then
		return nil
	end
	local ilvl, source = r.game, "game"
	if not ilvl then
		ilvl, source = math.floor(ILvl.Average(r) + 0.5), "ours" -- whole, as the game's
	end
	known[guid] = { ilvl = ilvl, source = source, name = not Secret(name) and name or nil, at = time() }
	for _, fn in ipairs(learned) do
		local ok, err = pcall(fn, guid, ilvl)
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
end

-------------------------------------------------------------------------------
--  Inspecting: one at a time, INSPECT_GAP apart; the probe's queue, and a quiet one
--  for a friendly player's tooltip whose item level isn't known yet.
--
--  The guard (the game has one inspect slot, shared with its Inspect window and other
--  addons): we stay away while the window is shown or pending (InspectFrame.unit set
--  before it shows, for at most INSPECT_WAIT after InspectUnit: the game never clears a
--  unit whose answer didn't come) and for OTHERS_BUSY seconds after an inspect that isn't ours; ours
--  is dropped when another starts after it. serial counts every NotifyInspect, lastTarget
--  is the latest one's GUID, readyGUID / readySerial the latest answer to it.
-------------------------------------------------------------------------------
local OTHERS_BUSY = 2 -- seconds an inspect that is not ours keeps us away
local queue, current, probing = {}, nil, false
local lastInspect = -math.huge
local tried = {} -- guid -> GetTime() of a quiet inspect that brought nothing
local serial = 0 -- bumped on every NotifyInspect, ours or not
local lastTarget = nil -- GUID of the latest NotifyInspect target (nil when unreadable)
local othersAt = -math.huge -- GetTime() of the latest inspect that is not ours
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

local function Busy()
	return InCombatLockdown() or InspectOpen() or GetTime() - othersAt < OTHERS_BUSY
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
	if ClearInspectPlayer and not InspectOpen() and serial == c.serial and othersAt < c.sentAt then
		ClearInspectPlayer()
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
	local unit = FindUnit(c.guid, c.unit)
	if not unit then
		if not c.quiet then
			Print(("%s: out of sight before the inspect could be read."):format(c.name))
		end
		return Done(c, false)
	end
	local r = ILvl.Read(unit)
	if r.complete or tries >= ITEM_RETRIES then
		local ilvl, source = Remember(unit, r)
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
		end
		return Done(c, ilvl ~= nil)
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
			Print("waiting: in combat or the Inspect window is open.")
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
	return entry and math.floor(entry.ilvl + 0.5) or nil
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
	local function Try()
		if serial ~= s or lastTarget ~= guid then
			return
		end
		local u = FindUnit(guid, unit)
		if not u then
			return
		end
		local r = ILvl.Read(u)
		if r.complete or tries >= ITEM_RETRIES then
			return Remember(u, r)
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
