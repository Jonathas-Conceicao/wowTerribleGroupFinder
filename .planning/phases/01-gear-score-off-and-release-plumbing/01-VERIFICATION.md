---
phase: 01-gear-score-off-and-release-plumbing
verified: 2026-11-11T00:00:00Z
status: passed
human_verified: 2026-11-12 (author: all in-game checks pass, 01-HUMAN-UAT.md)
score: 5/5 must-haves verified
overrides_applied: 0
human_verification:
  - test: "Open Forever's group finder Browse tab with real search results, hover solo and group rows"
    expected: "No GS column, no 'Your GS' text, no GS in any tooltip line; columns use the freed width without overlap"
    why_human: "Visual layout and real Forever data cannot be exercised outside the game"
  - test: "Open the Messages tab in game"
    expected: "Key list shows {name} {activity} {role} {class} {level} only; no {gs}; default request preset has no GS"
    why_human: "Rendered UI text in the live client"
  - test: "In a party on Forever, start a ready check, then open the Inspect window and check for inspect requests"
    expected: "No inspects are started by the addon (no INSPECT_READY traffic from TGF)"
    why_human: "Event behavior needs the live client; code evidence only shows no frame or event is registered"
  - test: "Open the AddOns list and check the addon's icon after ./scripts/install.bat and /reload"
    expected: "The TGF icon (tgf_icon_64x64) shows next to the addon"
    why_human: "TOC IconTexture rendering and the TGA's in-game validity (size, format) are only visible in game"
---

# Phase 1: Gear Score Off and Release Plumbing Verification Report

**Phase Goal:** Players see no gear score anywhere and the addon is ready to be packaged and published with its IDs and icon
**Verified:** 2026-11-11
**Status:** human_needed (all automated checks pass; in-game confirmations remain)
**Re-verification:** No, initial verification

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | No GS column, "Your GS", tooltip GS, or `{gs}` key in Browse table / preview / Messages tab | VERIFIED | `Core.lua:17` `ns.GEAR_SCORE = false`. Every GS surface is gated: `UI/Table.lua:50` (column added only if on), `:206` (sort value), `:316`/`:342` (tooltip GS lines; else plain `AddLine`), `:767` (Your GS), `Messages.lua:18` (`{gs}` token only if on), `:83` (value), `:204`. Row cell creation is keyed on `cells.gs`, which only exists when the column exists. Smoke harness (GS off): "row has no gs cell", "no tooltip line mentions GS", `SUMMARY: 0 failed`. |
| 2 | Ready check starts no inspects; GearScore.lua kept behind a single disabled switch | VERIFIED | `GearScore.lua:269` `GS.Init` returns before creating a frame or registering `READY_CHECK`/`INSPECT_READY`, so no inspect can start. Single switch `ns.GEAR_SCORE` (only definition in `Core.lua:17`). File still in repo and in the TOC. Smoke run with `--gs` (switch on) also `0 failed`, including secret-name/GUID inspect guards. |
| 3 | `.planning/research/GEARSCORE.md` holds the design notes; backlog has "finish or drop" item | VERIFIED | `GEARSCORE.md` exists with status, formula, slot weights, and re-enable notes. `ROADMAP.md` "Phase 999.1: Gear score: finish or drop (BACKLOG)", source GS-02. |
| 4 | TOC carries CurseForge and Wago IDs and `IconTexture`; sources in `Media/Source/`, texture in `Media/Textures/` | VERIFIED | TOC: `X-Curse-Project-ID: 1798577`, `X-Wago-ID: Q6aqvA6W`, `IconTexture: Interface\AddOns\TerribleGroupFinder\Media\Textures\tgf_icon_64x64`. `git ls-files Media`: `Media/Source/baseicon.ase`, `baseicon.png`, `Media/Textures/tgf_icon_64x64.tga` (all tracked). `release.yml` sets `CF_API_KEY` and `WAGO_API_TOKEN` env vars. |
| 5 | Package zip and install output contain only addon files and the in-game texture | VERIFIED | Ran `scripts/package.bat`: zip entries are the TOC, 10 Lua files, and `Media/Textures/tgf_icon_64x64.tga` only (12 files, under `TerribleGroupFinder/`). `install.ps1` and `package.ps1` derive the set from the TOC plus the IconTexture file plus `Media\Textures` only (never `Media\Source`). `.pkgmeta` ignores `Media/Source`, `*.png`, `*.ase`, `dist`, `.planning`, `scripts`. install.ps1 was not executed (it writes to the local client); verified by reading, and it shares the logic with package.ps1. |

**Score:** 5/5 truths verified

### Requirements Coverage

| Requirement | Description | Status | Evidence |
|-------------|-------------|--------|----------|
| GS-01 | No gear score anywhere; no inspects; file behind one switch | SATISFIED (in-game confirmation pending) | Truths 1, 2 |
| GS-02 | Design notes in GEARSCORE.md plus backlog item | SATISFIED | Truth 3 |
| REL-01 | TOC IDs; workflow enables upload keys | SATISFIED | Truth 4 (TOC IDs match exactly; workflow env keys present) |
| REL-02 | Sources under `Media/Source/`, texture as `IconTexture` | SATISFIED | Truth 4 |
| REL-03 | Packaging ships only addon files and the texture | SATISFIED | Truth 5 |

All five phase IDs appear in REQUIREMENTS.md and are accounted for. No orphaned requirements for Phase 1 (MSG, LOCK, UIP map to later phases; REL-04 belongs to the Release Review).

### Behavioral Spot-Checks and Probes

| Check | Command | Result | Status |
|-------|---------|--------|--------|
| Smoke harness, GS off | `node run.js <repo>` | `SUMMARY: 0 failed` | PASS |
| Smoke harness, GS on | `node run.js <repo> --gs` | `SUMMARY: 0 failed` | PASS |
| Formatting | `stylua --check .` | clean | PASS |
| Package contents | `scripts/package.bat` + zip listing | 12 entries as expected | PASS |

No `*/tests/probe-*.sh` probes exist in the repo.

### Anti-Patterns Found

None blocking. No TBD/FIXME/XXX markers surfaced in the GS-related grep of the shipped Lua. Dormant GS code paths and `gs` fields in `Preview.lua` sample data remain by design (needed to re-enable). Git working tree was clean before verification; `dist/` is gitignored.

### Human Verification Required

See the frontmatter list: in-game visual check of Browse and tooltips, Messages tab keys, ready-check behavior, and the icon in the AddOns list (also confirm the TGA is a size and format the client accepts).

### Gaps Summary

No gaps. Every roadmap success criterion is backed by code or command evidence. Remaining items are in-game confirmations that cannot be run here.

---

_Verified: 2026-11-11_
_Verifier: Claude (gsd-verifier)_
