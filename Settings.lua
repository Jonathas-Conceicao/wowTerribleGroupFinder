-------------------------------------------------------------------------------
--  Settings.lua -- the options registry (ns.Settings). Each option is a flat boolean key
--  in TerribleGroupFinderDB, saved only once the player sets it; until then Get gives the
--  option's default (so a default can still change in a later version). Features read Get
--  where they act (never a cached copy), so a change is live without a reload; Set tells
--  the listeners that need a redraw. The settings page (UI/SettingsPanel.lua) is built
--  from this list.
-------------------------------------------------------------------------------
local _, ns = ...

local S = {}
ns.Settings = S

local list = {} -- options in registration order
local byKey = {} -- key -> option
local listeners = {} -- key -> { fn, ... }
local db -- the saved table, held by reference (never copied or replaced)

-- Keys other modules keep in the same saved table: never an option's key.
local RESERVED =
	{ schema = true, invite = true, request = true, shards = true, meterPos = true, gs = true, autoRefresh = true }

-- A saved value that isn't a boolean is dropped, so Get falls back to the default.
local function Clean(opt)
	if db[opt.key] ~= nil and type(db[opt.key]) ~= "boolean" then
		db[opt.key] = nil
	end
end

--- Add an option: { key, default (boolean), label, section?, tooltip?, parent? (key of
--- the option it sits under), onChange(value, key)? }. A
--- key registered twice keeps its first option; a key that isn't a string, is reserved,
--- or comes without a boolean default is an error.
function S.Register(opt)
	assert(type(opt) == "table" and type(opt.key) == "string", "Settings.Register: option needs a string key")
	assert(not RESERVED[opt.key], "Settings.Register: reserved key " .. opt.key)
	assert(type(opt.default) == "boolean", "Settings.Register: option " .. opt.key .. " needs a boolean default")
	local existing = byKey[opt.key]
	if existing then
		return existing
	end
	list[#list + 1] = opt
	byKey[opt.key] = opt
	if db then
		Clean(opt)
	end
	return opt
end

--- The options in order. Callers must not modify it.
function S.List()
	return list
end

--- Hold the saved table and drop any saved option value that isn't a boolean.
function S.Init(saved)
	db = saved
	for _, opt in ipairs(list) do
		Clean(opt)
	end
end

--- The option's value, read now; its default before the saved table is ready; nil for a
--- key nobody registered.
function S.Get(key)
	local opt = byKey[key]
	if not opt then
		return nil
	end
	if db and type(db[key]) == "boolean" then
		return db[key]
	end
	return opt.default
end

--- Add a function called as fn(value, key) after the option changes; false for an
--- unknown key.
function S.OnChange(key, fn)
	if not byKey[key] or type(fn) ~= "function" then
		return false
	end
	local l = listeners[key]
	if not l then
		l = {}
		listeners[key] = l
	end
	l[#l + 1] = fn
	return true
end

local function Call(fn, value, key)
	local ok, err = pcall(fn, value, key)
	if not ok then
		local handler = geterrorhandler and geterrorhandler()
		if handler then
			handler(err)
		end
	end
end

--- Save a new value and tell the listeners; false for an unknown key or before the saved
--- table is ready, true otherwise (also when nothing changed).
function S.Set(key, value)
	local opt = byKey[key]
	if not opt or not db then
		return false
	end
	value = value and true or false
	if S.Get(key) == value and db[key] == value then
		return true
	end
	db[key] = value
	if opt.onChange then
		Call(opt.onChange, value, key)
	end
	for _, fn in ipairs(listeners[key] or {}) do
		Call(fn, value, key)
	end
	return true
end

local OPTIONS = {
	{
		key = "eliteQuestButton",
		section = "Group finder",
		label = "Elite quest button",
		default = true,
		tooltip = "Show an eye button beside elite quests in the objective tracker; it opens the group finder's Listing tab with what you need to list a group for that quest.",
	},
	{
		key = "dynamicRefresh",
		section = "Group finder",
		label = "Dynamic refresh",
		default = true,
		tooltip = "Refreshing the same search keeps the list and updates it in place. Off: the stock spinner and a new list.",
	},
	{
		key = "swipeAnimations",
		section = "Group finder",
		label = "Swipe animations",
		parent = "dynamicRefresh",
		default = true,
		tooltip = "Rows that leave or arrive on a refresh swipe out and in, and the rows below slide into place.",
	},
	{
		key = "regionFlags",
		section = "Group finder",
		label = "Region flags",
		default = true,
		tooltip = "Show each listing's region after its name: a flag where there is one, else the region's letters.",
	},
	{
		key = "ilvlPlayerTooltip",
		section = "Player inspection",
		label = "Player tooltips",
		default = false,
		tooltip = 'Show "Item Level N" on friendly players\' tooltips.',
	},
	{
		key = "specPoints",
		section = "Player inspection",
		label = "Talent points",
		default = false,
		tooltip = "Show talent points per tree (e.g. 31/20/0) on friendly players' tooltips.",
	},
	{
		key = "ilvlItemTooltip",
		section = "Player inspection",
		label = "Item tooltips",
		default = false,
		tooltip = 'Show "Item Level N" under the name of weapons and armor.',
	},
	{
		key = "ilvlCharacterSheet",
		section = "Player inspection",
		label = "Character sheet",
		default = false,
		tooltip = "Show your item level in a row under Movement Speed on the character sheet.",
	},
	{
		key = "ilvlInspect",
		section = "Player inspection",
		label = "Inspect window",
		default = false,
		tooltip = "Show the inspected player's item level in the Inspect window.",
	},
	{
		key = "slotItemLevel",
		section = "Player inspection",
		label = "Slot item level",
		default = false,
		tooltip = "Show each item's level beside its slot on the character sheet and the Inspect window.",
	},
	{
		key = "slotEnchants",
		section = "Player inspection",
		label = "Slot enchants",
		default = false,
		tooltip = 'Show each item\'s enchant beside its slot on the character sheet and the Inspect window, or "No enchant" where the slot can be enchanted.',
	},
	{
		key = "meterResetOnGroup",
		section = "Damage meter",
		label = "Ask to reset on joining a group",
		default = false, -- off for new installs; Migrate's schema 3 keeps it on for players from before v0.2.2
		tooltip = "When you join a group, ask whether to reset your damage meter: Details! when it's loaded, else the game's own meter while it's turned on.",
	},
	{
		key = "meterResetOnInstance",
		section = "Damage meter",
		label = "Ask to reset on entering an instance",
		default = false, -- off for new installs; Migrate's schema 4 keeps it on for earlier players
		tooltip = "When you enter a dungeon, raid, battleground or any other instance, ask whether to reset your damage meter: Details! when it's loaded, else the game's own meter while it's turned on.",
	},
}
for _, o in ipairs(OPTIONS) do
	S.Register(o)
end
