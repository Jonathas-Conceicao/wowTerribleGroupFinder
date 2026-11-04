# TerribleGroupFinder

A group finder addon for **WoW Forever**. It improves the game's own group finder
in place, keeping its look:

- its Browse tab becomes a table of solo players and groups, in the game's two sections,
  sortable by role (tank, healer, damage), level or gear score; players you hide, and
  listings with no slot for you, are greyed and moved to the end instead of vanishing
- one-click whispers to a solo player or a group's leader, from preset messages you set
  in a new Messages tab (filled into the whisper box, or sent at once with Auto-send)
- Battle.net friends, friends and recent allies marked on names, as the game marks them
- gear scores remembered between sessions (older ones shown in their own colour),
  refreshed for your group on every ready check, and your own shown for reference

**Status:** prototype / proof of concept.

## Supported clients

- WoW Forever (interface 16001). Retail is not a target for now.

## Development

- Deploy to the local Forever client: `./scripts/install.bat` (set
  `TGF_WOW_ROOT` if WoW is not under `Program Files (x86)\World of Warcraft`).
- Local test zip: `./scripts/package.bat` writes `dist/TerribleGroupFinder-<version>-dev.zip`.
- In game: `/tgf` toggles the group finder on Browse; `/tgf preview` switches the table
  between your search results and sample listings; `/tgf reset` restores the sample data;
  `/tgf version`. Where the game has no group finder, `/tgf` opens a preview stand-in
  with the same layout, on sample data.
- Format with `stylua .` from the repo root.
- Release: `./scripts/release.bat <version>` from `main` tags and pushes;
  GitHub Actions packages it with the BigWigs packager.

Blizzard UI reference: [wow-ui-source](https://github.com/Gethe/wow-ui-source),
branch `forever` — mainly `Interface/AddOns/Blizzard_GroupFinder_VanillaStyle`
and `Blizzard_APIDocumentationGenerated/LFGList*Documentation.lua`.

## License

[GPL-3.0](LICENSE).
