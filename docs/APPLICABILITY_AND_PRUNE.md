# Bộ tài liệu Evolution Plan — Có áp dụng được cho NutriScan hiện tại không?

**Ngày đánh giá:** 2026-08-05  
**Đối chiếu với:** code Flutter + Firebase thực tế + `MASTER_PLAN.md` + `plan.md` đã chốt  

---

## 1. Kết luận ngắn

| Câu hỏi | Trả lời |
|---------|---------|
| Có **ý tưởng** dùng được không? | **Có** — rất nhiều (Canonical Food, AI Gateway, verified nutrition, checklist Store, personas) |
| Có **áp nguyên xi** toàn bộ 45+ file / 20 sprint / NestJS+Postgres+K8s không? | **Không** — lệch stack và scope so với app đang chạy |
| Nên làm gì? | **Giữ tinh thần + ADR cốt lõi**, **bỏ / hoãn** lớp enterprise nặng, **map** về Firebase + Flutter hiện tại, tiếp tục build theo phase FKB |

**Quyết định vận hành:**  
Tiếp tục build app trên **Flutter + Firebase (Functions, Firestore/Auth/Storage) + Groq**.  
Canonical Food / Nutrition Engine / AI Gateway là **hướng đúng**, nhưng triển khai **gọn trên stack hiện có**, không rewrite backend sang NestJS ngay.

---

## 2. Stack thực tế vs stack trong tài liệu mới

| Hạng mục | App NutriScan **đang có** | Bộ docs Evolution Plan **giả định** | Khuyến nghị |
|----------|---------------------------|-------------------------------------|-------------|
| Mobile | Flutter + **Provider** + SQLite | Flutter + **Riverpod** + **Drift** | Giữ Flutter; Riverpod/Drift **tùy chọn sau**, không bắt buộc Phase 1 |
| Backend | **Firebase Cloud Functions** | **NestJS** + API Gateway riêng | **Giữ Functions**; AI Gateway = module trong Functions / 1 service nhỏ |
| Primary DB | Firestore (user) + SQLite (local) | **PostgreSQL 16** + Prisma | FKB có thể bắt đầu **Firestore**; Postgres chỉ khi search/scale đau |
| Queue | Không / nhẹ | **BullMQ + Redis** | Hoãn; Cloud Tasks khi cần batch import/MAPE |
| Admin | Không | **Next.js** full admin | Hoãn EPIC-07; curation bằng sheet/script trước |
| Infra | Firebase managed | Docker Compose → K8s | Hoãn EPIC-02 heavy; dùng Firebase + secret manager |
| AI | `groqChatCompletion` callable | Full Intent→Router→Memory→LiteLLM | **Mở rộng dần** callable hiện có (prompt version, cost log, fallback) |
| Monetization | Coins + IAP + Ads (đã có) | RevenueCat / Stripe (docs) | **Giữ** hệ hiện tại |

Tài liệu Evolution Plan mô tả **target 12–36 tháng / enterprise**.  
App của bạn cần **ship feature dinh dưỡng tin cậy trên nền đã có** trong vài tháng tới.

---

## 3. Phần **NÊN GIỮ** (áp dụng ngay / gần)

### 3.1 Product & nguyên tắc (giữ nguyên tinh thần)

| File / ý | Lý do giữ |
|----------|-----------|
| `vision.md` | Khớp hướng Personal Nutrition + tin cậy |
| `personas.md` (Minh, Lan, Hương) | Dùng khi ưu tiên UX scan / macro |
| `metrics_and_kpis.md` (North Star, retention, scan success) | Có thể đơn giản hóa số liệu |
| **ADR-0002 Flutter** | Khớp code + quyết định trước |
| **ADR-0003 AI Gateway** | Đúng hướng; implement gọn trên Functions |
| **ADR-0004 Canonical Food source of truth** | **Cốt lõi** — trùng MASTER_PLAN (verified vs estimated) |
| `04_nutrition_engine.md` nguyên tắc vàng | “AI không invent nutrition” → bắt buộc |
| Schema ý tưởng Canonical Food | Map sang Firestore/`fkb_foods` hoặc Prisma sau |
| Production / Release / Security **checklist rút gọn** | Store + delete account + restore IAP |
| Runbook ý tưởng (AI outage, high error) | Viết lại ngắn cho Firebase/Groq |

### 3.2 Khớp với `MASTER_PLAN.md` / `plan.md` đã viết

- Scan đã full → mở rộng **FKB + matcher + source badge**
- USDA + VN FCT làm ground truth
- MAPE / golden set
- Apple: delete account, restore, disclaimer
- Không rewrite Flutter

→ **Đây vẫn là đường build chính.**

---

## 4. Phần **CẦN SỬA** trước khi dùng

| Nội dung trong docs mới | Vấn đề | Cách sửa cho dự án này |
|-------------------------|--------|-------------------------|
| Architecture “Mobile → NestJS → Postgres → Redis” | Không phải runtime hiện tại | Vẽ lại: Flutter → Firebase Callable → Functions (AI + FKB) → Firestore/USDA |
| Riverpod + Drift bắt buộc Sprint 02 | App đang Provider + sqflite | “Củng cố repository”; migrate Riverpod/Drift **không** chặn FKB |
| EPIC-01 = 6–8 sprint foundation trước mọi thứ | Quá lâu trước khi có verified nutrition | **Song song**: foundation tối thiểu + FKB Phase 1 |
| EPIC-02 Docker/K8s | Firebase đã cover deploy | Hoãn đến khi rời Firebase hoặc worker nặng |
| EPIC-07 Admin full | Chưa cần non-engineer duyệt food tuần 1 | CSV/script + Firestore console trước |
| 50.000 foods ngay | Nặng cho MVP | Seed **1k–5k** USDA + món VN hot; scale dần |
| Sprint 01–20 như critical path cứng | Lịch enterprise | Rút **Phase build app** ~ Phase 0–5 trong `plan.md` |
| “Clinical / enterprise Q4 2027” | Dễ overclaim | Giữ non-goal: không claim clinical-grade sớm |
| Current state “React Native?” trong 20_PLAN | Sai thực tế | Chỉ **Flutter** |

---

## 5. Phần **LOẠI / HOÃN** (không làm lúc này)

| Hạng mục | Lý do hoãn |
|----------|------------|
| Kubernetes, Docker Compose prod full, Nginx cluster | Firebase managed đủ giai đoạn đầu |
| BullMQ + Redis bắt buộc | Chưa có worker volume |
| ClickHouse / BigQuery analytics pipeline | Amplitude/Firebase Analytics đủ sớm |
| Next.js Admin hoàn chỉnh (EPIC-07 full) | Sau khi FKB + matcher ổn |
| Temporal, gRPC service mesh | Overkill |
| On-device YOLO / full Vision Platform multi-food (EPIC-06 full) | Giữ single-food scan AI hiện tại; multi-food sau |
| EPIC-10 Growth (referral, achievements…) | Sau khi verified scan ổn định |
| Self-hosted LLM | Không năm 1 |
| Certificate Pinning + full EPIC-09 ngay Sprint 17 | Làm **subset**: delete account, secrets, rate limit; pinning khi gần store lớn |
| Đổi toàn bộ sang NestJS trước khi có FKB | Chặn shipping; không làm |

---

## 6. Bản đồ “Docs mới → Việc thực tế trên NutriScan”

| Ý docs mới | Việc cụ thể trên repo hiện tại |
|------------|--------------------------------|
| Canonical Food | Collection `fkb_foods` (hoặc Postgres sau) + import USDA/VN |
| AI không invent macro | Sau `analyzeFoodImage`: `matchFood` → override macros nếu verified |
| AI Gateway | Mở rộng `groqChatCompletion` → `aiComplete` (model, prompt_version, cost log, optional fallback) |
| Nutrition Calculator | Hàm `per_100g * grams/100` server hoặc client khi verified |
| Offline meals | Giữ/ mở rộng SQLite history (đã có); sync cloud sau |
| Observability | Crashlytics đã có; thêm structured log + Sentry optional trên Functions |
| Feature flag | Firebase Remote Config (matcher on/off, model id, sample rate) |
| Production gate | Checklist rút từ Store + crash-free + không path invent nutrition |

**Không** bắt đầu bằng “Sprint 01 Observability 2 tuần rồi mới đụng food” nếu mục tiêu là app dinh dưỡng có kho kiểm chứng — làm **tối thiểu quan sát** song song **FKB Phase 1**.

---

## 7. Lộ trình build **đã prune** (thay cho 20 sprint enterprise)

Bám `plan.md` + tinh thần docs mới:

| Phase | Việc | Lấy từ docs mới | Bỏ |
|-------|------|-----------------|-----|
| **0** | Chốt stack Firebase+Flutter; USDA key | ADR-0002, 0004 | Nest rewrite |
| **1** | FKB seed + search/get + match sau scan + badge | EPIC-05 ý, schema rút gọn, ADR-0004 | 50k foods, Admin full |
| **2** | Log `source` / `portion_grams` / migration SQLite | Nutrition engine rules | Drift bắt buộc |
| **3** | Golden set + MAPE | Technical KPI nutrition_calorie_mape | CI gate nặng nếu chưa có |
| **4** | Plan/coach ground context | AI platform subset | Intent detector đầy đủ |
| **5** | Delete account, restore IAP, disclaimer, Remote Config | EPIC-09 subset, release checklist | Pinning + full OWASP ngay |
| **6** | Curation unmatched, coverage VN | Verification workflow nhẹ | Next.js Admin |

Foundation (logging, secrets, flavors) = **checklist chạy ngầm**, không thành epic 2 tháng chặn product.

---

## 8. Cấu trúc docs **nên giữ trong repo** (gọn)

```
docs/
  MASTER_PLAN.md              # đã có — spine
  plan.md                     # đã có — phase + verify agent
  APPLICABILITY_AND_PRUNE.md  # file này

  product/
    vision.md                 # giữ (rút non-goal clinical)
    personas.md               # giữ

  adr/
    0001-record-architecture-decisions.md
    0002-mobile-framework-flutter.md
    0003-ai-gateway-approach.md      # sửa: implement on Cloud Functions
    0004-canonical-food-source-of-truth.md

  architecture/
    nutrition_engine.md       # rút từ 04 — nguyên tắc + flow match
    ai_gateway.md             # rút từ 03 — gateway trên Functions

  data/
    schema_fkb.md             # schema Firestore/FKB thực tế (không bắt buộc Prisma ngay)

  checklists/
    production_readiness_lite.md   # 15–25 item, không 59 item ngay
    release_store.md               # Apple/Play subset

  # HOÃN (không copy vào critical path)
  # epics 02,07,08 full / sprints 01-20 enterprise / infra k8s / admin next
```

Các file EPIC-02, 07, 08, 10, sprint 01–20 overview, infrastructure K8s, queue-backup Redis… giữ trong **archive/reference** nếu muốn, **không** coi là backlog bắt buộc tuần này.

---

## 9. ADR cần chỉnh một dòng (ý)

**ADR-0003 (AI Gateway):**  
Decision giữ; **implementation** = Cloud Functions module + Remote Config model list, không yêu cầu NestJS service tách ngay.

**ADR-0004 (Canonical Food):**  
Giữ nguyên — đây là quyết định quan trọng nhất của bộ docs mới và khớp mục tiêu “kho dữ liệu kiểm chứng”.

**Không chấp nhận** ngầm định Postgres + Nest là điều kiện tiên quyết để bắt đầu FKB.

---

## 10. Việc **tiếp theo để build app** (ưu tiên)

1. **Không** dừng để implement đủ 59-item production checklist trước.  
2. Bắt đầu **Phase 1A** trong `plan.md`: schema `fkb_foods` + import USDA seed.  
3. **Phase 1B–1C**: callable search/match → gắn vào `FoodProvider.analyzeFoodImage`.  
4. Song song nhẹ: Remote Config flag `fkb_matcher_enabled`, không log PII.  
5. Chỉ kéo Nest/Postgres/Admin khi FKB + matcher đã chứng minh value trên staging.

---

## 11. Tóm tắt một câu

Bộ tài liệu Evolution Plan **đúng hướng chiến lược** (Canonical Food, AI có kiểm soát, production discipline) nhưng **quá nặng và lệch stack** so với NutriScan Flutter+Firebase hiện tại — **áp dụng có chọn lọc**: giữ vision/ADR-0004/nutrition rules/checklist Store; **cắt** Nest/K8s/Admin/20-sprint foundation; **build tiếp** theo `plan.md` Phase 1 (FKB + match + badge).

---

*File này là cầu nối giữa bộ docs 2026-08-05 và quyết định triển khai thực tế trên codebase NutriScan.*
