# Phase 2: List Foundation - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-11-11
**Phase:** 2-list-foundation
**Areas discussed:** Scrolling structure, Header frames, Selection model, Layout placement, Row look, Search states, Sounds
**Mode:** `--auto` (author AFK) — every choice is the recommended option, made by Claude.

---

## Scrolling structure

| Option | Description | Selected |
|--------|-------------|----------|
| Linear view + flat data provider, collapse in Collect() | Reuses the existing item list; simple | ✓ |
| Tree view + TreeDataProvider (as stock) | Stock structure, but rewrites sort/collapse | |

[auto] Scrolling — Q: "Linear or tree view?" → Selected: "Linear + flat provider" (recommended)
[auto] Scrolling — Q: "How to get separate header/row pools?" → Selected: "Own XML virtual Buttons (no inheritance), header inherits Blizzard's grouping template in game when present" (recommended; frame-type pools would share one pool)
[auto] Scrolling — Q: "Fallback when ScrollBox API is missing?" → Selected: "Keep W.List with per-kind pools" (recommended)

## Header frames

[auto] Q: "Which header look?" → Selected: "Finder's own grouping template (full-alpha ADD highlight)" (UI-PARITY D4)
[auto] Q: "Header click sound?" → Selected: "None, as stock"

## Selection model

[auto] Q: "Key?" → Selected: "resultID (`l.id`)"
[auto] Q: "When cleared?" → Selected: "results received / failed, search start, selected ID gone or delisted, preview refresh"
[auto] Q: "Double-click?" → Selected: "Removed"

## Layout placement

| Option | Description | Selected |
|--------|-------------|----------|
| Needs my role in the bottom bar | Simple, no extra width in the stone band | ✓ |
| Filter dropdown next to the search box (Who tab style) | Needs ~90 px more in the stone band | |

[auto] Q: "Width?" → Selected: "Keep 620; check 580-620 in game"
[auto] Q: "Roles width?" → Selected: "92 (GS space)"

## Row look

[auto] Q: "Row height?" → Selected: "40 rows / 36 headers"
[auto] Q: "Activity count suffix?" → Selected: "Keep '+N'"
[auto] Q: "Greyed rows?" → Selected: "0.3 grey text + desaturated icons, role icons alpha 0.5"

## Search states

[auto] Q: "Text when our search box hides everything?" → Selected: "No listings match your search."

## Sounds

[auto] Q: "Hide / show sound?" → Selected: "CHECKBOX_ON (stock row-button convention)"
[auto] Q: "Checkbox look?" → Selected: "Template .Text, 26x26, ON/OFF sounds (shared W.Check)"

## Claude's Discretion

- Pixel offsets in the stone band and bottom bar; row art build timing; W.List kind handling;
  ClearSelection placement; sort arrow texcoords.

## Deferred Ideas

- Stock default order with 3-state header click (G35); right-click menu (G25); role-count display
  (G18); preview stock templates (G38).
