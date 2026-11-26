# Changelog

## v0.3.1

See how your invites ended, a list that follows the activities you pick, and a fix for the elite quest button.

### Added

- After you invite a player from the list (Group Invite or Auto-invite), their row says whether they accepted, declined, or the invite expired

### Changed

- Picking an activity in the Browse tab (for example one dungeon after choosing Dungeons) shows only that activity's listings at once, without pressing Refresh

### Fixed

- Clicking the elite quest button could raise Lua errors

## v0.3.0

A group finder eye on elite quests, item level and enchants beside each gear slot, and extras you turn on yourself.

### Added

- Elite quest LFG button: clicking it sets you up to create a listing with the quest's zone selected; you type the description yourself, due to Blizzard API restrictions
- Slot item level and enchant on the character sheet and the Inspect window

### Changed

- New installs start with only the group finder's options on (Elite quest button, Dynamic refresh, Swipe animations, Region flags); item level, talents, slot info and the damage meter prompts are off until you turn them on in Settings > AddOns > TerribleGroupFinder. If you already use the addon, your settings are kept
- The Settings page is now ordered Group finder, Player inspection, Damage meter, Messages; "Item level and talents" is now "Player inspection". After an update, new options carry the game's blue NEW tag (also on the addon's entry in the AddOns list) until you close Settings after looking at them

## v0.2.2

A damage meter prompt you can move, a choice of activity when whispering, and Settings buttons that act at once.

### Added

- Move the damage meter prompt: Settings > Damage meter > Move shows it so you can drag it; Lock keeps the spot, Default puts it back below the zone name
- Whispering a listing with several activities asks which one to name in the message; Edit fills in the whisper box with all of them, to write it yourself

### Changed

- The damage meter prompt shows the addon's icon and the game's own buttons
- Move and Edit whisper messages close the Settings window themselves
- "Ask to reset on joining a group" is off by default for new installs; existing settings are kept

## v0.2.1

A damage meter reset prompt, talent points on player tooltips, and region flags for more regions.

### Added

- Damage meter reset prompt: joining a group or entering a dungeon, raid or battleground asks whether to reset Details! (or the game's own damage meter when Details! isn't loaded); each prompt can be turned off in Settings
- Talent points per tree (for example 31/20/0) on friendly players' tooltips, under the item level, with its own setting
- Region flags for EU, China and Korea

### Changed

- The US and Oceania flags have proper art
- The settings section "Item level" is now "Item level and talents"

## v0.2.0

Item level across the game's UI, region flags, a refresh that keeps the list, and a settings page.

### Added

- Item level on friendly players' tooltips, on weapon and armor tooltips, as a row under Movement Speed on the character sheet, and on the Inspect window
- Region flags (US / Oceania) after each name, your own listing included, with the region in the row tooltip
- Tooltips on every row icon
- `{ilvl}` key for whisper messages: your equipped item level
- Settings page in Settings > AddOns (also `/tgf settings`): turn each item level spot, Dynamic refresh, the animations and region flags on or off
- `/tgf ilvl` and `/tgf region` print the item level and region details the addon reads, handy for bug reports

### Changed

- Dynamic refresh: the refresh button now keeps the list and updates it in place, with rows swiping out and in (try it in `/tgf preview`)
- Raid groups show a count beside each role icon, as the game's own finder does, instead of text

### Fixed

- Needs my role no longer greys groups that still have a slot for you

## v0.1.0

First release: Forever's own group finder gets a sortable table of solo players and groups, and whisper presets.

### Added

- Browse tab results table with class-coloured names, level, roles (open slots for groups), activity and listed age
- Solo players and Groups as collapsible sections, groups first while you are solo and solo players first while you lead
- Click a column header to sort each section by roles, level, activity or listed time
- Your own listing at the top, with the delist button
- Search box for name, activity or note, and a Needs my role filter
- Hide a player until they list again; hidden and delisted listings are greyed and moved to the end, never removed
- Select a row for Send Message and Group Invite at the bottom, or use the Whisper button on each row; right-click a row for the game's own menu
- Row tooltip in Forever's style, with friends in the group and listed age
- Player location: each row shows the solo player's or the group leader's zone, and a group's tooltip shows each member's zone
- Friend, Battle.net friend, guildmate and recent ally marks
- Messages tab with two whisper presets (inviting a player, used while you're in a group or to a solo player; asking a group for an invite, while you're on your own), key buttons, Auto-send and Auto-invite; a short pause after each automatic send, and nothing is sent during chat lockdown
- Slash commands `/tgf`, `/tgf preview`, `/tgf reset` and `/tgf version`
- Addon icon
