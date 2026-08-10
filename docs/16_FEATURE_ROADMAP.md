# 16_FEATURE_ROADMAP.md
# NutriScan — Feature Roadmap (bám kiến trúc hiện tại)

**Status:** Proposal — thay thế bản `FEATURE_UPGRADE_PLAN.md` (nguồn ngoài, giả định
sai kiến trúc)
**Supersedes input:** `FEATURE_UPGRADE_PLAN.md` (downloaded, không nằm trong repo,
tham chiếu tới các doc/EPIC không tồn tại — xem § 0)
**Depends on:** `MASTER_PLAN.md` (kiến trúc, ADR), `plan.md` Phase 6 (growth, đang
chạy)
**Owner:** Product + Engineering

---

## 0. Vì sao viết lại thay vì dùng bản gốc

Bản gốc giả định:
- Đã qua "Production Gate Sprint 20" — thực tế: `plan.md` Phase 5 gần xong (còn lại
  toàn bộ là việc cần thiết bị vật lý, xem `CLAUDE.md` § 6), Phase 6 (growth) đang
  chạy ongoing.
- Có sẵn NestJS/Python Vision microservice, Redis, BullMQ — thực tế: Firebase
  Functions + Firestore + SQLite client-side. `MASTER_PLAN.md` Part 9.3 nói rõ
  **không thêm Redis/queue khi chưa đo được nghẽn thật**.
- Tham chiếu `20_PROJECT_EVOLUTION_PLAN.md`, `EPIC-06`, `EPIC-10`, `personas.md`...
  — không tồn tại trong `docs/`.

Roadmap này giữ nguyên **mục tiêu kinh doanh** của bản gốc (§ 1) nhưng viết lại
**cách làm** để mỗi feature map vào extension point đã có, theo đúng
`CLAUDE.md` § 4 và ADR trong `MASTER_PLAN.md` Part 16.3.

---

## 1. Mục tiêu (giữ nguyên từ bản gốc)

| Mục tiêu | Metric (6–12 tháng) |
|----------|--------------------------------|
| Tăng độ chính xác & tốc độ core loop | Scan Success Rate ≥ 92%, p95 scan < 8s (đã là target trong `MASTER_PLAN.md` § 12.1 — không đổi) |
| Tăng retention | D7 ≥ 30%, D30 ≥ 18%, DAU/MAU ≥ 28% |
| Tăng giá trị cảm nhận | % user xem Insight / tuần ≥ 40% |
| Giảm friction log meal | Time-to-log (sau scan) < 8 giây |
| Chuẩn bị B2B nhẹ | Family/Coach sharing cơ bản |

## 2. Nguyên tắc (bổ sung nguyên tắc kiến trúc vào bản gốc)

Giữ nguyên 5 nguyên tắc gốc (Canonical Food, feature flag, offline-first, A/B, bám
personas), **cộng thêm**:

6. **Leo thang hạ tầng theo bằng chứng, không theo dự đoán** (`MASTER_PLAN.md` §
   9.3) — thử bằng cách mở rộng `aiComplete`/Functions trước; chỉ tách service
   riêng khi có số đo latency/cost/accuracy chứng minh cần.
7. **Không fork scan pipeline** (`CLAUDE.md` hard rule) — multi-food, barcode
   đều phải đi qua `FoodProvider.analyzeFoodImage`, không phải luồng song song.
8. **Không AI value nào được gắn nhãn `verified`** trừ khi đi qua FKB × grams —
   áp dụng cho mọi feature mới hiển thị con số dinh dưỡng (Health Score, Insight,
   Eat-This-Instead...).

---

## 3. Bảng đối chiếu: đề xuất gốc → cách làm phù hợp kiến trúc hiện tại

| Feature gốc | Hạ tầng bản gốc đề xuất | Cách làm thực tế | Effort mới |
|---|---|---|---|
| A1 Multi-food Detection | Vision Service riêng (YOLO/Grounding DINO) + SAM + Redis cache | Mở rộng prompt `groqChatCompletion`/vision hiện có để trả về **mảng** `{name, portion_grams, confidence}[]` thay vì 1 object. UI: list các món để user bỏ/sửa (không cần bounding box ở MVP) | 1.5–2 tuần (so với 5–7 tuần) |
| A2 Serving Size Estimation | Depth model + reference object CV | Đã có `portion_grams` từ model vision hiện tại; sai số xử lý bằng A3 (Quick Adjust) + học từ chỉnh sửa của user (log `user_edited` diff vào `validation_logs`) | gộp vào A1/A3, ~0 tuần riêng |
| A3 Quick Adjust UI | Flutter UI + Nutrition Calculator local | Giữ nguyên — đúng, không đổi | 1–2 tuần |
| A4 Barcode + OCR | ML Kit + custom OCR parser | ML Kit on-device (đúng) + text kết quả đi qua `matchFood` hiện có thay vì viết parser riêng | 2 tuần |
| A5 Voice Log | Whisper API + Intent parser riêng | **Bỏ khỏi roadmap** — app đang đứng trên "scan a photo", voice log là kênh nhập liệu khác hướng, không phục vụ core loop đó | — |
| B1 Health Score | Scoring Engine + lightweight ML | Rule-based trong Functions, đọc từ `food_logs` đã unify (Phase 2 đã xong) | 2–3 tuần |
| B2 Weekly Insight | AI Gateway + aggregation job (BullMQ) | Firebase Scheduler (đã dùng cho USDA import) gọi Function tổng hợp + `aiComplete`. Không cần BullMQ ở quy mô này | 2 tuần |
| B3 Pattern Detection | Scheduled worker + clustering | Cùng Scheduler ở B2, rule-based trước (giờ ăn khuya = threshold), không cần clustering ML ngay | 1 tuần |
| B4 Smart Goal Suggestion | Rule-based | Giữ nguyên | 1–2 tuần |
| B5 HealthKit/Health Connect | HealthKit/Health Connect | Giữ nguyên, client-only | 2–3 tuần |
| C1 Family/Shared Meal | "Admin Platform" | Firestore collection `households` + `firestore.rules` theo `request.auth.uid`, không cần Admin Platform riêng | 3 tuần |
| C2 Challenge/Streak | Gamification engine | Local SQLite + feature flag, không cần engine riêng | 2 tuần |
| C3 Coach View | Role-based dashboard riêng | Trang web nhẹ trên Firebase Hosting đọc qua 1 Function có `role` claim — không phải "Admin Platform" mới | 2–3 tuần |
| C4 Widget/Live Activity | WidgetKit/Glance | Giữ nguyên, đọc SQLite local (đúng như `MASTER_PLAN.md` § 4.6 đã thiết kế sẵn) | 2 tuần |
| C5 Smart Reminder | Local notification | Giữ nguyên | 1 tuần |
| D1 Eat This Instead | Recommendation Engine riêng | Query khoảng cách nutrient trên `fkb_foods` đã có sẵn (không cần vector DB ở quy mô hiện tại) | 1.5 tuần |
| D2 Recipe Reverse | Vision + LLM riêng | `aiComplete` với prompt mới, tái dùng pipeline ảnh hiện có | 3 tuần |
| D3 7-day Meal Plan | Planner service + constraint solver | **Đã tồn tại** — `meal_plan_provider.dart` + `generateMealPlan` (`MASTER_PLAN.md` Appendix A). Chỉ cần mở rộng ràng buộc 7 ngày + sở thích | 1.5 tuần (so với 4–6 tuần) |
| D4 Allergy Guard | Rule engine + Food KB tags | Thêm field `tags[]` vào `fkb_foods` schema (Phase 1A đã có `FkbFood` contract), rule check tại `matchFood` | 1.5 tuần |
| D5 On-device Vision | TFLite/CoreML | Giữ làm bet sau cùng — chỉ làm nếu A1 (prompt-based) không đạt latency/cost mục tiêu | không đổi, để cuối |

---

## 4. Roadmap theo Phase (nối tiếp `plan.md` Phase 6 — đang chạy)

`plan.md` Phase 6 (Operations & growth) đã bao gồm: curation loop, mở rộng VN
coverage, tune `MATCH_THRESHOLD`. Roadmap này là **Phase 7 trở đi**, chạy song
song/sau khi Phase 6 ổn định (matcher đạt baseline MAPE đã publish).

### Phase 7 — Core Loop Upgrade (tháng 1–2, rút từ 1–3)
Mục tiêu: scan "đáng tin" và nhanh hơn, không xây hạ tầng mới.

| # | Feature | Extension point | Effort |
|---|---|---|---|
| 7.1 | Multi-food (prompt-based) | `groqChatCompletion` response schema + `FoodProvider.analyzeFoodImage` | 1.5–2 tuần |
| 7.2 | Quick Adjust UI | Flutter, local Nutrition Calculator | 1–2 tuần |
| 7.3 | Barcode + Label OCR | ML Kit client + `matchFood` | 2 tuần |

**Song song:** 7.3 độc lập với 7.1, có thể làm cùng lúc.
**Exit:** Scan Success Rate + Time-to-log đo được trên staging trước khi mở Phase 8.

### Phase 8 — Personalization & Insight (tháng 2–4)

| # | Feature | Extension point | Effort |
|---|---|---|---|
| 8.1 | Health Score | Functions rule-based, đọc `food_logs` | 2–3 tuần |
| 8.2 | Weekly Insight | Firebase Scheduler + `aiComplete`, prompt_version mới | 2 tuần |
| 8.3 | Pattern Detection (rule-based) | Cùng job 8.2 | 1 tuần |
| 8.4 | Smart Goal Suggestion | Rule-based, đọc lịch sử | 1–2 tuần |
| 8.5 | HealthKit/Health Connect | Client-only | 2–3 tuần |

**Song song:** 8.5 độc lập, có thể làm bất kỳ lúc nào sau Phase 2 (đã xong).
**Exit:** % user xem Insight/tuần đo được.

### Phase 9 — Retention & Light Social (tháng 4–6)

| # | Feature | Extension point | Effort |
|---|---|---|---|
| 9.1 | Family/Shared Meal | `households` collection + `firestore.rules` | 3 tuần |
| 9.2 | Challenge & Streak | Local SQLite + feature flag | 2 tuần |
| 9.3 | Coach View (read-only) | Firebase Hosting + role-scoped Function | 2–3 tuần |
| 9.4 | Widget + Live Activity | WidgetKit/Glance đọc SQLite | 2 tuần |
| 9.5 | Smart Reminder | Local notification | 1 tuần |

**Exit:** DAU/MAU + streak length đo được.

### Phase 10 — Differentiation & Advanced AI (tháng 6–9)

| # | Feature | Extension point | Effort |
|---|---|---|---|
| 10.1 | Eat This Instead | Nutrient-distance query trên `fkb_foods` | 1.5 tuần |
| 10.2 | Allergy/Restriction Guard | `fkb_foods.tags[]` + `matchFood` rule | 1.5 tuần |
| 10.3 | 7-day Meal Plan cá nhân hóa | Mở rộng `generateMealPlan` đã có | 1.5 tuần |
| 10.4 | Recipe Reverse | `aiComplete` prompt mới | 3 tuần |
| 10.5 | On-device Vision (light) | TFLite/CoreML — **chỉ làm nếu 7.1 không đạt target** | 5–8 tuần |

**Gate:** 10.5 không tự động vào roadmap — cần số liệu latency/cost từ Phase 7
chứng minh cần trước khi duyệt.

---

## 5. Rủi ro & Mitigation (giữ ý gốc, thêm 1 rủi ro kiến trúc)

| Rủi ro | Mitigation |
|--------|------------|
| Multi-food accuracy thấp với món Việt | Thu thập data riêng + feedback loop qua `validation_logs` (đã có từ Phase 3C) |
| Serving estimation sai nhiều | Quick Adjust bắt buộc + học từ `user_edited` diff |
| AI cost tăng khi thêm Insight/Recipe | Daily uid cap đã có (`enforceDailyRateLimit`) + Remote Config model tier (`MASTER_PLAN.md` § 12.3) |
| Privacy (HealthKit) | Chỉ dùng data để tính remaining calories/insight, không bán dữ liệu |
| Scope creep | Giữ Phase 7 chặt, chỉ mở Phase 8 khi Phase 7 đạt metric |
| **Xây hạ tầng trước khi cần** (rủi ro riêng của bản gốc) | Mọi feature "AI/ML nặng" (multi-food detection, on-device vision) bắt đầu bằng cách mở rộng `aiComplete`; chỉ tách service khi đo được nghẽn thật (`MASTER_PLAN.md` § 9.3) |

## 6. Định nghĩa Done cho mỗi feature

Giữ checklist gốc + checklist `CLAUDE.md` § 9:
- [ ] Feature Flag (default OFF, qua Remote Config như `fkb_matcher_enabled`)
- [ ] `flutter analyze` clean, test cho critical path
- [ ] Analytics events đầy đủ
- [ ] Không vi phạm Canonical Food rule — không hiển thị AI value là `verified`
- [ ] Offline behavior định nghĩa rõ (theo bảng `MASTER_PLAN.md` § 4.5)
- [ ] String mới có localization (tối thiểu English)
- [ ] Không secret nào vào Flutter tree

## 7. Next Action

1. Chốt Phase 7 (không cần review model Vision — dùng ngay `aiComplete` hiện có).
2. Viết contract chi tiết cho response schema multi-food (mở rộng `matchFood`/
   scan JSON schema đang có ở Phase 1C).
3. Đo baseline Scan Success Rate + Time-to-log hiện tại trước khi bắt đầu 7.1,
   để có số so sánh.

---

**Tài liệu sống.** Khi bắt đầu từng Phase, tách thành mục trong `plan.md` theo
đúng format Phase 0–6 đã có (Purpose/Depends on/Work items/Verify/Definition of
done).
