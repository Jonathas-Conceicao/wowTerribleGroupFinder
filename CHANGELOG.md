# Changelog

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
