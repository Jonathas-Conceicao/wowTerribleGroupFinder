-------------------------------------------------------------------------------
--  Preview.lua -- sample data for the preview window (ns.Preview), shaped like what the
--  C_LFGList readers will produce: categories, activities and listings. As on Forever, a
--  listing is either a solo player (with the roles they can play) or a group (its leader
--  and members). Nothing here is sent anywhere.
-------------------------------------------------------------------------------
local _, ns = ...

local P = {}
ns.Preview = P

-- Category IDs as in Forever's LFGVanilla_Constants.lua.
P.categories = {
	{ id = 2, name = "Dungeons", atlas = "groupfinder-button-dungeons" },
	{ id = 114, name = "Raids", atlas = "groupfinder-button-raids-warlords" },
	{ id = 116, name = "Quests & Zones", atlas = "groupfinder-button-questing" },
	{ id = 118, name = "Battlegrounds", atlas = "groupfinder-button-battlegrounds" },
	{ id = 120, name = "Custom", atlas = "groupfinder-button-custom-pve" },
}

P.activities = {}
local activities = P.activities
local function A(key, name, category, minLevel, maxLevel, size)
	activities[key] = {
		key = key,
		name = name,
		category = category,
		minLevel = minLevel,
		maxLevel = maxLevel,
		size = size,
	}
end
A("RFC", "Ragefire Chasm", 2, 13, 18, 5)
A("WC", "Wailing Caverns", 2, 17, 24, 5)
A("DM", "The Deadmines", 2, 17, 26, 5)
A("SFK", "Shadowfang Keep", 2, 22, 30, 5)
A("BFD", "Blackfathom Deeps", 2, 24, 32, 5)
A("STOCKS", "The Stockade", 2, 24, 32, 5)
A("GNOMER", "Gnomeregan", 2, 29, 38, 5)
A("RFK", "Razorfen Kraul", 2, 29, 38, 5)
A("SMGY", "Scarlet Monastery: Graveyard", 2, 28, 38, 5)
A("SMLIB", "Scarlet Monastery: Library", 2, 29, 39, 5)
A("SMARM", "Scarlet Monastery: Armory", 2, 32, 42, 5)
A("SMCATH", "Scarlet Monastery: Cathedral", 2, 35, 45, 5)
A("RFD", "Razorfen Downs", 2, 37, 46, 5)
A("ULDA", "Uldaman", 2, 41, 51, 5)
A("ZF", "Zul'Farrak", 2, 42, 46, 5)
A("MARA", "Maraudon", 2, 46, 55, 5)
A("ST", "Sunken Temple", 2, 50, 56, 5)
A("BRD", "Blackrock Depths", 2, 52, 60, 5)
A("LBRS", "Lower Blackrock Spire", 2, 55, 60, 5)
A("DME", "Dire Maul: East", 2, 55, 60, 5)
A("SCHOLO", "Scholomance", 2, 58, 60, 5)
A("STRAT", "Stratholme", 2, 58, 60, 5)
A("UBRS", "Upper Blackrock Spire", 114, 58, 60, 10)
A("ZG", "Zul'Gurub", 114, 60, 60, 20)
A("MC", "Molten Core", 114, 60, 60, 40)
A("ONY", "Onyxia's Lair", 114, 60, 60, 40)
A("BWL", "Blackwing Lair", 114, 60, 60, 40)
A("STV", "Stranglethorn Vale", 116, 30, 45, 5)
A("HILLS", "Hillsbrad Foothills", 116, 20, 30, 5)
A("UNGORO", "Un'Goro Crater", 116, 48, 55, 5)
A("EPL", "Eastern Plaguelands", 116, 53, 60, 5)
A("WS", "Winterspring", 116, 55, 60, 5)
A("WSG", "Warsong Gulch", 118, 10, 60, 10)
A("AB", "Arathi Basin", 118, 20, 60, 15)
A("AV", "Alterac Valley", 118, 51, 60, 40)
A("CUSTOM", "Custom", 120, 1, 60, 40)

-- Members: "Name:CLASS:level:ROLE[@Zone]", the first one leads.
local function Members(list)
	local out = {}
	for i, spec in ipairs(list) do
		local name, class, level, role, rest = spec:match("^([^:]+):(%u+):(%d+):(%u+)(.*)$")
		local zone = rest and rest:match("^@(.+)$")
		out[i] = {
			name = name,
			class = class,
			level = tonumber(level),
			role = role,
			area = zone,
			leader = i == 1,
		}
	end
	return out
end
P.Members = Members

P.listings = {}
local listings = P.listings
local nextId = 0

-- The reserve: extra Dungeons listings the simulated refresh brings in as others leave.
-- Add appends to whichever table is the target.
P.reserve = {}
local target = listings

-- listedAt orders listings in time; a player listing again gets a newer one (and a new id),
-- which is what brings a hidden player back. acts are the activities themselves, as the
-- live reader gives them (name, size, level range, category). As on Forever, one member
-- is a solo player and more is a group.
-- Sample shards, one per listing in turn (US2, US1, AU1); one listing (Delas
-- Moonfang) has an unknown shard, so no flag.
local SHARDS = { 6934, 6925, 6801, 6934 }

local function Add(l, minutes)
	nextId = nextId + 1
	l.id, l.age, l.listedAt = nextId, minutes * 60, -minutes * 60
	l.shard = l.shard or SHARDS[nextId % #SHARDS + 1]
	l.solo = #l.members == 1
	l.voice = l.voiceMode ~= nil and l.voiceMode ~= ns.VOICE.None
	l.acts = {}
	for i, key in ipairs(l.activities) do
		l.acts[i] = activities[key]
	end
	target[#target + 1] = l
	return l
end

-- A group (two members or more): activity keys (one or more), members, comment, minutes
-- listed, extras.
local function Group(keys, members, comment, minutes, extra)
	assert(#members > 1, "a group has two members or more; one is a solo player")
	local l = extra or {}
	l.activities = type(keys) == "table" and keys or { keys }
	l.members = Members(members)
	l.leader = l.members[1]
	l.comment = comment
	return Add(l, minutes)
end

-- A solo player: "Name:CLASS:level", roles they can fill ("THD"), spec, area.
local function Solo(keys, who, roles, spec, area, comment, minutes, extra)
	local l = extra or {}
	local name, class, level = who:match("^([^:]+):(%u+):(%d+)$")
	l.activities = type(keys) == "table" and keys or { keys }
	l.leader = {
		name = name,
		class = class,
		level = tonumber(level),
		spec = spec,
		area = area,
		leader = true,
		roles = { tank = roles:find("T") ~= nil, healer = roles:find("H") ~= nil, dps = roles:find("D") ~= nil },
	}
	l.members = { l.leader }
	l.comment = comment
	return Add(l, minutes)
end

Group("DM", {
	"Varian Wrynn:WARRIOR:21:TANK@Westfall",
	"Anduin Wrynn:PRIEST:20:HEALER@Westfall",
	"Mathias Shaw:ROGUE:22:DAMAGER@Elwynn Forest",
}, "Need 2 dps, VanCleef quest run", 4)
-- Three damage dealers: "Needs my role" keeps this only for players who can tank or heal.
Group("DM", {
	"Valeera Sanguinar:ROGUE:22:DAMAGER@Westfall",
	"Jaina Proudmoore:MAGE:21:DAMAGER",
	"Wilfred Fizzlebang:WARLOCK:22:DAMAGER@Stormwind City",
}, "3 dps here, LF tank + healer", 5)
Group(
	{ "SMGY", "SMLIB" },
	{ "Uther Lightbringer:PALADIN:34:TANK", "Kael'thas Sunstrider:MAGE:33:DAMAGER" },
	"GY then Lib, need healer + 2",
	11,
	{
		voiceMode = ns.VOICE.Discord,
		playstyle = 3,
		counts = { TANK = 1, HEALER = 0, DAMAGER = 1 },
		remaining = { TANK = 0, HEALER = 1, DAMAGER = 2 },
	}
)
Group("WC", {
	"Rehgar Earthfury:SHAMAN:19:HEALER@The Barrens",
	"Nathanos Blightcaller:HUNTER:18:DAMAGER@The Barrens",
	"Ner'zhul Shadowmoon:WARLOCK:20:DAMAGER",
	"Varok Saurfang:WARRIOR:19:DAMAGER@Orgrimmar",
}, "LF tank, we have all quests", 2, { newPlayerFriendly = true })
Group(
	"BRD",
	{
		"Muradin Bronzebeard:WARRIOR:58:TANK@Blackrock Mountain",
		"Moira Thaurissan:PRIEST:57:HEALER@Blackrock Mountain",
		"Brann Bronzebeard:HUNTER:56:DAMAGER@Blackrock Mountain",
		"Aethas Sunreaver:MAGE:58:DAMAGER@Searing Gorge",
	},
	"Arena + Emperor, 1 dps",
	7,
	{
		voiceMode = ns.VOICE.None,
		counts = { TANK = 1, HEALER = 1, DAMAGER = 2 },
		remaining = { TANK = 0, HEALER = 0, DAMAGER = 1 },
	}
)
Group("STRAT", {
	"Tirion Fordring:PALADIN:60:HEALER@Eastern Plaguelands",
	"Teron Gorefiend:WARLOCK:60:DAMAGER@Eastern Plaguelands",
}, "UD strat, LF tank and 2 dps, know the route", 23)
Group("SFK", {
	"Malfurion Stormrage:DRUID:25:TANK@Silverpine Forest",
	"Tyrande Whisperwind:PRIEST:24:HEALER",
	"Garrosh Hellscream:WARRIOR:26:DAMAGER",
	"Garona Halforcen:ROGUE:24:DAMAGER",
	"Ansirem Runeweaver:MAGE:25:DAMAGER",
}, "Full, thanks!", 31, { delisted = true })
Group(
	"ZF",
	{ "Muln Earthfury:SHAMAN:45:DAMAGER@The Temple of Atal'Hakkar", "Vol'jin Darkspear:HUNTER:44:DAMAGER" },
	"Need tank, healer + 1, carrot run",
	1
)
Group(
	"RFK",
	{ "Hamuul Runetotem:DRUID:31:HEALER", "Grommash Hellscream:WARRIOR:30:TANK" },
	"Chill run, newbies welcome",
	15,
	{ newPlayerFriendly = true, voiceMode = ns.VOICE.Legacy, playstyle = 1 }
)
Group("UBRS", {
	"Danath Trollbane:WARRIOR:60:TANK",
	"Alonsus Faol:PRIEST:60:HEALER",
	"Meryl Felstorm:MAGE:60:DAMAGER",
	"Edwin VanCleef:ROGUE:60:DAMAGER",
	"Kanrethad Ebonlocke:WARLOCK:59:DAMAGER",
	"Alleria Windrunner:HUNTER:60:DAMAGER",
}, "Have key, LF healer + dps", 9)
Group("MC", {
	"Magni Bronzebeard:WARRIOR:60:TANK@Blackrock Mountain",
	"Thoras Trollbane:WARRIOR:60:TANK@Blackrock Mountain",
	"Calia Menethil:PRIEST:60:HEALER@Orgrimmar",
	"Natalie Seline:PRIEST:60:HEALER",
	"Fandral Staghelm:DRUID:60:HEALER",
	"Bolvar Fordragon:PALADIN:60:HEALER",
	"Vanessa VanCleef:ROGUE:60:DAMAGER",
	"Millhouse Manastorm:MAGE:60:DAMAGER",
	"Thalen Songweaver:MAGE:60:DAMAGER",
	"Shandris Feathermoon:HUNTER:60:DAMAGER",
	"Vereesa Windrunner:HUNTER:60:DAMAGER",
	"Maiev Shadowsong:ROGUE:60:DAMAGER",
	"Arcanist Doan:MAGE:60:DAMAGER",
	"Darius Crowley:WARRIOR:60:DAMAGER",
}, "Pug MC, SR +1, need fire res healers", 38, { voiceMode = ns.VOICE.Discord })
Group(
	"ONY",
	{
		"Dranosh Saurfang:WARRIOR:60:TANK@Dustwallow Marsh",
		"Lady Liadrin:PALADIN:60:HEALER@Orgrimmar",
		"Sylvanas Windrunner:HUNTER:60:DAMAGER",
	},
	"Ony pug, Discord required",
	19,
	{
		voiceMode = ns.VOICE.Discord,
		playstyle = 4,
		counts = { TANK = 1, HEALER = 1, DAMAGER = 1 },
		remaining = { TANK = 0, HEALER = 0, DAMAGER = 2 },
	}
)
Group(
	"EPL",
	{ "Alexandros Mograine:PALADIN:55:DAMAGER", "Lor'themar Theron:HUNTER:54:DAMAGER" },
	"Questing Tyr's Hand, anyone welcome",
	6
)
Group("STV", {
	"Hemet Nesingwary:HUNTER:38:DAMAGER@Stranglethorn Vale",
	"Talanji Zandalari:PRIEST:37:HEALER@Stranglethorn Vale",
}, "Kill quests in STV, any class", 3)
Group(
	"WSG",
	{ "Broll Bearmantle:DRUID:29:HEALER", "Jarod Shadowsong:WARRIOR:29:DAMAGER", "Lorna Crowley:HUNTER:28:DAMAGER" },
	"19 bracket premade",
	12
)
Group(
	"CUSTOM",
	{ "Archmage Khadgar:MAGE:60:DAMAGER", "Archmage Vargoth:MAGE:60:DAMAGER" },
	"Two mages selling portals",
	45
)

Solo("DM", "Archbishop Benedictus:PRIEST:20", "HD", "Holy", "Westfall", "Healer LF DM group", 3)
Solo(
	"DM",
	"Genn Greymane:WARRIOR:21",
	"TD",
	"Protection",
	"Westfall",
	"Can tank, know the place",
	1,
	{ voiceMode = ns.VOICE.Discord, playstyle = 2 }
)
Solo("DM", "Delas Moonfang:DRUID:20", "HD", nil, "Stormwind City", nil, 2, { shard = 9999 })
Solo("DM", "Archmage Arugal:MAGE:22", "D", "Fire", "Westfall", "Have water for everyone", 4)
Solo({ "DM", "WC" }, "Tess Greymane:ROGUE:19", "D", nil, "The Barrens", "Need the Defias quest", 6)
Solo("DM", "Keeper Remulos:DRUID:21", "THD", "Restoration", "Duskwood", "Any role", 7)
Solo(
	{ "DM", "SFK" },
	"Halduron Brightwing:HUNTER:23",
	"D",
	"Beast Mastery",
	"Redridge Mountains",
	"Pet tanks too lol",
	9
)
Solo("DM", "Saidan Dathrohan:PALADIN:22", "THD", nil, "Westfall", nil, 13)
Solo(
	"DM",
	"Ritssyn Flamescowl:WARLOCK:20",
	"D",
	"Affliction",
	"Elwynn Forest",
	"First time here",
	16,
	{ newPlayerFriendly = true }
)
Solo("DM", "Gryan Stoutmantle:WARRIOR:24", "TD", "Arms", "Westfall", "Can tank if needed", 20)
Solo(
	{ "SMGY", "SMLIB", "SMARM" },
	"Brigitte Abbendis:WARRIOR:35",
	"TD",
	"Protection",
	"Tirisfal Glades",
	"Can tank all SM wings",
	8
)
Solo(
	"BRD",
	"Mathrengyl Bearwalker:DRUID:57",
	"THD",
	"Feral",
	"Burning Steppes",
	"Any role, need the Attunement quest",
	14
)
Solo("WC", "Magister Rommath:MAGE:19", "D", nil, "The Barrens", nil, 1)
Solo("WC", "Magatha Grimtotem:SHAMAN:18", "HD", "Restoration", "The Barrens", nil, 5)
Solo("STRAT", "Taelan Fordring:PALADIN:60", "TH", "Holy", "Eastern Plaguelands", "Prot or holy, Living side", 22)
Solo("MC", "Ormak Grimshot:HUNTER:60", "D", "Marksmanship", "Orgrimmar", "Have fire res gear", 33)
Solo("MC", "Theodrus Frostbeard:PRIEST:60", "H", nil, "Ironforge", "Fire res healer", 12)
Solo("ZF", "Durotan Frostwolf:SHAMAN:44", "HD", "Restoration", "Tanaris", nil, 5)
Solo(
	"RFC",
	"Neeru Fireblade:WARLOCK:15",
	"D",
	nil,
	"Orgrimmar",
	"First time, happy to learn",
	2,
	{ newPlayerFriendly = true }
)

target = P.reserve
Group("WC", {
	"Cairne Bloodhoof:DRUID:20:TANK@Thunder Bluff",
	"Zen'tabra Moonstalker:DRUID:19:HEALER@The Barrens",
	"Hamuul Greymane:HUNTER:18:DAMAGER",
}, "WC from the start, need 2 dps", 1)
Group("SFK", {
	"Lorewalker Cho:PRIEST:25:HEALER@Silverpine Forest",
	"Arugal Sentinel:WARRIOR:24:TANK",
	"Drathir Ashbringer:MAGE:26:DAMAGER",
	"Belmont Vance:ROGUE:25:DAMAGER",
}, "SFK, LF 1 dps", 3)
Group("RFC", {
	"Rokhan Shadowhunter:SHAMAN:15:HEALER@Orgrimmar",
	"Eitrigg Blackhand:WARRIOR:15:TANK@Orgrimmar",
}, "Quick RFC, all quests", 2, { newPlayerFriendly = true })
Group("GNOMER", {
	"Gelbin Mekkatorque:PALADIN:34:TANK@Dun Morogh",
	"Mekgineer Thermaplugg:WARLOCK:33:DAMAGER@Ironforge",
}, "Gnomeregan, LF healer + 2 dps", 1)
Group("BFD", {
	"Tidebinder Alessa:SHAMAN:27:HEALER@Ashenvale",
	"Elune Priestess:PRIEST:26:HEALER",
	"Thrall Windrider:WARRIOR:28:TANK",
	"Dorgan Stonefist:WARRIOR:27:DAMAGER",
}, "BFD, need dps", 5, { voiceMode = ns.VOICE.Discord })
Solo("STOCKS", "Warden Thelwater:WARRIOR:26", "TD", "Protection", "Stormwind City", "Stockade run?", 2)
Solo("RFK", "Agamand Tidehunter:PALADIN:32", "HD", "Holy", "The Barrens", "Healer for Kraul", 4)
Solo({ "DM", "RFK" }, "Mistress Xandria:PRIEST:30", "H", nil, "Redridge Mountains", nil, 6)
target = listings

P.playstyles = { "Learning", "Fun (relaxed)", "Fun (serious)", "Expert" }

-- The party you lead when the preview plays a group leader (you are added first).
P.party = { "Anduin Lothar:WARRIOR:21:TANK", "Kurdran Wildhammer:HUNTER:20:DAMAGER" }

-- Who you know among the sample players: Battle.net friends, character friends,
-- guildmates and recent allies (the game reports these for real listings).
local SOCIAL = {
	["Archbishop Benedictus"] = { bnet = true },
	["Mathias Shaw"] = { bnet = true },
	["Keeper Remulos"] = { friend = true },
	["Uther Lightbringer"] = { guild = true },
	["Kael'thas Sunstrider"] = { guild = true },
	["Varian Wrynn"] = { recent = true },
	["Genn Greymane"] = { recent = true },
	["Taelan Fordring"] = { bnet = true, recent = true },
}
for _, l in ipairs(listings) do
	for _, m in ipairs(l.members) do
		for flag, on in pairs(SOCIAL[m.name] or {}) do
			m[flag] = on
		end
	end
end

-- Seconds the stock-like spinner shows in the preview when Dynamic refresh is off.
P.SEARCH_TIME = 0.5

-- Seconds after a simulated Dynamic refresh before a listing may turn delisted (as one does
-- between the game's refreshes).
P.DELIST_AFTER = 1.5

--- A shown listing turns delisted (greyed, moved to the end), about one time in three.
--- Only `state` changes. Returns the listing, or nil.
function P.DelistOne(state, shownKeys)
	if math.random(3) ~= 1 then
		return nil
	end
	local pool = {}
	for _, l in ipairs(state.listings) do
		if not l.mine and not l.delisted and shownKeys[ns.Listings.Key(l)] then
			pool[#pool + 1] = l
		end
	end
	if #pool == 0 then
		return nil
	end
	local l = pool[math.random(1, #pool)]
	l.delisted = true
	return l
end

--- The shown delisted listings leave (back to the reserve, live again), as the game's
--- Dynamic refresh drops them. Only `state` changes. Returns the key set that left.
function P.DropDelisted(state, shownKeys)
	local removed = {}
	for i = #state.listings, 1, -1 do
		local l = state.listings[i]
		if not l.mine and l.delisted and shownKeys[ns.Listings.Key(l)] then
			table.remove(state.listings, i)
			l.delisted = nil
			removed[ns.Listings.Key(l)] = true
			state.reserve[#state.reserve + 1] = l
		end
	end
	return removed
end

--- One simulated refresh of the preview data: 1-3 of the shown listings leave (back to the
--- reserve) and 1-3 new ones arrive from it. Only `state` changes. Returns the removed and
--- the added key sets.
function P.Churn(state, shownKeys)
	local removed, added = {}, {}
	local candidates = {}
	for _, l in ipairs(state.listings) do
		if not l.mine and shownKeys[ns.Listings.Key(l)] then
			candidates[#candidates + 1] = l
		end
	end
	if #candidates == 0 or #state.reserve == 0 then
		return removed, added
	end

	for _ = 1, math.random(1, math.min(3, #candidates)) do
		local l = table.remove(candidates, math.random(1, #candidates))
		for i, x in ipairs(state.listings) do
			if x == l then
				table.remove(state.listings, i)
				break
			end
		end
		l.delisted = nil
		removed[ns.Listings.Key(l)] = l
		state.reserve[#state.reserve + 1] = l
	end

	local fresh = {}
	for _, l in ipairs(state.reserve) do
		if not removed[ns.Listings.Key(l)] then
			fresh[#fresh + 1] = l
		end
	end
	if #fresh > 0 then
		for _ = 1, math.random(1, math.min(3, #fresh)) do
			local l = table.remove(fresh, math.random(1, #fresh))
			for i, x in ipairs(state.reserve) do
				if x == l then
					table.remove(state.reserve, i)
					break
				end
			end
			l.id, state.nextId = state.nextId, state.nextId + 1
			l.age, l.listedAt, l.delisted = 0, time(), nil
			state.listings[#state.listings + 1] = l
			added[ns.Listings.Key(l)] = l
		end
	end

	for key in pairs(removed) do
		removed[key] = true
	end
	for key in pairs(added) do
		added[key] = true
	end
	return removed, added
end

local searchToken = 0

--- The preview's refresh (the stand-in's button, and Forever's own with /tgf preview): the
--- same path as the game's Dynamic refresh through ns.Motion.Show (the delisted listings
--- swipe out with the ones that left, and a listing may turn delisted a moment later), or,
--- with Dynamic refresh off, a short spinner and a new list.
function P.Refresh()
	ns.Motion.Cancel()
	ns.Table.RelistOneHidden(ns.state.listings)
	local previous = ns.Table.CurrentKeys()
	local state = ns.state
	searchToken = searchToken + 1
	local token = searchToken
	if ns.Settings.Get("dynamicRefresh") ~= false then
		state.previewSearching = false -- a stock search still spinning ends here
		local selected = ns.Table.SelectedKey()
		P.Churn(state, previous)
		P.DropDelisted(state, previous)
		ns.Motion.Show(previous, selected, function()
			C_Timer.After(P.DELIST_AFTER, function()
				if token == searchToken and ns.state == state and P.DelistOne(state, ns.Table.CurrentKeys()) then
					ns.Table.RefreshAll()
				end
			end)
		end)
		return
	end
	P.Churn(state, previous)
	P.DelistOne(state, previous)
	state.previewSearching = true
	ns.Table.ClearSelection()
	C_Timer.After(P.SEARCH_TIME, function()
		if token ~= searchToken or ns.state ~= state then
			return
		end
		state.previewSearching = false
		ns.Table.RefreshAll()
	end)
end
