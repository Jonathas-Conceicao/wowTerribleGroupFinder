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
--  whispers, all from clicks. The finder is opened only through the game's own
--  LFGVanilla_ShowFrame (IP.ShowFinder), out of combat.
--
--  Where the game has no group finder, /tgf opens the preview stand-in.
-------------------------------------------------------------------------------
local _, ns = ...

local IP = {}
ns.InPlace = IP

local FINDER = "Blizzard_GroupFinder_VanillaStyle"
local BROWSE_TAB = 2
IP.LISTING_TAB = 1
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

-------------------------------------------------------------------------------
--  Dynamic refresh (setting dynamicRefresh, default on): the game's own search of the same
--  category and activities the list already shows (the refresh button, or Browse opening
--  again) doesn't blank the list. The search stays Blizzard's; we only read differently:
--  no spinner, the list as it was until the answer, then the answer replaces it in place
--  (ns.Listings.Read(snapshot)): new listings take their sorted place, the ones it lacks
--  or that came back delisted leave (swiping out, ns.Motion) and stay out until the next
--  new search (unless relisted), and the selection and whisper/invite marks follow their
--  listing by key. A failed refresh keeps the list; a search for anything else is a new
--  list; with the setting off every search is stock.
--  An answer wider than the picked activities (the first search after a reload, still out
--  when they were picked) shows only the picked ones (narrowTo).
--  There is never a refresh on a timer: the game blocks `Search` from one
--  (ADDON_ACTION_BLOCKED), and this addon never calls `Search` at all.
-------------------------------------------------------------------------------
local REFRESH_WAIT = 10 -- seconds a Dynamic refresh is waited on
-- pending: its answer is awaited; failed: it failed (the list stays); merge: its answer
-- arrived and the next read merges it; snapshot: the list it's compared with.
local refresh = { pending = false, failed = false, merge = false, snapshot = nil, at = 0 }
local shownFilter -- the category and activities of the list shown (set by its answer), as a string
-- The search Blizzard has out: LFGBrowse_DoSearch searches only while it isn't searching
-- already, so a call while one is out (its own double calls, a click during a search) does
-- nothing, and neither do we. issued: that search's filter, shown once it answers.
local searchOut, issued = false, nil
-- The category and activity set (empty: the whole category) of that search, and the set an
-- answer wider than the picks is narrowed to (held until the next answer).
local issuedCategory, issuedSet, narrowTo = nil, {}, nil

-- The picked activity IDs from the dropdown, in order (numbers only).
local function PickedIDs()
	local f = LFGBrowseFrame
	local acts = f and f.ActivityDropdown and f.ActivityDropdown.selectedValues
	local ids = {}
	if type(acts) == "table" then
		for _, id in ipairs(acts) do
			if type(id) == "number" then
				ids[#ids + 1] = id
			end
		end
	end
	return ids
end

local function PickedCategory()
	local f = LFGBrowseFrame
	local dd = f and f.CategoryDropdown
	if dd and type(dd.GetValue) == "function" then
		local ok, v = pcall(dd.GetValue, dd)
		if ok and type(v) == "number" then
			return v
		end
	end
	return nil
end

-- The picked activities as a set when an answer for the search (category, searched) is
-- wider than them; nil for a normal answer or when the picks can't be derived from it.
local function NarrowSet(category, searched)
	if type(searched) ~= "table" or type(category) ~= "number" or PickedCategory() ~= category then
		return nil
	end
	local picks = PickedIDs()
	if #picks == 0 then
		return nil
	end
	local wide = next(searched) ~= nil
	local set, n = {}, 0
	for _, id in ipairs(picks) do
		if wide and not searched[id] then
			return nil -- picked what wasn't searched: not derivable
		end
		if not set[id] then
			set[id] = true
			n = n + 1
		end
	end
	local m = 0
	for _ in pairs(searched) do
		m = m + 1
	end
	if m == n then
		return nil -- the same set: a normal answer
	end
	return set
end

-- The category and activities Blizzard's dropdowns hold, as a string (nil without an activity).
local function FilterKey()
	local f = LFGBrowseFrame
	local category = f and f.CategoryDropdown and f.CategoryDropdown.GetValue and f.CategoryDropdown:GetValue()
	local acts = f and f.ActivityDropdown and f.ActivityDropdown.selectedValues
	if type(category) ~= "number" or category <= 0 or type(acts) ~= "table" or #acts == 0 then
		return nil
	end
	local ids = {}
	for i, id in ipairs(acts) do
		ids[i] = tostring(id)
	end
	table.sort(ids)
	return category .. ":" .. table.concat(ids, ",")
end

local readAfterSwipe = false -- a read came in during a swipe-out: it runs once the list updated
local ReadSoon

-- Hooked after LFGBrowse_DoSearch: a refresh of the list shown, or a new list.
local function OnSearch()
	if searchOut then
		return -- Blizzard was searching already: this call started nothing
	end
	if not (LFGBrowseFrame and LFGBrowseFrame.searching == true) then
		return -- nothing searched (no category)
	end
	searchOut = true
	-- A new search shows its state at once: a swipe in progress is cancelled, and a read
	-- of the old answer deferred by it no longer runs (cleared before the cancel runs it).
	readAfterSwipe = false
	ns.Motion.Cancel()
	local key = FilterKey()
	issued = key
	issuedCategory = PickedCategory()
	issuedSet = {}
	for _, id in ipairs(PickedIDs()) do
		issuedSet[id] = true
	end
	if ns.UsingPreview() then
		-- /tgf preview: a search of the same filter again (the refresh button) runs the
		-- simulated refresh; any other is a new list of the preview data. The real search
		-- is harmless.
		local again = key ~= nil and key == shownFilter
		shownFilter = key
		if again then
			return ns.Preview.Refresh()
		end
		return ns.Table.ClearSelection()
	end
	local same = key ~= nil
		and key == shownFilter
		and #ns.Listings.items > 0
		and ns.Settings.Get("dynamicRefresh") ~= false
	refresh.failed, refresh.merge = false, false
	if same then
		refresh.pending, refresh.snapshot, refresh.at = true, ns.Listings.Snapshot(), GetTime()
		local at = refresh.at
		C_Timer.After(REFRESH_WAIT, function()
			if refresh.pending and refresh.at == at then
				refresh.pending, refresh.snapshot = false, nil -- no answer: the next read is a plain one
			end
		end)
	else
		refresh.pending, refresh.snapshot = false, nil
		ns.Listings.ClearDropped() -- a new list: what earlier refreshes dropped may show again
		ns.Table.ClearSelection()
	end
end

-- Once a refresh is in view (any Motion.Show, the preview's too), a read that came in
-- meanwhile runs.
local function AfterMotion()
	if readAfterSwipe then
		readAfterSwipe = false
		ReadSoon()
	end
end

local function Read()
	pending = false
	if refresh.pending and not ns.UsingPreview() then
		return -- keep showing the list until the refresh answers
	end
	if ns.Motion.Busy() then
		readAfterSwipe = true -- the rows going out still show the old list
		return
	end
	local previous = refresh.merge and refresh.snapshot or nil
	refresh.merge, refresh.snapshot = false, nil
	if not ns.UsingPreview() then
		local selected = previous and ns.Table.SelectedKey()
		ns.Listings.Read(previous, narrowTo)
		if previous then
			return ns.Motion.Show(previous, selected)
		end
	end
	if tbl then
		tbl:Refresh()
	end
end

-- Result updates come in bursts; read once per burst.
function ReadSoon()
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
	-- Your own row stays only while Forever has an active listing for you.
	hasListing = function()
		if ns.UsingPreview() then
			return ns.state.myListing ~= nil
		end
		if not (C_LFGList and C_LFGList.HasActiveEntryInfo) then
			return false
		end
		local active = C_LFGList.HasActiveEntryInfo()
		return not (issecretvalue and issecretvalue(active)) and active == true
	end,
	searching = function()
		-- A Dynamic refresh shows no spinner: the list stays until its answer.
		if ns.UsingPreview() then
			return ns.state.previewSearching == true
		end
		return LFGBrowseFrame and LFGBrowseFrame.searching == true and not refresh.pending
	end,
	-- A Dynamic refresh that failed keeps the list as it was.
	failed = function()
		return not ns.UsingPreview() and LFGBrowseFrame and LFGBrowseFrame.searchFailed == true and not refresh.failed
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

local function UncheckStock()
	for _, key in ipairs({ "ListingTab", "BrowsingTab", "WhoListingTab" }) do
		local tab = LFGParentFrame[key]
		if tab and tab.SetChecked then
			tab:SetChecked(false)
		end
	end
end

local function ShowMessages()
	for _, f in ipairs({ LFGListingFrame, LFGBrowseFrame, LFGWhoListFrame }) do
		f:Hide()
	end
	UncheckStock()
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
	refreshMessages = ns.Messages.BuildPanel(messages)
	messages:Hide()

	local below = LFGParentFrame.WhoListingTab or LFGParentFrame.BrowsingTab
	messagesTab = W.Create("Frame", LFGParentFrame, "LargeSideTabButtonTemplate")
	messagesTab:SetPoint("TOPLEFT", below, "BOTTOMLEFT", 0, -2)
	if messagesTab.Icon then
		messagesTab.Icon:SetTexture("Interface\\Icons\\INV_Letter_15")
		if messagesTab.SetFillToInterior then
			messagesTab:SetFillToInterior(true)
		elseif messagesTab.UpdateIconInterior then
			messagesTab.fillToInterior = true -- our own tab; read by its first SetChecked
		else
			messagesTab.Icon:SetSize(30, 30)
			messagesTab.Icon:SetTexCoord(0.03125, 0.96875, 0.03125, 0.96875)
		end
	end
	if messagesTab.SetChecked then
		messagesTab:SetChecked(false)
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
	if type(LFGParentFrame.UpdateTabs) == "function" then
		hooksecurefunc(LFGParentFrame, "UpdateTabs", function()
			if messages and messages:IsShown() then
				UncheckStock()
			end
		end)
	end
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
	source.refreshAnchor = f.RefreshButton -- read only; the search box sits right of it
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
		hooksecurefunc("LFGBrowse_DoSearch", OnSearch)
	end
	local events = CreateFrame("Frame")
	for _, event in ipairs(EVENTS) do
		events:RegisterEvent(event)
	end
	events:SetScript("OnEvent", function(_, event)
		local answer = event == "LFG_LIST_SEARCH_RESULTS_RECEIVED" or event == "LFG_LIST_SEARCH_FAILED"
		if answer then
			-- Blizzard is no longer searching. The list now shows the filter that was searched
			-- (a failed new search shows none; a failed refresh keeps its list).
			searchOut = false
			if event == "LFG_LIST_SEARCH_RESULTS_RECEIVED" then
				if ns.UsingPreview() then
					narrowTo = nil
					shownFilter = issued
				else
					narrowTo = NarrowSet(issuedCategory, issuedSet)
					shownFilter = narrowTo and FilterKey() or issued
				end
			elseif not refresh.pending then
				shownFilter = nil
				narrowTo = nil
			end
		end
		if answer and refresh.pending then
			refresh.pending = false
			if event == "LFG_LIST_SEARCH_FAILED" then
				refresh.failed, refresh.snapshot = true, nil -- keep the list as it was
				return
			end
			refresh.merge = true
		elseif answer and not ns.UsingPreview() then
			ns.Table.ClearSelection()
		end
		ReadSoon()
	end)
	shownFilter = FilterKey()
	ns.Motion.OnUpdated(AfterMotion)
	ns.Settings.OnChange("dynamicRefresh", function(on)
		if not on and refresh.pending then
			-- Off while a refresh is out: its answer is a plain read, and the spinner shows.
			refresh.pending, refresh.snapshot, refresh.merge = false, nil, false
			ns.Listings.ClearDropped()
			ns.Table.RefreshAll()
		end
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

-- Asked while the game's Settings panel was open: the Messages tab opens once it hides.
-- The panel (HIGH strata, no UIPanelWindows entry) would cover the finder, and nothing
-- here closes it (the Settings button does, through its own Close: SP.CloseThen); a
-- one-time HookScript is all that's added to it.
local messagesAfterSettings, settingsHooked = false, false

local function OpenAfterSettings()
	messagesAfterSettings = true
	if not settingsHooked then
		settingsHooked = true
		SettingsPanel:HookScript("OnHide", function()
			if not messagesAfterSettings then
				return
			end
			messagesAfterSettings = false
			-- next frame: out of the panel's own hide
			C_Timer.After(0, IP.OpenMessages)
		end)
	end
	ns.Print("the Messages tab opens when you close the Settings.")
end

--- Opens Forever's group finder on the given side tab (1 Listing, 2 Browse), through the
--- game's own LFGVanilla_ShowFrame. Out of combat only; true when it was asked of the game.
function IP.ShowFinder(tab)
	if InCombatLockdown() then
		ns.Print("can't open the group finder in combat.")
		return false
	end
	if
		not LFGParentFrame
		or not (type(LFGVanilla_ShowFrame) == "function" or type(LFGVanilla_ToggleFrame) == "function")
	then
		ns.Print("the group finder isn't ready yet.")
		return false
	end
	if type(LFGVanilla_ShowFrame) == "function" then
		LFGVanilla_ShowFrame(tab)
	elseif not LFGParentFrame:IsShown() then
		LFGVanilla_ToggleFrame(tab)
	end
	return true
end

--- Opens the group finder on our Messages tab (the stand-in's only where the game has no
--- group finder API). Out of combat only; with the game's Settings panel open, it opens
--- once that panel closes.
function IP.OpenMessages()
	if not ns.Listings.HasAPI() then
		ns.state.preview = true
		return ns.UI.Show("messages")
	end
	if InCombatLockdown() then
		return ns.Print("can't open the group finder in combat.")
	end
	if not (tbl and messages) then
		return ns.Print("the group finder isn't ready yet.")
	end
	if SettingsPanel and SettingsPanel.IsShown and SettingsPanel:IsShown() and SettingsPanel.HookScript then
		return OpenAfterSettings()
	end
	if not LFGParentFrame:IsShown() and not IP.ShowFinder(BROWSE_TAB) then
		return
	end
	-- last: the stock tabs' OnShow hooks hide Messages
	ShowMessages()
end
