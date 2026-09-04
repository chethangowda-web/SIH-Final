# PDS-PREDICT PROTOTYPE: ENGINEERING HANDOFF & SYSTEM BASELINE GUIDE

---

## 1. Executive Summary & Purpose
This document is the engineering handoff guide for the **PDS-PREDICT / PDS DemandSync** prototype (Baseline version `prototype-v0.1`). It explains the current codebase structure, operational procedures, test harnesses, architectural insights, and known limitations to enable seamless continuation of development.

---

## 2. System Status & Verification Baseline

| Verification Suite | Execution Command | Result | Pass Rate |
|---|---|---|:---:|
| **Backend Pytest Suite** | `.\.venv\Scripts\pytest` (in `backend/`) | **284 passed in 53.41s** | **100%** |
| **Flutter Static Analysis** | `flutter analyze` (in `frontend/`) | **No issues found (0 warnings/errors)** | **100%** |
| **Flutter Production Build** | `flutter build web` (in `frontend/`) | **Built `build\web` cleanly in 54.3s** | **100%** |

---

## 3. Operational URLs & Service Endpoints

- **Frontend Application (Web Portal):** `http://127.0.0.1:8080/`
- **Backend API Service:** `http://127.0.0.1:8000/`
- **Interactive OpenAPI Documentation (Swagger UI):** `http://127.0.0.1:8000/docs`
- **Alternative ReDoc API Documentation:** `http://127.0.0.1:8000/redoc`
- **Health Diagnostic Endpoint:** `http://127.0.0.1:8000/health`
- **Public Planning Cycle Status:** `http://127.0.0.1:8000/choice-window/status?cycle_id=2026-09`

---

## 4. Demo User Personas & Credentials

The system seeds representative demo accounts for immediate testing without manual user setup:

### 4.1 Citizen Beneficiary Personas (Password: `demo123`)
1. **Swathi Bhat (`BEN-KA-0001`):**
   - *Role:* Priority Household (PHH) Cardholder (4 members $\to$ 20 kg monthly quota).
   - *Home FPS:* Malleshwaram Seva Kendra (`FPS-KA-BLR-001`).
   - *Use Case:* Standard self-collection at home Fair Price Shop.
2. **Sunita Devi (`BEN-KA-0005`):**
   - *Role:* Migrant Construction Worker exercising ONORC portability (5 members $\to$ 25 kg quota).
   - *Home FPS:* Hosakote Rural FPS $\to$ Portability target: Peenya Industrial (`FPS-KA-BLR-004`).
   - *Use Case:* Interstate/inter-district portability surge signal.
3. **Ramesh Kumar (`BEN-KA-0015`):**
   - *Role:* Elderly PHH Cardholder requesting assisted doorstep delivery (3 members $\to$ 15 kg quota).
   - *Home FPS:* Jayanagar Community Depot (`FPS-KA-BLR-003`).
   - *Use Case:* Assisted doorstep delivery with distance surcharge fee audit.

### 4.2 Institutional / Administrative Personas (Password: `admin123` or `demo123`)
1. **District Supply Officer (DSO):** Username `dso_admin` / Role `DISTRICT_SUPPLY_OFFICER`
   - Holds administrative authority over cycle day advancement, Day 25 Demand Lock, review queue approvals, and dispatch authorization.
2. **Depot Manager:** Username `depot_manager` / Role `DEPOT_MANAGER`
   - Authority over warehouse inventory, truck gatepass scanning, and physical dispatch logging.

---

## 5. Startup, Reset, and Execution Commands

### 5.1 Starting the Backend Service
```powershell
cd e:\rationcard\backend
.\.venv\Scripts\Activate.ps1
uvicorn app.main:app --host 127.0.0.1 --port 8000 --reload
```

### 5.2 Starting the Frontend Application
```powershell
cd e:\rationcard\frontend
flutter run -d web-server --web-port 8080 --web-hostname 127.0.0.1
```

### 5.3 Database Re-seed / Clean Reset Command
To reset the SQLite database to the canonical benchmark state:
```powershell
cd e:\rationcard\backend
.\.venv\Scripts\python -c "from app.core.database import recreate_db; from app.data.seed_data import seed_all_data; recreate_db(); seed_all_data(recreate=True); print('Database successfully reset and seeded.')"
```

### 5.4 Running Test Harnesses
```powershell
# Complete backend test suite (284 tests)
cd e:\rationcard\backend
.\.venv\Scripts\pytest

# Specific test suites
.\.venv\Scripts\pytest tests\test_ration_receipt_rule.py
.\.venv\Scripts\pytest tests\test_choice_window_flow.py
.\.venv\Scripts\pytest tests\test_citizen_request_workflow.py

# Flutter analysis
cd e:\rationcard\frontend
flutter analyze
```

---

## 6. Repository Map: Where Critical Code Resides

```
e:\rationcard\
├── MASTER_PROJECT_SPEC.md              <- Canonical System Specification (SSOT)
├── PDS_DemandSync_College_Demo...md    <- Presentation Script & Pitch Deck Guide
├── docs\
│   ├── CURRENT_PROTOTYPE_HANDOFF.md    <- This Handoff Guide
│   ├── ARCHITECTURE.md                 <- Technical Architectural Overview
│   ├── DEMO_WALKTHROUGH.md             <- Step-by-Step Scenario Demonstration Guide
│   └── PDS_DEMANDSYNC_FUNCTIONAL...    <- Institutional Functional Specification
├── backend\
│   ├── app\
│   │   ├── main.py                     <- FastAPI Lifespan, CORS, Public APIs
│   │   ├── api\
│   │   │   ├── admin.py                <- DSO Dashboard, Demand Lock, Pipeline, Review Queue
│   │   │   ├── intent.py               <- Citizen Intent Submission, Entitlement, Receipt Rule
│   │   │   ├── auth.py                 <- JWT Token Issuance & Role Verification
│   │   │   ├── scarcity.py             <- Fair-Share Scarcity Allocation Endpoints
│   │   │   ├── beneficiaries.py        <- Cardholder Registry & Metadata
│   │   │   └── fps.py                  <- Fair Price Shop Queries & Inventory
│   │   ├── core\
│   │   │   ├── database.py             <- Migrations 001-006, WAL Config, Integrity Checks
│   │   │   ├── config.py               <- Pydantic BaseSettings, Ports, Environment
│   │   │   └── auth.py                 <- JWT Token Decoder, RBAC Role Guards
│   │   ├── models\
│   │   │   └── schemas.py              <- Pydantic In/Out Contracts
│   │   ├── services\
│   │   │   ├── planning_cycle_engine.py<- Day 21-24 Choice Window, Day 25 Demand Lock Engine
│   │   │   ├── forecast_engine.py      <- Multi-Factor Composite Demand Formulation
│   │   │   ├── constraint_engine.py    <- 9 Statutory Invariants Enforcement
│   │   │   ├── optimization_engine.py  <- TSP Capacitated Corridor Fleet Optimization
│   │   │   ├── dispatch_engine.py      <- Manifest Generation & SHA-256 Gatepass Signer
│   │   │   ├── scarcity_engine.py      <- Fair-Share Deficit Proportional Rationing
│   │   │   ├── ai_request_advisor.py   <- Entitlement Derivation ($N x 5kg$) & AI Assessment
│   │   │   └── governance_trail.py     <- Append-Only Audit Trail Service
│   │   └── data\
│   │       └── seed_data.py            <- Synthetic Benchmark Dataset (20 FPS, 2000 Citizens)
│   └── tests\                          <- 16 Comprehensive Pytest Files (284 Tests)
└── frontend\
    ├── lib\
    │   ├── main.dart                   <- Flutter Entrypoint & App Shell
    │   ├── core\
    │   │   ├── app_constants.dart      <- Palette, Typography, Dimens, API Base URL
    │   │   └── localization.dart       <- Trilingual Dictionary (EN, HI, KN)
    │   ├── models\
    │   │   ├── beneficiary_model.dart  <- Card Entitlement, Orders, Receipts Data Models
    │   │   └── admin_model.dart        <- KPIs, FPS Matrix, Pipeline State Models
    │   ├── services\
    │   │   └── api_service.dart        <- HTTP Client, Error Interceptor, Cache
    │   └── screens\
    │       ├── beneficiary\
    │       │   ├── beneficiary_home_screen.dart    <- Main Citizen Hub & Receipt Banner
    │       │   ├── intent_selection_screen.dart    <- 4-Step Preference & FPS Selector
    │       │   ├── intent_confirmation_screen.dart <- Order Review & Fee Audit
    │       │   └── biometric_verification_dialog.dart <- Simulated Sensor Handover Modal
    │       └── admin\
    │           ├── admin_dashboard_screen.dart     <- DSO Command Center & Stepper
    │           ├── predispatch_analysis_dialog.dart<- 4-Stage Decision Intelligence Pipeline
    │           ├── citizen_request_queue_dialog.dart<- Review Queue & Adjudication Modal
    │           └── digital_gatepass_dialog.dart    <- Sealed Manifest & QR Proof Modal
    └── test\                           <- Flutter Widget & Integration Test Suite
```

---

## 7. What Works Reliably (Core Strengths)

1. **Complete Backend Test Suite:** All 284 backend tests pass with 100% consistency across concurrency, security, and state-machine transitions.
2. **Durable Receipt Enforcement:** When a citizen confirms delivery ("I Received My Ration"), the receipt is recorded in `beneficiary_cycle_receipts`. Any subsequent attempt to submit an intent in that cycle is authoritatively blocked with HTTP 400.
3. **Choice Window & Day 25 Demand Lock:** Transitioning from Day 22 to Day 25 freezes all citizen signal mutations and generates an immutable demand snapshot with a verified SHA-256 canonical hash.
4. **Trilingual Localization:** The Flutter application switches reactively between English, Hindi, and Kannada while strictly preserving statutory numbers and currencies.
5. **9-Invariant Constraint Audit:** Hard mathematical checks catch over-payload trucks, depot deficits, and FPS storage violations before manifest locking.
6. **Stock Shortage Workflow:** Detecting godown shortages halts dispatch, delays delivery by 1–2 days, preserves citizen statutory rights, and allows seamless resumption once buffer grain arrives.

---

## 8. What is Fragile / Known Architectural Caveats

1. **Test Fixture State Isolation:**
   - Tests that mutate `planning_cycle_config` (e.g., advancing day to 25) must explicitly reset the planning day back to 22 upon teardown. Otherwise, subsequent test files that expect an open choice window will receive HTTP 400 Bad Request.
   - Always include cleanup in test fixture teardowns (`DELETE FROM demand_snapshots; DELETE FROM planning_cycle_config; INSERT OR REPLACE ... Day 22`).
2. **Foreign Key Cascade in SQLite:**
   - `delivery_disputes` has a foreign key constraint referencing `citizen_requests(request_id)`. Deleting records from `citizen_requests` without first deleting related `delivery_disputes` raises `sqlite3.IntegrityError: FOREIGN KEY constraint failed`.
3. **Flutter Widget Test Asynchrony:**
   - In `frontend/test/widget_test.dart`, `tester.pumpAndSettle()` can time out on complex screens that contain indefinite animation controllers or periodic timers (e.g., delivery countdown timers). In widget tests, use `tester.pump(const Duration(milliseconds: 100))` instead of infinite `pumpAndSettle()`.

---

## 9. Code Reuse vs. Redesign Recommendations for Next Phase

### Files to REUSE with High Confidence:
- `backend/app/services/planning_cycle_engine.py`: Rock-solid state machine and SHA-256 snapshot generator.
- `backend/app/services/constraint_engine.py`: Clean mathematical audit of 9 statutory invariants.
- `backend/app/services/optimization_engine.py`: Excellent Google OR-Tools / TSP implementation for corridor routing.
- `backend/app/core/database.py`: Clean migration architecture (migrations 001–006).
- `backend/tests/`: High-value regression suite covering security, adversarial cases, and business rules.
- `frontend/lib/core/localization.dart`: Complete, culturally accurate English/Hindi/Kannada dictionaries.
- `frontend/lib/screens/admin/digital_gatepass_dialog.dart`: Highly visual, realistic digital gatepass with QR code.

### Areas to REDESIGN in Hackathon V1:
- **Database Engine:** Migrate SQLite3 to PostgreSQL with PostGIS for true spatial corridor queries and enterprise concurrency.
- **Micro-Service Boundaries:** Decouple `admin.py` into dedicated sub-routers (`admin_dispatch.py`, `admin_forecast.py`, `admin_requests.py`, `admin_governance.py`).
- **State Management:** Introduce Riverpod or BLoC in Flutter to replace direct stateful widget setState synchronization.

---
*End of Engineering Handoff Guide — PDS DemandSync Prototype Baseline v0.1*
