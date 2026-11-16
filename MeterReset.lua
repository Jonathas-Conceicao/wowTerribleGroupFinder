-------------------------------------------------------------------------------
--  MeterReset.lua -- the damage meter reset prompt (ns.MeterReset): when you join a group
--  or enter an instance, a Yes / No dialog asks whether to reset your damage meter. The
--  meter is Details! when it is loaded, else the game's own meter while it is turned on;
--  with neither, nothing is asked. Each trigger has its own setting (meterResetOnGroup,
--  meterResetOnInstance), read where it acts; the instance one is skipped when Details!
--  asks or erases on a new instance itself. The dialog is our own frame (nothing is
--  added to the game's StaticPopup tables) and its question starts with the addon's [TGF]
--  tag; nothing is reset without a click on Yes.
-------------------------------------------------------------------------------
local _, ns = ...

local M = {}
ns.MeterReset = M

local DM_CVAR = "damageMeterEnabled" -- the game's own meter on / off (Blizzard_DamageMeter)

-- Details! when loaded: its global table (also known as _detalhes).
local function Details()
	local d = _G.Details or _G._detalhes
	if type(d) == "table" and type(d.ResetSegmentData) == "function" then
		return d
	end
	return nil
end

-- The game's own meter, only while it is turned on and available.
local function BlizzardOn()
	local DM = C_DamageMeter
	if type(DM) ~= "table" or type(DM.ResetAllCombatSessions) ~= "function" then
		return false
	end
	local on = C_CVar and C_CVar.GetCVarBool and C_CVar.GetCVarBool(DM_CVAR)
	if on ~= true then
		return false
	end
	if DM.IsDamageMeterAvailable then
		local ok, available = pcall(DM.IsDamageMeterAvailable)
		if not ok or available ~= true then
			return false
		end
	end
	return true
end

--- The meter a reset would clear: "details", "blizzard", or nil when there is none.
function M.Target()
	if Details() then
		return "details"
	end
	if BlizzardOn() then
		return "blizzard"
	end
	return nil
end

local NAMES = { details = "Details! damage meter", blizzard = "the damage meter" }

local SHORT = { details = "Details!", blizzard = "the damage meter" }

--- Reset the meter the question named (default: the one a reset would clear now). It is
--- checked again first; when it is gone or the reset fails, a chat line says so. True when
--- one was reset.
function M.Reset(target)
	target = target or M.Target()
	if target == "details" and not Details() then
		ns.Print("Details! isn't loaded now; nothing reset.")
		return false
	elseif target == "blizzard" and not BlizzardOn() then
		ns.Print("the damage meter is off now; nothing reset.")
		return false
	elseif target ~= "details" and target ~= "blizzard" then
		ns.Print("no damage meter to reset.")
		return false
	end
	local ok, err
	if target == "details" then
		local d = Details()
		ok, err = pcall(d.ResetSegmentData, d)
	else
		ok, err = pcall(C_DamageMeter.ResetAllCombatSessions)
	end
	if ok then
		ns.Print((target == "details" and "Details!" or "Damage meter") .. " reset.")
	else
		ns.Print("couldn't reset " .. SHORT[target] .. ": " .. tostring(err))
	end
	return ok
end

-------------------------------------------------------------------------------
--  The dialog: a StaticPopup-sized frame of our own. It never covers the game's popups nor
--  the zone name shown on entering an instance: each time it opens it sits below the lowest
--  of those (only read), and it is not raised above them.
-------------------------------------------------------------------------------
local dialog
local lastPromptAt -- GetTime() of the last prompt shown or answered

local POPUP_GAP = 8
local ZONE_TEXT_BOTTOM = 256 -- below the zone name and subzone text (ZoneTextFrame: top -128, 128 tall)

local function Bottom(frame)
	local b = type(frame) == "table" and frame.GetBottom and frame:GetBottom()
	return type(b) == "number" and b or nil
end

local function Place(f)
	f:ClearAllPoints()
	-- Never over the zone name shown on entering an instance: at least below where it shows,
	-- shown or not (it may come after us).
	local top = UIParent:GetTop()
	local lowest = type(top) == "number" and (top - ZONE_TEXT_BOTTOM) or nil
	for _, zone in ipairs({ ZoneTextFrame, SubZoneTextFrame }) do
		local b = Bottom(zone)
		if b and lowest and b < lowest then
			lowest = b
		end
	end
	local below
	local count = tonumber(STATICPOPUP_NUMDIALOGS) or 4
	for i = 1, count do
		local p = _G["StaticPopup" .. i]
		if type(p) == "table" and p.IsShown and p:IsShown() then
			-- The lowest on screen; the later one when the positions can't be told apart.
			if not below or (Bottom(p) or 0) <= (Bottom(below) or 0) then
				below = p
			end
		end
	end
	if below and (not lowest or (Bottom(below) or 0) <= lowest) then
		f:SetPoint("TOP", below, "BOTTOM", 0, -POPUP_GAP)
	elseif lowest and top then
		f:SetPoint("TOP", UIParent, "TOP", 0, -(top - lowest) - POPUP_GAP)
	else
		f:SetPoint("TOP", UIParent, "TOP", 0, -(ZONE_TEXT_BOTTOM + POPUP_GAP))
	end
end

local function Build()
	local W = ns.W
	local f = W.Create("Frame", UIParent, "BackdropTemplate")
	f:SetSize(320, 80)
	f:SetPoint("TOP", UIParent, "TOP", 0, -(ZONE_TEXT_BOTTOM + POPUP_GAP))
	f:SetFrameStrata("DIALOG")
	f:EnableMouse(true)
	f:Hide()
	-- The game's dialog border and background (StaticPopup's look); a plain backdrop where missing.
	local ok, border = pcall(CreateFrame, "Frame", nil, f, "DialogBorderTemplate")
	if ok and border then
		border:SetAllPoints()
	elseif f.SetBackdrop then
		f:SetBackdrop({
			bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
			edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
			tile = true,
			tileSize = 32,
			edgeSize = 32,
			insets = { left = 11, right = 12, top = 12, bottom = 11 },
		})
	end

	f.text = W.Text(f, "GameFontHighlight", 12, "CENTER")
	f.text:SetPoint("TOP", 0, -18)
	f.text:SetWidth(290)

	local yes = W.Button(f, YES or "Yes", 128, 21, function()
		lastPromptAt = GetTime()
		f:Hide()
		M.Reset(f.target)
	end)
	yes:SetPoint("BOTTOMRIGHT", f, "BOTTOM", -6, 16)
	local no = W.Button(f, NO or "No", 128, 21, function()
		lastPromptAt = GetTime()
		f:Hide()
	end)
	no:SetPoint("BOTTOMLEFT", f, "BOTTOM", 6, 16)
	return f
end

--- Ask whether to reset the meter. Does nothing without a meter, and keeps a dialog that
--- already shows.
function M.Ask()
	local target = M.Target()
	if not target then
		return false
	end
	dialog = dialog or Build()
	if dialog:IsShown() then
		return true
	end
	dialog.target = target -- Yes resets this meter, the one the question names
	dialog.text:SetText("[TGF] Reset " .. NAMES[target] .. "?")
	Place(dialog)
	dialog:Show()
	lastPromptAt = GetTime()
	return true
end

local MERGE = 10 -- seconds: both triggers firing close together ask once

-- A trigger's ask: none within MERGE seconds of the last prompt shown or answered.
local function AskFromTrigger()
	if lastPromptAt and GetTime() - lastPromptAt < MERGE then
		return
	end
	M.Ask()
end

-------------------------------------------------------------------------------
--  Triggers: joining a group (not in a group -> in one) and entering an instance (outside
--  or another instance -> this one). Entering the instance you left less than 15 minutes
--  ago is the same run (a graveyard run-back, a trip out to repair) and doesn't ask. A login
--  or /reload only records where you are.
-------------------------------------------------------------------------------
local SAME_RUN = 15 * 60 -- seconds outside after which the same instance is a new run

local grouped = false
local instance = nil -- the instance ID you're in, nil outside
local lastInstance, leftAt = nil, nil -- the instance you last left, and when
local ready = false -- after the first loading screen: roster updates before it are the login's

-- Details!' own new-instance erase (segments_auto_erase: 1 keep, 2 ask, 3 erase), only read.
-- With ask or erase, Details! handles entering an instance itself and we don't ask too.
local function DetailsHandlesInstances()
	local d = Details()
	if not d then
		return false
	end
	local mode = d.segments_auto_erase
	if type(mode) ~= "number" then
		return false
	end
	return mode == 2 or mode == 3
end

local function InstanceNow()
	local inside = IsInInstance()
	if not inside then
		return nil
	end
	local name, _, _, _, _, _, _, id = GetInstanceInfo()
	return id or name or true
end

local function OnEvent(_, event, isInitialLogin, isReloadingUi)
	if event == "PLAYER_ENTERING_WORLD" then
		local now = InstanceNow()
		local t = GetTime()
		local entered = now ~= nil
			and now ~= instance
			and not (now == lastInstance and leftAt and t - leftAt < SAME_RUN)
		if instance ~= nil and now ~= instance then
			lastInstance, leftAt = instance, t
		end
		instance = now
		if isInitialLogin or isReloadingUi or not ready then
			ready = true
			grouped = IsInGroup() == true
			return
		end
		if
			entered
			and ns.Settings.Get("meterResetOnInstance")
			and not (M.Target() == "details" and DetailsHandlesInstances())
		then
			AskFromTrigger()
		end
	elseif event == "GROUP_ROSTER_UPDATE" and ready then
		local now = IsInGroup() == true
		local joined = now and not grouped
		grouped = now
		if joined and ns.Settings.Get("meterResetOnGroup") then
			AskFromTrigger()
		end
	end
end

function M.Init()
	local f = CreateFrame("Frame")
	f:RegisterEvent("PLAYER_ENTERING_WORLD")
	f:RegisterEvent("GROUP_ROSTER_UPDATE")
	f:SetScript("OnEvent", OnEvent)
end
