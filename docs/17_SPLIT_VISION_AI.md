# 17 — Tách riêng đường xử lý ảnh (Vision AI)

**Document type:** Implementation plan for AI coding agents
**Status:** Ready to execute
**Last updated:** 2026-08-12
**Depends on:** `CLAUDE.md`, `docs/MASTER_PLAN.md`
**Hard rule:** Do **not** fork a second scan pipeline. Keep a single entry: `FoodProvider.analyzeFoodImage`. Only split **internal** image-prep + vision transport from text LLM calls.

**Revision note:** rewritten from an external draft after verifying it against the
actual code. Two corrections vs the original: image resize is 1024px (not
600px) with no size-skip shortcut, and — the important one — vision and text
calls do **not** already use different models today; both read the same
single `FeatureFlags().aiModelScan`. The original plan's Phase A was a pure
file reorg with zero latency/cost benefit and pushed the actual model split
to an unscoped "Follow-up." That's folded into scope here instead (§2.4,
Step 5) since it's low-risk (defaults preserve current behavior exactly) and
it's the only part of this ticket that actually moves the meal-plan-latency
problem raised separately this session.

---

## 0. Goal

Today almost everything goes through one client class `GroqService` and one Cloud Function `groqChatCompletion`, on one shared model:

| Call site | Needs image? | Model today | Should use |
|-----------|--------------|-------------|------------|
| `analyzeFoodImage` | Yes | `FeatureFlags().aiModelScan` | **Vision path** |
| `isFoodImage` | Yes | `FeatureFlags().aiModelScan` | **Vision path** |
| `generateMealPlan` | No | `FeatureFlags().aiModelScan` (same flag) | **Text path** |
| `fetchInsights` | No | `FeatureFlags().aiModelScan` (same flag) | **Text path** |
| `getHealthCoachResponse` | No | `FeatureFlags().aiModelScan` (same flag) | **Text path** |

**Target:**

1. Client: image resize/encode + vision request live in a dedicated module.
2. Client: vision and text calls read **separate** Remote Config model flags, so text traffic can move to a faster/cheaper non-reasoning model without touching vision, and without an app release.
3. Server: optional dedicated callable for vision (so provider can be Gemini/OpenAI later without touching meal-plan/coach).
4. Text traffic stays on Groq (or current text model) via existing `groqChatCompletion`.

---

## 1. Current code (what to split)

File: `nutriscan/lib/services/ai/groq_service.dart`

| Piece | Role | Destination |
|-------|------|-------------|
| `_processAndEncodeImage` | Decode → resize to ≤1024px longest side (only if larger) → always re-encode JPEG q75 → base64. No size-based skip; decode-failure falls back to raw base64 of the original bytes. | `image_prepare.dart` (pure, no network) |
| `_mimeTypeFromFile` | mime from path | same |
| `isFoodImage` | vision validation | `vision_ai_service.dart` |
| `analyzeFoodImage` | vision nutrition JSON | `vision_ai_service.dart` |
| `_getFoodValidationPrompt` / `_getLocalizedPrompt` / schema | vision prompts | `vision_ai_service.dart` or `vision_prompts.dart` |
| `generateMealPlan` / `fetchInsights` / `getHealthCoachResponse` | text only | keep in `groq_service.dart` **or** rename to `text_ai_service.dart` |
| `_callGroq` | HTTPS callable | text path keeps `groqChatCompletion`; vision path may call `visionCompletion` later (§3 Phase B) |
| `stripReasoning`, `_extractContentFromResponse`, brace/bracket matchers | shared response parsing | keep in `groq_service.dart`, import from `vision_ai_service.dart` — both paths can hit a reasoning model until §2.4 changes that, and `stripReasoning` is defense-in-depth even after |

`FoodProvider.analyzeFoodImage` must still call **one** method (e.g. `VisionAiService.analyzeFoodImage` or thin wrapper on existing name). Do not add a parallel scan API on the provider.

---

## 2. Target client layout

```
nutriscan/lib/services/ai/
  image_prepare.dart          # encode/resize only
  vision_ai_service.dart      # isFoodImage + analyzeFoodImage
  vision_prompts.dart         # optional: prompts + JSON schema strings
  groq_service.dart           # text: meal plan, insights, coach (+ shared parse helpers if needed)
  # optional later:
  # text_ai_service.dart      # rename when Groq is no longer the only text host
```

### 2.1 `image_prepare.dart`

Move **unchanged behavior** from current helpers (`groq_service.dart:47-88`):

- `mimeTypeFromFile(File)`
- `processAndEncodeImage(File)` → returns base64 string. Real current behavior: decode with `package:image`; if decode fails, return raw base64 of the original bytes unchanged; otherwise resize only if either dimension exceeds 1024px (longest side capped at 1024, aspect preserved), always re-encode to JPEG at quality 75 regardless of original format or size, then base64-encode the JPEG bytes.

Public, testable, no Firebase / no Provider.

### 2.2 `vision_ai_service.dart`

Responsibilities:

- Build multimodal `messages` (`text` + `image_url` data URL).
- Call backend vision endpoint (see §3).
- Parse JSON (`is_food`, macros, `portion_grams`, etc.) — reuse extract/parse logic from current `GroqService` (`_extractContentFromResponse`, `stripReasoning`).
- Expose:
  - `Future<bool> isFoodImage(File, {language})`
  - `Future<Map<String, dynamic>> analyzeFoodImage(File, {language})`

Model id: `FeatureFlags().aiModelVision` (§2.4 — new flag, defaults to the current hardcoded scan model, so this is a rename in effect, not a behavior change).

Do **not** put meal-plan or coach here.

### 2.3 `groq_service.dart` (text only after split)

Keep:

- `generateMealPlan`
- `fetchInsights`
- `getHealthCoachResponse`
- Shared: `_extractContentFromResponse`, `stripReasoning`, brace/bracket matchers, error localization, connectivity check (or move shared utils to `ai_response_utils.dart` if duplication with `vision_ai_service.dart` hurts)

Model id: `FeatureFlags().aiModelText` (§2.4 — new flag).

Remove vision methods once call sites updated.

### 2.4 `FeatureFlags` — split the model flag (new in this revision)

`lib/config/feature_flags.dart` currently exposes one Remote Config key,
`_aiModelScanKey` ("ai_model_scan"), read by every call site regardless of
whether it sends an image. Split it in two, **both defaulting to today's
model** so this step alone changes zero runtime behavior:

```dart
static const _aiModelVisionKey = 'ai_model_vision'; // was ai_model_scan
static const _aiModelTextKey = 'ai_model_text';      // new

// in init(): setDefaults({
//   ..., 
//   _aiModelVisionKey: ApiConfig.groqModel,
//   _aiModelTextKey: ApiConfig.groqModel,
// })

String get aiModelVision {
  final value = _remoteConfig?.getString(_aiModelVisionKey) ?? '';
  return value.isEmpty ? ApiConfig.groqModel : value;
}

String get aiModelText {
  final value = _remoteConfig?.getString(_aiModelTextKey) ?? '';
  return value.isEmpty ? ApiConfig.groqModel : value;
}
```

Keep the Remote Config parameter key string for vision as `ai_model_vision`
(a rename from `ai_model_scan` — nothing in the console has been set for it
yet per current ops state, so no migration needed; if that's no longer true,
keep `ai_model_scan` as the vision key instead of renaming it and only add
`ai_model_text` as new).

This is what actually lets text traffic (meal plan, insights, coach) move off
the shared reasoning model later — flip `ai_model_text` in the Remote Config
console to a faster non-reasoning Groq model (e.g. `llama-3.3-70b-versatile`)
with no app release. **This ticket does not flip that default** — it only
builds the capability. Changing the live text model is a quality/latency
trade-off for a separate decision, not bundled into this refactor.

### 2.5 Call site updates

| File | Change |
|------|--------|
| `food_provider.dart` | Inject/use `VisionAiService` (or factory) for `analyzeFoodImage` instead of `GroqService` for that call only |
| Any UI calling `isFoodImage` | Point to `VisionAiService` |
| Meal plan / coach / insights | Still `GroqService`, now reading `aiModelText` |

Search repo for `GroqService` and `analyzeFoodImage` / `isFoodImage` and update imports.

---

## 3. Server (recommended, can be Phase B)

### Phase A (client-only split) — ship first

Vision continues to call existing callable:

```ts
// still: groqChatCompletion
```

Client reorganizes files and splits the model flag (§2.4); no Functions deploy required for structure, and no Functions change at all since `groqChatCompletion` already takes `model` as a param in the request body.

### Phase B — dedicated vision callable

Add `visionCompletion` in `nutriscan/functions/src/index.ts` (or `vision.ts` imported from index):

- Auth + **same or stricter** daily rate limit (scan is the costly path).
- Input: `{ model?, messages, temperature?, max_tokens?, ... }` OpenAI-compatible multimodal body **or** a tighter schema `{ imageBase64, mimeType, prompt, language }`.
- Initially: forward to **Groq** with the vision-capable model (behavior parity).
- Later: switch implementation to Gemini / OpenAI without changing Flutter call shape.

Text stays on `groqChatCompletion`.

**Do not** put API keys in the Flutter tree (`CLAUDE.md`).

---

## 4. Implementation steps (agent order)

### Step 1 — Extract `image_prepare.dart`

- Copy `_processAndEncodeImage` + `_mimeTypeFromFile` behavior exactly (see §2.1 for the real current behavior).
- Unit-smoke: large image (>1024px either side) gets resized and re-encoded; small image still returns base64; a file that fails to decode returns raw base64 of the original bytes.

### Step 2 — Create `VisionAiService`

- Move `isFoodImage`, `analyzeFoodImage`, vision prompts/schemas.
- Internally use `ImagePrepare.processAndEncodeImage`.
- Transport: `_callVision(...)` → for Phase A call same `groqChatCompletion` HTTPS callable, `model: FeatureFlags().aiModelVision`.

### Step 3 — Slim `GroqService`

- Delete moved methods; fix any remaining references.
- Text calls (`generateMealPlan`, `fetchInsights`, `getHealthCoachResponse`) now read `model: FeatureFlags().aiModelText`.

### Step 4 — Wire `FoodProvider`

- Only change the AI client used for image analysis to `VisionAiService`.
- MatchFood / FKB / coin gates unchanged.

### Step 5 — Split the Remote Config flag (§2.4)

- Add `aiModelVision` / `aiModelText` to `FeatureFlags`, both defaulting to `ApiConfig.groqModel` (today's model) — verify via `configurationReport()`-style manual check that behavior is byte-identical until either is changed in the Remote Config console.
- This is the step that makes a later text-model swap a config change instead of a code change.

### Step 6 — (Optional) `visionCompletion` Cloud Function

- Parity tests: same image → comparable JSON fields.
- Feature flag or Remote Config: `vision_provider = groq | gemini | openai` (default `groq`).

### Step 7 — Verify

| # | Test | Expected |
|---|------|----------|
| 1 | Scan food photo | Same success path as before; FKB match still runs |
| 2 | Non-food image | `is_food: false` / existing NOT_FOOD handling |
| 3 | Meal plan | Still works via text path, still same model as before (flag defaults unchanged) |
| 4 | Health coach | Still works via text path |
| 5 | No Groq key in client | Still only Functions + Secret Manager |
| 6 | `analyzeFoodImage` only entry on provider | No second public scan API |
| 7 | Remote Config unset (fresh install / outage) | Both `aiModelVision` and `aiModelText` fall back to `ApiConfig.groqModel` — identical to pre-split behavior |

---

## 5. What not to do

- Do not create `FoodProvider.analyzeFoodImageV2` or a second scan pipeline.
- Do not move rate limiting only to the client.
- Do not embed Gemini/OpenAI keys in the app.
- Do not change nutrient key names (`calories_kcal`, `protein_g`, …) or verified macro rules.
- Do not expand vision prompts into medical diagnosis language.
- Do not flip `aiModelText`'s Remote Config value away from the current model as part of this PR — that's a separate, deliberate quality/latency trade-off decision (see revision note at top).

---

## 6. Follow-up (out of scope for this ticket)

- A/B Gemini Flash-Lite vs current Groq vision model on golden set.
- Actually flipping `ai_model_text` to a non-reasoning model and measuring meal-plan/coach latency + quality before/after.
- Analytics: `vision_latency_ms`, `vision_provider`, parse failures.

---

## 7. First PR title

`refactor(ai): split image prepare + VisionAiService from GroqService text path, split vision/text model flags`

**Scope:** Steps 1–5 only (Phase A, now including the flag split). Phase B callable (Step 6) in a second PR.
