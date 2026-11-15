# Phase 8: Region Flags and Row Icon Tooltips - Context

**Gathered:** 2026-11-14
**Status:** Ready for planning
**Mode:** Smart discuss, recommended answers auto-accepted (author: never pause autonomous runs; decisions listed for review at the end)

<domain>
## Phase Boundary

Finish the region flag prototype (`Region.lua`) and give every icon on a finder row its own hover tooltip. Flags: one US flag for both US shard groups, an Oceania flag, none for unknown servers; the region named in the row tooltip; a flag on your own listing too; the known-server table grows as you play and is saved. Icons: every icon on a row (flag, role icons / open slots, new player friendly, Discord, leader, friend / Battle.net friend / recent ally marks, friends in group) explains itself on hover, without breaking row hover, click-select or the right-click menu. Gated by `ns.Settings` key `regionFlags` (read where it acts; the toggle redraws the table). The settings page is Phase 10.

</domain>

<decisions>
## Implementation Decisions

### Region flags (author, 2026-11-14)
- One US flag for US1 and US2 (no E / W letter on rows); Oceania flag for AU; no flag for an unknown server
- Your own listing shows a flag too: the group leader's region (yours when you're solo or lead)
- Flag stays where the prototype puts it: right after the name, before the friend marks
- Row tooltip line names the region in plain words, e.g. "Region: US East" / "Region: US West" / "Region: Oceania" (grey), no internal shard code; for a group "Leader's region: …"
- US1 = West / US2 = East stays the assumed mapping (to confirm in game at the milestone end); the tooltip wording uses it
- Known servers: the seeded table plus learned ones (your own server, Battle.net friends' servers) saved in `DB.shards`; a learned entry only fills gaps, never overrides a seeded one; every reader guards secret values
- `regionFlags` off: no flags on rows and no region line in tooltips; turning it on/off redraws without a reload

### Icon tooltips
- Each icon gets its own small tooltip anchored to the icon, in the addon's existing tooltip style (gold title + optional grey/white note), replacing the row tooltip while the mouse is over the icon; moving back onto the row shows the row tooltip again
- Wording: reuse stock strings where they exist, read at runtime with plain fallbacks: new player friendly (`LFG_LIST_NEW_PLAYER_FRIENDLY_HEADER` / `_TOOLTIP`), voice (`VOICE_CHAT_MODE_FORMAT` + the voice mode label, e.g. Discord), roles (`TANK` / `HEALER` / `DAMAGER`; an open slot says "Open <role> slot"), leader ("Group leader"), class icon on a solo row (the class name), friend marks ("Battle.net friend" / "Friend" / "Recent ally"), friends in group (stock "Friends in group:" header + the names), flag (the region, as above)
- Implementation per research PITFALLS 9: icons that need a tooltip become real textures (the Discord icon is the pattern) with child hit frames created once per row, `SetPropagateMouseMotion(true)` / `SetPropagateMouseClicks(true)` so hover, click-select and right-click still reach the row; tooltip-owner checks include hit-frame children; hit frames and their tooltips are cleaned up when a row frame is recycled; the row tooltip re-show on result updates never overrides an open icon tooltip
- Greyed rows: icons keep their tooltips (same text)

### Claude's Discretion
- Exact layout of icon textures in the name cell (keep current visual order and spacing as close as possible)
- Whether the `/tgf region` probe stays (recommended: keep, diagnostic like `/tgf ilvl`)
- Harness stubs for hit frames and propagation

</decisions>

<code_context>
## Existing Code Insights

### Reusable Assets
- `Region.lua`: `Group`, `Learn`, `Of`, `Markup`, `LearnAround`, `Init(db)`, `Probe`, `KNOWN` seed table, `PLACES` (US1 / US2 / AU1)
- `UI/Table.lua`: `FillRow` (name text built from `who.name .. ns.Region.Markup(l.shard) .. W.Marks(who) .. tags`, Discord texture pattern), `ExtrasTooltip` (region line), `ShowTooltip`, `RefreshTooltip`, `HoveredRow`, ScrollBox element resetter
- `UI/Widgets.lua`: `W.Icon`, `W.Marks`, `W.AtlasMarkup`, `W.Tooltip`, role icons
- `Listings.lua`: `l.shard` from `partyGUID`; `Preview.lua`: sample shards (own entry needs one)
- `Settings.lua`: `regionFlags` registered (default on)

### Integration Points
- `UI/Table.lua` row build / fill / resetter; `Region.lua`; `Preview.lua` own entry; harness (scratchpad `smoke/`)

</code_context>

<specifics>
## Specific Ideas

- Author: "all LFG window icons should have a tooltip for what they are, like the murloc for new player welcome and so on"; "for US flags let's have just 1 icon for both US1 and US2"; "region flags on our own listing (based on the group leader flag)"

</specifics>

<deferred>
## Deferred Ideas

- A region filter for the list (not in v0.2)

</deferred>
