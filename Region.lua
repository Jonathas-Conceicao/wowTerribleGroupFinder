-------------------------------------------------------------------------------
--  Region.lua -- region flags and probe (ns.Region): a flag (US / Oceania) on each
--  listing, from the shard ID in its partyGUID. Forever's shards are hidden, but
--  Battle.net friends' game accounts name them and GUIDs carry a server ID. /tgf region
--  prints the IDs it finds: your own, your friends', the group's and the listings'.
-------------------------------------------------------------------------------
local _, ns = ...

local R = {}
ns.Region = R

-------------------------------------------------------------------------------
--  Region flags: a listing's partyGUID ("Party-<shard>-...") names the hidden shard its
--  leader plays on, the same ID as the shard's realm ID. A shard's name
--  ("CAMWOW US2 Realm 8 PvP") gives its group (US1, US2, AU1 and so on). Rules:
--    * the tooltip names the group as the game does ("US1"); where it is isn't assumed
--    * the flag is the group's country (its first two letters): one US flag for both US
--      groups, the Oceania flag for AU; no flag for a country we have no art for (its
--      tooltip line still shows) nor for an unknown shard
--    * the seeded table wins; learned shards (your own, Battle.net friends', saved in
--      DB.shards) only fill gaps
--    * your own listing shows the group leader's region (yours when solo or leading)
--    * all of it is gated by the regionFlags setting, read where it acts
--  Only shards seen live are seeded (US and AU); other regions' (EU and so on) are learned
--  from your own realm and your Battle.net friends', so they show once seen.
-------------------------------------------------------------------------------
local FLAGS = "Interface\\AddOns\\TerribleGroupFinder\\Media\\Textures\\flag_"
-- The flag art each country has (Media/Textures/flag_<name>).
local FLAG_ART = { US = "us", AU = "au" }
-- Seen with /tgf region on live Forever (2026-11-14): realm ID = GUID server ID.
local KNOWN = { [6925] = "US1", [6930] = "US2", [6933] = "US2", [6934] = "US2", [6801] = "AU1" }

local learned = {} -- shard ID -> group, saved in DB.shards once the DB is loaded

local function Plain(v)
	return v ~= nil and not (issecretvalue and issecretvalue(v))
end

-- The server ID a GUID carries ("Player-<server>-<id>", "Party-<server>-<id>").
local function Server(guid)
	if type(guid) ~= "string" or (issecretvalue and issecretvalue(guid)) then
		return nil
	end
	return guid:match("^[^-]+%-([^-]+)")
end
R.Server = Server

--- The group ("US2") a shard name gives, or nil when it isn't a Forever shard name.
function R.Group(name)
	if type(name) ~= "string" or not Plain(name) then
		return nil
	end
	return (name:gsub("%s", "")):upper():match("^CAMWOW(%a%a%d*)REALM")
end

--- Remember a shard's group; a seeded shard is never overridden. True when it is new.
function R.Learn(id, name)
	local group = R.Group(name)
	id = Plain(id) and tonumber(id) or nil
	if id and group and not KNOWN[id] and learned[id] ~= group then
		learned[id] = group
		return true
	end
	return false
end

--- Where a shard is ({ flag, label, group, source }), or nil when unknown. label is the group
--- ("US1"); flag is nil for a country we have no art for.
function R.Of(shard)
	if not Plain(shard) then
		return nil
	end
	local id = tonumber(shard)
	local group = id and KNOWN[id]
	local source = "seeded"
	if not group then
		group = id and learned[id]
		source = "learned"
	end
	if not group then
		return nil
	end
	return { flag = FLAG_ART[group:sub(1, 2)], label = group, group = group, source = source }
end

function R.Enabled()
	return ns.Settings.Get("regionFlags") ~= false
end

local function PlainIs(v, want)
	return Plain(v) and v == want
end

--- Where a listing is: yours = the leader's region (yours when solo or leading), else its shard.
--- In a group whose leader flag can't be read (secret or nil), the listing's own shard.
function R.ForListing(l)
	if l.mine and not ns.UsingPreview() then
		local place
		local grouped = IsInGroup and IsInGroup()
		local lead
		if grouped then
			lead = UnitIsGroupLeader("player")
		end
		if grouped and not Plain(lead) then
			return R.Of(l.shard) -- can't tell who leads: the party's own shard
		end
		if grouped and lead == false then
			local raid = IsInRaid and IsInRaid()
			local n = raid and GetNumGroupMembers() or GetNumSubgroupMembers()
			for i = 1, Plain(n) and tonumber(n) or 0 do
				local unit = (raid and "raid" or "party") .. i
				if PlainIs(UnitIsGroupLeader(unit), true) then
					place = R.Of(Server(UnitGUID(unit)))
					break
				end
			end
		else
			local ok, id = pcall(GetRealmID)
			place = ok and R.Of(id) or nil
			place = place or R.Of(Server(UnitGUID("player")))
		end
		if place then
			return place
		end
	end
	return R.Of(l.shard)
end

--- The tooltip line naming the region, or nil.
function R.Line(l)
	if not R.Enabled() then
		return nil
	end
	local place = R.ForListing(l)
	if not place then
		return nil
	end
	local group = not l.solo and #l.members > 1
	return (group and "Leader's region: " or "Region: ") .. place.label
end

--- The flag texture to draw ({ file, coords, width, height, place }), or nil.
function R.Flag(l)
	if not R.Enabled() then
		return nil
	end
	local place = R.ForListing(l)
	if not place or not place.flag then
		return nil
	end
	return {
		file = FLAGS .. place.flag,
		coords = { 0, 1, 12 / 64, 52 / 64 },
		width = 16,
		height = 10,
		place = place,
	}
end

-- Your own shard and the ones Battle.net friends in game are on. A newly learned shard
-- redraws the table, so its flags show without waiting for the next search.
local function LearnAround()
	local added = false
	if GetRealmID and GetRealmName then
		pcall(function()
			added = R.Learn(GetRealmID(), GetRealmName()) or added
		end)
	end
	local BN = C_BattleNet
	if BN and BN.GetFriendNumGameAccounts and BN.GetFriendGameAccountInfo and BNGetNumFriends then
		local ok, n = pcall(BNGetNumFriends)
		for f = 1, (ok and Plain(n) and tonumber(n)) or 0 do
			local okA, accounts = pcall(BN.GetFriendNumGameAccounts, f)
			for a = 1, (okA and Plain(accounts) and tonumber(accounts)) or 0 do
				local okG, g = pcall(BN.GetFriendGameAccountInfo, f, a)
				if okG and type(g) == "table" then
					added = R.Learn(g.realmID, g.realmName) or added
				end
			end
		end
	end
	if added and ns.Table and ns.Table.RefreshAll then
		ns.Table.RefreshAll()
	end
end

local scanPending = false
local function ScanSoon()
	if scanPending then
		return
	end
	scanPending = true
	C_Timer.After(2, function()
		scanPending = false
		LearnAround()
	end)
end

local hooked = false

local function Sane(id, group)
	return type(id) == "number" and type(group) == "string" and group:match("^%u%u%d*$") ~= nil and not KNOWN[id]
end

function R.Init(db)
	local saved = type(db.shards) == "table" and db.shards or {}
	for id, group in pairs(saved) do
		if not Sane(id, group) then
			saved[id] = nil
		end
	end
	for id, group in pairs(learned) do
		if saved ~= learned and Sane(id, group) then
			saved[id] = group
		end
	end
	db.shards = saved
	learned = saved
	if not hooked then
		hooked = true
		ns.Settings.OnChange("regionFlags", function()
			if ns.Table and ns.Table.RefreshAll then
				ns.Table.RefreshAll()
			end
		end)
	end
	local f = CreateFrame("Frame")
	for _, event in ipairs({ "PLAYER_LOGIN", "BN_FRIEND_INFO_CHANGED", "BN_FRIEND_ACCOUNT_ONLINE" }) do
		pcall(f.RegisterEvent, f, event)
	end
	f:SetScript("OnEvent", ScanSoon)
end

local function Show(v)
	if v == nil then
		return "nil"
	end
	if issecretvalue and issecretvalue(v) then
		return "<secret>"
	end
	return tostring(v)
end

local function Call(fn, ...)
	if type(fn) ~= "function" then
		return "n/a"
	end
	local out = { pcall(fn, ...) }
	if not out[1] then
		return "error"
	end
	for i = 2, #out do
		out[i] = Show(out[i])
	end
	return #out > 1 and table.concat(out, ", ", 2) or "nothing"
end

local function Unit(unit)
	local guid = UnitGUID(unit)
	if not guid then
		return
	end
	local realm = select(8, pcall(GetPlayerInfoByGUID, guid)) -- after pcall's ok: the 7th value
	ns.Print(
		string.format(
			"  %s %s: guid %s (server %s), GetPlayerInfoByGUID realm %s, UnitName realm %s",
			unit,
			Show(UnitName(unit)),
			Show(guid),
			Show(Server(guid)),
			Show(realm),
			Show(select(2, UnitName(unit)))
		)
	)
end

function R.Probe()
	local P = ns.Print
	P("region probe:")
	LearnAround()
	P("  GetCurrentRegion: " .. Call(GetCurrentRegion) .. ", name: " .. Call(GetCurrentRegionName))
	P(
		"  GetRealmID: "
			.. Call(GetRealmID)
			.. ", GetRealmName: "
			.. Call(GetRealmName)
			.. ", normalized: "
			.. Call(GetNormalizedRealmName)
	)
	local AS = C_AccountServices
	if AS then
		P("  preferred play settings: " .. Call(AS.GetPreferredPlaySettings))
		local ok, ids, names = pcall(AS.GetPreferredDatacenterLocalities or error)
		if ok and type(ids) == "table" then
			for i, id in ipairs(ids) do
				P(string.format("    locality %s = %s", Show(id), Show(type(names) == "table" and names[i] or nil)))
			end
		end
	end
	Unit("player")
	for i = 1, 4 do
		Unit("party" .. i)
	end
	Unit("target")

	-- Battle.net friends in game: the shard name and realm ID next to their character's GUID.
	local BN = C_BattleNet
	if BN and BN.GetFriendNumGameAccounts and BN.GetFriendGameAccountInfo and BNGetNumFriends then
		P("  Battle.net friends in game:")
		local shown = 0
		local okN, n = pcall(BNGetNumFriends)
		for f = 1, (okN and Plain(n) and tonumber(n)) or 0 do
			local okA, accounts = pcall(BN.GetFriendNumGameAccounts, f)
			for a = 1, (okA and Plain(accounts) and tonumber(accounts)) or 0 do
				local ok, g = pcall(BN.GetFriendGameAccountInfo, f, a)
				if ok and type(g) == "table" and g.characterName and shown < 15 then
					shown = shown + 1
					P(
						string.format(
							"    %s: realm %s (id %s), region %s, project %s, guid %s (server %s)",
							Show(g.characterName),
							Show(g.realmName),
							Show(g.realmID),
							Show(g.regionID),
							Show(g.wowProjectID),
							Show(g.playerGuid),
							Show(Server(g.playerGuid))
						)
					)
				end
			end
		end
	end

	-- Search results: the partyGUID each listing carries.
	if C_LFGList and C_LFGList.GetSearchResultInfo then
		P("  listings (partyGUID server):")
		local counts = {}
		for _, l in ipairs(ns.Listings.items) do
			if type(l.id) == "number" then
				local ok, info = pcall(C_LFGList.GetSearchResultInfo, l.id)
				local guid = ok and type(info) == "table" and info.partyGUID or nil
				local server = Server(guid) or "?"
				counts[server] = (counts[server] or 0) + 1
				if counts[server] <= 3 then
					P(
						string.format(
							"    %s%s: %s (server %s: %s)",
							l.solo and "" or "group ",
							l.leader.name,
							Show(guid),
							server,
							R.Of(server) and (R.Of(server).label .. " (" .. R.Of(server).source .. ")") or "unknown"
						)
					)
				end
			end
		end
		for server, n in pairs(counts) do
			local place = R.Of(server)
			P(string.format("    server %s (%s): %d listings", server, place and place.group or "unknown", n))
		end
	end
end
