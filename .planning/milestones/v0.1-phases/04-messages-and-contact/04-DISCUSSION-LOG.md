# Phase 4: Messages and Contact - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-11-11
**Phase:** 04-messages-and-contact
**Mode:** `--auto` (author AFK; the milestone brief fixed the behaviour, recommended option auto-selected for the rest)
**Areas discussed:** Presets and keys, Key buttons, Auto-send / Auto-invite, Contact lock, Migration, Side tab, Panel

---

## Presets and keys

| Option | Description | Selected |
|--------|-------------|----------|
| Store `{addon}`, render `[TGF]`, normalise in Format / on focus lost / on key insert | Key stays first without cursor jumps while typing | ✓ |
| Normalise on every keystroke | Cursor jumps | |
| Store literal `[TGF]` | Harder to tell from user text | |

| Option | Description | Selected |
|--------|-------------|----------|
| `{players}` = GetNumGroupMembers (min 1) | Counts you; solo = 1 | ✓ |
| Listing size | Not what the author asked | |

**Choice:** [auto] `{gs}` removed, `{name}` and `{role}` kept (author brief)

## Key buttons

| Option | Description | Selected |
|--------|-------------|----------|
| Same key set under both boxes, labelled with the key | Teaches the keys | ✓ |
| Per-preset key sets | `{players}` only on invite | |

## Auto-send / Auto-invite

| Option | Description | Selected |
|--------|-------------|----------|
| Unchecking Auto-send clears and greys Auto-invite | Author brief ("unchecks/greys") | ✓ |
| Keep Auto-invite checked but greyed | | |

| Option | Description | Selected |
|--------|-------------|----------|
| No invite when the whisper was only prefilled (lockdown) | Invite always follows a sent whisper | ✓ |
| Invite anyway | Invite before the message | |

## Contact lock

| Option | Description | Selected |
|--------|-------------|----------|
| Only auto-send clicks start the lock; others ignore clicks silently, look unchanged | Author brief | ✓ |
| Disable every contact button for 1 s | Visible flicker over the whole list | |

## Migration

| Option | Description | Selected |
|--------|-------------|----------|
| `db.version` marker, replace texts equal to any old default once | Phase 1 pattern, runs once | ✓ |
| Reset every preset | Loses custom texts | |

## Side tab and panel

**Choice:** [auto] UI-PARITY G1-G4 and G30-G33 as recommended there; icon kept (Q4 in game).

## Claude's Discretion

- Offsets, box height, spacing (UI-SPEC); key tooltip wording; lock helper location

## Deferred Ideas

- Localisation of labels; better tab icon; remembering Messages as the open tab
