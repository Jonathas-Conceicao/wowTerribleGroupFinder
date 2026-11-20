-------------------------------------------------------------------------------
--  UI/SettingsPanel.lua -- the addon's page in the game's Settings (AddOns), built from
--  ns.Settings.List(). Proxy settings keep the registry the one source of truth: a value
--  is saved only once the player sets it, and the registry's listeners fire on a change.
--  Taint: only Blizzard's public registration calls; no field is written on the Settings
--  panel; our two buttons close it through its own Close (SP.CloseThen).
-------------------------------------------------------------------------------
local _, ns = ...

local SP = {}
ns.SettingsPanel = SP

local category, categoryID

--- Register the page once. Does nothing where the game's Settings API is missing.
function SP.Init()
	if category then
		return
	end
	local S = Settings -- the game's table, not ns.Settings
	if
		type(S) ~= "table"
		or not S.RegisterVerticalLayoutCategory
		or not S.RegisterProxySetting
		or not S.CreateCheckbox
		or not S.RegisterAddOnCategory
		or not CreateSettingsListSectionHeaderInitializer
		or not CreateSettingsButtonInitializer
	then
		return
	end
	local cat, layout = S.RegisterVerticalLayoutCategory("TerribleGroupFinder")
	local varType = (S.VarType and S.VarType.Boolean) or "boolean"
	local inits = {}
	local section
	for _, opt in ipairs(ns.Settings.List()) do
		if opt.section and opt.section ~= section then
			section = opt.section
			layout:AddInitializer(CreateSettingsListSectionHeaderInitializer(section))
		end
		local key = opt.key
		local setting = S.RegisterProxySetting(cat, "TGF_" .. key, varType, opt.label, opt.default, function()
			return ns.Settings.Get(key)
		end, function(value)
			ns.Settings.Set(key, value)
		end)
		inits[key] = S.CreateCheckbox(cat, setting, opt.tooltip)
		-- A change from elsewhere (/tgf set) shows on an open page, its children re-evaluated.
		-- Skipped while the setting is locked: the change is the page's own.
		ns.Settings.OnChange(key, function()
			if not (SettingsPanel and SettingsPanel:IsShown() and setting.NotifyUpdate) then
				return
			end
			if setting.IsLocked and setting:IsLocked() then
				return
			end
			setting:NotifyUpdate()
		end)
	end
	for _, opt in ipairs(ns.Settings.List()) do
		local parent = opt.parent
		if parent and inits[parent] and inits[opt.key] then
			inits[opt.key]:SetParentInitializer(inits[parent], function()
				return ns.Settings.Get(parent)
			end)
		end
	end
	-- Last of the options' sections is Damage meter: the prompt's position goes under it.
	layout:AddInitializer(
		CreateSettingsButtonInitializer(
			"Prompt position",
			"Move",
			function()
				SP.CloseThen(ns.MeterReset.Move)
			end,
			"Closes Settings and shows the damage meter prompt, to drag where you want it. Lock saves the spot, Default puts it back below the game's own popups; both open this page again.",
			true
		)
	)
	layout:AddInitializer(CreateSettingsListSectionHeaderInitializer("Messages"))
	layout:AddInitializer(CreateSettingsButtonInitializer("Whisper presets", "Edit whisper messages", function()
		SP.CloseThen(ns.InPlace.OpenMessages)
	end, "Closes Settings and opens the group finder's Messages tab, where the whisper presets are edited.", true))
	S.RegisterAddOnCategory(cat)
	category = cat
	categoryID = cat:GetID()
end

-- Run once the game's Settings panel hides (the latest asked wins); a one-time HookScript
-- is all that's added to it (SP.CloseThen closes it through its own Close).
local afterClose, closeHooked = nil, false

--- Calls fn on the next frame after the Settings panel hides.
function SP.AfterClose(fn)
	afterClose = fn
	if closeHooked or not (SettingsPanel and SettingsPanel.HookScript) then
		return
	end
	closeHooked = true
	SettingsPanel:HookScript("OnHide", function()
		local run = afterClose
		afterClose = nil
		if run then
			C_Timer.After(0, run) -- out of the panel's own hide
		end
	end)
end

--- Closes the Settings panel the way its own Close does (unapplied game settings still ask
--- first), then calls fn once it has hidden. In combat, or where the panel isn't shown or
--- has no Close, fn is called now (it waits for the panel itself, or refuses, as it would).
function SP.CloseThen(fn)
	local panel = SettingsPanel
	if
		InCombatLockdown()
		or not (panel and panel.IsShown and panel:IsShown() and panel.HookScript and type(panel.Close) == "function")
	then
		return fn()
	end
	SP.AfterClose(fn)
	local ok = pcall(panel.Close, panel, true) -- true: don't fall back to the game menu
	if panel:IsShown() then
		-- Unapplied game settings: the game asks to discard them and the panel stays; the
		-- action is dropped, to click again. Where Close failed, fn runs now, as in combat.
		afterClose = nil
		if not ok then
			fn()
		end
	end
end

--- The registered category's ID; nil while unregistered.
function SP.ID()
	return categoryID
end

--- Print every option and its state (where the game's Settings API is missing, or after a bad `/tgf set`).
function SP.PrintAll()
	ns.Print("settings (change one with /tgf set <key> on|off):")
	for _, opt in ipairs(ns.Settings.List()) do
		local where = opt.section and (tostring(opt.section) .. ": ") or ""
		ns.Print(
			opt.key .. ": " .. (ns.Settings.Get(opt.key) and "on" or "off") .. " - " .. where .. tostring(opt.label)
		)
	end
end

--- `/tgf settings`: open the page out of combat; without the Settings API list the options.
function SP.Open()
	if not categoryID then
		SP.PrintAll()
		return
	end
	if InCombatLockdown() then
		ns.Print("can't open the settings in combat.")
		return
	end
	Settings.OpenToCategory(categoryID)
end

local VALUES = { on = true, ["true"] = true, ["1"] = true, off = false, ["false"] = false, ["0"] = false }

--- `/tgf set <key> on|off` (args lowercased): change one registered option and save it.
---@param args string|nil
function SP.Command(args)
	local name, word = (args or ""):match("^(%S+)%s+(%S+)$")
	local value = word and VALUES[word]
	local found
	if name and value ~= nil then
		for _, opt in ipairs(ns.Settings.List()) do
			if opt.key:lower() == name then
				found = opt
				break
			end
		end
	end
	if not found then
		ns.Print("usage: /tgf set <key> on|off")
		SP.PrintAll()
		return
	end
	if not ns.Settings.Set(found.key, value) then
		return ns.Print("settings aren't ready yet.")
	end
	ns.Print(tostring(found.label) .. ": " .. (value and "on" or "off"))
end
