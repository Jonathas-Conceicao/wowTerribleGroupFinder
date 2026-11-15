---
phase: 08-region-flags-and-row-icon-tooltips
plan: 03
subsystem: ui
tags: [tooltips, role-icons, open-slots]
requires: [08-02]
provides: [role slot hit targets, open-slot role tooltips]
affects: [UI/Widgets.lua, UI/Table.lua, CLAUDE.md]
key-files:
  modified: [UI/Widgets.lua, UI/Table.lua, CLAUDE.md]
decisions:
  - Role slots are the hit targets themselves (no extra child frame)
  - Open slot roles come from l.remaining when the server told us, else the composition estimate
metrics:
  completed: 2026-11-14
---

# Phase 8 Plan 03: Role icon tooltips Summary

Solo players' micro role icons and groups' filled and open slots now explain themselves on hover (role name from the game's TANK / HEALER / DAMAGER strings; "Open Tank slot" etc., or "Open slot" when no role can be told), and CLAUDE.md describes the Phase 8 behaviour.

## Commits
- 0462636: W.RoleIcon remembers role / micro / open role; role slots propagate and share the icon hit scripts; SetRoles assigns open-slot roles; IconTooltip "role" kind
- docs commit: CLAUDE.md lines for Region.lua, UI/Widgets.lua, UI/Table.lua

## Deviations from Plan
None. `Region.MarkupFor` still exists in Region.lua (unused in the repo, kept per Plan 02); CLAUDE.md does not mention it.

## Harness
All three modes (default, --fallback, --attach) print `SUMMARY: 0 failed`; 16 "icons: role" checks (propagation flags, solo roles, group filled slot, estimate open slots, remaining-based open slot, unattributable open slot, refill solo/group, greyed row, refresh keeps slot tooltip). `stylua --check .` passes.

## Deferred in-game checks (milestone end)
- Hover each role icon on solo rows and each filled / open slot on groups
- Click-select and right-click menu over role icons
- Greyed rows keep role tooltips; recycled rows show no stale role tooltip
- A results update while over a slot keeps the slot tooltip

## Known Stubs
None.

## Self-Check: PASSED
