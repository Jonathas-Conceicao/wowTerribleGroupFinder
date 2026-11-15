# Phase 5: Release Review - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-11-11
**Phase:** 05-release-review
**Areas discussed:** Cleanup scope, Version, Changelog draft, README, LICENSE shipping, Author review

Mode: `--auto` (author AFK). Every choice is the recommended option.

---

## Cleanup scope

| Option | Description | Selected |
|--------|-------------|----------|
| Dead code + comments + cheap review items | Remove dead code, strip planning refs, fix clear-cut info items | ✓ |
| Dead code and comments only | No review items | |
| All open UI review items | Includes behaviour/look changes | |

**Choice:** [auto] dead code + comments + cheap review items (recommended default)

## Version

| Option | Description | Selected |
|--------|-------------|----------|
| 0.1.0 / v0.1.0 | Milestone v0.1, first release | ✓ |

## Changelog draft

| Option | Description | Selected |
|--------|-------------|----------|
| Insert `## v0.1.0` above Unreleased, keep existing text | Append-only rule | ✓ |
| Replace Unreleased | Rewrites existing content (not allowed) | |

## README

| Option | Description | Selected |
|--------|-------------|----------|
| Leave untouched, suggestions in UAT | Author edits README | ✓ |
| Edit README | Not allowed without author direction | |

## LICENSE shipping

| Option | Description | Selected |
|--------|-------------|----------|
| Keep `.pkgmeta`, recommend shipping in UAT | Author's convention; their call | ✓ |
| Ship LICENSE now | Changes REL-03's file set without the author | |

## Author review

| Option | Description | Selected |
|--------|-------------|----------|
| 05-HUMAN-UAT.md, pending | Phase stays open | ✓ |

## Claude's Discretion

- Changelog and README-suggestion wording; key-button wrap restructuring.

## Deferred Ideas

- Tooltip blank lines, status colours, own-row hint, locked-click feedback, 02 IN-03 / IN-09, localisation.
