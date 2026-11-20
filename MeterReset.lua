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
local addonName, ns = ...

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
--  The dialog: a StaticPopup-sized frame of our own with the addon's icon. Where the player
--  placed it (Settings > Move, saved in DB.meterPos) it opens there; else it never covers the
--  game's popups nor the zone name shown on entering an instance: each time it opens it sits
--  below the lowest of those (only read), and it is not raised above them.
-------------------------------------------------------------------------------
local dialog
local lastPromptAt -- GetTime() of the last prompt shown or answered
local db

local POPUP_GAP = 8
local ZONE_TEXT_BOTTOM = 256 -- below the zone name and subzone text (ZoneTextFrame: top -128, 128 tall)
local ICON = "Interface\\AddOns\\" .. addonName .. "\\Media\\Textures\\tgf_icon_64x64"

local function Bottom(frame)
	local b = type(frame) == "table" and frame.GetBottom and frame:GetBottom()
	return type(b) == "number" and b or nil
end

local function Finite(v)
	return type(v) == "number" and v == v and v > -1e6 and v < 1e6
end

-- The saved spot (the dialog's top left, in UIParent's coordinates), or nil.
local function SavedPos()
	local p = db and db.meterPos
	if type(p) == "table" and Finite(p.left) and Finite(p.top) then
		return p
	end
	return nil
end

local function Place(f)
	f:ClearAllPoints()
	local saved = SavedPos()
	if saved then
		f:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", saved.left, saved.top)
		return
	end
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

-- A button in the game menu's style (the red three-slice SharedButtonTemplate); the
-- plain panel button where that template is missing.
local function MenuButton(parent, text, onClick)
	local ok, b = pcall(CreateFrame, "Button", nil, parent, "SharedButtonTemplate")
	if ok and b then
		b:SetSize(120, 26)
		b:SetText(text)
		b:SetScript("OnClick", onClick)
		return b
	end
	return ns.W.Button(parent, text, 120, 24, onClick)
end

local function Build()
	local W = ns.W
	local f = W.Create("Frame", UIParent, "BackdropTemplate")
	f:SetSize(380, 112)
	f:SetPoint("TOP", UIParent, "TOP", 0, -(ZONE_TEXT_BOTTOM + POPUP_GAP))
	f:SetFrameStrata("DIALOG")
	f:EnableMouse(true)
	f:SetClampedToScreen(true)
	f:SetMovable(true)
	f:RegisterForDrag("LeftButton")
	f:SetScript("OnDragStart", function(self)
		if self.moving then
			self:StartMoving()
		end
	end)
	f:SetScript("OnDragStop", function(self)
		self:StopMovingOrSizing()
	end)
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

	-- The addon's icon (the purple eye) on the left, the full height; the question and the
	-- buttons both beside it, in the body.
	local icon = f:CreateTexture(nil, "ARTWORK")
	icon:SetSize(76, 76)
	icon:SetPoint("LEFT", 18, 0)
	icon:SetTexture(ICON)
	local body = CreateFrame("Frame", nil, f)
	body:SetPoint("TOPLEFT", icon, "TOPRIGHT", 10, 4)
	body:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -20, 16)

	f.text = W.Text(f, "GameFontHighlight", 12, "CENTER")
	f.text:SetPoint("TOPLEFT", body, "TOPLEFT", 0, 0)
	f.text:SetPoint("BOTTOMRIGHT", body, "BOTTOMRIGHT", 0, 30)

	local yes = MenuButton(f, YES or "Yes", function()
		lastPromptAt = GetTime()
		f:Hide()
		M.Reset(f.target)
	end)
	yes:SetPoint("BOTTOMRIGHT", body, "BOTTOM", -4, 0)
	local no = MenuButton(f, NO or "No", function()
		lastPromptAt = GetTime()
		f:Hide()
	end)
	no:SetPoint("BOTTOMLEFT", body, "BOTTOM", 4, 0)

	-- Move mode (Settings > Move): drag the dialog; Lock saves the spot, Default goes back
	-- to the automatic spot; both reopen the Settings page.
	local default = MenuButton(f, DEFAULT or "Default", function()
		if db then
			db.meterPos = nil
		end
		M.EndMove()
	end)
	default:SetPoint("BOTTOMRIGHT", body, "BOTTOM", -4, 0)
	local lock = MenuButton(f, LOCK or "Lock", function()
		local left, top = f:GetLeft(), f:GetTop()
		if db and Finite(left) and Finite(top) then
			db.meterPos = { left = left, top = top }
		end
		M.EndMove()
	end)
	lock:SetPoint("BOTTOMLEFT", body, "BOTTOM", 4, 0)
	f.askButtons = { yes, no }
	f.moveButtons = { default, lock }
	return f
end

local function ShowButtons(f, moving)
	for _, b in ipairs(f.askButtons) do
		b:SetShown(not moving)
	end
	for _, b in ipairs(f.moveButtons) do
		b:SetShown(moving)
	end
end

-- The question for a meter, with Yes / No: Yes resets this meter, the one it names.
local function SetQuestion(f, target)
	f.target = target
	f.text:SetText("[TGF] Reset " .. NAMES[target] .. "?")
	ShowButtons(f, false)
end

--- Ask whether to reset the meter. Does nothing without a meter, and keeps a dialog that
--- already shows (a question, or the dialog being moved).
function M.Ask()
	local target = M.Target()
	if not target then
		return false
	end
	dialog = dialog or Build()
	if dialog:IsShown() then
		return not dialog.moving
	end
	SetQuestion(dialog, target)
	Place(dialog)
	dialog:Show()
	lastPromptAt = GetTime()
	return true
end

local function StartMove()
	dialog = dialog or Build()
	-- A question showing now is asked again once the move ends.
	if dialog:IsShown() and not dialog.moving then
		dialog.pending = dialog.target
	end
	dialog.moving = true
	dialog.target = nil
	dialog.text:SetText("[TGF] Drag to move the damage meter prompt, then Lock.")
	ShowButtons(dialog, true)
	Place(dialog)
	dialog:Show()
end

--- Settings > Move: shows the dialog to drag. The Settings button closes the panel first
--- (SP.CloseThen); where it is still shown (in combat nothing closes it) the dialog shows
--- once it hides.
function M.Move()
	if SettingsPanel and SettingsPanel.IsShown and SettingsPanel:IsShown() and ns.SettingsPanel.AfterClose then
		ns.SettingsPanel.AfterClose(StartMove)
		ns.Print("the damage meter prompt shows to be moved when you close the Settings.")
		return
	end
	StartMove()
end

--- Ends move mode (Lock or Default) and reopens the Settings page.
function M.EndMove()
	if not dialog then
		return
	end
	if dialog.StopMovingOrSizing then
		dialog:StopMovingOrSizing()
	end
	dialog.moving = false
	dialog:Hide()
	Place(dialog)
	local pending = dialog.pending
	dialog.pending = nil
	if pending and M.Target() == pending then
		SetQuestion(dialog, pending)
		dialog:Show()
	end
	ns.SettingsPanel.Open()
end

--- Whether the dialog is being moved (Settings > Move).
function M.Moving()
	return dialog ~= nil and dialog.moving == true and dialog:IsShown()
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

function M.Init(saved)
	db = saved
	if db and db.meterPos ~= nil and not SavedPos() then
		db.meterPos = nil -- not a spot we saved
	end
	local f = CreateFrame("Frame")
	f:RegisterEvent("PLAYER_ENTERING_WORLD")
	f:RegisterEvent("GROUP_ROSTER_UPDATE")
	f:SetScript("OnEvent", OnEvent)
end
