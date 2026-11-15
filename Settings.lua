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
local RESERVED = { schema = true, invite = true, request = true, shards = true, gs = true, autoRefresh = true }

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
		key = "ilvlPlayerTooltip",
		section = "Item level",
		label = "Player tooltips",
		tooltip = 'Show "Item Level N" on friendly players\' tooltips.',
	},
	{
		key = "ilvlItemTooltip",
		section = "Item level",
		label = "Item tooltips",
		tooltip = 'Show "Item Level N" under the name of weapons and armor.',
	},
	{
		key = "ilvlCharacterSheet",
		section = "Item level",
		label = "Character sheet",
		tooltip = "Show your item level in a row under Movement Speed on the character sheet.",
	},
	{
		key = "ilvlInspect",
		section = "Item level",
		label = "Inspect window",
		tooltip = "Show the inspected player's item level in the Inspect window.",
	},
	{
		key = "dynamicRefresh",
		section = "Group finder",
		label = "Dynamic refresh",
		tooltip = "Refreshing the same search keeps the list and updates it in place. Off: the stock spinner and a new list.",
	},
	{
		key = "swipeAnimations",
		section = "Group finder",
		label = "Swipe animations",
		parent = "dynamicRefresh",
		tooltip = "Rows that leave or arrive on a refresh swipe out and in, and the rows below slide into place.",
	},
	{
		key = "regionFlags",
		section = "Group finder",
		label = "Region flags",
		tooltip = "Show a region flag (US or Oceania) after each listing's name.",
	},
}
for _, o in ipairs(OPTIONS) do
	o.default = true
	S.Register(o)
end
