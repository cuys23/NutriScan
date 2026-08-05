# CLAUDE.md

Agent entry point for the NutriScan repository. Read this first, every session.

---

## 1. What this is

A Flutter + Firebase iOS/Android app that photographs a meal, identifies it with a
vision model, and logs nutrition. The product is being evolved from "AI scan demo"
into a verified-nutrition platform backed by a Food Knowledge Base (FKB) sourced
from USDA and the Vietnamese Food Composition Table.

```
NutriScan/
  docs/              ← plans; read before touching architecture
  nutriscan/         ← the Flutter app + Firebase Functions
    lib/
    functions/src/   ← TypeScript Cloud Functions
    eval/            ← golden set + import tooling
    firestore.rules
    storage.rules
```

## 2. Document map

| File | Read it when |
|------|--------------|
| `CLAUDE.md` (this) | Always, first |
| `docs/MASTER_PLAN.md` | Architecture, ADRs, product truth model |
| `docs/plan.md` | Implementing a feature phase — read **your assigned phase end to end** |
| `docs/15_IOS_RELEASE_PLAN.md` | Anything about shipping, compliance, signing, store |
| `docs/PHASE0_INVENTORY.md` | Locating existing scan-path code |

Precedence when documents disagree:

- Product / architecture → `MASTER_PLAN.md`
- Shipping / compliance → `15_IOS_RELEASE_PLAN.md`
- Implementation detail → `plan.md`

Contradicting an accepted ADR requires appending a new ADR, not editing the old one.

## 3. Hard rules

Violating any of these means the change gets reverted.

| Never | Why |
|-------|-----|
| Put Groq / OpenAI / USDA API keys in the Flutter tree | Keys live in Functions + Secret Manager only |
| Label a macro `verified` from raw AI output | `verified` means FKB per-100g × grams. Nothing else. |
| Propose a React Native / Kotlin rewrite | ADR-001, settled |
| Remove or bypass coin / IAP / ad gates while "cleaning up" | That is live monetization |
| Change a SQLite schema without an `onUpgrade` migration | User history must survive the update |
| Write medical claims into UI strings | "diagnose", "treat", "cure", "clinically proven" → App Store rejection |
| Build a second scan pipeline | Extend `FoodProvider.analyzeFoodImage`; do not fork it |
| Delete the Firebase Auth user before its cloud data | Security rules key off `request.auth.uid`; the data becomes unreachable |

Canonical nutrient keys, everywhere, no variants:

```
calories_kcal  protein_g  carbs_g  fat_g  fiber_g  sugar_g  sodium_mg
```

Scaling formula:

```
nutrient_total = nutrient_per_100g * (portion_grams / 100.0)
```

If `portion_grams` is null or ≤ 0, the log is `estimated` — never `verified`.

## 4. Extension points

Do not go looking; these are the files that matter.

| Concern | File |
|---------|------|
| Scan orchestration | `lib/providers/food/food_provider.dart` → `analyzeFoodImage` |
| Vision AI client | `lib/services/ai/groq_service.dart` |
| AI proxy + rate limit | `functions/src/index.ts` → `groqChatCompletion` |
| Food model | `lib/models/food.dart` |
| Local DB | `lib/services/database/database_helper.dart` |
| FKB (server) | `functions/src/fkb/`, `functions/src/usda/`, `functions/src/jobs/` |
| Coins | `lib/providers/coins/coin_provider.dart` |
| Subscription / IAP | `lib/providers/payment/subscription_provider.dart`, `lib/services/payment/iap_service.dart` |
| Account deletion | `lib/services/auth/account_deletion_service.dart` |
| Localization | `lib/config/app_localizations.dart` (15 locales, English fallback) |

## 5. Current state — 2026-08-05

**Done:** Phase 0, Phase 1A (78 verified foods imported — but see the critical
data-integrity debt item below before trusting any USDA-sourced `verified`
macro), Phase 1B (fkbSearch/fkbGet), Phase 1C (matchFood wired into
analyzeFoodImage), Phase 2 (SQLite migration for
portion_grams/source/fkb_food_id/match_score — landed ahead of 1D), Phase 1D
(source badge + localization keys, English only — see debt below), Phase 3A
(golden set, executed), Phase 3B (offline MAPE runner, executed — surfaced and
fixed a real `fkb/search.ts` tokenizer bug: match_rate 0.26 → 0.88, deployed),
and the iOS compliance fixes (delete account, ATT, SKAdNetwork, export
compliance, AdMob release guard, storage rules).

**Code done + deployed, staging verification pending:** Phase 3C (online
validation_logs sampling) — needs a real scan on staging to confirm rows land;
see `plan.md`.

**Not started:** `plan.md` Phases 4 → 6.

Next tickets, in order. Each closes only when its Verify table in `plan.md` has
been executed and the results pasted into the PR.

1. `feat(plan): ground prompts on log summary` — Phase 4
2. `feat(compliance): finish release checklist` — Phase 5

Known debt, **highest priority first — the first item below is a live
data-correctness bug, not routine cleanup:**

- **CRITICAL — most imported USDA FKB foods have the wrong `fdcId`, so their
  `name_en`/`nutrients_per_100g` are a completely unrelated food.** First pass
  (`eval/run_mape.mjs`, 2026-08-05) flagged 19/40 golden-set entries; a
  stricter re-check (excluding generic words like "raw"/"cooked" from the
  match heuristic) found the real number is closer to **all but 2–4 of the 40
  checked** — this looks systemic (the whole `fdcId` column misaligned against
  `hint`), not isolated typos. Examples: `usda_174608` (aliased "honey")
  actually holds "Chicken breast, roll, oven-roasted"; `usda_174833` ("olive
  oil") holds "Alcoholic Beverage, wine, table, red". A `matchFood` hit on any
  of these returns a `verified` badge with wrong macros — the exact failure
  `verified` is supposed to rule out. The import code itself is correct (keys
  off USDA's real returned `fdcId`); the bug is in the hand-typed `fdcId`s in
  `SEED_FOODS` (`functions/src/jobs/importUsdaSeed.ts`) and
  `eval/usda_seed_ids.json`. **Research done, production data not yet
  touched** — full status, a reusable `usdaFdcSearchDebug` lookup callable
  (already deployed, uses the existing Secret Manager key, never needs the
  raw key outside Functions), 9 confirmed correct-fdcId cross-references, and
  real USDA candidate results for all 68 seed entries are in
  `eval/USDA_FDC_FIX_NOTES.md` — read that file before resuming this, don't
  redo the lookups. `gs_039` in `eval/golden_set.json` (`usda_174814`) is a
  separate, smaller gap — that fdcId was never imported at all (404 on
  `fkbGet`).
- `eval/get_eval_token.mjs` (untracked, not committed) hardcodes a real
  password for the `eval_test@nutriscan.com` account in plaintext. Don't
  `git add` it as-is — move the password to an env var first, or delete it
  now that a token can be pasted manually.
- No `test/` directory exists. Highest value first: nutrient scaling math,
  `Food.toMap`/`fromMap` round-trip, the Phase 2 migration path.
- Delete-account localization keys exist in `en` only; 14 locales fall back to
  English. Keys are prefixed `delete_account_`.
- Source-badge localization keys (`source_verified`, `source_estimated`,
  `source_user_edited`, `source_verified_subtitle`, `nutrition_disclaimer_short`)
  exist in `en` only; 15 locales fall back to English. Same pattern as above.
- `eval/usda_seed_ids.json` has two duplicate `fdcId`s (170393 used for both
  "Mango, raw" and "Sweet potato, cooked, baked"; 173757 used for both
  "Tortilla, flour" and "Chickpeas, cooked"). The Phase 1A import upserts by
  `food_id = usda_{fdcId}`, so whichever entry ran last in the array silently
  overwrote the other in production `fkb_foods` — one of each pair is not
  actually in the FKB under its expected name. Fix: give the losing item its
  own correct `fdcId` (verify via USDA FDC search) and re-run the import.
  `eval/golden_set.json` (Phase 3A) deliberately excludes all four names to
  avoid depending on which one won.
- `app_version_subtitle` in `app_localizations.dart` is hardcoded and must be
  updated in the same commit as any `pubspec.yaml` version bump.
- `model_id`/`prompt_version` SQLite columns (Phase 2 migration) are still
  unpopulated in local scan history — Phase 3C wired them from
  `ApiConfig.groqModel`/`ApiConfig.scanPromptVersion` into the server-side
  `validation_logs` audit trail only (`matchFood` request), not into
  `Food`/`database_helper.dart`. Same fix (extend `Food.fromJson`/`toMap`)
  would close both at once if picked up.

## 6. Who does what

An agent cannot do console work. Do not attempt these, and do not report a task
blocked on them as failed — flag it and move on.

| Agent does | Human does |
|------------|------------|
| All Dart / TypeScript code | Apple Developer + App Store Connect account |
| Firestore + Storage rules edits | Agreements, tax, banking |
| Local test runs, `flutter analyze` | Creating IAP products in ASC |
| Docs and localization | AdMob console → real App ID + ad unit IDs |
| `firebase deploy` **if credentials are present** | APNs `.p8` key upload to Firebase |
| Migration scripts | Physical-device testing (delete account, IAP sandbox, ATT) |
| CI config | Screenshots, description, demo account |
| | Xcode archive + upload |

Verification steps that require a physical device are listed in
`15_IOS_RELEASE_PLAN.md` § 9.3 (S1–S16) and § 2 (D1–D6). An agent may write them
up and prepare the build; it cannot execute them.

## 7. Commands

```bash
cd nutriscan

flutter pub get
flutter analyze                 # must be clean before any PR
flutter test                    # once tests exist

cd ios && pod install && cd ..  # after any pubspec change

# Backend — always deploy before the client that depends on it
firebase deploy --only firestore:rules,storage
firebase deploy --only functions

# Functions
cd functions && npm run build && npm run serve   # local emulator
```

`lib/main.dart` redirects Cloud Functions to a local emulator under `kDebugMode`.
That is intentional. Do not remove it, and do not let it leak into release builds.

## 8. Conventions

- Conventional commits: `feat(scan):`, `fix(fkb):`, `chore(ai):`
- Providers over direct service calls from widgets; repositories for new features
- Zod-validate every callable input in Functions; no unjustified `any`
- All user-facing strings go through `AppLocalizations`
- PR checklist: tests, feature-flag plan, screenshot if UI changed, cost note if
  the change touches AI usage

## 9. Before you finish a task

- [ ] `flutter analyze` clean
- [ ] No secret committed — `git grep -nE "(gsk_|AIza[0-9A-Za-z_-]{20,})" -- nutriscan/lib`
- [ ] New user-facing strings localized (English at minimum)
- [ ] If nutrition display changed: `source` is handled and no AI value is shown as `verified`
- [ ] If the schema changed: migration written and the upgrade path tested
- [ ] The Verify table for your phase in `plan.md` executed, results in the PR
