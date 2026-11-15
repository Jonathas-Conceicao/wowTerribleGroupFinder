# Phase 3 — UI Review

**Audited:** 2026-11-11
**Baseline:** 03-UI-SPEC.md (approved), with 03-CONTEXT.md, 03-01..04-SUMMARY.md and 03-VERIFICATION.md. Phase 2's `02-UI-REVIEW.md` is the format reference.
**Screenshots:** not captured. This is a WoW addon with no dev server or browser, so the audit is code-only. Items that need the game client are listed under "Needs in-game confirmation" and mirror the verifier's `human_verification` list. They are not scored as defects.

---

## Pillar Scores

| Pillar | Score | Key Finding |
|--------|-------|-------------|
| 1. Copywriting | 3/4 | Stock globals with English fallbacks throughout the tooltip. The hidden-note wording differs from the contract, and Listed-cell words and button labels are still hardcoded English. |
| 2. Visuals | 3/4 | Micro icons, Discord icon, delist and hide buttons are built to the contract, and frame reuse is handled. The tooltip drops the blank line the contract requires, and the extras block adds blank lines the contract does not have. |
| 3. Color | 3/4 | Contract colours come from the colour globals, with correct fallbacks. Six raw `|cffRRGGBB` sites remain, and one of them (delisted) is the wrong red. |
| 4. Typography | 3/4 | Blizzard font objects only, no size overrides on the happy path. The two-line stack still relies on hand-placed offsets. |
| 5. Spacing | 3/4 | `HIDE_W` 24, `ACTIONS_W` 95, micro step 20, Discord clamp and the delist/hide anchors match the contract. Some magic numbers remain, and the Activity column is tighter by 4 px. |
| 6. Experience Design | 3/4 | Delist is guarded, tooltip refresh is event-driven and avoids the buttons. A non-leader group member gets no delist and no explanation, and the refresh re-owns the tooltip. |

**Overall: 18/24**

No BLOCKER found. Every pillar has WARNING-level findings.

---

## Top 3 Priority Fixes

1. **Tooltip blank-line rules do not match the contract** (WARNING) — `UI/Table.lua:513-517, 570-589`. Block 3/4 to block 6 has no separating blank when the listing has no comment, because the only blank before block 6 is inside the comment branch (`:513-517`). That is the common case for solo players. The contract says a blank follows the leader/members block whenever anything follows. In the other direction, `ExtrasTooltip` adds a blank before the friends header (`:584`) and another before "Listed" (`:588`). The contract has X1 to X5 contiguous after one blank. Result: solo tooltips run the leader line into "Members: 1", and tooltips with friends are taller than designed. Fix: call `tip.blank()` right after the leader/members block (it collapses with the comment's own blank), and remove the two extra blanks in `ExtrasTooltip`. Confirm against the stock tooltip in game.
2. **Raw colour codes survive, and "delisted" uses the wrong red** (WARNING) — `UI/Table.lua:278, 302, 767` (`|cff999999`) and `:1078, 1080, 1082` (`|cffff3333` / `|cff33ff33`). The contract says Delisted is `RED_FONT_COLOR`-equivalent, and `ff3333` is not what the global resolves to (about `ff1919`). The green for "invited" and "sent" is not a contract colour at all. Phase 2 flagged the same pattern and this phase added a new use of it. Fix: route these through `Gray()` and a small `Colored(text, W.RED / W.GREEN)` helper using the existing colour globals, and keep the greyed-row `Plain()` path.
3. **Own row for a non-leader group member shows nothing in the action area, with no explanation** (WARNING) — `UI/Table.lua:1117-1130`. The contract allows "nothing otherwise", and it matches stock. In practice the row reads "Your listing" with no buttons and no hint that the leader owns the listing. Fix: give the own row a tooltip line ("Only your group's leader can unlist") on hover, or carry the explanation in the existing row tooltip. This is cheap because `ShowTooltip` already runs for the own row.

Further issues, lower priority:

4. Leader icon in the tooltip uses `CreateSimpleTextureMarkup("Interface\\GroupFrame\\UI-Group-LeaderIcon", 16, 16)` first (`:486-490`) and the atlas only as a fallback. The contract names the `groupfinder-icon-leader` atlas at 16. The tooltip and the Name cell (`:1020`, which uses the atlas) will show two different leader icons. Prefer the atlas, and fall back to the texture.
5. The hidden-note copy is "Hidden until they make a new listing (use the eye button to show)." (`:591`), while the contract says "(+ to show)". The new wording is better, since the button is an eye now, but it is an undocumented deviation. Update the UI-SPEC copy table rather than the code.
6. `RefreshTooltip` calls `ShowTooltip`, which calls `SetOwner` again (`:600`). That resets the tooltip anchor and can make it blink on every results update while hovering. Check in game; if it shows, rebuild with `GameTooltip:ClearLines()` only when the owner and listing id are unchanged.
7. Delist and hide icon-state setup is split across two duplicated branches in `FillRow` (`:1121-1138`). The delist branch checks only `HasAtlas("groupfinder-icon-redx")` while the hide branch also checks `styled`. A non-styled fallback button would render the atlas inside a `UIPanelButtonTemplate` button. Use one helper with the same rule for both.
8. Hard-coded English remains for the row `Whisper` label, `Hide` / `Show` tooltips, the Listed cell words (`delisted`, `invited`, `sent`), `"%d/%d members"` (`:1059`) and `"Listed N ago"` (`:589`). The spec defers localisation, so this is tracked, not a regression.

---

## Detailed Findings

### Pillar 1: Copywriting (3/4)

Matches the contract:
- The tooltip uses the stock globals with the contract's English fallbacks: `LFG_LIST_ENTRY_DELISTED`, `LFG_LIST_NEW_PLAYER_FRIENDLY_HEADER`, `LEVEL_ABBR`, `LFG_LIST_COMMENT_FORMAT`, `LFG_LIST_TOOLTIP_MEMBERS(_SIMPLE)`, `VOICE_CHAT_MODE_FORMAT` and its four mode labels, `LFG_LIST_INDENT`, `LFG_LIST_BOSSES_DEFEATED`, `LFG_LIST_TOOLTIP_FRIENDS_IN_GROUP` (`UI/Table.lua:368-376, 472-593`).
- Own row label is `LFG_SELF_LISTING` (`:1071`); delist tooltip is `LFG_LIST_UNLIST or "Unlist"` (`:903`).
- Hide and show tooltips carry the contract's "Hide" / "Show" titles and explanation lines (`:895-902`).
- The old "Can play:", "Looking for:", "Members: n/m" and the voice flag in the Listed line are gone.
- Delist has no confirmation, as stock; the code keeps the stock behaviour of no visible error when there is no active entry.

Deviations:
- Hidden note wording differs from the contract (Fix 5).
- Raw English Listed words and button labels (Fix 8). `"Whisper"` on a solo row while you lead is Phase 4's, not scored here.
- Playstyle colour: code is `GREEN_FONT_COLOR`, which matches the UI-SPEC (D-17), but the ROADMAP says light grey. This is an author decision already raised by the verifier. It is not a code defect.

### Pillar 2: Visuals (3/4)

Matches the contract:
- Solo rows use the micro role atlas at an explicit 18 px, step 20, packed from the left in T > H > D order, and desaturated at 0.5 alpha when greyed (`UI/Table.lua:715-727`, `UI/Widgets.lua:412-425`). `SetRole` re-sets the size on every call, so a frame that held a solo row and is reused for a group goes back to 14 px.
- The Discord icon sits at the right of the name text plus 4 px, level with the name line (icon top -3, 16 px, against name top -4), and the name is clamped to 110 px when it shows, so the icon never leaves the 150 px cell (`:1033-1055`). The fallback is the text tag. Greyed rows desaturate it and take alpha 0.5.
- Own row uses the `groupfinder-highlightbar` pair, "Your listing" in light green, no Whisper, no hide button, and the delist button (24 x 22, RIGHT -8, `redx` at atlas size, frame level +2) in its place (`:857-863, 1130-1138`). The Activity cell already reserves `ACTIONS_W`, so nothing shifts.
- Hide button: `UIMenuButtonStretchTemplate` via one builder (`W.IconButton`), 24 x 22, 16 px icon, `UI-Common-MouseHilight` ADD highlight, eye atlases for hide/show, "x" / "+" fallback, and it stays enabled on greyed rows (`UI/Widgets.lua:318-337`, `UI/Table.lua:1121-1129`).
- Tooltip order follows the contract's blocks 1 to 9 and X1 to X5, with activity groups, indents and the 10-member cut-off.

Weaknesses:
- Blank-line rules (Fix 1) and the leader icon source (Fix 4).
- A row still has no focal point other than the selected bar; own row gets its own art and the green label, which helps.
- The Name cell on a group row can show a leader atlas at atlas size next to the name. If the atlas is larger than 16 px it will overlap the name at x = 20 (in-game check).

### Pillar 3: Color (3/4)

- Accent discipline holds: `BRIGHTBLUE` is used only for activity text that matches your active listing (row `:1099`, tooltip `:418-439`). "Your listing" is `LIGHTGREEN`, comment is `LIGHTGRAY`, playstyle is `GREEN`, delisted is `RED`, bosses are red with a gold header (`:472-566`). Fallback RGBs in `UI/Widgets.lua:58-64` match the contract's table.
- Greyed rows take `{0.3, 0.3, 0.3}` on all text including the comment and class-coloured name; `FillRow` restores colours on every fill (`:1088-1107`).
- Defects: six raw `|cff` sites (Fix 2). `Plain()` strips them on greyed rows, so the greying is correct. The leftover issue is hue only.

### Pillar 4: Typography (3/4)

- Fonts follow the contract: `GameFontNormal` (name), `GameFontDisable` (level), `GameFontHighlightSmall` (activity, "Your listing", counts), `GameFontDisableSmall` (sub-line, comment, Listed). The sizes passed to `W.Text` only apply if a font object fails to resolve. Tooltip lines use `AddLine` and `AddDoubleLine` with explicit colour only.
- Remaining roughness: text offsets `-4` / `-19` and the Discord icon's `-3` are tuned by hand and coupled to each other (`:815-817, 840-844, 1047`). A change of the name font would silently misalign the Discord icon. The comment is `GameFontDisableSmall` recoloured on every fill, matching the contract but doubling the colour logic with the greyed path.

### Pillar 5: Spacing (3/4)

- `HIDE_W` is 24 and `ACTIONS_W` is `HIDE_W + 3 + MSG_W + 2` = 95; Whisper is anchored RIGHT of the hide button at -3; hide at RIGHT -2; delist at RIGHT -8 (`UI/Table.lua:37-38, 852-867`). The header uses the same `Layout(..., -(ACTIONS_W + GAP))` (`:1561`), so the column strip stays aligned.
- Name width is bound at 130 (cell 150 less the 20 px class icon), clamped to 110 with the Discord icon: this is the contract's 150 - 16 - 4 in the cell's terms.
- Micro icons 3 x 18 + 2 x 2 = 58 of 92 px, so they fit and never wrap.
- Concerns: the Activity column lost 4 px and was already the tightest column in Phase 2 (Q1 still open). Magic numbers (20/15 icon steps, 32 px cell, 20 px name offset) are spread through `SetRoles` and `BuildRow`.

### Pillar 6: Experience Design (3/4)

Strong:
- Delist re-checks `CanUnlist` on click, requires `HasActiveEntryInfo()` (secret-guarded), calls only `C_LFGList.RemoveListing()`, and does not search or switch tab (`:653-691`). No inheritance of the stock mixin. This follows the taint rules in CLAUDE.md.
- The button is hidden, never disabled, when the player cannot unlist, as the contract says. Clicking it cannot select the row, since own rows ignore clicks (`:871-875`).
- Tooltip refresh is event-driven and rides on `Instance:Refresh`; it skips rows where the mouse is over Whisper, hide or delist, so button tooltips are not overwritten (`:1208-1230`). A row that moved away hides the tooltip.
- Hidden rows keep a working show button; delisted rows keep Whisper disabled (`:1117-1120`).
- Boss lookup is skipped for your own row and preview rows, and is wrapped in `pcall` with a secret guard.

Gaps:
- Fix 3: no explanation for a non-leader member.
- Fix 6: the refresh re-owns the tooltip each time.
- Delist is one click with no confirmation. This is stock behaviour and was agreed in the contract, but combined with the delist button sitting 8 px from the edge of a densely clickable row it is worth watching in game.
- Hide still has no keyboard path (rows are not focusable); unchanged since Phase 2.

---

## Needs in-game confirmation

These are open in 03-VERIFICATION.md and are not scored as defects:
- Atlas existence on the Forever client: `UI-ChatIcon-Discord`, `groupfinder-icon-role-micro-*`, `newplayerchat-chaticon-newcomer`, `groupfinder-icon-leader`, `transmog-icon-hidden`, `socialqueuing-icon-eye`, `groupfinder-icon-redx`.
- Hide icon legibility at 16 px in 24 x 22 (UI-PARITY Q10); micro icons at 18 px square; Discord icon level with the name and truncation at 110 px.
- Group-row leader atlas at atlas size against the name at x = 20.
- Q1: Activity readable at 620 px after the 4 px loss.
- Tooltip order and wording side by side with Forever's own tooltip (to settle Fix 1), and whether re-owning the tooltip on refresh blinks (Fix 6).
- Delist as solo, as leader and as a non-leader member; `/console taintLog 1` while hovering and clicking.
- Playstyle colour (green as built or light grey per the ROADMAP).
- Needs my role on real server remaining-slot data.

---

## Files Audited
- `C:\Users\jonat\Repositories\TerribleGroupFinder\UI\Table.lua`
- `C:\Users\jonat\Repositories\TerribleGroupFinder\UI\Widgets.lua`
- `C:\Users\jonat\Repositories\TerribleGroupFinder\Listings.lua`
- `C:\Users\jonat\Repositories\TerribleGroupFinder\Preview.lua`
- `C:\Users\jonat\Repositories\TerribleGroupFinder\.planning\phases\03-rows-tooltip-and-own-listing\03-UI-SPEC.md`
- `C:\Users\jonat\Repositories\TerribleGroupFinder\.planning\phases\03-rows-tooltip-and-own-listing\03-VERIFICATION.md`
- `C:\Users\jonat\Repositories\TerribleGroupFinder\.planning\phases\02-list-foundation\02-UI-REVIEW.md`
