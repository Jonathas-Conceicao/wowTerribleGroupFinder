# Phase 1: Gear Score Off and Release Plumbing - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-11-11
**Phase:** 01-gear-score-off-and-release-plumbing
**Areas discussed:** Switch shape, GearScore.lua load, Table with GS off, Messages `{gs}`, Icon format, Packaging scope
**Mode:** `--auto` (author AFK); every choice is the recommended option.

---

## Switch shape

| Option | Description | Selected |
|--------|-------------|----------|
| `ns.GEAR_SCORE = false` in Core.lua | One constant, loaded first, visible to every file | ✓ |
| Flag inside GearScore.lua (`GS.enabled`) | Needs GearScore.lua loaded for others to read it | |
| Saved variable / slash toggle | Players could turn it on; out of scope | |

[auto] Switch — Q: "Where does the single switch live?" → Selected: "ns.GEAR_SCORE in Core.lua" (recommended default)

## GearScore.lua load

| Option | Description | Selected |
|--------|-------------|----------|
| Keep in TOC, Init returns early, frame created inside Init | One edit re-enables everything | ✓ |
| Remove from TOC | Doesn't ship, but re-enabling needs two edits | |

[auto] GearScore.lua — Q: "Keep it loaded?" → Selected: "Keep in TOC, inert while off" (recommended default)

## Table with GS off

| Option | Description | Selected |
|--------|-------------|----------|
| Drop column, shift right-hand columns left, Activity absorbs | Minimal, Phase 2 re-lays out | ✓ |
| Leave an empty gap | Looks broken | |
| Full re-layout now | Belongs to Phase 2 (UIP-04) | |

[auto] Table — Q: "What happens to the GS column width?" → Selected: "Shift left, Activity absorbs" (recommended default)

## Messages `{gs}`

| Option | Description | Selected |
|--------|-------------|----------|
| Drop key + default text, migrate exact old default | Author's saved text stays clean | ✓ |
| Render `{gs}` as empty | Leaves "(Tank, GS )" | |

[auto] Messages — Q: "How is `{gs}` removed?" → Selected: "Drop key, migrate old default" (recommended default)

## Icon format

| Option | Description | Selected |
|--------|-------------|----------|
| 32-bit uncompressed TGA via node script | No converter installed; WoW reads TGA | ✓ |
| BLP | No BLP converter available | |

[auto] Icon — Q: "Texture format?" → Selected: "TGA" (recommended default)

## Packaging scope

| Option | Description | Selected |
|--------|-------------|----------|
| Ignore Media/Source + *.ase in .pkgmeta; package.ps1 scans Media/Textures only; fix install IconTexture lookup | Only addon files + texture ship | ✓ |
| Only .pkgmeta | Local zip could still pick stray textures | |

[auto] Packaging — Q: "What to tighten?" → Selected: "All three" (recommended default)

## Claude's Discretion

- Switch comment placement, `Short` alias, PNG decoder details, column-shift arithmetic, smoke harness design.

## Deferred Ideas

- GS width redistribution (Phase 2), new presets (Phase 4), finish/drop GS (backlog 999.1), BLP icon.
