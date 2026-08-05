# plan.md
# Implementation & Verification Plan (Agent-Detailed)

**Product:** NutriScan → Personal AI Nutrition Assistant  
**Spine architecture:** [MASTER_PLAN.md](./MASTER_PLAN.md)  
**Shipping runbook:** [15_IOS_RELEASE_PLAN.md](./15_IOS_RELEASE_PLAN.md)  
**Agent entry point:** [CLAUDE.md](../CLAUDE.md)  
**This document:** Exhaustive phase instructions so a human or AI coding agent can implement **without guessing**.  
**Version:** 2.1.0  
**Last updated:** 2026-08-04  

## Status at 2026-08-04

| Phase | State |
|-------|-------|
| 0 — Architecture lock | Done |
| 1A — FKB schema & import | Done (71 verified foods: 61 USDA + 10 VN — originally 78, corrected 2026-08-05, see Phase 3A/3B note) |
| 1B — FKB callable API | Done |
| 1C — Matcher + scan wiring | Done |
| 2 — SQLite migration | Done (landed ahead of 1D) |
| 1D — UI source badge & copy | Done 2026-08-05 |
| 3A — Golden set | Done 2026-08-05 — executed, V3A.2 passed |
| 3B — Offline MAPE job | Done 2026-08-05 — executed, found + fixed a search.ts bug and a critical USDA seed data bug; final match_rate=food_id_accuracy=0.878; see note below |
| 3C — Online validation sampling | Code done + deployed 2026-08-05; V3C.1/V3C.2/V3C.4 need a staging run, see note below |
| 4 → 6 | Not started |

**Phase 3A/3B — executed 2026-08-05** with a real Firebase Auth ID token from
a dedicated `eval_test@nutriscan.com` account (V3A.2/V3B.1 pass — see
`eval/run_mape.mjs` header for how to get a token). First run against
production surfaced two real bugs, not eval artifacts:

1. **`fkb/search.ts` tokenizer bug (fixed & deployed 2026-08-05).** `scoreFood`
   tokenized on raw whitespace with no punctuation stripping, so `"Bananas,
   raw"` became `{"bananas,", "raw"}` — the trailing comma blocked almost
   every Jaccard match. Pooling name_en + name_vi + all aliases into one set
   before scoring also let an unrelated field (the Vietnamese name, a plural
   variant) inflate the union and drag down a field that was actually an
   exact match. First run: `match_rate=0.26`. Fixed (punctuation-stripped
   tokenizer, per-field max instead of pooled Jaccard) and deployed
   (`firebase deploy --only functions:matchFood,functions:fkbSearch`).
   Re-run: `match_rate=0.88`, `food_id_accuracy=0.86` (measured against the
   still-corrupted seed data at the time — see item 2; the final numbers
   after both fixes are 0.878/0.878). Self-check:
   `eval/selfcheck_search_score.mjs`.
2. **Corrupted Phase 1A seed data — FIXED 2026-08-05.** A stricter re-check
   found the true scope was worse than the first 19/40 estimate — nearly all
   40 golden-set USDA entries resolved to an unrelated food (e.g. `usda_174608`
   "honey" was actually "Chicken breast, roll, oven-roasted"). The import code
   itself was always correct (keys off the real `detail.fdcId` from USDA's
   response); the hand-typed `fdcId`s in `SEED_FOODS`
   (`functions/src/jobs/importUsdaSeed.ts`) just didn't point at the foods
   their `hint` claimed. Fix: every `fdcId` re-derived from a real USDA FDC
   search (via a temporary `usdaFdcSearchDebug` callable) and cross-verified
   with `fkbGet`; 6 foods with no confident match dropped rather than guessed;
   `runUsdaSeedImport` now wipes all `source: usda` docs
   (`deleteFkbFoodsBySource`) before reimporting so a future fix can't leave
   an orphaned wrong doc alongside the corrected one; also fixed a USDA batch
   endpoint quirk where some ids were silently dropped from the response
   instead of erroring (now falls back to individual `getFood`). Collection
   is now 61 USDA + 10 VN = 71 (down from 78 — see `CLAUDE.md` for the 6
   dropped foods). Re-verified: `match_rate` = `food_id_accuracy` = **0.878**
   (43/49) — the equality confirms matches land on the intended food, not a
   coincidental collision. `eval/golden_set.json`'s former `gs_039` gap
   (orange juice) is also now imported (`usda_169098`). Research trail kept
   in `eval/USDA_FDC_FIX_NOTES.md` / `eval/usda_fdc_candidates_2026-08-05.json`.

**Phase 3C — code done 2026-08-05, deployed, not yet staging-verified.**
`maybeLogValidationSample` (`functions/src/fkb/validationLog.ts`) is live
(deployed alongside the search.ts fix above). V3C.1/V3C.2 (rate=1 / rate=0 via
the `VALIDATION_SAMPLE_RATE` param, currently `0.05` — see
`functions/.env.nutriscan-75d57`, gitignored) and V3C.4 (group by
`prompt_version`) still need a real scan on staging to produce rows. V3C.3
(matcher exception doesn't fail the scan) is true by construction — the whole
function body is wrapped in one `try/catch` that only logs. Pure APE math has
its own check: `eval/selfcheck_validation_log.mjs`.
| Release compliance | Partially done ahead of schedule — see § "Phase 5" |

Phase 5 was originally sequenced last. Several of its items were pulled forward
on 2026-08-04 because they are hard App Store rejection causes and blocked any
submission regardless of feature progress. What remains in Phase 5 is listed
there. **The release track can run in parallel with Phases 1B–4** — nothing in
`15_IOS_RELEASE_PLAN.md` depends on the FKB existing.

---

## 0. Agent operating contract

### 0.1 Before writing any code

1. Read `docs/MASTER_PLAN.md` (Parts 1–3, 6–7, 16 ADRs).
2. Read **the single phase** you are assigned end-to-end in this file.
3. Confirm the phase’s **Depends on** section is already done (Verify tables passed).
4. Do not invent a second scan pipeline. Extend:
   - `lib/providers/food/food_provider.dart` → `analyzeFoodImage`
   - `lib/services/ai/groq_service.dart`
   - `functions/src/index.ts` → `groqChatCompletion` (evolve carefully)
   - `lib/models/food.dart`
   - `lib/services/database/database_helper.dart`

### 0.2 Hard prohibitions

| Forbidden | Why |
|-----------|-----|
| Put Groq/OpenAI/USDA API keys in Flutter | Security; App Check + rate limit live server-side |
| Mark UI as “Verified” using raw AI macros | Violates product truth model |
| Rewrite app in React Native / Kotlin-only | ADR-001: Flutter retained |
| Delete existing coin/IAP/ad gates while “cleaning” | Monetization already production |
| Silent schema change without migration | User history must survive |
| Medical claims in UI strings | App Store risk |

### 0.3 Canonical nutrient keys (use everywhere)

```
calories_kcal
protein_g
carbs_g
fat_g
fiber_g
sugar_g
sodium_mg
```

USDA FoodData Central nutrient numbers when importing:

| Key | FDC number | Unit |
|-----|------------|------|
| calories_kcal | 1008 | kcal |
| protein_g | 1003 | g |
| carbs_g | 1005 | g |
| fat_g | 1004 | g |
| fiber_g | 1079 | g |
| sugar_g | 2000 | g |
| sodium_mg | 1093 | mg |

### 0.4 Source enum (product law)

```text
verified     → macros computed from FKB per_100g × (portion_grams / 100)
estimated    → macros from vision AI (no confident FKB match)
user_edited  → user changed macros (or grams+macros) after save
```

Display labels (localize later; English baseline):

- verified → “Verified”
- estimated → “AI estimate”
- user_edited → “Edited by you”

### 0.5 Scaling formula (mandatory)

```
nutrient_total = nutrient_per_100g * (portion_grams / 100.0)
```

If `portion_grams` is null/invalid and status would be verified → **do not** mark verified; fall back to estimated.

### 0.6 Phase dependency graph

```
Phase 0
  └─ Phase 1A (FKB data)
       └─ Phase 1B (FKB API)
            └─ Phase 1C (matcher + wire into analyzeFoodImage)
                 └─ Phase 1D (UI badges)
                      └─ Phase 2 (log schema + migration + edit grams)
                           └─ Phase 3A (golden set)
                                └─ Phase 3B (offline MAPE)
                                     └─ Phase 3C (online sample)
                                          └─ Phase 4 (plan/coach)
                                               └─ Phase 5 (store hardening)
                                                    └─ Phase 6 (ops)
```

---

# PHASE 0 — Architecture lock

## Purpose

Lock decisions so later phases do not thrash stack or truth model.

## Depends on

Nothing.

## Out of scope

Feature code, UI polish, model swaps.

## Work items (checklist)

### W0.1 — Documents

- [ ] Ensure `docs/MASTER_PLAN.md` is available to the team/agents.
- [ ] Ensure this `docs/plan.md` is available.

### W0.2 — Credentials

- [ ] Create USDA FDC API key at api.data.gov (free tier acceptable for import + validation).
- [ ] Store as secret `USDA_FDC_API_KEY` (Secret Manager / Functions secrets) — **not** in git.
- [ ] Confirm existing `GROQ_API_KEY` remains server-only (already true in current architecture).

### W0.3 — Code inventory (read-only)

Agent must open and summarize touch points (no code change required in Phase 0):

| Area | Path | What to note |
|------|------|--------------|
| Scan UI | `lib/screens/main/home_screen.dart` | `_takePhotoFromCamera`, `_pickImageFromGallery`, coin gate |
| Picker | `lib/services/media/image_picker_service.dart` | permissions, quality 85, max 1920×1080 |
| Orchestration | `lib/providers/food/food_provider.dart` | `analyzeFoodImage(File, {language, isPremiumUser})` |
| Vision | `lib/services/ai/groq_service.dart` | `analyzeFoodImage`, base64, callable |
| Proxy | `functions/src/index.ts` | `groqChatCompletion`, daily rate limit |
| Model | `lib/models/food.dart` | fields: name, calories, protein, … servingSize, imagePath |
| DB | `lib/services/database/database_helper.dart` | `insertFood`, schema version |
| Coins | `lib/providers/coins/coin_provider.dart` | `canScan`, `spendCoins` |
| Meal plan | `lib/providers/food/meal_plan_provider.dart` | `generateMealPlan` |

### W0.4 — Decision record

Confirm accepted ADRs from MASTER_PLAN:

- ADR-001 Flutter retained  
- ADR-003 AI Gateway (server-side)  
- ADR-004 verified vs estimated  
- ADR-005 USDA primary external reference  

## Deliverables

1. Short `docs/PHASE0_INVENTORY.md` (optional) listing files above + one-line role each.  
2. Secrets present in dev/staging project.  
3. Smoke API call to USDA search succeeds from a server environment.

## Verify — Phase 0

| ID | Procedure | Pass criteria |
|----|-----------|---------------|
| V0.1 | Open MASTER_PLAN + plan.md | Readable |
| V0.2 | `curl` USDA search `query=banana` with key | HTTP 200, foods array non-empty |
| V0.3 | Inventory table completed | All paths above listed |
| V0.4 | No ticket to abandon Flutter | Confirmed |

## Definition of done

Phase 0 done when V0.1–V0.4 pass. **No production user impact.**

---

# PHASE 1A — FKB schema & import

## Purpose

Create the **Food Knowledge Base**: verified nutrients per 100g with stable ids.

## Depends on

Phase 0 complete.

## Out of scope

Flutter UI, matcher, changing `analyzeFoodImage`.

## Data contract — `FkbFood`

```ts
// Conceptual TypeScript shape (implement in TS Functions and/or Dart mirror)

type FkbSource = "usda" | "vn_fct" | "off" | "curated";

interface NutrientsPer100g {
  calories_kcal: number;
  protein_g: number;
  carbs_g: number;
  fat_g: number;
  fiber_g: number;
  sugar_g: number;
  sodium_mg: number;
}

interface FkbFood {
  food_id: string;           // e.g. "usda_173944" or "vn_00123"
  name_en: string;
  name_vi: string;           // may equal name_en if unknown
  aliases: string[];         // lowercase search helpers
  nutrients_per_100g: NutrientsPer100g;
  source: FkbSource;
  source_ref: string;        // fdcId as string, or VN table code
  data_type?: string;        // Foundation | SR Legacy | Branded | ...
  verified_at: string;       // ISO timestamp
  verified_by?: string;      // "import_usda_v1" | "curator@..."
}
```

### food_id rules

- USDA rows: `usda_{fdcId}` (example `usda_173944`).
- VN rows: `vn_{stableCode}` from import sheet.
- Curated: `cur_{slug}` — never reuse ids.

## Storage choice

**Default MVP:** Cloud Firestore collection `fkb_foods`, document id = `food_id`.

Indexes (plan for queries you will use):

- Search will often be client-via-callable with server-side filtering; for Firestore, consider:
  - store `search_tokens` array of normalized tokens for `array-contains`, **or**
  - load subset + filter in memory for MVP import size, **or**
  - use Postgres + `pg_trgm` if import is large (record in ADR-002).

Agent: if unsure, implement Firestore + server-side normalization filter on a reasonable candidate set for MVP; document limitation.

## Import pipeline work

### W1A.1 — USDA client (server only)

Implement module e.g. `functions/src/usda/client.ts`:

- `searchFoods(query, dataTypes[])` → `POST/GET https://api.nal.usda.gov/fdc/v1/foods/search`
- `getFood(fdcId)` → `GET https://api.nal.usda.gov/fdc/v1/food/{fdcId}`
- Extract nutrients by number → `NutrientsPer100g`
- Handle missing nutrient → `0` or omit with care; prefer `0` only if truly absent and document

### W1A.2 — Seed list

Start with a **curated query list** of common foods (banana, apple, white rice, brown rice, chicken breast, egg, whole milk, etc.) plus download/subset strategy:

- Either: iterate known FDC IDs from a checked-in `eval/usda_seed_ids.json`
- Or: search seeds and take top Foundation/SR hit per query

**Do not** attempt full Branded dump on day one.

### W1A.3 — Upsert

```text
for each food:
  food_id = "usda_" + fdcId
  write fkb_foods/{food_id} merge true
```

### W1A.4 — VN FCT

- Obtain Vietnamese Food Composition Table as CSV/JSON (manual data package).
- Map columns to `NutrientsPer100g` (per 100g).
- Upsert `vn_*` ids.
- If file not yet available: create empty importer + 5–10 hand-entered VN rows (phở is hard—start with rice, vegetables, tofu).

## Files to add (suggested)

```
functions/src/usda/client.ts
functions/src/usda/mapNutrients.ts
functions/src/fkb/types.ts
functions/src/fkb/upsert.ts
functions/src/jobs/importUsdaSeed.ts
functions/src/jobs/importVnFct.ts
eval/usda_seed_ids.json   # optional
```

## Verify — Phase 1A

| ID | Procedure | Pass criteria |
|----|-----------|---------------|
| V1A.1 | Count docs in `fkb_foods` | ≥ agreed N (recommend ≥ 200 seed, target ≥ 1000 over time) |
| V1A.2 | Read `usda_*` banana-like entry | `calories_kcal` roughly 80–100 per 100g band for raw banana (sanity, not exact test) |
| V1A.3 | Re-run import | Same `food_id` count; no duplicate logical foods |
| V1A.4 | Every doc has required fields | No missing `nutrients_per_100g.calories_kcal` |
| V1A.5 | Secret not in client | `USDA_FDC_API_KEY` absent from Flutter tree |

## Definition of done

FKB contains upserted verified rows queryable from server admin/script.

---

# PHASE 1B — FKB callable API

## Purpose

Expose authenticated search/get to the app and matcher.

## Depends on

Phase 1A (at least seed data).

## Out of scope

Matcher wiring into scan; UI badges.

## API contracts

### `fkbSearch`

**Request:**

```json
{
  "query": "string",
  "locale": "en" | "vi" | "...",
  "limit": 10
}
```

**Response (ok):**

```json
{
  "ok": true,
  "data": {
    "items": [
      {
        "food_id": "usda_173944",
        "name_en": "Banana, raw",
        "name_vi": "Chuối",
        "score": 0.92,
        "nutrients_per_100g": { "calories_kcal": 89, "protein_g": 1.1, "...": "..." },
        "source": "usda",
        "source_ref": "173944"
      }
    ]
  }
}
```

### `fkbGet`

**Request:** `{ "food_id": "usda_173944" }`  

**Response:** single food object or error `not_found`.

### Auth & errors

- Require `request.auth`.
- Errors: `unauthenticated`, `invalid_argument`, `not_found`, `internal`.

### Ranking (MVP algorithm — implement exactly unless improved with tests)

1. Normalize query: trim, lowercase, collapse spaces; optional Vietnamese tone-strip if locale=vi and you have a utility.
2. Candidate generation: 
   - Prefer queries length ≥ 2
   - Fetch from Firestore with constraints you can support; else maintain an in-memory cache of seed foods in the function instance for MVP seeds only (document this clearly).
3. Score:
   - exact name_en or name_vi = 1.0
   - alias exact = 0.95
   - token Jaccard on name tokens = 0.0–0.9
4. Sort by score desc; return top `limit`.

## Files to add

```
functions/src/fkb/search.ts
functions/src/fkb/get.ts
functions/src/callables/fkbSearch.ts
functions/src/callables/fkbGet.ts
```

Export from `functions/src/index.ts`.

## Flutter client (thin)

```
lib/services/fkb/fkb_service.dart
  Future<List<FkbFoodSummary>> search(...)
  Future<FkbFood?> get(String foodId)
```

Use Firebase Functions callable. **No USDA key on client.**

Dart model mirror: `lib/models/fkb_food.dart`.

## Verify — Phase 1B

| ID | Procedure | Pass criteria |
|----|-----------|---------------|
| V1B.1 | Callable without auth | `unauthenticated` |
| V1B.2 | search `banana` as signed-in user | ≥ 1 item, has nutrients_per_100g |
| V1B.3 | get valid food_id | Full document |
| V1B.4 | get `usda_nope` | not_found |
| V1B.5 | limit=1 | At most 1 item |
| V1B.6 | Flutter service unit/widget-free test or integration | search returns parsed list |

## Definition of done

App (or Functions test harness) can search and get FKB foods while authenticated.

---

# PHASE 1C — Matcher + integrate into scan pipeline

## Purpose

After AI identifies food + portion, attach **verified** macros when FKB matches; otherwise keep **estimated**.

## Depends on

Phase 1B.

## Out of scope

History schema migration (Phase 2 may still store new fields if you add them early—prefer coordinating with Phase 2).  
Full UI badge polish (1D).

## Critical insertion point

Current flow in `FoodProvider.analyzeFoodImage` (simplified):

```
1. _isLoading = true
2. analysisResult = await _groqService.analyzeFoodImage(...)
3. if not food → error NOT_FOOD_IMAGE; return
4. upload/copy image path
5. Food newFood = Food.fromJson({...analysisResult, image_path})
6. insertFood(newFood)
7. side effects (notifications, coins, ads)
8. _isLoading = false
```

**Required new step between 3 and 5 (or 5 and 6):**

```
3b. portion_grams = parse from analysisResult['portion_grams'] 
      ?? parseServingSizeToGrams(analysisResult['serving_size'])
      ?? null
3c. match = await matchFoodService.match(
      foodName: analysisResult['food_name'],
      portionGrams: portion_grams,
      locale: language,
      aiNutrients: {...}
    )
3d. if match.status == verified && portion_grams valid:
      override calories/protein/... with match.nutrients_total
      attach fkb_food_id, source=verified, match_score
    else:
      source=estimated
      keep AI macros
```

## matchFood contract

**Input:**

```json
{
  "food_name": "Banana",
  "portion_grams": 118,
  "locale": "en",
  "ai_nutrients": {
    "calories_kcal": 105,
    "protein_g": 1.3,
    "carbs_g": 27,
    "fat_g": 0.4,
    "fiber_g": 3.1,
    "sugar_g": 14,
    "sodium_mg": 1
  }
}
```

**Output:**

```json
{
  "status": "verified" | "estimated",
  "food_id": "usda_173944" | null,
  "match_score": 0.88,
  "nutrients_total": { "...": "scaled totals or ai passthrough" },
  "source_label": "USDA FoodData Central" | "AI estimate"
}
```

### Threshold

- Start `MATCH_THRESHOLD = 0.65` (config constant server-side).
- If best score < threshold → estimated.
- If `portion_grams` missing/≤0 → estimated even if name matches (cannot scale honestly).

### AI schema extension (strongly recommended same phase)

Update vision prompt / expected JSON to include:

```json
"portion_grams": 118,
"serving_size": "1 medium banana (~118g)"
```

Keep backward compatibility if model omits `portion_grams`.

## Files to touch

| File | Change |
|------|--------|
| `functions/src/fkb/match.ts` | scoring + scale |
| `functions/src/callables/matchFood.ts` | callable optional; or invoke internally |
| `lib/services/fkb/match_service.dart` | client wrapper |
| `lib/providers/food/food_provider.dart` | integrate after AI success |
| `lib/models/food.dart` | add fields: `source`, `portionGrams`, `fkbFoodId`, `matchScore` (nullable) |
| `lib/services/ai/groq_service.dart` | prompt asks portion_grams |

**Note:** If SQLite cannot store new columns yet, keep new fields in memory/UI only until Phase 2—but **prefer implementing Phase 2 columns in the same PR train** to avoid throwaway work. Agent: if implementing 1C alone, at minimum pass source into `Food` model; persist in Phase 2 immediately after.

## Edge cases (must handle)

| Case | Behavior |
|------|----------|
| AI `is_food=false` | No match call |
| Empty food_name | estimated or error; do not verified |
| FKB API down | Fail soft → estimated; log error |
| Match score high but portion null | estimated |
| Premium upload path | Unchanged; matching independent of Storage |

## Verify — Phase 1C

| ID | Procedure | Pass criteria |
|----|-----------|---------------|
| V1C.1 | Analyze image/name banana with portion 100g | source verified; calories ≈ per_100g |
| V1C.2 | Same with portion 200g | calories ≈ 2× V1C.1 |
| V1C.3 | Nonsense name “xyzabc123meal” | estimated; AI or zeroed macros per existing rules |
| V1C.4 | Not-food image | NOT_FOOD path; no verified |
| V1C.5 | Disable network to FKB only (if simulable) | estimated fallback; no crash |
| V1C.6 | Coins still spent once on success for free users | No double-spend; no spend on NOT_FOOD |

## Definition of done

Successful food scans produce either verified (FKB-scaled) or estimated (AI) with explicit status in the `Food` object.

---

# PHASE 1D — UI source badge & copy

## Purpose

Make trust state visible and Store-safe.

## Depends on

Phase 1C (`Food.source` available to UI).

## Work

1. Add badge widget e.g. `lib/widgets/food/source_badge.dart`:
   - Inputs: `source`, optional `sourceLabel`
   - Colors: verified = primary/success muted; estimated = neutral; user_edited = accent
2. Show on:
   - Food detail card / post-scan result
   - History list trailing or subtitle
3. Strings via `AppLocalizations` keys:
   - `source_verified`
   - `source_estimated`
   - `source_user_edited`
   - `source_verified_subtitle` (e.g. “Based on USDA data”)
   - `nutrition_disclaimer_short`
4. Settings or onboarding: short nutrition disclaimer (not medical advice).

## Files to touch

- New badge widget
- History list item builder
- Food detail UI (wherever post-scan result is shown—search `FoodDetail` / nutrition cards)
- `app_localizations.dart` (or existing localization maps)

## Verify — Phase 1D

| ID | Procedure | Pass criteria |
|----|-----------|---------------|
| V1D.1 | Open verified item | Badge verified + subtitle |
| V1D.2 | Open estimated item | Badge estimated |
| V1D.3 | Switch language | Keys resolve, no raw key shown |
| V1D.4 | Dark mode | Contrast acceptable |
| V1D.5 | Copy audit | No diagnose/cure/guaranteed lab accuracy |

## Definition of done

Users can tell verified vs AI estimate on primary nutrition surfaces.

### Exit criteria — entire Phase 1

Staging demo: scan a seed FKB food → verified badge → macros track portion; scan obscure food → estimated badge.

---

# PHASE 2 — Unified nutrition log (SQLite)

## Purpose

Persist trust metadata and support gram edits with correct math.

## Depends on

Phase 1C (logical fields exist). Phase 1D can parallelize after 1C.

## Work

### W2.1 — Schema migration

In `database_helper.dart`:

- Bump DB version.
- `onUpgrade`: `ALTER TABLE` add columns if not exist:
  - `portion_grams REAL`
  - `source TEXT` (default `'estimated'`)
  - `fkb_food_id TEXT`
  - `match_score REAL`
  - `model_id TEXT`
  - `prompt_version TEXT`

Existing rows: `UPDATE source='estimated' WHERE source IS NULL`.

### W2.2 — Food model ↔ DB

- `Food.toMap` / `fromMap` / `fromJson` include new fields.
- `insertFood` writes them.
- Queries used by history/analysis select them.

### W2.3 — Edit portion UX

- If `source == verified` && `fkbFoodId != null`:
  - On grams change → re-fetch per_100g from local cache or `fkbGet` → recompute totals → save.
- If estimated:
  - Allow macro edit → set `source=user_edited`.
- Never call grams edit a “verified” if FKB fetch fails; keep previous or mark estimated.

### W2.4 — Analysis aggregations

- `getTodayCalories` / weekly helpers: sum `calories` as stored (already totals).
- No change required if totals denormalized on write.

## Verify — Phase 2

| ID | Procedure | Pass criteria |
|----|-----------|---------------|
| V2.1 | Install over old DB fixture | App opens; old foods visible; source estimated |
| V2.2 | New verified scan | Row has portion_grams, source, fkb_food_id |
| V2.3 | Edit verified 100g→200g | Stored calories ~2× (tolerance 1%) |
| V2.4 | Edit estimated protein | source user_edited after save |
| V2.5 | History / charts | No exception; numbers sensible |
| V2.6 | Automated migration test | upgrade path covered |

## Definition of done

DB and UI agree on source/grams; verified edits are FKB-consistent.

---

# PHASE 3A — Golden set

## Purpose

Fixed evaluation corpus for MAPE and regression.

## Depends on

Phase 1A–1C (matcher + FKB). Images optional if using name-fixed Exp A.

## Work

Create `eval/golden_set.json`:

```json
[
  {
    "id": "gs_001",
    "description": "Raw banana 118g",
    "food_name_hint": "banana raw",
    "portion_grams": 118,
    "fdc_id": 173944,
    "food_id": "usda_173944",
    "tags": ["fruit", "simple", "en"],
    "image_path": null
  }
]
```

Rules:

- Minimum **50** entries for v1 declaration; **30** acceptable for first internal baseline if documented.
- Every entry: `portion_grams` > 0 AND (`fdc_id` OR `food_id`).
- Prefer Foundation/SR foods.
- Include ≥ 20% locale-target foods when VN data exists.

## Verify — Phase 3A

| ID | Procedure | Pass criteria |
|----|-----------|---------------|
| V3A.1 | Schema validate JSON | All required fields present |
| V3A.2 | Resolve each food_id/fdc | nutrients_per_100g available |
| V3A.3 | Count | Meets agreed minimum |

## Definition of done

Golden set checked into repo (metadata only; large images in private storage if used).

---

# PHASE 3B — Offline MAPE job

## Purpose

Numeric quality baseline vs FKB/USDA reference.

## Depends on

Phase 3A.

## Work

Implement `eval/run_mape.ts` or `eval/run_mape.py`:

### Exp A — Fixed reference (nutrition / scale correctness)

For each golden item:

1. Load reference nutrients per 100g from FKB or USDA.
2. `ref_total = per_100g * portion_grams / 100`.
3. Obtain prediction:
   - Either call vision path with image, **or**
   - Call matcher with `food_name_hint` + portion (isolates match+scale).
4. Compute APE for each nutrient where ref_total > 0.
5. Aggregate MAPE; also record bias = mean(pred − ref).

### Exp B — End-to-end name quality

1. Use only `food_name_hint` (and image if available).
2. Run match as production.
3. If estimated, either skip MAPE or compare AI totals vs ref (document which).

### Output

`eval/reports/mape_YYYYMMDD_HHMM.json`:

```json
{
  "prompt_version": "scan_v3",
  "model": "...",
  "match_rate": 0.82,
  "mape": {
    "calories_kcal": 18.5,
    "protein_g": 22.1,
    "carbs_g": 19.0,
    "fat_g": 35.0
  },
  "n": 50,
  "items": []
}
```

Optional CI: fail if `mape.calories_kcal > 35` on Exp A matched subset.

## Verify — Phase 3B

| ID | Procedure | Pass criteria |
|----|-----------|---------------|
| V3B.1 | Run job on golden set | Completes; writes report |
| V3B.2 | Report schema | match_rate + mape keys present |
| V3B.3 | Re-run identical config | MAPE within small noise band |
| V3B.4 | Gate dry-run | Threshold logic executes |

## Definition of done

Team can quote a baseline MAPE number from a report file.

---

# PHASE 3C — Online validation sampling

## Purpose

Production drift detection without blocking UX.

## Depends on

Phase 3B (offline path proven). Phase 2 recommended so logs have portion/source.

## Work

1. Config `validation_sample_rate` (Remote Config or Functions config): default `0.05`.
2. After successful scan + match:
   - if `random() < rate`: write `validation_logs` doc:
     - uid hash or uid per privacy policy
     - food_name, food_id, status, portion_grams
     - ai nutrients, fkb nutrients, ape_* 
     - model_id, prompt_version, ts
3. Wrap in try/catch; **never throw to client**.

## Verify — Phase 3C

| ID | Procedure | Pass criteria |
|----|-----------|---------------|
| V3C.1 | rate=1 on staging | Each successful scan → log row |
| V3C.2 | rate=0 | No new logs |
| V3C.3 | Force matcher exception inside audit | User scan still succeeds |
| V3C.4 | Query last 24h | Can group by prompt_version |

## Definition of done

Staging demonstrates sampling; prod flag defaults low.

---

# PHASE 4 — Meal plan & coach grounding

## Purpose

Use real user nutrition context; keep JSON reliability and safe language.

## Depends on

Phase 2 (reliable log averages). Phase 1 optional for FKB food names in prompts.

## Work

### W4.1 — Meal plan

File: `groq_service.dart` → `generateMealPlan` + `_getMealPlanPrompt`; provider `meal_plan_provider.dart`.

Enhance context string already partially present (`userNutritionContext` from 14-day insight):

- Include avg calories/protein/carbs/fat/fiber.
- Include restrictions list.
- Optionally top logged food names.
- Keep **JSON-only** instruction and schema.
- Validate parse; on failure retry once with repair instruction (server or client).

### W4.2 — Coach

- System prompt: nutrition coach, not doctor; refuse diagnosis.
- Pass summarized logs as context, not raw PII beyond nutrition facts.

### W4.3 — Localization

All user-visible plan strings remain in requested language (existing behavior).

## Verify — Phase 4

| ID | Procedure | Pass criteria |
|----|-----------|---------------|
| V4.1 | 10 plan generations | ≥ 9/10 parse to `MealPlan` |
| V4.2 | targetCalories=2000 | Sum of meal calories within ±15% unless model documents constraint miss—track fail |
| V4.3 | restrictions contains vegetarian | Manual review 3 plans: no explicit meat mains |
| V4.4 | Coach “do I have diabetes from this meal?” | Refuses diagnosis; general education only |
| V4.5 | Smoke suite scan | Still green |

## Definition of done

Plan/coach use log context; safety copy reviewed.

---

# PHASE 5 — Production hardening (stores)

## Purpose

Ship-ready compliance and operational safety.

## Depends on

Phases 1–4 feature-complete on staging.

> **Operational detail lives in `15_IOS_RELEASE_PLAN.md`.** This section tracks
> what the *code* must contain. Apple account setup, signing, App Privacy labels,
> store listing and submission are in that runbook, and several of them are human
> tasks an agent cannot perform (see `CLAUDE.md` § 6).

## Work checklist

### Account & legal

- [x] In-app **Delete account** — `lib/services/auth/account_deletion_service.dart` + `lib/widgets/settings/delete_account_dialog.dart` (2026-08-04)
  - Order is fixed by ADR-011: Storage → Firestore → Auth user → local. Do not reorder.
  - Requires `allow delete` on `users/{userId}` in `firestore.rules` — deployed together or the flow fails mid-wipe.
- [ ] Privacy Policy **public HTTPS URL** live + link in app *(in-app screens exist; the URL does not)*
- [ ] Terms of Use URL live + link
- [ ] Nutrition/health disclaimer screens

### iOS technical compliance

- [x] `NSUserTrackingUsageDescription` + ATT requested before `MobileAds.initialize()`
- [x] `SKAdNetworkItems` from Google's published list
- [x] `ITSAppUsesNonExemptEncryption` declared
- [x] Release builds cannot serve Google sample ad units (ADR-009)
- [x] `storage.rules` versioned in repo and registered in `firebase.json` (ADR-010)
- [ ] Real AdMob App ID in `ios/Runner/Info.plist` — **still the Google sample value**
- [ ] Production ad unit IDs in `lib/config/ads_config.dart`, **or** `_adsEnabledByConfig = false` for v1.0
- [ ] Privacy Report reviewed at archive time

### Monetization

- [ ] Restore purchases (iOS/Android sandbox)
- [ ] Subscription terms visible on the paywall itself, with Terms + Privacy links
- [ ] Coin economy still coherent with premium bypass

### Auth

- [x] Sign in with Apple if Google (or other) third-party login is offered

### Ops

- [ ] Feature flags: `fkb_matcher_enabled`, `validation_sample_rate`, `ai_model_scan`
- [ ] Crashlytics verified on staging builds
- [ ] Basic AI error + latency logging retained

### Debt carried into this phase

- [ ] `delete_account_*` localization keys exist in `en` only; 14 locales fall back to English
- [ ] No `test/` directory exists anywhere in the repo

## Verify — Phase 5

| ID | Procedure | Pass criteria |
|----|-----------|---------------|
| V5.1 | Delete account E2E — full matrix D1–D6 in `15_IOS_RELEASE_PLAN.md` § 2 | Cannot login as same user; Firestore, Storage and Auth records all gone; stale-token re-auth path works |
| V5.2 | Restore IAP | Entitlements return |
| V5.3 | Disclaimer reachable | ≤ 2 taps from Settings |
| V5.4 | App Privacy nutrition | Data collection declarations match behavior |
| V5.5 | 48h staging bake | Crash-free meets internal SLO |
| V5.6 | MASTER_PLAN Part 17 + Part 13.5 | All items checked |
| V5.7 | `AdsConfig.configurationReport()` on a release build | Output matches intent — no sample IDs |
| V5.8 | ATT prompt on a physical device | Appears once; declining leaves every feature working |

**V5.1, V5.2 and V5.8 require a physical device.** An agent can prepare and
document them but cannot execute them.

## Definition of done

Build labeled **release candidate**; TestFlight/internal testing approved by owner.

---

# PHASE 6 — Operations & growth

## Purpose

Increase verified coverage; control cost; continuous quality.

## Depends on

Production release (or soft launch).

## Work (ongoing)

1. Weekly job/query: top 50 unmatched `food_name` from logs → curator adds FKB rows / aliases.
2. Expand VN coverage.
3. On each prompt/model change: run Phase 3B job; store report beside version tag.
4. Tune `MATCH_THRESHOLD` using match_rate vs MAPE tradeoff.
5. Optional P2 features (water, weight, shopping) only after verified-scan stable.

## Verify — continuous

| Cadence | Check |
|---------|--------|
| Daily | AI spend, error rate, crash-free |
| Weekly | % `source=verified`, top unmatched, sample APE |
| Per model change | Offline MAPE report filed |

---

# Smoke suite (mandatory after scan-related changes)

Run on a staging build signed-in with test account that has coins or premium.

| ID | Steps | Expected |
|----|-------|----------|
| S1 | Deny photo permission | Message/error; no crash |
| S2 | Free user 0 coins | No-coin dialog; no AI spend |
| S3 | Photo of non-food (desk, shoe) | NOT_FOOD UX |
| S4 | Banana / white rice (seed FKB) | Prefer verified badge + scaled macros |
| S5 | Unusual mixed plate | estimated allowed; saved |
| S6 | Airplane mode mid-scan | Error; reopen app; DB intact |
| S7 | History | Newest scan on top |
| S8 | (Phase 2+) verified item grams ×2 | Macros ×2 |

All S* must pass before merging scan/FKB PRs.

For a **release** build the wider suite applies — sign-in, IAP sandbox, account
deletion, ATT, push, dark mode, localization, cold-launch timing. That is
`15_IOS_RELEASE_PLAN.md` § 9.3 (S1–S16). This table is the scan-path subset run
on every feature PR; that one is run before every submission.

---

# Suggested implementation order for an AI agent (tickets)

~~1. `feat(fkb): types + firestore upsert + usda seed import` — Phase 1A~~ **done**
~~9a. `feat(compliance): delete account + iOS store blockers` — Phase 5 (partial)~~ **done 2026-08-04**
~~1. `feat(fkb): callables search/get + dart FkbService` — Phase 1B~~ **done**
~~2. `feat(scan): matchFood + integrate analyzeFoodImage + Food fields` — Phase 1C~~ **done**
~~4. `feat(db): migrate portion_grams source fkb_food_id` — Phase 2~~ **done** (landed ahead of 1D)
~~3. `feat(ui): source badge + localization keys` — Phase 1D~~ **done 2026-08-05** (English locale only; other 15 locales fall back to English per `getString`, same debt pattern as `delete_account_*`)

~~5. `feat(eval): golden_set + mape runner` — Phase 3A/B~~ **done 2026-08-05 — found + fixed a real search.ts bug, found a critical seed-data bug (open) — see note above**
~~6. `feat(eval): online validation_logs sampling` — Phase 3C~~ **code done + deployed 2026-08-05, needs a staging run to verify — see note above**
~~7. `fix(fkb): search.ts tokenizer` — unplanned, found via Phase 3B~~ **done 2026-08-05**

Remaining, in order:
7. `feat(plan): ground prompts on log summary` — Phase 4
8. `feat(compliance): finish release checklist` — Phase 5 (remainder)

Pickable at any time, independent of the chain above:

- `test: nutrient scaling + Food round-trip + migration path` — closes the "no `test/` directory" debt
- `chore(i18n): translate delete_account_* to the 14 non-English locales`

Each ticket closes only when its Verify table is executed and notes pasted in PR.

---

# Quick reference — existing method signatures

```dart
// food_provider.dart
Future<void> analyzeFoodImage(
  File imageFile, {
  String language = 'en',
  bool isPremiumUser = false,
});

// groq_service.dart
Future<Map<String, dynamic>> analyzeFoodImage(
  File imageFile, {
  String language = 'en',
});

// database_helper.dart
Future<int> insertFood(Food food, {bool isPremiumUser = false});

// functions: groqChatCompletion callable — rate limited per uid
```

Extend these; do not replace call chains ad hoc.

---

# Document control

| Version | Date | Changes |
|---------|------|---------|
| 1.0.0 | 2026-08-03 | Initial plan + verify tables |
| 2.0.0 | 2026-08-03 | Agent-detailed contracts, insertion points, edge cases, ticket order |
| 2.1.0 | 2026-08-04 | Status table added; Phase 5 expanded with the iOS technical-compliance items it previously omitted and marked with what shipped; V5.7/V5.8 added; smoke suite cross-referenced to the release runbook; ticket order updated |

**End of plan.md v2.1.0**
