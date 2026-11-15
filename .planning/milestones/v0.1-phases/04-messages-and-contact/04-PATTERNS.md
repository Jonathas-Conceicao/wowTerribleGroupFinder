# Phase 4: Messages and Contact - Pattern Map

**Mapped:** 2026-11-11
**Files analyzed:** 8 (6 repo files modified, 2 external harness files modified; no new repo files, so the TOC is unchanged)
**Analogs found:** 8 / 8 (every change extends or replaces an existing function; the "analog" is the code being replaced or its nearest sibling)

All paths relative to `C:\Users\jonat\Repositories\TerribleGroupFinder` unless absolute. Line numbers are from the working tree at mapping time (before Phase 4 edits). Smoke harness dir (outside repo): `C:\Users\jonat\AppData\Local\Temp\claude\3a677a53f55271b6\8039163f-18e8-4930-88a2-d8efcca63b25\scratchpad\smoke\` (`harness.lua` stubs and asserts, `tail.lua` assertions, `run.js` loads TOC files via fengari; flags `--gs`, `--attach`).

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|-------------------|------|-----------|----------------|---------------|
| `Messages.lua` (keys, `Normalize`, `Format`, `Init` migration, `Get/Set`, `Send` + invite, lock, `BuildPanel`) | service + component builder | request-response (click -> send) + CRUD (saved presets) | itself: `Init` (27-40), `Format` (75-89), `Send` (97-123), `BuildPanel` (136-216) | exact |
| `Core.lua` (`ns.GroupSize()`, comment drops `{gs}`) | utility | transform | itself: `ns.CanInvite` (83-88), `ns.Party` (126-) | exact |
| `UI/Widgets.lua` (`W.SetPressed`, tooltip gold-title option, `W.Check` disabled-label helper) | component helper | request-response | `W.Button` (290-313), `W.Check` (346-370), `Tooltip` (266-287) | exact |
| `UI/Table.lua` (`Instance:Message` + lock guard, `Instance:Invite` guard, `FillRow` / `RefreshButtons` pressed look) | component | event-driven + request-response | itself: 661-667, 694-706, 864-866, 1117-1119, 1312-1317, 1581-1588 | exact |
| `UI/InPlace.lua` (`AddMessagesTab`: `SetChecked(false)`, `SetFillToInterior`, `UpdateTabs` hook, tooltip) | provider (hook / wiring) | event-driven | itself: `AddMessagesTab` (130-173), `ShowMessages` (103-118); `StayHidden` (89-97) for the `hooksecurefunc` style | exact |
| `UI/MainFrame.lua` (`BuildMessages` -> same layers as game) | component (preview stand-in) | request-response | itself: `BuildMessages` (353-366) | exact |
| Smoke harness `harness.lua` | test (stubs) | request-response | itself: `GetTime`/`C_Timer`/`C_PartyInfo`/`C_ChatInfo` stubs (249, 273, 287, 294-295), seed `OLD_REQ`/`NEW_REQ` (348-351) | exact |
| Smoke harness `tail.lua` | test (asserts) | request-response | itself: no-GS block (82-106), `check`/`probe` (2-6) | exact |

## Pattern Assignments

### `Messages.lua` (service, request-response + CRUD)

**Analog:** itself. Keep the module shape (`local _, ns = ...`, `M`, `local db`, `local W` set inside `BuildPanel`).

**Defaults, tokens and the one-time reset to replace** (lines 13-21, 37-39):
```lua
M.DEFAULTS = {
	invite = "Hi {name}! We're forming a group for {activity}, want to join?",
	request = "Hi {name}! Level {level} {class} here ({role}), could I join you for {activity}?",
}
M.TOKENS = "{name} {activity} {role} {class} {level}" .. (ns.GEAR_SCORE and " {gs}" or "")
local OLD_REQUEST = "Hi {name}! Level {level} {class} here ({role}, GS {gs}), could I join you for {activity}?"
...
	if not ns.GEAR_SCORE and db.request.text == OLD_REQUEST then
		db.request.text = M.DEFAULTS.request
	end
```
Phase 4: new defaults per D-02 (`{addon} Level {level} {class}, for {activity}` / `{addon} Group for {activity} with {players} players`); `M.TOKENS` becomes an ordered key list (`M.KEYS`, `{addon}` first, label `[TGF]`) that `BuildPanel` and the tooltips iterate; the compare-and-replace becomes a table of previous defaults per kind plus `db.version` (suggested: `saved.messages.version`, RESEARCH "Runtime State Inventory"). Previous defaults to match: invite = the current `M.DEFAULTS.invite` above; request = current default above AND `OLD_REQUEST`. Run the migration only when `version < 2`, then `version = 2`; custom text untouched. A fresh install (no `messages` table) gets new defaults and `version = 2` directly. Keep `db[kind].auto = db[kind].auto == true` and add `db.invite.autoInvite = db.invite.autoInvite == true and db.invite.auto` (D-09 enforced in `Init`).

**Get/Set shape to extend** (lines 42-53):
```lua
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
```
Add `autoInvite` as a third return of `Get` and a fourth param of `Set`; in `Set`, `auto == false` also writes `autoInvite = false`, and `autoInvite = true` is stored only while `db[kind].auto` is true.

**Format core to keep** (lines 74-89): the `gsub("{(%a+)}", function(key) return values[key] end)` shape already leaves unknown keys literal (nil return keeps the match), which D-01 needs for a leftover `{gs}`. Wrap its result in parentheses (it is, via `((...))`) because `gsub` returns two values. Changes: drop `MyGS` (69-72) and the `ns.GEAR_SCORE` branch (83-85); add `addon = M.ADDON_KEY`, `players = tostring(ns.GroupSize())`; call `M.Normalize` on the raw text first; `:sub(1, MAX)` last (D-05).
```lua
local values = {
	name = l and l.leader.name or "Name",
	activity = l and l.acts[1] and l.acts[1].name or "the dungeon",
	role = MyRoleText(),
	class = ns.W.ClassName(ns.PlayerClass()),
	level = tostring(ns.PlayerLevel()),
}
```
Lua pattern trap (RESEARCH Pitfall 6): `[TGF]` in a pattern must be `%[TGF%]`; `{`/`}` are literal; parenthesise every `gsub` that is chained or returned.

**Send sequence core** (lines 97-123, the extension point):
```lua
function M.Send(l, preview)
	local kind = KindFor(l)
	local text = M.Format(kind, l)
	-- Forever lists only your own mega-realm: whisper by plain character name.
	local target = l.leader.name
	local _, auto = M.Get(kind)
	if auto and preview then
		ns.state.messaged[l.id] = true
		return ns.Print(string.format("preview: whispered %s: %s", target, text))
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
		return
	end
	if ChatFrameUtil and ChatFrameUtil.SendTellWithMessage then
		ChatFrameUtil.SendTellWithMessage(target, text)
	else
		ns.Print(string.format("would open a whisper to %s with: %s", target, text))
	end
end
```
Phase 4: add a `from` param (`"row"` / `"send"`); after the real send (and after the preview auto-send print) do, only for `kind == "invite"` with `autoInvite` and `ns.CanInvite()`: `C_PartyInfo.InviteUnit(target)` (plain name; preview prints `"preview: would invite %s (C_PartyInfo.InviteUnit)."` copied from `Table.lua:700`) and `ns.state.invited[l.id] = true`; then `M.StartLock(l.id, from)`; return `true`. Prefill and lockdown paths: no invite, no lock, return `false`. Keep the `C_ChatInfo`-first / global-second form (do not collapse to the one-liner in RESEARCH's sketch).

**Lock (new, in Messages.lua; copy RESEARCH "Lock" block)**: `lock = { deadline, id, source, gen }`; `M.Locked()` compares `GetTime()` to the deadline; `M.LockID()`, `M.LockSource()` return nil when not locked; `M.StartLock` bumps `gen`, sets deadline `GetTime() + 1`, `C_Timer.After(1, ...)` closure compares `gen`, clears, then `ns.Table.RefreshAll()` if present. Call `GetTime` / `C_Timer.After` as globals at runtime (the harness replaces them after load; never cache in file-level locals).

**BuildPanel to rebuild** (lines 136-216). Existing per-section pattern worth keeping, including the refresher closure and `HookScript("OnTextChanged")` save-if-user:
```lua
local auto = W.Check(parent, "Auto-send", function(b)
	M.Set(kind, nil, b:GetChecked() and true or false)
end)
auto:SetPoint("TOPLEFT", 4, y - 76)
W.Tooltip(auto, "Auto-send", "On: the message button sends the message at once. Off: it opens the whisper and you press Enter.")
local reset = W.Button(parent, "Default", 80, 22, function()
	M.Reset(kind)
	refreshers[kind]()
end)
...
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
```
Phase 4 replaces the single-line `W.EditBox(parent, 400)` (157-160) with the `InputScrollFrameTemplate` recipe (RESEARCH Pattern 2: size, then `EditBox:SetWidth(w-18)`, `SetMaxLetters(255)`, `OnEnterPressed` -> `ClearFocus`, newline strip, probe with `C_XMLUtil.GetTemplateInfo` + `box.EditBox` check, fallback to `W.EditBox`). The sample listing selection for the example line (`ns.Preview.listings[kind == "invite" and #ns.Preview.listings or 1]`, line 182) stays. `Default` still calls `M.Reset(kind)` (text only). `BuildPanel` becomes the single builder of layers + content for both hosts (signature per RESEARCH: `M.BuildPanel(panel)` creating stone band, art, border, divider, intro and a content frame at TOPLEFT (18,-100) / BOTTOMRIGHT (-18,16); UI-SPEC geometry). Delete the "Placeholders:" footer (200-210) and the `ns.GEAR_SCORE` text.

**Key button recipe** (copy `W.Button` call, add font objects; RESEARCH "Key button recipe"): `W.Button(parent, label, 60, 22, onClick)`, `SetNormalFontObject("GameFontNormalSmall")`, `SetDisabledFontObject("GameFontDisableSmall")`, `SetText(label)`, then `SetWidth(b:GetFontString():GetStringWidth() + 24)`; rows of 4 + 3 with 4 px gaps (`SetPoint("LEFT", prev, "RIGHT", 4, 0)`), pitch 24. Click: `edit:Insert(key)`, `edit:SetFocus()`, then `M.Set(kind, edit:GetText())` explicitly (do not rely on `Insert` firing `OnTextChanged` with `user` true; RESEARCH A5).

**Auto-invite gating** (RESEARCH Pattern 4): one Auto-send handler, order save -> uncheck Auto-invite and save false -> `Disable()` -> `c.Text:SetFontObject("GameFontDisableSmall")` (use `c.Label`, which `W.Check` aliases to `c.Text` or the fallback string); on: `Enable()`, restore the remembered font object, leave unchecked. Call the same sync from the refresher. `autoInvite:SetMotionScriptsWhileDisabled(true)` so the disabled tooltip works.

---

### `Core.lua` (utility, transform)

**Analog:** `ns.CanInvite` / `ns.Party` (lines 83-88, 126-136), which already branch on `ns.UsingPreview()`.

```lua
function ns.CanInvite()
	if ns.UsingPreview() then
		return true
	end
	return not IsInGroup() or UnitIsGroupLeader("player") or UnitIsGroupAssistant("player") or false
end
```
Add `ns.GroupSize()` beside it: preview returns `#ns.Party()`; game returns `max(GetNumGroupMembers(), 1)` with the cheap secret guard (`if issecretvalue and issecretvalue(n) then n = 1 end`, RESEARCH Pitfall 9; same optional-global style as `Listings.lua`'s `Secret`). Edit the comment at lines 13-17 to drop the "`{gs}` message key" mention (CLAUDE.md: edit comments with Edit tool; keep the rest). Note the harness stub `G.GetNumGroupMembers = function() return 0 end` (harness 287) makes `max(...,1)` the testable path.

---

### `UI/Widgets.lua` (component helper, request-response)

**Analog:** `W.Button` (290-313) for the new pressed helper (same `Create`/fallback idiom), `W.Check` (346-370) for the label alias, `Tooltip` (266-287) for the gold-title option.

**`W.Button` fallback shape to respect** (lines 290-308): the flat fallback has no `Left/Middle/Right`, so `W.SetPressed` must guard `b.Left` etc. (RESEARCH Pattern 1) and fall back to `SetButtonState` only.
```lua
function W.Button(parent, text, width, height, onClick)
	local b = Create("Button", parent, "UIPanelButtonTemplate")
	b:SetSize(width or 100, height or 22)
	if not b:GetNormalTexture() then
		local bg = b:CreateTexture(nil, "BACKGROUND")
		...
		b:SetNormalTexture(bg)
```

**Place `W.SetPressed(b, on)`** after `W.Button`: RESEARCH Pattern 1 sketch (state + `UI-Panel-Button-Down`/`-Up` on `Left/Middle/Right`, `HookScript` on `OnMouseUp`, `OnShow`, `OnEnable` guarded by `HasScript`, skip when not pressed and was not pressed, only touch art when `b:IsEnabled()`, call `SetButtonState("NORMAL", false)` explicitly on release per A1). Use `b.tgfPressed` as the per-frame flag (frames are recycled, so `FillRow` calls it on every fill).

**`W.Check` label alias to rely on** (lines 355-362): `c.Label` is `c.Text` or our own FontString; use `c.Label:SetFontObject(...)` for the disabled look.
```lua
if c.Text then
	c.Text:SetText(label or "")
	c.Label = c.Text
else
	c.Label = W.Text(c, "GameFontHighlightSmall", 11)
```

**`Tooltip` to extend** (lines 266-287): title/body may already be functions of the frame; the title colour is hard-coded white (`GameTooltip:SetText(t, 1, 1, 1)`). UI-SPEC wants gold titles for Phase 4 tooltips: add an optional fourth argument (e.g. `opts.gold`) so existing callers are unchanged (RESEARCH Pitfall 10). For the disabled Auto-invite second line use a function body that reads `self:IsEnabled()` and appends a `GRAY_FONT_COLOR`-coded line (nil-safe colour globals; fallback `{0.5,0.5,0.5}` per UI-SPEC).

---

### `UI/Table.lua` (component, event-driven + request-response)

**Analog:** itself, six touch points.

**1. `Instance:Message`** (lines 660-667). Add `from` and the lock guard; `Send` now starts the lock itself:
```lua
function Instance:Message(l)
	if not l or l.mine then
		return
	end
	ns.Messages.Send(l, self.source.preview())
	T.RefreshAll()
end
```
Becomes `Instance:Message(l, from)`: `if not l or l.mine or ns.Messages.Locked() then return end`, then `ns.Messages.Send(l, self.source.preview(), from)`, then `T.RefreshAll()`. Note the guard sits before `Send`, so a locked click makes no sound, prefill, whisper or invite (D-15). The delisted row is already blocked by `SetEnabled(not l.delisted)` on the row button.

**2. `Instance:Invite`** (lines 694-706). Add the guard as the first statement; no lock is started here (D-15):
```lua
function Instance:Invite(l)
	if not (l and l.solo and not l.mine) then
		return
	end
	ns.state.invited[l.id] = true
	if self.source.preview() then
		ns.Print(format("preview: would invite %s (C_PartyInfo.InviteUnit).", l.leader.name))
	else
		-- One mega-realm per ruleset: invite by plain character name, no realm suffix.
		C_PartyInfo.InviteUnit(l.leader.name)
	end
	T.RefreshAll()
end
```

**3. Row button OnClick** (lines 864-867):
```lua
row.message = W.Button(row, "Whisper", MSG_W, 20, function(b)
	inst:Message(b:GetParent().listing)
end)
```
Pass `"row"` as the second argument.

**4. `FillRow`** (lines 1117-1119): after `SetEnabled`, because `Enable()` can fire `OnEnable` and reset the art (RESEARCH Pitfall 7):
```lua
row.message:SetShown(not l.mine)
row.message:SetText("Whisper")
row.message:SetEnabled(not l.delisted)
```
Add `W.SetPressed(row.message, ns.Messages.LockSource() == "row" and ns.Messages.LockID() == l.id)`. `FillRow` already "sets every visible state" because frames are recycled (CONTEXT "Established Patterns").

**5. `Instance:RefreshButtons`** (lines 1312-1317): add the send-button press last:
```lua
function Instance:RefreshButtons()
	self:ValidateSelection()
	local sel = ShownSelection(self)
	self.send:SetEnabled(sel ~= nil)
	self.invite:SetEnabled(sel ~= nil and sel.solo == true and ns.CanInvite())
end
```
Append `W.SetPressed(self.send, ns.Messages.LockSource() == "send")` after the `SetEnabled`.

**6. Bottom buttons** (lines 1581-1588): pass `"send"`:
```lua
self.send = W.Button(host, SEND_MESSAGE or "Send Message", 111, 28, function()
	self:Message(ShownSelection(self))
end)
```
`T.RefreshAll()` (1629-1633) is the release hook the lock calls (`for _, inst in ipairs(T.instances) do inst:Refresh() end`); `Messages.lua` calls it through `ns.Table` at runtime (Table loads after Messages).

---

### `UI/InPlace.lua` (provider, event-driven)

**Analog:** itself, `AddMessagesTab` (130-173). Taint style comes from `StayHidden` (89-97, `hooksecurefunc`) and the existing `SetChecked`-on-Blizzard-tabs loops in `ShowMessages` (103-118).

**Current tab block to change** (lines 138-158, 169):
```lua
local stone = messages:CreateTexture(nil, "BACKGROUND", nil, 1)
stone:SetPoint("TOPLEFT", 2, -21)
stone:SetPoint("BOTTOMRIGHT", -2, 3)
if not W.Atlas(stone, "groupfinder-background") then ... end
local content = CreateFrame("Frame", nil, messages)
content:SetPoint("TOPLEFT", 16, -70)
content:SetPoint("BOTTOMRIGHT", -16, 16)
refreshMessages = ns.Messages.BuildPanel(content)
...
messagesTab = W.Create("Frame", LFGParentFrame, "LargeSideTabButtonTemplate")
messagesTab:SetPoint("TOPLEFT", below, "BOTTOMLEFT", 0, -2)
if messagesTab.Icon then
	messagesTab.Icon:SetTexture("Interface\\Icons\\INV_Letter_15")
	messagesTab.Icon:SetSize(30, 30)
	messagesTab.Icon:SetTexCoord(0.03125, 0.96875, 0.03125, 0.96875)
end
messagesTab.tooltipText = "Messages"
...
W.Tooltip(messagesTab, "Messages", "Whisper presets for inviting players and asking groups.")
```
Phase 4: remove the hand-made `stone` texture and the `content` frame (the Who layers and content now come from `ns.Messages.BuildPanel(messages)`); after `Icon:SetTexture`, `if messagesTab.SetFillToInterior then messagesTab:SetFillToInterior(true) else <keep 30x30 + texcoord> end`; `messagesTab:SetChecked(false)` right after creation (G1); delete the `W.Tooltip(messagesTab, ...)` line (G4, `tooltipText` stays); add the G3 hook inside `AddMessagesTab`:
```lua
hooksecurefunc(LFGParentFrame, "UpdateTabs", function()
	if messages:IsShown() then
		for _, key in ipairs({ "ListingTab", "BrowsingTab", "WhoListingTab" }) do
			local tab = LFGParentFrame[key]
			if tab and tab.SetChecked then
				tab:SetChecked(false)
			end
		end
	end
end)
```
(this duplicates the loop in `ShowMessages` 107-112; factor one local `UncheckStock()` used by both). Guard with `type(LFGParentFrame.UpdateTabs) == "function"` so the stub path never errors. The `SetCustomOnMouseUpHandler` branch (159-168) stays.

---

### `UI/MainFrame.lua` (component, preview stand-in)

**Analog:** itself, `BuildMessages` (353-366):
```lua
local function BuildMessages(parent)
	local panel = CreateFrame("Frame", nil, parent)
	local back = panel:CreateTexture(nil, "BACKGROUND")
	back:SetPoint("TOPLEFT", 4, -60)
	back:SetPoint("BOTTOMRIGHT", -4, 3)
	if not W.Atlas(back, "groupfinder-background") then
		back:SetColorTexture(0.05, 0.05, 0.05, 0.6)
	end
	local content = CreateFrame("Frame", nil, panel)
	content:SetPoint("TOPLEFT", 16, -70)
	content:SetPoint("BOTTOMRIGHT", -16, 16)
	refreshMessages = ns.Messages.BuildPanel(content)
	return panel
end
```
Reduce to `panel = CreateFrame("Frame", nil, parent)`; `refreshMessages = ns.Messages.BuildPanel(panel)`; `return panel`. The registration (368-372, `UI.AddPanel("messages", ..., BuildMessages, function() if refreshMessages then refreshMessages() end end, nil, 3)`) is unchanged. The stand-in is 458 x 535 like `LFGParentFrame`, so the same geometry applies (UI-SPEC "Panel Geometry").

---

### Smoke harness `harness.lua` (test, stubs)

**Analog:** itself. Facts the new checks must account for (read at mapping time):
- Frame stub (12-70): `Insert`, `SetFocus`, `SetCursorPosition`, `SetButtonState`, `SetMotionScriptsWhileDisabled`, `SetFillToInterior` are all chainable no-ops via the `^Set|^Insert|...` prefix match, so they never record state: add explicit `M("Insert", ...)` (splice into `__text` at a `__cursor`), `M("GetCursorPosition", ...)` (currently returns 0, line 56), `M("SetCursorPosition", ...)`, and a `SetButtonState` that records `self.__bstate` / `self.__bstateLock` for LOCK-02 asserts.
- `HookScript` (31): `self.__scripts[n] = self.__scripts[n] or fn` does NOT chain; a hook after a `SetScript` is dropped and a hook before one is overwritten. Phase 4's `HookScript("OnTextChanged")` on the preset box and `W.SetPressed`'s `OnMouseUp/OnShow/OnEnable` hooks will be invisible to the stub unless it keeps a `__hooks[n]` list that the test calls; add that, or call the stored script directly in the new asserts.
- `G.GetTime = os.clock` (273): replace with a controllable clock (`local now = 0; G.GetTime = function() return now end`) and drive `C_Timer.After` (249 pushes `{ t, fn }` into `timers`) to fire the 1 s release.
- `G.C_PartyInfo = { InviteUnit = function() end }` (294) and `G.C_ChatInfo = { SendChatMessage = ..., InChatMessagingLockdown = function() return false end }` (295): wrap these to append to an ordered `calls` log (`"send:"..text`, `"invite:"..name`) for the sequence assert; make lockdown switchable.
- `G.GetNumGroupMembers = function() return 0 end` (287) -> `{players}` 1 solo; make it settable for a party-size assert.
- Seed (348-351): `OLD_REQ`, `NEW_REQ`, `TerribleGroupFinderDB = { messages = { request = { text = OLD_REQ } }, gs = seedGS }`. Update `NEW_REQ` to the D-02 request default; add old invite default and a custom-text seed for the migration assert (custom kept, `version` marker set). Lines 525-526 repeat the `NEW_REQ` checks.
- `--attach` mode (353-): `G.LFGParentFrame` has `BrowsingTab`, `WhoListingTab`; add a `UpdateTabs` function field so the `hooksecurefunc(LFGParentFrame, "UpdateTabs", ...)` path runs (check how `G.hooksecurefunc` at 257 wraps table methods).

---

### Smoke harness `tail.lua` (test, asserts)

**Analog:** itself, `check`/`probe` helpers and the no-GS block.
```lua
local fail = 0
local function check(cond, msg) say((cond and "PASS " or "FAIL ") .. msg); if not cond then fail = fail + 1 end end
local function probe(name, fn)
  local ok, e = pcall(fn)
  if not ok then check(false, name .. " raised: " .. tostring(e)) end
end
```
Existing asserts that will break and must be rewritten (D-01, D-24): tail 33 (`TOKENS` has `{gs}`, `--gs` mode), 37-38 (placeholder help lists `{gs}`; `{gs}` filled when on), 85-87 (`"Placeholders:"` text must exist), 95-97 (no UI text mentions GS; `TOKENS` has no `{gs}`; keep the no-GS text scan, drop the `TOKENS` and placeholder lines), 98-100 (`DEFAULTS.request` has no "GS"; equals `NEW_REQ`; migrated), 102-106 (typed `{gs}` stays literal still valid; "default request formats without GS" still valid). Note `--gs` mode asserts `{gs}` is filled when `ns.GEAR_SCORE` is on: D-01 removes that, so replace with "typed `{gs}` stays literal in both modes".

New asserts (D-25), each in a `probe(...)` block so an exception is a FAIL not an abort:
`Format("request")` equals `[TGF] Level 23 Warrior, for The Deadmines` (sample listing); invite with `{players}` 1 solo and the party size when `GetNumGroupMembers` is raised / preview "as leader"; `Normalize` (`"x {addon} y [TGF]"` -> `"{addon} x y"`, literal `[TGF]` mid-text moved first, deduped); key insert at cursor; `[TGF]` button to front (no-op if first); Auto-invite disabled + unchecked + saved false when Auto-send is off, enabled after on and still unchecked; send then invite order and plain name; no invite when `ns.CanInvite()` is false; second click ignored inside the lock, other row and bottom buttons ignored, pressed state set, released after firing the timer; lockdown prefill (no send, no invite, no lock); migration once with custom kept and the version marker; tab `__checked == false` at creation and after `UpdateTabs`. All modes (`--gs`, plain, `--attach`) must end `0 failed`.

## Shared Patterns

### Plain character name for whisper / invite
**Source:** `Messages.lua:100-101`, `UI/Table.lua:702-703`
**Apply to:** the new auto-invite in `M.Send`
```lua
-- Forever lists only your own mega-realm: whisper by plain character name.
local target = l.leader.name
...
-- One mega-realm per ruleset: invite by plain character name, no realm suffix.
C_PartyInfo.InviteUnit(l.leader.name)
```

### Never send during chat messaging lockdown
**Source:** `Messages.lua:107-109`
**Apply to:** `M.Send` only (invite follows the same gate: no whisper, no invite, no lock)
```lua
local locked = C_ChatInfo and C_ChatInfo.InChatMessagingLockdown and C_ChatInfo.InChatMessagingLockdown()
if auto and not locked then
```

### Probe-then-fallback for Blizzard templates and atlases
**Source:** `UI/Widgets.lua:290-308` (`W.Button`), `UI/Widgets.lua:346-362` (`W.Check`), `UI/InPlace.lua:141-143` (`W.Atlas(...)` with a `SetColorTexture` fallback)
**Apply to:** `InputScrollFrameTemplate` boxes, the Who-style layers (`groupfinder-Stat-StoneBG`, `groupfinder-background`, `common-insideframe`, `groupfinder-ScrollLine`), key buttons
```lua
if not W.Atlas(stone, "groupfinder-background") then
	stone:SetColorTexture(0.05, 0.05, 0.05, 0.8)
end
```

### Taint-safe Blizzard hooks
**Source:** `UI/InPlace.lua:89-97, 170-172`
**Apply to:** the `UpdateTabs` hook and any tab work: only `Hide()`, `HookScript`, `hooksecurefunc`, `SetChecked` on Blizzard's tab buttons; never write fields on Blizzard frames
```lua
for _, f in ipairs({ LFGListingFrame, LFGBrowseFrame, LFGWhoListFrame }) do
	f:HookScript("OnShow", HideMessages)
end
```

### Recycled-row state is derived, not stored on the frame
**Source:** `UI/Table.lua:1116-1120` (`FillRow` sets selected / shown / text / enabled every fill)
**Apply to:** the pressed look (`FillRow`, `RefreshButtons`); lock state lives in `Messages.lua` only

### Call timers and clocks as globals
**Source:** harness stubs `harness.lua:249, 273`
**Apply to:** `Messages.lua` lock (`GetTime()`, `C_Timer.After` looked up at call time, not cached in locals)

### Style
`stylua .` from the repo root after the tasks (CLAUDE.md); tabs for indentation; no `sed -i` on `.md`; do not touch `CHANGELOG.md`.

## No Analog Found

| File / piece | Role | Data Flow | Reason |
|--------------|------|-----------|--------|
| `InputScrollFrameTemplate` preset box | component | request-response | No multi-line EditBox exists in the addon; use RESEARCH Pattern 2 (Blizzard source `Blizzard_SharedXML/Shared/InputBox/InputBoxTemplates.lua:82-135`) with `W.EditBox` (`Widgets.lua:373-396`) as the fallback |
| `W.SetPressed` (script-swapped panel button art) | component helper | event-driven | No pressed-state helper exists; use RESEARCH Pattern 1 |
| Contact lock (`M.StartLock` / `M.Locked`) | service | event-driven | No lock or cooldown exists; use RESEARCH "Lock" block |
| `ns.Messages.Normalize` | utility | transform | No text normaliser exists; use RESEARCH Pattern 5 with the finalisation notes there |

## Metadata

**Analog search scope:** `Messages.lua`, `Core.lua`, `UI/Widgets.lua`, `UI/Table.lua`, `UI/InPlace.lua`, `UI/MainFrame.lua`, the smoke harness dir
**Files scanned:** 7 repo files (targeted reads, `Table.lua` and `Widgets.lua` by line range), 2 harness files (stub block and no-GS asserts)
**Pattern extraction date:** 2026-11-11
