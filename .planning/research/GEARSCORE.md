# Gear score: design notes and how to re-enable

## Status

Switched off for v0.1 behind `ns.GEAR_SCORE = false` in `Core.lua` (D-01). `GearScore.lua`
still loads, but `GS.Init` returns early: it creates no frame and registers no event (D-02),
so nothing is inspected and nothing is pruned. The saved cache `DB.gs` is left untouched
(D-04). Backlog item 999.1 in `ROADMAP.md` ("Gear score: finish or drop", GS-02) decides
whether to finish or remove it.

## Formula

Our own score, on the item level scale:

- Each gear slot's item level, times a quality factor, times the slot's weight (GearScore's
  public slot weights), summed and divided by the total weight of the 17 gear slots.
- A two-hander takes both hand weights (the off-hand slot is skipped).
- The shirt and tabard do not count. An empty slot counts 0.
- Items whose quality has not loaded yet count with factor 1 and mark the result incomplete;
  incomplete results are retried and not stored.
- Stored scores are rounded to one decimal.

Slot weights (`SLOTS` in `GearScore.lua`):

| Slot id | Slot | Weight |
|---------|------|--------|
| 1 | Head | 1 |
| 2 | Neck | 0.5625 |
| 3 | Shoulder | 0.75 |
| 5 | Chest | 1 |
| 6 | Waist | 0.75 |
| 7 | Legs | 1 |
| 8 | Feet | 0.75 |
| 9 | Wrist | 0.5625 |
| 10 | Hands | 0.75 |
| 11 | Finger 1 | 0.5625 |
| 12 | Finger 2 | 0.5625 |
| 13 | Trinket 1 | 0.5625 |
| 14 | Trinket 2 | 0.5625 |
| 15 | Back | 0.5625 |
| 16 | Main hand | 1 |
| 17 | Off hand | 1 |
| 18 | Ranged | 0.3164 |

Quality factors (`QUALITY`), against an epic of the same level:

| Quality | Name | Factor |
|---------|------|--------|
| 0 | Poor | .5 |
| 1 | Common | .7 |
| 2 | Uncommon | .85 |
| 3 | Rare | .93 |
| 4 | Epic | 1 |
| 5 | Legendary | 1.1 |
| 6 | Artifact | 1.1 |
| 7 | Heirloom | .93 |

## Cache

`DB.gs` (`TerribleGroupFinderDB.gs`) maps name to `{ gs, level, at }` (score, the player's
level, `time()` when seen). Names are stored without a realm suffix (`ns.Short`). Entries
older than 60 days (`KEEP_DAYS`) are pruned in `GS.Init`, as are malformed ones.

## Fresh vs outdated

A score read this session is fresh. One known only from an earlier session is outdated and
is shown in `W.GS_OUTDATED` = `|cffb08d57`, and row tooltips add "(earlier today / N days
ago)". Colour tiers come from `W.GS` (`UI/Widgets.lua`), by share = gs / (level + 5), level
defaulting to 60:

- share >= 1.05: purple `|cffa335ee`
- share >= 0.95: blue `|cff0070dd`
- share >= 0.8: green `|cff1eff00`
- below: white `|cffffffff`
- unknown: grey dash `|cff666666-|r`

## Inspect queue

- A ready check (`READY_CHECK`) queues every group member without a fresh score and stores
  your own.
- One inspect at a time, `INSPECT_GAP` 1.5 s between inspects, `INSPECT_WAIT` 4 s timeout
  per inspect, up to `ITEM_RETRIES` 3 item-data tries a second apart.
- Never in combat and never while `InspectFrame` is open (the queue waits twice the gap and
  tries again).
- Own score: `PLAYER_EQUIPMENT_CHANGED` and `PLAYER_ENTERING_WORLD`, one second later.
- Skips units that don't exist, are offline, or fail `CanInspect`.

## Display

- GS column (x=268, w=44, centered, header "GS"), sorted descending first. For groups it
  shows the best known GS among the leader and members.
- "Your GS" text in the table's top band, with a hover tooltip; it uses `ns.Me().gs`.
- GS line in row tooltips: solo players get a right-hand "GS n"; group members each get
  their score on the right.
- `{gs}` message key in the Messages tab and `M.Format`, filled from your own score ("?"
  when unknown).
- Without the switch the Activity column starts at x=268 instead of 318.

## Idea for later

Share scores between TerribleGroupFinder users by addon whisper, since listed players are
rarely in inspect range: a versioned one-line message of at most 255 bytes, sent through a
send queue within the addon message limits; drop messages from self, ignored players,
flooders and malformed senders; send nothing during `C_ChatInfo.InChatMessagingLockdown()`.

## Open in-game checks

- Ready-check inspects on Forever: range, timeouts, whether `CanInspect` and
  `INSPECT_READY` behave as expected.
- Tune the quality factors and colour tiers against real gear on Forever's items.

## How to re-enable

Set `ns.GEAR_SCORE = true` in `Core.lua`. Nothing else.

What comes back:

- The GS column with its header, sort and descending-first entry.
- "Your GS" in the top band and its tooltip.
- The GS lines in row tooltips.
- The `{gs}` key: listed in the Messages tab's placeholder list (whose help text then says
  the rest include your gear score), filled by `M.Format`, and `ns.Me().gs`.
- `GS.Init`'s cache prune and its four event registrations: `INSPECT_READY`,
  `READY_CHECK`, `PLAYER_EQUIPMENT_CHANGED`, `PLAYER_ENTERING_WORLD`.
- Cache use: lookups for listings and group members, and the ready-check inspects.

What does not come back by itself:

- The default request preset no longer contains `GS {gs}` (a fresh install or a "Default"
  click gives the preset without it); users add the key themselves.
- The saved request text of anyone who logged in with the switch off and still had the old
  GS default (`... ({role}, GS {gs}), ...`) was reset to the new default by `M.Init`'s
  migration. That cannot be undone by the switch; the key has to be added back by hand.
- README and CHANGELOG wording about gear score.
- Phase 2's re-layout of the table may need the GS column width again.
