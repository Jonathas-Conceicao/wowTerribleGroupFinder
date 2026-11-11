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
-- Presets that were once the default; a saved copy of one becomes the new default (once).
local PREVIOUS = {
	invite = { "Hi {name}! We're forming a group for {activity}, want to join?" },
	request = {
		"Hi {name}! Level {level} {class} here ({role}), could I join you for {activity}?",
		-- The gear score era text; its old key is spelled in two pieces, as it is no key any more.
		"Hi {name}! Level {level} {class} here ({role}, GS {g" .. "s}), could I join you for {activity}?",
	},
}
local VERSION = 2
local MAX = 255

local ROLE_NAMES = { tank = "Tank", healer = "Healer", dps = "Damage" }

local db

function M.Init(saved)
	saved.messages = saved.messages or {}
	db = saved.messages
	local migrate = (db.version or 1) < VERSION
	for _, kind in ipairs(M.KINDS) do
		db[kind] = db[kind] or {}
		if type(db[kind].text) ~= "string" then
			db[kind].text = M.DEFAULTS[kind]
		elseif migrate then
			for _, old in ipairs(PREVIOUS[kind]) do
				if db[kind].text == old then
					db[kind].text = M.DEFAULTS[kind]
				end
			end
		end
		db[kind].auto = db[kind].auto == true
	end
	db.invite.autoInvite = db.invite.autoInvite == true and db.invite.auto
	db.request.autoInvite = nil
	db.version = VERSION
end

--- text, Auto-send, Auto-invite (only the invite preset has it, and only with Auto-send on).
function M.Get(kind)
	local d = db[kind]
	if kind == "invite" then
		return d.text, d.auto, d.autoInvite == true and d.auto
	end
	return d.text, d.auto, false
end

function M.Set(kind, text, auto, autoInvite)
	local d = db[kind]
	if text ~= nil then
		d.text = text:sub(1, MAX)
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
	return out:sub(1, MAX)
end

-- Which preset a listing takes: solo players get the invite one, groups the request one.
local function KindFor(l)
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
	local invite = kind == "invite" and autoInvite and ns.CanInvite()
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
		if C_ChatInfo and C_ChatInfo.SendChatMessage then
			C_ChatInfo.SendChatMessage(text, "WHISPER", nil, target)
		else
			SendChatMessage(text, "WHISPER", nil, target)
		end
		ns.state.messaged[l.id] = true
		if invite then
			C_PartyInfo.InviteUnit(target)
			ns.state.invited[l.id] = true
		end
		M.StartLock(l.id, from or "row")
		return true
	end
	if ChatFrameUtil and ChatFrameUtil.SendTellWithMessage then
		ChatFrameUtil.SendTellWithMessage(target, text)
	else
		ns.Print(string.format("would open a whisper to %s with: %s", target, text))
	end
	return false
end

-------------------------------------------------------------------------------
--  The Messages tab: both presets, each with Auto-send and Reset
-------------------------------------------------------------------------------
local W

local SECTIONS = {
	{ kind = "invite", title = "Inviting a solo player", help = "The message button on a solo player's row." },
	{ kind = "request", title = "Asking a group for an invite", help = "The message button on a group's row." },
}

--- Builds the tab's content in `parent` (the space below the title); returns a refresh.
function M.BuildPanel(parent)
	W = ns.W
	local refreshers = {}
	local y = -4
	local intro = W.Text(parent, "GameFontHighlightSmall", 11)
	intro:SetPoint("TOPLEFT", 4, y)
	intro:SetPoint("RIGHT", -4, 0)
	intro:SetWordWrap(true)
	intro:SetText(
		"The message button on each row whispers that player or group leader. With Auto-send off it opens the whisper with the message for you to send with Enter; on, it sends right away."
	)
	y = y - 40
	for _, s in ipairs(SECTIONS) do
		local kind = s.kind
		local title = W.Text(parent, "GameFontNormal", 13)
		title:SetPoint("TOPLEFT", 4, y)
		title:SetText(s.title)
		local help = W.Text(parent, "GameFontDisableSmall", 10)
		help:SetPoint("LEFT", title, "RIGHT", 8, 0)
		help:SetText(s.help)

		local box = W.EditBox(parent, 400)
		box:SetPoint("TOPLEFT", 10, y - 20)
		box:SetPoint("RIGHT", -10, 0)
		box:SetMaxLetters(MAX)
		local example = W.Text(parent, "GameFontDisableSmall", 10)
		example:SetPoint("TOPLEFT", 6, y - 46)
		example:SetPoint("RIGHT", -6, 0)
		example:SetWordWrap(true)

		local auto = W.Check(parent, "Auto-send", function(b)
			M.Set(kind, nil, b:GetChecked() and true or false)
		end)
		auto:SetPoint("TOPLEFT", 4, y - 76)
		W.Tooltip(
			auto,
			"Auto-send",
			"On: the message button sends the message at once. Off: it opens the whisper and you press Enter."
		)
		local reset = W.Button(parent, "Default", 80, 22, function()
			M.Reset(kind)
			refreshers[kind]()
		end)
		reset:SetPoint("TOPRIGHT", -10, y - 76)

		local function Example()
			local sample = ns.Preview.listings[kind == "invite" and #ns.Preview.listings or 1]
			example:SetText("e.g. " .. M.Format(kind, sample, box:GetText()))
		end
		box:HookScript("OnTextChanged", function(b, user)
			if user then
				M.Set(kind, b:GetText())
			end
			Example()
		end)
		refreshers[kind] = function()
			local text, on = M.Get(kind)
			box:SetText(text)
			box:SetCursorPosition(0)
			auto:SetChecked(on)
			Example()
		end
		y = y - 112
	end
	return function()
		for _, kind in ipairs(M.KINDS) do
			refreshers[kind]()
		end
	end
end
