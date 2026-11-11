# TerribleGroupFinder

WoW Forever addon (interface 16001, game type `camelot`): improves Forever's own group
finder (`Blizzard_GroupFinder_VanillaStyle`) **in place**: its Browse tab gets a sortable
table of solo players and groups. Prototype stage. License: GPL-3.0.

## Key Constraints
- **Forever only.** One TOC, `## Interface: 16001`. Retail is out of scope for now
- No flavour-forked Lua/XML files; if a flavour is added later, extend the `## Interface:` list
- **In place, not a new window.** In game the addon changes Forever's own finder; it never opens a window of its own. The stand-in window (`UI/MainFrame.lua`) is for preview and development only, used where the game's finder is missing, and mirrors its layout
- Forever runs on the modern client: guard reads with `issecretvalue()` where values may be secret, and never send addon messages during `C_ChatInfo.InChatMessagingLockdown()`
- Realms: Forever is one mega-realm per ruleset (PvP, PvE, RP-PvP, RP-PvE) and the group finder only lists players from your own, so whisper and invite by plain character name, without a realm suffix
- UI should look native to Forever (Blizzard templates and atlases), not a custom skin
- Taint: never replace or write fields on Blizzard's finder; only `Hide()` its parts (hooked to stay hidden), `HookScript`, `hooksecurefunc`, resize `LFGParentFrame`, and parent our own frames to it. Restricted calls (`Search`, `CreateListing`, `UpdateListing`) stay Blizzard's

## Forever's group finder model (keep the UI faithful to it)
- A listing is a solo player (with the roles they can play) or a group (leader + members). No applications, no applicant list
- Leaders browse solo players and invite them; solo players browse groups and whisper the leader. **No "apply"**: each row's button whispers (preset messages, Messages tab)
- Browse picks a category and activities (Blizzard's dropdowns), then searches; results are one list: your listing, then two collapsible sections (Solo players, Groups) with a divider each — groups first while solo, solo players first while leading
- Never remove a listing from view: hidden (X, until they relist), delisted and (with Needs my role) no-slot-for-you listings are greyed and moved to the end of their section
- Listing (create/update/unlist) stays Blizzard's own tab, untouched: its description box is secure

## Architecture
- `Core.lua` — namespace, `TerribleGroupFinderDB`, runtime state (`ns.state`), the questions the table asks (`ns.IsLeader/CanInvite/MyRoles/Party/MyListingSize/GroupSize`) answered from the game or the preview, `/tgf`
- `Preview.lua` — sample categories, activities and listings (`ns.Preview`), same shape as `Listings.lua`'s
- `GearScore.lua` — `ns.GS`: our score (slot-weighted, quality-scaled item level), the cache (`DB.gs`: name → gs, level, time), fresh vs outdated (earlier session), ready check → inspect group members without a fresh score
- `Messages.lua` — `ns.Messages`: the whisper presets (`invite` for solo players, `request` for group leaders) with placeholders (keys such as `{players}`; `{addon}` renders `[TGF]` and is always first and only once), defaults, Auto-send (off: prefill the whisper box, Enter to send) and Auto-invite (solo players: whisper, then invite by plain name; needs Auto-send), a 1 s contact lock after a send, a one-time migration of the old default presets (custom ones kept), and `BuildPanel`, which builds the Who-style Messages panel for both the game and the preview
- `Listings.lua` — `ns.Listings`: reads Forever's search results into listing tables (secret values skip the listing), with friend / guildmate / recent ally marks, voice mode, playstyle and member counts
- `UI/Widgets.lua` — `ns.W` helpers: Blizzard templates/atlases first, plain textures as fallback where they're missing, pooled scroll list (fallback where the ScrollBox API is missing), dropdown, role/class icons, GS colours, `W.IconButton` (small atlas icon button, plain fallback) and `W.AtlasMarkup` (empty where the atlas is missing) and `W.SetPressed` (the pressed look held during the contact lock); tooltips use a gold title and a note line
- `UI/Templates.xml` — the two plain virtual Buttons (list header / list row) the table's ScrollBox pools; no scripts, no `file=` paths
- `UI/Table.lua` — `ns.Table`: the table placed in a Browse frame, scrolling in its own ScrollBox (Blizzard's `WowScrollBoxList` + `MinimalScrollBar`) with separate header and row frames (`W.List` fallback where the API is missing): sections, column headers above the list, selection by result ID (cleared on new results and when a search starts), the stock search states (spinner, no results, search failed, "no listings match" for our search box), the search box in the stone band beside the refresh button, Needs my role and the status in the bottom bar, a small icon hide button, Needs my role from the server's remaining slots, sort within each section by Roles (T>H>D) / Lvl / GS (groups: best known) / Activity / Listed, your GS, friend marks, Whisper per row, Send Message + Group Invite at the bottom (the contact buttons honour the 1 s lock and show the pressed look; Group Invite never locks). Rows look like Forever's: list-button art (mid2 background / hover / selected), class-coloured names, grey level, activity blue when it matches your active listing, greyed rows in stock grey with desaturated icons, the leader icon on groups, stock micro role icons for solo players and a Discord icon. Your own row shows "Your listing" with the stock delist button (solo player or leader; no Whisper). The row tooltip follows Forever's stock order and wording with our extras after it, and is re-shown for the row under the mouse whenever results update. Layout guard: fixed columns from the left, Listed + buttons from the right, Activity flexible between; every cell width-bound
- `UI/InPlace.lua` — attaches the table to `LFGBrowseFrame` once Blizzard's finder loads; widens `LFGParentFrame` while Browse shows; adds a fourth side tab (Messages: starts unchecked, icon filled like the stock tabs, a post-hook on `LFGParentFrame.UpdateTabs` keeps it from showing checked with a stock tab, the template's own tooltip); `/tgf`
- `UI/MainFrame.lua` — the preview stand-in for `LFGParentFrame` (Listing, Browse, Messages tabs; Blizzard's Browse geometry)
- `UI/Listing.lua` — the stand-in's copy of Forever's Listing tab (List Self / List Group); not used in game
- `TerribleGroupFinder.toc` — the load list is the shipped file set
- `scripts/install.bat` / `install.ps1` — deploy to the local `_forever_` client (derives files from the TOC)
- `scripts/package.bat` / `package.ps1` — local test zip in `dist/` (gitignored), same file set as install
- `scripts/release.bat` — tag and push a release; `.github/workflows/release.yml` packages it (BigWigs packager on tag push; CurseForge/Wago keys and TOC project IDs not set yet)
- `.pkgmeta` — BigWigs packager config

## Style Reference
- Blizzard UI source: `C:\Users\jonat\Repositories\wow-ui-source`, branch `forever` — read-only, never check out another branch or modify it
- Forever group finder: `Interface/AddOns/Blizzard_GroupFinder_VanillaStyle/` (Mainline XML is what Forever uses)
- API docs: `Interface/AddOns/Blizzard_APIDocumentationGenerated/LFGListInfoDocumentation.lua`
- Sister addon with the same conventions: `C:\Users\jonat\Repositories\TerribleBuffTracker`

## GSD Workflow
- **Project plan & workflow:** managed with GSD in `.planning/` — see `.planning/PROJECT.md` (context, requirements, decisions), `.planning/STATE.md`, and per milestone `ROADMAP.md` / `REQUIREMENTS.md`. Design notes from the prototype: `.planning/research/`
- **Milestone branching** (`git.branching_strategy = "milestone"`): each milestone runs on `milestone/{milestone}-{slug}`; on completion, push the branch, squash-merge it into `main` with one clean message, then tag `vX.Y.Z` on `main` and push the tag (see PROJECT.md → Git Workflow)
- **Milestone close-out:** milestones are atomic, and each one ends with a **Release Review** phase (code cleanup, README screenshots, version, changelog draft, then the author's review of `README.md` and `CHANGELOG.md`). A bug introduced and fixed inside a milestone is never mentioned outside `.planning/` (changelog, README, this file, code comments, commit messages on `main`). See PROJECT.md → Milestone Close-out
- **Changelog / README:** read by people and mostly written by the author. Agents don't add changelog entries during a milestone; the Release Review drafts the version's section once, for the author to review

## Workflow
- **Never overwrite or rewrite `CHANGELOG.md`.** Outside the Release Review's draft, append only, and only when asked
- Run `stylua .` from the repo root after finishing a task
- Never use `sed -i` or shell redirects on `.md` files or anything in `.planning/` — use the Edit tool
- Deploy with `./scripts/install.bat`, then `/reload` in game
