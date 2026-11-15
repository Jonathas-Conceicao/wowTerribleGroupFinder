# Phase 4: Messages and Contact - Context

**Gathered:** 2026-11-11
**Status:** Ready for planning
**Mode:** `--auto` (author AFK; every gray area auto-resolved with the recommended option, see `04-DISCUSSION-LOG.md`). The author's milestone brief fixed most of the behaviour; it is copied here as locked decisions.

<domain>
## Phase Boundary

Players contact others in one click from sensible default presets, with Auto-send and Auto-invite,
and cannot spam: new default presets with an `[TGF]` addon key, one button per key under each
preset box (inserts at the cursor; the addon key always first, at most once), Auto-send then
Auto-invite on the invite preset (Auto-invite only while Auto-send is on), a 1 s contact lock with
a "sending" pressed look after any auto-send click, a one-time migration of saved old defaults,
the Messages side tab made stock-correct (UIP-01) and the Messages panel rebuilt with the Who
tab's frame layers, multi-line boxes and native checkboxes (UIP-11).

Requirements: MSG-01..06, LOCK-01..03, UIP-01, UIP-11.
(In `research/UI-PARITY.md`: G1-G4 = UIP-01; G30-G33 = UIP-11; D6, D7.)

Not in this phase: localization of the hardcoded English labels, a better side-tab icon than
`INV_Letter_15` (in-game check Q4), the right-click menu (G25), gear score (stays off).

</domain>

<decisions>
## Implementation Decisions

### Presets and keys (MSG-01, MSG-02, MSG-04)
- **D-01:** Keys: `{addon}`, `{name}`, `{activity}`, `{class}`, `{level}`, `{role}`, `{players}`.
  `{gs}` is removed from Messages entirely (no `MyGS`, no `ns.GEAR_SCORE` branch in Messages; the
  `Core.lua` gear-score comment is updated to drop the `{gs}` mention). An unknown key (e.g. a
  saved `{gs}`) renders literally, so the player sees it in the example line.
- **D-02:** Defaults (stored with the `{addon}` key, rendered `[TGF]`):
  - request: `{addon} Level {level} {class}, for {activity}` → `[TGF] Level 23 Warrior, for The Deadmines`
  - invite: `{addon} Group for {activity} with {players} players`
- **D-03:** `{players}` = your current group size counting yourself (`GetNumGroupMembers()`,
  at least 1; solo = 1). Preview: `#ns.Party()` (1 solo, the sample party size while "as leader").
  `{role}` stays (your roles, as today). `{name}` stays (the whisper target).
- **D-04:** `{addon}` renders `[TGF]` (constant `M.ADDON_KEY = "[TGF]"`). Normalisation
  (`M.Normalize(text)`): every `{addon}` and every literal `[TGF]` is removed, and if there was at
  least one, a single `{addon} ` is put at the very start (surrounding whitespace collapsed). It runs
  in `Format` (rendered text always correct), when the box loses focus and on a key-button insert
  (stored text keeps the key first). It does not run on every keystroke (no cursor jumps).
- **D-05:** The rendered whisper is cut to 255 characters (chat limit); the raw preset keeps
  `maxLetters` 255 as today.

### Key buttons (MSG-03)
- **D-06:** Under each preset's box, one row of buttons, one per key, labelled with the key
  itself (`{name}`, `{activity}` ...); the addon key's button reads `[TGF]` and comes first. Both
  presets show the same key set (every key resolves in both).
- **D-07:** A key button inserts the key at the cursor (`EditBox:Insert`), then `SetFocus()` and
  saves; the `[TGF]` button puts `{addon} ` at the front (no-op if already first), keeps the
  cursor after it and saves the normalised text. Tooltip on each key button: what the key
  becomes (e.g. "Your level", "Your current group size, counting you").

### Auto-send and Auto-invite (MSG-05, MSG-06)
- **D-08:** The invite preset has two checkboxes in order: Auto-send, then Auto-invite. The
  request preset has Auto-send only. Saved as `db.invite.autoInvite` (boolean, default false).
- **D-09:** Auto-invite is enabled only while Auto-send is checked. Unchecking Auto-send also
  unchecks Auto-invite (saved false) and disables it: `Disable()` + label `GameFontDisableSmall`.
  Checking Auto-send again enables Auto-invite but leaves it unchecked. `M.Get` / saved state can
  never report autoInvite true with auto false (enforced in `M.Set` and `M.Init`).
- **D-10:** Sequence on a contact click for a solo listing with Auto-send + Auto-invite on: the
  whisper is sent, then — in the same click — `C_PartyInfo.InviteUnit(plain name)` when
  `ns.CanInvite()` (Forever's own invite rule; else whisper only). Marks `messaged` and `invited`.
- **D-11:** Auto-invite fires only after a real auto-send. During
  `C_ChatInfo.InChatMessagingLockdown()` the whisper is prefilled (never sent) and no invite is
  sent; no lock starts (nothing was sent).
- **D-12:** Contact paths that honour the presets: the row Whisper button and the bottom Send
  Message (LOCK-03, the same `Instance:Message` → `ns.Messages.Send` path). Group rows use the
  request preset (no invite). The bottom Group Invite stays a plain invite (no whisper).
- **D-13:** Row Whisper label stays "Whisper" on every row (it always whispers; the invite is
  extra). Preview: auto-send prints the whisper and, with Auto-invite, the would-invite line.

### Contact lock (LOCK-01, LOCK-02, LOCK-03)
- **D-14:** The lock lives in `Messages.lua` (`M.Locked()`, `M.LockedBy(button)` or equivalent),
  1 s from the moment of an auto-send (`GetTime()` deadline + `C_Timer.After(1, release)`; the
  `GetTime()` check makes the lock correct even if the timer is late).
- **D-15:** Only a click that actually auto-sends starts the lock (prefill clicks and plain Group
  Invite clicks don't). While locked, the handlers of every row Whisper, the bottom Send Message
  and the bottom Group Invite return at once (no sound, no whisper, no invite, no prefill). Their
  look is not changed (no disabling flicker across the list).
- **D-16:** "Sending" look: the clicked button gets `SetButtonState("PUSHED", true)` for the second,
  then `SetButtonState("NORMAL")` on release. The send itself is instant (before the press).
  ScrollBox recycling: `FillRow` re-applies the state — pressed only on the row frame now showing
  the locked listing id (row button) — and the bottom Send Message is restored by release /
  `RefreshButtons`. Release calls `T.RefreshAll()` so enabled states are recomputed.
- **D-17:** Outside the lock: the delist button, the hide (X) button, selection, sorting, the
  search box, and the Messages panel's own buttons.

### One-time migration
- **D-18:** Following phase 1's pattern (`OLD_REQUEST` compare in `M.Init`), with a version marker
  so it runs once: `db.version` (absent = 1). On load with version < 2: a preset whose text equals
  any previous default for its kind (invite: the prototype invite default; request: the prototype
  request default and the old GS request default) is replaced by the new default; custom texts are
  kept untouched. Then `db.version = 2`. Changes made later by the player are never touched again.

### Messages side tab (UIP-01)
- **D-19:** `messagesTab:SetChecked(false)` right after creation (G1); `fillToInterior` on (G2:
  `SetFillToInterior(true)` where present, else the field before the first `SetChecked`; keep the
  30x30 + texcoord fallback); `hooksecurefunc(LFGParentFrame, "UpdateTabs", fn)` unchecks the three
  stock tabs while Messages shows (G3) — reading only, `SetChecked` on Blizzard's tab buttons is
  what `ShowMessages` already does (button state, not a field write; see UI-PARITY D9); tooltip:
  `tooltipText = "Messages"` only, the `W.Tooltip` hook is dropped (G4).
- **D-20:** Icon stays `Interface\Icons\INV_Letter_15` (in-game check Q4).

### Messages panel (UIP-11)
- **D-21:** In game and in the preview stand-in the panel uses the Who tab's layers (G33):
  stone band `groupfinder-Stat-StoneBG` (2,-21) down to the art top -7; art `groupfinder-background`
  (4,-80)/(-4,3); border `common-insideframe` (3,-78)/(-4,3); `groupfinder-ScrollLine` at the art top
  -20 and bottom +42 as WhoList where it fits; colour fallbacks where atlases are missing. Title
  `LFG_TITLE`. The intro text sits in the stone band; the presets inside the inset.
- **D-22:** Preset boxes: `InputScrollFrameTemplate` (non-secure), ~3 lines tall, char count
  shown, `maxLetters` 255; size set first then `EditBox:SetWidth(w-18)`; Enter clears focus;
  newlines stripped (paste). Fallback: the current single-line `W.EditBox`.
- **D-23:** Per preset, top to bottom: title (+ help), box, key-button row (G32:
  `UIPanelButtonTemplate` 22 tall, width = text width + 24, `GameFontNormalSmall`), checkboxes
  (`W.Check`: `UICheckButtonTemplate` 26x26 with its own `.Text` and ON/OFF sounds — already in
  place), "Default" button (`UIPanelButtonTemplate`, 22 tall) on the right, example line. Exact
  offsets: UI-SPEC.
- **D-24:** Intro / help texts updated for Auto-invite and the 1 s lock; the old "Placeholders:"
  footer is replaced by the key buttons (each has a tooltip).

### Testing
- **D-25:** Smoke harness checks: default rendering (request `[TGF] Level 23 Warrior, for The
  Deadmines`, invite with `{players}` 1 solo / party size), `Normalize` (addon key moved first,
  deduped, literal `[TGF]`), key insert at cursor and `[TGF]` button to front, Auto-invite gating
  (disabled + unchecked with Auto-send off, saved false), auto-send + invite sequence order
  (SendChatMessage then InviteUnit, plain name), no invite without `CanInvite`, the 1 s lock (stub
  `GetTime` / `C_Timer.After`: second click ignored, other row and bottom buttons ignored, pressed
  state, released after the timer), lockdown prefill (no send, no invite, no lock), migration
  (old defaults → new once, custom kept, version marker), tab unchecked at creation and after
  `UpdateTabs`. All harness modes end with 0 failed.

### Claude's Discretion
- Exact offsets, box height and spacing (UI-SPEC).
- D-06 layout: seven key buttons don't fit one 410 px row, so the UI-SPEC puts them in two rows
  (`[TGF] {name} {activity} {players}` / `{class} {level} {role}`); every key still has its button.
- Whether the lock helper lives in Messages.lua or a small block in Table.lua (default: Messages.lua).
- Key-button tooltip wording.
- Discuss step did not chain into plan-phase automatically: the orchestrating run executes
  ui-phase before plan-phase, as instructed.

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Project rules and research
- `CLAUDE.md` — Forever-only, in place, taint rules, lockdown rule, plain-name whisper/invite, stylua, no sed on .md
- `.planning/research/UI-PARITY.md` — G1-G4, G30-G34; D6 (side tabs, Messages panel), D7 (panel controls), D8 (Enter/ESC, sounds), D9 (taint notes); Q4
- `.planning/REQUIREMENTS.md` — MSG-01..06, LOCK-01..03, UIP-01, UIP-11
- `.planning/phases/02-list-foundation/02-UI-SPEC.md`, `.planning/phases/03-rows-tooltip-and-own-listing/03-UI-SPEC.md` — UI conventions to reuse
- `.planning/phases/03-rows-tooltip-and-own-listing/03-CONTEXT.md` — row buttons, delist/hide outside the lock
- `.planning/STATE.md` — Phase 4 inputs under Blockers/Concerns

### Blizzard source (C:\Users\jonat\Repositories\wow-ui-source, branch forever, read-only)
- `Interface/AddOns/Blizzard_GroupFinder_VanillaStyle/Blizzard_LFGVanilla_ParentFrame.lua` — `UpdateTabs` :56-71, tab setup :96-104
- `Interface/AddOns/Blizzard_GroupFinder_VanillaStyle/Mainline/Blizzard_LFGVanilla_ParentFrame.xml` — side tabs, fillToInterior :21-24
- `Interface/AddOns/Blizzard_GroupFinder_VanillaStyle/Mainline/WhoList.xml` — panel layers :102-137
- `Interface/AddOns/Blizzard_GroupFinder_VanillaStyle/Mainline/Blizzard_LFGVanilla_Listing.xml` — checkbox :564-585, comment box :602-633
- `Interface/AddOns/Blizzard_SharedXML/Shared/InputBox/InputBoxTemplates.xml:72-176` — `InputScrollFrameTemplate`
- `Interface/AddOns/Blizzard_SharedXML/Mainline/SharedUIPanelTemplates.lua:361-419` — side tab mouse-up, icon interior, tooltip
- `Interface/AddOns/Blizzard_SharedXML/Shared/Button/UIPanelButtonTemplates.xml` — `UIPanelButtonTemplate`

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `Messages.lua` — `M.Init` (phase 1 one-time `OLD_REQUEST` reset), `M.Get/Set/Reset`, `M.Format`, `M.Send` (lockdown → prefill already), `M.BuildPanel`
- `UI/Table.lua` `Instance:Message` (≈661), `Instance:Invite` (≈694), row `row.message` (≈864), `FillRow` (≈1118 resets label), `RefreshButtons` (≈1312), bottom `self.send` / `self.invite` (≈1581)
- `UI/InPlace.lua` `AddMessagesTab`, `ShowMessages`, `HideMessages` (≈100-160)
- `UI/MainFrame.lua` `BuildMessages` (≈353) — the preview panel; mirror the in-game layers
- `UI/Widgets.lua` `W.Check` (template `.Text`, sounds), `W.Button`, `W.EditBox`, `W.Tooltip`, `W.Atlas`, `W.Text`, `W.PlayCheckbox`
- `Core.lua` `ns.CanInvite`, `ns.Party`, `ns.MyRoles`, `ns.PlayerLevel`, `ns.PlayerClass`

### Established Patterns
- Every Blizzard template / atlas is probed with a fallback so the preview renders anywhere
- Whisper / invite by plain character name; never send during chat messaging lockdown (prefill)
- Frames are reused by the ScrollBox: `FillRow` sets every visible state

### Integration Points
- `ns.state.messaged` / `ns.state.invited` marks drive the row's "sent" / "invited" look
- `T.RefreshAll()` after a contact action
- Preview `/tgf` must keep working (stand-in Messages tab)

</code_context>

<specifics>
## Specific Ideas

- Request default renders exactly `[TGF] Level 23 Warrior, for The Deadmines`
- The `[TGF]` key is always first and at most once, whatever the player types
- The "sending" press: clicked button pushed for 1 s, others silently ignore clicks

</specifics>

<deferred>
## Deferred Ideas

- Localising the hardcoded English labels (key tooltips, panel texts)
- A side-tab icon made for the mask (Q4 in-game check)
- Remembering Messages as the open tab (would need writing `selectedTab`, not allowed)

</deferred>

---

*Phase: 04-messages-and-contact*
*Context gathered: 2026-11-11*
