# Phase 2 — UI Review

**Audited:** 2026-11-11
**Baseline:** 02-UI-SPEC.md (approved), checked against Forever's finder source (`Blizzard_GroupFinder_VanillaStyle`, branch `forever`, read-only)
**Screenshots:** not captured. This is a WoW addon with no dev server or browser, so the audit is code-only. Everything that needs the game client is already tracked in `02-HUMAN-UAT.md` (11 tests, all pending) and is not repeated as a finding here.

---

## Pillar Scores

| Pillar | Score | Key Finding |
|--------|-------|-------------|
| 1. Copywriting | 2/4 | Stock global strings are used where the contract names them, but column labels, tooltips and the row buttons are hardcoded English. The hide button is a bare "x" / "+" glyph. |
| 2. Visuals | 3/4 | Faithful copy of the stock header and row art with atlas fallbacks. The row's only focal point is the selected bar, and the hide control relies on a tooltip. |
| 3. Color | 3/4 | Atlas, Blizzard-global and accent usage match the contract. Several raw `|cffRRGGBB` codes bypass the colour globals. |
| 4. Typography | 3/4 | Blizzard font objects throughout, with no size overrides on the happy path. A few spec deviations and one unverified squeeze. |
| 5. Spacing | 3/4 | Header and row extents, art insets and the bottom row copy stock values. The Activity column is probably narrow, and the geometry is magic numbers in several places. |
| 6. Experience Design | 3/4 | Searching, failed, empty and filtered states are covered, and selection is keyed by ID. Unlist has no confirmation, and Unlist and Hide are visually weak. |

**Overall: 17/24**

---

## Top 3 Priority Fixes

1. **Hardcoded English labels and tooltips bypass localisation** (WARNING) — `Table.lua:54-57,75-76` ("Name", "Lvl", "Roles", "Activity", "Listed"), `:615,839` ("Whisper"/"Unlist"), `:640`, `:1117-1125`, `:351,354,378`. The contract only allows "ours" for specific strings. Non-English clients get a half-translated finder. Fix: use stock globals where they exist (`NAME`, `LEVEL_ABBR`/`LEVEL`, `ROLE`, `ACTIVITY`, `WHISPER`) and pull the remaining "ours" strings into one locals table so they can be localised later.
2. **Unlist is a one-click destructive action beside Whisper** (WARNING) — `Table.lua:454-473, 839`. On your own row the same 66x20 button position that means "Whisper" elsewhere calls `C_LFGList.RemoveListing()` directly, with no confirmation and no distinct styling. A misclick delists you. Fix: a `StaticPopup` confirm, or a visually distinct (red) button. Phase 3 / UIP-08 is already planned to replace it with the stock delist button, so a quick confirm is enough until then.
3. **Activity column may be too narrow at 620** (WARNING, to confirm in game as Q1) — `Table.lua:54-61,535-548`. Activity starts at x=284 and runs to Listed. Listed is 44 wide and the buttons take `ACTIONS_W` = 91, plus two 6 px gaps. That leaves roughly 120-130 px for a 11pt name plus a "+N" suffix and a comment line. Multi-activity names will be cut (`ActivityText` appends `+N` after the name, which is cut first). Fix: confirm in game; if it is tight, narrow Name to about 130 or put the "+N" first, or widen to 660.

Further issues (also real, lower priority):

4. The hide control is a plain "x" / "+" `UIPanelButtonTemplate` button. Its only explanation is a tooltip (`Table.lua:611,640`), and "+" does not read as "show again". Use stock `common-icon-redx` / `common-icon-plus` atlases, with the glyphs as fallback. (The checker already flagged this as non-blocking.)
5. Raw colour codes: `|cff999999` (`:266,290,361,529`), `|cff33ff33` (`:775,801,803`), `|cffff3333` (`:799`). The contract says "colour globals; raw RGB only for the one value stock hard-codes". Use `GRAY_FONT_COLOR`, `GREEN_FONT_COLOR` and `RED_FONT_COLOR`, through the existing `Gray()` helper.
6. `row:Reinitialize()` on every select/deselect (`:634`) re-inits all visible frames. Fine at this size, but it would flicker or reset hover state with a very large list. Reinitialise only the previous and new selected frames through `ForEachFrame`.

---

## Detailed Findings

### Pillar 1: Copywriting (2/4)

Matches the contract:
- Section labels use `LFG_LIST_CATEGORY_SOLO_PLAYERS` / `LFG_LIST_CATEGORY_GROUPS` with a grey count (`Table.lua:80-83,688`).
- Search states use `SEARCHING`, `LFG_LIST_NO_RESULTS_FOUND` and `LFG_LIST_SEARCH_FAILED` (`:927,945,1268`).
- Bottom buttons use `SEND_MESSAGE` and `GROUP_INVITE` (`:1237,1241`).
- "No listings match your search." and the search-box instructions match the contract (`:947,1135`).
- The old "Nothing listed here..." text is gone.

Deviations:
- Column labels, "Whisper", "Unlist", "Needs my role", the status line (`:950`) and the tooltips are English literals. The contract marks only a subset as "ours" and does not cover the column labels. `Lvl` and `Name` have stock equivalents.
- The tooltip text ("Can play:", "Looking for:", "earlier today", "a day ago") is built with string concatenation, so it cannot be translated.
- "Whisper" on a solo row while you lead (where the action is really an invite message) is acknowledged in the checker sign-off as Phase 3's. Not scored against this phase.
- The error state gives no retry hint beyond the stock text. The contract accepts this because the refresh button is the retry path.

### Pillar 2: Visuals (3/4)

- Section header: `common-button-list-collapseExpand` background, plus/minus icons and the highlight, at the contract's anchors (`:660-684`). When the stock grouping template resolves, `ResultBG`, `ExpandIcon`, `CollapseIcon` and `Highlight` exist under the same parent keys (verified in `Browse.xml:277-315`), so `FillHeader` cannot hit a nil.
- Rows: `mid2` background/hover/selected trio, with the `groupfinder-highlightbar` pair for your own row, at the contract insets (`:555-566,745-753`). No second inset is drawn. The per-row scroll line is removed.
- Greyed rows desaturate the class/leader icon and the role slots and take alpha 0.5 (`:764,828-831`), as contracted.
- Weakness: the only visual emphasis in a row is the selected bar (an ADD blend of yellow, or `mid2-selected`). On a data-dense row there is no weight difference beyond class colour. This was a checker FLAG and is acceptable for a prototype.
- Weakness: the hide control is a text glyph (see Fix 4). The column-header arrow and its fallback ("^" / "v" in the label) are sound.
- The spinner and "Searching" label are placed per the stock anchors (`:1262-1268`).

### Pillar 3: Color (3/4)

- 60/30/10 matches the contract: the art surface is dominant, `mid2` rows and header bars are secondary, and `BRIGHTBLUE` appears only on Activity text when it matches your listing (`:820`). Nothing else uses the accent.
- Hidden, delisted and no-slot rows are fully grey (`W.DELISTED`), class-coloured names included (`:812-816`), and are restored on reuse (`:817-826`).
- Defects: `|cff999999`, `|cff33ff33` and `|cffff3333` are raw codes (`:266,290,361,529,775,799-803`). `(you)` is green, but the contract says "Your listing" in green is Phase 3, so the green suffix is slightly early. `Plain()` strips these codes on greyed rows, which is correct.
- The flat fallback colours (`0.1,0.1,0.1,0.5`, gold at 0.12) are only used where an atlas is missing and are close in tone.

### Pillar 4: Typography (3/4)

- Font objects match the contract: `GameFontNormal` (name, header label), `GameFontDisable` (level, state text), `GameFontHighlightSmall` (activity, status), `GameFontDisableSmall` (second line, Listed), `GameFontNormalLarge` (Searching). The sizes passed to `W.Text` only matter if the font object fails to resolve (`Widgets.lua:186-188`), so there are no size overrides on the happy path.
- Deviations: the status text in `GameFontHighlightSmall` and the row buttons in `GameFontNormal` are as contracted. `row.gs` uses `GameFontHighlight` (not in the contract table, but GS is off by default). `row.count` and `row.activity` both use `GameFontHighlightSmall`, and the role-count text for large groups is a second, similar size.
- Risk: the name cell has `GameFontNormal` plus a 16 px icon, class marks and up to three tag icons in 150 px (`:575-583,765-775`). Long names plus tags will be truncated by the width bound. This is a design limit, not a bug.

### Pillar 5: Spacing (3/4)

- Header 36 and row 40 extents, the 3/-8 and 3/-2 art insets, the list anchors (`3,-6` / `-22,2`), the 20 px column strip with 19 px header buttons, the 26x26 checkbox and the bottom buttons (111x28 at 21,16 and 109x28 at -21,16) all match the contract.
- The header strip and the rows share `Layout` and both subtract the scroll-bar width through `PlaceStrip` (`:535-548,1165-1170`). The callback keeps them aligned when the bar toggles. Good.
- Concerns: column x-positions are hand-computed constants (`:54-61`), so adding a column means re-deriving them. The Activity space is likely tight (see Fix 3). The cells are 32 px tall inside 40 px rows, so two text lines of 12 and 10 pt are fitted by `-4` / `-19` offsets that are not derived from the font height.

### Pillar 6: Experience Design (3/4)

- States: searching (list cleared, spinner), failed (text only, selection dropped), no results, filtered-by-search, and results all have their own presentation (`:915-949`).
- Selection is keyed by listing ID and survives re-sorts. It is cleared on search start, results, failure and re-show. Send and Invite act only on a selection that is shown (`ShownSelection`, `:425-428`). Delisted and own rows ignore clicks silently (`:624`). Hide is reversible.
- Sounds are routed through `W.PlayCheckbox`; ignored clicks are silent, as contracted.
- Taint discipline: no inheritance of the stock row templates. The stock grouping template is used only when it resolves, and the ScrollBox path falls back to `W.List`.
- Gaps: Unlist has no confirmation (see Fix 2). There is no keyboard path for row selection (no focusable rows). Whisper and the hide button give no feedback beyond the row's "sent" / "invited" text and the checkbox sound. An unlisted search box with no results gives no clear-search hint beyond the text. None of these break a flow.

---

## Files Audited
- `C:\Users\jonat\Repositories\TerribleGroupFinder\UI\Table.lua`
- `C:\Users\jonat\Repositories\TerribleGroupFinder\UI\Widgets.lua`
- `C:\Users\jonat\Repositories\TerribleGroupFinder\UI\InPlace.lua`
- `C:\Users\jonat\Repositories\TerribleGroupFinder\UI\Templates.xml`
- `C:\Users\jonat\Repositories\TerribleGroupFinder\.planning\phases\02-list-foundation\02-UI-SPEC.md`
- `C:\Users\jonat\Repositories\TerribleGroupFinder\.planning\phases\02-list-foundation\02-HUMAN-UAT.md`
- Blizzard source: `Blizzard_GroupFinder_VanillaStyle/Mainline/Blizzard_LFGVanilla_Browse.xml` (lines 277-316)
