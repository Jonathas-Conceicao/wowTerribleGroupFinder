# Phase 5: Release Review - Research

**Researched:** 2026-11-11
**Domain:** Close-out of milestone v0.1 for a WoW Forever Lua addon (code audit, no web research)
**Confidence:** HIGH (every finding below was read from the working tree at branch `milestone/v0.1-milestone`; line numbers are current as of that read)

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions
- **D-01:** Remove dead code and duplication added during the milestone. Candidates (the planner must confirm each is still present before scheduling it): `W.Line` with no callers, `host:ForEachFrame` / `list:ForEachFrame` with no callers, `row.item` and `row.listing` holding the same table (keep one), `local view` in `BuildList` shadowing the module `view` (rename to `scrollView`), `VoiceLabels()` rebuilt per tooltip (cache once, lazily), `HoveredRow()` computed before the `band:IsVisible()` early return.
- **D-02:** Strip planning references from code and doc comments: review IDs (WR-/IN-/CR-), decision IDs (`D-19` etc.), phase numbers, and any wording that describes an in-milestone bug ("used to", "previously", "fix for", "no longer"). Comments describe what the code does now.
- **D-03:** `CLAUDE.md`: strip any in-milestone bug mention and bring the Architecture lines that no longer match the code in line with it (gear score is switched off behind `ns.GEAR_SCORE`, so the Table line's GS sort / "your GS" and the GearScore line are described as off; Messages line mentions the keys, Auto-invite and the contact lock). Only accuracy edits, no restructuring.
- **D-04:** Cheap, behaviour-neutral or clearly bug-fixing items from the reviews are in scope:
  - Messages key-button wrap (04 IN-01 / UI review): wrap at most once, so a third row can never start over the Auto-send row (drop the forced `i == 5` break when the width test already wrapped, or make the width test the only rule while keeping two rows for the stock labels).
  - Example line (04 IN-02): pick the first sample listing of the right kind (solo for the invite preset, group for the request preset) instead of by position.
  - Pasted newlines (04 IN-03): keep the cursor position when stripping newlines.
  - Hide hint wording (03 IN-01): word the tooltip hint without naming the eye icon.
  - Preview flags (02 IN-08): `searching()` / `failed()` return false while `ns.UsingPreview()`.
  - Stale status while searching (02 IN-04): clear the status text and shown IDs in the searching branch before `RefreshButtons()`.
  - Header labels width-bound on the template path (02 IN-05) if it is a two-anchor change.
- **D-05:** Out of scope for cleanup (recorded for the author / later milestones): tooltip blank-line rules vs UI-SPEC, raw `|cff..` status colours, a hint on a non-leader's own row, feedback for clicks during the lock or lockdown prefill, intro text length, disabled Auto-invite label font, 02 IN-09 (listings during chat lockdown), 02 IN-03 (triple refresh on show), playstyle colour (author's call), localisation.
- **D-06:** Run `stylua .` and the smoke harness (default, `--gs`, `--fallback`, `--attach`) after the cleanup; all must end `0 failed`.
- **D-07:** Milestone version is **0.1.0**, tag `v0.1.0`. The TOC keeps `## Version: @project-version@` (already true). Nothing to edit; record the confirmation in the summary.
- **D-08:** Insert a new `## v0.1.0` section at the top of `CHANGELOG.md`, directly under `# Changelog` and above the existing `## Unreleased` section, with the Edit tool. The existing text stays as is; the author is told that the bootstrap line under Unreleased likely folds into v0.1.0.
- **D-09:** Content: one-line summary, then Added / Changed / Removed / Fixed, user-facing and short. First release: sections describe what the addon offers. Changed / Removed only if they say something to a user (gear score being off is not a removal for a first release). Fixed is empty and omitted or marked as none. Never name or describe any third-party or reference addon.
- **D-10:** `README.md` is not edited. Suggested changes go into `05-HUMAN-UAT.md`: drop the gear score mentions, describe the Messages tab keys, Auto-invite and the 1 s contact lock, the own-listing row with delist, the tooltip, the icon; status line wording for a first release.
- **D-11:** The README has no screenshots: step skipped, noted in the summary and UAT.
- **D-12:** `.pkgmeta` keeps excluding `LICENSE`. Recommendation for the author, recorded in `05-HUMAN-UAT.md`: ship `LICENSE` in the release zip (drop it from `.pkgmeta`'s ignore list and add it to the install / package file set).
- **D-13:** `05-HUMAN-UAT.md` lists, pending: README review (with the suggestions), CHANGELOG draft review, open decisions (playstyle colour, LICENSE shipping, branch name `milestone/v0.1-milestone` vs the intended `milestone/v0.1-initial-release`, the stray local `milestone/v1.0-milestone` branch, store secrets `CF_API_KEY` / `WAGO_API_TOKEN`, whether CurseForge / Wago accept the `forever` game type) and a consolidated pointer to the in-game checks in phases 1-4 `*-HUMAN-UAT.md`. Phase 5 is not marked complete.

### Claude's Discretion
- Exact wording of the changelog draft and the README suggestions.
- How the key-button wrap rule is restructured, as long as the stock labels keep two rows.

### Deferred Ideas (OUT OF SCOPE)
- Items in D-05 (tooltip blank lines, status colours, own-row hint, locked-click feedback, IN-09, triple refresh, localisation) - next milestone candidates
- Gear score finish-or-drop stays in backlog 999.1
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| REL-04 | Release Review: code cleanup, version confirmed, changelog draft, author review of README.md / CHANGELOG.md | Sections 1-3 (cleanup, with exact locations), 4 (CLAUDE.md), 5 (changelog inventory + README mismatches), 6 (version / plumbing), 7 (harness safety) |
</phase_requirements>

## Summary

The cleanup list in CONTEXT D-01/D-04 is mostly still accurate, with **three corrections that change the plan**:

1. `ForEachFrame` (both the ScrollBox `host:` wrapper and `W.List`'s `list:`) is **no longer dead**: `Instance:HoveredRow` and `Instance:RefreshTooltip` (added in Phase 3) call `self.list:ForEachFrame`. Resolved, skip. Removing it would break the tooltip refresh.
2. `row.item` is write-only in the addon (nothing reads it on a row), **but the harness's `ItemOf()` reads `fr.item` on the `--fallback` path**. Removing `row.item` from `FillRow` makes the fallback probes raise. Either keep the field or change the harness helper to `fr.item or fr.listing` in the same task. Header frames keep `frame.item` (the header click handler reads it).
3. 02 IN-05 (header label width-bound) is **not** a two-anchor change: the sort arrow is anchored to the text's `RIGHT`/`LEFT` edge, so a two-anchor text would put the arrow at the button edge, away from the label. Skip it (record for the author).

Everything else (W.Line, `local view` shadow, VoiceLabels, HoveredRow order, key wrap, example by position, pasted newline cursor, hide hint, preview flags, stale status) is still present and is a small, local edit. IN-08 (preview flags) **will fail one `--attach` harness probe** unless that probe is updated (details in section 7).

Planning-reference comments in shipped files are almost clean: exactly **one** review/decision ID remains (`D-19` at `UI/Table.lua:1194`), plus one `.planning` path pointer (`Core.lua:15`), one stale doc comment (`W.List` signature, `UI/Widgets.lua:607`), a "Hidden players (X)" wording (`UI/Table.lua:8`), and a gear-score-era history comment (`Messages.lua:40`). CLAUDE.md has four stale spots (GearScore line, Table line, Widgets line, release.bat line); the Messages line already mentions keys, Auto-invite and the lock.

**Primary recommendation:** Plan three small tasks: (A) code cleanup edits in `Table.lua` / `Widgets.lua` / `Messages.lua` / `InPlace.lua` plus the harness updates, then `stylua .` and the four harness modes; (B) CLAUDE.md accuracy edits; (C) CHANGELOG `## v0.1.0` draft plus `05-HUMAN-UAT.md`. Do not touch README.md, `.pkgmeta`, scripts, the TOC.

## Architectural Responsibility Map

Not a multi-tier web app; the addon is a single client-side Lua layer. Tier ownership for the phase's edits:

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Table list/tooltip/status cleanup | `UI/Table.lua` | `UI/Widgets.lua` (fallback list) | Presentation layer |
| Source flags (searching/failed) | `UI/InPlace.lua` (in-game source) | `UI/MainFrame.lua` (preview source) | Source adapters feed `Table.Attach` |
| Preset text, key buttons, example | `Messages.lua` (`BuildPanel`) | `Preview.lua` (sample data) | Messages owns its panel |
| Docs (CLAUDE.md, CHANGELOG, UAT) | repo docs | `.planning/` | Edit tool only on `.md` |

## Standard Stack

No new libraries. Tooling already in use:

| Tool | Purpose | Notes |
|------|---------|-------|
| `stylua` (repo `stylua.toml`) | formatting, run `stylua .` from repo root after edits | CLAUDE.md rule |
| Smoke harness (node + fengari) | `node run.js <repo> [--gs|--fallback|--attach]` | outside repo, in session scratchpad |
| Edit tool | all `.md` and `.planning/` edits | no `sed -i`, no shell redirects on `.md` |

## Package Legitimacy Audit

No external packages are installed in this phase. **Packages removed:** none. **Packages flagged:** none.

## Architecture Patterns

### Data flow touched by the cleanup (no behaviour change)

```
Forever LFGBrowseFrame (searching / searchFailed flags, results)
        |
        v
InPlace.source { listings, preview, hasListing, searching, failed }   <- IN-08 edit
        |
        v
Table.Attach -> Instance:Refresh()
        |-- HoveredRow() (reads GameTooltip owner via list:ForEachFrame)   <- reorder edit
        |-- searching branch: Clear + spinner + status/shownIDs clear      <- IN-04 edit
        |-- failed branch
        '-- normal: Collect -> list:SetItems -> RefreshTooltip(hovered)
                                  |
                                  v
                    BuildList: ScrollBox host  (local scrollView)          <- rename
                               or W.List fallback (frame.item set by FillRow)
```

### Anti-Patterns to Avoid
- **Removing `ForEachFrame`**: it is the tooltip-refresh path (`Table.lua:1205`, `1219`).
- **Editing `.md` files with `sed -i`/redirects** or rewriting `CHANGELOG.md` (CLAUDE.md rule): use Edit and insert only.
- **Mentioning in-milestone bugs anywhere outside `.planning/`**: the changelog "Fixed" stays empty, comments describe present behaviour only.

## 1. Cleanup candidates: status and minimal change

| # | Item (source) | Present? | Where (now) | Minimal change |
|---|---------------|----------|-------------|----------------|
| 1 | `W.Line` unused (02 IN-02) | **Yes** | `UI/Widgets.lua:256-263` (definition only; the only other hit for `W.Line` in all shipped files is none; `MainFrame.lua`'s `ScrollLine` is unrelated) | Delete the whole `function W.Line(parent) ... end` block (8 lines). Check the Widgets header index comment (~line 1-10, 607) does not list it: it does not. |
| 2 | `ForEachFrame` unused (02 IN-02) | **Resolved - skip** | `UI/Widgets.lua:713`, `UI/Table.lua:1401` are called from `UI/Table.lua:1205` (`HoveredRow`) and `1219` (`RefreshTooltip`) | None. Do NOT remove. |
| 3 | `row.item` duplicates `row.listing` (02 IN-02) | **Yes, write-only on rows** | `UI/Table.lua:1006` (`row.item = item`), `1007` `local l = item`, `1008` `row.listing = l`. Header `frame.item` at `953` is read at `944` - keep. | In `FillRow`: delete `row.item = item`; replace the two lines with `local l = item` + `row.listing = l` unchanged. **Harness coupling**: `harness.lua:510-513` `ItemOf(fr)` returns `fr.item` on the fallback path; change it to `return fr.item or fr.listing` in the same task (the scratchpad harness is outside the repo and may be edited). If the planner prefers zero harness risk, drop this item. |
| 4 | `local view` shadows module `view` in `BuildList` (02 IN-01) | **Yes** | `UI/Table.lua:1358` (`local view = CreateScrollBoxListLinearView()`), used at `1359`, `1362`, `1365` (`SetElementFactory/ExtentCalculator/Resetter`) and in the `ScrollUtil.InitScrollBoxListWithScrollBar(box, bar, view)` call (~1372). Module `view` is declared `Table.lua:87`. | Rename the local and its 5 uses inside that `if box.SetDataProvider and bar.Init then` block to `scrollView`. No other `view` use inside the block refers to the module table (the `placeStrip`/`host:` functions do not touch it). |
| 5 | `VoiceLabels()` rebuilt per tooltip (03 IN-02) | **Yes** | `UI/Table.lua:368-376` defined, called once at `549` | `local voiceLabels` upvalue; `local function VoiceLabels() if not voiceLabels then local v = ns.VOICE; voiceLabels = {...same four entries...} end return voiceLabels end`. Harness `harness.lua:1537-1542` nils the `VOICE_CHAT_MODE_*` globals mid-run and restores them; the cache returns the same English strings either way (fallback strings equal the stub values), so no probe changes are expected. |
| 6 | `HoveredRow()` before the `band:IsVisible()` return (03 IN-03) | **Yes** | `UI/Table.lua:1239-1240` (`local hovered = self:HoveredRow()` then `if not self.band:IsVisible() then return end`) | Swap the order: guard first, then `local hovered = self:HoveredRow()`. The list is not yet re-filled at that point, so the value is the same. |
| 7 | Hide hint names the eye (03 IN-01) | **Yes** | `UI/Table.lua:591` `"Hidden until they make a new listing (use the eye button to show)."` | Replace with `"Hidden until they make a new listing (use the hide button to show)."` (no icon named). The harness only looks for the prefix `"Hidden until"` (`harness.lua:1492`), safe. Note CLAUDE.md line 14 says "hidden (X, until they relist)" - see section 4. |
| 8 | Preview flags (02 IN-08) | **Yes** | `UI/InPlace.lua:81-86` (`searching`, `failed`). `UI/MainFrame.lua:338` `failed` already returns false and has no `searching` (fine). | `searching = function() return not ns.UsingPreview() and LFGBrowseFrame and LFGBrowseFrame.searching == true end`, same shape for `failed` with `searchFailed`. **Keep the value false (not nil) when the frame exists** because `harness.lua:914` asserts `source.failed() == false`. See section 7: one `--attach` probe must be adjusted. |
| 9 | Stale status while searching (02 IN-04) | **Yes** | `UI/Table.lua:1259-1267` searching branch: `Clear()`, `spinner:Show()`, `stateText:SetText("")`, `RefreshButtons()`, `RefreshTooltip` | Before `self:RefreshButtons()` add `self.status:SetText("")` and `wipe(self.shownIDs)` (the failed branch at `1273-1275` already clears `status`; `shownIDs` is a field of `self` (`Table.lua:1453`, wiped at `1155`)). Do not attempt the "move stateText below own row" part (not in D-04). |
| 10 | Header label width-bound, template path (02 IN-05) | **Yes, but not a two-anchor change** | `UI/Table.lua:1536-1543` (`text:SetPoint(j, b, j, off, 0)`), arrow anchored to `text` at `1555-1558` | **Skip.** Giving the text two anchors (LEFT +4 / RIGHT -4) makes the FontString as wide as the button, so the arrow anchored at `text` RIGHT/LEFT would sit at the button edge, not at the label end. Record in UAT/open items for a later milestone. |
| 11 | Key-button wrap (04 IN-01) | **Yes** | `Messages.lua:411-441` | See the wrap rule below. |
| 12 | Example by position (04 IN-02) | **Yes** | `Messages.lua:379` `ns.Preview.listings[kind == "invite" and #ns.Preview.listings or 1]` | Add a local helper above `Example()`: `local function Sample() for _, l in ipairs(ns.Preview.listings) do if (kind == "invite") == (l.solo == true) then return l end end end` and use `local sample = Sample()`. `l.solo` is set in `Preview.lua:108` (`#l.members == 1`); `M.Format` takes a listing (`Messages.lua:~140`). If a kind had no sample the call would pass nil: not the case with the current data (both kinds exist). |
| 13 | Pasted newline moves cursor (04 IN-03) | **Yes** | `Messages.lua:385-393` (`text = text:gsub("[\r\n]+", " "); e:SetText(text)`) | Capture `local pos = e:GetCursorPosition()` before; compute how many characters were removed before the cursor; after `e:SetText(text)` call `e:SetCursorPosition(pos - removedBefore)` (clamped at 0). Caveat (MEDIUM): `GetCursorPosition` counts characters while `string.sub`/`#` count bytes; newline characters are ASCII but earlier characters may be multi-byte. Safe rule: count removed characters by replacing in the *prefix* `text:sub(1, <byte offset of cursor>)`; where the byte offset is not known, only adjust when the prefix is pure ASCII, otherwise keep the old behaviour. Keep it simple; the harness has no paste probe. Also note `gsub` returns two values: wrap in parentheses (`(text:gsub(...))`) before storing, as the current line already assigns only the first. |

### Key-button wrap: current algorithm and a safe rule

Current (`Messages.lua:411-441`): `x, rowY = 0, -86`; for each key `i`: the button width is `GetStringWidth()+24`; then `if i == 5 or (x > 0 and x + w > BOX_WIDTH) then x, rowY = 0, rowY - 24 end`; place at `(x,rowY)`; `x = x + w + 4`.

Widths: `BOX_WIDTH = 410` (`Messages.lua:279`); row pitch 24; button height 22; first row at y -86, so row 2 is -110 and a third row would be -134, which overlaps the Auto-send checkbox at y -138 (`Messages.lua:455`). Labels: `[TGF] {name} {activity} {players} {class} {level} {role}` (7).

Widths for the stock labels: the harness stub measures `#text*6` (`harness.lua:57`): 54, 60, 84, 78, 66, 66, 60. Rows by width test alone: row 1 = first 5 (x after 5 = 362; the 6th needs 428 > 410) and row 2 = 2 keys. Real in-game font widths are narrower (about 5-5.5 px per character, estimate, [ASSUMED]); the 6th/7th key could then fit on row 1 (6+1). Either way two rows, but the layout would change from today's 4+3 split.

**Recommended rule (keeps today's 4+3 look exactly, wraps at most once):**

```lua
local x, rowY, wrapped = 0, -86, false
...
if not wrapped and (i == 5 or (x > 0 and x + b:GetWidth() > BOX_WIDTH)) then
	x, rowY, wrapped = 0, rowY - 24, true
end
```

With the stock labels the first wrap is at `i == 5` (the width test does not fire earlier: after 4 keys x = 54+4+60+4+84+4+78+4 = 292 in harness units, the 5th key itself fits), giving 4+3, identical to today. If localised labels were wide enough for the width test to fire before key 5, the single wrap is used up and the rest continues on row 2 (it can overflow the box width to the right, which is cosmetic) instead of starting a third row over the checkbox. Update the comment above it to "two rows (4 + 3); wraps once at most". No harness check depends on key positions (`panel-keys` probes only check count, labels, tooltips, insert/normalise behaviour, `harness.lua:2055-2080`).

## 2. Comments referencing planning artefacts or in-milestone history

Grep of the TOC load list plus CLAUDE.md for `D-NN`, `WR-/IN-/CR-`, `UIP-/GS-/REL-/MSG-/LOCK-`, "Phase N", `G\d+`: **one hit**. Wording search ("used to", "previously", "no longer", "fix", "was", "now", "once", "old", "earlier") gave the following relevant lines; everything else matched is ordinary present-tense wording (`once per refresh`, `now` meaning "currently", etc.) and needs no change.

| File:line | Text (short) | Suggested change |
|-----------|--------------|------------------|
| `UI/Table.lua:1194` | `-- True when the shared tooltip is open on one of this table's row frames (D-19). Read before the` | Delete ` (D-19)`; the sentence stays correct. |
| `UI/Table.lua:7-8` | `... Activity, Listed. Hidden players (X) and, with Needs my role, listings with` | Replace `Hidden players (X)` with `Hidden players` (the hide button is an icon button, not an X, `Table.lua:1132`). Re-wrap the two lines (stylua does not rewrap comments). |
| `UI/Table.lua:15` | `... Name, Lvl, Roles (and GS, while ns.GEAR_SCORE is on) have fixed widths from the left, Listed` | Current-state wording, fine (long line only). Optional re-wrap. |
| `UI/Widgets.lua:607-611` | `W.List(parent, rowHeight, makeRow, fillRow)` / `(parent, kinds, kindOf, fillItem)` doc | Still accurate: `UI/Listing.lua:306` uses the number form and `Table.lua:1410` the kinds form. No change. |
| `Messages.lua:35` | `-- Presets that were once the default; a saved copy of one becomes the new default (once).` | Keep the migration (behaviour). Reword to describe the mechanism without history: `-- Earlier default presets: a saved copy of one is replaced by the current default (version 2 migration, once).` |
| `Messages.lua:40` | `-- The gear score era text; its old key is spelled in two pieces, as it is no key any more.` | Reword: `-- An earlier request default that carried a gear score key; the key is spelled in two pieces so it is never read as a key.` Do not say "era". Decision for the author (flag, do not do): since v0.1.0 is the first release, the whole `PREVIOUS` table and the `VERSION` migration only serve the author's own saved variables; removing them is a behaviour change, out of scope for cleanup. |
| `Core.lua:13-15` | `-- Gear score is switched off for v0.1. ... See .planning/research/GEARSCORE.md.` | Present-tense and accurate. The `.planning/` path is a pointer to a non-shipped file (`.planning` is excluded by `.pkgmeta`); suggest `-- Gear score is switched off. Setting this to true brings back the GS column, "Your GS", the tooltip lines and the ready-check inspects. Messages have no gear score key.` and drop the version and the path sentence. |
| `UI/Table.lua:8`, `UI/Table.lua:15`, `GearScore.lua:267` | mention `ns.GEAR_SCORE` | accurate, keep. |
| `Preview.lua`, `Listings.lua`, `UI/MainFrame.lua`, `UI/Listing.lua`, `UI/InPlace.lua`, `UI/Templates.xml` | no planning IDs or history wording | none |

Search also covered `TODO|FIXME|XXX|HACK|milestone|v0.1|prototype|review|research|harness|probe`: only `Core.lua:13-15` (above) matched in shipped files. In CLAUDE.md the only hits are legitimate workflow text (GSD Workflow section, which is *about* the milestone rules, not a bug mention) and "Prototype stage" at line 5 (author's wording; flag for the author if v0.1.0 should read differently).

## 3. Other dead code

- Function/field audit: every `function X`, `local function X`, `W./ns./M./L./GS./T./IP.` definition and constant was counted across the shipped files; the **only** name with a single occurrence is `Line` (`W.Line`). Every local declared at file/function scope appears at least twice in its file (no unused locals found by textual scan; `luacheck`/`luac` are not installed, so this is a name-count scan, not a compiler check).
- Gear-score code (`GearScore.lua`, the `if ns.GEAR_SCORE then` branches in `Table.lua:59-63, 238, 503, 508, 1491`, `Core.lua:123`, `W.GS`) is intentionally kept behind the switch (GS-01); not dead.
- `UI/Listing.lua` and `UI/MainFrame.lua` are not used in game but are the preview stand-in (documented in CLAUDE.md); not dead.
- Open design note (not a cleanup item, do not change): `Instance:Delist` calls `C_LFGList.RemoveListing()` directly (`Table.lua:683-697`), the remainder of 02 IN-06, while CLAUDE.md says "Listing (create/update/unlist) stays Blizzard's own tab". It is not in D-04/D-05. Record it in `05-HUMAN-UAT.md` as an open author decision.

## 4. CLAUDE.md lines that no longer match

Only accuracy edits (use the Edit tool; keep structure):

| Line | Current | Suggested replacement |
|------|---------|----------------------|
| 14 (Forever model) | `hidden (X, until they relist)` | `hidden (until they relist)` |
| 26 `GearScore.lua` | `ns.GS: our score (slot-weighted, ...), the cache ..., ready check -> inspect group members without a fresh score` | `` - `GearScore.lua` — `ns.GS`: our score (slot-weighted, quality-scaled item level), the cache (`DB.gs`: name → gs, level, time), fresh vs outdated (earlier session), ready check → inspect group members without a fresh score. **Switched off** behind `ns.GEAR_SCORE` (Core.lua, false): no GS column, "Your GS", tooltip lines or inspects; design notes in `.planning/research/GEARSCORE.md` `` |
| 27 `Messages.lua` | already lists keys, `{addon}`, defaults, Auto-send, Auto-invite, the 1 s lock, migration, `BuildPanel` | Accurate. Optional: drop `a one-time migration of the old default presets (custom ones kept)` only if the author removes the migration; otherwise keep. No change needed. |
| 29 `UI/Widgets.lua` | `..., role/class icons, GS colours, W.IconButton ...` | change `GS colours` to `GS colours (used only while gear score is on)` |
| 32 `UI/Table.lua` | `...sort within each section by Roles (T>H>D) / Lvl / GS (groups: best known) / Activity / Listed, your GS, friend marks, Whisper per row...` | `...sort within each section by Roles (T>H>D) / Lvl / Activity / Listed (a GS sort and "Your GS" exist but are off with gear score), friend marks, Whisper per row...` (the rest of the line, including the own-listing row with the stock delist button, the tooltip and the layout guard, is already accurate) |
| 35 (new, after `UI/MainFrame.lua`/`Listing.lua`) | no line for the icon | add `` - `Media/Textures/` — the in-game icon (`IconTexture` in the TOC); `Media/Source/` holds its art sources and never ships `` |
| 38 `scripts/release.bat` | `...(BigWigs packager on tag push; CurseForge/Wago keys and TOC project IDs not set yet)` | `...(BigWigs packager on tag push; the workflow publishes the first `## ` section of CHANGELOG.md; uploads to CurseForge / Wago need the `CF_API_KEY` / `WAGO_API_TOKEN` repository secrets, and the TOC carries the project IDs)` (REL-01 done; secrets are an open author item, D-13) |

No in-milestone bug mention was found in CLAUDE.md (line 50 states the *rule*, which is fine).

## 5. User-facing feature inventory (for `## v0.1.0`) and README mismatches

Read from the code, not the docs.

**Browse tab (Forever's own finder, in place; the stock Category / Activity dropdowns, Search/Refresh stay Blizzard's):**
- Results table with columns Name (class icon, class-coloured name, Discord icon when the listing uses Discord voice), Lvl, Roles (solo players: stock micro role icons; groups: open slots as role counts, leader icon), Activity (blue when it matches your active listing), Listed (age; "delisted" red / "invited" / "sent" status words).
- Two collapsible sections, Solo players and Groups, with Forever's grouping-header look and counts; groups first while solo, solo players first while leading.
- Click a column header to sort within each section: Roles (T>H>D), Lvl, Activity, Listed (arrow shows direction; second click reverses). No GS column.
- Your own listing first, with "Your listing" in green and the stock delist button (solo player or group leader only).
- Search box beside the refresh button: filters by name, activity or note.
- Needs my role checkbox: greys and moves to the end groups with no open slot for your roles, and solo players who cannot fill a slot your group has open (uses the server's remaining-slot counts when available).
- Hide button on each row (greys and moves the player to the end until they make a new listing; click again to show). Delisted listings are greyed and moved to the end as well; nothing is ever removed from view.
- Selecting a row (click; click again to clear; stock sound) enables Send Message and, for a solo player when you can invite, Group Invite at the bottom; a Whisper button on each row; status line "N solo players, M groups".
- Stock states: spinner while searching, "No results found.", "Search failed.", and "No listings match your search." for our search box.
- Row tooltip in Forever's stock order and wording (activities with groups, members/roles, voice chat, comment, playstyle in light grey), with extras after it (friends in group, listed age, hidden note); refreshes for the row under the mouse when results update.
- Friend, Battle.net friend, guildmate and recent ally marks on names.

**Messages tab (a fourth side tab on Forever's window, icon: a letter):**
- Two presets: for solo players (invite) and for group leaders (request), multi-line boxes with a live example line.
- Keys as buttons under each box: `[TGF]` (always first, once), `{name}`, `{activity}`, `{players}`, `{class}`, `{level}`, `{role}`. Defaults: invite `[TGF] Group for {activity} with {players} players`; request `[TGF] Level {level} {class}, for {activity}`.
- Auto-send checkbox per preset (off: the whisper box opens with the message, Enter sends; on: sent at once). Solo-player preset also has Auto-invite (needs Auto-send; whispers, then sends the group invite). Default button restores the standard text.
- After an auto-send, the whisper/invite buttons ignore clicks for 1 second and the clicked button stays pressed ("sending"). Never sends during chat messaging lockdown (prefills the box instead).

**Slash commands** (`Core.lua:281-308`): `/tgf` (also `/terriblegroupfinder`) toggles the finder on Browse; `/tgf preview` switches between your search results and sample listings; `/tgf reset` restores the sample data; `/tgf version`.

**Icon:** `Media/Textures/tgf_icon_64x64.tga` as the TOC `IconTexture`. **Not present in v0.1.0:** gear score (switched off, never released).

**README.md statements that no longer match the code** (list only; README must not be edited):
1. "sortable by role (tank, healer, damage), level or gear score" - gear score is off; sorts are role, level, activity, listed.
2. The bullet "gear scores remembered between sessions ... refreshed for your group on every ready check, and your own shown for reference" - off in v0.1.0.
3. The Messages bullet omits the keys, Auto-invite, the Default button and the 1 s contact lock.
4. Own listing row with delist, row tooltip, Needs my role, hide button, search box and the icon are not described.
5. "**Status:** prototype / proof of concept." - wording for a first release is the author's call.
6. Slash command line is accurate; the "preview stand-in" wording is accurate.
7. No screenshots exist (D-11: step skipped).

## 6. Release plumbing facts

- **TOC:** `## Interface: 16001`, `## Version: @project-version@` (unchanged, D-07 satisfied), `## X-Curse-Project-ID: 1798577`, `## X-Wago-ID: Q6aqvA6W`, `## IconTexture: Interface\AddOns\TerribleGroupFinder\Media\Textures\tgf_icon_64x64`, `## X-License: GPL-3.0`, `## SavedVariables: TerribleGroupFinderDB`. Load list: `Core.lua Preview.lua GearScore.lua Messages.lua Listings.lua UI\Widgets.lua UI\Templates.xml UI\Table.lua UI\MainFrame.lua UI\InPlace.lua UI\Listing.lua`.
- **`.pkgmeta`:** `package-as: TerribleGroupFinder`; `manual-changelog` file `RELEASE_NOTES.md` (markdown). Ignore list: `.gitignore, .gitattributes, .pkgmeta, .github, .planning, CHANGELOG.md, CLAUDE.md, README.md, LICENSE, RELEASE_NOTES.md, stylua.toml, scripts, tools, "*.png", "*.org", Media/Source, "*.ase", dist, .release`. `LICENSE` is excluded (D-12: keep, recommend shipping in UAT). Note `"*.png"` excludes the source PNG; the shipped icon is a `.tga`.
- **`scripts/install.ps1` / `package.ps1`:** file set = TOC load list + files referenced by `file=` in loaded XML (Templates.xml has none) + the TOC `IconTexture` file (`.blp`/`.tga`) + every `.blp`/`.tga` under `Media/Textures`; `install.ps1` also copies the TOC itself; `package.ps1` warns when a texture is not git-tracked. **No LICENSE** in either (matches `.pkgmeta`); shipping LICENSE would need `.pkgmeta` and both scripts edited (author decision, not this phase).
- **`.github/workflows/release.yml`:** triggers on every tag push (`"**"`); `awk '/^## /{if(found) exit; found=1} found' CHANGELOG.md > RELEASE_NOTES.md` publishes **the first `## ` section including its heading line**. So the new `## v0.1.0` section must be above `## Unreleased` (D-08) or `Unreleased` would be published. Secrets: `GITHUB_TOKEN` (as `GITHUB_OAUTH`), `CF_API_KEY`, `WAGO_API_TOKEN`. Packager `BigWigsMods/packager@v2` with `-n "{package-name}-{project-version}"`.
- **`scripts/release.bat <version>`:** tags `v<version>` and pushes `origin main` + the tag; refuses to run off `main` unless `TGF_ALLOW_BRANCH=1`. Run only after the squash-merge (not this phase).
- **CHANGELOG.md now:** `# Changelog` / `## Unreleased` / one bootstrap bullet. The insertion point is between `# Changelog` and `## Unreleased`.
- **Branches:** `main`, `milestone/v0.1-milestone` (current), `milestone/v1.0-milestone` (stray, local), `remotes/origin/main`.

## 7. Validation: smoke harness

`run.js` loads the TOC file list (so removing/renaming files is picked up automatically), sets `REPO`, `FILELIST`, `FLAGS` and runs `harness.lua` (about 2150 lines) in fengari with WoW stubs. Modes: default, `--gs`, `--fallback`, `--attach`. Last recorded run `out.txt` ends `SUMMARY: 0 failed`.

Probe-by-probe impact of the cleanup:

| Change | Harness impact |
|--------|----------------|
| Remove `W.Line` | None (no probe references it). |
| Keep `ForEachFrame` | The harness defines `f.ForEachFrame` on its ScrollBox stub (`harness.lua:234`); tooltip-refresh probes (`1621-1670`) depend on the real code path. Do not remove. |
| Remove `row.item` | **Breaks `--fallback`**: `ItemOf(fr)` (`harness.lua:510-513`) returns `fr.item` when the frame lacks `GetElementData`. Change to `return fr.item or fr.listing`, or keep `row.item`. Probe `harness.lua:676-680` checks `fr.listing == item` (stays valid). |
| Rename module-shadowing `view` to `scrollView` | None; the harness's own `local view = box.__view` (`harness.lua:177, 187, 236, 663`) is its own variable. The probe at `664` checks extents 36/40. |
| `VoiceLabels` cache | `harness.lua:1537-1542` toggles the globals; strings are identical, no failure expected. Re-run to confirm. |
| `HoveredRow` after visibility guard | `tip-refresh` probes (`1621-1670`) still hold; the `band:IsVisible()` stub must be true there (it is, the tooltip refresh runs). |
| Hide hint reword | Probe checks the prefix `"Hidden until"` only (`harness.lua:1492`, `tipprobes.lua:46`). Safe. |
| **Preview flags (IN-08)** | **Breaks one `--attach` probe** unless adjusted: the harness sets `ns.state.preview = true` (`harness.lua:495-497`) and then at `harness.lua:927-940` sets `LFGBrowseFrame.searching = true` / `searchFailed = true` and expects the spinner and "Search failed." text. With the fix, `searching()`/`failed()` are false while `UsingPreview()`, so the spinner/failed assertions fail. Update the harness: set `ns.state.preview = false` before line 928 and `true` again before `local oldPL = ns.PreviewListings` (line ~938), and add a check that with `preview = true` and `LFGBrowseFrame.searching = true`, `inst.source.searching()` is false (and `failed()` false with `searchFailed = true`). `harness.lua:914` (`source.failed() == false`) still passes if `failed` returns `false` not `nil` when the frame exists. The `tip-refresh` probe at `1663-1667` overrides `inst.source.searching` itself, unaffected. |
| Stale status (IN-04) | Add a probe: after a normal refresh, flip `LFGBrowseFrame.searching = true` and assert `inst.status.__text == ""` and `next(inst.shownIDs) == nil`. Existing spinner probes still pass. |
| Key wrap | No position probes exist; optionally add a check that with the stub widths the keys' second-row points are at `-110` and no point has y `-134`. |
| Example by kind | No probe on the example text; optionally assert the invite example shows a solo player's name and the request example a group's. |
| Pasted newline cursor | No probe; optionally fire `OnTextChanged(edit, true)` with `"a\nb"` and cursor 2 and expect the cursor at 2 (stub `SetCursorPosition` at `harness.lua:102`). |

### Test Framework
| Property | Value |
|----------|-------|
| Framework | Custom Lua smoke harness under node + fengari (outside the repo) |
| Config file | none; flags `--gs`, `--fallback`, `--attach` |
| Quick run command | `node run.js "C:/Users/jonat/Repositories/TerribleGroupFinder"` (cwd: the scratchpad `smoke` folder) |
| Full suite command | the same plus `--gs`, `--fallback`, `--attach` (four runs, each must end `SUMMARY: 0 failed`) |
| Format check | `stylua .` (repo root) |

### Phase Requirements → Test Map
| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| REL-04 (cleanup) | No behaviour change, all probes still pass | smoke | the four harness runs | yes (harness), probe edits needed per the table above |
| REL-04 (comments) | No planning IDs left in shipped files/CLAUDE.md | grep | `rg -n "\b(D\|WR\|IN\|CR\|UIP\|MSG\|LOCK\|REL)-[0-9]+\|[Pp]hase [0-9]" Core.lua Preview.lua GearScore.lua Messages.lua Listings.lua UI CLAUDE.md` (expect no output) | n/a |
| REL-04 (version) | TOC keeps `@project-version@` | grep | `rg -n "^## Version: @project-version@" TerribleGroupFinder.toc` | yes |
| REL-04 (changelog) | `## v0.1.0` is the first `## ` section | grep | `rg -n -m1 "^## " CHANGELOG.md` shows `## v0.1.0` | after the edit |
| REL-04 (author review) | README and CHANGELOG reviewed | manual-only | `05-HUMAN-UAT.md` (author, left open) | after the plan |

### Sampling Rate
- Per task commit: `stylua .` and the default harness run.
- Per wave merge / phase gate: all four harness modes at `0 failed`, plus the comment grep.

### Wave 0 Gaps
- [ ] Harness edits (outside the repo): `ItemOf` fallback, IN-08 probe adjustment, optional new probes. No repo test files are needed.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Dead-code detection | a bespoke analyser | the name-count grep already run + the harness | no linter installed; the scan found one item |
| Cursor tracking on paste | a diff algorithm | subtract removed newline characters before the cursor | only newline runs are replaced |
| Changelog extraction | a new script | the existing awk in `release.yml` | defines the format (first `## ` section, heading included) |

## Common Pitfalls

### Pitfall 1: Removing `ForEachFrame` because CONTEXT calls it dead
**What goes wrong:** the tooltip refresh (`HoveredRow`, `RefreshTooltip`) stops working and the tip-refresh probes raise.
**How to avoid:** the planner schedules no ForEachFrame removal; the task text says "resolved - skip".

### Pitfall 2: `row.item` removal breaks only the `--fallback` harness
**What goes wrong:** `ItemOf(fr).header` indexes nil in fallback mode.
**How to avoid:** change `ItemOf` in the same task, or keep the field. Re-run all four modes.

### Pitfall 3: IN-08 silently invalidates the `--attach` spinner/failed probes
**What goes wrong:** `ns.state.preview = true` in attach mode makes `searching()` false after the fix.
**How to avoid:** the harness edit in section 7, done in the same task as the InPlace edit.

### Pitfall 4: Two-anchor header text moves the sort arrow
**What goes wrong:** arrows float at the button edge.
**How to avoid:** skip IN-05; record it for later.

### Pitfall 5: `gsub` returning two values
**What goes wrong:** `SetText(text:gsub(...))` or a table field assignment receives the count too.
**How to avoid:** parenthesise `(text:gsub(...))` where the result is passed on.

### Pitfall 6: Changelog heading order
**What goes wrong:** inserting under `## Unreleased` publishes the wrong notes (the workflow takes the first `## ` section).
**How to avoid:** insert directly under `# Changelog` (D-08), with the Edit tool, leaving the rest untouched.

### Pitfall 7: Leaking in-milestone history
**What goes wrong:** a changelog "Fixed" entry, a code comment, or a CLAUDE.md line mentions a bug introduced and fixed inside v0.1.
**How to avoid:** Fixed omitted; comments reworded as in section 2; recheck with the grep.

## Code Examples

### Key wrap that wraps at most once
```lua
-- Source: Messages.lua:411-441, adapted
local x, rowY, wrapped = 0, -86, false
for i, k in ipairs(M.KEYS) do
	-- ... button created and sized ...
	if not wrapped and (i == 5 or (x > 0 and x + b:GetWidth() > BOX_WIDTH)) then
		x, rowY, wrapped = 0, rowY - 24, true
	end
	b:SetPoint("TOPLEFT", x, rowY)
	x = x + b:GetWidth() + 4
end
```

### Example sample of the right kind
```lua
-- Source: Messages.lua:379, adapted
local function Sample()
	for _, l in ipairs(ns.Preview.listings) do
		if (kind == "invite") == (l.solo == true) then
			return l
		end
	end
end
```

### Preview-aware source flags
```lua
-- Source: UI/InPlace.lua:81-86, adapted
searching = function()
	return not ns.UsingPreview() and LFGBrowseFrame and LFGBrowseFrame.searching == true
end,
failed = function()
	return not ns.UsingPreview() and LFGBrowseFrame and LFGBrowseFrame.searchFailed == true
end,
```
(`not ns.UsingPreview()` is `false` in preview, so the expression yields `false`; with the frame present and not in preview it yields a boolean, so `failed() == false` holds.)

## State of the Art

Not applicable (close-out audit). Forever's finder, stock atlases and templates are the style reference per CLAUDE.md.

## Runtime State Inventory

Not a rename/refactor/migration phase. Stored data note only: `TerribleGroupFinderDB` has `messages` (version 2 migration) and `gs` cache; nothing here changes saved-variable shapes.

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | In-game `GameFontNormalSmall` widths are about 5-5.5 px per character, so the stock keys may fit 6+1 under a width-only rule | Section 1 (key wrap) | Low: the recommended rule keeps the forced 4+3 split either way |
| A2 | `GetCursorPosition` counts characters (UTF-8 aware) while Lua string functions count bytes | Section 1, item 13 | Cursor could land a few characters off after a paste containing multi-byte characters before the cursor; cosmetic |
| A3 | The author keeps the `Messages` migration (`PREVIOUS`, `VERSION = 2`) even for a first release | Section 2 | Removing it would be a behaviour change; left to the author |
| A4 | Store secrets `CF_API_KEY` / `WAGO_API_TOKEN` are not yet set (CLAUDE.md says "not set yet", D-13 lists them as pending) | Section 6 | Upload steps would be skipped on the first tag |

## Open Questions

1. **Is `Instance:Delist`'s direct `C_LFGList.RemoveListing()` acceptable for v0.1.0?**
   - Known: stock routes through `LFGListingFrame:RemoveListing()` and sets a pending flag; CLAUDE.md says unlisting stays Blizzard's.
   - Unclear: whether the author accepts it as released behaviour.
   - Recommendation: do not change in this phase; list under open decisions in `05-HUMAN-UAT.md`.
2. **Keep or drop the preset migration for a first release?** Recommendation: keep; flag to the author.
3. **README "Status" wording and "Prototype stage" in CLAUDE.md line 5** - author's call (UAT).

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| node + fengari (harness) | D-06 validation | yes (`node_modules` present in the scratchpad `smoke` folder; `out.txt` shows a prior green run) | not probed | none needed |
| stylua | CLAUDE.md rule, D-06 | assumed on PATH (used in earlier phases) [ASSUMED, not probed] | - | none |
| lua / luac / luacheck | optional lint | no | - | name-count scan used instead |
| git | commits, branch checks | yes | - | - |

Missing dependencies with no fallback: none.

## Security Domain

Not applicable to this phase (no new input handling, network, auth or crypto). The only security-relevant constraint is existing and unchanged: no addon messages during `C_ChatInfo.InChatMessagingLockdown()`, `issecretvalue()` guards, and taint rules (never write fields on Blizzard frames). The cleanup edits touch only our own frames and pure-Lua tables, with `InPlace.lua`'s `searching`/`failed` only reading `LFGBrowseFrame` fields as before. ASVS categories V2-V6 do not apply.

## Sources

### Primary (HIGH confidence)
- Repo files read at `milestone/v0.1-milestone`: `Core.lua`, `Messages.lua`, `Preview.lua`, `UI/Table.lua`, `UI/Widgets.lua`, `UI/InPlace.lua`, `UI/MainFrame.lua`, `TerribleGroupFinder.toc`, `.pkgmeta`, `.github/workflows/release.yml`, `scripts/release.bat`, `scripts/package.ps1`, `scripts/install.ps1`, `CLAUDE.md`, `README.md`, `CHANGELOG.md`
- `.planning/phases/05-release-review/05-CONTEXT.md`, `.planning/REQUIREMENTS.md`, `.planning/PROJECT.md` (Milestone Close-out)
- `.planning/phases/02-list-foundation/02-REVIEW.md` (Info), `03-rows-tooltip-and-own-listing/03-REVIEW.iter2.md` (Info), `04-messages-and-contact/04-REVIEW.md` (Info)
- Smoke harness `run.js` / `harness.lua` in the session scratchpad

### Secondary / Tertiary
- None. Font widths in A1 are an estimate.

## Metadata

**Confidence breakdown:**
- Cleanup item status and locations: HIGH (read from the tree)
- Harness impact: HIGH for `row.item` and IN-08 (read the probes), MEDIUM for VoiceLabels (reasoned)
- Cursor-position handling: MEDIUM (A2)
- Release plumbing: HIGH

**Research date:** 2026-11-11
**Valid until:** until the next code edit on the branch (line numbers drift); re-grep the item names rather than trusting numbers.
