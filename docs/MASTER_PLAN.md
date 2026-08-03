# MASTER_PLAN.md
# NutriScan → Personal AI Nutrition Assistant

**Document type:** Technical Design Document (TDD) / Software Design Document (SDD)  
**Status:** Blueprint — single source of truth  
**Version:** 1.0.0  
**Last updated:** 2026-08-03  
**Product codename:** NutriScan  
**Platforms:** iOS · Android (Flutter)  
**Audience:** Founders, engineers, AI coding agents (Claude / Cursor / GPT)

---

## How to use this document

1. Read **Part 1–3** before any feature work.
2. AI agents must load this file + relevant ADR before generating architecture-level code.
3. Product decisions change only via ADR append (never silent rewrite).
4. Implementation details live in `docs/0x_*.md` children; this file is the spine.
5. Existing codebase: Flutter app under `nutriscan/` with scan flow already production-capable. This plan **evolves** that app into a verified-nutrition platform — it does not throw it away.

---

# PART 1 — Product Vision

## 1.1 One-line vision

> **Personal AI Nutrition Assistant** — scan real meals, log against a **verified food knowledge base**, plan diet, and coach progress — with numbers you can defend in production and App Store review.

## 1.2 What we are NOT

| Not this | Why |
|----------|-----|
| “AI scan food demo” | Unverified macros ≠ nutrition product |
| Clinical medical device | Out of scope; requires regulatory path |
| Generic calorie counter only | Differentiation is AI + verified FKB + coaching |
| Backend rewrite for its own sake | Leverage existing Flutter + Firebase + Groq pipeline |

## 1.3 What we ARE

| Pillar | Description |
|--------|-------------|
| **Capture** | Photo / gallery → food identity + portion |
| **Ground** | Match to **Food Knowledge Base (FKB)** (USDA, VN FCT, curated) |
| **Log** | Daily nutrition log with source badge (`verified` / `estimated` / `user_edited`) |
| **Plan** | Meal plans constrained by goals, restrictions, and FKB foods |
| **Coach** | Conversational guidance grounded in user logs + guidelines |
| **Trust** | Disclaimers, account deletion, restore purchases, privacy — App Store ready |

## 1.4 Success definition (12 months)

- Users can complete scan → verified or estimated log in &lt; 8s p95.
- ≥ 70% of successful scans resolve to **verified** FKB entries (after curation ramp).
- MAPE calories on internal golden set ≤ 30% vs USDA/VN reference (matched samples).
- Subscription funnel live; restore purchase + delete account pass review.
- Crash-free sessions ≥ 99.5%; AI cost per DAU within budget envelope.

## 1.5 Non-goals (explicit)

- Diagnosing disease or prescribing treatment.
- Guaranteeing lab-grade accuracy on every photo.
- Supporting every world cuisine on day one.
- Replacing registered dietitians.

---

# PART 2 — Functional Requirements

## 2.1 Core epics

| ID | Epic | Priority | Notes |
|----|------|----------|-------|
| E01 | Auth & profile | P0 | Existing Firebase Auth; extend profile (goals, restrictions, weight) |
| E02 | Food scan | P0 | **Already implemented** — evolve with FKB match + source badge |
| E03 | Nutrition log & history | P0 | History exists; standardize on `food_id` + grams + source |
| E04 | Food Knowledge Base | P0 | **New** — verified warehouse |
| E05 | Meal plan generator | P1 | Exists via Groq; constrain to FKB + goals |
| E06 | Insights & reports | P1 | Weekly/monthly; prefer verified logs |
| E07 | Health coach chat | P1 | Exists; ground on user context + FKB |
| E08 | Water / weight tracking | P2 | Lightweight local + sync |
| E09 | Shopping list | P2 | From meal plan grocery list |
| E10 | Subscription & coins | P0 | Exists (IAP + coins + ads) |
| E11 | Cloud backup | P1 | Exists pattern; align with FKB ids |
| E12 | Notifications | P1 | Exists; meal reminders, progress |
| E13 | Legal & compliance UX | P0 | Privacy, Terms, delete account, disclaimers |

## 2.2 Scan flow — target behavior

```
User taps Scan
  → Camera | Gallery
  → Gate: premium OR coins
  → Permission + pick image
  → AI vision (name, portion_grams, confidence)
  → FKB matcher
      → HIT  → macros from FKB × grams/100, source=verified
      → MISS → macros from AI, source=estimated, enqueue curation signal
  → Persist log (local first)
  → Optional: sample online MAPE audit
  → UI shows badge + editable grams
  → Side effects: coins, ads, notifications
```

## 2.3 Source-of-truth policy (product rule)

| Source | User label | Editable | Used in insights by default |
|--------|------------|----------|------------------------------|
| `verified` | “Theo [USDA / Viện DD / Curated]” | grams yes; macros warn | Yes |
| `estimated` | “Ước lượng AI” | grams + macros | Yes, weighted lower later |
| `user_edited` | “Bạn đã chỉnh” | yes | Yes |
| `rejected` | Not food | n/a | No |

## 2.4 Acceptance criteria — scan (production)

- [ ] p95 latency image→result ≤ 8s on median device + good network.
- [ ] Not-food path shows clear UX (existing `NOT_FOOD_IMAGE`).
- [ ] Every saved item has `source` enum.
- [ ] Offline: queue failed AI calls; show cached history.
- [ ] No API keys in client binary (already true via Cloud Function).

---

# PART 3 — System Architecture

## 3.1 High-level diagram

```
┌─────────────────────────────────────────────────────────────┐
│                     Flutter App (iOS/Android)                │
│  UI · Providers · SQLite (offline log) · Secure Storage     │
└───────────────┬─────────────────────────────▲───────────────┘
                │ Callable / HTTPS            │ Streams / REST
                ▼                             │
┌─────────────────────────────────────────────────────────────┐
│                 API / Cloud Functions layer                  │
│  Auth gate · App Check · Rate limit · Feature flags          │
└───────┬─────────────┬──────────────┬────────────┬───────────┘
        │             │              │            │
        ▼             ▼              ▼            ▼
   AI Gateway    FKB Service    Billing/IAP    Notifications
   (multi-model) (search/get)   verify         FCM
        │             │
        ▼             ▼
   Groq/OpenAI/    Postgres or Firestore FKB
   Gemini/Claude   + USDA import jobs
        │
        ▼
   Optional queue (Cloud Tasks) for batch eval / curation
```

## 3.2 Design principles

1. **Offline-first logs** — SQLite remains source for on-device history; cloud is sync + FKB + AI.
2. **AI never sole truth** — macros display prefers FKB.
3. **Server-side secrets** — Groq/OpenAI/USDA keys only in Functions/Secret Manager.
4. **Provider-agnostic AI** — `AiGateway` interface; swap models via config.
5. **Observable** — every AI call logs model, prompt_version, tokens, latency, outcome.
6. **Evolve, don’t rewrite** — scan path in `FoodProvider` / `GroqService` is extended, not discarded.

## 3.3 Logical components

| Component | Responsibility | Today | Target |
|-----------|----------------|-------|--------|
| Mobile app | UX, local DB, gates | Flutter full scan | + FKB client, badges |
| `groqChatCompletion` | AI proxy + daily cap | Live | Generalize → `aiGateway` |
| FKB service | Search/get verified foods | **Missing** | New |
| Matcher | AI name → food_id | **Missing** | New |
| Validation job | MAPE vs USDA | Designed | Batch + sample online |
| IAP / coins | Monetization | Live | Keep |
| Curation admin | Promote estimated→verified | **Missing** | Later (console or sheet) |

---

# PART 4 — Mobile Architecture

## 4.1 Platform decision

**Keep Flutter.**  
Codebase, widgets, providers, Firebase wiring, and scan UX already exist. Migrating to React Native/Expo would burn months without user value.

**ADR-001:** Flutter retained (see Part 16).

## 4.2 Layering (target)

```
lib/
  main.dart
  config/           # colors, api, ads, feature flags
  models/           # Food, MealPlan, FoodLog, FkbFood, ...
  data/
    local/          # sqflite/drift DAOs
    remote/         # functions, fkb api
    repositories/   # FoodRepository, LogRepository, PlanRepository
  providers/        # ChangeNotifier / Riverpod later
  services/         # thin wrappers (image, notifications)
  features/
    scan/
    history/
    plan/
    coach/
    settings/
    subscription/
  widgets/
  utils/
```

**Migration style:** feature folders grow gradually; do not big-bang move every file.

## 4.3 State

- Short term: keep **Provider** (already pervasive).
- Optional later: Riverpod for new modules only.
- Rule: no continuous pointer/scroll state in `setState`/`notifyListeners` loops.

## 4.4 Local database

- Keep **SQLite** (`database_helper` today).
- Schema additions:
  - `food_logs.source`
  - `food_logs.fkb_food_id` (nullable)
  - `food_logs.portion_grams`
  - `food_logs.prompt_version` / `model_id`
- Consider **Drift** only if schema migrations become painful.

## 4.5 Offline behavior

| Action | Offline |
|--------|---------|
| View history | Yes |
| Edit grams on existing log | Yes |
| New scan | Queue or block with clear message (AI requires network) |
| Meal plan generate | Requires network |
| FKB search cache | LRU of recent matches optional |

---

# PART 5 — Backend Architecture

## 5.1 Current vs target

| Concern | Current | Target |
|---------|---------|--------|
| Runtime | Firebase Cloud Functions v2 | Same primary; Cloud Run if CPU-heavy import |
| Auth | Firebase Auth | Same + App Check (already) |
| Data | Firestore (user) + client SQLite | + FKB store (Firestore **or** Postgres) |
| AI | Single `groqChatCompletion` | `aiComplete` multi-provider |
| Secrets | GROQ_API_KEY | + USDA_FDC_API_KEY, optional OPENAI/GEMINI |

## 5.2 Recommended callable surface

| Function | Auth | Purpose |
|----------|------|---------|
| `aiComplete` | Required | Unified chat/vision completion |
| `fkbSearch` | Required | Query verified foods |
| `fkbGet` | Required | Get by food_id |
| `matchFood` | Required | AI payload → best FKB hit |
| `validateAgainstUsda` | Required | Online MAPE sample (internal) |
| `verifyPurchase` | Required | Existing IAP verification path |

## 5.3 Why not “all Postgres on day one”

Firestore + Functions already ship. FKB can start as:

1. **Firestore collection `fkb_foods`** (MVP, &lt; ~200k docs comfortable with good indexes), or  
2. **Postgres** when full-text + heavy analytics dominate.

**ADR-002** records the choice at implementation time with measured needs.

## 5.4 Jobs

| Job | Trigger | Work |
|-----|---------|------|
| USDA import | Scheduler / manual | Upsert Foundation/SR subset |
| VN FCT import | Manual | Upsert Vietnamese table |
| MAPE eval | CI / weekly | Golden set → report |
| Curation digest | Weekly | Top unmatched names |

---

# PART 6 — AI Architecture

## 6.1 Roles of models

| Task | Input | Output | Suggested tier |
|------|-------|--------|----------------|
| Food vision | Image | name, portion_grams, is_food, confidence | Groq vision / Gemini Flash |
| Meal plan | Goals + restrictions + nutrition context | Strict JSON plan | Llama 70B / Gemini Flash / GPT mini |
| Insights | Aggregated logs | 3–5 insight objects | Same as plan or cheaper |
| Health coach | History + user context | Natural language | Stronger model optional |
| Matching assist | Ambiguous name | Normalized query / aliases | Small text model optional |

## 6.2 AI Gateway rules

1. Client never holds provider API keys.
2. Every request: `uid`, `task`, `model`, `prompt_version`, latency, token usage logged.
3. Daily per-uid rate limit (existing pattern — keep and tune).
4. JSON tasks: schema validation (Zod) + one retry with “repair” prompt.
5. Fail open to user-friendly errors; fail closed on auth.

## 6.3 Prompt versioning

```
prompt_version = "scan_v3" | "plan_v2" | "coach_v1"
```

Stored on each log/plan. MAPE and quality metrics sliced by version.

## 6.4 Cost routing (policy)

| Task | Default | Premium upsell |
|------|---------|----------------|
| Scan vision | Low-cost vision | Higher-accuracy vision |
| Meal plan | Fast JSON model | Higher-quality model |
| Coach | Mid model | Top model / longer context |

Exact model IDs live in Remote Config / server config — not hardcoded in app releases.

## 6.5 Grounding

- Coach and plan prompts include: last N days averages, restrictions, preferred FKB food ids when available.
- Never invent micronutrient claims without FKB or explicit estimate flag.

---

# PART 7 — Database Design

## 7.1 Conceptual ERD

```
users
  id, auth_providers, created_at, locale, goals, restrictions[]

fkb_foods
  food_id PK
  name_en, name_vi, aliases[]
  nutrients_per_100g (json/map)
  source (usda|vn_fct|off|curated)
  source_ref (fdc_id, ...)
  confidence, verified_at, verified_by
  data_type (foundation|sr|branded|...)

food_logs
  id, user_id, fkb_food_id nullable
  display_name
  portion_grams
  nutrients_total (denormalized for offline)
  source (verified|estimated|user_edited)
  model_id, prompt_version
  image_path
  analyzed_at

meal_plans
  id, user_id, json_body, params, created_at

chat_messages
  id, user_id, role, content, created_at

subscriptions / coin_ledger
  existing patterns

validation_logs (internal)
  matched, ape_*, model, prompt_version, ts
```

## 7.2 Nutrient canonical keys

Use consistent keys everywhere:

`calories_kcal`, `protein_g`, `carbs_g`, `fat_g`, `fiber_g`, `sugar_g`, `sodium_mg`

USDA number map (server):

| Key | FDC nutrient number |
|-----|---------------------|
| calories_kcal | 1008 |
| protein_g | 1003 |
| carbs_g | 1005 |
| fat_g | 1004 |
| fiber_g | 1079 |
| sugar_g | 2000 |
| sodium_mg | 1093 |

## 7.3 FKB import rules

- Prefer **per 100g**.
- Store original language names + English when available.
- Aliases: common VN spellings, brand-less forms.
- Soft-delete never hard-delete verified rows referenced by logs.

---

# PART 8 — API Design

## 8.1 Conventions

- Firebase Callable preferred for authenticated app traffic.
- All responses: `{ ok, data?, error?: { code, message } }`.
- Idempotency keys for purchase verification.
- Pagination: `cursor` + `limit` for search.

## 8.2 `matchFood` (sketch)

**Request:**

```json
{
  "food_name": "phở bò",
  "portion_grams": 350,
  "locale": "vi",
  "ai_nutrients": { "calories_kcal": 420, "protein_g": 22 }
}
```

**Response:**

```json
{
  "ok": true,
  "data": {
    "status": "verified",
    "food_id": "usda_174036",
    "match_score": 0.81,
    "nutrients_total": { "calories_kcal": 390, "protein_g": 20 },
    "source_label": "USDA FoodData Central",
    "ai_fallback_used": false
  }
}
```

## 8.3 Error codes (shared)

`unauthenticated`, `rate_limited`, `not_food`, `ai_timeout`, `ai_parse_error`, `fkb_unavailable`, `invalid_argument`

---

# PART 9 — Infrastructure

## 9.1 Environments

| Env | Purpose |
|-----|---------|
| `dev` | Emulators + debug flags |
| `staging` | Production-like; TestFlight / internal track |
| `prod` | App Store / Play |

## 9.2 Services

- Firebase: Auth, Firestore, Functions, Storage, FCM, Crashlytics, Analytics, App Check
- Secrets: GCP Secret Manager
- Optional later: Cloud SQL (Postgres), Memorystore (Redis), Cloud Tasks
- Object storage: Firebase Storage for meal images (premium path exists)

## 9.3 When to add Redis / Queue

| Symptom | Add |
|---------|-----|
| Repeated FKB search hot keys | Redis cache in front of FKB |
| USDA import / MAPE batch long | Cloud Tasks / Cloud Run job |
| Fan-out notifications heavy | Already FCM; queue if custom fan-out |

Do **not** add Redis on day one without measured latency pain.

---

# PART 10 — DevOps

## 10.1 CI pipeline (target)

```
PR → analyze (dart) → unit tests → (optional) MAPE job on changed prompts
main → build Android + iOS artifacts → deploy Functions → tag
```

## 10.2 Release train

1. Feature flags off in prod.
2. Staging bake ≥ 48h.
3. Staged rollout Play; phased TestFlight.
4. Monitor crash + AI error rate + cost dashboard.

## 10.3 Observability

| Signal | Tool |
|--------|------|
| Crashes | Crashlytics |
| Product events | Analytics |
| AI cost/latency | Firestore `ai_usage` or Langfuse |
| Functions logs | Cloud Logging |
| MAPE trends | Weekly report from `validation_logs` |

---

# PART 11 — Security

## 11.1 Hard requirements

- [ ] No provider API keys in app binary (already).
- [ ] App Check enforced on sensitive callables.
- [ ] Auth required on AI and FKB write-ish paths.
- [ ] Rate limit per uid (AI).
- [ ] Image access: user-scoped storage paths.
- [ ] PII minimized in AI prompts (no full legal name required).
- [ ] Account deletion wipes cloud user data path (App Store).

## 11.2 Threat notes

| Threat | Mitigation |
|--------|------------|
| Stolen ID token → AI abuse | App Check + rate limit + cost alerts |
| Prompt injection in coach | System prompt isolation; no tool that mutates billing |
| Scraping FKB | Auth + rate limit + no public dump API |

---

# PART 12 — Performance & Scaling

## 12.1 Latency budgets

| Path | p95 target |
|------|------------|
| Cold open → home | ≤ 2.5s |
| Scan end-to-end | ≤ 8s |
| FKB search | ≤ 300ms cached / ≤ 800ms uncached |
| History scroll | 60fps, local DB |

## 12.2 Scale milestones

| Users | Focus |
|-------|--------|
| 0–1k | Stabilize scan + FKB MVP; cost caps |
| 1k–10k | Cache FKB; prompt/model A/B; curation of top unmatched |
| 10k–50k | Consider Postgres FKB; stronger monitoring; regional if needed |
| 50k–100k+ | Queue heavy jobs; CDN images; dedicated AI budget ops |

## 12.3 AI cost controls

- Daily uid cap (existing).
- Remote Config model tier.
- Cache identical image hashes short TTL (optional, privacy-aware).
- Prefer FKB hit → skip re-vision only when product allows “re-log same food”.

---

# PART 13 — Apple Review & Store Checklist

## 13.1 Mandatory product behaviors

- [ ] **Delete account** in-app (not only email support).
- [ ] **Restore purchases** working.
- [ ] Privacy Policy URL + in-app access.
- [ ] Terms of Use.
- [ ] Subscription terms clear (length, price, cancel).
- [ ] No misleading “medical” claims in screenshots/subtitle.
- [ ] Nutrition / health **disclaimer** visible (onboarding + settings).
- [ ] Sign in with Apple if other third-party login offered.

## 13.2 Copy guidelines

Avoid: “diagnose”, “treat”, “cure”, “guaranteed accurate lab results”.  
Prefer: “estimate”, “track”, “informed by USDA / national tables”, “not medical advice”.

## 13.3 Data & tracking

- Nutrition labels / ATT as required.
- Declare data collection in App Privacy nutrition.
- Crashlytics / Analytics disclosed.

## 13.4 IAP

- Coins and premium must use IOS IAP where digital features unlock.
- Existing `in_app_purchase` path — keep server verify.

---

# PART 14 — Development Roadmap

## Phase 0 — Architecture lock (1 week)

- Publish this MASTER_PLAN + ADR-001…004.
- Inventory current scan path; list extension points.
- Obtain USDA FDC API key; sample import 1k foods.

**Exit:** Team/agent agrees: Flutter stays; FKB is source of truth for verified macros.

## Phase 1 — FKB MVP (2–3 weeks)

- Schema `fkb_foods` + import USDA subset + VN FCT CSV.
- `fkbSearch` / `fkbGet` callables.
- Client `FoodRepository.matchAfterScan`.
- UI badge verified/estimated.

**Exit:** ≥ 1 live scan path shows verified badge on matched banana/chicken/rice tests.

## Phase 2 — Log model unification (1–2 weeks)

- Migrate food history rows to `portion_grams` + `source` + optional `fkb_food_id`.
- Edit grams recalculates from per_100g when verified.

**Exit:** History and insights read unified log model.

## Phase 3 — Quality system (2 weeks)

- Golden set v1 (50–100 items with grams + fdc_id).
- Offline MAPE job; CI optional gate.
- Online `validation_logs` sampling 5%.

**Exit:** Baseline MAPE report published; threshold policy documented.

## Phase 4 — Plan & coach grounding (2 weeks)

- Meal plan prompt includes FKB-aware context.
- Coach system prompt + disclaimer hardening.

**Exit:** Plan JSON still schema-valid; copy review for Store.

## Phase 5 — Production hardening (2 weeks)

- Delete account flow end-to-end.
- Restore purchase QA.
- Feature flags; cost dashboard; staged rollout.

**Exit:** Store submission candidate.

## Phase 6 — Growth (ongoing)

- Curation loop for top unmatched VN dishes.
- Premium model tier.
- Water/weight/shopping as P2.

---

# PART 15 — Coding Standards

## 15.1 Dart / Flutter

- `dart analyze` clean on CI.
- No new API keys in repo.
- Providers: side effects explicit; avoid notify spam.
- UI strings via existing localization pattern.
- New features: prefer repository over calling Functions from widgets.

## 15.2 TypeScript Functions

- Zod validate all callable inputs.
- Structured logs (json).
- Timeouts explicit; mirror client expectations.
- No `any` without justification.

## 15.3 Git

- Conventional commits preferred: `feat(scan):`, `fix(fkb):`, `chore(ai):`
- PR checklist: tests, flag plan, screenshot if UI, cost note if AI.

---

# PART 16 — AI Coding Rules (Claude / Cursor / GPT)

## 16.1 Before generating code, agent must

1. Read this MASTER_PLAN relevant parts.
2. Prefer extending `FoodProvider.analyzeFoodImage` over parallel scan pipelines.
3. Never put secrets in Flutter.
4. Any macro shown as verified must come from FKB math, not silent AI overwrite.
5. Match existing naming: `AppColors`, `AppLocalizations`, Provider patterns.

## 16.2 Prompt header for agents (copy)

```text
You are implementing NutriScan (Flutter + Firebase).
Single source of truth: docs/MASTER_PLAN.md
Rules:
- Flutter retained; do not propose RN migration.
- Verified nutrition numbers come from FKB (USDA/VN/curated).
- AI vision is for identity + portion estimate.
- Server-side AI only via Cloud Functions gateway.
- Preserve offline SQLite history behavior.
- App Store: no medical claims; support delete account & restore IAP.
```

## 16.3 Architecture Decision Records

### ADR-001 — Retain Flutter
**Decision:** Continue Flutter for mobile.  
**Reason:** Full scan, IAP, Firebase, localization already shipped. Rewrite cost ≫ benefit.  
**Status:** Accepted.

### ADR-002 — FKB storage
**Decision:** Start with Firestore `fkb_foods` (or Postgres if import size/query demands).  
**Reason:** Align with existing Firebase ops; revisit at 10k+ users or search pain.  
**Status:** Provisional until first import metrics.

### ADR-003 — AI Gateway
**Decision:** All model calls through Cloud Functions; multi-provider behind one interface.  
**Reason:** Key safety, rate limit, observability, cost routing.  
**Status:** Accepted (extends current Groq function).

### ADR-004 — Verified vs Estimated
**Decision:** Dual-path macros with mandatory `source` on every log.  
**Reason:** Production honesty + App Store / user trust.  
**Status:** Accepted.

### ADR-005 — USDA as primary external reference
**Decision:** USDA FoodData Central is default Western/global reference; VN FCT for local dishes.  
**Reason:** Authoritative, API access, industry standard for validation.  
**Status:** Accepted.

### ADR-006 — MAPE validation is a product system, not a one-off script
**Decision:** Golden set + offline job + optional online sample.  
**Reason:** Model/prompt regressions otherwise invisible.  
**Status:** Accepted.

### ADR-007 — Monetization remains IAP + coins + ads
**Decision:** Keep current economy; premium may unlock higher AI tier / unlimited scans.  
**Reason:** Already integrated; changing store products mid-flight is high risk.  
**Status:** Accepted.

### ADR-008 — Feature flags over hard cuts
**Decision:** Remote Config / server flags for matcher, model ids, sample rates.  
**Reason:** Safe rollout and instant rollback.  
**Status:** Accepted.

---

# PART 17 — Release Checklist

## 17.1 Pre-merge

- [ ] Analyze / tests green
- [ ] No secrets committed
- [ ] Strings localized for touched UX
- [ ] `source` handled if nutrition display touched

## 17.2 Pre-submit (store)

- [ ] Delete account tested on iOS/Android
- [ ] Restore purchases tested
- [ ] Privacy + Terms URLs live
- [ ] Subscription screenshots match behavior
- [ ] Health/nutrition disclaimers present
- [ ] Crashlytics clean on staging
- [ ] AI error rate acceptable
- [ ] Cost projection within budget

## 17.3 Post-release

- [ ] Monitor crash-free rate 72h
- [ ] Monitor AI spend daily
- [ ] Review top unmatched food names weekly
- [ ] MAPE report if prompt/model changed

---

# Appendix A — Mapping to existing codebase

| Plan concept | Existing artifact |
|--------------|-------------------|
| Scan UI | `lib/screens/main/home_screen.dart` |
| Image pick | `lib/services/media/image_picker_service.dart` |
| Analyze orchestration | `lib/providers/food/food_provider.dart` → `analyzeFoodImage` |
| Vision AI | `lib/services/ai/groq_service.dart` |
| AI proxy | `functions/src/index.ts` → `groqChatCompletion` |
| Food model | `lib/models/food.dart` |
| Local DB | `lib/services/database/database_helper.dart` |
| Meal plan | `meal_plan_provider.dart` + `generateMealPlan` |
| Coins | `lib/providers/coins/coin_provider.dart` |
| Subscription | `subscription_provider` + IAP service |

**Extension order:** FKB service → match after AI JSON → persist `source` → UI badge → MAPE jobs.

---

# Appendix B — Glossary

| Term | Meaning |
|------|---------|
| FKB | Food Knowledge Base — verified nutrient warehouse |
| MAPE | Mean Absolute Percentage Error vs reference |
| Golden set | Labeled images + portion grams + reference food ids |
| AiGateway | Server component routing to model providers |
| Verified | Macros computed from FKB × portion |
| Estimated | Macros from model without confident FKB match |

---

# Appendix C — Next documents (Phase 2 of docs)

After this MASTER_PLAN is accepted, split deep-dives:

```
docs/
  README.md
  MASTER_PLAN.md          ← this file
  00_PROJECT_VISION.md    (extract Part 1)
  01_PRODUCT_REQUIREMENTS.md
  02_TECH_STACK.md
  03_SYSTEM_ARCHITECTURE.md
  04_DATABASE_DESIGN.md
  05_BACKEND_ARCHITECTURE.md
  06_AI_ARCHITECTURE.md
  07_MOBILE_ARCHITECTURE.md
  08_SECURITY.md
  09_INFRASTRUCTURE.md
  10_DEVOPS.md
  11_APP_STORE_GUIDELINE.md
  12_ROADMAP.md
  13_CODING_STANDARD.md
  14_ADR/                 (ADR-001…)
  CLAUDE.md               (agent rules short form)
```

---

**End of MASTER_PLAN.md v1.0.0**

This document is the spine. Implementation without updating ADRs for contradictory decisions is considered out of process.
