-------------------------------------------------------------------------------
--  Preview.lua -- sample data for the preview window (ns.Preview), shaped like what the
--  C_LFGList readers will produce: categories, activities and listings. As on Forever, a
--  listing is either a solo player (with the roles they can play) or a group (its leader
--  and members). A gear score ("gs") is only known for players who share it (players
--  running this addon); the rest have none. Nothing here is sent anywhere.
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

-- A gear score: "22.4" known now, "~22.4" known from an earlier session (outdated).
local function GS(text)
	local stale = text:sub(1, 1) == "~"
	return tonumber(stale and text:sub(2) or text), stale or nil
end

-- Members: "Name:CLASS:level:ROLE[:gs]", the first one leads.
local function Members(list)
	local out = {}
	for i, spec in ipairs(list) do
		local name, class, level, role, gs = spec:match("^([^:]+):(%u+):(%d+):(%u+):?(~?[%d%.]*)$")
		local value, stale = GS(gs)
		out[i] = {
			name = name,
			class = class,
			level = tonumber(level),
			role = role,
			gs = value,
			gsStale = stale,
			leader = i == 1,
		}
	end
	return out
end
P.Members = Members

P.listings = {}
local listings = P.listings
local nextId = 0

-- listedAt orders listings in time; a player listing again gets a newer one (and a new id),
-- which is what brings a hidden player back. acts are the activities themselves, as the
-- live reader gives them (name, size, level range, category). As on Forever, one member
-- is a solo player and more is a group.
local function Add(l, minutes)
	nextId = nextId + 1
	l.id, l.age, l.listedAt = nextId, minutes * 60, -minutes * 60
	l.solo = #l.members == 1
	l.voice = l.voiceMode ~= nil and l.voiceMode ~= ns.VOICE.None
	l.acts = {}
	for i, key in ipairs(l.activities) do
		l.acts[i] = activities[key]
	end
	listings[#listings + 1] = l
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

-- A solo player: "Name:CLASS:level[:gs]", roles they can fill ("THD"), spec, area.
local function Solo(keys, who, roles, spec, area, comment, minutes, extra)
	local l = extra or {}
	local name, class, level, gs = who:match("^([^:]+):(%u+):(%d+):?(~?[%d%.]*)$")
	local value, stale = GS(gs)
	l.activities = type(keys) == "table" and keys or { keys }
	l.leader = {
		name = name,
		class = class,
		level = tonumber(level),
		gs = value,
		gsStale = stale,
		spec = spec,
		area = area,
		leader = true,
		roles = { tank = roles:find("T") ~= nil, healer = roles:find("H") ~= nil, dps = roles:find("D") ~= nil },
	}
	l.members = { l.leader }
	l.comment = comment
	return Add(l, minutes)
end

Group(
	"DM",
	{ "Brannoc:WARRIOR:21:TANK:22.4", "Elsiwyn:PRIEST:20:HEALER:~21.0", "Tobbin:ROGUE:22:DAMAGER:23.1" },
	"Need 2 dps, VanCleef quest run",
	4
)
-- Three damage dealers: "Needs my role" keeps this only for players who can tank or heal.
Group(
	"DM",
	{ "Corvin:ROGUE:22:DAMAGER:23.5", "Ellery:MAGE:21:DAMAGER:~20.9", "Haskel:WARLOCK:22:DAMAGER" },
	"3 dps here, LF tank + healer",
	5
)
Group(
	{ "SMGY", "SMLIB" },
	{ "Kaelthorn:PALADIN:34:TANK:36.2", "Mirabelle:MAGE:33:DAMAGER:~31.8" },
	"GY then Lib, need healer + 2",
	11,
	{
		voiceMode = ns.VOICE.Discord,
		playstyle = 3,
		counts = { TANK = 1, HEALER = 0, DAMAGER = 1 },
		remaining = { TANK = 0, HEALER = 1, DAMAGER = 2 },
	}
)
Group(
	"WC",
	{ "Durgash:SHAMAN:19:HEALER", "Pip:HUNTER:18:DAMAGER", "Nyx:WARLOCK:20:DAMAGER:19.8", "Halvard:WARRIOR:19:DAMAGER" },
	"LF tank, we have all quests",
	2,
	{ newPlayerFriendly = true }
)
Group(
	"BRD",
	{
		"Grimtusk:WARRIOR:58:TANK:61.5",
		"Solenne:PRIEST:57:HEALER:57.9",
		"Varok:HUNTER:56:DAMAGER:~55.4",
		"Isolde:MAGE:58:DAMAGER:59.2",
	},
	"Arena + Emperor, 1 dps",
	7,
	{
		voiceMode = ns.VOICE.None,
		counts = { TANK = 1, HEALER = 1, DAMAGER = 2 },
		remaining = { TANK = 0, HEALER = 0, DAMAGER = 1 },
	}
)
Group(
	"STRAT",
	{ "Aldric:PALADIN:60:HEALER:66.0", "Morwen:WARLOCK:60:DAMAGER:63.4" },
	"UD strat, LF tank and 2 dps, know the route",
	23
)
Group("SFK", {
	"Ferris:DRUID:25:TANK",
	"Lunelle:PRIEST:24:HEALER",
	"Kord:WARRIOR:26:DAMAGER",
	"Sable:ROGUE:24:DAMAGER",
	"Quill:MAGE:25:DAMAGER",
}, "Full, thanks!", 31, { delisted = true })
Group("ZF", { "Rhazgul:SHAMAN:45:DAMAGER:44.7", "Zul:HUNTER:44:DAMAGER" }, "Need tank, healer + 1, carrot run", 1)
Group(
	"RFK",
	{ "Tamsin:DRUID:31:HEALER:~33.0", "Bram:WARRIOR:30:TANK:29.6" },
	"Chill run, newbies welcome",
	15,
	{ newPlayerFriendly = true, voiceMode = ns.VOICE.Legacy, playstyle = 1 }
)
Group("UBRS", {
	"Ostrava:WARRIOR:60:TANK:68.1",
	"Bellamy:PRIEST:60:HEALER:64.3",
	"Cinder:MAGE:60:DAMAGER",
	"Thane:ROGUE:60:DAMAGER:65.0",
	"Vex:WARLOCK:59:DAMAGER",
	"Rook:HUNTER:60:DAMAGER:62.2",
}, "Have key, LF healer + dps", 9)
Group("MC", {
	"Aethelred:WARRIOR:60:TANK:72.3",
	"Corwin:WARRIOR:60:TANK:70.1",
	"Ysolde:PRIEST:60:HEALER:69.4",
	"Bryn:PRIEST:60:HEALER",
	"Faelan:DRUID:60:HEALER:66.8",
	"Hollis:PALADIN:60:HEALER",
	"Gerrit:ROGUE:60:DAMAGER:68.0",
	"Iona:MAGE:60:DAMAGER",
	"Jareth:MAGE:60:DAMAGER:67.5",
	"Kestra:HUNTER:60:DAMAGER",
	"Lorne:WARLOCK:60:DAMAGER",
	"Mael:ROGUE:60:DAMAGER:64.9",
	"Nessa:MAGE:60:DAMAGER",
	"Orrin:WARRIOR:60:DAMAGER",
}, "Pug MC, SR +1, need fire res healers", 38, { voiceMode = ns.VOICE.Discord })
Group(
	"ONY",
	{ "Pellam:WARRIOR:60:TANK:69.9", "Quenna:PRIEST:60:HEALER", "Rivka:MAGE:60:DAMAGER" },
	"Ony pug, Discord required",
	19,
	{
		voiceMode = ns.VOICE.Discord,
		playstyle = 4,
		counts = { TANK = 1, HEALER = 1, DAMAGER = 1 },
		remaining = { TANK = 0, HEALER = 0, DAMAGER = 2 },
	}
)
Group("EPL", { "Stellan:PALADIN:55:DAMAGER", "Torva:HUNTER:54:DAMAGER:53.0" }, "Questing Tyr's Hand, anyone welcome", 6)
Group("STV", { "Ulric:ROGUE:38:DAMAGER", "Maren:PRIEST:37:HEALER:~36.1" }, "Kill quests in STV, any class", 3)
Group("WSG", { "Wren:DRUID:29:HEALER", "Xander:WARRIOR:29:DAMAGER", "Yara:ROGUE:28:DAMAGER" }, "19 bracket premade", 12)
Group("CUSTOM", { "Zephyr:MAGE:60:DAMAGER", "Sorrel:MAGE:60:DAMAGER" }, "Two mages selling portals", 45)

Solo("DM", "Ashlin:PRIEST:20:21.3", "HD", "Holy", "Westfall", "Healer LF DM group", 3)
Solo(
	"DM",
	"Ironvale:WARRIOR:21:24.0",
	"TD",
	"Protection",
	"Westfall",
	"Can tank, know the place",
	1,
	{ voiceMode = ns.VOICE.Discord, playstyle = 2 }
)
Solo("DM", "Saelis:PRIEST:20:~19.5", "HD", nil, "Stormwind City", nil, 2)
Solo("DM", "Quintus:MAGE:22:~23.0", "D", "Fire", "Westfall", "Have water for everyone", 4)
Solo({ "DM", "WC" }, "Marrow:ROGUE:19", "D", nil, "The Barrens", "Need the Defias quest", 6)
Solo("DM", "Lyss:DRUID:21:20.6", "THD", "Restoration", "Duskwood", "Any role", 7)
Solo({ "DM", "SFK" }, "Torvald:HUNTER:23:25.1", "D", "Beast Mastery", "Redridge Mountains", "Pet tanks too lol", 9)
Solo("DM", "Bertram:PALADIN:22:~21.7", "THD", nil, "Westfall", nil, 13)
Solo(
	"DM",
	"Cressida:WARLOCK:20:18.7",
	"D",
	"Affliction",
	"Elwynn Forest",
	"First time here",
	16,
	{ newPlayerFriendly = true }
)
Solo("DM", "Dunstan:WARRIOR:24:26.2", "TD", "Arms", "Westfall", "Can tank if needed", 20)
Solo(
	{ "SMGY", "SMLIB", "SMARM" },
	"Boruk:WARRIOR:35:37.4",
	"TD",
	"Protection",
	"Tirisfal Glades",
	"Can tank all SM wings",
	8
)
Solo("BRD", "Cael:DRUID:57:58.8", "THD", "Feral", "Burning Steppes", "Any role, need the Attunement quest", 14)
Solo("WC", "Delphine:MAGE:19", "D", nil, "The Barrens", nil, 1)
Solo("WC", "Fennick:SHAMAN:18:17.9", "HD", "Restoration", "The Barrens", nil, 5)
Solo("STRAT", "Eamon:PALADIN:60:65.2", "TH", "Holy", "Eastern Plaguelands", "Prot or holy, Living side", 22)
Solo("MC", "Fenna:HUNTER:60:67.1", "D", "Marksmanship", "Orgrimmar", "Have fire res gear", 33)
Solo("MC", "Garran:PRIEST:60", "H", nil, "Ironforge", "Fire res healer", 12)
Solo("ZF", "Gwyn:SHAMAN:44:~43.5", "HD", "Restoration", "Tanaris", nil, 5)
Solo("RFC", "Hale:WARLOCK:15", "D", nil, "Orgrimmar", "First time, happy to learn", 2, { newPlayerFriendly = true })

P.playstyles = { "Learning", "Fun (relaxed)", "Fun (serious)", "Expert" }

-- The party you lead when the preview plays a group leader (you are added first).
P.party = { "Garrick:WARRIOR:21:TANK:23.8", "Neve:HUNTER:20:DAMAGER" }

-- Who you know among the sample players: Battle.net friends, character friends,
-- guildmates and recent allies (the game reports these for real listings).
local SOCIAL = {
	Ashlin = { bnet = true },
	Tobbin = { bnet = true },
	Lyss = { friend = true },
	Kaelthorn = { guild = true },
	Mirabelle = { guild = true },
	Brannoc = { recent = true },
	Ironvale = { recent = true },
	Eamon = { bnet = true, recent = true },
}
for _, l in ipairs(listings) do
	for _, m in ipairs(l.members) do
		for flag, on in pairs(SOCIAL[m.name] or {}) do
			m[flag] = on
		end
	end
end
