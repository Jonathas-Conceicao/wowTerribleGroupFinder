---
phase: 13-region-flags-for-every-region
plan: 01
subsystem: media
tags: [flags, textures, tga, converter]
requires: []
provides:
  - Media/Textures/flag_{us,au,eu,cn,kr,tw}.tga (64x32, flag at top-left)
affects: [13-02 Region.lua FLAG_ART]
key-files:
  created:
    - Media/Source/png2tga.js
    - Media/Source/flags/SOURCE.md
    - Media/Source/flags/flag_{us,au,eu,cn,kr,tw}.png
    - Media/Textures/flag_{eu,cn,kr,tw}.tga
  modified:
    - Media/Textures/flag_us.tga
    - Media/Textures/flag_au.tga
  deleted:
    - Media/Source/flags.js
requirements-completed: [REG-05, REG-08]
duration: 10min
completed: 2026-11-16
---

# Phase 13 Plan 01: Flag art Summary

The author's flagpedia.net PNGs are converted 1:1 to six 64x32 TGAs by a dependency-free Node converter, and the old flag generator is deleted.

## Commits
- 77673f7: moved PNGs to Media/Source/flags, added SOURCE.md, removed flags.js
- 1a92564: png2tga.js and the six TGAs

## Results
- Each TGA is 8210 bytes with header `00 00 02 00 00 00 00 00 00 00 00 00 40 00 20 00 20 28`.
- Flag sizes: US 40x21 (4-bit palette), AU 40x20, EU/CN/KR/TW 40x27, at top-left; the rest is transparent.
- Sampled pixels (RGBA): EU field (0,51,153,255); CN field (238,28,37,255); US bottom-row stripe (179,25,66,255), i.e. the palette's red; (40,0) and (0,31) are alpha 0 in all six files.
- The converter only decodes (palette, tRNS, sub-byte unpacking, unfiltering) and pads. It throws on unsupported input.
- No CHANGELOG.md, README.md or CLAUDE.md edits.

## Deviations from Plan
None. The plan was executed as written.

## HUMAN-UAT
1. After `./scripts/install.bat`, fully restart the client (a `/reload` may keep the old cached US/AU textures), then `/tgf preview`. Check that the US, AU, EU, CN, KR and TW flags look sharp and upright (US/AU/TW cantons top-left), with no faded right or bottom edge. If an edge looks soft, note it (a half-texel coord inset in Region.lua is the fix).
2. Screenshot reminder: the flags on rows changed look; the author decides whether to retake README prints.

## Self-Check: PASSED
