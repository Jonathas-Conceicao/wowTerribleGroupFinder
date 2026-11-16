---
phase: 13-region-flags-for-every-region
source: 13-REVIEW.md
fixed: 2026-11-16
---

# Phase 13 review fixes

| Finding | Outcome | Notes |
|---------|---------|-------|
| WR-01 tag measured bounded on pooled rows | fixed (2887965) | `SetWidth(0)` then `GetUnboundedStringWidth()` (number-checked, `GetStringWidth()` fallback) |
| IN-01 groups over 32 bytes never learned | accepted | Byte cap keeps saved data bounded; real shard groups are short; revisit from bug reports |
| IN-02 FLAG_ART heights restate the PNG sizes | accepted | Six fixed author files; a replaced flag at another size is caught in-game (UAT 1) |
| IN-03 possible soft right / bottom edge | deferred to UAT 1 | If seen: half-texel coord inset at draw time; no art change (author's no-generated-art rule rules out padding edits) |
| IN-04 unprintable first characters | accepted | Shard names are ASCII in practice |
| IN-05 Region.lua reads Preview's shardGroups | accepted | Preview-only path, gated by `ns.UsingPreview()` |
| IN-06 CLAUDE.md said the flag is always a texture | fixed (2887965) | Region line now mentions the text tag |
