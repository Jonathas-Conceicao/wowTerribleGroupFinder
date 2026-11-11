-------------------------------------------------------------------------------
--  UI/InPlace.lua -- puts the table inside Forever's own group finder (ns.InPlace).
--
--  Once Blizzard_GroupFinder_VanillaStyle loads, its Browse tab (LFGBrowseFrame) keeps its
--  title, portrait, Category and Activity dropdowns, refresh and options buttons, so the
--  game still does the searching; its result list and bottom buttons give way to ours, and
--  the window widens while Browse is shown. Its Listing and Who tabs are left as they are;
--  a fourth side tab, Messages, holds the whisper presets.
--
--  Taint: nothing of Blizzard's is replaced or written to. We only Hide() its parts (its
--  list, hooked to stay hidden; its panels while Messages shows), HookScript its OnShow/
--  OnHide, call its tabs' SetChecked, resize the parent and parent our own frames to it.
--  Restricted calls (Search, CreateListing) stay Blizzard's; ours are invites and
--  whispers, all from clicks.
--
--  Where the game has no group finder, /tgf opens the preview stand-in.
-------------------------------------------------------------------------------
local _, ns = ...

local IP = {}
ns.InPlace = IP

local FINDER = "Blizzard_GroupFinder_VanillaStyle"
local BROWSE_TAB = 2
local WIDE = 620
local REPLACED =
	{ "ScrollBox", "ScrollBar", "SendMessageButton", "GroupInviteButton", "NoResultsFound", "SearchingSpinner" }
local EVENTS = {
	"LFG_LIST_SEARCH_RESULTS_RECEIVED",
	"LFG_LIST_SEARCH_RESULT_UPDATED",
	"LFG_LIST_SEARCH_FAILED",
	"LFG_LIST_ACTIVE_ENTRY_UPDATE",
	"GROUP_ROSTER_UPDATE",
}

local IsLoaded = C_AddOns and C_AddOns.IsAddOnLoaded or IsAddOnLoaded

local tbl, baseWidth
local pending = false

local function Read()
	pending = false
	if not ns.UsingPreview() then
		ns.Listings.Read()
	end
	if tbl then
		tbl:Refresh()
	end
end

-- Result updates come in bursts; read once per burst.
local function ReadSoon()
	if pending then
		return
	end
	pending = true
	C_Timer.After(0.2, Read)
end

local source = {
	listings = function()
		if ns.UsingPreview() then
			return ns.PreviewListings(2)
		end
		return ns.Listings.items
	end,
	preview = function()
		return ns.UsingPreview()
	end,
	searching = function()
		return LFGBrowseFrame and LFGBrowseFrame.searching == true
	end,
}

local function StayHidden(part)
	part:Hide()
	hooksecurefunc(part, "Show", part.Hide)
	hooksecurefunc(part, "SetShown", function(self, shown)
		if shown then
			self:Hide()
		end
	end)
end

-- A fourth side tab, under Forever's own three, for the whisper presets. Showing it hides
-- the three panels (Hide() only); any of them showing again hides it.
local messages, messagesTab, refreshMessages

local function ShowMessages()
	for _, f in ipairs({ LFGListingFrame, LFGBrowseFrame, LFGWhoListFrame }) do
		f:Hide()
	end
	for _, key in ipairs({ "ListingTab", "BrowsingTab", "WhoListingTab" }) do
		local tab = LFGParentFrame[key]
		if tab and tab.SetChecked then
			tab:SetChecked(false)
		end
	end
	messages:Show()
	if messagesTab.SetChecked then
		messagesTab:SetChecked(true)
	end
	refreshMessages()
end

local function HideMessages()
	if not messages:IsShown() then
		return
	end
	messages:Hide()
	if messagesTab.SetChecked then
		messagesTab:SetChecked(false)
	end
end

local function AddMessagesTab()
	local W = ns.W
	messages = W.Create("Frame", LFGParentFrame, "PortraitFrameTemplateNoCloseButton")
	messages:SetAllPoints()
	messages:SetFrameLevel(LFGBrowseFrame:GetFrameLevel())
	if messages.SetTitle then
		messages:SetTitle(LFG_TITLE or "Group Finder")
	end
	local stone = messages:CreateTexture(nil, "BACKGROUND", nil, 1)
	stone:SetPoint("TOPLEFT", 2, -21)
	stone:SetPoint("BOTTOMRIGHT", -2, 3)
	if not W.Atlas(stone, "groupfinder-background") then
		stone:SetColorTexture(0.05, 0.05, 0.05, 0.8)
	end
	local content = CreateFrame("Frame", nil, messages)
	content:SetPoint("TOPLEFT", 16, -70)
	content:SetPoint("BOTTOMRIGHT", -16, 16)
	refreshMessages = ns.Messages.BuildPanel(content)
	messages:Hide()

	local below = LFGParentFrame.WhoListingTab or LFGParentFrame.BrowsingTab
	messagesTab = W.Create("Frame", LFGParentFrame, "LargeSideTabButtonTemplate")
	messagesTab:SetPoint("TOPLEFT", below, "BOTTOMLEFT", 0, -2)
	if messagesTab.Icon then
		messagesTab.Icon:SetTexture("Interface\\Icons\\INV_Letter_15")
		messagesTab.Icon:SetSize(30, 30)
		messagesTab.Icon:SetTexCoord(0.03125, 0.96875, 0.03125, 0.96875)
	end
	messagesTab.tooltipText = "Messages"
	if messagesTab.SetCustomOnMouseUpHandler then
		messagesTab:SetCustomOnMouseUpHandler(function(_, button, upInside)
			if button == "LeftButton" and upInside then
				ShowMessages()
			end
		end)
	else
		messagesTab:EnableMouse(true)
		messagesTab:SetScript("OnMouseUp", ShowMessages)
	end
	W.Tooltip(messagesTab, "Messages", "Whisper presets for inviting players and asking groups.")
	for _, f in ipairs({ LFGListingFrame, LFGBrowseFrame, LFGWhoListFrame }) do
		f:HookScript("OnShow", HideMessages)
	end
end

local function Attach()
	if tbl or not (LFGBrowseFrame and LFGParentFrame) then
		return
	end
	local f = LFGBrowseFrame
	baseWidth = LFGParentFrame:GetWidth()
	tbl = ns.Table.Attach(f, f.BackgroundArt or f, source)
	for _, key in ipairs(REPLACED) do
		if f[key] then
			StayHidden(f[key])
		end
	end
	f:HookScript("OnShow", function()
		LFGParentFrame:SetWidth(WIDE)
		ns.Table.ClearSelection()
		Read()
	end)
	f:HookScript("OnHide", function()
		LFGParentFrame:SetWidth(baseWidth)
	end)
	if f:IsShown() then
		LFGParentFrame:SetWidth(WIDE)
	end
	if LFGListingFrame and LFGWhoListFrame then
		AddMessagesTab()
	end
	if LFGBrowse_DoSearch then
		hooksecurefunc("LFGBrowse_DoSearch", function()
			ns.Table.ClearSelection()
		end)
	end
	local events = CreateFrame("Frame")
	for _, event in ipairs(EVENTS) do
		events:RegisterEvent(event)
	end
	events:SetScript("OnEvent", function(_, event)
		if event == "LFG_LIST_SEARCH_RESULTS_RECEIVED" or event == "LFG_LIST_SEARCH_FAILED" then
			ns.Table.ClearSelection()
		end
		ReadSoon()
	end)
	Read()
end

function IP.Init()
	if not ns.Listings.HasAPI() then
		return
	end
	if IsLoaded(FINDER) then
		return Attach()
	end
	local wait = CreateFrame("Frame")
	wait:RegisterEvent("ADDON_LOADED")
	wait:SetScript("OnEvent", function(self, _, name)
		if name == FINDER then
			self:UnregisterAllEvents()
			Attach()
		end
	end)
end

--- /tgf: toggles the game's group finder on Browse; the preview stand-in where there is
--- none. With keepOpen, only opens it (or re-reads it when already open).
function IP.Open(keepOpen)
	if tbl and LFGVanilla_ToggleFrame then
		if InCombatLockdown() then
			return ns.Print("can't open the group finder in combat.")
		end
		if keepOpen and LFGBrowseFrame:IsShown() then
			return Read()
		end
		LFGVanilla_ToggleFrame(BROWSE_TAB)
		return
	end
	ns.state.preview = true
	if keepOpen then
		ns.UI.Show("browse")
	else
		ns.UI.Toggle("browse")
	end
end
