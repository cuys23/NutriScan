# Phase 0 — Code Inventory & Architecture Lock

**Date:** 2026-08-03  
**Status:** Complete  

## W0.3 — Existing Codebase Touch Points

| Area | Path | Role |
|------|------|------|
| Scan UI | `lib/screens/main/home_screen.dart` | Camera/gallery picker, coin gate, scan trigger |
| Image picker | `lib/services/media/image_picker_service.dart` | Permissions, quality 85, max 1920×1080 |
| Scan orchestration | `lib/providers/food/food_provider.dart` | `analyzeFoodImage(File, {language, isPremiumUser})` — main scan pipeline |
| Vision AI | `lib/services/ai/groq_service.dart` | `analyzeFoodImage`, base64 encoding, callable proxy |
| AI proxy | `functions/src/index.ts` → `groqChatCompletion` | Server-side Groq relay, rate limit per UID |
| Food model | `lib/models/food.dart` | Fields: name, calories, protein, carbs, fat, fiber, sugar, sodium, healthScore, servingSize |
| Local DB | `lib/services/database/database_helper.dart` | SQLite `insertFood`, schema version 1 |
| Coins | `lib/providers/coins/coin_provider.dart` | `canScan`, `spendCoins` |
| Meal plan | `lib/providers/food/meal_plan_provider.dart` | `generateMealPlan` |
| Subscription | `lib/providers/payment/subscription_provider.dart` | IAP + premium features gate |
| Cloud backup | `lib/services/auth/cloud_backup_service.dart` | Auto backup for premium users |
| API config | `lib/config/api_config.dart` | Model ID only (groqModel); **no API keys in client** ✓ |
| Firebase config | `lib/config/firebase_config.dart` | Firebase options |
| IAP verify | `functions/src/index.ts` → `verifyPurchase` | Server-side purchase validation |

## W0.4 — ADR Confirmation

| ADR | Decision | Status |
|-----|----------|--------|
| ADR-001 | Flutter retained | ✅ Accepted |
| ADR-002 | FKB storage: start with Firestore | ✅ Provisional |
| ADR-003 | AI Gateway (server-side via Cloud Functions) | ✅ Accepted |
| ADR-004 | Verified vs Estimated (dual-path with mandatory `source`) | ✅ Accepted |
| ADR-005 | USDA as primary external reference | ✅ Accepted |
| ADR-006 | MAPE validation as product system | ✅ Accepted |
| ADR-007 | Monetization remains IAP + coins + ads | ✅ Accepted |
| ADR-008 | Feature flags over hard cuts | ✅ Accepted |

## W0.2 — Credentials

| Secret | Location | Status |
|--------|----------|--------|
| `GROQ_API_KEY` | Firebase Secret Manager | ✅ Already present |
| `USDA_FDC_API_KEY` | Firebase Secret Manager | ✅ Configured (2026-08-03) |
| Apple IAP keys | Firebase Secret Manager | ⏳ Pending (IAP_TEST_MODE=true) |
| Google Play SA JSON | Firebase Secret Manager | ⏳ Pending (IAP_TEST_MODE=true) |

## V0.2 — USDA API Smoke Test

```
curl "https://api.nal.usda.gov/fdc/v1/foods/search?query=banana&pageSize=1&api_key=***"
→ HTTP 200, totalHits: 4930, foods array non-empty ✅
```

## Architecture Notes

- **No API keys in Flutter tree** — confirmed. `ApiConfig` only holds model name string.
- **SQLite schema version 1** — no `source`, `portion_grams`, or `fkb_food_id` columns yet (Phase 2).
- **Food model** lacks `source`, `portionGrams`, `fkbFoodId`, `matchScore` fields (Phase 1C/2).
- **Scan pipeline** in `FoodProvider.analyzeFoodImage` is the extension point for FKB matcher (Phase 1C).
