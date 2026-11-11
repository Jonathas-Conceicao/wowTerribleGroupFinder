-------------------------------------------------------------------------------
--  Messages.lua -- the whisper presets (ns.Messages). Forever's finder has listings only,
--  so reaching someone is a whisper: to a solo player, "invite" (you'd like them in your
--  group); to a group's leader, "request" (you'd like an invite). Each has a text with
--  placeholders and an Auto-send box, off by default: off, the message button opens the
--  whisper box with the text in it and you press Enter; on, it is sent at once.
-------------------------------------------------------------------------------
local _, ns = ...

local M = {}
ns.Messages = M

M.KINDS = { "invite", "request" }
M.DEFAULTS = {
	invite = "Hi {name}! We're forming a group for {activity}, want to join?",
	request = "Hi {name}! Level {level} {class} here ({role}), could I join you for {activity}?",
}
M.TOKENS = "{name} {activity} {role} {class} {level}" .. (ns.GEAR_SCORE and " {gs}" or "")
-- The request preset before gear score was switched off; a saved copy of it is replaced.
local OLD_REQUEST = "Hi {name}! Level {level} {class} here ({role}, GS {gs}), could I join you for {activity}?"
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
	if not ns.GEAR_SCORE and db.request.text == OLD_REQUEST then
		db.request.text = M.DEFAULTS.request
	end
end

function M.Get(kind)
	return db[kind].text, db[kind].auto
end

function M.Set(kind, text, auto)
	if text ~= nil then
		db[kind].text = text:sub(1, MAX)
	end
	if auto ~= nil then
		db[kind].auto = auto
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

local function MyGS()
	local gs = ns.Me().gs
	return gs and string.format("%.1f", gs) or "?"
end

--- The text for a listing: the preset with its placeholders filled in.
function M.Format(kind, l, text)
	local values = {
		name = l and l.leader.name or "Name",
		activity = l and l.acts[1] and l.acts[1].name or "the dungeon",
		role = MyRoleText(),
		class = ns.W.ClassName(ns.PlayerClass()),
		level = tostring(ns.PlayerLevel()),
	}
	if ns.GEAR_SCORE then
		values.gs = MyGS()
	end
	return ((text or db[kind].text):gsub("{(%a+)}", function(key)
		return values[key]
	end))
end

-- Which preset a listing takes: solo players get the invite one, groups the request one.
local function KindFor(l)
	return l.solo and "invite" or "request"
end

--- The message button (runs from a click): opens the whisper with the text, or sends it.
function M.Send(l, preview)
	local kind = KindFor(l)
	local text = M.Format(kind, l)
	local target = l.leader.fullName or l.leader.name
	local _, auto = M.Get(kind)
	if auto then
		ns.state.messaged[l.id] = true
		if preview then
			return ns.Print(string.format("preview: whispered %s: %s", target, text))
		end
		if C_ChatInfo and C_ChatInfo.SendChatMessage then
			C_ChatInfo.SendChatMessage(text, "WHISPER", nil, target)
		else
			SendChatMessage(text, "WHISPER", nil, target)
		end
		return
	end
	if ChatFrameUtil and ChatFrameUtil.SendTellWithMessage then
		ChatFrameUtil.SendTellWithMessage(target, text)
	else
		ns.Print(string.format("would open a whisper to %s with: %s", target, text))
	end
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
	local tokens = W.Text(parent, "GameFontDisableSmall", 10)
	tokens:SetPoint("TOPLEFT", 4, y)
	tokens:SetPoint("RIGHT", -4, 0)
	tokens:SetWordWrap(true)
	tokens:SetText(
		"Placeholders: "
			.. M.TOKENS
			.. ". {name} is who you whisper, {activity} their listing's; the rest are you (your roles, class, level"
			.. (ns.GEAR_SCORE and ", gear score" or "")
			.. ")."
	)
	return function()
		for _, kind in ipairs(M.KINDS) do
			refreshers[kind]()
		end
	end
end
