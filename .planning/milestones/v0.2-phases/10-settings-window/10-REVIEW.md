---
phase: 10-settings-window
reviewed: 2026-11-14T00:00:00Z
depth: standard
files_reviewed: 5
files_reviewed_list:
  - UI/SettingsPanel.lua
  - Settings.lua
  - Core.lua
  - UI/InPlace.lua
  - TerribleGroupFinder.toc
findings:
  critical: 0
  warning: 3
  info: 3
  total: 6
status: issues_found
fixed_at: 2026-11-14T00:00:00Z
fix_status: partial
fixed: 5
skipped: 1
---

# Phase 10: Code Review Report

**Reviewed:** 2026-11-14
**Depth:** standard
**Files Reviewed:** 5
**Status:** issues_found

## Narrative Findings (AI reviewer)

### Summary

Diff `4d62e00..HEAD` checked against Blizzard's `forever` source (`Blizzard_Settings_Shared`, `Blizzard_GroupFinder_VanillaStyle`).

What is correct:
- The Settings API calls match the signatures: `RegisterProxySetting(cat, variable, type, name, default, get, set)`, `CreateCheckbox(cat, setting, tooltip)`, `CreateSettingsButtonInitializer(name, buttonText, click, tooltip, addSearchTags)` with the required non-nil `addSearchTags`, and `SetParentInitializer(init, predicate)`.
- The proxy getter and setter go through `ns.Settings`, so the registry stays the only source of truth.
- No field is written on `SettingsPanel`.
- `OpenToCategory` → `C_SettingsUtil.OpenSettingsPanel` (`HasRestrictions`) is only reached from a slash command, which comes from a hardware event, and only out of combat.
- Init order is correct: `ns.Settings.Init(db)` runs before `SettingsPanel.Init()`, and the TOC loads `SettingsPanel.lua` after `InPlace.lua`.
- `/tgf set` parsing is correct for lowercased input: keys are compared with `opt.key:lower()`, a bare `set` or empty arguments print the usage, and `setfoo` does not match.

No blockers. There are three warnings, all about the "Edit whisper messages" button and how state syncs between the panel and the slash command.

### Warnings

#### WR-01: "Edit whisper messages" opens the group finder behind the Settings panel

**File:** `UI/SettingsPanel.lua:58-60`, `UI/InPlace.lua:411-429`
**Issue:** `SettingsPanel` has `frameStrata="HIGH"` and no `UIPanelWindows` entry (`Blizzard_SettingsPanel.xml:4`). `ShowUIPanel` does not close it. `LFGParentFrame` is a MEDIUM-strata `left` panel. So the button shows the Messages tab underneath the Settings panel, which covers most of the screen. To the player, the button seems to do nothing until they close Settings. The file header says "our button never closes it", which avoids taint, but nothing makes up for it.
**Fix:** Keep the panel open (closing it from addon code is a taint risk), but make the result visible. Change the button text and tooltip to say it takes effect when Settings closes, for example "Opens on the group finder's Messages tab when you close Settings". Or open the finder when the panel hides:
```lua
if SettingsPanel and SettingsPanel:IsShown() then
  ns.Print("the Messages tab opens when you close the Settings.")
  -- one-shot: SettingsPanel:HookScript("OnHide", ...) guarded by a pending flag; HookScript only
end
```

#### WR-02: `IP.OpenMessages` falls back to the preview stand-in and turns preview on in game

**File:** `UI/InPlace.lua:416-428`
**Issue:** The in-game branch needs `tbl and messages`. `messages` is nil when `LFGListingFrame` or `LFGWhoListFrame` is missing (`Attach`, line 324). `tbl` is nil before Blizzard's finder has loaded. In both cases the code falls through to `ns.state.preview = true; ns.UI.Show("messages")`. That opens the addon's own window in game, which CLAUDE.md forbids ("never opens a window of its own"). It also leaves `ns.state.preview` on, so the next real Browse read shows sample listings.
**Fix:** Only use the stand-in where the game has no finder API:
```lua
if not ns.Listings.HasAPI() then
  ns.state.preview = true
  return ns.UI.Show("messages")
end
if not (tbl and messages) then
  return ns.Print("the group finder isn't ready yet.")
end
```

#### WR-03: `/tgf set` leaves an open Settings page stale

**File:** `UI/SettingsPanel.lua:104-123`
**Issue:** `ns.Settings.Set` writes the saved value directly and never touches the Blizzard `Setting` object. While the Settings page is open, its checkbox still shows the old value. The `swipeAnimations` parent predicate is not re-evaluated either, so the child stays enabled or disabled against the new `dynamicRefresh` value. The page only corrects itself on its next `OnShow`.
**Fix:** In `SP.Init`, keep the setting objects and refresh them on a change, only while the panel is shown (this limits insecure calls into the panel's callbacks):
```lua
ns.Settings.OnChange(key, function()
  if SettingsPanel and SettingsPanel:IsShown() and setting.NotifyUpdate then
    setting:NotifyUpdate()
  end
end)
```

### Info

#### IN-01: `SP.Command` ignores what `ns.Settings.Set` returns
**File:** `UI/SettingsPanel.lua:121-122`
**Issue:** It prints "on" or "off" even when `Set` returns false (before the saved table is ready). This can't happen after `ADDON_LOADED`, but the message would be wrong if it did.
**Fix:** `if not ns.Settings.Set(found.key, value) then return ns.Print("settings aren't ready yet.") end`.

#### IN-02: The Settings panel's "Defaults" button saves the defaults
**File:** `UI/SettingsPanel.lua:42-46`
**Issue:** Defaults calls the proxy setter with each default, so `db[key] = true` is saved. That breaks the registry's rule that a value is saved only once the player sets it, so a default changed in a later version would no longer apply to these players.
**Fix:** Accept this and document it, or add `ns.Settings.Reset(key)` (`db[key] = nil` and notify listeners) and call it from the setter when `value == opt.default`.

#### IN-03: The usage line leaves out `config`
**File:** `Core.lua:297`
**Issue:** `/tgf config` works but isn't listed. `PrintAll` also prints `tostring(opt.section)`, which would read "nil" for an option registered without a section.
**Fix:** List `settings|config` in the usage line, and skip the section text when it is nil.

## Fix Notes

- **WR-01 fixed** (`52e7ee3`, with WR-02: same function). With the game's Settings panel shown, `IP.OpenMessages` remembers the request, adds a one-time `SettingsPanel:HookScript("OnHide")` and prints "the Messages tab opens when you close the Settings."; on hide it opens the Messages tab on the next frame (`C_Timer.After(0)`, out of the panel's own hide; still out of combat only). The panel is never hidden or written to by us. The button's tooltip says the tab opens when you close Settings. In-game check: the hook runs on every later Settings close but does nothing without a pending request.
- **WR-02 fixed** (`52e7ee3`). The stand-in (and `ns.state.preview = true`) only where `ns.Listings.HasAPI()` is false. In game, before Blizzard's finder has loaded (or without the Listing/Who frames), it prints "the group finder isn't ready yet." Loading the finder ourselves (`GroupFinderVanillaStyle_LoadUI`, a secure load-on-demand addon) was left out: the stock `ToggleLFGFrame` only opens it once the game has loaded it, and loading a secure addon from addon code risks taint.
- **WR-03 fixed** (`cbaa814`). Each proxy setting gets an `ns.Settings.OnChange` listener that calls the setting's own `NotifyUpdate()` while `SettingsPanel` is shown (re-reads our getter, so no write and no setter loop); skipped while the setting is locked (the change came from the page's own `ApplyValue`, which triggers its own update). The Swipe animations child follows through the parent's value-changed callback.
- **IN-01 fixed** (`a9833f1`). `SP.Command` prints "settings aren't ready yet." when `Set` returns false.
- **IN-02 skipped.** Clearing the saved key in the setter when `value == default` would also clear an explicit click back to the default, so that player would follow a later default change: it breaks "saved only once set" for explicit choices. Telling the Defaults button apart would need a hook on Blizzard's setting objects or panel (writes fields on them: taint). Accepted as is: Defaults saves the current defaults; noted in CLAUDE.md.
- **IN-03 fixed** (`d7fade9`). Usage lists `settings|config`; `PrintAll` drops the section text when an option has none.

Smoke harness (outside the repo): new checks for WR-01 (deferred open, one hook, hint, later hides do nothing), WR-02 (no preview in game; "isn't ready" with the API but no finder) and WR-03 (NotifyUpdate only while shown and unlocked); `""`, `--fallback`, `--attach` all 0 failed. Deployed with `scripts/install.ps1`.

---

_Reviewed: 2026-11-14_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
