-------------------------------------------------------------------------------
--  Listings.lua -- Forever's search results (ns.Listings), read into the same shape as the
--  preview's sample listings: id, solo, leader, members (name, class, level, role, and for
--  a solo player their roles, spec and area), acts (name, size, level range, category),
--  comment, age, listedAt, delisted, mine. Read only after the game's own search; never
--  searches by itself. Any value the client hands back as secret skips the listing.
-------------------------------------------------------------------------------
local _, ns = ...

local L = { items = {} }
ns.Listings = L

local MAX_RESULTS = 200
local ROLE_OF = { TANK = "TANK", HEALER = "HEALER", DAMAGER = "DAMAGER" }

local function Secret(v)
	return v ~= nil and issecretvalue ~= nil and issecretvalue(v)
end

local acts = {} -- activityID -> our activity table, made once each
local function Act(id)
	local a = acts[id]
	if a then
		return a
	end
	local info = C_LFGList.GetActivityInfoTable(id)
	if type(info) ~= "table" or Secret(info.fullName) then
		return nil
	end
	a = {
		key = id,
		name = (info.shortName and info.shortName ~= "") and info.shortName or info.fullName,
		fullName = info.fullName,
		category = info.categoryID,
		minLevel = info.minLevelSuggestion or info.minLevel or 1,
		maxLevel = info.maxLevelSuggestion or 60,
		size = (info.maxNumPlayers and info.maxNumPlayers > 0) and info.maxNumPlayers or 5,
	}
	acts[id] = a
	return a
end
L.Act = Act

local function Member(id, i)
	local p = C_LFGList.GetSearchResultPlayerInfo(id, i)
	if type(p) ~= "table" then
		return nil
	end
	if Secret(p.name) or Secret(p.level) or Secret(p.classFilename) or Secret(p.assignedRole) then
		return nil
	end
	if not p.name then
		return nil
	end
	local m = {
		name = ns.GS.Short(p.name),
		fullName = p.name,
		class = p.classFilename or "WARRIOR",
		level = p.level or 0,
		role = ROLE_OF[p.assignedRole] or "DAMAGER",
		leader = p.isLeader == true,
		spec = p.specName,
		area = p.areaName,
	}
	local r = p.lfgRoles
	if type(r) == "table" then
		m.roles = { tank = r.tank == true, healer = r.healer == true, dps = r.dps == true }
	end
	return m
end

-- Marks the members you know: Battle.net friends, character friends and guildmates as the
-- game lists them for the result (GetSearchResultFriends, as the retail finder's tooltip
-- uses), and recent allies (C_RecentAllies, as chat marks them).
local function Names(list, set)
	for k in pairs(set) do
		set[k] = nil
	end
	for _, name in ipairs(type(list) == "table" and list or {}) do
		if type(name) == "string" and not Secret(name) then
			set[ns.GS.Short(name)] = true
		end
	end
	return set
end
local bnetSet, charSet, guildSet = {}, {}, {}

function L.Social(id, members)
	if C_LFGList.GetSearchResultFriends then
		local ok, bnet, chars, guild = pcall(C_LFGList.GetSearchResultFriends, id)
		if ok then
			Names(bnet, bnetSet)
			Names(chars, charSet)
			Names(guild, guildSet)
			for _, m in ipairs(members) do
				m.bnet, m.friend, m.guild = bnetSet[m.name], charSet[m.name], guildSet[m.name]
			end
		end
	end
	local RA = C_RecentAllies
	if RA and RA.IsSystemEnabled and RA.IsRecentAllyByFullName then
		local ok, enabled = pcall(RA.IsSystemEnabled)
		if ok and enabled then
			for _, m in ipairs(members) do
				local found, ally = pcall(RA.IsRecentAllyByFullName, m.fullName)
				m.recent = found and ally == true or nil
			end
		end
	end
end

local function Read(id, now)
	local info = C_LFGList.GetSearchResultInfo(id)
	if type(info) ~= "table" then
		return nil
	end
	if Secret(info.numMembers) or Secret(info.age) or Secret(info.activityIDs) then
		return nil
	end
	local l = { id = id, acts = {}, members = {} }
	for _, aid in ipairs(info.activityIDs or {}) do
		local a = Act(aid)
		if a then
			l.acts[#l.acts + 1] = a
		end
	end
	if #l.acts == 0 then
		return nil
	end
	for i = 1, info.numMembers or 0 do
		local m = Member(id, i)
		if m then
			l.members[#l.members + 1] = m
		end
	end
	if #l.members == 0 then
		return nil
	end
	for _, m in ipairs(l.members) do
		if m.leader then
			l.leader = m
		end
	end
	l.leader = l.leader or l.members[1]
	L.Social(id, l.members)
	l.solo = (info.numMembers or 1) == 1
	if l.solo then
		l.leader.roles = l.leader.roles or { tank = false, healer = false, dps = true }
	end
	-- The comment is shown as is; it may not support string work, so it is not searched.
	l.comment = not Secret(info.comment) and info.comment or nil
	l.age = info.age or 0
	l.listedAt = now - l.age
	l.delisted = info.isDelisted == true
	l.mine = info.hasSelf == true or nil
	l.voice = info.voiceMode ~= nil and info.voiceMode ~= 0
	l.newPlayerFriendly = info.newPlayerFriendly == true
	return l
end

--- Reads the last search's results; returns the listings.
function L.Read()
	local items = L.items
	for i = #items, 1, -1 do
		items[i] = nil
	end
	if not (C_LFGList and C_LFGList.GetSearchResultInfo) then
		return items
	end
	if C_ChatInfo and C_ChatInfo.InChatMessagingLockdown and C_ChatInfo.InChatMessagingLockdown() then
		return items
	end
	local get = C_LFGList.GetFilteredSearchResults or C_LFGList.GetSearchResults
	local _, results = get()
	local now = GetTime()
	for i = 1, math.min(type(results) == "table" and #results or 0, MAX_RESULTS) do
		local id = results[i]
		if not Secret(id) then
			local ok, l = pcall(Read, id, now)
			if ok and l then
				items[#items + 1] = l
			end
		end
	end
	return items
end

--- Whether the client has the group finder API at all.
function L.HasAPI()
	return C_LFGList ~= nil and C_LFGList.GetSearchResultInfo ~= nil and C_LFGList.GetPremadeGroupFinderStyle ~= nil
end
