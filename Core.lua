-------------------------------------------------------------------------------
--  Core.lua -- namespace, saved variables, runtime state, the questions the table asks
--  (are you leading, allowed to invite, your roles and party), and slash
--  commands. Each answer comes from the game, or from the sample data while the preview
--  runs: always where the game's group finder is missing, on request in game.
-------------------------------------------------------------------------------
local addonName, ns = ...

local GetMetadata = C_AddOns and C_AddOns.GetAddOnMetadata or GetAddOnMetadata

ns.version = GetMetadata and GetMetadata(addonName, "Version") or "dev"

-- How a listing's voice chat is set up (the game's enum; the same values elsewhere).
ns.VOICE = (Enum and Enum.LFGEntryVoiceMode) or { None = 0, Legacy = 1, Discord = 2, Custom = 3 }

--- A character name without its realm suffix; nil for anything but a readable string (a
--- secret value can't be matched or used as a key).
function ns.Short(name)
	if type(name) ~= "string" or (issecretvalue and issecretvalue(name)) then
		return nil
	end
	return name:match("^([^%-]+)") or name
end

local DEFAULTS = {
	schema = 4,
}

-- The options on by default up to v0.2.2, frozen (never read from the registry, whose
-- defaults are now the new ones).
local V022_ON = {
	"ilvlPlayerTooltip",
	"specPoints",
	"ilvlItemTooltip",
	"ilvlCharacterSheet",
	"ilvlInspect",
	"meterResetOnInstance",
}

-- Saved data from an older version, brought up to schema 4 in place (the table is never
-- replaced: the settings registry, the presets and the shard table all hold it). Runs
-- before every module's Init. The obsolete keys go on every load, so a trip back to an
-- older version that wrote them again leaves nothing behind.
-- Schema 3: meterResetOnGroup defaults off for new installs; saved data from an earlier
-- schema gets it saved on, unless the player set it. "Saved data" is whether the table
-- held any key when the addon loaded, which is why Migrate runs before DEFAULTS are
-- filled in.
-- Schema 4: only the group finder's options (and the Elite quest button) are on for new
-- installs; saved data from an earlier schema gets the six options that were on by default
-- in v0.2.2 saved on, unless the player set them. A table holding only `schema` counts as
-- saved data (a v0.2.x install that never set anything). Options new in v0.3.0 follow their
-- defaults for everyone.
function ns.Migrate(db)
	local existing = next(db) ~= nil
	db.gs = nil -- v0.1 gear score cache
	db.autoRefresh = nil -- an unused key from a development build, cleared
	if (tonumber(db.schema) or 0) < 3 then
		if existing and type(db.meterResetOnGroup) ~= "boolean" then
			db.meterResetOnGroup = true
		end
		db.schema = 3
	end
	if (tonumber(db.schema) or 0) < 4 then
		if existing then
			for _, key in ipairs(V022_ON) do
				if type(db[key]) ~= "boolean" then
					db[key] = true
				end
			end
		end
		db.schema = 4
	end
end

local function Print(...)
	print("|cff4fc3f7TerribleGroupFinder|r:", ...)
end
ns.Print = Print

function ns.PlayerLevel()
	local level = UnitLevel and UnitLevel("player")
	return (type(level) == "number" and level > 0) and level or 21
end

-- Roles each class can play.
ns.CLASS_ROLES = {
	WARRIOR = { tank = true, dps = true },
	PALADIN = { tank = true, healer = true, dps = true },
	HUNTER = { dps = true },
	ROGUE = { dps = true },
	PRIEST = { healer = true, dps = true },
	SHAMAN = { healer = true, dps = true },
	MAGE = { dps = true },
	WARLOCK = { dps = true },
	DRUID = { tank = true, healer = true, dps = true },
}

function ns.PlayerClass()
	local _, class = UnitClass("player")
	return ns.CLASS_ROLES and ns.CLASS_ROLES[class] and class or "PALADIN"
end

local function Copy(t)
	local out = {}
	for k, v in pairs(t) do
		out[k] = type(v) == "table" and Copy(v) or v
	end
	return out
end

function ns.UsingPreview()
	return ns.state ~= nil and ns.state.preview == true
end

function ns.IsLeader()
	if ns.UsingPreview() then
		return ns.state.asLeader
	end
	return IsInGroup() and UnitIsGroupLeader("player") == true
end

-- Forever's own rule for its Group Invite button.
function ns.CanInvite()
	if ns.UsingPreview() then
		return true
	end
	return not IsInGroup() or UnitIsGroupLeader("player") or UnitIsGroupAssistant("player") or false
end

-- How many players are in your group now, counting you: 1 solo.
function ns.GroupSize()
	if ns.UsingPreview() then
		return #ns.Party()
	end
	local n = GetNumGroupMembers and GetNumGroupMembers() or 0
	if issecretvalue and issecretvalue(n) then
		n = 0
	end
	return math.max(n or 0, 1)
end

-- The roles you play: the game's saved group finder roles, else the preview's.
function ns.MyRoles()
	if not ns.UsingPreview() and C_LFGListRoles and C_LFGListRoles.GetRoles then
		local r = C_LFGListRoles.GetRoles()
		if type(r) == "table" then
			return { tank = r.tank == true, healer = r.healer == true, dps = r.dps == true }
		end
	end
	return ns.state.roles
end

-- You, as a listing member.
function ns.Me()
	local roles = ns.MyRoles()
	local me = {
		name = UnitName("player") or "You",
		class = ns.PlayerClass(),
		level = ns.PlayerLevel(),
		role = roles.tank and "TANK" or roles.healer and "HEALER" or "DAMAGER",
		roles = { tank = roles.tank, healer = roles.healer, dps = roles.dps },
		leader = true,
	}
	return me
end

local ROLE_OF = { TANK = "TANK", HEALER = "HEALER", DAMAGER = "DAMAGER" }

-- Your party, you first: the game's group, or in the preview the sample party while it
-- plays a leader.
function ns.Party()
	local party = { ns.Me() }
	if ns.UsingPreview() then
		if ns.state.asLeader then
			for _, m in ipairs(ns.Preview.Members(ns.Preview.party)) do
				m.leader = false
				party[#party + 1] = m
			end
		end
		return party
	end
	party[1].role = ROLE_OF[UnitGroupRolesAssigned("player")] or party[1].role
	party[1].leader = not IsInGroup() or UnitIsGroupLeader("player")
	if IsInGroup() and not IsInRaid() then
		for i = 1, GetNumSubgroupMembers() do
			local unit = "party" .. i
			local _, class = UnitClass(unit)
			party[#party + 1] = {
				name = UnitName(unit) or "?",
				class = class or "WARRIOR",
				level = UnitLevel(unit) or 0,
				role = ROLE_OF[UnitGroupRolesAssigned(unit)] or "DAMAGER",
				leader = UnitIsGroupLeader(unit),
			}
		end
	end
	return party
end

-- The size of the group your own listing is for (5 without one).
function ns.MyListingSize()
	if ns.UsingPreview() then
		local mine = ns.state.myListing
		local a = mine and ns.Preview.activities[mine.activities[1]]
		return a and a.size or 5
	end
	local entry = C_LFGList.HasActiveEntryInfo() and C_LFGList.GetActiveEntryInfo()
	local id = type(entry) == "table" and entry.activityIDs and entry.activityIDs[1]
	local a = id and ns.Listings.Act(id)
	return a and a.size or 5
end

-- Your own listing in the preview, shown first in its section as Forever shows yours.
local function MyEntry()
	local mine = ns.state.myListing
	if not mine then
		return nil
	end
	local party = ns.Party()
	local acts = {}
	for i, key in ipairs(mine.activities) do
		acts[i] = ns.Preview.activities[key]
	end
	local voiceMode = mine.voiceMode or (mine.voice and ns.VOICE.Discord or ns.VOICE.None)
	return {
		id = 0,
		mine = true,
		solo = #party == 1,
		acts = acts,
		members = party,
		leader = party[1],
		comment = mine.comment,
		age = 0,
		listedAt = time(),
		newPlayerFriendly = mine.newPlayerFriendly,
		voiceMode = voiceMode,
		voice = voiceMode ~= ns.VOICE.None,
		playstyle = mine.playstyle,
		shard = 6934, -- the preview's own entry plays on a US2 shard
	}
end

-- The preview's listings for a category (and a set of activity keys; empty for all).
local previewItems = {}
function ns.PreviewListings(category, activities)
	for i = #previewItems, 1, -1 do
		previewItems[i] = nil
	end
	local any = activities and next(activities) ~= nil
	local mine = MyEntry()
	for _, l in ipairs(mine and { mine } or {}) do
		previewItems[#previewItems + 1] = l
	end
	for _, l in ipairs(ns.state.listings) do
		for _, a in ipairs(l.acts) do
			if a.category == category and (not any or activities[a.key]) then
				previewItems[#previewItems + 1] = l
				break
			end
		end
	end
	return previewItems
end

-- Runtime-only state: your preview roles, whispers sent, invites, hidden players (until
-- they list again), the preview's own listing, its sample listings and the reserve the
-- simulated refresh draws new ones from.
local function CopyListings(src)
	local out = Copy(src)
	for _, l in ipairs(out) do
		if l.solo then
			l.members = { l.leader }
		else
			l.leader = l.members[1]
		end
	end
	return out
end

local function ResetState(preview)
	ns.state = {
		preview = preview,
		roles = { tank = false, healer = true, dps = true },
		messaged = {},
		invited = {},
		hidden = {},
		asLeader = false,
		myListing = nil,
		listings = CopyListings(ns.Preview.listings),
		reserve = CopyListings(ns.Preview.reserve),
		nextId = 1000, -- above every sample and reserve id
		previewSearching = false,
	}
end

local frame = CreateFrame("Frame")

frame:SetScript("OnEvent", function(_, event, ...)
	local handler = ns[event]
	if handler then
		handler(ns, ...)
	end
end)
frame:RegisterEvent("ADDON_LOADED")

function ns:ADDON_LOADED(name)
	if name ~= addonName then
		return
	end
	frame:UnregisterEvent("ADDON_LOADED")
	if type(TerribleGroupFinderDB) ~= "table" then
		TerribleGroupFinderDB = {}
	end
	ns.db = TerribleGroupFinderDB
	ns.Migrate(ns.db)
	for key, value in pairs(DEFAULTS) do
		if ns.db[key] == nil then
			ns.db[key] = value
		end
	end
	ns.Settings.Init(ns.db)
	ResetState(not ns.Listings.HasAPI())
	ns.ILvl.Init()
	ns.ILvlUI.Init()
	ns.GearSlots.Init()
	ns.Region.Init(ns.db)
	ns.MeterReset.Init(ns.db)
	ns.Messages.Init(ns.db)
	ns.InPlace.Init()
	ns.QuestButton.Init()
	ns.SettingsPanel.Init()
end

local USAGE = "/tgf [preview | reset | version | ilvl | region | meter | gear | settings|config | set <key> on|off]"

SLASH_TERRIBLEGROUPFINDER1 = "/tgf"
SLASH_TERRIBLEGROUPFINDER2 = "/terriblegroupfinder"
SlashCmdList.TERRIBLEGROUPFINDER = function(msg)
	local command = (msg or ""):lower():match("^%s*(.-)%s*$")
	if not ns.state then
		ResetState(not ns.Listings.HasAPI())
	end
	if command == "" then
		ns.InPlace.Open()
	elseif command == "preview" then
		if not ns.Listings.HasAPI() then
			return Print("the game's group finder is missing here, so the preview is always on.")
		end
		ns.state.preview = not ns.state.preview
		Print(ns.state.preview and "showing sample listings (preview)." or "showing your search results.")
		ns.InPlace.Open(true)
	elseif command == "reset" then
		ns.Motion.Cancel()
		ResetState(ns.state.preview)
		ns.Table.RefreshAll()
		Print("preview data reset.")
	elseif command == "ilvl" then
		ns.ILvl.Probe()
	elseif command == "region" then
		ns.Region.Probe()
	elseif command == "gear" then
		ns.GearSlots.Probe()
	elseif command == "meter" then
		if ns.MeterReset.Moving() then
			Print("the damage meter prompt is being moved: Lock or Default first.")
		elseif not ns.MeterReset.Ask() then
			Print("no damage meter to reset: Details! isn't loaded and the game's meter is off.")
		end
	elseif command == "settings" or command == "config" then
		ns.SettingsPanel.Open()
	elseif command == "set" or command:sub(1, 4) == "set " then
		ns.SettingsPanel.Command(command:match("^set%s*(.-)$"))
	elseif command == "version" then
		Print("version " .. ns.version)
	else
		Print(USAGE)
	end
end
