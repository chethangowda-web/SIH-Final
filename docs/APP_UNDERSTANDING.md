# PDS DemandSync — App Understanding

> Self-prepared technical understanding of this repo (`D:\SIH FINAL`), synthesized from source reads of `backend/` + `frontend/` + root docs.
> SIH 2026 prototype: pre-dispatch demand intelligence layer for India's PDS.

---

## 1. What this app is (and is not)

**Problem:** Under ONORC portability, 800M+ beneficiaries can lift grain at *any* FPS, but godown→FPS dispatch is planned weeks ahead from *static* quotas. Result: stockouts in migrant/industrial hubs, idle/surplus stock elsewhere.

**Solution:** A voluntary, non-binding **forward intent signal** collected in a time-boxed **Choice Window (Days 21–24)**, frozen on **Day 25 Demand Lock (SHA-256 sealed)**, then run through a deterministic pipeline before trucks move:

```
Intent (21–24) → Demand Lock (25) → Forecast → Constraint audit
  → Scarcity fair-share (if deficit) → Route optimization
  → Manifest lock + gatepass → Dispatch → ePoS actuals → Evaluation/MAPE → Recalibration
```

**Explicit non-goals (per `MASTER_PROJECT_SPEC.md`):**
- Not an entitlement change, not an FPS lock, not an ONORC replacement — citizen can still lift anywhere.
- ML is advisory only; deterministic statutory rules gate dispatch; DSO authorizes.
- Zero real PII/Aadhaar/biometrics. All demo data synthetic (`BEN-KA-*`, `RC-KA-*`). Biometric/GPS/WhatsApp are simulated.

**Core formula (`forecast_engine.py`):**
`raw = (1 − α)·H + α·I`, where `α = w·C`, `w = INTENT_WEIGHT (0.65)`, `H` = historical avg, `I` = locked intent, `C` = confidence; then `target = raw·(1+0.05 buffer)`, `dispatch = min(target − inventory, capacity − inventory)`.

**9 statutory invariants (`constraint_engine.py`):** depot non-negativity, FPS capacity ceiling, 10,000 kg truck payload, 85% statutory floor, quota ceiling (PHH 5 kg/member, AAY 35 kg fixed), Day-25 freeze (HTTP 400), single receipt/cycle (HTTP 400), SHA-256 gatepass seal, append-only audit.

---

## 2. Tech stack & repo map

| Layer | Tech |
|---|---|
| Frontend | Flutter 3 / Dart (`frontend/`), Material3, `http`, `flutter_map` + `latlong2`, `intl`, `image_picker`, `crypto`, Firebase Auth |
| Backend | Python 3.11/3.12 + FastAPI + Uvicorn (`backend/app/`), Pydantic v2, pandas/numpy/scikit-learn, httpx, Twilio (mocked), python-dotenv |
| DB | SQLite WAL + FK, raw `sqlite3` (no ORM). Prod target per spec: Postgres+PostGIS (not implemented) |
| Deploy | Root `Dockerfile` (python:3.11-slim, pre-seeds DB at build) + `railway.json` (healthcheck `/health/live`). Serves Flutter web at `/app/` |

```
D:\SIH FINAL\
  backend/app/main.py          # FastAPI app, mounts /api + /api/v1 + / (aliases), serves Flutter at /app
  backend/app/api/             # 19 routers (~200 routes)
  backend/app/services/        # 22 engines (forecast, cycle, workflow, scarcity, VRP, manifest, ...)
  backend/app/core/            # config, database (migrations 001–016, ~40 tables), auth, logging
  backend/app/models/schemas.py# Pydantic I/O (~600 lines)
  backend/app/data/seed_data.py# CSV-driven seed (621 FPS / 10k beneficiaries / 63 depots / 311 trucks)
  backend/tests/               # 26 test files
  frontend/lib/main.dart       # MaterialApp(home: DemoLoginScreen), global 401 redirect
  frontend/lib/screens/        # beneficiary/ admin(24)/ dso(8)/ fps/ inspector/
  frontend/lib/services/api_service.dart # ~4150 lines, ~150+ API methods
  frontend/lib/models/         # 9 model files
  frontend/lib/core/           # constants, localization (en/hi/kn), responsive
  docs/                        # architecture, manuals, audit reports
```

---

## 3. Backend understanding

### 3.1 Entrypoint & config
- `app/main.py:app` + `backend/server.py` prod launcher. Lifespan: `validate_production_config()` → `init_db()` (best-effort). Middleware: `CorrelationIdMiddleware`, security headers, CORS.
- `core/config.py`: `PROJECT_NAME="PDS DemandSync"`, `VERSION="1.0.0-demo-v1"`, `API_V1_PREFIX="/api"`, `DB_PATH=<backend>/pds_demandsync.db`, `CURRENT_CYCLE="2026-09"`, `NEXT_CYCLE="2026-10"`, `INTENT_WEIGHT=0.65`, `SAFETY_BUFFER_PCT=0.05`, `OTP_MODE="demo"`, `SMS_ENABLED=False`.
- Routers mounted 3× (canonical `/api`, hidden `/api/v1`, hidden `/`); public `GET /api/choice-window/status`; `GET /` returns service directory.

### 3.2 Database & seed scale
- `core/database.py` migrations `_001`–`_016`, ~40 tables: `fps, depots, vehicles, routes, beneficiaries, beneficiary_auth, intent, historical_demand, inventory, forecast, dispatch, actual_distribution, forecast_evaluation, model_calibration, manifests, manifest_audit_logs, gatepasses, truck_telemetry, truck_route_tracking, notifications, constraint_logs, users, refresh_tokens, cycle_workflow_states, workflow_audit_logs, governance_audit_logs, demand_snapshots, planning_cycle_config, citizen_requests, entitlement_policies, delivery_disputes, beneficiary_cycle_receipts, feedback, depot_stock_cycles, stockout_risk_predictions, scarcity_allocation_plans/items, dso_* , fps_inspections, surprise_inspection_orders, epos_transactions, household_members, smart_grain_atm`, etc.
- `data/seed_data.py` (CSVs in `backend/data/csv/`): **621 FPS across 31 Karnataka districts, 10,000 beneficiaries, 63 godowns→depots (DEPOT-01 Hebbal guaranteed), 311 trucks, 22,321 historical rows (12 mo), 10,000 intents for 2026-10**; inventory 10–60% capacity (72/28 rice/wheat); intra-district godown→FPS routes; resets `demand_snapshots` + `planning_cycle_config` for active cycle.

### 3.3 Auth, RBAC, cycle state
- `core/auth.py`: HMAC-SHA256 `payload.signature` tokens (10h TTL), salted SHA-256 passwords, `OAuth2PasswordBearer`. Seeded users: `admin/dso/field_officer/inspector/fps/auditor` + beneficiary logins. `PDS_TEST_AUTH_MOCK=1` bypass (prod-disabled).
- `check_admin_access` matrix: `/admin/demo/reset` ADMIN-only; gatepass writes FIELD_OFFICER/DSO/ADMIN; most writes DSO/ADMIN; reads DSO/ADMIN/AUDITOR/FIELD_OFFICER; `verify_owner` pins BENEFICIARY to own id. `dashboard.py` additionally `RoleChecker(DSO,ADMIN,AUDITOR)`.
- `planning_cycle_engine.py`: `START_DAY=21, END_DAY=24, LOCK_DAY=25`; closing freezes `demand_snapshots` + canonical hash; post-lock intent mutations → 400.
- `workflow_manager.py`: `FORECASTED→VALIDATED→ALLOCATED→OPTIMIZED→MANIFEST_DRAFT→MANIFEST_LOCKED→GATEPASS_READY→DISPATCHED→VERIFIED→EVALUATED→CYCLE_CLOSED` with guarded transitions.

### 3.4 API surface (grouped)
- **System:** `GET /health, /health/live, /health/ready, /health/status, /admin/operations/status`; `GET /api/choice-window/status` (public).
- **Auth (`api/auth.py`):** `POST /auth/login|/auth/token`, `POST /auth/citizen/send-otp|verify-otp`, `GET /auth/citizen/search|household-phones|firebase-login`, `POST /auth/refresh|logout`, `GET /auth/me`.
- **Masters:** `GET /beneficiaries, /beneficiaries/{id}`; `GET /fps, /fps/{id}` (+ `/officer/…` twins).
- **Intent/citizen (`api/intent.py`):** `POST /intent`, `GET /intents`, `POST /intent/simulate-channel`, `GET /beneficiary/{id}/entitlement-summary|delivery-records`, `POST /beneficiary/{id}/confirm-delivery`.
- **Stock:** `GET /historical-demand/{fps_id}, /inventory/{fps_id}`; `GET /dashboard/summary`.
- **Scarcity (`/admin/scarcity/*`):** `depot-balance`, `predict-risk`, `simulate-fair-share`, `approve-plan`, `audit-trail/{plan_id}`.
- **Anomaly/routing:** `GET /anomaly/scan|summary`; `/routing/optimize|gis-heatmap|verify-arrival|tracking/active|tracking/{truck}|tracking/{truck}/{advance,report-delay,report-deviation,confirm-arrival,confirm-delivery}`.
- **Ops:** `/import/fps-csv|beneficiaries-csv`, `GET /reports/allocation-order`, `/feedback/submit|list|{ticket}/resolve|escalation/*`, `POST /twilio-webhook`, `GET /tts/speak`.
- **Grain ATM (`/grain-atm/*`):** `status|network-summary|{atm_id}|verify|dispense`.
- **Officer/FPS/ePoS/inspector (`api/officer.py`):** inspection order flow + session/evidence/sealed-report; FPS open/close, consignments, confirm-receipt, discrepancy; `epos/verify-beneficiary|dispense|eligibility`; inspector dashboard/targets/ai-insights/exceptions/decision-trace + geofence.
- **Auditor (`api/auditor.py`, dual aliases):** overview/cycles/assignments; audit lifecycle `audits/{id}/{records,verify-records,reconciliation,inspections,exceptions,findings,generate-report,finalize-report,close}`; `trace/{entity}/{id}`, `ai/{insights,anomalies,recommendations}`.
- **Admin (`api/admin.py`, ~90 routes):** `fps/{id}/override`, `stock-headroom-check`, `dashboard`, `fps/{id}[ /analytics|forecast|dispatch-decision]`, `forecast/generate|lock`, `choice-window/close`, `planning-cycle/{demand-snapshot,set-day}`, `dispatch/generate|manifest(s)`, `distribution/simulate|records`, `evaluation[ /cycle/{id}]`, `calibrate`, `constraints/validate|fps/{id}|resolve|revalidate`, `optimization/run|corridor/{truck}|what-if`, `manifests/{generate,update,lock,revise,verify-seal}`, `gatepasses|gatepass/{truck}|gatepass/{id}/advance`, `notifications/dispatch|logs`, `dispatch/delay|resume|send-delay-alert`, `workflow/{status,transition,closure-checklist,close-cycle}`, `governance/trail|governance-events`, `database/integrity|backup`, `command-center`, `system-impact`, `demo/scenarios|scenario/run|reset`, `citizen-requests[ /{id}/authorize]`, `delivery-disputes[ /{id}/resolve]`, `causal-trace*|simulate-shift`, full `dso/*` console, `judge-view`.

### 3.5 Service engines (what each does)
| Service | Role |
|---|---|
| `forecast_engine.ForecastEngine` | Intent-history blend + buffer + risk tier |
| `planning_cycle_engine` | 21–24 open / 25 lock + snapshot hash |
| `workflow_manager` | 11-state pipeline guard |
| `stockout_risk_engine` | LogisticRegression burn-rate risk tiers |
| `scarcity_engine` | FAIR_SHARE / PRO_RATA / FLOOR_PRIORITY plans |
| `ai_request_advisor` | Advisory APPROVE/PARTIAL/REDIRECT/DEFER + fee |
| `dispatch_engine` / `dispatch_decision_engine` | FPS→truck/godown mapping; `recommended = forecast+buffer−stock` |
| `optimization_engine` / `vrp_solver` | Haversine×1.25 corridor clustering + VRP |
| `constraint_engine` | Capacity/stock/policy → `constraint_logs` |
| `manifest_engine` / `gatepass_engine` | Build/lock/revise + seal; ISSUED→VERIFIED→LOADED→DISPATCHED |
| `evaluation_engine` | MAE/MAPE + `model_calibration` re-tune |
| `causal_trace_engine` | Intent→receipt lineage + shift sim |
| `anomaly_engine` | Spike/duplicate fraud flags |
| `governance_trail` | Append-only audit logs |
| `notification_engine` / `sms_provider` | Fast2SMS/MSG91/Demo/Twilio, masked phones |
| `truck_tracking_service` | ETA/checkpoints/delays |
| `grain_atm_service` | ATM verify/dispense vs entitlement |
| `demo_scenario_engine` | Canned judge-demo scenarios |

---

## 4. Frontend understanding

### 4.1 Entry, routing, config
- `lib/main.dart`: `MaterialApp(navigatorKey: rootNavigatorKey, home: DemoLoginScreen)`; imperative `Navigator.push` only (no go_router); global 401 → back to login.
- `core/constants.dart:AppConstants`: prod default `http://10.20.16.9:8000/api`; web uses `origin/api` when hosted, else localhost:8000; `apiTimeout=35s`; navy GovTech theme (`primaryNavy 0xFF0B2942`), 8-stage `workflowSteps`.
- Theme: Material3, Inter, navy AppBar, white cards (r=12), navy buttons (r=8).

### 4.2 Login & roles (`screens/beneficiary/demo_login_screen.dart`, ~2170 lines)
Single chooser → Citizen OTP tab vs Department tab.
- **Citizen:** `card_id + phone` → `validateHouseholdCredentials` → `sendCitizenOtp` (300s timer, demo `123456` autofill) → `verifyCitizenOtp` → `AuthSession(BENEFICIARY)`. Helpers: household phones, search, Firebase bridge.
- **Official:** `username/password` → `POST /auth/login` → token+role → route to Admin / DSO / Inspector / FPS / Auditor centers. Presets: `admin_user, dso_user, field_officer_user, auditor_user`.
- Demo creds: officials `*_user/*_pass` (`admin_pass`); citizens `RC-KA-000001…010000` / `BEN-KA-*`, OTP `123456`.

### 4.3 Citizen journey
1. `beneficiary_home_screen.dart` (~3280 lines): entitlement card (non-editable `members×5kg`), language bar, FPS-free vs Home-delivery (`₹87.50 = Base ₹20+distance`), timeline, map (`flutter_map`), ETA timer, confirm/dispute, feedback, voice hooks.
2. `intent_selection_screen.dart` (~1510 lines): mode → FPS search (`Home FPS` / `PORTABILITY SHIFT` tags) + map → (home only) address/fee → statutory summary with over-quota guard.
3. `intent_confirmation_screen.dart` (~920 lines): review → `submitSingleIntent/submitIntent` → QR receipt ("DSO aggregating…"); cycle-received guard blocks resubmit.
4. `intent_history_screen.dart`: chronological intents; home shows `REQUESTED→ALLOCATED→OUT_FOR_DELIVERY→DELIVERED→CONFIRMED`, delay banner (`STOCK_DELAYED, 1–2 days`, no-resubmit).
5. `grain_atm/`: welcome → verify (RationID/Aadhaar-demo/OTP) → dispense (`VM-001`) → receipt; `RATION ALREADY RECEIVED` guard.

### 4.4 Officer journeys
- **Admin (`screens/admin/`, 24 files):** master dashboard (lock/forecast/dispatch/GIS/eval); FPS detail; auditor vigilance center; causal-trace; citizen-request/dispute queue; 9-rule constraints; gatepass (SHA-256, 4-stage); TSP what-if; escalation clusters; FPS dispatch-decision; FPS forecast (`D̂` + what-if); pre-dispatch inspector; incident detail; judge defense view; manifest manager (+ canvas route map); 4-stage pre-dispatch runner; readiness alerts; scarcity fair-share (deficit/fair-share/authorize); SIH demo scenarios; system health.
- **DSO (`screens/dso/`, 8 files):** `dso_command_center_screen` (workflow-first, `PLANNING_OPEN→CYCLE_CLOSED`, cycle 2026-09, ring + action bar + metrics + trace + exceptions + timeline + AI) + legacy validate/allocation/optimization/dispatch/delivery/monitor/evaluation views.
- **FPS (`screens/fps/fps_command_center_screen.dart`, ~1560 lines):** 12-nav (Dashboard/Stock/Deliveries/e-PoS/Beneficiaries/Transactions/Reports/AI/Exceptions/Trace/Sources), default `FPS-KA-BLR-002`; e-PoS terminal (`BEN-KA-0001/123456`, biometric|OTP → eligibility→verify→dispense).
- **Inspector (`screens/inspector/`, 8-stage):** SelectTarget→Travel/Geofence→VerifyDelivery→6-PointInspection→Evidence→Review→Submit/Seal→SealedRecord; scale/moisture/CCTV/ePoS/hygiene + `image_picker` evidence.
- **Field officer / System admin:** gatepasses + active truck tracking; health view.

### 4.5 Client, models, UI kit
- `services/api_service.dart` (~4150 lines, ~150 methods): `AuthenticatedClient` (skip auth for login/health, pre-flight expiry, Bearer inject, 401→logout+redirect, 403→keep session); `parseError` → typed `ApiException(401/403/409/422/500)`; groups: OTP, beneficiary, admin workflow, DSO, pre-dispatch (constraints/optimization/gatepass/tracking/heatmap/inspection/alerts), command-center, scarcity, causal-trace, ePoS, auditor, GrainATM, demo/judge.
- `services/auth_session.dart`: token/role/`beneficiaryId`/35s-timeout… (36ks expiry), `isAdmin` set, broadcast stream. Plus `dso/fps/inspector/auditor/grain_atm/firebase/voice` services.
- `models/` (9 files): `beneficiary_model`, `admin_model` (~3720 lines), `health_model`, `grain_atm_model`, `auditor_model`, `scarcity_model`, `dso/dso_models` (workflow enum), `fps/fps_models`, `inspector/inspector_models`.
- `widgets/` (~38): `workflow_stepper, status_badge, delivery_timeline, metric_card, decision_formula_card, fee_breakdown_card, fps_detail_drawer, enterprise_dialog_scaffold, voice_pictorial_assist, whatsapp_ussd_simulator_dialog` + `dso/*, fps/*, inspector/*`.
- `core/localization.dart`: `AppLanguage(en/hi/kn)`, `LanguageController` + `tr(key,params)` (~400 keys); tricolor `ProminentLanguageBar`. Voice: `VoiceAssistantService` (elderly mode, per-screen guides) + audio helpers.

---

## 5. End-to-end flows

**Happy path:** Citizen OTP login → entitlement view → intent (FPS+window) → QR receipt → DSO dashboard aggregation → Day-25 lock → `forecast/generate` → `constraints/validate` → `optimization/run` → `dispatch/generate` → `manifests/lock` → gatepass advance → truck tracking → ePoS dispense → `confirm-delivery` → `distribution/simulate` → `evaluation` → `calibrate`.

**Deficit:** `scarcity/depot-balance` → `predict-risk` → `simulate-fair-share` → `approve-plan` → delay banner (`send-delay-alert`) → `dispatch/resume`.

**Dispute/inspection/ATM:** `feedback/submit → resolve`, `delivery-disputes → resolve`; officer inspection order → accept → verify-arrival → submit → sealed report; ATM verify → dispense → receipt (all receipt-guarded).

**Guards you’ll hit:** post-lock intent edit → 400; duplicate receipt → 400; over-quota intent → 422; expired token → 401 redirect.

---

## 6. Run & deploy

```bash
# backend
cd backend; python -m venv .venv; .venv\Scripts\activate
pip install -r requirements.txt
uvicorn app.main:app --reload --host 127.0.0.1 --port 8000
# docs: http://127.0.0.1:8000/docs | health: /api/health

# frontend
cd frontend; flutter pub get; flutter run -d chrome
```

Deploy: root Dockerfile builds + `init_db()` pre-seed, `CMD uvicorn app.main:app --host 0.0.0.0 --port $PORT`; railway healthcheck `/health/live`. Live: `/app/` (web), `/docs`, `/api/health`.

---

## 7. Key-file quick reference

Backend: `backend/app/main.py`, `app/core/{config,database,auth}.py`, `app/models/schemas.py`, `app/data/seed_data.py`, `app/api/{admin,officer,auditor,intent,auth}.py`, `app/services/{forecast_engine,planning_cycle_engine,workflow_manager,scarcity_engine,stockout_risk_engine,manifest_engine,gatepass_engine,evaluation_engine,causal_trace_engine}.py`.
Frontend: `frontend/lib/main.dart`, `lib/core/{constants,localization}.dart`, `lib/services/{api_service,auth_session}.dart`, `lib/screens/beneficiary/{demo_login_screen,beneficiary_home_screen,intent_selection_screen,intent_confirmation_screen}.dart`, `lib/screens/{admin/admin_dashboard_screen,dso/dso_command_center_screen,fps/fps_command_center_screen,inspector/inspector_command_center_screen}.dart`.
