---
phase: 04-messages-and-contact
plan: 04
subsystem: ui
tags: [wow-addon, side-tab, taint, hooksecurefunc]
requires:
  - phase: 04-03
    provides: Messages panel and BuildPanel
provides:
  - Messages side tab that matches Forever's stock tabs (unchecked at start, filled icon, UpdateTabs-aware, template tooltip)
  - CLAUDE.md architecture bullets for the Phase 4 work
affects: [05-release-review]
tech-stack:
  added: []
  patterns: [post-hook on LFGParentFrame.UpdateTabs, single UncheckStock helper]
key-files:
  modified: [UI/InPlace.lua, CLAUDE.md]
key-decisions:
  - "Fill-to-interior order: SetFillToInterior(true), else our own tab's fillToInterior field, else the 30x30 + texcoord fallback"
  - "W.Tooltip hook removed; the template's tooltipText is the only tooltip"
requirements-completed: [UIP-01]
duration: 30min
completed: 2026-11-11
---

# Phase 4 Plan 04: Messages Tab Parity and Phase Close Summary

The Messages side tab now starts unchecked, fills its icon like Forever's tabs, never shows checked together with a stock tab (post-hook on `LFGParentFrame.UpdateTabs`), and uses the template's own tooltip; CLAUDE.md is updated and the build is installed.

## Tasks

1. Harness stubs and red checks (outside the repo, no commit): `hooksecurefunc` wraps table methods, `LargeSideTabButtonTemplate` gets `Icon` / `SetFillToInterior` / custom mouse-up handler, attach `LFGParentFrame` gets `ListingTab` and `UpdateTabs`; probe `tab-uip01` ran red (3 failed).
2. `56986f0` feat: `UncheckStock` helper, `SetChecked(false)` at creation, fill-to-interior, `UpdateTabs` hook, `W.Tooltip` line removed.
3. `6aa1a25` docs: CLAUDE.md bullets for Messages.lua (`[TGF]`, Auto-invite, lock, migration, BuildPanel), `W.SetPressed`, Table contact buttons, InPlace tab, `ns.GroupSize`.

## Verification

Final harness output (default, `--gs`, `--fallback`, `--attach`): each ends `SUMMARY: 0 failed`. `stylua --check .` passes. CHANGELOG.md and README.md untouched.

Install output (`& .\scripts\install.bat` via PowerShell, exit 0):
```
Deploying 13 files derived from TerribleGroupFinder.toc: ...
Deployed version: 56986f0-dirty-dev
Installed to C:\Program Files (x86)\World of Warcraft\_forever_\Interface\AddOns\TerribleGroupFinder
Done! /reload in WoW to load the addon.
```
No missing-file report.

## Deviations from Plan

- `cmd //c scripts\\install.bat` from Git Bash mangled the path; used PowerShell instead (same script, exit 0).
- The first CLAUDE.md commit attempt did nothing (forgot `git add`); redone, no content change.
- Ambiguity: the harness checks the `SetFillToInterior` branch only; the other two fallback branches are untested by the stub.

## Threat Model

T-04-15/16: hook is a `hooksecurefunc` post-hook, installed only when `UpdateTabs` is a function, with nil-guards; no field writes on `LFGParentFrame` or stock tabs (only `SetChecked(false)`); `fillToInterior` is only ever set on our own tab. T-04-17: install derives the file set from the TOC.

## human_needed (in-game checks for the author, not blocking)

- Pressed look shows on the clicked Whisper / Send Message for about 1 s and does not flash back on mouse-up (A1, A2)
- A rapid double click sends once; scrolling during the lock does not move the press to another row
- Auto-send + Auto-invite: one click on a solo player whispers then invites, by plain name
- Lockdown prefill opens the whisper box with no send
- Disabled Auto-invite shows a grey label and its tooltip with "Turn on Auto-send first."
- Key buttons insert at the cursor and keep focus (A4); `[TGF]` typed mid-text moves to the front on leaving the box
- Enter / Escape / paste in the multi-line box; the 56 px box shows 3 lines plus char count; key-row widths under 410 px
- Who-style layers and the ScrollLine divider at y -300 look right in game and in `/tgf`
- Messages tab starts unselected, icon fills like the stock tabs (Q4 `INV_Letter_15`); a listing update while Messages is open keeps only Messages checked; tooltip is the template's
- Old default presets migrated on first load, custom ones kept
- No taint messages with `/console taintLog 1`; then `/reload` in game

## Self-Check: PASSED

Commits 56986f0 and 6aa1a25 exist; UI/InPlace.lua and CLAUDE.md changed; all four harness modes 0 failed.
