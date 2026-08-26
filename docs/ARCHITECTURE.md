# PDS DemandSync - Technical Architecture Document

## 1. System Overview

**PDS DemandSync** is an intelligent decision-support overlay designed to bridge the operational gap between static public distribution grain allocations and dynamic beneficiary mobility. By harvesting early voluntary intent signals from ration cardholders prior to the monthly allocation cycle, civil supplies authorities can optimize buffer stocks, mitigate urban/migrant stockouts, and reduce godown holding losses.

---

## 2. High-Level Architecture

```
┌────────────────────────────────────────────────────────────────────────┐
│                          FLUTTER FRONTEND LAYER                        │
│                                                                        │
│   ┌────────────────────────┐              ┌────────────────────────┐   │
│   │   Beneficiary Portal   │              │ District Admin Portal  │   │
│   │   - Intent Submission  │              │ - Demand Forecasting   │   │
│   │   - FPS Availability   │              │ - Allocation Approval  │   │
│   │   - Intent Status      │              │ - Variance & Learning  │   │
│   └───────────┬────────────┘              └───────────┬────────────┘   │
│               │                                       │                │
│               └───────────────────┬───────────────────┘                │
└───────────────────────────────────┼────────────────────────────────────┘
                                    │ HTTP / REST (JSON)
                                    ▼
┌────────────────────────────────────────────────────────────────────────┐
│                           FASTAPI BACKEND LAYER                        │
│                                                                        │
│   ┌────────────────────────────────────────────────────────────────┐   │
│   │                     API Routing & Controllers                  │   │
│   │      /api/health   /api/intent   /api/forecast   /api/dispatch │   │
│   └───────────────┬───────────────────────────────┬────────────────┘   │
│                   │                               │                    │
│                   ▼                               ▼                    │
│   ┌───────────────────────────────┐ ┌──────────────────────────────┐   │
│   │     Forecast & ML Engine      │ │      Simulation Engine       │   │
│   │   - Intent Aggregator         │ │   - Godown Dispatch Sim      │   │
│   │   - Historical Trend Baseline │ │   - ePoS Distribution Sim    │   │
│   │   - Scikit-Learn Calibrator   │ │   - Forecast vs Actual Eval  │   │
│   └───────────────┬───────────────┘ └─────────────┬────────────────┘   │
│                   │                               │                    │
└───────────────────┼───────────────────────────────┼────────────────────┘
                    │                               │
                    ▼                               ▼
┌────────────────────────────────────────────────────────────────────────┐
│                        DATA PERSISTENCE LAYER                          │
│                                                                        │
│                      SQLite Relational Database                        │
│   ┌───────────────┐ ┌───────────────┐ ┌───────────────┐ ┌──────────┐   │
│   │ Beneficiaries │ │   FPS Shops   │ │ Intent Signals│ │ Forecast │   │
│   └───────────────┘ └───────────────┘ └───────────────┘ └──────────┘   │
└────────────────────────────────────────────────────────────────────────┘
```

---

## 3. The 6-Stage Closed-Loop State Machine

Every PDS distribution cycle (e.g., Monthly Cycle `2026-09`) transitions through a deterministic finite state lifecycle:

| Stage | Name | Description | Key Actor / Service |
|---|---|---|---|
| **S1** | `INTENT_WINDOW_OPEN` | Beneficiaries register non-binding intent for upcoming cycle | Beneficiary Portal |
| **S2** | `INTENT_LOCKED` | Intent collection window closes; aggregate signals validated | Backend Scheduler |
| **S3** | `FORECAST_GENERATED` | Multi-variable ML model combines intent + historical averages | Forecast Engine |
| **S4** | `DISPATCH_PLANNED` | District Admin approves quota; simulated dispatch orders issued | District Admin |
| **S5** | `DISTRIBUTION_ACTIVE` | Simulated point-of-sale (ePoS) lifting transactions recorded | Simulator Service |
| **S6** | `RECONCILED_&_LEARNED`| Forecast vs Actual variance computed; model weights calibrated | ML Calibrator |

---

## 4. Mathematical Model for Demand Forecasting

Let for a given Fair Price Shop $j$ and commodity $c$ in cycle $t$:
- $H_{j,c}^{(t)}$ = Baseline Historical Demand (3-month exponential moving average)
- $I_{j,c}^{(t)}$ = Aggregated Beneficiary Intent Signal
- $C_j^{(t)}$ = Intent Reliability / Confidence Score ($0 \le C_j \le 1.0$)
- $S_j$ = Maximum Physical Storage Capacity of FPS $j$
- $B_j$ = Minimum Safety Buffer Stock ($0.05 \cdot S_j$)

### 4.1. Intent Confidence Scoring
The confidence score $C_j^{(t)}$ for an FPS is computed from historical adherence of beneficiaries declaring intent for FPS $j$:
$$C_j^{(t)} = \beta \cdot \text{HistoricalAdherence}_j + (1 - \beta) \cdot \frac{\text{IntentCount}_j}{\text{RegisteredQuota}_j}$$

### 4.2. Composite Demand Forecast
$$\hat{D}_{j,c}^{(t)} = (1 - w \cdot C_j^{(t)}) \cdot H_{j,c}^{(t)} + (w \cdot C_j^{(t)}) \cdot I_{j,c}^{(t)} + \Delta_{calendar}$$

Where:
- $w \in [0.4, 0.8]$ is the intent weighting factor.
- $\Delta_{calendar}$ is a seasonal/festival adjustment factor.

### 4.3. Final Constrained Allocation
$$A_{j,c}^{(t)} = \min\left(S_j, \max\left(B_j, \hat{D}_{j,c}^{(t)}\right)\right)$$

### 4.4. Closed-Loop Model Calibration
Upon cycle completion with actual ePoS lifting $Y_{j,c}^{(t)}$, the system calculates:
$$\text{MAPE}_j = \frac{|\hat{D}_{j,c}^{(t)} - Y_{j,c}^{(t)}|}{Y_{j,c}^{(t)}}$$
The learning module updates weight parameter $w$ using gradient descent to minimize cross-cycle prediction error.

---

## 5. Database Schema (SQLite)

### 5.1. `fps_shops`
- `fps_id` (TEXT, PK): e.g. `FPS-KA-BLR-001`
- `name` (TEXT): Name of FPS dealer / center
- `district` (TEXT): District name (e.g. `Bengaluru Urban`)
- `taluk` (TEXT): Sub-district / Taluk
- `pincode` (TEXT): 6-digit postal code
- `registered_cards` (INTEGER): Static registered ration cards
- `capacity_quintals` (REAL): Storage capacity in quintals (1 quintal = 100 kg)
- `current_inventory_quintals` (REAL): Present stock balance

### 5.2. `beneficiaries`
- `card_id` (TEXT, PK): Pseudonymous card ID e.g. `RC-KA-9901`
- `scheme_type` (TEXT): `AAY` (Antyodaya Anna Yojana) or `PHH` (Priority Household)
- `head_of_family` (TEXT): Masked / Synthetic name
- `members_count` (INTEGER): Family member entitlement count
- `home_fps_id` (TEXT, FK): Base home registered FPS
- `monthly_wheat_kg` (REAL): Entitled wheat quota
- `monthly_rice_kg` (REAL): Entitled rice quota

### 5.3. `intent_signals`
- `intent_id` (TEXT, PK): UUID
- `cycle_id` (TEXT): e.g. `2026-09`
- `card_id` (TEXT, FK): Beneficiary card
- `target_fps_id` (TEXT, FK): Chosen FPS for collection
- `timestamp` (DATETIME): Submission timestamp
- `intent_type` (TEXT): `HOME_LIFTING` vs `PORTABILITY_MIGRANT`
- `status` (TEXT): `SUBMITTED`, `VALIDATED`, `PROCESSED`

### 5.4. `cycle_forecasts`
- `forecast_id` (TEXT, PK): UUID
- `cycle_id` (TEXT): e.g. `2026-09`
- `fps_id` (TEXT, FK): Target FPS
- `baseline_rice_qtl` (REAL): Historical baseline projection
- `intent_rice_qtl` (REAL): Declared intent signal
- `forecasted_rice_qtl` (REAL): Final composite forecast
- `allocated_rice_qtl` (REAL): Approved dispatch quota
- `confidence_score` (REAL): Model confidence [0.0 - 1.0]
- `status` (TEXT): `DRAFT`, `LOCKED`, `DISPATCHED`, `RECONCILED`

### 5.5. `cycle_actuals`
- `actual_id` (TEXT, PK): UUID
- `cycle_id` (TEXT): e.g. `2026-09`
- `fps_id` (TEXT, FK): Target FPS
- `actual_rice_qtl` (REAL): Final recorded ePoS lifted quantity
- `variance_qtl` (REAL): Forecast - Actual
- `mape_percent` (REAL): Absolute percentage error
- `stockout_occurred` (BOOLEAN): Whether shop hit stockout under baseline vs forecast

---

## 6. REST API Specification

| Method | Endpoint | Description |
|---|---|---|
| `GET` | `/api/health` | System health, database connection, uptime |
| `GET` | `/api/fps` | List all Fair Price Shops with inventory and capacity |
| `GET` | `/api/beneficiaries/lookup/{card_id}` | Lookup beneficiary quota & home FPS |
| `POST`| `/api/intent/submit` | Submit forward-looking intent for upcoming cycle |
| `GET` | `/api/forecast/cycle/{cycle_id}` | Get district-wide forecast vs baseline data |
| `POST`| `/api/forecast/lock` | District admin locks forecast for dispatch |
| `POST`| `/api/simulation/dispatch` | Run godown-to-FPS dispatch simulation |
| `POST`| `/api/simulation/actuals` | Ingest simulated ePoS actual distributions |
| `GET` | `/api/calibration/metrics` | Forecast vs Actual evaluation & model weights |

---

## 7. GovTech Design Principles

1. **Color Palette**:
   - Primary: Deep India Navy (`#0A2540` / `#1E3A8A`)
   - Secondary / Accent: Ashoka Blue (`#2563EB`) & Saffron Gold (`#D97706`)
   - Surface / Background: Crisp Gov Neutral (`#F8FAFC`, `#FFFFFF`)
   - Semantic: Success Green (`#16A34A`), Warning Amber (`#EAB308`), Danger Coral (`#DC2626`)
2. **Typography**:
   - Primary: Inter / Roboto (Clean, accessible, high legibility)
3. **Information Density**:
   - High readability metric cards, real-time KPI summaries, standard GovTech emblems & status badges.
