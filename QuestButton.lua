-------------------------------------------------------------------------------
--  QuestButton.lua -- the Elite quest eye (ns.QuestButton): an eye button of ours on tracked
--  elite quests in the objective tracker (Quest and Campaign modules). A click, out of
--  combat, opens Forever's group finder on its Listing tab.
--
--  Taint: post-hooks only (hooksecurefunc on the module instances' EndLayout). The eye is
--  our own Button parented to the block, kept in a weak table, never a field on the block.
--  The only change to Blizzard's tracker is the HeaderText's RIGHT anchor, moved only when
--  the title keeps its line count and set again by the block's own layout. Nothing of the
--  finder is selected or written. Gated by eliteQuestButton, read where it acts.
-------------------------------------------------------------------------------
local _, ns = ...

local Q = {}
ns.QuestButton = Q

local MODULES = { "QuestObjectiveTracker", "CampaignQuestObjectiveTracker" }
local EYE_SIZE = 30
local ICON_SIZE = 13
local OFFSET_X = 5
local OFFSET_Y = 2
local SPACING = 2
local EYE_ATLAS = "socialqueuing-icon-eye"
local EYE_FALLBACK = "Interface\\Icons\\INV_Misc_Spyglass_03" -- a stock game icon
local TIP_TITLE = "Find a group for this quest"
local TIP_NOTE = "Opens the group finder's Listing tab with this quest's details."

local eyes = setmetatable({}, { __mode = "k" }) -- block -> our button
local moved = setmetatable({}, { __mode = "k" }) -- blocks whose header anchor we moved
local hooked = {} -- module -> true
local hookedList = {}
local eligible = {} -- questID -> boolean
local pending = false -- a pass that waited for the end of combat

Q.failed = nil -- why the installer didn't install
Q.lastError = nil -- the last error of a pass

local function Secret(v)
	return issecretvalue ~= nil and issecretvalue(v)
end

local function PlainNumber(v)
	return type(v) == "number" and not Secret(v)
end

-- Elite by the game's own flag; the quest tag's ID where that API is missing. Never the
-- title's "(Elite)" text, never suggestedGroup. No eye where the game gives its own.
local function Eligible(id)
	local cached = eligible[id]
	if cached ~= nil then
		return cached
	end
	local elite
	if type(C_QuestLog) == "table" and type(C_QuestLog.IsEliteQuest) == "function" then
		local ok, value = pcall(C_QuestLog.IsEliteQuest, id)
		if ok and type(value) == "boolean" and not Secret(value) then
			elite = value
		end
	end
	if elite == nil then
		elite = false
		if type(C_QuestLog) == "table" and type(C_QuestLog.GetQuestTagInfo) == "function" then
			local eliteTag = 1
			if Constants and Constants.QuestConsts and Constants.QuestConsts.QUEST_INFO_ELITE_ID then
				eliteTag = Constants.QuestConsts.QUEST_INFO_ELITE_ID
			elseif Enum and Enum.QuestTag and Enum.QuestTag.Group then
				eliteTag = Enum.QuestTag.Group
			end
			local ok, info = pcall(C_QuestLog.GetQuestTagInfo, id)
			if ok and type(info) == "table" and PlainNumber(info.tagID) and info.tagID == eliteTag then
				elite = true
			end
		end
	end
	local gameEye = false
	if type(C_LFGList) == "table" and type(C_LFGList.CanCreateQuestGroup) == "function" then
		local ok, value = pcall(C_LFGList.CanCreateQuestGroup, id)
		gameEye = ok and not Secret(value) and value == true
	end
	local result = elite and not gameEye
	eligible[id] = result
	return result
end

local function CanUsePremade()
	if type(C_LFGInfo) ~= "table" or type(C_LFGInfo.CanPlayerUsePremadeGroup) ~= "function" then
		return true
	end
	local ok, value = pcall(C_LFGInfo.CanPlayerUsePremadeGroup)
	return ok and not Secret(value) and value == true
end

-- Read only: is the block's right-edge frame Blizzard's own find-group eye?
local function HasGameEye(block)
	local r = block.rightEdgeFrame
	if type(r) ~= "table" or not r.Icon then
		return false
	end
	if type(r.GetAttribute) == "function" then
		local ok, value = pcall(r.GetAttribute, r, "questID")
		if ok and value ~= nil then
			return true
		end
	end
	local mixin = QuestObjectiveFindGroupButtonMixin
	return mixin ~= nil and r.OnClick == mixin.OnClick
end

local function NewEye(block)
	local eye = CreateFrame("Button", nil, block)
	eye:SetSize(EYE_SIZE, EYE_SIZE)
	eye:SetNormalTexture("Interface\\Buttons\\UI-SquareButton-Up")
	eye:SetPushedTexture("Interface\\Buttons\\UI-SquareButton-Down")
	eye:SetDisabledTexture("Interface\\Buttons\\UI-SquareButton-Disabled")
	eye:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight", "ADD")
	local hl = eye:GetHighlightTexture()
	if hl then
		hl:SetAlpha(0.5)
	end
	if eye.SetMotionScriptsWhileDisabled then
		eye:SetMotionScriptsWhileDisabled(true)
	end
	local icon = eye:CreateTexture(nil, "ARTWORK", nil, 5)
	icon:SetPoint("CENTER", -1, 0)
	if ns.W.HasAtlas(EYE_ATLAS) then
		icon:SetAtlas(EYE_ATLAS)
		icon:SetSize(ICON_SIZE, ICON_SIZE)
	else
		icon:SetTexture(EYE_FALLBACK)
		icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
		icon:SetSize(16, 16)
	end
	eye.Icon = icon
	eye:RegisterForClicks("LeftButtonUp")
	eye:SetScript("OnMouseDown", function(self)
		if self:IsEnabled() then
			self.Icon:ClearAllPoints()
			self.Icon:SetPoint("CENTER", -2, -1)
		end
	end)
	eye:SetScript("OnMouseUp", function(self)
		self.Icon:ClearAllPoints()
		self.Icon:SetPoint("CENTER", -1, 0)
	end)
	eye:SetScript("OnEnter", function(self)
		ns.W.ShowTip(self, TIP_TITLE, nil, { gold = true, note = TIP_NOTE })
	end)
	eye:SetScript("OnLeave", function()
		GameTooltip:Hide()
	end)
	eye:SetScript("OnClick", function(self)
		Q.Click(self)
	end)
	eye:Hide()
	return eye
end

local function Place(eye, block)
	eye:ClearAllPoints()
	local r = block.rightEdgeFrame
	if r == nil then
		eye:SetPoint("TOPRIGHT", block, "TOPRIGHT", OFFSET_X, OFFSET_Y)
	else
		eye:SetPoint("RIGHT", r, "LEFT", -SPACING, 0)
	end
end

local function HeaderBase(block)
	local base = block.rightEdgeOffset
	if PlainNumber(base) then
		return base
	end
	return 0
end

-- Header room: the title's right edge moves in for the eye only when it keeps its line count.
local function MakeRoom(block, eye)
	local text = block.HeaderText
	if type(text) ~= "table" or not text.SetPoint or not text.GetNumLines then
		return
	end
	local base = HeaderBase(block)
	local target = base + (block.rightEdgeFrame and 0 or OFFSET_X) - eye:GetWidth() - SPACING
	local before = text:GetNumLines()
	text:SetPoint("RIGHT", target, 0)
	if text:GetNumLines() ~= before then
		text:SetPoint("RIGHT", base, 0)
		moved[block] = nil
	else
		moved[block] = true
	end
end

local function Restore(block)
	if not moved[block] then
		return
	end
	moved[block] = nil
	local text = block.HeaderText
	if type(text) == "table" and text.SetPoint then
		text:SetPoint("RIGHT", HeaderBase(block), 0)
	end
end

local function HideEye(block)
	local eye = eyes[block]
	if eye then
		eye:Hide()
	end
end

local function UpdateBlock(block)
	local id = block.id
	if not PlainNumber(id) then
		HideEye(block)
		Restore(block)
		return
	end
	local on = ns.Settings.Get("eliteQuestButton") and CanUsePremade() and Eligible(id) and not HasGameEye(block)
	if not on then
		HideEye(block)
		Restore(block)
		return
	end
	if InCombatLockdown() and block.rightEdgeFrame then
		-- no anchoring to the quest item button in combat
		HideEye(block)
		pending = true
		return
	end
	local eye = eyes[block]
	if not eye then
		eye = NewEye(block)
		eyes[block] = eye
	end
	Place(eye, block)
	eye:Show()
	MakeRoom(block, eye)
end

-- The hook body: runs after every layout of a module. Never raises into the tracker.
local function Pass(module)
	local ok, err = pcall(function()
		local used = module and module.usedBlocks
		if type(used) ~= "table" then
			return
		end
		for _, blocks in pairs(used) do
			if type(blocks) == "table" then
				for _, block in pairs(blocks) do
					if type(block) == "table" then
						UpdateBlock(block)
					end
				end
			end
		end
	end)
	if not ok then
		Q.lastError = tostring(err)
	end
end

local function RefreshAll()
	pending = false
	for _, module in ipairs(hookedList) do
		Pass(module)
	end
end

local function HookModules()
	for _, name in ipairs(MODULES) do
		local module = _G[name]
		if type(module) == "table" and type(module.EndLayout) == "function" and not hooked[module] then
			hooksecurefunc(module, "EndLayout", Pass)
			hooked[module] = true
			hookedList[#hookedList + 1] = module
			Pass(module)
		end
	end
	return #hookedList
end

local function Install()
	if HookModules() == 0 then
		if not (EventUtil and EventUtil.ContinueOnAddOnLoaded) then
			return false
		end
		EventUtil.ContinueOnAddOnLoaded("Blizzard_ObjectiveTracker", function()
			if HookModules() == 0 then
				Q.failed = "no tracker module"
			end
		end)
	end
	local events = CreateFrame("Frame")
	events:RegisterEvent("QUEST_LOG_UPDATE")
	events:RegisterEvent("PLAYER_REGEN_ENABLED")
	events:SetScript("OnEvent", function(_, event)
		if event == "QUEST_LOG_UPDATE" then
			wipe(eligible)
		elseif pending then
			RefreshAll()
		end
	end)
	ns.Settings.OnChange("eliteQuestButton", RefreshAll)
	return true
end

function Q.Init()
	local ok, result = pcall(Install)
	if not ok then
		Q.failed = tostring(result)
	elseif result == false then
		Q.failed = "missing"
	else
		Q.failed = nil
	end
end

--- The eye's click: the quest is read now (blocks are recycled). Out of combat only.
function Q.Click(eye)
	local block = eye:GetParent()
	local id = block and block.id
	if not PlainNumber(id) then
		return
	end
	if InCombatLockdown() then
		ns.Print("can't open the group finder in combat.")
		return
	end
	ns.InPlace.ShowFinder(ns.InPlace.LISTING_TAB)
end
