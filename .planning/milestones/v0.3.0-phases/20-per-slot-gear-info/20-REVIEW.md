---
phase: 20-per-slot-gear-info
reviewed: 2026-11-24T00:00:00Z
depth: standard
files_reviewed: 4
files_reviewed_list:
  - GearSlots.lua
  - ItemLevel.lua
  - Core.lua
  - TerribleGroupFinder.toc
findings:
  critical: 0
  warning: 2
  info: 4
  total: 6
status: fixed
---

# Phase 20: Code Review Report

**Reviewed:** 2026-11-24
**Depth:** standard
**Files Reviewed:** 4
**Status:** issues_found

## Summary

I found no blockers. I checked these against the code and the Blizzard `forever` source:

- **Upvalue order:** every local is declared before its first caller. `RedrawKind` is forward-declared, and `Print`, `WindowGuid`, `Cancel`, `Schedule` and `ClearKind` all sit above `Draw`.
- **Taint:** only `hooksecurefunc`, `HookScript("OnHide")` and our own child frames are used. Nothing is written on a Blizzard frame or table.
- **Secret values:** unit, GUID, link, id, tooltip data and line fields all go through `Clear`/`Secret`.
- **Inspect GUID:** the guard is correct. `ILvl.InspectReadyFor` needs `readyGUID == guid and readySerial == serial`. A retarget, a new `NotifyInspect` or a hide blanks the overlays. A GUID change clears every inspect overlay.
- **"No enchant" on unloaded data:** it cannot show for unloaded data. A slot is "known" only after `GetDetailedItemLevelInfo(link)` returns a number, and `enchantID` is read from the link itself.
- **Settings off:** `OnChange` redraws, and `Draw` blanks every overlay when both keys are off.
- **Ranged slot:** `GetItemInfoInstant` is unpacked correctly (`classID`, `subclassID` at positions 6 and 7). The subclasses 2, 3 and 18 match bow, gun and crossbow.
- **Slot buttons:** the name patterns and IDs agree with `PaperDollFrame.xml`. The bag buttons that also call `PaperDollItemSlotButton_Update` are filtered out by `GS.SHOW`, because their IDs are above 18 or 0.

The two warnings below are robustness gaps.

## Warnings

### WR-01: Pending item data gives up after about 3 seconds and is never requested

**Status: fixed (5efd50d).** Pending slots call `C_Item.RequestLoadItemDataByID`; `GET_ITEM_INFO_RECEIVED` redraws (one coalesced redraw a frame later, only for a kind with a pending slot); the inspect not-ready wait has its own retry budget (`inspectReady`). The 1 s retries stay as a backstop.

**File:** `GearSlots.lua:281, 453-475, 521-523`
**Issue:**
- A "pending" slot is retried at most `ITEM_RETRIES` (3) times, 1 s apart. Nothing calls `C_Item.RequestLoadItemData` or listens for `GET_ITEM_INFO_RECEIVED`.
- On the Inspect window, the not-ready wait (`Schedule("inspect")` at line 514) uses the same budget. A slow `INSPECT_READY` can therefore leave no retries for the item-load wait that follows.
- The count is reset only by the next Blizzard slot update. Slots of a freshly inspected player with uncached items can stay blank until the player is re-inspected.
- Blank is the safe failure, because it never shows "No enchant". It is still a functional gap.

**Fix:** Request the item data and redraw when it arrives.
```lua
-- in Draw, state == "pending":
if r.link or id then pcall(C_Item.RequestLoadItemData, ...) end   -- via Item.CreateFromItemLink(link):ContinueOnItemLoad(...)
-- or: register GET_ITEM_INFO_RECEIVED on readyFrame and call RedrawKind("inspect") / RedrawKind("player") deferred by one frame
```
Keep the 1 s retry as a backstop. Use a separate counter for "inspect not answered yet", so it does not consume the item-load retries.

### WR-02: Stale per-button retry and blank state when the inspect GUID is nil

**Status: fixed (e0ade1c).** The timer only drops the retry when the captured GUID was non-nil and differs.

**File:** `GearSlots.lua:469, 506-510`
**Issue:**
- `Schedule("inspect")` captures `shownGuid.inspect`. That value can be nil when `WindowGuid()` is nil, for example when `InspectFrame.unit` has no GUID yet.
- The timer aborts if `WindowGuid() ~= guid`. Once the window's GUID becomes non-nil, the retry is dropped (nil ~= guid).
- The `INSPECT_READY` handler normally covers this. If the ready event arrives before our frame sees a matching `WindowGuid()`, the overlays stay blank until the next Blizzard update.

**Fix:** In the timer, compare against the current GUID only when the captured one is non-nil.
```lua
if kind == "inspect" and guid ~= nil and WindowGuid() ~= guid then return end
```

## Info

### IN-01: File header contradicts the file

**Status: fixed (8f79b90).**

**File:** `GearSlots.lua:4, 16`
**Issue:** The header says "Nothing here draws" and "nothing is cached". The file now holds the overlay frames (lines 271-570) and per-kind state (`shownGuid`, `retry`, `overlays`).
**Fix:** Reword the header: the data half (lines 1-270) is stateless, and the overlay half draws.

### IN-02: Overlays are created even when both options are off

**Status: skipped (not trivial; out of requested scope).**

**File:** `GearSlots.lua:542-558`
**Issue:** `OnSlotUpdate` calls `Overlay(button)`, which creates a frame and two FontStrings, for every slot update regardless of the settings. Both options default to off, so most users get 17 to 34 idle frames each for no use.
**Fix:** In `OnSlotUpdate`, return before `Overlay(button)` when neither setting is on and no overlay exists yet. Call `Overlay` again from the `OnChange` redraw path. That means iterating the known slot buttons, or remembering them in `kindOf`.

### IN-03: "No enchant" is a static guess for some slots

**Status: skipped (author's in-game check).**

**File:** `GearSlots.lua:51-67`
**Issue:**
- Head (1) and shoulders (3) are marked enchantable. In vanilla they take only faction, ZG or AQ enchants, so a red "No enchant" may be noise for many players.
- Off-hand (17) is marked enchantable for any item.
- Rings are excluded on the author's own low-confidence note.
These need the author's in-game check. They are not defects until checked.
**Fix:** Verify in game against the `/tgf gear` output ("enchantable yes/no" versus the enchant ID). Adjust `ENCHANTABLE` if needed.

### IN-04: Layout constants are unverified

**Status: skipped (author's in-game check).**

**File:** `GearSlots.lua:274-281`
**Issue:** The constants (`SIDE_WIDTH` 80, `MAIN_WIDTH` 60, `ABOVE_WIDTH` 42) are marked "first guesses". No-wrap, one-line strings truncate long enchant names silently. The left-column text also lands over the model area.
**Fix:** Tune in game. Consider a tooltip or abbreviation for long enchant text.
