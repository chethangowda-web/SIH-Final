# PDS DemandSync — SIH 2026 Jury Demonstration Walkthrough & Script

> **PROTOTYPE DEMONSTRATION NOTICE**:  
> PDS DemandSync is a research software prototype and simulation developed for the **Smart India Hackathon (SIH 2026)**. It utilizes synthetic, simulated data for demonstration purposes and is **not connected to live government databases, production ePoS terminals, or active state supply depots**.

---

## A. Demo Objective

To demonstrate a forward-looking, explainable supply chain intelligence loop for India's Public Distribution System (PDS):
1. **Citizens declare forward-looking collection intent & location preference (ONORC portability)** ahead of the distribution cycle.
2. **AI & Deterministic Demand Forecasting** blends 6-cycle historical lifting averages ($H$) with active beneficiary intent signals ($I$) weighted by intent confidence ($C$).
3. **District Administrators review FPS-level risks, inspect mathematical formula calculations, and lock allocations**.
4. **Multi-Echelon Dispatch Simulation** translates locked allocations into regional godown supply manifests and truck fleet delivery schedules.
5. **Actual ePoS Distribution Simulation** generates realistic operational lifting across all Fair Price Shops.
6. **Mathematical Evaluation** quantifies forecast accuracy (MAPE, MAE, Accuracy %).
7. **Closed-Loop ML Calibration (scikit-learn)** optimizes intent influence parameters ($w$) for future distribution cycles without breaking locked cycles.

```
Beneficiary Intent Signal (I)
         +
Historical Demand Baseline (H)
         +
Intent Confidence Score (C)
         ↓
Explainable Demand Forecast (D̂)
         ↓
Administrative Forecast Lock
         ↓
Multi-Echelon Godown Dispatch Plan
         ↓
Truck Fleet Delivery Manifest
         ↓
Actual ePoS Grain Lifting Simulation (A)
         ↓
Forecast vs Actual Evaluation (MAPE / MAE)
         ↓
Closed-Loop ML Calibration (scikit-learn Ridge)
```

---

## B. Benchmark Environment & Starting State

| Parameter | Demonstration Value |
|---|---|
| **District** | Demo Nagar (Simulated Bengaluru Urban Cluster) |
| **Active Cycle** | `2026-09` (Cycle 7 - September 2026) |
| **Target Calibrated Cycle** | `2026-10` (Cycle 8 - October 2026) |
| **Historical Cycles** | 6 Past Lifting Cycles (`2026-03` to `2026-08`) |
| **Fair Price Shops (FPS)** | 20 Urban, Peri-Urban & Migrant Industrial Centers |
| **Registered Beneficiaries** | 2,000 Pseudonymized Benchmark Households |
| **Commodities** | Rice & Wheat |
| **Origin Storage Godowns** | 2 Central Depots (`Hebbal Central FCI Godown` & `Banaswadi PDS Storage Depot`) |
| **Transport Fleet** | 4 Dedicated Delivery Trucks across 4 Regional Corridors |
| **Initial Workflow State** | `PLANNING_OPEN` |

---

## C. Beneficiary Side Walkthrough (Citizen Experience)

1. **Access Citizen Portal**:
   - Navigate to `/` (Citizen Demo Login).
2. **Select Demo Beneficiary**:
   - Choose **Swathi B. (Demo)** (`BEN-KA-0001` — Registered at Malleshwaram Seva Kendra).
   - Click **"Enter Citizen Portal"**.
3. **Home Dashboard**:
   - View quota entitlement (35 kg: 25 kg Rice + 10 kg Wheat).
   - View family members and current registered FPS.
4. **Declare Forward-Looking Intent**:
   - Click **"Declare Ration Intent"**.
   - **Select Intended Fair Price Shop**: Choose **FPS-KA-BLR-013 (Peenya Industrial Area Phase-1)** to simulate seasonal migrant worker portability (ONORC).
   - **Select Preferred Collection Window**: 1st week of the month.
   - **Confirm Expected Quantities**: 25 kg Rice, 10 kg Wheat.
   - Set confidence indicator (e.g. 95%).
5. **Submit & Confirmation**:
   - Click **"Submit Intent"**.
   - System registers the pre-distribution signal, marks `is_portability_intent = true`, and stores it into the persistent SQLite database.

---

## D. District Admin Walkthrough (Civil Supplies Office)

1. **Access Admin Portal**:
   - Switch to `/admin/dashboard` or click **"Admin Portal"** in the top navigation.
2. **Initial State (`PLANNING_OPEN`)**:
   - Notice the amber badge: `PLANNING STAGE OPEN`.
   - KPI Cards show:
     - Historical Baseline (104.9 MT)
     - Intent Demand (24.4 MT)
     - Forecast Demand (0.0 MT — Awaiting generation)
     - Recommended Dispatch (0.0 MT)
     - Risk & Confidence (0 High Risk, 92% Avg Confidence)
3. **Step 1 — Generate Pre-Dispatch Forecast**:
   - Click **"Generate Forecast"**.
   - Status badge transitions to `DRAFT FORECAST READY` (Blue).
   - System executes deterministic weighted linear formula across all 20 FPS (Rice & Wheat) and persists 40 records to SQLite `forecast` table.
   - Total Forecast Demand updates to **58.0 MT** and Recommended Dispatch updates to **1.8 MT**.
4. **Step 2 — Inspect FPS Risk & Formula Explanation**:
   - Click the analytics icon on **FPS-KA-BLR-013 (Peenya Industrial Area)**.
   - View the **Visual Formula Explanation Card**:
     $$\hat{D} = (1 - 0.65 \cdot C) \cdot H + (0.65 \cdot C) \cdot I$$
   - Clearly observe the distinction between:
     - **Forecast Demand ($\hat{D}$)**: Expected consumption (57,959 kg district-wide).
     - **Recommended Dispatch**: Net godown shipment needed after subtracting on-hand stock and applying 5% safety buffer (1,823 kg).
5. **Step 3 — Authorize & Lock Allocations**:
   - Click **"Lock Forecast"**.
   - Status badge transitions to `FORECAST LOCKED` (Navy).
   - Allocations are frozen in SQLite to prevent accidental modification.
6. **Step 4 — Generate Godown Dispatch Manifest**:
   - Click **"Generate Dispatch"**.
   - Status badge transitions to `DISPATCH MANIFEST GENERATED` (Green).
   - Allocations are assigned to 4 regional vehicle corridors from Hebbal Central FCI Godown and Banaswadi PDS Buffer Depot.
7. **Step 5 — Simulate Actual ePoS Distribution (Phase 6A)**:
   - Click **"Simulate Actuals"**.
   - Status badge transitions to `ACTUAL ePoS LIFTING SIMULATED` (Amber).
   - Simulates realistic operational lifting across all 20 FPS with deterministic variance.
8. **Step 6 — Evaluate Forecast vs Actual Accuracy (Phase 6B)**:
   - Click **"Evaluate Accuracy"**.
   - Status badge transitions to `FORECAST EVALUATED` (Teal).
   - View evaluation dialog:
     - **Overall Accuracy**: **97.52%**
     - **Mean Absolute Percentage Error (MAPE)**: **2.48%**
     - **Mean Absolute Error (MAE)**: **35.42 kg**
     - Commodity accuracy (Rice MAPE: 2.46%, Wheat MAPE: 2.50%)
     - FPS-by-FPS audit table.
9. **Step 7 — Closed-Loop Machine Learning Calibration (Phase 6C)**:
   - Click **"Calibrate ML Model"**.
   - Status badge transitions to `ML MODEL CALIBRATED (v1.1)` (Purple).
   - System trains `scikit-learn Ridge` regression on observed lifting:
     - Current Intent Weight: $w = 0.65$
     - Calibrated Weight: $w^* = 0.65$ (Model Version: `v1.1-calibrated`)
     - Target Future Cycle: `2026-10` (October 2026)
     - Preserves frozen `2026-09` allocations while training parameters for future cycles.

---

## E. Mathematical Formulations & ML Details

### 1. Pre-Dispatch Demand Forecast Formula:
$$\hat{D}_{j,c} = (1 - w \cdot C_{j,c}) \cdot H_{j,c} + (w \cdot C_{j,c}) \cdot I_{j,c}$$

Where:
- $H_{j,c}$: 6-Cycle Historical Lifting Average for FPS $j$ and commodity $c$
- $I_{j,c}$: Aggregated Beneficiary Intent Demand for FPS $j$ and commodity $c$
- $C_{j,c}$: Average confidence score of declared intent signals ($0.0 \le C \le 1.0$)
- $w = 0.65$: Configurable intent influence weight (`settings.INTENT_WEIGHT`)

### 2. Forecast vs Actual Evaluation Metrics:
$$\text{MAPE} = \frac{1}{N} \sum_{i=1}^{N} \frac{|A_i - \hat{D}_i|}{\max(A_i, 1.0)} \times 100\%$$
$$\text{MAE} = \frac{1}{N} \sum_{i=1}^{N} |A_i - \hat{D}_i|$$
$$\text{Overall Accuracy} = 100\% - \text{MAPE}$$

### 3. Closed-Loop Machine Learning Calibration (scikit-learn):
- **Objective**: Minimize error between predicted demand $\hat{D}(w)$ and actual observed lifting $A$.
- **Transformation**: $(A - H) \approx w \cdot \big[C \cdot (I - H)\big]$
- **Model**: `sklearn.linear_model.Ridge(alpha=1.0, fit_intercept=False)` fit over 40 FPS observations.
- **Safety Envelope**: Calibrated weight clamped to $[0.20, 0.90]$ and applied to future Cycle `2026-10`.

---

## F. 3-Minute SIH Jury Presentation Script

| Time | Screen | Jury Speaking Script |
|---|---|---|
| **0:00 - 0:40** | Beneficiary Screen | *"Respected jury members, today's PDS suffers from a fundamental blindspot: godown dispatch relies purely on historical data. When seasonal workers or students migrate under One Nation One Ration Card, destination shops run out of grain while origin shops sit with idle stock. PDS DemandSync solves this by capturing forward-looking beneficiary intent."* |
| **0:40 - 1:15** | Intent Submission | *"Here on the Citizen Portal, a beneficiary declares ahead of the cycle that they will collect their quota at Peenya Industrial Hub. The system instantly registers this signal without compromising privacy."* |
| **1:15 - 1:55** | Admin Dashboard & Formula | *"Switching to the District Admin Portal, the Civil Supplies Officer generates an explainable demand forecast. Notice this isn't a black box: the formula visibly balances 6-month historical lifting with intent signals weighted by confidence. The admin locks the forecast, ensuring complete auditability."* |
| **1:55 - 2:25** | Dispatch Simulation | *"The system generates the operational dispatch manifest, routing exact grain requirements from central FCI godowns to regional transport trucks and Fair Price Shops."* |
| **2:25 - 3:00** | Evaluation & ML Calibration | *"Finally, PDS DemandSync closes the loop. Once ePoS grain distribution occurs, our evaluation engine computes mathematical accuracy: 97.5% accuracy with under 2.5% MAPE. Using scikit-learn Ridge regression, the system automatically calibrates the model parameters for the upcoming October cycle. This creates a self-improving, intelligent supply chain for India's food security."* |

---

## G. Reset Procedure for Successive Jury Demos

To reset the workflow state back to `PLANNING_OPEN` for the next evaluation round:
1. Click the **Amber Reset Icon (`↻`)** in the Admin Portal top navigation bar.
2. Click **"Confirm Reset"**.
3. Alternatively, trigger the API endpoint:
   ```bash
   curl -X POST "http://localhost:8000/admin/demo/reset?cycle_id=2026-09"
   ```
4. All benchmark data (2,000 beneficiaries, 20 FPS, historical data) remains intact, ready for a fresh demonstration from scratch.

---

## H. Server Launch Commands

### 1. Backend Server (FastAPI)
```powershell
cd E:\rationcard\backend
.\.venv\Scripts\python.exe -m uvicorn app.main:app --reload --port 8000
```
- API Docs: `http://localhost:8000/docs`
- Health Endpoint: `http://localhost:8000/health`

### 2. Frontend Application (Flutter)
```powershell
cd E:\rationcard\frontend
flutter run -d chrome
```

---

## I. Automated Test Verification

Run all 30 backend tests:
```powershell
cd E:\rationcard\backend
.\.venv\Scripts\python.exe -m pytest tests/ -v
```
Expected output: **30 passed (100% pass rate)**.
