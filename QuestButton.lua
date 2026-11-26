-------------------------------------------------------------------------------
--  QuestButton.lua -- the Elite quest eye (ns.QuestButton): an eye button of ours on tracked
--  elite quests in the objective tracker (Quest and Campaign modules). A click, out of
--  combat, opens Forever's group finder on its Listing tab with Quests & Zones picked and the
--  quest's zone ticked, the way the player's own clicks would.
--
--  Taint: post-hooks only (hooksecurefunc on the module instances' EndLayout). The eye is
--  our own plain Button parented to the block, kept in a weak table, never a field on the
--  block. The changes to Blizzard's tracker are anchors only, set again by the block's own
--  layout: the HeaderText's RIGHT anchor (moved only when the title still fits one line) and,
--  out of combat, the quest item button's (moved left of the eye, retail's order).
--
--  The click is secure: nothing in the tracker is protected. While the mouse is over an eye
--  (out of combat), one SecureActionButton of ours, a child of UIParent placed by screen
--  coordinates, covers it; its macro /clicks the game's own buttons (the group finder micro
--  button, the Listing tab) and two click-delegates of ours, which click the Quests & Zones
--  category button and the zone's checkbox. Those run in Blizzard's code as the player's
--  clicks, so Post stays the game's own. The zone is ticked only when its row is on screen
--  (the list is never scrolled). The description box takes no text from addons: the cursor is
--  put in it for the player to type, and the hint box (our own frame beside it, outside the
--  finder) shows the quest and its zone.
-------------------------------------------------------------------------------
local addonName, ns = ...

local Q = {}
ns.QuestButton = Q

local MODULES = { "QuestObjectiveTracker", "CampaignQuestObjectiveTracker" }
local EYE_SIZE = 30
local ICON_SIZE = 18
local OFFSET_X = 5
local OFFSET_Y = 2
local SPACING = 2
local EYE_ICON = "Interface\\AddOns\\" .. addonName .. "\\Media\\Textures\\tgf_icon_64x64"
local TIP_TITLE = "Find a group for this quest"
local TIP_NOTE = "Opens the group finder's Listing tab on Quests & Zones, with this quest's zone ticked."
local QUEST_CATEGORY = 116 -- Forever's file-local LFGLISTING_QUEST_CATEGORY_ID, carried as our own
local HINT_W = 240
local HINT_PAD = 15 -- the dialog border's inset plus 3 px of air around the text
local GAP = 3
local SIDE_TAB_W = 44 -- the finder's side tabs, where their width can't be read
local OUTLINE_ATLAS = "groupfinder-button-cover-hover"
-- The macro's /click targets: the game's own, then our two click-delegates.
local OPENER = "LFDMicroButton"
local LISTING_TAB = "LFGParentFrameTab1"
local PICK_CATEGORY = "TGFQuestCategory"
local PICK_ACTIVITY = "TGFQuestActivity"

local eyes = setmetatable({}, { __mode = "k" }) -- block -> our button
local moved = setmetatable({}, { __mode = "k" }) -- blocks whose header anchor we moved
local movedItem = setmetatable({}, { __mode = "k" }) -- block -> the quest item button we moved
local hooked = {} -- module -> true
local hookedList = {}
local eligible = {} -- questID -> boolean
local pending = false -- a pass that waited for the end of combat

Q.failed = nil -- why the installer didn't install
Q.lastError = nil -- the last error of a pass

local reported = {} -- step -> true: the steps that already printed their chat line

-- A failed step: kept for /tgf quest, one chat line per distinct step per session.
local function Fail(step, err)
	Q.lastError = step .. ": " .. tostring(err)
	if not reported[step] then
		reported[step] = true
		ns.Print("Quest eye: " .. step .. " failed")
	end
end

-- Runs fn(...) under pcall; a failure goes to Fail and gives nil, else the first four results.
local function Try(step, fn, ...)
	local ok, a, b, c, d = pcall(fn, ...)
	if not ok then
		Fail(step, a)
		return nil
	end
	return a, b, c, d
end

-- A script handler that never raises and returns nothing.
local function Guarded(step, fn)
	return function(...)
		Try(step, fn, ...)
	end
end

local function Secret(v)
	return issecretvalue ~= nil and issecretvalue(v)
end

local function PlainNumber(v)
	return type(v) == "number" and not Secret(v)
end

local function PlainString(v)
	if type(v) == "string" and not Secret(v) and v ~= "" then
		return v
	end
	return nil
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

local function ShowEyeTip(owner)
	ns.W.ShowTip(owner, TIP_TITLE, nil, { gold = true, note = TIP_NOTE })
end

local function EyeDown(eye)
	if not (eye and eye.Icon) then
		return
	end
	if eye:IsEnabled() then
		eye:SetButtonState("PUSHED")
		eye.Icon:ClearAllPoints()
		eye.Icon:SetPoint("CENTER", -2, -1)
	end
end

local function EyeUp(eye)
	if not (eye and eye.Icon) then
		return
	end
	eye:SetButtonState("NORMAL")
	eye.Icon:ClearAllPoints()
	eye.Icon:SetPoint("CENTER", -1, 0)
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
	icon:SetTexture(EYE_ICON) -- the addon's own purple eye
	icon:SetSize(ICON_SIZE, ICON_SIZE)
	icon:SetPoint("CENTER", -1, 0)
	eye.Icon = icon
	eye:RegisterForClicks("LeftButtonUp")
	eye:SetScript("OnMouseDown", Guarded("press", EyeDown))
	eye:SetScript("OnMouseUp", Guarded("press", EyeUp))
	eye:SetScript("OnEnter", function(self)
		Try("tooltip", ShowEyeTip, self)
		Try("cover", Q.Cover, self)
	end)
	eye:SetScript(
		"OnLeave",
		Guarded("leave", function(self)
			if GameTooltip:GetOwner() == self then
				GameTooltip:Hide()
			end
		end)
	)
	eye:SetScript(
		"OnClick",
		Guarded("click", function(self)
			Q.Click(self)
		end)
	)
	eye:Hide()
	return eye
end

-- Where Blizzard puts the quest item button when it's the block's first right-edge frame.
local function ItemHome(block)
	local s = block.parentModule and block.parentModule.questItemButtonSettings
	local x = s and PlainNumber(s.offsetX) and s.offsetX or 0
	local y = s and PlainNumber(s.offsetY) and s.offsetY or 0
	return x, y
end

-- Retail's order: the eye at the block's top right, the quest item button left of it and
-- centred on it (out of combat only; the block's own layout puts the button back).
local function Place(eye, block)
	eye:ClearAllPoints()
	eye:SetPoint("TOPRIGHT", block, "TOPRIGHT", OFFSET_X, OFFSET_Y)
	local item = block.rightEdgeFrame
	if type(item) == "table" and item ~= eye and item.SetPoint then
		item:ClearAllPoints()
		item:SetPoint("RIGHT", block, "TOPRIGHT", OFFSET_X - EYE_SIZE - SPACING, OFFSET_Y - EYE_SIZE / 2)
		movedItem[block] = item
	end
end

local function RestoreItem(block)
	local item = movedItem[block]
	if not item then
		return
	end
	if InCombatLockdown() then
		pending = true
		return
	end
	movedItem[block] = nil
	if block.rightEdgeFrame == item then
		local x, y = ItemHome(block)
		item:ClearAllPoints()
		item:SetPoint("TOPRIGHT", block, "TOPRIGHT", x, y)
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
-- With or without the item button, the eye takes the same room from the title's right end.
local function MakeRoom(block)
	local text = block.HeaderText
	if type(text) ~= "table" or not text.SetPoint or not text.GetWidth then
		return
	end
	local base = HeaderBase(block)
	local target = base + OFFSET_X - EYE_SIZE - SPACING
	-- measured, not re-wrapped: the unbounded title must fit the narrower width on one line
	text:SetPoint("RIGHT", base, 0)
	local lineWidth = text:GetWidth()
	local textWidth = text.GetUnboundedStringWidth and text:GetUnboundedStringWidth() or text:GetStringWidth()
	if PlainNumber(lineWidth) and PlainNumber(textWidth) and textWidth <= lineWidth + (target - base) then
		text:SetPoint("RIGHT", target, 0)
		moved[block] = true
	else
		moved[block] = nil
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

local function Off(block)
	HideEye(block)
	Restore(block)
	RestoreItem(block)
end

local function UpdateBlock(block)
	local id = block.id
	if not PlainNumber(id) then
		return Off(block)
	end
	local on = ns.Settings.Get("eliteQuestButton") and CanUsePremade() and Eligible(id)
	if not on then
		return Off(block)
	end
	if InCombatLockdown() and block.rightEdgeFrame then
		-- the quest item button isn't moved in combat: the eye waits for the end of combat
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
	MakeRoom(block)
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
		Fail("layout", err)
	end
	Try("recheck", Q.Recheck)
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
	Q.failed = nil -- before Install: its load callback may record a failure at once
	local ok, result = pcall(Install)
	if not ok then
		Q.failed = tostring(result)
	elseif result == false then
		Q.failed = "missing"
	end
end

-------------------------------------------------------------------------------
--  The quest's name, zone and Quests & Zones activity (read only)
-------------------------------------------------------------------------------
local function QuestName(id)
	if type(C_QuestLog) ~= "table" or type(C_QuestLog.GetTitleForQuestID) ~= "function" then
		return nil
	end
	local ok, value = pcall(C_QuestLog.GetTitleForQuestID, id)
	return ok and PlainString(value) or nil
end

local function MapName(mapID)
	if not PlainNumber(mapID) or mapID <= 0 or type(C_Map) ~= "table" or type(C_Map.GetMapInfo) ~= "function" then
		return nil
	end
	local ok, info = pcall(C_Map.GetMapInfo, mapID)
	if ok and type(info) == "table" then
		return PlainString(info.name)
	end
	return nil
end

-- Forever's quest log groups quests under zone headers: the nearest header above the quest.
local function ZoneFromLog(id)
	if type(C_QuestLog) ~= "table" or type(C_QuestLog.GetLogIndexForQuestID) ~= "function" then
		return nil
	end
	local ok, index = pcall(C_QuestLog.GetLogIndexForQuestID, id)
	if not ok or not PlainNumber(index) or index < 1 or type(C_QuestLog.GetInfo) ~= "function" then
		return nil
	end
	for i = index, 1, -1 do
		local okInfo, info = pcall(C_QuestLog.GetInfo, i)
		if okInfo and type(info) == "table" and not Secret(info.isHeader) and info.isHeader then
			return PlainString(info.title)
		end
	end
	return nil
end

local function ZoneFromTask(id)
	if type(C_TaskQuest) ~= "table" or type(C_TaskQuest.GetQuestZoneID) ~= "function" then
		return nil
	end
	local ok, mapID = pcall(C_TaskQuest.GetQuestZoneID, id)
	return ok and MapName(mapID) or nil
end

local function ZoneFromMap(id)
	if type(GetQuestUiMapID) ~= "function" then
		return nil
	end
	local ok, mapID = pcall(GetQuestUiMapID, id)
	return ok and MapName(mapID) or nil
end

--- The three zone answers (quest log header, task quest zone, quest UI map), for the probe.
function Q.ZoneSources(id)
	return ZoneFromLog(id), ZoneFromTask(id), ZoneFromMap(id)
end

local function Zone(id)
	return ZoneFromLog(id) or ZoneFromTask(id) or ZoneFromMap(id)
end

-- The names an activity goes by: the list's own (LFGUtil_GetActivityInfoName), full, short.
local function ActivityNames(activityID)
	if type(C_LFGList) ~= "table" or type(C_LFGList.GetActivityInfoTable) ~= "function" then
		return {}
	end
	local ok, info = pcall(C_LFGList.GetActivityInfoTable, activityID)
	if not ok or type(info) ~= "table" then
		return {}
	end
	local names = {}
	if type(LFGUtil_GetActivityInfoName) == "function" then
		local okName, listed = pcall(LFGUtil_GetActivityInfoName, info)
		names[#names + 1] = okName and PlainString(listed) or nil
	end
	names[#names + 1] = PlainString(info.fullName)
	names[#names + 1] = PlainString(info.shortName)
	return names
end

--- The Quests & Zones activity named like the quest's zone (the zone sources in order):
--- its ID and name, or nil.
function Q.ActivityFor(id)
	if type(C_LFGList) ~= "table" or type(C_LFGList.GetAvailableActivities) ~= "function" then
		return nil
	end
	local ok, activities = pcall(C_LFGList.GetAvailableActivities, QUEST_CATEGORY)
	if not ok or type(activities) ~= "table" then
		return nil
	end
	local log, task, map = Q.ZoneSources(id)
	for _, zone in ipairs({ log or false, task or false, map or false }) do
		if zone then
			local want = zone:lower()
			for _, activityID in ipairs(activities) do
				if PlainNumber(activityID) then
					for _, name in ipairs(ActivityNames(activityID)) do
						if name:lower() == want then
							return activityID, name
						end
					end
				end
			end
		end
	end
	return nil
end

local function CategoryName()
	if type(C_LFGList) == "table" and type(C_LFGList.GetLfgCategoryInfo) == "function" then
		local ok, info = pcall(C_LFGList.GetLfgCategoryInfo, QUEST_CATEGORY)
		if ok and type(info) == "table" and PlainString(info.name) then
			return info.name
		end
	end
	return "Quests & Zones"
end

local function EliteTag()
	return PlainString(ELITE) or "Elite"
end

local function HasActiveListing()
	if type(C_LFGList) == "table" and type(C_LFGList.HasActiveEntryInfo) == "function" then
		local ok, value = pcall(C_LFGList.HasActiveEntryInfo)
		return ok and not Secret(value) and value == true
	end
	return false
end

--- The hint as one chat line (the stand-in, or with an active listing). Nil without a name.
function Q.HintLine(id)
	local name = QuestName(id)
	if not name then
		return nil
	end
	local zone = Zone(id)
	return name
		.. " ("
		.. EliteTag()
		.. "): list a group under "
		.. CategoryName()
		.. (zone and (", " .. zone) or "")
		.. "."
end

-------------------------------------------------------------------------------
--  The secure click: our cover over the eye, and the two click-delegates
-------------------------------------------------------------------------------
local cover, pickCategory, pickActivity, coverEvents
local armed = { quest = nil, activity = nil, activityName = nil }

-- One of our secure buttons. The macro's /click is a key up: act on it whatever the
-- player's "cast on key down" setting says.
local function SecureButton(name, action)
	local b = CreateFrame("Button", name, UIParent, "SecureActionButtonTemplate")
	b:SetAttribute("type", action)
	b:SetAttribute("useOnKeyDown", false)
	b:RegisterForClicks("LeftButtonUp")
	return b
end

-- The Quests & Zones category button (read only), unless that category is already picked.
local function CategoryButton()
	local frame = LFGListingFrame
	if not frame or type(frame.GetCategorySelection) ~= "function" then
		return nil
	end
	local picked = frame:GetCategorySelection()
	if PlainNumber(picked) and picked == QUEST_CATEGORY then
		return nil
	end
	local buttons = frame.CategoryView and frame.CategoryView.CategoryButtons
	if type(buttons) ~= "table" then
		return nil
	end
	for _, button in ipairs(buttons) do
		if
			type(button) == "table"
			and PlainNumber(button.categoryID)
			and button.categoryID == QUEST_CATEGORY
			and type(button.IsShown) == "function"
			and button:IsShown()
		then
			return button
		end
	end
	return nil
end

-- The zone row's checkbox, when Quests & Zones is picked, the zone isn't ticked yet and its
-- row is on screen (read only: the list is never scrolled or expanded).
local function ActivityCheck(activityID)
	local frame = LFGListingFrame
	if
		not (activityID and frame)
		or type(frame.GetCategorySelection) ~= "function"
		or type(frame.IsActivitySelected) ~= "function"
	then
		return nil
	end
	local picked = frame:GetCategorySelection()
	if not PlainNumber(picked) or picked ~= QUEST_CATEGORY then
		return nil
	end
	if frame:IsActivitySelected(activityID) then
		return nil
	end
	local box = frame.ActivityView and frame.ActivityView.ScrollBox
	if not (box and type(box.FindFrameByPredicate) == "function" and box:IsVisible()) then
		return nil
	end
	local row = box:FindFrameByPredicate(function(_, node)
		local data = type(node) == "table" and type(node.GetData) == "function" and node:GetData() or node
		return type(data) == "table" and PlainNumber(data.activityID) and data.activityID == activityID
	end)
	local check = row and row.CheckButton
	if check and check:IsVisible() and check:IsEnabled() then
		return check
	end
	return nil
end

-- PreClick, out of combat: the macro for this quest. The finder is toggled open only when
-- it's closed (the micro button would close it); with an active listing nothing is picked.
local function Arm(c)
	if InCombatLockdown() then
		return
	end
	-- cleared first: a failure below leaves no stale macro to run
	c:SetAttribute("macrotext", nil)
	armed.quest, armed.activity, armed.activityName = nil, nil, nil
	local text, id, activity, activityName = Try("macro", function()
		local eye = c.eye
		local block = eye and eye:GetParent()
		local questID = block and block.id
		if not PlainNumber(questID) or not LFGParentFrame then
			return nil
		end
		local lines = {}
		if not LFGParentFrame:IsShown() then
			lines[#lines + 1] = "/click " .. OPENER
		end
		lines[#lines + 1] = "/click " .. LISTING_TAB
		local actID, actName
		if not HasActiveListing() then
			lines[#lines + 1] = "/click " .. PICK_CATEGORY
			actID, actName = Q.ActivityFor(questID)
			if actID then
				lines[#lines + 1] = "/click " .. PICK_ACTIVITY
			end
		end
		return table.concat(lines, "\n"), questID, actID, actName
	end)
	if text then
		c:SetAttribute("macrotext", text)
		armed.quest, armed.activity, armed.activityName = id, activity, activityName
	end
end

-- The description box takes no text from addons (SetText, Insert and paste are all refused:
-- "Call is illegal when disabled by security settings"), so with Quests & Zones picked the
-- cursor is put in it, still empty, for the player to type the hint's text. Focus only:
-- nothing of the box is read beyond its text being empty, nothing written.
local function FocusDescription()
	local frame = LFGListingFrame
	if not frame or type(frame.GetCategorySelection) ~= "function" then
		return
	end
	local picked = frame:GetCategorySelection()
	if not PlainNumber(picked) or picked ~= QUEST_CATEGORY then
		return
	end
	local view = frame.ActivityView
	local box = view and view.Comment and view.Comment.EditBox
	if not (box and box.SetFocus and box:IsVisible() and box:IsEnabled()) then
		return
	end
	local text = box:GetText()
	if Secret(text) or (text ~= nil and text ~= "") then
		return
	end
	box:SetFocus()
end

-- PostClick: the hint. Where the macro couldn't open the Listing tab, the game's own opener.
local function After()
	Try("after", function()
		local id = armed.quest
		if not id then
			return
		end
		if not (LFGListingFrame and LFGListingFrame:IsShown()) then
			if InCombatLockdown() or not (ns.InPlace and ns.InPlace.ShowFinder) then
				return
			end
			if not ns.InPlace.ShowFinder(ns.InPlace.LISTING_TAB) then
				return
			end
		end
		if Q.ShowHint(id) then
			Try("description", FocusDescription)
		end
	end)
	armed.quest, armed.activity, armed.activityName = nil, nil, nil
end

local function BuildCover()
	if cover then
		return cover
	end
	local c = SecureButton(nil, "macro")
	c:SetFrameStrata("DIALOG")
	c:Hide()
	c:SetScript(
		"OnEnter",
		Guarded("hover", function(self)
			if self.eye then
				if self.eye.LockHighlight then
					self.eye:LockHighlight()
				end
				Try("tooltip", ShowEyeTip, self)
			end
		end)
	)
	c:SetScript(
		"OnLeave",
		Guarded("leave", function(self)
			if GameTooltip:GetOwner() == self then
				GameTooltip:Hide()
			end
			Try("uncover", Q.Uncover)
		end)
	)
	c:SetScript(
		"OnMouseDown",
		Guarded("press", function(self)
			EyeDown(self.eye)
		end)
	)
	c:SetScript(
		"OnMouseUp",
		Guarded("press", function(self)
			EyeUp(self.eye)
		end)
	)
	c:SetScript("PreClick", Arm)
	c:SetScript("PostClick", After)

	-- each named delegate and the events frame are made once, whatever fails midway
	pickCategory = pickCategory or SecureButton(PICK_CATEGORY, "click")
	pickActivity = pickActivity or SecureButton(PICK_ACTIVITY, "click")
	for _, b in ipairs({ pickCategory, pickActivity }) do
		-- shown so /click always reaches them, but nothing to see or hit
		b:SetSize(1, 1)
		b:SetAlpha(0)
		b:EnableMouse(false)
		b:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", 0, 0)
	end
	pickCategory:SetScript("PreClick", function(self)
		if InCombatLockdown() then
			return
		end
		self:SetAttribute("clickbutton", nil)
		self:SetAttribute("clickbutton", Try("category button", CategoryButton))
	end)
	pickActivity:SetScript("PreClick", function(self)
		if InCombatLockdown() then
			return
		end
		self:SetAttribute("clickbutton", nil)
		self:SetAttribute("clickbutton", Try("activity checkbox", ActivityCheck, armed.activity))
	end)

	-- combat starts: the cover goes while it still can
	if not coverEvents then
		coverEvents = CreateFrame("Frame")
		coverEvents:RegisterEvent("PLAYER_REGEN_DISABLED")
		coverEvents:SetScript("OnEvent", function()
			Try("uncover", Q.Uncover)
		end)
	end
	cover = c
	return c
end

--- Lays our secure cover over the eye under the mouse (out of combat, in game only), by
--- screen coordinates: nothing of the tracker is anchored to it.
function Q.Cover(eye)
	if InCombatLockdown() or not LFGParentFrame or not ns.Listings.HasAPI() then
		return
	end
	if not eye then
		return
	end
	local left, bottom = eye:GetLeft(), eye:GetBottom()
	local width, height = eye:GetSize()
	if not (PlainNumber(left) and PlainNumber(bottom) and PlainNumber(width) and PlainNumber(height)) then
		return
	end
	Try("build", BuildCover)
	local c = cover
	if not c then
		return
	end
	if c.eye and c.eye ~= eye and c.eye.UnlockHighlight then
		c.eye:UnlockHighlight()
	end
	c.eye = eye
	c:SetScale(eye:GetEffectiveScale() / UIParent:GetEffectiveScale())
	c:ClearAllPoints()
	c:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", left, bottom)
	c:SetSize(width, height)
	c:Show()
end

--- After a tracker layout: the cover follows its eye while the mouse is still over it, and
--- goes when the eye is gone or the mouse left.
function Q.Recheck()
	if not cover or not cover:IsShown() or InCombatLockdown() then
		return
	end
	local eye = cover.eye
	if eye and eye.IsVisible and eye:IsVisible() and eye:IsMouseOver() then
		Q.Cover(eye)
	else
		Q.Uncover()
	end
end

--- Takes the cover away (out of combat; in combat it was already taken at its start).
function Q.Uncover()
	if not cover or not cover:IsShown() or InCombatLockdown() then
		return
	end
	local eye = cover.eye
	if eye then
		if eye.UnlockHighlight then
			eye:UnlockHighlight()
		end
		EyeUp(eye)
	end
	cover:Hide()
end

-------------------------------------------------------------------------------
--  The hint (our own box beside the finder) and the category outline
-------------------------------------------------------------------------------
local hint, outline

local function StopOutline()
	if outline then
		if outline.pulse then
			outline.pulse:Stop()
		end
		outline:Hide()
	end
end

-- Our own pulsing outline on the Quests & Zones category button (read only use of it),
-- shown only while that category isn't picked yet.
local function PlaceOutline()
	local target = CategoryButton()
	if not target then
		return StopOutline()
	end
	if not outline then
		outline = CreateFrame("Frame", nil, target)
		outline:EnableMouse(false)
		if ns.W.HasAtlas(OUTLINE_ATLAS) then
			local tex = outline:CreateTexture(nil, "OVERLAY")
			tex:SetAtlas(OUTLINE_ATLAS, true)
			tex:SetBlendMode("ADD")
			tex:SetPoint("CENTER")
		else
			local c = NORMAL_FONT_COLOR
			local r, g, b = 1, 0.82, 0
			if c then
				r, g, b = c.r, c.g, c.b
			end
			local function Edge(p1, p2, w, h)
				local t = outline:CreateTexture(nil, "OVERLAY")
				t:SetColorTexture(r, g, b, 1)
				t:SetBlendMode("ADD")
				t:SetPoint(p1)
				t:SetPoint(p2)
				if w then
					t:SetWidth(w)
				end
				if h then
					t:SetHeight(h)
				end
			end
			Edge("TOPLEFT", "TOPRIGHT", nil, 2)
			Edge("BOTTOMLEFT", "BOTTOMRIGHT", nil, 2)
			Edge("TOPLEFT", "BOTTOMLEFT", 2, nil)
			Edge("TOPRIGHT", "BOTTOMRIGHT", 2, nil)
		end
		local group = outline:CreateAnimationGroup()
		local alpha = group:CreateAnimation("Alpha")
		alpha:SetFromAlpha(0.35)
		alpha:SetToAlpha(1)
		alpha:SetDuration(0.8)
		group:SetLooping("BOUNCE")
		outline.pulse = group
	end
	outline:SetParent(target)
	outline:ClearAllPoints()
	outline:SetAllPoints(target)
	outline:SetFrameLevel(target:GetFrameLevel() + 5)
	outline:Show()
	outline.pulse:Play()
end

-- Beside the description box, just outside the finder (below its side tabs); while the box
-- isn't shown (no category picked yet), right of the side tabs at the top.
local function PlaceHint()
	if not hint then
		return
	end
	if not (LFGListingFrame and LFGParentFrame) then
		return
	end
	hint:ClearAllPoints()
	local view = LFGListingFrame.ActivityView
	local comment = view and view.Comment
	local frameRight = LFGParentFrame:GetRight()
	local commentRight = comment and comment.IsVisible and comment:IsVisible() and comment:GetRight()
	if PlainNumber(frameRight) and PlainNumber(commentRight) then
		hint:SetPoint("LEFT", comment, "RIGHT", frameRight - commentRight + 4, 0)
	else
		local tabs = LFGParentFrame.ListingTab
		local tabWidth = tabs and tabs:IsShown() and tabs:GetWidth()
		hint:SetPoint("TOPLEFT", LFGParentFrame, "TOPRIGHT", (PlainNumber(tabWidth) and tabWidth or SIDE_TAB_W) + 6, -2)
	end
end

local function BuildHint()
	if hint then
		return hint
	end
	if not (LFGListingFrame and LFGParentFrame) then
		return nil
	end
	local W = ns.W
	-- a child of the Listing tab (it hides with it), placed outside the finder, past its
	-- side tabs: the finder keeps its size
	local f = W.Create("Frame", LFGListingFrame, "BackdropTemplate")
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
	f:SetWidth(HINT_W)
	f:SetFrameLevel(LFGListingFrame:GetFrameLevel() + 10)
	f:EnableMouse(true)
	f:Hide()

	local close
	local okClose, made = pcall(W.Create, "Button", f, "UIPanelCloseButton")
	if okClose and made then
		close = made
	else
		close = W.Button(f, "x", 20, 20)
	end
	close:SetPoint("TOPRIGHT", -2, -2)
	close:SetScript("OnClick", function()
		f:Hide()
	end)

	local inner = HINT_W - 2 * HINT_PAD
	f.lines = {}
	for i = 1, 4 do
		local fs = W.Text(f, i == 1 and "GameFontNormal" or "GameFontHighlightSmall", i == 1 and 12 or 11)
		fs:SetWidth(i == 1 and inner - 20 or inner)
		fs:SetJustifyH("LEFT")
		fs:SetWordWrap(false) -- width-bound: a long name is cut, never wrapped
		if fs.SetMaxLines then
			fs:SetMaxLines(1)
		end
		f.lines[i] = fs
	end
	f.lines[1]:SetTextColor(1, 0.82, 0)

	f:SetScript("OnHide", StopOutline)
	hint = f

	LFGListingFrame:HookScript("OnHide", function()
		if hint:IsShown() then
			hint:Hide()
		end
	end)
	local view = LFGListingFrame.CategoryView
	if view then
		view:HookScript("OnShow", function()
			if hint:IsShown() then
				Try("outline", PlaceOutline)
				Try("hint", PlaceHint)
			end
		end)
	end
	local activities = LFGListingFrame.ActivityView
	if activities then
		activities:HookScript("OnShow", function()
			if hint:IsShown() then
				Try("hint", PlaceHint)
			end
		end)
	end
	local events = CreateFrame("Frame")
	events:RegisterEvent("LFG_LIST_ACTIVE_ENTRY_UPDATE")
	events:SetScript("OnEvent", function()
		if hint:IsShown() and HasActiveListing() then
			hint:Hide()
		end
	end)
	return hint
end

local function ShowHintBody(id)
	local name = QuestName(id)
	if not name or not LFGListingFrame or not LFGListingFrame:IsShown() then
		return false
	end
	if HasActiveListing() then
		-- the Listing tab shows the active listing, no categories
		local line = Q.HintLine(id)
		if line then
			ns.Print(line)
		end
		return false
	end
	local f = BuildHint()
	if not f then
		return false
	end
	local picked, ticked = false, false
	if type(LFGListingFrame.GetCategorySelection) == "function" then
		local selection = LFGListingFrame:GetCategorySelection()
		picked = PlainNumber(selection) and selection == QUEST_CATEGORY
	end
	local activity = armed.quest == id and armed.activity or nil
	local zone = armed.quest == id and armed.activityName or Zone(id)
	if picked and activity and type(LFGListingFrame.IsActivitySelected) == "function" then
		ticked = LFGListingFrame:IsActivitySelected(activity) == true
	end

	local texts = { "[" .. EliteTag() .. "] " .. name }
	if zone then
		texts[#texts + 1] = "Zone: " .. zone .. (ticked and " (ticked)" or "")
	end

	local height = HINT_PAD * 2
	local above
	for i, fs in ipairs(f.lines) do
		local text = texts[i]
		fs:ClearAllPoints()
		if text then
			fs:SetText(text)
			if above then
				fs:SetPoint("TOPLEFT", above, "BOTTOMLEFT", 0, -GAP)
				height = height + GAP
			else
				fs:SetPoint("TOPLEFT", HINT_PAD, -HINT_PAD)
			end
			height = height + (fs:GetStringHeight() or 0)
			fs:Show()
			above = fs
		else
			fs:Hide()
		end
	end
	Try("hint", PlaceHint)
	f:SetHeight(height)
	f:Show()
	if not Try("outline", function()
		PlaceOutline()
		return true
	end) then
		StopOutline()
	end
	return true
end

--- Shows the hint box beside the finder (and the outline while Quests & Zones isn't
--- picked). False when it only printed a chat line (an active listing) or showed nothing.
function Q.ShowHint(id)
	return Try("hint", ShowHintBody, id) == true
end

--- The eye's own click, reached only when the cover isn't over it: in combat a chat line;
--- the stand-in prints the hint; else the game's own opener and the hint, nothing picked.
function Q.Click(eye)
	local block = eye and eye:GetParent()
	local id = block and block.id
	if not PlainNumber(id) then
		return
	end
	if InCombatLockdown() then
		ns.Print("can't open the group finder in combat.")
		return
	end
	if not ns.Listings.HasAPI() then
		local line = Q.HintLine(id)
		if line then
			ns.Print(line)
		end
		return
	end
	armed.quest, armed.activity, armed.activityName = nil, nil, nil
	if ns.InPlace and ns.InPlace.ShowFinder and ns.InPlace.ShowFinder(ns.InPlace.LISTING_TAB) then
		Q.ShowHint(id)
	end
end

-------------------------------------------------------------------------------
--  /tgf quest: what the eye reads, per tracked quest (read only)
-------------------------------------------------------------------------------
local function Say(v)
	if Secret(v) then
		return "secret"
	end
	return tostring(v)
end

local function Call(fn, ...)
	if type(fn) ~= "function" then
		return "n/a"
	end
	local ok, a = pcall(fn, ...)
	if not ok then
		return "error"
	end
	return Say(a)
end

local function EyeShown(id)
	for block, eye in pairs(eyes) do
		if block.id == id and eye:IsShown() then
			return true
		end
	end
	return false
end

local function TrackedIDs()
	local ids = {}
	if
		type(C_QuestLog) == "table"
		and type(C_QuestLog.GetNumQuestWatches) == "function"
		and type(C_QuestLog.GetQuestIDForQuestWatchIndex) == "function"
	then
		for i = 1, C_QuestLog.GetNumQuestWatches() do
			local id = C_QuestLog.GetQuestIDForQuestWatchIndex(i)
			if PlainNumber(id) then
				ids[#ids + 1] = id
			end
		end
		return ids
	end
	for _, module in ipairs(hookedList) do
		for _, blocks in pairs(module.usedBlocks or {}) do
			for _, block in pairs(blocks) do
				if PlainNumber(block.id) then
					ids[#ids + 1] = block.id
				end
			end
		end
	end
	return ids
end

-- ", failed steps: build, hint" for the steps that failed this session, else "".
local function FailedSteps()
	local steps = {}
	for step in pairs(reported) do
		steps[#steps + 1] = step
	end
	if #steps == 0 then
		return ""
	end
	table.sort(steps)
	return ", failed steps: " .. table.concat(steps, ", ")
end

function Q.Probe()
	local ok, err = pcall(function()
		local names = {}
		for _, name in ipairs(MODULES) do
			if hooked[_G[name]] then
				names[#names + 1] = name
			end
		end
		ns.Print(
			"quest eye: hooked "
				.. (#names > 0 and table.concat(names, ", ") or "none")
				.. (Q.failed and (", failed: " .. Q.failed) or "")
				.. (Q.lastError and (", last error: " .. Q.lastError) or "")
				.. FailedSteps()
				.. ", eliteQuestButton "
				.. Say(ns.Settings.Get("eliteQuestButton"))
				.. ", premade "
				.. (C_LFGInfo and Call(C_LFGInfo.CanPlayerUsePremadeGroup) or "n/a")
				.. ", opener "
				.. (_G[OPENER] and "yes" or "missing")
				.. ", listing tab button "
				.. (_G[LISTING_TAB] and "yes" or "missing")
		)
		local ids = TrackedIDs()
		if #ids == 0 then
			ns.Print("no tracked quests")
		end
		for _, id in ipairs(ids) do
			local tagID, tagName = "?", "?"
			if type(C_QuestLog) == "table" and type(C_QuestLog.GetQuestTagInfo) == "function" then
				local okTag, info = pcall(C_QuestLog.GetQuestTagInfo, id)
				if okTag and type(info) == "table" then
					tagID, tagName = Say(info.tagID), Say(info.tagName)
				end
			end
			local log, task, map = Q.ZoneSources(id)
			local activity, activityName = Q.ActivityFor(id)
			ns.Print(
				id
					.. " "
					.. (QuestName(id) or "?")
					.. ": elite "
					.. Call(C_QuestLog and C_QuestLog.IsEliteQuest, id)
					.. ", tag "
					.. tagID
					.. " "
					.. tagName
					.. ", CanCreateQuestGroup "
					.. Call(C_LFGList and C_LFGList.CanCreateQuestGroup, id)
					.. ", our eye "
					.. (EyeShown(id) and "yes" or "no")
					.. ", zone log "
					.. Say(log)
					.. " / task "
					.. Say(task)
					.. " / map "
					.. Say(map)
					.. ", activity "
					.. (activity and (Say(activity) .. " " .. Say(activityName)) or "none")
			)
		end
		local list = "n/a"
		if type(C_LFGList) == "table" and type(C_LFGList.GetAvailableActivities) == "function" then
			local okAct, acts = pcall(C_LFGList.GetAvailableActivities, QUEST_CATEGORY)
			list = "none"
			if okAct and type(acts) == "table" and #acts > 0 then
				local out = {}
				for _, actID in ipairs(acts) do
					local okInfo, info = pcall(C_LFGList.GetActivityInfoTable, actID)
					out[#out + 1] = okInfo and type(info) == "table" and Say(info.fullName) or Say(actID)
				end
				list = table.concat(out, ", ")
			end
		end
		ns.Print("Quests & Zones (116) activities: " .. list)
	end)
	if not ok then
		ns.Print("quest probe failed: " .. tostring(err))
	end
end
