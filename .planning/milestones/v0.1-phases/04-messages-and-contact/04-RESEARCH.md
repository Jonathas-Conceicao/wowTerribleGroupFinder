# Phase 4: Messages and Contact - Research

**Researched:** 2026-11-11
**Domain:** WoW Forever (interface 16001) addon UI in Lua 5.1: Blizzard templates (`InputScrollFrameTemplate`, `LargeSideTabButtonTemplate`, `UIPanelButtonTemplate`, `UICheckButtonTemplate`), chat/party APIs, a 1 s contact lock
**Confidence:** HIGH on Blizzard template behaviour (read in the `forever` branch source); MEDIUM on a few runtime orderings that only the game can confirm (listed as in-game checks)

## Summary

Every Blizzard template this phase needs exists in the `forever` source and works from Lua with our own non-secure frames. Three findings change how the approved UI-SPEC / CONTEXT must be implemented, and the planner must build them into the tasks:

1. **`SetButtonState("PUSHED", true)` alone will not look pressed.** `UIPanelButtonTemplate` (Forever uses the Mainline XML) has no Normal/Pushed textures. Its art is three plain textures (`Left`, `Middle`, `Right`) that `UIPanelButton_OnMouseDown/OnMouseUp/OnShow/OnEnable/OnDisable` re-skin to `UI-Panel-Button-Down/Up/Disabled`. The button state only moves the label by the pushed text offset. The "sending" look therefore needs a small helper (`W.SetPressed`) that sets the state **and** the three textures to `UI-Panel-Button-Down`, and re-applies itself after those template scripts reset the art (post-hooks on `OnMouseUp`, `OnShow`, `OnEnable`). All of this is on our own buttons, so it is taint-safe.
2. **A disabled `CheckButton` receives no `OnEnter`/`OnLeave`** unless `SetMotionScriptsWhileDisabled(true)` is set (the API exists; stock uses `motionScriptsWhileDisabled="true"` in 292 XML places). UI-SPEC says "hover still works because the frame stays mouse-enabled": that is wrong for Buttons. The Auto-invite checkbox needs `SetMotionScriptsWhileDisabled(true)` for its "Turn on Auto-send first." tooltip. Also, `UICheckButtonTemplate.Text` is a plain `FontString` (not `ButtonText`), so disabling the button does **not** grey the label, and the template has no disabled box art: the label font swap to `GameFontDisableSmall` (already in UI-SPEC) is the only cue, and a desaturated normal texture is an optional extra.
3. **`InputScrollFrameTemplate` is configured in its `OnLoad`, which runs inside `CreateFrame`**, before Lua can set anything: `maxLetters` defaults to 0 (unlimited), the EditBox width is set to `frame:GetWidth() - 18` while the frame is still 0 wide, and the `CharCount` shows *remaining* letters (`maxLetters - numLetters`). So Lua must set size, then `EditBox:SetWidth(w-18)`, then `EditBox:SetMaxLetters(255)`, then `SetText` (which triggers the stock `OnTextChanged` and refreshes `CharCount`). The multi-line EditBox has **no** `OnEnterPressed` script: Enter inserts a newline until we set one.

Everything else is straightforward: `UpdateTabs` is a mixin method on `LFGParentFrame`, so `hooksecurefunc(LFGParentFrame, "UpdateTabs", fn)` is valid and fixes the "Messages tab and a stock tab both checked after a listing update" case (G3); `SetFillToInterior(true)` exists on the tab mixin; `C_ChatInfo.SendChatMessage`, `C_PartyInfo.InviteUnit`, `C_ChatInfo.InChatMessagingLockdown`, `ChatFrameUtil.SendTellWithMessage`, `C_Timer.After` and `GetNumGroupMembers` are all present and already used or documented.

**Primary recommendation:** Put the lock, key list, normalisation, migration and the send-then-invite sequence in `Messages.lua` (state derived from `M.LockSource()` / `M.LockID()`), let `UI/Table.lua` derive the pressed look from that state on every `FillRow` / `RefreshButtons`, add one `W.SetPressed` helper, and build the Messages panel once inside `M.BuildPanel(panel)` (layers + content) so `InPlace.lua` and `MainFrame.lua` stop duplicating geometry.

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

- **D-01:** Keys: `{addon}`, `{name}`, `{activity}`, `{class}`, `{level}`, `{role}`, `{players}`. `{gs}` is removed from Messages entirely (no `MyGS`, no `ns.GEAR_SCORE` branch in Messages; the `Core.lua` gear-score comment is updated to drop the `{gs}` mention). An unknown key (e.g. a saved `{gs}`) renders literally, so the player sees it in the example line.
- **D-02:** Defaults (stored with the `{addon}` key, rendered `[TGF]`): request: `{addon} Level {level} {class}, for {activity}` -> `[TGF] Level 23 Warrior, for The Deadmines`; invite: `{addon} Group for {activity} with {players} players`.
- **D-03:** `{players}` = your current group size counting yourself (`GetNumGroupMembers()`, at least 1; solo = 1). Preview: `#ns.Party()` (1 solo, the sample party size while "as leader"). `{role}` stays (your roles, as today). `{name}` stays (the whisper target).
- **D-04:** `{addon}` renders `[TGF]` (constant `M.ADDON_KEY = "[TGF]"`). Normalisation (`M.Normalize(text)`): every `{addon}` and every literal `[TGF]` is removed, and if there was at least one, a single `{addon} ` is put at the very start (surrounding whitespace collapsed). It runs in `Format` (rendered text always correct), when the box loses focus and on a key-button insert (stored text keeps the key first). It does not run on every keystroke (no cursor jumps).
- **D-05:** The rendered whisper is cut to 255 characters (chat limit); the raw preset keeps `maxLetters` 255 as today.
- **D-06:** Under each preset's box, one row of buttons, one per key, labelled with the key itself (`{name}`, `{activity}` ...); the addon key's button reads `[TGF]` and comes first. Both presets show the same key set (every key resolves in both).
- **D-07:** A key button inserts the key at the cursor (`EditBox:Insert`), then `SetFocus()` and saves; the `[TGF]` button puts `{addon} ` at the front (no-op if already first), keeps the cursor after it and saves the normalised text. Tooltip on each key button: what the key becomes (e.g. "Your level", "Your current group size, counting you").
- **D-08:** The invite preset has two checkboxes in order: Auto-send, then Auto-invite. The request preset has Auto-send only. Saved as `db.invite.autoInvite` (boolean, default false).
- **D-09:** Auto-invite is enabled only while Auto-send is checked. Unchecking Auto-send also unchecks Auto-invite (saved false) and disables it: `Disable()` + label `GameFontDisableSmall`. Checking Auto-send again enables Auto-invite but leaves it unchecked. `M.Get` / saved state can never report autoInvite true with auto false (enforced in `M.Set` and `M.Init`).
- **D-10:** Sequence on a contact click for a solo listing with Auto-send + Auto-invite on: the whisper is sent, then, in the same click, `C_PartyInfo.InviteUnit(plain name)` when `ns.CanInvite()` (Forever's own invite rule; else whisper only). Marks `messaged` and `invited`.
- **D-11:** Auto-invite fires only after a real auto-send. During `C_ChatInfo.InChatMessagingLockdown()` the whisper is prefilled (never sent) and no invite is sent; no lock starts (nothing was sent).
- **D-12:** Contact paths that honour the presets: the row Whisper button and the bottom Send Message (LOCK-03, the same `Instance:Message` -> `ns.Messages.Send` path). Group rows use the request preset (no invite). The bottom Group Invite stays a plain invite (no whisper).
- **D-13:** Row Whisper label stays "Whisper" on every row (it always whispers; the invite is extra). Preview: auto-send prints the whisper and, with Auto-invite, the would-invite line.
- **D-14:** The lock lives in `Messages.lua` (`M.Locked()`, `M.LockedBy(button)` or equivalent), 1 s from the moment of an auto-send (`GetTime()` deadline + `C_Timer.After(1, release)`; the `GetTime()` check makes the lock correct even if the timer is late).
- **D-15:** Only a click that actually auto-sends starts the lock (prefill clicks and plain Group Invite clicks don't). While locked, the handlers of every row Whisper, the bottom Send Message and the bottom Group Invite return at once (no sound, no whisper, no invite, no prefill). Their look is not changed (no disabling flicker across the list).
- **D-16:** "Sending" look: the clicked button gets `SetButtonState("PUSHED", true)` for the second, then `SetButtonState("NORMAL")` on release. The send itself is instant (before the press). ScrollBox recycling: `FillRow` re-applies the state (pressed only on the row frame now showing the locked listing id (row button)) and the bottom Send Message is restored by release / `RefreshButtons`. Release calls `T.RefreshAll()` so enabled states are recomputed.
- **D-17:** Outside the lock: the delist button, the hide (X) button, selection, sorting, the search box, and the Messages panel's own buttons.
- **D-18:** Following phase 1's pattern (`OLD_REQUEST` compare in `M.Init`), with a version marker so it runs once: `db.version` (absent = 1). On load with version < 2: a preset whose text equals any previous default for its kind (invite: the prototype invite default; request: the prototype request default and the old GS request default) is replaced by the new default; custom texts are kept untouched. Then `db.version = 2`. Changes made later by the player are never touched again.
- **D-19:** `messagesTab:SetChecked(false)` right after creation (G1); `fillToInterior` on (G2: `SetFillToInterior(true)` where present, else the field before the first `SetChecked`; keep the 30x30 + texcoord fallback); `hooksecurefunc(LFGParentFrame, "UpdateTabs", fn)` unchecks the three stock tabs while Messages shows (G3), reading only; `SetChecked` on Blizzard's tab buttons is what `ShowMessages` already does (button state, not a field write; see UI-PARITY D9); tooltip: `tooltipText = "Messages"` only, the `W.Tooltip` hook is dropped (G4).
- **D-20:** Icon stays `Interface\Icons\INV_Letter_15` (in-game check Q4).
- **D-21:** In game and in the preview stand-in the panel uses the Who tab's layers (G33): stone band `groupfinder-Stat-StoneBG` (2,-21) down to the art top -7; art `groupfinder-background` (4,-80)/(-4,3); border `common-insideframe` (3,-78)/(-4,3); `groupfinder-ScrollLine` at the art top -20 and bottom +42 as WhoList where it fits; colour fallbacks where atlases are missing. Title `LFG_TITLE`. The intro text sits in the stone band; the presets inside the inset. (UI-SPEC narrows the ScrollLine to one divider at panel y -300.)
- **D-22:** Preset boxes: `InputScrollFrameTemplate` (non-secure), ~3 lines tall, char count shown, `maxLetters` 255; size set first then `EditBox:SetWidth(w-18)`; Enter clears focus; newlines stripped (paste). Fallback: the current single-line `W.EditBox`.
- **D-23:** Per preset, top to bottom: title (+ help), box, key-button row (G32: `UIPanelButtonTemplate` 22 tall, width = text width + 24, `GameFontNormalSmall`), checkboxes (`W.Check`: `UICheckButtonTemplate` 26x26 with its own `.Text` and ON/OFF sounds, already in place), "Default" button (`UIPanelButtonTemplate`, 22 tall) on the right, example line. Exact offsets: UI-SPEC.
- **D-24:** Intro / help texts updated for Auto-invite and the 1 s lock; the old "Placeholders:" footer is replaced by the key buttons (each has a tooltip).
- **D-25:** Smoke harness checks: default rendering, `Normalize`, key insert at cursor and `[TGF]` button to front, Auto-invite gating, auto-send + invite sequence order, no invite without `CanInvite`, the 1 s lock, lockdown prefill, migration, tab unchecked at creation and after `UpdateTabs`. All harness modes end with 0 failed.

### Claude's Discretion

- Exact offsets, box height and spacing (UI-SPEC).
- Whether the lock helper lives in Messages.lua or a small block in Table.lua (default: Messages.lua).
- Key-button tooltip wording.
- Discuss step did not chain into plan-phase automatically: the orchestrating run executes ui-phase before plan-phase, as instructed.

### Deferred Ideas (OUT OF SCOPE)

- Localising the hardcoded English labels (key tooltips, panel texts)
- A side-tab icon made for the mask (Q4 in-game check)
- Remembering Messages as the open tab (would need writing `selectedTab`, not allowed)
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| MSG-01 | Default request preset `{addon} Level {level} {class}, for {activity}` | Defaults + `Format` rules (Messages Core section); smoke check on rendered text |
| MSG-02 | Default invite preset `{addon} Group for {activity} with {players} players`, `{players}` = current group size | `{players}` via `max(GetNumGroupMembers(), 1)` (stock does the same, `Blizzard_UIPanels_Game/Cata/PVPFrame.lua:749`); preview `#ns.Party()`; recommend `ns.GroupSize()` in Core |
| MSG-03 | One button per key under each box; click inserts at the cursor | `EditBox:Insert` documented (`SimpleEditBoxAPIDocumentation.lua:446`); button recipe + harness EditBox cursor model |
| MSG-04 | Addon key renders `[TGF]`, always first, at most once; its button puts it first | `M.Normalize` algorithm (Lua-pattern pitfalls for `[TGF]` documented); run in `Format`, focus lost, key insert |
| MSG-05 | Invite preset: Auto-send then Auto-invite; Auto-invite greyed unless Auto-send; unchecks with it | `UICheckButtonTemplate` facts (label is a plain FontString, motion scripts while disabled); single handler order save -> uncheck -> disable |
| MSG-06 | Both on: one click whispers then invites | Sequence in `M.Send`: `C_ChatInfo.SendChatMessage` then `C_PartyInfo.InviteUnit(plain name)` gated by `ns.CanInvite()`; no invite in lockdown |
| LOCK-01 | After an auto-send every whisper/invite button ignores clicks for 1 s | Lock in `Messages.lua` using `GetTime()` deadline + `C_Timer.After`; guards in `Instance:Message`, `Instance:Invite` |
| LOCK-02 | Clicked button stays visibly pressed for 1 s | `W.SetPressed` (state + `UI-Panel-Button-Down` textures + re-apply hooks); finding 1 above |
| LOCK-03 | Bottom Send Message uses same preset path and lock | Same `Instance:Message` path with `from = "send"`; pressed look derived from `M.LockSource()` in `RefreshButtons` |
| UIP-01 | Messages tab starts unchecked, fills icon, never checked with another tab, stock tooltip | `SetChecked(false)`, `SetFillToInterior(true)`, `hooksecurefunc(LFGParentFrame, "UpdateTabs")`, `tooltipText` only |
| UIP-11 | Panel uses the Who layers, multi-line boxes, native checkboxes with sounds, Auto-invite disabled look | Who layer XML (`WhoList.xml:102-137`), `InputScrollFrameTemplate` recipe, `UICheckButtonTemplate` facts |
</phase_requirements>

## Architectural Responsibility Map

This is a client-only addon (no server tier). Tiers are mapped to the addon's own layers.

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Preset text, keys, normalisation, migration, saved state | `Messages.lua` (logic + `TerribleGroupFinderDB`) | `Core.lua` (answers `ns.GroupSize/CanInvite/MyRoles`) | CLAUDE.md: Core answers "the questions the table asks" from game or preview |
| Send, auto-invite, lockdown prefill | `Messages.lua` (`M.Send`) | Blizzard APIs (`C_ChatInfo`, `C_PartyInfo`, `ChatFrameUtil`) | One path for row Whisper and bottom Send Message (LOCK-03) |
| Contact lock (deadline, owner, release) | `Messages.lua` | `UI/Table.lua` (guards + pressed look) | D-14 default; Table only reads lock state |
| Pressed look on recycled rows | `UI/Table.lua` (`FillRow`, `RefreshButtons`) | `UI/Widgets.lua` (`W.SetPressed`) | ScrollBox recycles frames: state must be derived on every fill |
| Messages panel (layers, boxes, key buttons, checkboxes) | `Messages.lua` `M.BuildPanel(panel)` | `UI/Widgets.lua` helpers | One builder for the game and the stand-in |
| Side tab (check state, fill, tooltip, UpdateTabs hook) | `UI/InPlace.lua` | Blizzard `LFGParentFrame` (read/Hide/SetChecked only) | Taint rules: only Hide/HookScript/hooksecurefunc/SetChecked on Blizzard's |
| Stand-in panel placement | `UI/MainFrame.lua` | — | Preview only; calls the same `M.BuildPanel` |

## Standard Stack

No external packages. Everything is Blizzard-shipped UI, Lua 5.1 and the existing addon helpers. `slopcheck`, `npm`, `pip` are not applicable.

### Core
| Library / Template | Version | Purpose | Why Standard |
|--------------------|---------|---------|--------------|
| `InputScrollFrameTemplate` | `forever` branch (`Blizzard_SharedXML/Shared/InputBox/InputBoxTemplates.xml:72-176`) | Multi-line preset boxes with char count | Stock multi-line input; the Listing tab's comment box derives from the secure sibling |
| `LargeSideTabButtonTemplate` + `SidePanelTabButtonMixin` | `SharedUIPanelTemplates.xml:1008`, `.lua:312-445` | Messages side tab | Same template as Forever's three tabs |
| `UIPanelButtonTemplate` | `SharedUIPanelTemplates.xml:315` -> `SecureUIPanelTemplates.xml:39` | Key buttons, Default, row/bottom buttons | Already wrapped by `W.Button` |
| `UICheckButtonTemplate` | `Shared/Button/CheckButtonTemplates.xml:50` | Auto-send, Auto-invite | Already wrapped by `W.Check` |
| `C_ChatInfo.SendChatMessage` / `SendChatMessage` | `ChatInfoDocumentation.lua:564`; global alias `Blizzard_DeprecatedChatInfo/Deprecated_ChatInfo.lua:8` | Auto-send whisper | Already used in `M.Send`; both exist |
| `C_PartyInfo.InviteUnit` | `PartyInfoDocumentation.lua:357` | Auto-invite | Same call `Instance:Invite` and stock Browse (`Blizzard_LFGVanilla_Browse.lua:1472`) use |
| `C_ChatInfo.InChatMessagingLockdown` | `ChatInfoDocumentation.lua:293` | Lockdown guard | CLAUDE.md rule |
| `ChatFrameUtil.SendTellWithMessage` | `Blizzard_ChatFrameBase/Shared/ChatFrameUtil.lua:367` | Prefill the whisper box | Already used |
| `C_Timer.After`, `GetTime` | `UITimerDocumentation.lua:11` | Lock release + deadline | Standard |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| `InputScrollFrameTemplate` | `UIPanelInputScrollFrameTemplate` (`SecureScrollTemplates.xml:54`) | Secure variant for the Listing comment box; wrong here (we are non-secure). Rejected. |
| `W.SetPressed` (art + state) | `SetButtonState` only | State alone does not change the `UIPanelButtonTemplate` art (see Summary). Rejected. |
| Timer-only lock | `GetTime()` deadline + timer | Deadline is correct even if the timer is late (D-14). Use both. |

**Installation:** none.
**Version verification:** not applicable (no registry packages); every API/template citation above was read in `C:\Users\jonat\Repositories\wow-ui-source` on branch `forever`.

## Package Legitimacy Audit

No external packages are installed in this phase.

| Package | Registry | Age | Downloads | Source Repo | slopcheck | Disposition |
|---------|----------|-----|-----------|-------------|-----------|-------------|
| (none) | — | — | — | — | — | — |

**Packages removed due to slopcheck [SLOP] verdict:** none
**Packages flagged as suspicious [SUS]:** none

## Architecture Patterns

### System Architecture Diagram

```
 click on row "Whisper" ----------\                  click on bottom "Send Message"
 (row.message OnClick)             \                 (self.send OnClick)
                                    v                       |
                          Instance:Message(l, button, from) <-+
                                    |
              M.Locked()? --yes--> return (no sound, no prefill, no whisper, no invite)
                                    | no
                                    v
                         M.Send(l, preview, from)
                                    |
              KindFor(l): solo -> "invite" ; group -> "request"
                                    |
              text = Format(kind, l)   (Normalize -> keys -> cut 255)
                                    |
              auto-send on?  --no--> prefill whisper box (ChatFrameUtil.SendTellWithMessage) ; no lock
                                    | yes
              InChatMessagingLockdown()? --yes--> prefill ; no invite ; no lock
                                    | no
                                    v
                      C_ChatInfo.SendChatMessage(text,"WHISPER",nil,plainName)
                      state.messaged[id] = true
                                    |
        kind=="invite" and autoInvite and ns.CanInvite()?
                          yes -> C_PartyInfo.InviteUnit(plainName) ; state.invited[id] = true
                                    |
                      StartLock(id, from)  -> deadline = GetTime()+1 ; C_Timer.After(1, release)
                                    |
                  Instance:Message continues -> T.RefreshAll()
                                    |
                 FillRow / RefreshButtons derive:  W.SetPressed(btn, M.LockSource()=="row" and M.LockID()==l.id)
                                                   W.SetPressed(self.send, M.LockSource()=="send")
                                    |
                 timer fires -> clear lock -> T.RefreshAll() -> everything un-pressed

 bottom "Group Invite" -> Instance:Invite: if M.Locked() return ; plain InviteUnit ; no lock started

 Messages panel (M.BuildPanel(panel)) -- boxes / key buttons / checkboxes --> M.Set / M.Reset --> TerribleGroupFinderDB.messages
 Side tab (InPlace) --> ShowMessages / HideMessages ; hooksecurefunc(LFGParentFrame,"UpdateTabs") keeps stock tabs unchecked
```

### Recommended Project Structure
```
Messages.lua          # keys, Normalize, Format, Get/Set/Reset/Init(+migration), Send(+invite), lock, BuildPanel(panel)
Core.lua              # + ns.GroupSize() (game: max(GetNumGroupMembers(),1); preview: #ns.Party()); comment drops {gs}
UI/Widgets.lua        # + W.SetPressed(button, on); W.Check gets Disable-label handling hooks (or done in Messages)
UI/Table.lua          # Instance:Message(l, button, from), Instance:Invite guard, FillRow/RefreshButtons re-apply pressed
UI/InPlace.lua        # AddMessagesTab: SetChecked(false), SetFillToInterior, UpdateTabs hook, tooltipText only, panel = BuildPanel
UI/MainFrame.lua      # BuildMessages -> just calls ns.Messages.BuildPanel(panel) (same geometry)
```

### Pattern 1: Pressed look on a stock `UIPanelButtonTemplate`
**What:** Set the button state, then also swap the three art textures; re-apply when the template's own scripts reset them.
**When to use:** the clicked row Whisper / bottom Send Message during the 1 s lock.
**Why:** `UIPanelButtonNoTooltipTemplate` draws `Left`/`Middle`/`Right` with `UI-Panel-Button-Up`; `UIPanelButton_OnMouseDown` swaps to `-Down`, `OnMouseUp`/`OnShow`/`OnEnable` swap back to `-Up`, `OnDisable` to `-Disabled` (`Blizzard_SharedXML/SecureUIPanelTemplates.xml:39-80`, `SecureUIPanelTemplates.lua:36-79`). `SetButtonState(state, lock)` is documented (`SimpleButtonAPIDocumentation.lua:293`) but only affects the button's own state (label offset).
**Example:**
```lua
-- UI/Widgets.lua (sketch; our own buttons only)
local function ApplyPressed(b)
	local tex = b.tgfPressed and "Interface\\Buttons\\UI-Panel-Button-Down" or "Interface\\Buttons\\UI-Panel-Button-Up"
	for _, key in ipairs({ "Left", "Middle", "Right" }) do
		if b[key] and b[key].SetTexture then
			b[key]:SetTexture(tex)
		end
	end
end

function W.SetPressed(b, on)
	on = on and true or false
	if b.tgfPressed == on and not on then
		return -- common path on every FillRow: nothing to undo
	end
	if not b.tgfHooked then
		b.tgfHooked = true
		-- the template resets the art on mouse up / show / enable: put it back while pressed
		for _, script in ipairs({ "OnMouseUp", "OnShow", "OnEnable" }) do
			if b:HasScript(script) then
				b:HookScript(script, function(self)
					if self.tgfPressed then
						ApplyPressed(self)
					end
				end)
			end
		end
	end
	b.tgfPressed = on
	b:SetButtonState(on and "PUSHED" or "NORMAL", on)
	if b.Left then
		ApplyPressed(b) -- on release this restores the Up art (the template only does it on mouse up/show/enable)
	end
end
```
Notes: (a) when `on` is false and the button was not pressed, skip work (`FillRow` calls this for every row on every fill); the early return above must still handle "was pressed, now not" (check `b.tgfPressed` before overwriting; the sketch is illustrative, finalise the guard in the task). (b) A **disabled** button must keep `UI-Panel-Button-Disabled` art: only apply Up/Down when `b:IsEnabled()`. (c) The W.Button fallback (flat `SetNormalTexture(bg)`) has no `Left/Middle/Right`; `SetButtonState("PUSHED", true)` plus the label offset is the best available there, or give the fallback a `SetPushedTexture` darker colour.

### Pattern 2: `InputScrollFrameTemplate` created from Lua
**What:** The template's `OnLoad` (`InputBoxTemplates.lua:82-95`) already ran at `CreateFrame` with a 0-wide frame, so Lua must finish the setup.
**Example:**
```lua
-- Source: Blizzard_SharedXML/Shared/InputBox/InputBoxTemplates.lua:82-135 (read in forever branch)
local function PresetBox(parent, width, height, onChange)
	local ok = C_XMLUtil and C_XMLUtil.GetTemplateInfo and C_XMLUtil.GetTemplateInfo("InputScrollFrameTemplate")
	local box = ok and W.Create("ScrollFrame", parent, "InputScrollFrameTemplate")
	if not (box and box.EditBox) then          -- template missing OR OnLoad failed inside pcall
		if box then box:Hide(); box:SetParent(nil) end
		local e = W.EditBox(parent, width)     -- single-line fallback (existing helper)
		return e, e
	end
	box:SetSize(width, height)                 -- 1. size first
	local edit = box.EditBox
	edit:SetWidth(width - 18)                  -- 2. template's own convention (scroll bar gutter)
	edit:SetMaxLetters(255)                    -- 3. maxLetters defaulted to 0 in OnLoad
	box.CharCount:Show()                       -- hideCharCount is nil -> already shown; explicit is harmless
	edit:SetScript("OnEnterPressed", edit.ClearFocus)   -- no stock OnEnterPressed: Enter would add a newline
	edit:HookScript("OnTextChanged", function(self, user)  -- HookScript: the stock InputScrollFrame_OnTextChanged keeps running
		local text = self:GetText()
		if text:find("[\r\n]") then            -- pasted newlines
			self:SetText((text:gsub("[\r\n]+", " ")))
			return
		end
		onChange(self, user)
	end)
	return box, edit
end
```
Facts to rely on: `CharCount` text is `maxLetters - numLetters` (remaining), refreshed by the stock `OnTextChanged`; Escape clears focus via the stock `OnEscapePressed` (`:127`); `OnMouseDown` on the frame focuses the EditBox (`:101`); the ScrollBar is created by `ScrollFrame_OnLoad` and hidden when nothing scrolls (`scrollBarHideIfUnscrollable = true`); `smartNavigationIgnored` is already set. `SetText` from Lua fires `OnTextChanged` with `userInput == false`, so saving only when `user` is true (as today) does not echo programmatic writes.

### Pattern 3: Side tab (UIP-01)
```lua
-- Source: SharedUIPanelTemplates.lua:373-407 ; Blizzard_LFGVanilla_ParentFrame.lua:56-71,90-104
messagesTab = W.Create("Frame", LFGParentFrame, "LargeSideTabButtonTemplate")
messagesTab:SetPoint("TOPLEFT", below, "BOTTOMLEFT", 0, -2)
messagesTab.Icon:SetTexture("Interface\\Icons\\INV_Letter_15")
if messagesTab.SetFillToInterior then
	messagesTab:SetFillToInterior(true)         -- UpdateIconInterior: texcoord .03125-.96875 and 50x50 (extent default 50)
else
	messagesTab.Icon:SetSize(30, 30)            -- fallback only
	messagesTab.Icon:SetTexCoord(0.03125, 0.96875, 0.03125, 0.96875)
end
messagesTab:SetChecked(false)                   -- G1: SelectedTexture is shown by default (template XML:1036)
messagesTab.tooltipText = "Messages"            -- G4: template OnEnter shows it (SharedUIPanelTemplates.lua:408-419)
hooksecurefunc(LFGParentFrame, "UpdateTabs", function()
	if messages:IsShown() then UncheckStock() end   -- G3
end)
```
`UpdateTabs` is `LFGParentFrameMixin:UpdateTabs` (`Blizzard_LFGVanilla_ParentFrame.lua:56`), applied to the frame by `mixin="LFGParentFrameMixin"` (`ParentFrame.xml:31`), and is called as `LFGParentFrame:UpdateTabs()` from `SetActiveTab` (:27), `OnShow` (:39) and the `LFG_LIST_ACTIVE_ENTRY_UPDATE` handler (:51). It `SetChecked`s the three stock tabs from `selectedTab` (only when `LFGVANILLA_SETTING_MODERN_STYLE`), so without the hook a listing update while Messages shows would re-check a stock tab (G3). `hooksecurefunc(table, "UpdateTabs", fn)` is therefore valid. The tab's `OnLoad` (`InitializeSizeForTabArt`, `InitializeIconAnchoring`) runs at creation from the template; the stock tabs set 30x30 in their own mixin `OnLoad` and reach 50x50 only through `SetChecked` -> `UpdateIconInterior` (`fillToInterior` key set in XML, `ParentFrame.xml:21-24`), which is why `SetFillToInterior(true)` (which calls `UpdateIconInterior` immediately) is the equivalent.

### Pattern 4: Auto-invite checkbox gating (MSG-05 / D-09)
One handler for Auto-send, in this order: save auto -> if off: uncheck Auto-invite, save `autoInvite=false`, `Disable()`, label `GameFontDisableSmall` -> if on: `Enable()`, label back to the remembered object (leave unchecked). The refresh path (`ShowMessages` -> `refreshMessages`) must run the same sync from saved state. Required extras (see Pitfalls): `autoInvite:SetMotionScriptsWhileDisabled(true)`; label is `c.Text` (plain FontString): `c.Text:SetFontObject(...)`; remember `c.Text:GetFontObject()` before the first swap (it is `GameFontNormalSmall` from the template).

### Pattern 5: Normalize (D-04)
```lua
M.ADDON_KEY = "[TGF]"
function M.Normalize(text)
	local n
	text, n = text:gsub("%s*{addon}%s*", " ")      -- '{' is not magic in Lua patterns
	local m
	text, m = text:gsub("%s*%[TGF%]%s*", " ")      -- '[' and ']' ARE magic: escape them
	if n + m == 0 then
		return text
	end
	text = text:gsub("^%s+", ""):gsub("%s+$", "")  -- careful: gsub returns 2 values; wrap in parentheses when chaining/returning
	return "{addon} " .. text                      -- trailing space only if text ~= "" (else just "{addon}")
end
```
Finalise details in the task (parenthesise gsub results; decide that `"{addon}"` alone stays `"{addon}"` without a trailing space). `Format` calls `Normalize` first, substitutes keys with `gsub("{(%a+)}", ...)` (an unknown key returns nil so Lua keeps the match: `{gs}` stays literal, as D-01 requires), then `:sub(1, 255)`.

### Anti-Patterns to Avoid
- **Caching `GetTime`/`C_Timer` in file-level locals** (`local GetTime = GetTime`): the smoke harness replaces the globals after load; call them as globals at runtime.
- **`SetScript` on the template's `OnTextChanged`/`OnEscapePressed`**: it would remove the stock char count and scroll handling. Use `HookScript`. `OnEnterPressed` has no stock script, so `SetScript` is right there.
- **Per-keystroke `Normalize`** (cursor jumps) - D-04 forbids it.
- **Disabling/greying other contact buttons during the lock** - D-15 forbids it; ignore clicks only.
- **Writing fields on Blizzard frames**: the only Blizzard-object calls are `SetChecked` on the three stock tabs, `Hide()`, `HookScript`, `hooksecurefunc`.
- **Storing lock state on frames**: rows are recycled; derive from `M.LockSource()/M.LockID()` on every fill.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Multi-line box with scrolling and char count | Custom EditBox + ScrollFrame + counter | `InputScrollFrameTemplate` | Cursor scrolling (`ScrollingEdit_*`), char count, scroll bar, border art all included |
| Side tab art, hover, selected state, tooltip, sound | A custom `CheckButton` tab | `LargeSideTabButtonTemplate` | Already used; only `SetChecked/SetFillToInterior/tooltipText` needed |
| Checkbox | Custom texture toggle | `UICheckButtonTemplate` via `W.Check` | Sounds already wired; `DisabledCheckedTexture` included |
| Whisper prefill | Opening the chat box by hand | `ChatFrameUtil.SendTellWithMessage` | Handles editbox choice and parsing |
| Timer | `OnUpdate` frame | `C_Timer.After` + `GetTime()` deadline | Simple and correct when late |
| Atlas/template presence | try/catch around layout | `W.HasAtlas` / `C_XMLUtil.GetTemplateInfo` + `.EditBox` check | Existing probe pattern |

**Key insight:** the only genuinely custom pieces are the pressed look (the stock button art is script-driven) and the Normalize/lock logic; everything visual is a stock template.

## Runtime State Inventory

> This phase is not a rename/migration of strings, but it does migrate saved data (D-18), so the stored-data category is answered explicitly.

| Category | Items Found | Action Required |
|----------|-------------|------------------|
| Stored data | `TerribleGroupFinderDB.messages.{invite,request}.text/auto` (SavedVariables). New: `messages.invite.autoInvite`, `messages.version` | Data migration in `M.Init` (D-18): replace texts equal to a previous default, keep custom ones, set `version = 2`. Suggested marker location: `saved.messages.version` (Messages' own table) rather than `ns.db.schema` (Core's `DEFAULTS.schema = 1`) to avoid two meanings of "version" |
| Live service config | None (no external service) | None, verified by repo scan |
| OS-registered state | None | None |
| Secrets/env vars | None | None |
| Build artifacts | None (`scripts/install.ps1` derives files from the TOC; no new file is added if `BuildPanel` stays in `Messages.lua`) | If a new Lua file were added, it must go in the TOC load list |

Previous defaults to match (for the migration): invite `"Hi {name}! We're forming a group for {activity}, want to join?"`; request `"Hi {name}! Level {level} {class} here ({role}), could I join you for {activity}?"` and the old GS request `"Hi {name}! Level {level} {class} here ({role}, GS {gs}), could I join you for {activity}?"` (currently `OLD_REQUEST` in `Messages.lua:20`; fold it into the same table and remove the `not ns.GEAR_SCORE` condition). Migration must run before the "fill missing text with defaults" step or after it consistently; a fresh install (no `messages` table) gets the new defaults and `version = 2` directly.

## Common Pitfalls

### Pitfall 1: "Pressed" that does not look pressed
**What goes wrong:** `SetButtonState("PUSHED", true)` only shifts the label; the red button art stays "Up".
**Why:** `UIPanelButtonTemplate` art is script-swapped textures, not Normal/Pushed textures (`SecureUIPanelTemplates.xml:39-80`).
**How to avoid:** `W.SetPressed` (Pattern 1). Include the re-apply hooks: `UIPanelButton_OnMouseUp` (post-click) and `UIPanelButton_OnEnable/OnShow` (ScrollBox re-show / `SetEnabled` in `FillRow` and `RefreshButtons`) would otherwise reset the art.
**Warning signs:** the button looks normal while locked; or it "pops" back as soon as the mouse is released. **In-game check:** the order of `OnMouseUp` vs `OnClick` is not documented in the source; the post-hook on `OnMouseUp` makes the result independent of the order.

### Pitfall 2: Disabled Auto-invite has no tooltip
**What goes wrong:** hovering the greyed checkbox shows nothing.
**Why:** disabled Buttons skip `OnEnter/OnLeave` unless `SetMotionScriptsWhileDisabled(true)` (API: `SimpleButtonAPIDocumentation.lua:403`; stock sets `motionScriptsWhileDisabled="true"` e.g. `Blizzard_RaidFrame/Mainline/RaidFrame.xml:145`).
**How to avoid:** call it once at creation of the Auto-invite checkbox. The tooltip body is a function of the frame: read `b:IsEnabled()` when the tooltip opens and append "Turn on Auto-send first." (existing `W.Tooltip` accepts function bodies; its single `AddLine` can carry a grey-coded second line, or extend `W.Tooltip` minimally).
**Warning signs:** tooltip appears on Auto-send but never on a disabled Auto-invite.

### Pitfall 3: Checkbox label does not grey
**What goes wrong:** `Disable()` leaves the label gold.
**Why:** `Text` is a `FontString` (`parentKey="Text"` in the ARTWORK layer), not `ButtonText` (`CheckButtonTemplates.xml:55-63`); the template also has no disabled box texture, only `DisabledCheckedTexture`.
**How to avoid:** `c.Text:SetFontObject("GameFontDisableSmall")` on disable, restore the remembered object on enable; optionally desaturate `c:GetNormalTexture()`. In the fallback path `W.Check` creates a `GameFontHighlightSmall` label as `c.Label` (no `c.Text`): the same swap works on `c.Label`.

### Pitfall 4: Template configured before Lua can touch it
See Summary finding 3. Size -> `EditBox:SetWidth(w-18)` -> `SetMaxLetters(255)` -> `SetText`. If `SetMaxLetters(255)` is skipped the box accepts unlimited text and `CharCount` shows a negative or huge number; if `EditBox:SetWidth` is skipped text wraps at -18 px (invisible).

### Pitfall 5: Enter adds a newline; paste adds newlines
Multi-line EditBox with no `OnEnterPressed`. Set it (`ClearFocus`) and strip `[\r\n]` in the hooked `OnTextChanged` (re-entrant: `SetText` fires the hook again with `user == false`, and the stripped text has no newline, so there is no loop).

### Pitfall 6: Lua pattern traps in Normalize/Format
`[TGF]` inside a pattern is a character class (matches single letters T, G or F); escape it `%[TGF%]`. `{` and `}` are literal in Lua patterns. `string.gsub` returns two values; chaining `:gsub():gsub()` or returning it from a function leaks the count - parenthesise. `Format`'s `gsub("{(%a+)}", fn)` keeps the original text when `fn` returns nil/false (unknown keys stay literal). A key value containing `%` is fine when returned from a function (it is not a replacement string).

### Pitfall 7: Selection of the contact button state on recycled rows
`FillRow` reuses frames: if only `Message` sets the pressed look, scrolling or `RefreshAll` leaves a pressed look on a row that now shows another listing. Always call `W.SetPressed(row.message, M.LockSource() == "row" and M.LockID() == l.id)` in `FillRow` (after `SetEnabled`, which can fire `OnEnable`), and `W.SetPressed(self.send, M.LockSource() == "send")` last in `RefreshButtons`.

### Pitfall 8: Timer ordering / stale releases
A second lock cannot start inside the first (clicks are ignored), but a release timer from an earlier lock must not clear a later one in tests or after `/reload`-free state changes: store a generation counter and have the release closure compare it. Release also must call `T.RefreshAll()` (via `ns.Table`, loaded after `Messages.lua`, available at runtime).

### Pitfall 9: Secret values
CLAUDE.md requires `issecretvalue()` guards where values may be secret. `GetNumGroupMembers()` is not documented as secret; a one-line guard (`if issecretvalue and issecretvalue(n) then n = 1 end`) is cheap and consistent. Plain names come from `Listings.lua`, which already skips secret listings.

### Pitfall 10: UI-SPEC tooltip colour vs existing helper
UI-SPEC says the key-button tooltip title is gold (`NORMAL_FONT_COLOR`) and the body `HIGHLIGHT_FONT_COLOR`, but `W.Tooltip` (`UI/Widgets.lua:266-284`) draws the title white (`SetText(t, 1, 1, 1)`) and an uncoloured wrapped body. Pick one in the plan: either add an optional gold-title mode to `W.Tooltip` (affects only new callers) or accept the existing white title for consistency with the rest of the addon. Recommended: add a `NORMAL_FONT_COLOR` option and use it for the Phase 4 tooltips only.

## Code Examples

### Send with optional invite and lock (sketch)
```lua
-- Messages.lua. Returns true when the message was actually sent (so callers know a lock started).
function M.Send(l, preview, from)
	local kind = KindFor(l)
	local text = M.Format(kind, l)
	local target = l.leader.name                 -- plain name, no realm (CLAUDE.md)
	local _, auto, autoInvite = M.Get(kind)
	if auto and preview then
		ns.state.messaged[l.id] = true
		ns.Print(string.format("preview: whispered %s: %s", target, text))
		if kind == "invite" and autoInvite and ns.CanInvite() then
			ns.state.invited[l.id] = true
			ns.Print(string.format("preview: would invite %s (C_PartyInfo.InviteUnit).", target))
		end
		M.StartLock(l.id, from)
		return true
	end
	local locked = C_ChatInfo and C_ChatInfo.InChatMessagingLockdown and C_ChatInfo.InChatMessagingLockdown()
	if auto and not locked then
		(C_ChatInfo and C_ChatInfo.SendChatMessage or SendChatMessage)(text, "WHISPER", nil, target)
		ns.state.messaged[l.id] = true
		if kind == "invite" and autoInvite and ns.CanInvite() then
			C_PartyInfo.InviteUnit(target)
			ns.state.invited[l.id] = true
		end
		M.StartLock(l.id, from)
		return true
	end
	-- prefill (also the lockdown path): no send, no invite, no lock
	...
	return false
end
```
(Use the existing if/else form for the two send functions rather than the one-liner; the sketch is shortened.) Note `ns.state.invited` is already handled in `FillRow`'s Listed text (invited wins over messaged).

### Lock
```lua
local lock = { deadline = 0, id = nil, source = nil, gen = 0 }
function M.Locked() return GetTime() < lock.deadline end
function M.LockID() return M.Locked() and lock.id or nil end
function M.LockSource() return M.Locked() and lock.source or nil end
function M.StartLock(id, source)
	lock.gen = lock.gen + 1
	local gen = lock.gen
	lock.deadline, lock.id, lock.source = GetTime() + 1, id, source
	C_Timer.After(1, function()
		if lock.gen == gen then
			lock.deadline, lock.id, lock.source = 0, nil, nil
			if ns.Table and ns.Table.RefreshAll then ns.Table.RefreshAll() end
		end
	end)
end
```
`Locked()` being false the moment the deadline passes (even before the timer runs) makes click-ignoring correct if the timer is late; the pressed look follows on the release `RefreshAll`.

### Table side (sketch)
```lua
function Instance:Message(l, from)
	if not l or l.mine or ns.Messages.Locked() then return end
	ns.Messages.Send(l, self.source.preview(), from)   -- starts the lock itself when it auto-sent
	T.RefreshAll()                                     -- FillRow/RefreshButtons now show the press
end
function Instance:Invite(l)
	if ns.Messages.Locked() then return end
	...unchanged...
end
-- row.message OnClick: inst:Message(b:GetParent().listing, "row")   (Table.lua:864-866)
-- self.send OnClick:   self:Message(ShownSelection(self), "send")   (Table.lua:1581-1583)
```

### Key button recipe
```lua
local b = W.Button(parent, key.label, 60, 22, nil)       -- label "[TGF]" for the addon key, else the key text
b:SetNormalFontObject("GameFontNormalSmall")
b:SetDisabledFontObject("GameFontDisableSmall")
b:SetText(key.label)                                       -- after the font object so the width is measured with it
b:SetWidth(b:GetFontString():GetStringWidth() + 24)       -- G32
```
The `UIPanelButtonNoTooltipTemplate` sets `fitTextWidthPadding = 40` for `FitToText`; we do not use it (spec padding is 24).

## State of the Art

| Old Approach | Current Approach | Impact |
|--------------|------------------|--------|
| Single-line `InputBoxTemplate` for presets | `InputScrollFrameTemplate` | 3 lines visible, char count, wraps |
| Side tab never unchecked | `SetChecked(false)` + `UpdateTabs` hook | Parity with the three stock tabs |
| `{gs}` key and "Placeholders:" footer | Key buttons with tooltips | Discoverable keys, no GS |
| Lock-less contact buttons | 1 s contact lock with pressed look | Anti-spam (LOCK-01..03) |

**Deprecated/outdated:** none relevant. `SendChatMessage` global is a deprecated alias of `C_ChatInfo.SendChatMessage` (`Deprecated_ChatInfo.lua:8`); keep the existing `C_ChatInfo` first, global second.

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | `SetButtonState("NORMAL")` (lock omitted/false) unlocks a button previously locked with `SetButtonState("PUSHED", true)` (WoW wiki semantics from training; not in the Blizzard Lua source) | Pattern 1 | Button stays pushed after the second; mitigate by calling `SetButtonState("NORMAL", false)` explicitly. In-game check |
| A2 | Order of `OnMouseUp` and `OnClick` for a click on a Button | Pitfall 1 | None if the `OnMouseUp` post-hook is used (design is order-independent); otherwise the press might flash back to Up |
| A3 | `Enable()` fires `OnEnable` only on a real disabled->enabled transition | Pitfall 7 | If it fires every call, the post-hook still restores the art; only a visual flicker risk |
| A4 | Clicking a non-edit button does not clear an EditBox's focus; `EditBox:Insert` inserts at the stored cursor even when unfocused | Key button recipe | Key text could land at the wrong place; mitigated by `SetFocus()` after insert and an in-game check |
| A5 | Real `EditBox:Insert` calls `OnTextChanged` (user flag unspecified) | Pattern 2 | Mitigated: key-button handler saves explicitly after `Insert` instead of relying on the hook |
| A6 | `GetNumGroupMembers()` counts raid members in a raid group (not just the party) | D-03 | `{players}` would read the raid size; acceptable (stock does the same, `PVPFrame.lua:749`) |

## Open Questions

1. **Where does `version` live?**
   - Known: D-18 says `db.version` inside the Messages module (`db = saved.messages`); `ns.db.schema = 1` already exists in Core.
   - Unclear: nothing blocking.
   - Recommendation: `saved.messages.version` (absent = 1), written to 2 at the end of `M.Init`.
2. **Does the pressed look need to survive `W.Button`'s fallback art?** Only matters where `UIPanelButtonTemplate` is missing (preview on odd clients). Recommendation: implement `Left/Middle/Right` path; fallback relies on button state + a `SetPushedTexture` colour added in `W.Button`'s fallback branch.
3. **Gold tooltip title** (Pitfall 10): extend `W.Tooltip` or keep white. Recommendation: extend.

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| Node.js + fengari (smoke harness) | Verification | yes | `node_modules/fengari` in the scratchpad harness dir | — |
| `stylua` | Workflow rule (`stylua .` after each task) | assumed installed (project rule) | — | — |
| Forever client (`_forever_`) | In-game UAT | author only | — | Smoke harness + `/tgf` preview |
| Blizzard source (`wow-ui-source`, branch `forever`) | Reference | yes (read-only) | — | — |

**Missing dependencies with no fallback:** none for planning; in-game checks are deferred to the author (STATE.md).

## Validation Architecture

> `workflow.nyquist_validation` is `false` in `.planning/config.json`; the section is included because the run brief asks for it explicitly.

### Test Framework
| Property | Value |
|----------|-------|
| Framework | Custom fengari (Lua 5.3 in Node) smoke harness with WoW stubs (not a unit-test framework) |
| Location | `C:/Users/jonat/AppData/Local/Temp/claude/3a677a53f55271b6/8039163f-18e8-4930-88a2-d8efcca63b25/scratchpad/smoke/` (outside the repo): `run.js`, `harness.lua` (stubs + checks), `tail.lua` (the checks section), `splice.js` |
| Quick run command | `node run.js C:/Users/jonat/Repositories/TerribleGroupFinder` (from the harness dir) |
| Full suite command | the same with each flag: `--gs`, `--fallback`, `--attach` (all four currently report `SUMMARY: 0 failed`; 397 / 363 / 300 / 412 PASS lines) |

### How the harness works (for adding checks)
- `run.js` creates a fengari state, reads `TerribleGroupFinder.toc`, passes `REPO`, `FILELIST` (TOC `.lua` paths) and `FLAGS` (e.g. `--attach`) as globals, runs `harness.lua`.
- `harness.lua` = stubs (everything up to the line `local fail = 0`) + the checks. `tail.lua` is the checks section; `splice.js` replaces everything from `local fail = 0` in `harness.lua` with `tail.lua`. **Edit stubs in `harness.lua` above that marker; edit checks in `tail.lua`, then run `node splice.js`.**
- Frames: `newFrame(kind, name)` returns a table with a metatable whose `__index` makes any `Set*/Get*/Is*/Enable*/Disable*/Clear*/Register*/Hook*/Create*/Add*/Show*/Hide*/Insert*/Update*/Select*...` method a chainable no-op; a set of real methods is `rawset` (SetText/GetText, SetChecked/GetChecked, SetEnabled/IsEnabled, Enable/Disable, SetScript/GetScript, SetPoint, `GetStringWidth = 6 * #text`, `GetCursorPosition = 0`, ...). Frames are logged in `log.allFrames`; `log.texts` holds every `SetText`; `log.sounds`, `log.tips`, `log.tipLines`, `log.hooks`, `log.events`, `log.atlases`.
- `CreateFrame(kind, name, parent, template)` records `__template`, runs `decorate(f, tmpl)` which adds template children for known templates (WowScrollBoxList, UIMenuButtonStretchTemplate, MinimalScrollBar, LFGBrowseSearchEntryGroupingTemplate). `KNOWN` + `C_XMLUtil.GetTemplateInfo` control what `TemplateKnown` reports.
- Timers: `C_Timer.After(t, fn)` pushes `{t, fn}` onto the local `timers` list; `log.flushTimers(max)` runs them FIFO ignoring the delay. `GetTime = os.clock` (real clock).
- Chat/party: `C_ChatInfo = { SendChatMessage = noop, InChatMessagingLockdown = false }`, `C_PartyInfo = { InviteUnit = noop }`, `GetNumGroupMembers = 0`, `IsInGroup = false`, `UnitIsGroupLeader = true`, `issecretvalue = false`, `PlaySound` logs to `log.sounds`. Tests replace these globals with recorders and restore them (see the WR-04 probe pattern).
- Helpers in the checks: `check(cond, msg)` (prints PASS/FAIL, counts failures), `probe(name, fn)` (pcall wrapper that fails on error), `Frames(inst)`, `ItemOf`, `mkSolo/mkGroup`. The program ends with `SUMMARY: N failed` and a non-zero exit when N > 0.
- Modes: default (GS off, preview), `--gs` (sets `ns.GEAR_SCORE = true` after Core loads), `--fallback` (no ScrollBox API, W.List path), `--attach` (stubs `LFGParentFrame`, `LFGBrowseFrame`, `LFGListingFrame`, `LFGWhoListFrame`, so `InPlace.Attach` and `AddMessagesTab` run).
- The saved DB is seeded before load: `TerribleGroupFinderDB = { messages = { request = { text = OLD_REQ } }, gs = seedGS }`; `Messages.Init(saved)` takes any table, so migration cases call `ns.Messages.Init(customSaved)` directly and finish with `ns.Messages.Init(TerribleGroupFinderDB)` to restore.

### Stub gaps the new checks need (add above `local fail = 0`)
| Gap | Why | Change |
|-----|-----|--------|
| `HookScript` does not chain (`self.__scripts[n] = self.__scripts[n] or fn`) | Checks must run template-then-hook order, and `W.SetPressed` hooks `OnMouseUp/OnShow/OnEnable` | Keep a separate `__hooks[n]` list and a helper `fire(frame, script, ...)` that runs the `SetScript` function then the hooks; leave existing behaviour for scripts nothing else uses |
| `hooksecurefunc(table, name, fn)` only records `{a,b,c}` in `log.hooks` | UpdateTabs check | Either call the recorded `fn` directly in the check, or wrap `a[b]` in the stub (give the attach `LFGParentFrame` an `UpdateTabs` function that checks the stock tabs) |
| `GetTime = os.clock` | Lock needs a controllable clock | `local now = 0; G.GetTime = function() return now end` plus `log.advance(dt)`; Messages must call the global at runtime |
| `EditBox` has no text/cursor model (`GetCursorPosition = 0`, `SetCursorPosition/Insert` no-ops) | Key insert at cursor, `[TGF]` to front | For kind `EditBox`: `__cursor`, real `Insert` (splice at cursor, advance, fire `OnTextChanged`), `SetCursorPosition`, `GetCursorPosition`, `SetMaxLetters/GetMaxLetters`, `GetNumLetters`, `SetFocus/ClearFocus/HasFocus` recording, `SetText` firing `OnTextChanged(self, false)` |
| `decorate` has no `InputScrollFrameTemplate` | Box path | Add `EditBox` (an EditBox frame), `CharCount` (FontString), `ScrollBar`; add the name to `KNOWN` (and leave it out in `--fallback`-style probes to test the single-line fallback) |
| `UIPanelButtonTemplate` has no `Left/Middle/Right`; `SetButtonState/GetButtonState` are chainable no-ops; `SetTexture` is a no-op | Pressed look | `decorate` for `UIPanelButtonTemplate`: three textures with a recording `SetTexture`; `rawset` `SetButtonState(state, lock)` storing `__state/__locked` and `GetButtonState` |
| `UICheckButtonTemplate` has no `Text` | Disabled label font | `decorate`: `f.Text = newFrame("FontString")` with a recording `SetFontObject`/`GetFontObject`; `SetMotionScriptsWhileDisabled` recorder |
| `LargeSideTabButtonTemplate` has no `Icon` or `SetFillToInterior`; `SetChecked` stub is the generic one | UIP-01 | `decorate`: `Icon` texture, `SetFillToInterior` recorder, `SetChecked` already stored in `__checked` (note the `Frame` kind uses the same stub) |
| `--attach` `LFGParentFrame` lacks `ListingTab` | `ShowMessages` iterates `ListingTab/BrowsingTab/WhoListingTab` | Add `ListingTab` kid (BrowsingTab and WhoListingTab already exist) |
| `print` | Preview send lines | Temporarily replace `print`/`ns.Print` capture in the check |

### Existing checks that will break and must be rewritten (`tail.lua`)
- `--gs` block (~lines 33-38): `TOKENS has {gs}`, "placeholder help lists {gs}", `{gs} is filled when on`. After D-01 there is no `{gs}` in any mode; replace with "key list has no `{gs}`; `Format(..., "{gs}")` stays literal even with `ns.GEAR_SCORE = true`".
- GS-off block (~lines 83-105): `Placeholders:` text, `TOKENS`, `NEW_REQ` default (`Hi {name}! ...`), "old default request migrated" (the seeded `OLD_REQ` now migrates to the new default `{addon} Level {level} {class}, for {activity}`), "typed {gs} stays literal" (keep, still true), "no UI text mentions GS" (still valid: the new texts contain no `GS`).
- Any check relying on `M.Get` returning exactly two values keeps working if `autoInvite` is a third return.

### Phase Requirements -> Test Map
| Req ID | Behavior | Test Type | Automated check (add to `tail.lua`) | In-game UAT item |
|--------|----------|-----------|--------------------------------------|------------------|
| MSG-01 | Request default renders `[TGF] Level 23 Warrior, for The Deadmines` | smoke | `Format("request", PreviewListing 1 activity "The Deadmines")` equals the string; `DEFAULTS.request == "{addon} Level {level} {class}, for {activity}"` | Whisper a group leader: message reads as above |
| MSG-02 | Invite default renders `[TGF] Group for <act> with <n> players`; n = group size | smoke | Solo preview -> `... with 1 players`; `ns.state.asLeader = true` -> party size; non-preview with `GetNumGroupMembers` stubbed 0 -> 1, 3 -> 3 | Solo and in a party: example line and whisper show the right n |
| MSG-03 | Key button inserts at cursor | smoke | Build panel; set box text `"ab"`, cursor 1; click `{name}` button -> text `"a{name}b"`, cursor after, focus set, `DB` saved; 7 key buttons per preset, `[TGF]` first, labels = keys | Click each key with the cursor mid-text; focus stays |
| MSG-04 | `[TGF]` first, once | smoke | `Normalize` cases: `"hi {addon} there"`, `"a [TGF] b [TGF]"`, `"{addon}{addon}x"`, `""`, only-key; `Format` output starts with `[TGF]` once; `[TGF]` button moves it to front and is a no-op when first; focus-lost handler normalises stored text | Type `[TGF]` mid-text, leave the box: it moves to the front |
| MSG-05 | Auto-invite gating | smoke | Auto-send off -> `autoInvite:IsEnabled() == false`, unchecked, `Text.__font == "GameFontDisableSmall"`, saved `autoInvite == false`; on -> enabled, unchecked; toggling off while checked unchecks + saves false; `M.Set` and `M.Init` with `{auto=false, autoInvite=true}` never report true | Disabled look; hover shows "Turn on Auto-send first." (needs `SetMotionScriptsWhileDisabled`) |
| MSG-06 | Whisper then invite | smoke | Recorders: order `SendChatMessage` then `InviteUnit`, both with the plain name; no invite when `ns.CanInvite()` false (non-preview, in group, not leader); no invite for groups; `invited` and `messaged` marks | One click on a solo player: whisper and group invite arrive |
| LOCK-01 | Lock 1 s | smoke | After an auto-send: second click on same row, another row, bottom Send Message and bottom Group Invite do nothing (no recorder calls, no `PlaySound`, no prefill); advance clock 1 s + `flushTimers()` -> click works again; late timer: advance clock without running the timer -> `Locked()` false | Rapid double click sends once |
| LOCK-02 | Pressed look | smoke | Clicked row button: `__state == "PUSHED"`, `__locked`, art textures = `...Down`; other rows normal; after release all `NORMAL`/`Up`; `FillRow` recycle: re-fill the row with another listing -> not pressed, with the locked one -> pressed | Looks pressed for ~1 s; scrolling does not move the pressed look to another row |
| LOCK-03 | Bottom Send Message same path | smoke | Select a listing, click `inst.send`: same recorders as the row path, lock source `"send"`, `inst.send` pressed, rows not pressed | Same message and lock from the bottom button |
| LOCK (D-11/D-15) | Lockdown and prefill | smoke | `InChatMessagingLockdown = true` with auto on: no send, no invite, no lock, prefill called (stub `ChatFrameUtil.SendTellWithMessage`); prefill (auto off) and Group Invite start no lock | In lockdown the whisper box opens with the text |
| D-17 | Outside the lock | smoke | During the lock: delist, hide, select, sort callbacks still work | — |
| D-18 | Migration | smoke | `Init({messages={invite={text=OLD_INVITE},request={text=PROTO_REQ}}})` -> new defaults, `version == 2`; custom text kept; second `Init` after the player resets nothing; GS-era request replaced | Upgrade a profile with old defaults |
| UIP-01 | Tab | smoke (`--attach`) | Tab created from `LargeSideTabButtonTemplate`; `__checked == false` after creation; `SetFillToInterior(true)` called (or fallback size 30); `tooltipText == "Messages"`; no `OnEnter` hook added (tooltip hook gone); `ShowMessages` via custom mouse-up handler checks it and unchecks the three; recorded `UpdateTabs` hook, while Messages shown, unchecks stock tabs; hidden -> does nothing | New tab starts unselected; icon fills like the others; listing update while Messages open keeps only Messages checked |
| UIP-11 | Panel | smoke | `BuildPanel` in game host and stand-in creates the layers (atlas names logged in `log.atlases`: `groupfinder-background`, `groupfinder-Stat-StoneBG`, `common-insideframe`, `groupfinder-ScrollLine`); box via `InputScrollFrameTemplate` (`SetSize` before `EditBox:SetWidth(w-18)`, `SetMaxLetters(255)`), fallback single-line when template unknown; Enter handler present; newline stripped; checkboxes via `UICheckButtonTemplate`; copy strings from UI-SPEC present in `log.texts` | Visual comparison with the Who tab; 3 lines + char count fit in the 56 px box; key rows under 410 px |

### Sampling Rate
- **Per task commit:** `node run.js <repo>` (default mode) + `stylua .`
- **Per wave merge:** all four modes (`""`, `--gs`, `--fallback`, `--attach`), each must end `SUMMARY: 0 failed`
- **Phase gate:** four modes green, then the in-game UAT list (`04-HUMAN-UAT.md`) for the author

### Wave 0 Gaps
- [ ] Stub extensions in `harness.lua` (table above) - must land before any new check can pass
- [ ] Rewrite of the outdated `--gs` / GS-off Messages checks (list above)
- [ ] New check block in `tail.lua` for each row of the map; re-run `node splice.js` after editing `tail.lua`
- [ ] `04-HUMAN-UAT.md` stub with the in-game items (author-run): pressed look appears and clears; hover tooltip on a disabled Auto-invite; tab icon fit (Q4); key-row widths and 56 px box fit; ScrollLine divider; Enter/Escape/paste behaviour in the multi-line box; `OnMouseUp`/`OnClick` ordering (press does not flash back)

## Security Domain

`security_enforcement` is not set to false; the surface here is small.

### Applicable ASVS Categories
| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication / V3 Session | no | — |
| V4 Access Control | yes (game-side) | Only send/invite from user clicks; respect `InChatMessagingLockdown`; invite only when `ns.CanInvite()` (Forever's own rule) |
| V5 Input Validation | yes | Strip newlines, cap at 255 (`maxLetters` + `sub(1,255)` after rendering), unknown keys stay literal, Lua patterns escaped (`%[TGF%]`) |
| V6 Cryptography | no | — |

### Known Threat Patterns
| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| Whisper/invite spam (accidental double click, runaway clicks) | Denial of service (on other players) | 1 s lock after an auto-send, deadline-based so it holds if the timer is late |
| Automated chat during restricted state | Tampering | Never `SendChatMessage` in `InChatMessagingLockdown()`; prefill instead; no invite then |
| Taint spreading into Blizzard's finder | Elevation | Only own frames; `Hide/HookScript/hooksecurefunc/SetChecked` on Blizzard's; restricted calls (`Search`, `CreateListing`, `UpdateListing`) untouched |
| Secret values in names/counts | Information disclosure / errors | `issecretvalue` guards (names come via `Listings.lua`, which skips secret listings) |
| Control characters/newlines in a stored preset | Tampering | Newline strip in the box; `Format` output cut to 255 |

## Sources

### Primary (HIGH confidence) - read in `C:\Users\jonat\Repositories\wow-ui-source`, branch `forever`
- `Interface/AddOns/Blizzard_SharedXML/Shared/InputBox/InputBoxTemplates.xml:72-176` and `.lua:1-135` - `InputScrollFrameTemplate`, `InputScrollFrame_OnLoad` (:82), `OnTextChanged` (:107), `OnEscapePressed` (:127), CharCount semantics
- `Interface/AddOns/Blizzard_SharedXML/Mainline/SharedUIPanelTemplates.xml:1008-1067` and `.lua:312-445` - `LargeSideTabButtonTemplate`, `SidePanelTabButtonMixin` (`SetFillToInterior` :377, `UpdateIconInterior` :383, `SetChecked` :391, `OnEnter` :408, `SetCustomOnMouseUpHandler` :373)
- `Interface/AddOns/Blizzard_SharedXML/SecureUIPanelTemplates.xml:39-80` and `.lua:36-79` - `UIPanelButtonNoTooltipTemplate` art swapping; `Mainline/SharedUIPanelTemplates.xml:315` `UIPanelButtonTemplate`
- `Interface/AddOns/Blizzard_SharedXML/Shared/Button/CheckButtonTemplates.xml:50-63` - `UICheckButtonTemplate` (`Text` plain FontString, `DisabledCheckedTexture`)
- `Interface/AddOns/Blizzard_GroupFinder_VanillaStyle/Blizzard_LFGVanilla_ParentFrame.lua:56-104` and `Mainline/Blizzard_LFGVanilla_ParentFrame.xml:21-24,31,95-135` - `UpdateTabs`, tab template, `fillToInterior`, tab anchors
- `Interface/AddOns/Blizzard_GroupFinder_VanillaStyle/Mainline/WhoList.xml:102-137` - panel layers
- `Interface/AddOns/Blizzard_GroupFinder_VanillaStyle/Mainline/Blizzard_LFGVanilla_Listing.xml:564-585,602-633` - stock checkbox and secure comment box
- `Interface/AddOns/Blizzard_APIDocumentationGenerated/`: `ChatInfoDocumentation.lua:293,564`, `PartyInfoDocumentation.lua:357`, `SimpleButtonAPIDocumentation.lua:151,293,403`, `SimpleEditBoxAPIDocumentation.lua:446,646,759,769,779`, `UITimerDocumentation.lua:11`, `SimpleFontStringAPIDocumentation.lua:580`
- `Interface/AddOns/Blizzard_ChatFrameBase/Shared/ChatFrameUtil.lua:367`; `Blizzard_DeprecatedChatInfo/Deprecated_ChatInfo.lua:8`; `Blizzard_UIPanels_Game/Cata/PVPFrame.lua:749` (`max(GetNumGroupMembers(), 1)`)
- Repo: `Messages.lua`, `Core.lua`, `UI/Table.lua` (:661-705, :864-866, :1079-1082, :1160-1170, :1312-1317, :1581-1587), `UI/InPlace.lua` (:99-173), `UI/MainFrame.lua` (:351-372), `UI/Widgets.lua` (:266-402)
- Smoke harness: `run.js`, `harness.lua`, `tail.lua`, `splice.js` (scratchpad `smoke/`); all four modes run green at research time

### Secondary (MEDIUM confidence)
- `.planning/research/UI-PARITY.md` G1-G4, G30-G34, D6-D9 (project's own earlier audit, consistent with the source reads above)

### Tertiary (LOW confidence)
- WoW wiki semantics for `SetButtonState` locking, click event ordering, `Enable()` firing `OnEnable` (training knowledge; see Assumptions A1-A3)

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH - all templates/APIs read in the `forever` source
- Architecture: HIGH - follows existing `Instance:Message` / `FillRow` / `RefreshButtons` structure and the stated taint rules
- Pitfalls: HIGH for the three template findings (source-verified); MEDIUM for runtime ordering (in-game checks listed)

**Research date:** 2026-11-11
**Valid until:** 30 days (stable Blizzard templates; re-check only if Forever's UI branch updates)
