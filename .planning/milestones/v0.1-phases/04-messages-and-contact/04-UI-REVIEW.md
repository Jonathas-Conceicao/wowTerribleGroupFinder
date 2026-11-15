# Phase 4 — UI Review

**Audited:** 2026-11-11
**Baseline:** 04-UI-SPEC.md (status approved; its checker sign-off boxes are still "pending"), with 04-01..04-SUMMARY.md, 04-HUMAN-UAT.md and Phase 3's `03-UI-REVIEW.md` as the format reference. Blizzard's own source (`wow-ui-source`, branch `forever`) was consulted for the templates the panel inherits.
**Screenshots:** not captured. This is a WoW addon with no dev server or browser, so the audit is code-only. Items that need the game client are listed under "Needs in-game confirmation" and mirror the 11 pending tests in `04-HUMAN-UAT.md`. They are not scored as defects.

---

## Pillar Scores

| Pillar | Score | Key Finding |
|--------|-------|-------------|
| 1. Copywriting | 3/4 | Every contract string is present and word-for-word. Deviations: the Auto-invite tooltip's "Works only when you can invite" has no on-screen counterpart, and a lockdown fallback is silent. |
| 2. Visuals | 3/4 | Layers, divider, key rows, side tab and press look follow the Who-tab contract. The two-row key layout can break into three rows and collide with the checkbox row. |
| 3. Color | 4/4 | No raw colour codes or hex in the new panel. Every colour comes from a font object or colour global, and the press look is stock button art. |
| 4. Typography | 3/4 | Font objects only. The intro is sized to the 4-line cap with no margin, and the Auto-invite label may jump in size when it is disabled. |
| 5. Spacing | 3/4 | Offsets match the contract numbers (block y 0 / -208, box 410 x 56, rows -86 / -110, checkbox -138, example -168, Default -6 / -140). The overflow guard is not independent of the forced row break. |
| 6. Experience Design | 3/4 | Auto-invite gating, the lock and the press survive recycling and re-show. A lockdown prefill is silent and the example line previews text the Whisper button may not send. |

**Overall: 19/24**

No BLOCKER found. Pillars 1, 2, 4, 5 and 6 carry WARNING-level findings.

---

## Top 3 Priority Fixes

1. **Key-row overflow guard stacks on the forced break and can collide with the checkbox row** (WARNING) — `Messages.lua:438-440`. The condition `i == 5 or (x > 0 and x + b:GetWidth() > BOX_WIDTH)` is evaluated per button. If row 1 overflows 410 px (longer fonts, another locale) and wraps early, `{players}` lands on row 2 and `{class}` is then force-broken to a third row. The third row sits at y -134 to -156, overlapping the Auto-send checkbox at y -138. The contract says the guard "wraps greedily to a further row only as a guard", meaning the explicit break must not add a row on top of a guard wrap. Fix: track `rowIndex`, break at `i == 5` only when the current row is still the first one (or when `x > 0` and the previous break was not already taken), and shift the checkbox, Default and example rows by `(rows - 2) * 24` if a third row ever appears. The 32 px spare at the panel bottom can absorb one extra row.
2. **Intro text has zero headroom in its 4-line cap** (WARNING) — `Messages.lua:271-315`. The intro is about 290 characters in `GameFontHighlightSmall` at 430 px. The contract budgets 4 lines (48 of the 60 free px), and `SetMaxLines(4)` will silently cut the last sentence, "After an automatic send, the contact buttons rest for 1 second.", if the font renders wider than the estimate. The sentence that explains the 1 s lock is the one at risk, and nothing signals the cut. Fix: confirm in game (UAT 8), then either tighten the copy by one clause or lower the band's top margin from -27 to -25 for a fifth line. The band is 66 px tall, so five 12 px lines fit if the top offset drops to about -24.
3. **Contact lock gives no feedback beyond the press on the one clicked button** (WARNING) — `UI/Table.lua:662, 695`. During the 1 s lock `Instance:Message` and `Instance:Invite` return silently, with no sound, no tooltip change and no look change on the other buttons. That matches the contract (D-15 and auto-decision 6), so it is by design. The cost is that a user who clicks a second Whisper within the second sees nothing happen. The same is true of a click during chat lockdown, which silently becomes a prefill. Fix, optional and within the contract's spirit: let the prefill path print one `ns.Print` line the first time per session ("Chat is locked down: the message was put in the whisper box instead"). Alternatively, add it to the Auto-send tooltip body. Do not change the lock look.

Further issues, lower priority:

4. Disabled Auto-invite swaps its label to `GameFontDisableSmall` (`Messages.lua:496`) while the enabled label is whatever `UICheckButtonTemplate` ships (`normalFont`, `:485`). `W.Check`'s comment says the template label is `GameFontNormalSmall`. If the template's font is larger than the Small variant, the label shrinks when Auto-send is off and the row reflows by a few pixels. Confirm in game (UAT 5), and if it jumps, use `GameFontDisableSmall`'s non-small peer or recolour with `SetTextColor` instead of swapping the font object.
5. `PresetBox` sets `SetMaxLetters(255)` in letters (`Messages.lua:328`), while `M.Clip` cuts at 255 bytes (`:83-98`). A message with multibyte characters (accented names) can be accepted by the box and then cut shorter by `Clip` on send or save. The char count shows letters remaining, so the user sees a number that is wrong for those messages. Fix: either document that the limit is bytes or cap the box with an `OnTextChanged` byte check.
6. The Messages tab icon fallbacks exist (`UI/InPlace.lua:148-158`), but the tab is probed only by method names. If Forever's `LargeSideTabButtonTemplate` has neither `SetFillToInterior` nor `UpdateIconInterior`, the 30 x 30 fallback applies and the icon looks unlike the three stock tabs. In-game check Q4, already listed.
7. The Example line always formats against `ns.Preview.listings` (`Messages.lua:379`), including in game. The sample leader name and activity are sample data. This is labelled "e.g.", which is honest, but a user can read the sample's activity as real. Consider using a neutral sample ("Name", "the dungeon") in game, where `M.Format` already has fallbacks.
8. Hard-coded English throughout (titles, help, intro, tooltips, `ROLE_NAMES`). Localisation is deferred by the contract, so this is tracked, not a regression.
9. The stand-in's Messages panel (`UI/MainFrame.lua:353-357`) is a bare `CreateFrame("Frame")` handed to `BuildPanel`. The UI-SPEC check "stand-in offsets match the in-game layers" depends on `UI.AddPanel` sizing that frame to 458 x 535 and on the shell supplying the title and portrait. It was not verified from the code read here.

---

## Detailed Findings

### Pillar 1: Copywriting (3/4)

Matches the contract:
- Intro, both block titles and help lines, "Auto-send", "Auto-invite", "Default", the "e.g. " prefix, and every key tooltip are word-for-word identical to the Copywriting Contract (`Messages.lua:22-34, 271-277, 449-512`). `[TGF]` uses the label as its tooltip title, as specified.
- The Messages tab tooltip is `tooltipText = "Messages"` only, with no `W.Tooltip` hook (`UI/InPlace.lua:162`).
- "Turn on Auto-send first." is a gray second line, produced by the `note` callback only when the button is disabled (`:478-482`), and the tooltip still opens while disabled via `SetMotionScriptsWhileDisabled` (`:469-471`).
- Default presets read as plain, specific messages (`Messages.lua:17-20`) and the migration list stops old defaults from persisting.
- Labels name the action, not generic OK/Submit/Cancel. The row CTA "Whisper" is unchanged, per D-13.

Deviations:
- The Auto-invite tooltip says "Works only when you can invite", but nothing in the panel shows whether the player can invite right now. `ns.CanInvite()` gates the send (`:220`) and the panel never reflects it (WARNING, low).
- The lockdown fallback and the "could not send" path produce no panel copy. The contract accepts this for the lockdown case ("no message shown, as today"). The failed-send line "could not send the whisper to <name>." is only in chat (`:244`).
- Fix 3 above (silent lock).

### Pillar 2: Visuals (3/4)

Matches the contract:
- Layers follow `Who.xml`: `groupfinder-background` at (4, -80) / (-4, 3); stone band at (2, -21) to the art's top-right with y -7; `common-insideframe` border at (3, -78) / (-4, 3); one `groupfinder-ScrollLine` at y -300 with atlas height. Each is gated on `W.HasAtlas` with a flat-colour or skip fallback, so the panel never errors (`Messages.lua:287-316`).
- The panel is one builder shared by the game tab and the stand-in (`BuildPanel`), which holds the "mirrors Forever's layout" rule.
- A clear focal point per block: gold title, help in grey on the same line, the box, then the controls in a fixed reading order (keys, toggles, example).
- Key buttons are grouped as specified (4 + 3, `[TGF]` first), 22 tall, width from `GetStringWidth() + 24`, 4 px gap, each with a gold-title tooltip (`:411-445`).
- Auto-invite is shown on the invite block only, visible but disabled when Auto-send is off, per auto-decision 4. The Default button is right-aligned to the box edge.
- The "sending" look: `SetButtonState("PUSHED", true)` plus a re-apply of the stock `UI-Panel-Button-Down` art on mouse-up, show and enable (`UI/Widgets.lua:335-376`). The paths are the same files Blizzard's own templates use (`SharedUIPanelTemplates.xml:760`, `Blizzard_SecureTransferUI.xml`). `FillRow` re-applies it per fill by listing id and source (`UI/Table.lua:1123, 1321`), so recycled rows do not show a stale press.
- Side tab: `LargeSideTabButtonTemplate` under `WhoListingTab` at y -2, `SetChecked(false)` on creation, fill-to-interior with a fallback ladder, stock tabs unchecked via `UpdateTabs` hook (`UI/InPlace.lua:134-183`). Only `SetChecked` is written on Blizzard's tabs, as the taint rule allows.

Weaknesses:
- Fix 1 (third key row overlaps the checkbox row).
- Fix 2 (intro may truncate).
- The Default button is the only element pinned right; Auto-send / Auto-invite sit left at x 0 to about 196. Between them is about 140 px of empty row. That is by contract, but it makes the row read as unbalanced. No change recommended without a design decision.
- The side tab icon under the fill mask is unconfirmed (Fix 6).

### Pillar 3: Color (4/4)

- The new code has no `|cff` strings, no hex and no `rgb()`. A grep of `Messages.lua` for colour literals finds only the flat fallbacks in `BuildLayers` (`SetColorTexture(0.05, 0.05, 0.05, 0.8)` and `(0.12, 0.1, 0.08, 1)`), which are the contract's stated fallbacks for missing atlases.
- Text colour roles come from font objects: `GameFontNormal` (titles), `GameFontHighlightSmall` (intro, box), `GameFontDisableSmall` (help, example, disabled label), `GameFontNormalSmall` (key labels). The tooltips use `NORMAL_FONT_COLOR`, `HIGHLIGHT_FONT_COLOR` and `GRAY_FONT_COLOR` with contract-matching fallbacks (`UI/Widgets.lua:280-292`).
- The accent is reserved for nothing, and nothing uses it. The pressed state is template art, not a colour. Phase 3's raw-colour issue (six `|cff` sites in `UI/Table.lua`) is not repeated here.
- Not a defect, but worth knowing: the help line and the example line use the same grey as the disabled label, so a disabled Auto-invite reads like help text. The contract chose this.

### Pillar 4: Typography (3/4)

- Font objects only. `W.Text(..., 13 / 11 / 10)` sizes apply only when the object fails to resolve (`UI/Widgets.lua:218-226`). Key labels are `GameFontNormalSmall` / `GameFontDisableSmall`; Default uses `GameFontNormal` via `W.Button`, as the contract's table says.
- Distinct sizes: Normal (titles, Default), Small (keys, intro, box, checkboxes), DisableSmall (help, example). That is three sizes and a gold / white / grey split, within the contract.
- Weakness: Fix 2 (intro headroom) and Fix 4 (disabled label font swap).
- The title and help share one line, with help anchored `LEFT` of the title's `RIGHT` + 8 and `SetWordWrap(false)`. The longest title plus its help is roughly 150 + 8 + 250 px, so it fits in 422 px at the estimated widths. A wider font would clip the help silently rather than wrap. Low risk.

### Pillar 5: Spacing (3/4)

- Offsets match the contract table: blocks at content y 0 and -208 (422 x 192), content frame (18, -100) / (-18, 16), title at 0, help +8, box at (6, -20), key rows starting -86 with pitch 24, checkbox row -138, Auto-invite at Auto-send's label + 16, example at (4, -168) with `SetMaxLines(2)`, Default at (-6, -140), box 410 x 56 with the edit box 392 wide (`Messages.lua:274-279, 326-329, 372-376, 412, 455, 468, 511`).
- Vertical budget holds: block 2 ends at content y -400 (panel y -500), 32 px under the art bottom's 532.
- Divider sits at panel y -300, between block 1's end (-292) and block 2's start (-308), 8 px each side.
- No arbitrary-value drift beyond the contract's numbers. The magic numbers `18`, `24`, `16` and `-168` are each commented in the spec, not in the code.
- Weakness: Fix 1. The row-break logic is the one place the layout can leave the contract, and it is exactly the contract's "Guard" row.
- Minor: the key row ignores the 422 block width and guards against 410 (the box width). That is stricter than needed and matches the contract's guard value, but it means a row that would fit in 422 wraps early on a wide font.

### Pillar 6: Experience Design (3/4)

Strong:
- Auto-send / Auto-invite gating is one handler that saves, unchecks and disables in order (`Messages.lua:486-498`), and `Init` enforces the same rule at load (`:68`), so a hand-edited saved variable cannot produce Auto-invite on without Auto-send.
- Text is saved raw per keystroke and normalised on focus loss, with the stored value written back to the box so the box always equals the stored text (`:383-409`). A pasted newline is replaced by a space. Enter clears focus, Escape uses the template default.
- Send path: the lock is deadline-based on `GetTime()` with a generation counter, so a late timer cannot release a newer lock (`:178-206`). A failed send prints a line and starts no lock. Lockdown falls back to prefill without sending or inviting. The preview prints instead of whispering, with the invite line when Auto-invite is on.
- Switching tabs: any stock panel's `OnShow` hides Messages and unchecks ours; `UpdateTabs` is hooked to keep stock tabs unchecked while Messages shows; the Browse `OnHide` resets the width (`UI/InPlace.lua:173-182, 203-205`).
- Default restores text only, so the choices (Auto-send, Auto-invite) are not lost.
- Fallbacks: no template or atlas is required for the panel to build.

Gaps:
- Fix 3 (silent lock and silent lockdown prefill).
- The Example line previews `M.Format` output, but during chat lockdown or with Auto-send off, the Whisper button prefills rather than sends. The example is a preview of the text, not of the action. The tooltip explains it, and the panel does not.
- Default replaces the text with no confirmation, as the contract states. The old text is not recoverable, and the box has no undo beyond the edit box's own. Acceptable per contract, but the loss is silent for a user who spent time on a custom message. A one-level "undo" (keep the last text until the panel hides) would cost little.
- No keyboard path to the key buttons other than Tab through frames, which the panel does not set up. Same class of gap as Phase 3's hide button. Unchanged.
- The `W.SetPressed` hooks are installed on first use per button and never removed; they check `b.tgfPressed`, so they cost nothing when idle. No defect.

---

## Needs in-game confirmation

These are open in `04-HUMAN-UAT.md` and are not scored as defects:
- Real key-button widths against the 5.8 px/char estimate, and whether any row exceeds 410 px (UAT 6; ties to Fix 1).
- Intro fits in four lines at 430 px (UAT 8; ties to Fix 2).
- 56 px box shows three lines plus the char count without clipping (UAT 7). If clipped, raise the box to 60 and shift rows below by 4.
- Divider at panel y -300 reads right between the blocks; stand-in and in-game layers match (UAT 8).
- Side tab starts unchecked, the icon fills under the mask, only Messages stays checked through a listing update, and hover shows the template's "Messages" tooltip only (UAT 9).
- Auto-invite gating look, including the label font when disabled (UAT 5; ties to Fix 4).
- 1 s press and lock behaviour on a row Whisper, the bottom Send Message and Group Invite (UAT 3).
- Whisper text on solo and group rows, chat lockdown prefill, failed-send line (UAT 1, 2, 4).
- Preset migration happens once and keeps custom text (UAT 10).
- `/console taintLog 1` while using the tab, Whisper, Send Message and Group Invite (UAT 11).

---

## Files Audited
- `C:\Users\jonat\Repositories\TerribleGroupFinder\Messages.lua`
- `C:\Users\jonat\Repositories\TerribleGroupFinder\UI\InPlace.lua`
- `C:\Users\jonat\Repositories\TerribleGroupFinder\UI\MainFrame.lua` (Messages panel, lines 348-363)
- `C:\Users\jonat\Repositories\TerribleGroupFinder\UI\Widgets.lua` (Atlas, Text, Tooltip, Button, SetPressed, Check, EditBox)
- `C:\Users\jonat\Repositories\TerribleGroupFinder\UI\Table.lua` (lock and pressed look, Message / Invite / Delist, FillRow press lines)
- `C:\Users\jonat\Repositories\TerribleGroupFinder\.planning\phases\04-messages-and-contact\04-UI-SPEC.md`
- `C:\Users\jonat\Repositories\TerribleGroupFinder\.planning\phases\04-messages-and-contact\04-HUMAN-UAT.md`
- `C:\Users\jonat\Repositories\TerribleGroupFinder\.planning\phases\03-rows-tooltip-and-own-listing\03-UI-REVIEW.md`
- Blizzard source (read-only): `Blizzard_SharedXML/Mainline/SharedUIPanelTemplates.xml`, `Blizzard_SharedXML/Shared/InputBox/InputBoxTemplates.lua`
