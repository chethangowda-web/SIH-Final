# PDS DemandSync: System Architecture & Functional Specification Report

**Document Version:** 2.0-Production  
**Project:** Public Distribution System (PDS) DemandSync Platform  
**Target Region:** Bengaluru Urban Pilot District (Karnataka, India)  
**Classification:** Institutional Decision Support & Citizen Governance Documentation  
**Date:** September 1, 2026  

---

## 1. Executive Summary & Application Overview

### 1.1 The Core Problem
The traditional Public Distribution System (PDS) operates on a static, historical quota push model. Grain dispatch allocations from central Food Corporation of India (FCI) godowns to neighborhood Fair Price Shops (FPS) are fixed months in advance based purely on static ration card registrations. 

This static model creates two systemic failures:
1. **Severe Stockouts at High-Portability Nodes:** Migrant workers exercising One Nation One Ration Card (ONORC) portability flood specific industrial and transit FPS shops (e.g., Peenya Industrial, Outer Ring Road), depleting stocks in days and leaving local families stranded.
2. **Grain Spoilage at Low-Demand Depots:** FPS shops with declining footfalls receive excess grain that exceeds local storage capacity, leading to infestation, damage, and financial loss.

### 1.2 The PDS DemandSync Solution
**PDS DemandSync** transforms the Public Distribution System from a *static push model* into a **demand-driven, predictive pull model**. Beneficiaries express forward-looking demand signals (intents) through an accessible multilingual portal before the monthly cycle starts. 

The platform blends:
- **Citizen Intent Signals** (explicit choice of commodity, destination FPS, and delivery mode),
- **Explainable Multi-Factor AI Demand Forecasting** ($D̂ = w_1 H + w_2 I + w_3 S + w_4 M$),
- **9-Invariant Statutory Constraint Audits** (ensuring no FPS exceeds storage capacity or breaches minimum statutory food security floors),
- **Traveling Salesperson (TSP) Fleet Optimization** (automated multi-stop corridor routing for 10 MT trucks),
- **Cryptographic SHA-256 Digital Gatepasses & Tamper-Evident Governance Logs**.

---

## 2. Beneficiary / Customer Portal

The Beneficiary Portal is designed for accessibility, clarity, and trust across diverse citizen demographics.

```
┌─────────────────────────────────────────────────────────────────────────┐
│                      BENEFICIARY EXPERIENCE FLOW                        │
├─────────────┬─────────────┬─────────────┬─────────────┬─────────────────┤
│ 1. PERSONA  │ 2. HOUSEHOLD│ 3. SERVICE  │ 4. COMBINED │ 5. BIOMETRIC    │
│    LOGIN    │ ENTITLEMENT │ & LOCATION  │ ORDER & REVIEW│  HANDOVER     │
└─────────────┴─────────────┴─────────────┴─────────────┴─────────────────┘
```

### 2.1 Demo Persona Login & Multilingual Engine
- **One-Click Verified Personas:** Demo personas representing distinct real-world demographics:
  - **Swathi Bhat (`BEN-KA-0001`):** Priority Household (PHH) resident collector at Malleshwaram Seva Kendra.
  - **Sunita Devi (`BEN-KA-0005`):** Migrant construction worker exercising portability at Bellandur Outer Ring Road.
  - **Ramesh Kumar (`BEN-KA-0015`):** Shift industrial worker at Peenya Industrial Area.
- **Trilingual Localization:** Instant, reactive switching between **English**, **Hindi (हिन्दी)**, and **Kannada (ಕನ್ನಡ)**. The UI updates instantly across all labels and policy notices while preserving statutory numerical figures, quantities, card IDs, and currency.

### 2.2 Household Entitlement Calculator ($N \times 5\text{ kg}$)
- **Family Member Selection:** Beneficiaries can adjust eligible family member counts (1 to 8 members).
- **Statutory Formula:** Demonstrates Karnataka Food Security rules of **5 kg per person per month** (e.g., $5\text{ members} \times 5\text{ kg} = 25\text{ kg}$ monthly quota).
- **Entitlement Protection:** Beneficiaries cannot request more than their statutory monthly ceiling.

### 2.3 Service Mode & FPS Selection
- **FPS Self-Collection:** Free collection at registered or portable Fair Price Shops.
- **Assisted Doorstep Delivery:** Available for elderly, remote, or busy households with statutory transparent transport fees (₹20 base + ₹5/km surcharge).
- **Portability Selector:** Search across 20 Fair Price Shops across Bengaluru Urban with live distance metrics and inventory headroom indicators.

### 2.4 Combined Rice + Wheat Order Section
- **Unified Order Presentation:** Rice and Wheat are consolidated into a single card with separate line items (e.g., 20 kg Rice + 5 kg Wheat = 25 kg Total).
- **Real-Time Fee & Quota Audits:** Instant calculation of commodity cost (₹0.00 subsidized) and transparent transport fee breakdowns before submission.

### 2.5 Biometric / Thumb Verification Simulation
- **Simulated Sensor Verification:** Simulates an optical fingerprint scan for both FPS counter pickup and doorstep delivery handover.
- **Eligibility Checking:** Ensures the cardholder is eligible before unlocking grain distribution.
- **Privacy First:** **No biometric data is captured or stored.** The system uses a client-side cryptographic mock token.

### 2.6 Delivery Tracking & Delay Notice Banner
- **5-Stage Delivery Timeline:** `Requested` → `Allocated` → `Out for Delivery` → `Arrived` → `Delivered & Verified`.
- **Prominent Delay Alert Banner:** If government stock constraints occur, an amber card alerts the citizen:
  > *"⏳ Delivery Delayed: Your ration delivery is temporarily delayed due to government stock availability. Expected delivery: Within 1–2 Days. You do not need to submit your request again."*

---

## 3. District Officer & Admin Portal

The Officer Portal serves as the institutional Command Center for district food supply logistics.

### 3.1 District Analytics Dashboard
- **Key Performance Indicators (KPIs):** Total Active Intents, Aggregated Declared Intent (MT), Multi-Factor Forecast (MT), Recommended Dispatch (MT), and Average Confidence Score (96.4%).
- **FPS Health Matrix:** Risk level breakdowns across all 20 Fair Price Shops (`LOW_RISK`, `BALANCED`, `SURGE_RISK`, `STORAGE_DEFICIT`).

### 3.2 Citizen Request & Review Queue
- **Institutional Decision Support:** 8 filtered tabs:
  - `All Requests`, `Pending Review`, `Approved`, `Delayed`, `Partial Allocation`, `Redirected`, `Deferred`, `Delivery Disputes`.
- **Officer Decision Actions:** Full Quota Approval, Partial Floor Allocation, Redirect to Nearby FPS, or Temporary Deferral with mandatory justification logging.

### 3.3 Readiness & Multi-Channel Broadcast Center
- **Automated Dealer & Beneficiary Notifications:** WhatsApp broadcasts to FPS dealers and SMS/IVR notifications to citizens.
- **Stock Shortage Delay Broadcast Tool:** Dedicated modal allowing officers to dispatch official 1–2 day delay notices directly to beneficiaries.

### 3.4 Corridor Optimization & Truck Simulation
- **4 Fleet Delivery Corridors:**
  - `DEMO-KA-04-E-1021`: North-West Heavy Corridor (Eicher Pro 10 MT)
  - `DEMO-KA-04-E-1022`: East Corridor / IT Belt (Tata Ultra 10 MT)
  - `DEMO-KA-51-M-3419`: South Industrial Corridor (BharatBenz 10 MT)
  - `DEMO-KA-04-E-1023`: Central Buffer Corridor (Ashok Leyland 10 MT)
- **Interactive Map & Live Telemetry:** Real-time truck position tracking along optimized TSP multi-stop routes.
- **3 Operational Pre-Dispatch Incidents:**
  1. *En-route Mechanical Breakdown / Corridor Congestion*
  2. *FPS Storage Headroom Constraint (< 15% Remaining)*
  3. *Portability Demand Surge Spike (> 35% Migrant Volume)*

---

## 4. Pre-Dispatch Decision Intelligence Pipeline

When the officer clicks **"Run Pre-Dispatch Analysis"**, the platform executes a 4-stage automated pipeline with live elapsed timers.

```
┌─────────────────────────────────────────────────────────────────────────┐
│                    PRE-DISPATCH DECISION PIPELINE                       │
├─────────────┬─────────────┬─────────────┬───────────────────────────────┤
│ 1. FORECAST │ 2. VALIDATE │ 3. OPTIMIZE │ 4. MANIFEST                   │
│   (Demand)  │(Constraints)│ (Logistics) │   (SHA-256 Seal)              │
└─────────────┴─────────────┴─────────────┴───────────────────────────────┘
```

| Stage | Name | Core Operation | Processing Time | Output Metric |
|:---:|---|---|:---:|---|
| **1** | **FORECAST** | Multi-factor linear demand composite model combining historical consumption, forward intent, seasonal factors, and migrant portability rates. | 3.0s | `62.7 MT Demand Calculated` |
| **2** | **VALIDATE** | Mathematical audit of 9 statutory logistics invariants, checking FPS storage capacity, vehicle weight limits, statutory food security floors, and buffer thresholds. | 2.0s | `9 Invariant Rules Verified` |
| **3** | **OPTIMIZE** | Multi-stop Traveling Salesperson Problem (TSP) heuristic computing lowest-cost routes across the 4 district vehicle corridors. | 3.0s | `4 Fleet Corridors (142 km)` |
| **4** | **MANIFEST** | Sealing individual truck loading manifests with immutable cryptographic SHA-256 digital gatepass hashes. | 2.0s | `Digital Gatepass Sealed` |

---

## 5. Government Stock Shortage Workflow (Delay vs. Cancellation)

### 5.1 The Policy Mandate
> **Government Policy:** A temporary buffer stock shortage at central FCI godowns must **NEVER cancel or permanently reject a citizen's statutory ration quota**. Food security is a statutory right. Stock shortages must be treated as **temporary delays (1–2 days)** while buffer replenishment is in transit.

```
┌─────────────────────────────────────────────────────────────────────────┐
│                     STOCK SHORTAGE STATE MACHINE                        │
│                                                                         │
│  [Requested] ──► [Allocated] ──► [Stock Shortage] ──► [DELAYED]         │
│                                                          │              │
│                                                    (Buffer Arrives)     │
│                                                          │              │
│  [Delivered] ◄── [Out for Delivery] ◄── [Resume Dispatch]               │
└─────────────────────────────────────────────────────────────────────────┘
```

### 5.2 Scenario B Execution in DemandSync
1. **Detection:** When Scenario B (Stock Shortage) is selected in Pre-Dispatch Analysis, the pipeline detects an 8.4 MT buffer deficit during the **VALIDATE** stage.
2. **Halting & Warning:** The pipeline pauses at VALIDATE, showing an operational amber alert:
   > *"⚠ Stock Constraint Detected — Government buffer stock temporarily unavailable. Recommended Action: Delay Dispatch (1–2 Days) & Notify Beneficiaries."*
3. **Delay Dispatch Action:** The officer clicks **"Delay Dispatch (1–2 Days)"**. This transitions the district workflow and citizen orders to `DELAYED` / `STOCK_DELAYED` without deleting any allocation.
4. **Beneficiary Notification:** The officer sends an official SMS notification. The citizen portal displays the amber *"⏳ Delivery Delayed"* card reassuring the user that their request remains secured.
5. **Resume Dispatch:** When stock arrives at the depot, the officer clicks **"Resume Dispatch"** on the dashboard, immediately restoring the pipeline and moving orders to `OUT_FOR_DELIVERY`.

---

## 6. Security, Governance & Verification Architecture

### 6.1 Cryptographic Gatepass Sealing
- Every manifest is hashed using canonical **SHA-256** checksums (`manifest_id`, `truck_id`, `depot_id`, `items`, `timestamp`).
- Any downstream tampering or route deviation invalidates the digital gatepass seal immediately.

### 6.2 Append-Only Governance Audit Trail
- All administrative state transitions (Approvals, Redirections, Delays, Resumptions) are recorded in an append-only `governance_audit_logs` database table with actor IDs, roles, correlation IDs, before/after states, and timestamps.
- AI automated systems are strictly prohibited from approving officer-restricted state transitions.

### 6.3 Privacy-Preserving Biometric Simulation
- The biometric verification dialog simulates fingerprint matching for operational demo purposes.
- **Zero Raw Biometric Storage:** No fingerprints, minutiae templates, or personal biometric records are stored in SQLite or transmitted over APIs.

---

## 7. Backend Architecture & Core API Endpoints

The backend is built with **FastAPI** (Python 3.12+) and **SQLite3** with WAL mode for concurrency.

```
┌─────────────────────────────────────────────────────────────────────────┐
│                      FASTAPI BACKEND MODULES                            │
├───────────────────┬───────────────────┬─────────────────────────────────┤
│ app/api/admin.py  │ app/api/beneficiary│ app/services/dispatch_engine.py │
│ app/api/auth.py   │ app/api/intent.py │ app/services/scarcity_engine.py │
└───────────────────┴───────────────────┴─────────────────────────────────┘
```

### Key API Surface

| Method | Endpoint | Description |
|---|---|---|
| `POST` | `/api/v1/auth/login` | Authenticates officer and citizen sessions; issues Bearer tokens. |
| `GET` | `/api/v1/beneficiaries/{id}` | Retrieves beneficiary profile, card type, and registered FPS. |
| `GET` | `/api/v1/beneficiary/{id}/entitlement-summary` | Computes dynamic $N \times 5\text{ kg}$ quotas, balances, and fees. |
| `POST` | `/api/v1/intent` | Submits monthly forward intent declaration. |
| `GET` | `/api/v1/admin/dashboard` | Returns full district overview, KPIs, and FPS health matrix. |
| `POST` | `/api/v1/admin/predispatch/run` | Executes 4-stage Pre-Dispatch Pipeline with scenario flags. |
| `POST` | `/api/v1/admin/dispatch/delay` | Applies temporary 1–2 day delay due to stock constraints. |
| `POST` | `/api/v1/admin/dispatch/resume` | Resumes dispatch lifecycle once buffer stock is replenished. |
| `POST` | `/api/v1/admin/notifications/send-delay-alert` | Sends targeted SMS/WhatsApp delay alerts to beneficiaries. |
| `GET` | `/api/v1/admin/citizen-requests` | Returns paginated Citizen Request Review Queue with 8 filter tabs. |
| `POST` | `/api/v1/admin/citizen-requests/{id}/authorize` | Authorizes, caps, redirects, or defers citizen requests. |

---

## 8. End-to-End Data Flow

```
[1. Citizen] ────────► Submits Intent (Rice + Wheat, Location, Delivery Mode)
       │
[2. Intake]  ────────► Citizen Request Queue & Database Store
       │
[3. Forecast] ───────► Multi-Factor Composite Calculation (D̂ = w₁H + w₂I + w₃S + w₄M)
       │
[4. Validate] ───────► 9-Invariant Logistics & Storage Capacity Audit
       │
[5. Optimize] ───────► TSP 4-Corridor Truck Route Scheduling
       │
[6. Manifest] ───────► SHA-256 Digital Gatepass Generated & Locked
       │
[7. Dispatch] ───────► Fleet Movement / Simulation (Normal or 1-2 Day Delay)
       │
[8. Handover] ───────► Citizen Biometric / Thumb Verification Simulation
       │
[9. Close]   ────────► Order Completed & Remaining Card Balance Updated
```

---

## 9. Review Demonstration Guide (Step-by-Step Scenarios)

When demonstrating the application to examiners, evaluators, or project reviewers, use these three clear scenarios:

### Scenario 1: Standard Citizen Intent & Biometric Handover
1. **Login:** Open Beneficiary Portal and select **Swathi Bhat** (Kannada/English).
2. **Household Quota:** Change family members from 4 to 5. Notice quota updates from 20 kg to 25 kg ($5 \times 5\text{ kg}$).
3. **Order Selection:** Choose Assisted Doorstep Delivery or FPS Collection. Select Rice (20 kg) + Wheat (5 kg).
4. **Review & Confirm:** Check the combined Rice + Wheat card and submit the intent.
5. **Biometric Verification:** Tap "Simulate Biometric Verification" on the delivery card to demonstrate the fingerprint scan and successful completion.

### Scenario 2: Officer Pre-Dispatch Intelligence & Pipeline
1. **Login:** Access the District Officer Portal (`/admin`).
2. **Run Pipeline:** Click **"Run Pre-Dispatch Analysis"** in the top action bar.
3. **Live Timers:** Watch the 4 stages execute sequentially with real-time counting elapsed timers (`00:03`, `00:02`, `00:03`, `00:02`).
4. **Manifest Lock:** Review the 62.7 MT forecast and click **"Lock Manifest & Proceed"**.

### Scenario 3: Government Stock Shortage & Non-Cancellation Delay Flow
1. **Pre-Dispatch Dialog:** Open "Run Pre-Dispatch Analysis" and select **"Scenario B: Government Stock Shortage"**.
2. **Constraint Detection:** Watch the pipeline stop at **2. VALIDATE** showing the amber *"⚠ Stock Constraint Detected"* warning.
3. **Delay Dispatch:** Click **"Delay Dispatch (1–2 Days)"**.
4. **Send Alert:** Open **"Send Stock Delay Alert"** in Readiness Alerts to broadcast SMS notices.
5. **Verify Citizen Portal:** Switch to Swathi Bhat's portal to show the amber *"⏳ Delivery Delayed (1–2 Days)"* card reassuring the citizen that their quota is safe.
6. **Resume Dispatch:** Return to Admin Portal and click the **"Resume Dispatch"** button to restore operations.

---

## 10. Automated Test Results & Verification

All automated test suites pass cleanly across both frontend and backend.

```
========================================================================================
                          AUTOMATED TEST VERIFICATION SUMMARY
========================================================================================
1. Flutter Static Analyzer (dart analyze lib/)
   - Result: 0 Errors, 0 Fatal Warnings (Clean)

2. Flutter Unit & Widget Test Suites (flutter test)
   - Total Tests Executed: 41
   - Total Passed: 41
   - Total Failed: 0
   - Passing Rate: 100.0%

3. FastAPI Backend Pytest Suite (python -m pytest backend/tests/)
   - Total Test Cases: 276
   - Total Passed: 276
   - Total Failed: 0
   - Total Skipped: 0
   - Duration: 49.52s
   - Passing Rate: 100.0%
========================================================================================
```

---

*Report prepared and certified for academic and institutional evaluation of PDS DemandSync.*
