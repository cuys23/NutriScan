# USDA seed fdcId correction — working notes (2026-08-05)

Status: **research done, production data NOT yet touched.** The only production
write this session was the `fkb/search.ts` tokenizer fix (see git history) —
`SEED_FOODS` and `fkb_foods` docs are unchanged.

## Scope (corrected from earlier estimate)

Initial pass flagged 19/40 golden-set USDA entries as wrong. A stricter
re-check (excluding generic words like "raw"/"cooked" from the match
heuristic) shows the real number is closer to **all but 2–4 of the 40**
checked. This looks systemic — likely the whole `fdcId` column in
`SEED_FOODS` (`functions/src/jobs/importUsdaSeed.ts`) got misaligned against
the `hint` column when it was written, not isolated typos.

## Tooling added (still deployed, safe to reuse)

`usdaFdcSearchDebug` callable (`functions/src/index.ts`) — thin passthrough to
USDA FDC search using the existing `USDA_FDC_API_KEY` secret, so re-verifying
fdcIds never needs the raw key outside Functions. Call it the same way as
`fkbGet`/`matchFood` (needs a Firebase Auth ID token). Remove once `SEED_FOODS`
is corrected and re-imported.

## Candidate fdcIds already looked up

`eval/usda_fdc_candidates_2026-08-05.json` — one real USDA FDC search result
set (Foundation/SR Legacy filtered) per current `SEED_FOODS` hint, fetched via
`usdaFdcSearchDebug`. Not yet reviewed/selected line-by-line for all 68.

## Confirmed via cross-reference (verified with `fkbGet`, high confidence — the
*current* wrong fdcId for one hint turned out to hold the correct data for a
*different* hint already in `SEED_FOODS`; just repoint, no new lookup needed)

| Hint | Correct fdcId | Evidence |
|------|---------------|----------|
| Banana, raw | 173944 (unchanged) | Already correct: "Bananas, raw", 89 kcal |
| Apple, raw, with skin | 171688 (unchanged) | Already correct: "Apples, raw, with skin...", 52 kcal |
| Strawberries, raw | 167762 | Currently mislabeled "Orange" in SEED_FOODS; real content is "Strawberries, raw", 32 kcal |
| Blueberries, raw | 171711 | Currently mislabeled "Avocado"; real content is "Blueberries, raw", 57 kcal |
| Cheese, cheddar | 170899 | Currently mislabeled "Yogurt"; real content is "Cheese, cheddar, sharp, sliced", 410 kcal |
| Potato, boiled | 170440 | Currently mislabeled "Spinach"; real content is "Potatoes, boiled, cooked without skin...", 86 kcal |
| Rice, white, long-grain, cooked | 168878 | Currently mislabeled "Bread, white"; real content is "Rice, white, long-grain, regular, enriched, cooked", 130 kcal |
| Garlic, raw | 169230 | Currently mislabeled "Carrot"; real content is "Garlic, raw", 149 kcal (plausible — garlic really is ~149 kcal/100g) |
| Tomato, red, raw | 170457 | Currently mislabeled "Rice"; real content is "Tomatoes, red, ripe, raw, year round average", 18 kcal |

Orphaned old fdcIds surfaced by the swaps above (currently in `fkb_foods`,
match none of our hints, candidates for deletion once the real replacement
lands): 167775 (apple juice concentrate), 174687 (jackfruit), 170069
(waxgourd), 171057 (chicken giblets), 174002 (beef loin steak raw), 175159
(tuna yellowfin raw), 172184 (egg yolk raw), 174288 (chickpea flour), 170903
(Greek yogurt lowfat), 170886 (yogurt plain lowfat), 170855 (Swiss cheese),
169228 (eggplant), 170407 (collards), 170050 (tomato, cooked — close but wrong
prep state for the "raw" hint).

## Not yet reviewed

The remaining ~55 `SEED_FOODS` entries need a human or a fresh agent pass
through `eval/usda_fdc_candidates_2026-08-05.json` (pick the best
Foundation/SR Legacy candidate per hint, or drop the hint if nothing fits) —
several hints (oats, pasta, noodles, corn) only have raw/dry Foundation
matches, not cooked, which needs the hint text corrected to match reality
rather than picking a cooked-sounding entry that doesn't exist.

## Next steps, in order

1. Finish picking one fdcId per remaining hint from the candidates file (or
   drop the hint).
2. Rewrite `SEED_FOODS` in `functions/src/jobs/importUsdaSeed.ts` and
   `eval/usda_seed_ids.json` to match.
3. Re-run `importUsdaSeed` (upserts by new fdcId — creates fresh correct docs,
   does not touch the old wrong ones).
4. **Delete the orphaned old-fdcId docs** (list above, plus whatever the
   remaining-55 pass turns up) — leaving them live risks two `fkb_foods` docs
   tied for the same alias/name (old wrong one, new correct one), which makes
   `matchFood` non-deterministic between right and wrong data.
5. Re-run `eval/run_mape.mjs` against the corrected data and update the
   Phase 3A/3B numbers in `docs/plan.md`.
6. Remove `usdaFdcSearchDebug` from `functions/src/index.ts`.
