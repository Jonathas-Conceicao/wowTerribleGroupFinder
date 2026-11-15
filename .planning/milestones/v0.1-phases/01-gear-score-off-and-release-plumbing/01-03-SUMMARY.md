---
phase: 01-gear-score-off-and-release-plumbing
plan: 03
subsystem: release-plumbing
tags: [packaging, icon, tga, curseforge, wago, powershell]
requires: [01-01]
provides:
  - "Store IDs and IconTexture in the TOC"
  - "tools/png2tga.js and the tracked 64x64 TGA icon"
  - "install/package scripts that resolve and validate IconTexture and ship only Media/Textures"
affects: [phase-05-release-review]
tech-stack:
  added: []
  patterns: ["IconTexture resolved from the TOC path, prefix stripped, .blp/.tga probed"]
key-files:
  created: [tools/png2tga.js, Media/Textures/tgf_icon_64x64.tga, Media/Source/baseicon.ase, Media/Source/baseicon.png]
  modified: [.gitattributes, TerribleGroupFinder.toc, .github/workflows/release.yml, .pkgmeta, scripts/install.ps1, scripts/package.ps1]
decisions:
  - "CF_API_KEY and WAGO_API_TOKEN kept as the secret/env names (author's choice)"
  - "The icon block is duplicated in install.ps1 and package.ps1 rather than dot-sourced"
metrics:
  tasks: 3
  completed: 2026-11-11
requirements-completed: [REL-01, REL-02, REL-03]
---

# Phase 1 Plan 03: Release Plumbing Summary

The TOC now carries CurseForge 1798577, Wago Q6aqvA6W and an IconTexture pointing at a tracked 64x64 TGA built by a dependency-free converter. The release workflow reads upload keys from secrets, and the local zip and deploy ship only the TOC, the 10 Lua files and the texture.

## Commits
- `Task 1` icon sources moved to Media/Source, tools/png2tga.js, TGA built and tracked (message: feat(01-03): add addon icon sources, png2tga tool and 64x64 TGA)
- `ae9d601` TOC fields, release.yml keys, .pkgmeta ignores, install/package script fixes

## Verification
- TGA readback: `TGA OK 4096 pixels, 2801 transparent`; file is 16402 bytes; a non-PNG input exits 1 with "not a PNG file (bad signature)".
- `git check-attr binary Media/Source/baseicon.ase` reports set; nothing named baseicon remains at the repo root.
- Zip (`Packaged 12 files`), exact entries:
  - TerribleGroupFinder/TerribleGroupFinder.toc
  - TerribleGroupFinder/Core.lua
  - TerribleGroupFinder/Preview.lua
  - TerribleGroupFinder/GearScore.lua
  - TerribleGroupFinder/Messages.lua
  - TerribleGroupFinder/Listings.lua
  - TerribleGroupFinder/UI/Widgets.lua
  - TerribleGroupFinder/UI/Table.lua
  - TerribleGroupFinder/UI/MainFrame.lua
  - TerribleGroupFinder/UI/InPlace.lua
  - TerribleGroupFinder/UI/Listing.lua
  - TerribleGroupFinder/Media/Textures/tgf_icon_64x64.tga
- Negative test in a scratch copy (IconTexture leaf changed to `tgf_icon_missing`): package.ps1 and install.ps1 both print the IconTexture ERROR and exit 1 (install before any deploy; the scratch client folder stayed empty).
- install.bat output:
  ```
  Deploying 12 files derived from TerribleGroupFinder.toc: TerribleGroupFinder.toc, Core.lua, Preview.lua, GearScore.lua, Messages.lua, Listings.lua, UI\Widgets.lua, UI\Table.lua, UI\MainFrame.lua, UI\InPlace.lua, UI\Listing.lua, Media\Textures\tgf_icon_64x64.tga
  Deployed version: ae9d601-dev
  Installed to C:\Program Files (x86)\World of Warcraft\_forever_\Interface\AddOns\TerribleGroupFinder
  Done! /reload in WoW to load the addon.
  ```
- `stylua --check .` exit 0; smoke harness: `SUMMARY: 0 failed`.

## Deviations from Plan
- The worktree copies of the TOC, package.ps1 and release.yml are LF on disk (git normalises to CRLF for .toc/.ps1 at commit via .gitattributes), so edits kept the on-disk endings; the plan assumed CRLF on disk. No functional effect.

## Watch items for Phase 5
- CF_API_KEY is the packager's deprecated name for CF_API_TOKEN (kept by the author's choice).
- Whether CurseForge / Wago accept the `forever` game type is only known after the first tagged release.

## Known Stubs
None.

## Self-Check: PASSED
