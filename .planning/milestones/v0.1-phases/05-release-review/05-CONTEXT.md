# Phase 5: Release Review - Context

**Gathered:** 2026-11-11
**Status:** Ready for planning

<domain>
## Phase Boundary

Close out milestone v0.1 per PROJECT.md → Milestone Close-out: code cleanup (no behaviour change,
plus cheap clear-cut fixes of open review info items), version confirmation (0.1.0 / tag `v0.1.0`),
a drafted `## v0.1.0` section at the top of `CHANGELOG.md`, and the author's review of
`README.md` and the changelog draft as the phase's UAT (left open for the author). No new features,
no push, tag or merge.

</domain>

<decisions>
## Implementation Decisions

### Code cleanup scope
- **D-01:** Remove dead code and duplication added during the milestone. Candidates (the planner
  must confirm each is still present before scheduling it): `W.Line` with no callers,
  `host:ForEachFrame` / `list:ForEachFrame` with no callers, `row.item` and `row.listing` holding
  the same table (keep one), `local view` in `BuildList` shadowing the module `view` (rename to
  `scrollView`), `VoiceLabels()` rebuilt per tooltip (cache once, lazily), `HoveredRow()` computed
  before the `band:IsVisible()` early return.
- **D-02:** Strip planning references from code and doc comments: review IDs (WR-/IN-/CR-),
  decision IDs (`D-19` etc.), phase numbers, and any wording that describes an in-milestone bug
  ("used to", "previously", "fix for", "no longer"). Comments describe what the code does now.
- **D-03:** `CLAUDE.md`: strip any in-milestone bug mention and bring the Architecture lines that
  no longer match the code in line with it (gear score is switched off behind `ns.GEAR_SCORE`, so
  the Table line's GS sort / "your GS" and the GearScore line are described as off; Messages line
  mentions the keys, Auto-invite and the contact lock). Only accuracy edits, no restructuring.
- **D-04:** Cheap, behaviour-neutral or clearly bug-fixing items from the reviews are in scope:
  - Messages key-button wrap (04 IN-01 / UI review): wrap at most once, so a third row can never
    start over the Auto-send row (drop the forced `i == 5` break when the width test already
    wrapped, or make the width test the only rule while keeping two rows for the stock labels).
  - Example line (04 IN-02): pick the first sample listing of the right kind (solo for the invite
    preset, group for the request preset) instead of by position.
  - Pasted newlines (04 IN-03): keep the cursor position when stripping newlines.
  - Hide hint wording (03 IN-01): word the tooltip hint without naming the eye icon.
  - Preview flags (02 IN-08): `searching()` / `failed()` return false while `ns.UsingPreview()`.
  - Stale status while searching (02 IN-04): clear the status text and shown IDs in the searching
    branch before `RefreshButtons()`.
  - Header labels width-bound on the template path (02 IN-05) if it is a two-anchor change.
- **D-05:** Out of scope for cleanup (recorded for the author / later milestones): tooltip blank-line
  rules vs UI-SPEC, raw `|cff..` status colours, a hint on a non-leader's own row, feedback for
  clicks during the lock or lockdown prefill, intro text length, disabled Auto-invite label font,
  02 IN-09 (listings during chat lockdown — a behaviour choice), 02 IN-03 (triple refresh on show —
  touches selection ordering), playstyle colour (author's call), localisation.
- **D-06:** Run `stylua .` and the smoke harness (default, `--gs`, `--fallback`, `--attach`) after the
  cleanup; all must end `0 failed`.

### Version
- **D-07:** Milestone version is **0.1.0**, tag `v0.1.0`. The TOC keeps `## Version: @project-version@`
  (already true). Nothing to edit; record the confirmation in the summary.

### Changelog draft
- **D-08:** Insert a new `## v0.1.0` section at the top of `CHANGELOG.md`, directly under `# Changelog`
  and above the existing `## Unreleased` section, with the Edit tool. The existing text stays as is;
  the author is told that the bootstrap line under Unreleased likely folds into v0.1.0.
- **D-09:** Content: one-line summary, then Added / Changed / Removed / Fixed, user-facing and short.
  This is the first release, so the sections describe what the addon offers. Changed / Removed are
  kept only if they say something to a user (gear score being off is not a removal for a first
  release: nothing was released with it). Fixed is empty and omitted or marked as none.
  Never name or describe any third-party or reference addon.

### README
- **D-10:** `README.md` is not edited (agents change it only as the author directs). The suggested
  changes go into `05-HUMAN-UAT.md`: drop the gear score mentions (sort by gear score, the gear score
  bullet), describe the Messages tab keys, Auto-invite and the 1 s contact lock, the own-listing row
  with delist, the tooltip, the icon; status line wording for a first release.

### README screenshots
- **D-11:** The README has no screenshots: step skipped, noted in the summary and UAT.

### Packaging / LICENSE
- **D-12:** `.pkgmeta` keeps excluding `LICENSE` (the author's own convention). Recommendation for the
  author, recorded in `05-HUMAN-UAT.md`: ship `LICENSE` in the release zip (drop it from `.pkgmeta`'s
  ignore list and add it to the install / package file set), since the TOC declares GPL-3.0 and the
  licence text normally travels with the distributed files.

### Author review (UAT)
- **D-13:** `05-HUMAN-UAT.md` lists, pending: README review (with the suggestions), CHANGELOG draft
  review, open decisions (playstyle colour, LICENSE shipping, branch name `milestone/v0.1-milestone`
  vs the intended `milestone/v0.1-initial-release`, the stray local `milestone/v1.0-milestone`
  branch, store secrets `CF_API_KEY` / `WAGO_API_TOKEN`, whether CurseForge / Wago accept the
  `forever` game type) and a consolidated pointer to the in-game checks in phases 1–4
  `*-HUMAN-UAT.md`. Phase 5 is not marked complete.

### Claude's Discretion
- Exact wording of the changelog draft and the README suggestions.
- How the key-button wrap rule is restructured, as long as the stock labels keep two rows.

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Close-out rules
- `.planning/PROJECT.md` §Milestone Close-out — the steps of this phase, atomic milestones
- `CLAUDE.md` — constraints, architecture list, workflow rules (Edit tool for `.md`, never rewrite CHANGELOG)
- `.planning/ROADMAP.md` §Phase 5 — success criteria

### Open review items (cleanup inputs)
- `.planning/phases/02-list-foundation/02-REVIEW.md` §Info — IN-01..IN-09
- `.planning/phases/03-rows-tooltip-and-own-listing/03-REVIEW.iter2.md` §Info — IN-01..IN-03
- `.planning/phases/04-messages-and-contact/04-REVIEW.md` §Info — IN-01..IN-03
- `.planning/phases/03-rows-tooltip-and-own-listing/03-UI-REVIEW.md`, `.planning/phases/04-messages-and-contact/04-UI-REVIEW.md` — advisory UI items

### In-game checks to point at
- `.planning/phases/01-gear-score-off-and-release-plumbing/01-HUMAN-UAT.md`
- `.planning/phases/02-list-foundation/02-HUMAN-UAT.md`
- `.planning/phases/03-rows-tooltip-and-own-listing/03-HUMAN-UAT.md`
- `.planning/phases/04-messages-and-contact/04-HUMAN-UAT.md`

### Release plumbing
- `TerribleGroupFinder.toc`, `.pkgmeta`, `.github/workflows/release.yml`, `scripts/package.ps1`, `scripts/install.ps1`

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- Smoke harness (outside the repo, in the session scratchpad `smoke/run.js`) with modes default, `--gs`, `--fallback`, `--attach`
- `ns.Preview.listings` entries carry a kind (solo / group) usable for the example line

### Established Patterns
- `stylua .` formatting; comments are plain present-tense descriptions
- All work stays on `milestone/v0.1-milestone`; no push / tag / merge in this phase

### Integration Points
- `UI/Table.lua` (dead code, tooltip hint, preview flags, status), `UI/Widgets.lua` (`W.Line`, ForEachFrame), `Messages.lua` (key wrap, example, cursor), `CHANGELOG.md`, `CLAUDE.md`

</code_context>

<specifics>
## Specific Ideas

- The run is autonomous (author AFK): every choice above was auto-selected and logged; the author's review stays open.

</specifics>

<deferred>
## Deferred Ideas

- Items in D-05 (tooltip blank lines, status colours, own-row hint, locked-click feedback, IN-09, triple refresh, localisation) — next milestone candidates
- Gear score finish-or-drop stays in backlog 999.1

</deferred>

---

*Phase: 05-release-review*
*Context gathered: 2026-11-11*
