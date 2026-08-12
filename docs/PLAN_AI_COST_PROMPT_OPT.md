# Kế hoạch thực hiện: Tối ưu Prompt AI + Chi phí Inference

**Dự án:** NutriScan  
**Ngày:** 2026-08-10  
**Mục tiêu:** Giảm chi phí gọi model, ổn định JSON, không phụ thuộc Groq Developer (đang khóa upgrade), giữ FKB verified/estimated và pipeline scan hiện tại.

**Không làm trong plan này:** Reskin UI Phase B, weekly budget, social share (đã có plan riêng).

---

## 0. Bối cảnh (vì sao làm)

| Ràng buộc | Hệ quả |
|----------|--------|
| Groq: free OK, **Developer tier tạm đóng** | Rate limit free không đủ production |
| Google One ≠ Gemini API | Cần API key + (khi scale) Cloud Billing riêng |
| Hiện 2 lần vision (validate → analyze) | Gần gấp đôi token ảnh |
| Schema / prompt dài | Output token + parse phức tạp |
| Mọi scan đều gọi AI | Chi phí tuyến tính theo volume |

**Nguyên tắc:** Ít request × model rẻ × ảnh nhỏ × cache × limit free × FKB sau AI.

---

## 1. Kết quả mong đợi (Definition of Done)

- [ ] Vision: **một** lần gọi model / ảnh (không còn validate riêng trừ khi A/B).
- [ ] Prompt analysis + meal plan + coach **gọn**, JSON đúng schema, `flutter analyze` / test parse OK.
- [ ] Ảnh gửi model đã **nén** (cạnh dài ≤ 1024).
- [ ] Provider cấu hình được qua env/secret: `gemini` | `openai` | `groq` (fallback).
- [ ] Primary mặc định staging: **Gemini Flash** (hoặc Flash-Lite); Groq chỉ fallback/dev nếu còn quota.
- [ ] Free user: **giới hạn số lần AI scan / ngày** (giữ hoặc siết coin gate hiện có).
- [ ] FKB `matchFood` / badge verified **không đổi quy tắc**.
- [ ] Chạy lại eval MAPE / match_rate trên golden set; ghi số trước/sau.
- [ ] Budget alert billing (GCP hoặc OpenAI) bật ở mức thấp (vd $10 / $50).

---

## 2. Phạm vi & ngoài phạm vi

### Trong scope

1. Prompt + schema trong `lib/services/ai/groq_service.dart` (và rename/abstraction nếu cần).  
2. Nén ảnh trước khi đưa vào request.  
3. AI Gateway / multi-provider phía **Cloud Functions** (key không vào client).  
4. Giới hạn usage + cache đơn giản (hash / món đã lưu).  
5. Tài liệu env + checklist deploy.

### Ngoài scope

- Đổi ngưỡng FKB / công thức verified.  
- Self-host GPU.  
- Fine-tune model.  
- UI reskin đầy đủ.  
- Barcode / weekly budget.

---

## 3. Phases thực hiện

### Phase 1 — Prompt & schema (1–2 ngày) · **không cần đổi billing**

**Mục tiêu:** Ít token, JSON ổn, vẫn chạy trên Groq free / provider hiện tại.

| # | Việc | File / chỗ |
|---|------|------------|
| 1.1 | Gộp food validation vào analysis: một request vision; `is_food: false` → dialog non-food như cũ | `groq_service.dart` — bỏ hoặc bypass `_getFoodValidationPrompt` trên happy path |
| 1.2 | Thay `_getLocalizedPrompt` bằng schema ngắn (food_name, portion_grams, macros, serving_size, description ≤ 2 câu) | Cùng file |
| 1.3 | Cắt meal plan schema: bỏ instructions dài / tips nếu UI không bắt buộc; hạ `max_tokens` (vd 3072) | `_getMealPlanPrompt`, `_requestMealPlanContent` |
| 1.4 | Coach: system ngắn + giới hạn độ dài trả lời; chỉ gửi N tin history gần nhất (vd 8) | `_getHealthCoachSystemPrompt`, `getHealthCoachResponse` |
| 1.5 | Insights: gửi aggregate, không full log thô | `_getInsightsPrompt` |
| 1.6 | `temperature` analysis ~0.2–0.3 | request body |

**Prompt analysis chuẩn (copy vào code):**

```text
Role: Food image → JSON only. Language for ALL text fields: {langName}.

Return ONE JSON object, no markdown:
{
  "is_food": true,
  "food_name": "",
  "portion_grams": 0,
  "calories": 0,
  "protein": 0,
  "carbs": 0,
  "fat": 0,
  "fiber": 0,
  "sugar": 0,
  "sodium": 0,
  "serving_size": "",
  "description": ""
}

Rules:
- is_food=false only if no edible item. Unsure → true.
- portion_grams > 0 when is_food=true; numbers estimate visible edible portion.
- description ≤ 2 short sentences in {langName}; food_name in {langName}.
- No medical claims. No extra keys.
```

**Verify Phase 1**

- [ ] Scan món thật → JSON parse OK, log SQLite OK.  
- [ ] Ảnh không phải đồ ăn → non-food dialog.  
- [ ] Meal plan generate + parse OK.  
- [ ] Coach trả lời + không claim y tế.  
- [ ] So nhanh: số lần gọi API / 1 scan = **1** (vision).

**Commit gợi ý:** `perf(ai): single vision call and compact prompts`

---

### Phase 2 — Nén ảnh + giới hạn client (0.5–1 ngày)

| # | Việc |
|---|------|
| 2.1 | Trước khi encode base64 / upload: resize max side **768–1024**, JPEG quality ~0.7–0.8 |
| 2.2 | Xác nhận coin / daily AI limit free vẫn chặn (không nới khi tối ưu) |
| 2.3 | (Optional) Nút “Log lại món đã lưu” trên Home — **0 AI** (reuse row SQLite) |

**Verify:** Kích thước payload ảnh giảm rõ (log byte length); scan vẫn nhận diện được.

**Commit:** `perf(ai): compress images before vision request`

---

### Phase 3 — Multi-provider gateway (2–3 ngày) · **quan trọng khi hết quota Groq**

**Kiến trúc mục tiêu:**

```
App → Cloud Function (callable)
        → provider router (env)
              primary: Gemini Flash
              fallback: Groq free | OpenAI | OpenRouter
        → cùng JSON contract
→ client → matchFood / FKB (không đổi)
```

| # | Việc | Ghi chú |
|---|------|---------|
| 3.1 | Secret: `GEMINI_API_KEY` (và/hoặc `OPENAI_API_KEY`) trong Functions | Không put key vào Flutter |
| 3.2 | Env/param: `AI_VISION_PROVIDER=gemini\|openai\|groq` | Remote Config optional sau |
| 3.3 | Implement adapter: cùng input (messages/image) → cùng shape output text/JSON | `functions/src` |
| 3.4 | Giữ `groqChatCompletion` hoặc generalize `aiChatCompletion` | App chỉ gọi một callable |
| 3.5 | Timeout + 1 retry fallback provider | Tránh double-bill vô hạn |
| 3.6 | Daily per-user cap phía Functions (đã có ý với Groq) áp dụng mọi provider | Chống abuse |

**Thứ tự bật:**

1. Staging: `gemini` primary.  
2. Đo latency + parse rate.  
3. Production khi ổn; Groq = fallback nếu còn key free.

**Verify Phase 3**

- [ ] Staging scan end-to-end với Gemini.  
- [ ] Tắt Gemini key → fallback vẫn trả lỗi controlled hoặc provider 2.  
- [ ] FKB match + badge như cũ.  
- [ ] Không lộ key trên client (inspect request).

**Commit:** `feat(ai): multi-provider gateway with Gemini primary`

---

### Phase 4 — Cache & giảm gọi lặp (1–2 ngày)

| # | Việc | Ưu tiên |
|---|------|---------|
| 4.1 | Cache kết quả theo **perceptual/hash** ảnh (local hoặc Functions TTL 24–72h) | Cao |
| 4.2 | UI: chọn từ **hôm nay / gần đây** không gọi AI | Cao |
| 4.3 | Text mô tả món → search FKB trước, AI text chỉ khi miss | Trung (sau) |

**Verify:** Scan trùng ảnh / “ăn lại” không tăng billing tương ứng.

**Commit:** `perf(ai): response cache and reuse logged meals`

---

### Phase 5 — Đo lường & kiểm soát tiền (song song Phase 3–4)

| # | Việc |
|---|------|
| 5.1 | Log `provider`, `model`, `prompt_version`, usage tokens (Functions logger) |
| 5.2 | Chạy `eval` golden set — ghi `match_rate` / MAPE trước–sau đổi model/prompt |
| 5.3 | Billing alert GCP / OpenAI: $10, $50 |
| 5.4 | Dashboard đơn giản: số AI calls / ngày (Firestore aggregate hoặc log) |

**Verify:** Có số liệu 7 ngày; biết cost/scan xấp xỉ.

---

## 4. Thứ tự đề xuất (timeline ~1–2 tuần)

```
Tuần 1
  Ngày 1–2  Phase 1 prompts
  Ngày 2–3  Phase 2 compress + reuse UI tối thiểu
  Ngày 3–5  Phase 3 gateway Gemini

Tuần 2
  Ngày 1–2  Phase 4 cache
  Ngày 2–3  Phase 5 metrics + eval + alert
  Buffer    Fix parse / rate limit / docs CLAUDE.md
```

Có thể **chỉ làm Phase 1+2** trước nếu chưa có Gemini key — vẫn giảm cost ngay trên Groq free.

---

## 5. Rủi ro & giảm thiểu

| Rủi ro | Giảm thiểu |
|--------|------------|
| Gemini JSON lệch schema | `response_format` / prompt “JSON only” + repair retry 1 lần (đã có pattern meal plan) |
| match_rate giảm sau đổi model | Golden set bắt buộc trước ship production |
| User free hết limit sớm | Copy rõ + rewarded ad / premium; text log FKB |
| Double bill primary+fallback | Fallback chỉ khi error/timeout, không parallel |
| Medical claim từ coach | System prompt cố định + filter từ cấm |

---

## 6. Checklist bàn giao

- [ ] `docs/PLAN_AI_COST_PROMPT_OPT.md` (file này) trong repo  
- [ ] Cập nhật `CLAUDE.md`: primary provider, cấm key client, prompt_version  
- [ ] Secrets documented (không commit value)  
- [ ] Số liệu eval trước/sau  
- [ ] Quyết định production provider ghi ADR ngắn (vd `ADR-00X-ai-provider.md`)

---

## 7. Agent / Claude Code — lệnh giao việc

```text
Đọc CLAUDE.md và docs/PLAN_AI_COST_PROMPT_OPT.md.
Chỉ làm Phase 1 trước (prompt + single vision call).
Không đổi FKB rules, không reskin UI, không bỏ coin gate.
Sau Phase 1: báo cáo file đổi, cách test scan, số lần gọi API mỗi scan.
Dừng lại chờ review trước Phase 3 (Gemini gateway).
```

Phase 3 khi được phép:

```text
Tiếp PLAN_AI_COST_PROMPT_OPT Phase 3:
- GEMINI_API_KEY secret
- AI_VISION_PROVIDER
- Callable thống nhất, Gemini primary
- Giữ contract JSON Phase 1
- Không đưa key xuống Flutter
```

---

## 8. Tóm tắt một trang

| Phase | Việc chính | Cost impact |
|-------|------------|-------------|
| 1 | 1 vision call + prompt/schema gọn | Cao (ngay) |
| 2 | Nén ảnh + reuse món | Trung–cao |
| 3 | Gemini primary + fallback | Mở production khi Groq kẹt |
| 4 | Cache / hash | Cao khi user lặp |
| 5 | Đo & alert | Kiểm soát burn |

**Xong plan này:** app vẫn Personal AI Nutrition Assistant với FKB; inference **rẻ hơn, ít phụ thuộc Groq paid, sẵn sàng scale có trần chi phí.**
