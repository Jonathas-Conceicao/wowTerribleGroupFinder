# Phase 12: Damage Meter Reset Prompt - Context

**Gathered:** 2026-11-16
**Status:** Ready for planning
**Mode:** Smart discuss, recommended answers auto-picked (author's standing rule for /gsd-autonomous: no pauses; decisions reported at the end)

<domain>
## Phase Boundary

Finish and ship the damage meter reset prompt already built on `topic/dev` (`MeterReset.lua`,
settings `meterResetOnGroup` / `meterResetOnInstance`, `/tgf meter`, commit `6d2fe02`): the prompt
text starts with `[TGF]`, and the triggers, meter choice, settings and test command are checked
against MTR-01..04. No new triggers or meters.

</domain>

<decisions>
## Implementation Decisions

### Prompt text (MTR-03)
- Text: `[TGF] Reset Details! damage meter?` with Details! loaded, `[TGF] Reset the damage meter?` for the game's own meter (author: start with "[TGF]" so players know where it comes from)
- `[TGF]` is plain text, the same tag the whisper presets use (no colour code), so it reads as one line in the dialog's highlight font
- Buttons stay the game's `YES` / `NO` strings; no third "Don't ask again" button (the two settings cover turning it off)

### Behaviour (already built; keep)
- Meter choice: Details! when loaded (`Details:ResetSegmentData()`), else the game's meter only while `damageMeterEnabled` is on and `C_DamageMeter.IsDamageMeterAvailable()`; neither → nothing asked (author decision, 2026-11-16)
- Triggers: joining a group (not grouped → grouped) and entering any instance (outside or another instance → this one); a login or `/reload` only records state; roster updates before the first loading screen are ignored
- One dialog at a time; nothing resets without Yes; no Escape handling (keyboard propagation is restricted in combat)
- Own dialog frame (`DialogBorderTemplate`, StaticPopup's spot and button size), never `StaticPopupDialogs` (taint rule: never write Blizzard's data)

### Settings and command (MTR-04)
- Section "Damage meter" with "Ask to reset on joining a group" / "Ask to reset on entering an instance", both on by default (author decision)
- `/tgf meter` shows the prompt now; with no meter it prints why

### Claude's Discretion
- Whether the CLAUDE.md line needs the `[TGF]` wording; test updates in the session smoke harness

</decisions>

<code_context>
## Existing Code Insights

### Reusable Assets
- `MeterReset.lua`: `M.Target()`, `M.Reset()`, `M.Ask()`, `Build()` (dialog), `NAMES` (the meter's name in the question)
- `ns.W.Button`, `ns.W.Text`, `ns.W.Create` (template with fallback)

### Established Patterns
- Settings read where they act (`ns.Settings.Get`), registered in `Settings.lua` `OPTIONS`; the page is built from the list
- `[TGF]` is the addon's tag in whispers (`Messages.lua`, `{addon}` key)

### Integration Points
- `Core.lua` `ADDON_LOADED` calls `ns.MeterReset.Init()`; `/tgf meter` in the slash handler
- `TerribleGroupFinder.toc` lists `MeterReset.lua` after `Region.lua`

</code_context>

<specifics>
## Specific Ideas

- Author: "change the message to start with "[TGF]" so user knows where is the popup from and can disable easily if they want"
- The popup was simplified on request (one line + Yes / No, like the WeakerScripts sample's StaticPopup)

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope.

</deferred>
