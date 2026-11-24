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
--
--  The hint box is our own frame parented to the Listing tab; the finder is widened for it
--  (IP.WidenListing). Our outline is parented to the Quests & Zones category button. Both
--  only read Blizzard's frames: nothing is selected, filled or clicked, the player picks,
--  types and posts.
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
local QUEST_CATEGORY = 116 -- Forever's file-local LFGLISTING_QUEST_CATEGORY_ID, carried as our own
local HINT_W = 240
local HINT_EXTRA = HINT_W + 12
local HINT_TOP = -26 -- just under the title bar, the roles band's top
local HINT_PAD = 12
local HINT_MAX_HEIGHT = 100 -- the category buttons start about 106 px below the hint's top
local GAP = 3
local OUTLINE_ATLAS = "groupfinder-button-cover-hover"

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

-------------------------------------------------------------------------------
--  The hint (our own box on the Listing tab) and the category outline
-------------------------------------------------------------------------------
local function PlainString(v)
	if type(v) == "string" and not Secret(v) and v ~= "" then
		return v
	end
	return nil
end

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

-- The four strings, or nil when the quest's name can't be read.
local function HintText(id)
	local name = QuestName(id)
	if not name then
		return nil
	end
	local zone = Zone(id)
	return "[" .. EliteTag() .. "] " .. name,
		"Category: " .. CategoryName(),
		zone and ("Zone: " .. zone) or nil,
		'Description: type "' .. name .. '"'
end

--- The hint as one chat line (the stand-in, or when the box can't show). Nil without a name.
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
		.. ', description "'
		.. name
		.. '".'
end

local hint, outline

local function Cleanup()
	if outline then
		if outline.pulse then
			outline.pulse:Stop()
		end
		outline:Hide()
	end
	ns.InPlace.WidenListing(0)
end

-- Our own pulsing outline on the Quests & Zones category button (read only use of it).
local function PlaceOutline()
	local view = LFGListingFrame and LFGListingFrame.CategoryView
	local buttons = view and view.CategoryButtons
	local target
	if type(buttons) == "table" then
		for _, button in ipairs(buttons) do
			if type(button) == "table" and button.categoryID == QUEST_CATEGORY and button:IsShown() then
				target = button
				break
			end
		end
	end
	if not target then
		if outline then
			if outline.pulse then
				outline.pulse:Stop()
			end
			outline:Hide()
		end
		return
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

local function HasActiveListing()
	if type(C_LFGList) == "table" and type(C_LFGList.HasActiveEntryInfo) == "function" then
		local ok, value = pcall(C_LFGList.HasActiveEntryInfo)
		return ok and not Secret(value) and value == true
	end
	return false
end

local function BuildHint()
	if hint then
		return hint
	end
	if not LFGListingFrame then
		return nil
	end
	local W = ns.W
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
	f:SetPoint("TOPRIGHT", LFGListingFrame, "TOPRIGHT", -6, HINT_TOP)
	f:SetFrameLevel(math.max(LFGListingFrame:GetFrameLevel() + 10, 510))
	f:EnableMouse(true)
	f:Hide()

	local close
	local okClose, made = pcall(W.Create, "Button", f, "UIPanelCloseButton")
	if okClose and made then
		close = made
		close:SetPoint("TOPRIGHT", -2, -2)
	else
		close = W.Button(f, "x", 20, 20)
		close:SetPoint("TOPRIGHT", -2, -2)
	end
	close:SetScript("OnClick", function()
		f:Hide()
	end)

	local inner = HINT_W - 2 * HINT_PAD
	f.title = W.Text(f, "GameFontNormal", 12)
	f.title:SetWidth(inner - 20)
	f.category = W.Text(f, "GameFontHighlightSmall", 11)
	f.category:SetWidth(inner)
	f.zone = W.Text(f, "GameFontHighlightSmall", 11)
	f.zone:SetWidth(inner)
	f.desc = W.Text(f, "GameFontHighlightSmall", 11)
	f.desc:SetWidth(inner)
	for _, fs in ipairs({ f.title, f.category, f.zone, f.desc }) do
		fs:SetJustifyH("LEFT")
		fs:SetWordWrap(false) -- width-bound: a long name is cut, never wrapped
		if fs.SetMaxLines then
			fs:SetMaxLines(1)
		end
	end
	f.title:SetTextColor(1, 0.82, 0)
	f.title:SetPoint("TOPLEFT", HINT_PAD, -HINT_PAD)
	f.category:SetPoint("TOPLEFT", f.title, "BOTTOMLEFT", 0, -GAP)

	f:SetScript("OnHide", Cleanup)
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
				PlaceOutline()
			end
		end)
	end
	local events = CreateFrame("Frame")
	events:RegisterEvent("LFG_LIST_ACTIVE_ENTRY_UPDATE")
	events:RegisterEvent("PLAYER_REGEN_DISABLED")
	events:SetScript("OnEvent", function(_, event)
		if not hint:IsShown() then
			return
		end
		if event == "PLAYER_REGEN_DISABLED" or HasActiveListing() then
			hint:Hide()
		end
	end)
	return hint
end

--- Shows the hint box and the outline on the Listing tab. False when it only printed a chat
--- line (no name, an active listing, no finder to widen) or showed nothing.
function Q.ShowHint(id)
	local title, category, zone, desc = HintText(id)
	if not title or not LFGListingFrame or not LFGListingFrame:IsShown() then
		return false
	end
	if HasActiveListing() then
		-- the Listing tab shows the active listing, no categories
		ns.Print(Q.HintLine(id))
		return false
	end
	local f = BuildHint()
	if not f then
		return false
	end
	if not ns.InPlace.WidenListing(HINT_EXTRA) then
		ns.Print(Q.HintLine(id))
		return false
	end
	f.title:SetText(title)
	f.category:SetText(category)
	f.desc:SetText(desc)
	f.desc:ClearAllPoints()
	local height = HINT_PAD * 2 + f.title:GetStringHeight() + f.category:GetStringHeight() + f.desc:GetStringHeight()
	if zone then
		f.zone:SetText(zone)
		f.zone:ClearAllPoints()
		f.zone:SetPoint("TOPLEFT", f.category, "BOTTOMLEFT", 0, -GAP)
		f.zone:Show()
		f.desc:SetPoint("TOPLEFT", f.zone, "BOTTOMLEFT", 0, -GAP)
		height = height + f.zone:GetStringHeight() + GAP * 3
	else
		f.zone:Hide()
		f.desc:SetPoint("TOPLEFT", f.category, "BOTTOMLEFT", 0, -GAP)
		height = height + GAP * 2
	end
	f:SetHeight(math.min(height, HINT_MAX_HEIGHT))
	f:Show()
	PlaceOutline()
	return true
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
	if not ns.Listings.HasAPI() then
		-- the stand-in / preview has no finder: the hint as one chat line
		local line = Q.HintLine(id)
		if line then
			ns.Print(line)
		end
		return
	end
	if ns.InPlace.ShowFinder(ns.InPlace.LISTING_TAB) then
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
				.. ", eliteQuestButton "
				.. Say(ns.Settings.Get("eliteQuestButton"))
				.. ", premade "
				.. (C_LFGInfo and Call(C_LFGInfo.CanPlayerUsePremadeGroup) or "n/a")
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
