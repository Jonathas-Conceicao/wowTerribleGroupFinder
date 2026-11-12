-------------------------------------------------------------------------------
--  Messages.lua -- the whisper presets (ns.Messages). Forever's finder has listings only,
--  so reaching someone is a whisper: to a solo player, "invite" (you'd like them in your
--  group); to a group's leader, "request" (you'd like an invite). Each has a text with
--  keys ({name}, {activity}, ...) and an Auto-send box, off by default: off, the message
--  button opens the whisper box with the text in it and you press Enter; on, it is sent at
--  once. A solo player's preset also has Auto-invite: after the whisper, invite them.
--  After an auto-send the contact buttons lock for a second.
-------------------------------------------------------------------------------
local _, ns = ...

local M = {}
ns.Messages = M

M.KINDS = { "invite", "request" }
M.ADDON_KEY = "[TGF]"
M.DEFAULTS = {
	invite = "{addon} Group for {activity} with {players} players",
	request = "{addon} Level {level} {class}, for {activity}",
}
-- The keys a preset may hold, in the order the Messages tab shows them.
M.KEYS = {
	{
		key = "{addon}",
		label = "[TGF]",
		tip = "Marks the message as sent with TerribleGroupFinder. Always placed first, once.",
	},
	{ key = "{name}", tip = "The player you whisper: the solo player or the group's leader." },
	{ key = "{activity}", tip = "The first activity of their listing." },
	{ key = "{players}", tip = "Your current group size, counting you." },
	{ key = "{class}", tip = "Your class." },
	{ key = "{level}", tip = "Your level." },
	{ key = "{role}", tip = "The roles you can play, for example Tank/Healer." },
}
local MAX = 255

local ROLE_NAMES = { tank = "Tank", healer = "Healer", dps = "Damage" }

local db

function M.Init(saved)
	saved.messages = saved.messages or {}
	db = saved.messages
	for _, kind in ipairs(M.KINDS) do
		db[kind] = db[kind] or {}
		if type(db[kind].text) ~= "string" then
			db[kind].text = M.DEFAULTS[kind]
		end
		db[kind].auto = db[kind].auto == true
	end
	db.invite.autoInvite = db.invite.autoInvite == true and db.invite.auto
	db.request.autoInvite = nil
end

--- text, Auto-send, Auto-invite (only the invite preset has it, and only with Auto-send on).
function M.Get(kind)
	local d = db[kind]
	if kind == "invite" then
		return d.text, d.auto, d.autoInvite == true and d.auto
	end
	return d.text, d.auto, false
end

--- Cuts to MAX bytes without splitting a multi-byte UTF-8 character.
function M.Clip(s)
	if #s <= MAX then
		return s
	end
	local cut = MAX
	-- Back off while the first dropped byte is a continuation byte (0x80-0xBF).
	while cut > 0 do
		local b = s:byte(cut + 1)
		if b and b >= 0x80 and b <= 0xBF then
			cut = cut - 1
		else
			break
		end
	end
	return s:sub(1, cut)
end

function M.Set(kind, text, auto, autoInvite)
	local d = db[kind]
	if text ~= nil then
		d.text = M.Clip(text)
	end
	if auto ~= nil then
		d.auto = auto
		if auto == false and kind == "invite" then
			d.autoInvite = false
		end
	end
	if autoInvite ~= nil and kind == "invite" then
		d.autoInvite = autoInvite == true and d.auto == true
	end
end

function M.Reset(kind)
	db[kind].text = M.DEFAULTS[kind]
end

local function MyRoleText()
	local roles, out = ns.MyRoles(), {}
	for _, key in ipairs({ "tank", "healer", "dps" }) do
		if roles[key] then
			out[#out + 1] = ROLE_NAMES[key]
		end
	end
	return #out > 0 and table.concat(out, "/") or "any role"
end

--- Puts the addon key once at the very start: every {addon} and literal [TGF] is removed
--- and, if there was one, a single {addon} leads. No key at all leaves the text alone.
function M.Normalize(text)
	local count = 0
	local rest, n = text:gsub("%s*{addon}%s*", " ")
	count = count + n
	rest, n = rest:gsub("%s*%[TGF%]%s*", " ")
	count = count + n
	if count == 0 then
		return text
	end
	rest = (rest:gsub("^%s+", ""))
	rest = (rest:gsub("%s+$", ""))
	if rest == "" then
		return "{addon}"
	end
	return "{addon} " .. rest
end

--- The text for a listing: the preset with its keys filled in.
function M.Format(kind, l, text)
	local values = {
		addon = M.ADDON_KEY,
		name = l and l.leader.name or "Name",
		activity = l and l.acts[1] and l.acts[1].name or "the dungeon",
		players = tostring(ns.GroupSize()),
		role = MyRoleText(),
		class = ns.W.ClassName(ns.PlayerClass()),
		level = tostring(ns.PlayerLevel()),
	}
	local raw = M.Normalize(text or db[kind].text)
	local out = raw:gsub("{(%a+)}", function(key)
		return values[key]
	end)
	return M.Clip(out)
end

-- Which preset a whisper takes: in a group you always offer yours (invite); on your own you
-- ask a group for a spot (request) and offer a solo player to group up (invite).
local function KindFor(l)
	if ns.GroupSize() > 1 then
		return "invite"
	end
	return l.solo and "invite" or "request"
end

-------------------------------------------------------------------------------
--  The contact lock: for a second after an auto-send the contact buttons do nothing, so
--  no one gets a whisper or an invite twice. The deadline is checked against GetTime, so it
--  holds when the timer runs late; a generation number stops an old timer from releasing a
--  newer lock.
-------------------------------------------------------------------------------
local lock = { deadline = 0, id = nil, source = nil, gen = 0 }

function M.Locked()
	return GetTime() < lock.deadline
end

function M.LockID()
	return M.Locked() and lock.id or nil
end

function M.LockSource()
	return M.Locked() and lock.source or nil
end

function M.StartLock(id, source)
	lock.gen = lock.gen + 1
	local gen = lock.gen
	lock.deadline = GetTime() + 1
	lock.id, lock.source = id, source
	C_Timer.After(1, function()
		if lock.gen ~= gen then
			return
		end
		lock.deadline, lock.id, lock.source = 0, nil, nil
		if ns.Table and ns.Table.RefreshAll then
			ns.Table.RefreshAll()
		end
	end)
end

--- The message button (runs from a click): opens the whisper with the text, or sends it
--- (and, for a solo player with Auto-invite, invites them). Returns true after a real
--- auto-send, which starts the lock.
function M.Send(l, preview, from)
	if M.Locked() then
		return false
	end
	local kind = KindFor(l)
	local text = M.Format(kind, l)
	-- Forever lists only your own mega-realm: whisper by plain character name.
	local target = l.leader.name
	local _, auto, autoInvite = M.Get(kind)
	-- Auto-invite only reaches solo players: a group's leader is already in a group.
	local invite = kind == "invite" and l.solo and autoInvite and ns.CanInvite()
	if auto and preview then
		ns.state.messaged[l.id] = true
		ns.Print(string.format("preview: whispered %s: %s", target, text))
		if invite then
			ns.state.invited[l.id] = true
			ns.Print(string.format("preview: would invite %s (C_PartyInfo.InviteUnit).", target))
		end
		M.StartLock(l.id, from or "row")
		return true
	end
	-- Never send addon-side during chat messaging lockdown: fall back to prefilling the box.
	local locked = C_ChatInfo and C_ChatInfo.InChatMessagingLockdown and C_ChatInfo.InChatMessagingLockdown()
	if auto and not locked then
		-- Marked only when the call returned without error; a send the server later
		-- rejects (offline, throttled) still counts as attempted.
		local ok = pcall(function()
			if C_ChatInfo and C_ChatInfo.SendChatMessage then
				C_ChatInfo.SendChatMessage(text, "WHISPER", nil, target)
			else
				SendChatMessage(text, "WHISPER", nil, target)
			end
		end)
		if not ok then
			ns.Print(string.format("could not send the whisper to %s.", target))
			return false
		end
		ns.state.messaged[l.id] = true
		if invite and C_PartyInfo and C_PartyInfo.InviteUnit and pcall(C_PartyInfo.InviteUnit, target) then
			ns.state.invited[l.id] = true
		end
		M.StartLock(l.id, from or "row")
		return true
	end
	if preview then
		ns.Print(string.format("preview: would open a whisper to %s with: %s", target, text))
	elseif ChatFrameUtil and ChatFrameUtil.SendTellWithMessage then
		ChatFrameUtil.SendTellWithMessage(target, text)
	else
		ns.Print(string.format("would open a whisper to %s with: %s", target, text))
	end
	return false
end

-------------------------------------------------------------------------------
--  The Messages tab: both presets, each with Auto-send, key buttons and Default. One
--  builder for the game's fourth side tab and the preview stand-in; the frame layers are
--  those of Forever's Who tab (stone band, art, inset border, one divider).
-------------------------------------------------------------------------------
local W

local SECTIONS = {
	{
		kind = "invite",
		title = "Inviting a player",
		help = "Used by Whisper while in a group, or on a solo player's row.",
		y = 0,
	},
	{
		kind = "request",
		title = "Asking a group for an invite",
		help = "Used by Whisper on a group's row while on your own.",
		y = -220,
	},
}

local BOX_WIDTH, BOX_HEIGHT = 410, 56

local function TemplateKnown(name)
	return C_XMLUtil ~= nil and C_XMLUtil.GetTemplateInfo ~= nil and C_XMLUtil.GetTemplateInfo(name) ~= nil
end

--- The frame layers of the Who tab, on `panel`. Atlases the client lacks get flat colours
--- (art, band) or are skipped (border, divider).
local function BuildLayers(panel)
	local art = panel:CreateTexture(nil, "BACKGROUND", nil, 1)
	art:SetPoint("TOPLEFT", 4, -80)
	art:SetPoint("BOTTOMRIGHT", -4, 3)
	W.Atlas(art, "groupfinder-background", 0.05, 0.05, 0.05, 0.8)
	local band = panel:CreateTexture(nil, "BACKGROUND", nil, 2)
	band:SetPoint("TOPLEFT", 2, -21)
	band:SetPoint("BOTTOMRIGHT", art, "TOPRIGHT", 0, -7)
	W.Atlas(band, "groupfinder-Stat-StoneBG", 0.12, 0.1, 0.08, 1)
	if W.HasAtlas("common-insideframe") then
		local border = panel:CreateTexture(nil, "BORDER")
		border:SetPoint("TOPLEFT", 3, -78)
		border:SetPoint("BOTTOMRIGHT", -4, 3)
		border:SetAtlas("common-insideframe")
	end
	if W.HasAtlas("groupfinder-ScrollLine") then
		local line = panel:CreateTexture(nil, "OVERLAY")
		line:SetPoint("TOPLEFT", 4, -300)
		line:SetPoint("TOPRIGHT", -4, -300)
		line:SetAtlas("groupfinder-ScrollLine")
		local info = C_Texture.GetAtlasInfo("groupfinder-ScrollLine")
		line:SetHeight(info and info.height or 3)
	end
end

--- A multi-line preset box (InputScrollFrameTemplate, plain Lua, not the Listing tab's
--- secure one); a single-line edit box where the template is missing. Returns box, edit.
local function PresetBox(parent)
	if TemplateKnown("InputScrollFrameTemplate") then
		local box = W.Create("ScrollFrame", parent, "InputScrollFrameTemplate")
		local edit = box.EditBox
		if edit then
			-- The template's OnLoad ran with width 0 and no letter limit: size, width, limit.
			box:SetSize(BOX_WIDTH, BOX_HEIGHT)
			edit:SetWidth(BOX_WIDTH - 18)
			edit:SetMaxLetters(255)
			box:SetPoint("TOPLEFT", 6, -32)
			edit:SetScript("OnEnterPressed", function(e)
				e:ClearFocus()
			end)
			return box, edit
		end
		box:Hide()
		box:SetParent(nil)
	end
	local edit = W.EditBox(parent, BOX_WIDTH)
	edit:SetPoint("TOPLEFT", 6, -32)
	edit:SetMaxLetters(255)
	return edit, edit
end

--- Builds the tab into `panel`; returns a refresh (texts, checkboxes, examples).
function M.BuildPanel(panel)
	W = ns.W
	BuildLayers(panel)
	local content = CreateFrame("Frame", nil, panel)
	content:SetPoint("TOPLEFT", 18, -88)
	content:SetPoint("BOTTOMRIGHT", -18, 16)
	panel.tgfBlocks = {}
	local refreshers = {}

	for _, s in ipairs(SECTIONS) do
		local kind = s.kind
		local block = CreateFrame("Frame", nil, content)
		block:SetSize(422, 204)
		block:SetPoint("TOPLEFT", 0, s.y)
		local handles = { keys = {} }
		panel.tgfBlocks[kind] = handles

		local title = W.Text(block, "GameFontNormal", 13)
		title:SetPoint("TOPLEFT", 0, 0)
		title:SetText(s.title)
		local help = W.Text(block, "GameFontDisableSmall", 10)
		-- On its own line under the title, cut to the block: never past the panel.
		help:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -2)
		help:SetPoint("RIGHT", block, "RIGHT", -4, 0)
		help:SetWordWrap(false)
		help:SetMaxLines(1)
		help:SetText(s.help)

		local box, edit = PresetBox(block)
		handles.box, handles.edit = box, edit

		local example = W.Text(block, "GameFontDisableSmall", 10)
		example:SetPoint("TOPLEFT", 4, -180)
		example:SetPoint("RIGHT", -4, 0)
		example:SetWordWrap(true)
		example:SetMaxLines(2)
		handles.example = example
		local function Sample()
			for _, l in ipairs(ns.Preview.listings) do
				if (kind == "invite") == (l.solo == true) then
					return l
				end
			end
		end
		local function Example()
			local sample = Sample()
			example:SetText("e.g. " .. M.Format(kind, sample, edit:GetText()))
		end

		edit:HookScript("OnTextChanged", function(e, user)
			local text = e:GetText()
			if text:find("[\r\n]") then
				local pos = e:GetCursorPosition()
				local prefix = text:sub(1, pos)
				local ascii = not prefix:find("[\128-\255]")
				local before = (prefix:gsub("[\r\n]+", " "))
				text = (text:gsub("[\r\n]+", " "))
				e:SetText(text)
				if ascii then
					e:SetCursorPosition(#before)
				end
				if user then
					M.Set(kind, text)
				end
				return
			end
			if user then
				M.Set(kind, text)
			end
			Example()
		end)
		edit:HookScript("OnEditFocusLost", function(e)
			local text = M.Normalize(e:GetText())
			if text ~= e:GetText() then
				e:SetText(text)
			end
			M.Set(kind, text)
			local stored = M.Get(kind)
			if stored ~= e:GetText() then
				e:SetText(stored)
			end
			Example()
		end)

		-- Key buttons: two rows (4 + 3); wraps once at most.
		local x, rowY, wrapped = 0, -98, false
		for i, k in ipairs(M.KEYS) do
			local label = k.label or k.key
			local b = W.Button(block, label, 60, 22, function()
				if k.key == "{addon}" then
					local text = edit:GetText()
					if text:sub(1, #k.key) ~= k.key then
						edit:SetText(M.Normalize(k.key .. " " .. text))
						edit:SetCursorPosition(math.min(#k.key + 1, #edit:GetText()))
					end
				else
					edit:Insert(k.key)
				end
				edit:SetFocus()
				M.Set(kind, edit:GetText())
				local stored = M.Get(kind)
				if stored ~= edit:GetText() then
					edit:SetText(stored)
				end
				Example()
			end)
			b:SetNormalFontObject("GameFontNormalSmall")
			b:SetDisabledFontObject("GameFontDisableSmall")
			b:SetText(label)
			local fs = b:GetFontString()
			b:SetWidth((fs and fs:GetStringWidth() or 0) + 24)
			if not wrapped and (i == 5 or (x > 0 and x + b:GetWidth() > BOX_WIDTH)) then
				x, rowY, wrapped = 0, rowY - 24, true
			end
			b:SetPoint("TOPLEFT", x, rowY)
			x = x + b:GetWidth() + 4
			W.Tooltip(b, label, k.tip, { gold = true })
			handles.keys[#handles.keys + 1] = b
		end

		-- Auto-send, and (solo players only) Auto-invite, which needs Auto-send.
		local auto, autoInvite, SyncAutoInvite
		auto = W.Check(block, "Auto-send", function(b)
			M.Set(kind, nil, b:GetChecked() and true or false)
			if SyncAutoInvite then
				SyncAutoInvite()
			end
		end)
		auto:SetPoint("TOPLEFT", 0, -150)
		W.Tooltip(
			auto,
			"Auto-send",
			"On: the Whisper button sends the message at once. Off: it opens the whisper with the message and you press Enter. After an automatic send, the contact buttons rest for 1 second.",
			{ gold = true }
		)
		handles.auto = auto

		if kind == "invite" then
			autoInvite = W.Check(block, "Auto-invite", function(b)
				M.Set("invite", nil, nil, b:GetChecked() and true or false)
			end)
			autoInvite:SetPoint("LEFT", auto.Label, "RIGHT", 16, 0)
			if autoInvite.SetMotionScriptsWhileDisabled then
				autoInvite:SetMotionScriptsWhileDisabled(true)
			end
			W.Tooltip(
				autoInvite,
				"Auto-invite",
				"Also invites the player right after the message is sent. Works only when you can invite.",
				{
					gold = true,
					note = function(self)
						if not self:IsEnabled() then
							return "Turn on Auto-send first."
						end
					end,
				}
			)
			local normalFont = autoInvite.Label:GetFontObject() or "GameFontHighlightSmall"
			function SyncAutoInvite()
				local _, on = M.Get("invite")
				if on then
					autoInvite:Enable()
					autoInvite.Label:SetFontObject(normalFont)
					autoInvite:SetChecked(select(3, M.Get("invite")) and true or false)
				else
					autoInvite:SetChecked(false)
					M.Set("invite", nil, nil, false)
					autoInvite:Disable()
					autoInvite.Label:SetFontObject("GameFontDisableSmall")
				end
			end
			handles.autoInvite = autoInvite
		end

		local function ShowText()
			edit:SetText((M.Get(kind)))
			edit:SetCursorPosition(0)
			Example()
		end
		local reset = W.Button(block, "Default", 80, 22, function()
			M.Reset(kind)
			ShowText()
		end)
		reset:SetPoint("TOPRIGHT", -6, -152)
		W.Tooltip(reset, "Default", "Restores the standard message.", { gold = true })
		handles.reset = reset

		refreshers[kind] = function()
			local _, on = M.Get(kind)
			ShowText()
			auto:SetChecked(on)
			if SyncAutoInvite then
				SyncAutoInvite()
			end
		end
	end

	local function Refresh()
		for _, kind in ipairs(M.KINDS) do
			refreshers[kind]()
		end
	end
	Refresh()
	return Refresh
end
