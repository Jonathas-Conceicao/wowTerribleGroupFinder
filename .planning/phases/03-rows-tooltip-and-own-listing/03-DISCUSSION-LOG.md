# Phase 3: Rows, Tooltip and Own Listing - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-11-11
**Phase:** 03-rows-tooltip-and-own-listing
**Mode:** `--auto` (author AFK; recommended option auto-selected for every question)
**Areas discussed:** Role icons and voice, Own listing row, Tooltip, Tooltip refresh, Hide button, Needs my role

---

## Role icons and voice

| Option | Description | Selected |
|--------|-------------|----------|
| Micro atlases for solo, large for groups | Stock `SOLO_*` vs group atlases | ✓ |
| Micro everywhere | Uniform, not stock | |

| Option | Description | Selected |
|--------|-------------|----------|
| Discord icon only for Discord mode, voice line in tooltip | Stock behaviour | ✓ |
| Keep generic voice icon for any mode | Current prototype | |

**Choice:** [auto] stock behaviour (recommended default)

## Own listing row

| Option | Description | Selected |
|--------|-------------|----------|
| Stock delist button (UIMenuButtonStretchTemplate + redx), "Your listing" green in Activity, no Whisper/hide | Stock copy | ✓ |
| Keep "Unlist" panel button | Prototype | |

| Option | Description | Selected |
|--------|-------------|----------|
| Own row shown only while HasActiveEntryInfo() | Row vanishes after delist without a search | ✓ |
| Wait for next search | Row lingers until results | |

**Choice:** [auto] stock delist button; own row tied to HasActiveEntryInfo (recommended)

## Tooltip

| Option | Description | Selected |
|--------|-------------|----------|
| GameTooltip in stock order and wording, extras after | Small, taint-safe | ✓ |
| Copy LFGBrowseSearchEntryTooltip frame | Large; deferred | |

**Choice:** [auto] GameTooltip, stock order; playstyle in green as first extra; comment light grey

## Tooltip refresh

| Option | Description | Selected |
|--------|-------------|----------|
| Re-run ShowTooltip on the hovered row after Refresh | Follows what's under the mouse (stock) | ✓ |
| Hide tooltip on refresh | Simpler, worse UX | |

## Hide button

| Option | Description | Selected |
|--------|-------------|----------|
| UIMenuButtonStretchTemplate 24x22 + eye icons (transmog-icon-hidden / socialqueuing-icon-eye) | Stock row-button size, no red X | ✓ |
| common-icon-redx | Reads as delete/unlist | |

## Needs my role

| Option | Description | Selected |
|--------|-------------|----------|
| Server `*_REMAINING` counts, COMPOSITION fallback | Stock rule | ✓ |
| Keep COMPOSITION estimate only | Prototype | |

## Claude's Discretion

- Icon sizes, inline atlas markup style, helper split, shared small-button builder.
- Did not auto-chain into plan-phase: the orchestrating run calls ui-phase first.

## Deferred Ideas

- Custom tooltip frame; G18 compact role counts; G25 right-click menu; localization of labels; Q1 width.
