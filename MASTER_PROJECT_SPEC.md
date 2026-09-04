# MASTER PROJECT SPECIFICATION: PDS-PREDICT / PDS DEMANDSYNC
**A Pre-Dispatch Demand Intelligence and Coordination Layer for India's Public Distribution System**

---

## Document Metadata
- **Project Name:** PDS-PREDICT / PDS DemandSync
- **Working Title:** A Pre-Dispatch Demand Intelligence and Coordination Layer for India's Public Distribution System (PDS)
- **Target Hackathon:** Smart India Hackathon (SIH) / College Internal Hackathon Prototype Baseline
- **Document Version:** 1.0 (Master Baseline Specification)
- **Date:** September 2026
- **Status:** Canonical Single Source of Truth (SSOT) for Next-Generation Development

---

## 1. Project Identity

### 1.1 Project Name
**PDS-PREDICT** (Institutional System Identity: **PDS DemandSync**)

### 1.2 Working Title
*A Pre-Dispatch Demand Intelligence and Coordination Layer for India's Public Distribution System*

### 1.3 Target Context
Smart India Hackathon (SIH) / National Innovation Prototype for Ministry of Consumer Affairs, Food & Public Distribution, and State Civil Supplies Corporations.

### 1.4 One-Line Description
A pre-dispatch decision intelligence layer that captures beneficiary collection preferences during a time-bounded choice window, locks an immutable demand baseline on Day 25, validates it against physical and policy constraints, and computes an optimized, verifiable dispatch manifest before trucks leave government godowns.

---

## 2. Core Problem: The Pre-Dispatch Coordination Gap

### 2.1 What the Problem IS NOT
To maintain complete credibility with PDS administrators, domain experts, and hackathon judges:
- We **DO NOT** claim: *"India has no PDS digitization."* (India has digitized over 5.4 lakh Fair Price Shops with electronic Point of Sale [e-PoS] devices and 100% Aadhaar seeding).
- We **DO NOT** claim: *"India has no GPS or route optimization."* (Many states have vehicle tracking systems [VTS] and fixed corridor routes).
- We **DO NOT** claim: *"Every PDS truck is routinely rerouted in mid-transit because beneficiary demand changes."* (PDS supply chains operate on strict bulk allocation, not dynamic on-the-fly truck rerouting).

### 2.2 What the Real Problem IS
The critical vulnerability in modern PDS logistics is the **pre-dispatch coordination gap**:
1. **Static Quota Push vs. Dynamic Footfall:** Allocations from Food Corporation of India (FCI) / State Warehousing godowns to neighborhood Fair Price Shops (FPS) are determined weeks in advance based entirely on *static registration records*.
2. **ONORC Portability Volatility:** Under the One Nation One Ration Card (ONORC) scheme, migrant laborers and urban workers can legally lift grain at any FPS nationwide. However, the supply chain has **zero advance visibility** into where beneficiaries intend to lift their quota in any given month.
3. **Severe Localized Stockouts:** High-portability clusters (industrial zones, construction corridors, peri-urban transit hubs) experience demand surges that exhaust shop quotas within days, forcing genuine beneficiaries to face turnaways and repeat visits.
4. **Depot-Level Spoilage & Stranded Capital:** Conversely, residential shops with declining footfalls receive full static quotas that sit idle, exceeding storage capacity, escalating infestation risks, and tying up statutory working grain capital.
5. **No Pre-Dispatch Verification:** District Supply Officers (DSOs) lack an integrated decision layer that reconciles citizen preference signals, storage limits, truck capacities, and statutory minimums **before** physical truck departure.

---

## 3. Core Novelty: Coordination & Decision Workflow

### 3.1 Conceptual Definition
> **A PDS-specific pre-dispatch coordination layer that converts beneficiary preferred-location signals collected during a defined choice window into a locked demand baseline, validates that demand against stock, allocation, FPS and vehicle constraints, and generates an auditable dispatch manifest before physical truck movement.**

### 3.2 Where Novelty Resides
The core intellectual property and innovation is **the pre-dispatch coordination and decision workflow**:
- **NOT** inventing new machine learning algorithms (standard regression, gradient boosting, and time-series models suffice).
- **NOT** inventing GPS tracking, e-PoS devices, or biometric sensors.
- **NOT** inventing ONORC or replacing state food portals.
- **THE NOVELTY IS:** Architecting a deterministic, time-stepped policy pipeline that synchronizes citizen voluntary signals, statutory entitlement floors, warehouse constraints, and fleet logistics into a single, immutable, auditable pre-dispatch decision chain.

---

## 4. Unique Selling Proposition (USP)

> **"Don't reroute the truck after it leaves. Prepare the demand before it leaves."**

While commercial logistics platforms attempt costly, disruptive en-route dynamic adjustments, PDS DemandSync solves the issue upstream during Days 21–25 of the monthly planning cycle—transforming unpredictable demand into a locked, validated, and optimized loading manifest before a single grain bag is hoisted onto a vehicle.

---

## 5. System Boundary: Augmentation, Not Replacement

PDS DemandSync is explicitly designed as an **augmentation and decision-support layer**. It does not replace existing sovereign infrastructure:

| Existing System | Role in Sovereign PDS | How PDS-PREDICT Augments It |
|---|---|---|
| **FCI / CWC Godowns** | Central bulk storage & procurement | Feeds real-time available depot stock into constraint checks |
| **State Food Portals** | Master beneficiary registry & card entitlement | Reads card type, household size, and statutory entitlement rules |
| **e-PoS Devices** | Counter-level biometrics & grain disbursement | Consumes distribution actuals for forecast-vs-actual evaluation |
| **ONORC Engine** | Inter-state/intra-state portability transaction clearing | Provides forward choice window to capture portability intent in advance |
| **Transporter Fleet** | Physical haulage of foodgrains | Generates mathematically validated, corridor-optimized truck manifests |

---

## 6. System Actors & Roles

```
┌────────────────────────────────────────────────────────────────────────┐
│                        PDS-PREDICT ACTOR ECOSYSTEM                     │
├───────────────────┬───────────────────┬────────────────────────────────┤
│ 1. BENEFICIARY    │ 2. DSO / ADMIN    │ 3. FPS DEALER                  │
│    Citizen signal │    District Supply│    Fair Price Shop             │
│    declaration    │    Officer control│    quota receiver              │
├───────────────────┼───────────────────┼────────────────────────────────┤
│ 4. WAREHOUSE      │ 5. TRANSPORTER    │ 6. DECISION LAYER              │
│    Supply depot   │    Fleet carrier  │    PDS DemandSync              │
│    loading origin │    contractor     │    Coordination Engine         │
└───────────────────┴───────────────────┴────────────────────────────────┘
```

1. **Beneficiary (Citizen):**
   - Declares service choice (FPS self-collection vs. assisted doorstep delivery).
   - Declares preferred collection location (home registered shop vs. alternative portable shop).
   - Views statutory entitlement breakdown ($N \times 5\text{ kg}$).
   - Tracks order lifecycle and delivery ETA.
   - Confirms receipt ("I Received My Ration") or flags shortfall disputes.
2. **District Supply Officer (DSO / Admin):**
   - Controls monthly cycle progression (Days 21–24 Choice Window $\to$ Day 25 Demand Lock).
   - Reviews and authorizes exceptional citizen portability requests and review queue cases.
   - Seals demand snapshots and runs the pre-dispatch decision intelligence pipeline.
   - Evaluates forecast vs. actual offtake accuracy across all Fair Price Shops.
3. **FPS Dealer (Fair Price Shop Operator):**
   - Receives advance notification of locked demand baselines and expected truck delivery windows.
   - Prepares local shop storage capacity and staging areas prior to vehicle arrival.
4. **Warehouse / Supply Node (Depot Manager):**
   - Receives cryptographically sealed loading manifests specifying exact grain allocations per truck.
   - Verifies digital gatepass QR codes at warehouse exit gates.
5. **Vehicle / Transport Operator (Fleet Haulier):**
   - Executes multi-stop corridor deliveries according to optimized routing sequences.
   - Reports en-route delays or mechanical incidents directly to district command.
6. **PDS-PREDICT Decision Layer:**
   - Autonomous calculation engine executing forecasting, constraint verification, and mathematical optimization.

---

## 7. The Monthly Planning Cycle: Rhythm of Governance

The entire system operates around a strict, time-bounded monthly calendar:

```
               MONTHLY PLANNING & DISTRIBUTION TIMELINE
  
  Days 1 – 20           Days 21 – 24           Day 25             Days 26 – 31
┌──────────────┐     ┌──────────────────┐   ┌─────────────┐    ┌─────────────────┐
│ Active Month │ ──► │  CHOICE WINDOW   │──►│ DEMAND LOCK │ ──►│ PRE-DISPATCH &  │
│ Distribution │     │ Citizen Signals  │   │  Snapshot   │    │ Physical Truck  │
│  At Counters │     │ (Preferred FPS)  │   │ SHA-256 Seal│    │   Dispatches    │
└──────────────┘     └──────────────────┘   └─────────────┘    └─────────────────┘
```

### Phase 1: Days 21–24 (The Choice Window)
- **Status:** `CHOICE_WINDOW_OPEN`
- **Actions Permitted:**
  - Beneficiaries log in to view current registered FPS.
  - Beneficiaries declare service preference (FPS collection vs. home delivery) and preferred shop for the upcoming month.
  - Beneficiaries can modify or update their choice freely.
  - DSO dashboard displays real-time aggregated signal counters and portability heatmaps.

### Phase 2: Day 25 (Demand Lock)
- **Status:** `DEMAND_LOCKED` / `FORECAST_LOCKED`
- **System Action:**
  - Choice window closes automatically at 23:59:59 (or via DSO manual authorization).
  - System aggregates all declared preferences per FPS, commodity, and delivery mode.
  - Blends preferences with historical baselines into a frozen demand baseline ($\hat{D}$).
  - Computes a canonical **SHA-256 digital hash** sealing the demand snapshot.
  - **Mutation Lock:** All beneficiary requests for the current cycle are permanently frozen. Direct API or UI mutation attempts are rejected with HTTP 400.

### Phase 3: Days 25+ (Pre-Dispatch Planning & Dispatch Execution)
- **Status:** `VALIDATED` $\to$ `ALLOCATED` $\to$ `OPTIMIZED` $\to$ `MANIFEST_LOCKED` $\to$ `DISPATCHED`
- Downstream logistics pipeline runs against the frozen Day 25 baseline:
  $$\text{Demand Baseline} \longrightarrow \text{Constraint Audit} \longrightarrow \text{Optimization} \longrightarrow \text{Manifest Lock} \longrightarrow \text{Disbursement}$$

---

## 8. Demand Lock vs. Manifest Lock

To prevent architectural confusion, this distinction is strictly enforced across the system:

| Attribute | Demand Lock (Day 25) | Manifest Lock (Pre-Dispatch) |
|---|---|---|
| **Core Question** | *"What demand are we planning for?"* | *"What exact stock, vehicle, and route will leave?"* |
| **System Actor** | District Supply Officer / Automated Cycle Engine | Warehouse Logistics Officer / Dispatch Manager |
| **Input Data** | Beneficiary intent signals + historical baselines | Locked demand + warehouse inventory + fleet availability |
| **State Mutation** | Freezes citizen preferences; prevents citizen edits | Freezes truck loading orders; prevents allocation changes |
| **Cryptographic Seal**| SHA-256 hash of aggregated demand vector | SHA-256 digital gatepass signed for truck release |
| **Downstream Impact** | Feeds constraint verification and optimization | Authorizes warehouse gate exit and driver trip ticket |

---

## 9. End-to-End System Workflow

```
BENEFICIARY
    │
    ▼
CHOICE WINDOW (Days 21–24)
  - Beneficiary selects preferred Fair Price Shop / Doorstep mode
  - Validates statutory quota (5 kg / member)
    │
    ▼
DAY 25 DEMAND LOCK
  - System freezes all citizen preferences
  - Generates immutable Demand Snapshot + SHA-256 digest
  - Rejects any subsequent modification attempts
    │
    ▼
MULTI-FACTOR DEMAND FORECASTING
  - Composites locked intent + historical consumption + seasonality + portability rate
    │
    ▼
STATUTORY CONSTRAINT ENGINE (9 Invariants)
  - Validates depot stock availability
  - Validates Fair Price Shop physical storage capacity
  - Validates truck gross vehicle payload limits (10 MT)
  - Validates statutory entitlement floors
    │
    ▼
FLEET LOGISTICS OPTIMIZATION
  - Runs multi-stop Traveling Salesperson Problem (TSP) / VRP algorithm
  - Assigns Fair Price Shops to 4 regional transport corridors
    │
    ▼
DISPATCH MANIFEST GENERATION & MANIFEST LOCK
  - Creates individual truck manifests
  - Signs Digital Gatepass with cryptographic verification token
    │
    ▼
WAREHOUSE PHYSICAL LOADING & DISPATCH
  - Gatepass scanned at depot exit
  - Live transit monitoring across corridors
    │
    ▼
FAIR PRICE SHOP RECEIPT & BENEFICIARY DISTRIBUTION
  - Dealer verifies truck arrival and offloads grain bags
  - Beneficiaries lift quota with simulated biometric verification
    │
    ▼
CITIZEN RECEIPT CONFIRMATION / DISPUTE RESOLUTION
  - Beneficiary clicks "I Received My Ration" (or reports shortfall)
  - Permanent receipt recorded; beneficiary blocked from re-applying in current cycle
    │
    ▼
CYCLE EVALUATION & AUDIT TRAIL
  - Forecast vs. Actual offtake evaluation computed
  - Model weights calibrated for subsequent cycle
```

---

## 10. System Architecture: Modular Decomposition

To eliminate monolithic coupling, PDS-PREDICT is decomposed into 17 distinct functional modules:

```
┌────────────────────────────────────────────────────────────────────────┐
│                    PDS-PREDICT MODULAR ARCHITECTURE                    │
├──────────────────────────────────┬─────────────────────────────────────┤
│ 1. Beneficiary Portal (Flutter)  │ 2. Admin Command Center (Flutter)   │
│ 3. Auth & RBAC Engine            │ 4. Demand Signal Engine             │
│ 5. Planning Cycle State Machine  │ 6. Demand Snapshot & Sealing Engine │
│ 7. Multi-Factor Forecast Engine  │ 8. Warehouse Inventory Engine       │
│ 9. Scarcity & Allocation Engine  │ 10. Statutory Constraint Engine     │
│ 11. Fleet Optimization Engine    │ 12. Corridor Route Engine           │
│ 13. Manifest & Gatepass Engine   │ 14. Dispatch Monitoring Engine      │
│ 15. Exception & Delay Engine     │ 16. Governance Audit & Eval Engine  │
│ 17. Multi-Channel Notification   │                                     │
└──────────────────────────────────┴─────────────────────────────────────┘
```

1. **Beneficiary Portal:** Flutter client providing accessible, multilingual citizen service declaration, tracking, and confirmation.
2. **Admin Command Center:** High-density institutional dashboard for District Supply Officers with KPI analytics, geospatial views, and pipeline controls.
3. **Authentication & RBAC Engine:** JWT-based stateless security enforcing strict role boundaries (`CITIZEN_BENEFICIARY`, `DISTRICT_SUPPLY_OFFICER`, `DEPOT_MANAGER`, `FPS_DEALER`).
4. **Demand Signal Engine:** Ingests forward intent declarations, validates card entitlement ceilings, and manages location preferences.
5. **Planning Cycle Engine:** Deterministic state machine governing monthly timeline progression (Days 21–24 $\to$ Day 25 $\to$ Days 26–31).
6. **Demand Snapshot Engine:** Serializes canonical JSON demand baselines and computes immutable SHA-256 cryptographic seals.
7. **Forecast Engine:** Computes weighted composite demand projections combining historical time-series with locked forward intent signals.
8. **Inventory Engine:** Manages multi-depot available stocks, storage headroom, and grain commodity balances (Rice, Wheat).
9. **Scarcity & Allocation Engine:** Enforces mathematical fair-share rationing policies when depot stock deficits occur.
10. **Statutory Constraint Engine:** Deterministic rule validator enforcing 9 non-negotiable food security and logistics invariants.
11. **Fleet Optimization Engine:** Solves Capacitated Vehicle Routing / TSP problems across regional delivery corridors.
12. **Route Engine:** Calculates road network distances, travel durations, and corridor geofences.
13. **Manifest & Gatepass Engine:** Binds trucks, drivers, commodities, and destination shops into sealed digital loading sheets.
14. **Dispatch Monitoring Engine:** Tracks vehicle transit milestones, arrival timestamps, and offloading confirmations.
15. **Exception & Delay Engine:** Manages stockout alerts, mechanical breakdowns, and official 1–2 day delay broadcasts.
16. **Evaluation & Audit Engine:** Measures forecast accuracy ($R^2$, MAPE), logs immutable governance events, and maintains forensic audit trails.
17. **Notification Layer:** Multi-channel broadcast service (WhatsApp, SMS, IVR simulation) dispatching arrival and delay notices.

---

## 11. Machine Learning Architecture: Decision Support, Not Autonomous Dispatch

### 11.1 The Machine Learning Boundary
A fundamental principle of public food governance:
> **Machine Learning MUST NEVER autonomously trigger physical grain dispatch.**

In PDS-PREDICT, prediction is purely an **advisory input**. Deterministic statutory constraint rules act as hard safety boundaries, and mathematical optimization generates feasible recommendations.

```
┌───────────────────────────┐     ┌───────────────────────────┐
│ Historical Consumption    │     │ Locked Citizen Signals    │
│ (Past 6 Monthly Cycles)   │     │ (Day 25 Frozen Baseline)  │
└─────────────┬─────────────┘     └─────────────┬─────────────┘
              │                                 │
              └───────────────┬─────────────────┘
                              ▼
                ┌───────────────────────────┐
                │  Multi-Factor Demand ML   │
                │  D̂ = w1·H + w2·I + w3·S   │
                └─────────────┬─────────────┘
                              ▼
                ┌───────────────────────────┐
                │  Statutory Rule Engine    │  ◄── 9 Invariant Hard Constraints
                │  (Deterministic Pass/Fail)│      (Stock, Capacity, Ceilings)
                └─────────────┬─────────────┘
                              ▼
                ┌───────────────────────────┐
                │ Fleet Optimization Engine │  ◄── OR-Tools / TSP Solver
                │ (Capacitated Allocation)  │
                └─────────────┬─────────────┘
                              ▼
                ┌───────────────────────────┐
                │ Authorized Dispatch Plan  │  ◄── Requires DSO Approval
                └───────────────────────────┘
```

### 11.2 Demand Formulation
$$\hat{D}_{f, c} = w_1 \cdot H_{f, c} + w_2 \cdot I_{f, c} + w_3 \cdot S_f \cdot H_{f, c} + w_4 \cdot P_f \cdot H_{f, c}$$
Where:
- $H_{f, c}$: Historical rolling average consumption for FPS $f$ and commodity $c$.
- $I_{f, c}$: Locked forward intent signal aggregated on Day 25.
- $S_f$: Seasonal festival / holiday adjustment factor ($0.95 \le S_f \le 1.25$).
- $P_f$: Portability migration inflow factor ($0.0 \le P_f \le 0.40$).
- Weights $w_1, w_2, w_3, w_4$: Dynamically calibrated monthly based on minimum mean absolute percentage error (MAPE).

---

## 12. Statutory & Operational Constraints (9 Invariants)

Every proposed dispatch must satisfy all 9 non-negotiable invariants before manifest generation:

| Invariant | Name | Mathematical / Operational Rule | Violation Action |
|:---:|---|---|---|
| **INV-01** | **Depot Stock Non-Negativity** | $\sum_{f} \text{Allocated}_{f, c} \le \text{StockAvailable}_{\text{depot}, c}$ | Block dispatch; trigger Scarcity Allocation |
| **INV-02** | **FPS Storage Capacity Ceiling** | $\text{StockCurrent}_f + \text{DispatchProposed}_f \le \text{Capacity}_{\text{max}, f}$ | Cap dispatch; reallocate excess to buffer godown |
| **INV-03** | **Vehicle Payload Compliance** | $\sum_{f \in \text{Route}} \text{Load}_{f} \le \text{MaxPayload}_{\text{truck}}$ ($10,000\text{ kg}$) | Split route; allocate additional carrier |
| **INV-04** | **Statutory Food Security Floor** | $\text{Allocated}_{f, c} \ge 0.85 \times \text{StatutoryEntitlement}_{f, c}$ | Rejection forbidden; minimum floor guaranteed |
| **INV-05** | **Citizen Quota Ceiling** | $\text{DeclaredQty}_i \le \text{Members}_i \times 5.0\text{ kg}$ | Reject declaration at API gateway with HTTP 422 |
| **INV-06** | **Day 25 Demand Freeze** | $\Delta \text{Preference} = 0 \quad \forall \text{ Cycle Day } \ge 25$ | Reject mutation; return HTTP 400 Bad Request |
| **INV-07** | **Single Cycle Receipt Enforce** | $\text{Receipts}(\text{Ben}_i, \text{Cycle}_k) \le 1$ | Reject subsequent intent with HTTP 400 |
| **INV-08** | **Digital Gatepass Seal** | $\text{Seal} = \text{SHA256}(\text{ManifestPayload}) \ne \emptyset$ | Truck cannot pass warehouse gate without valid seal |
| **INV-09** | **Tamper-Evident Audit Trace** | $\text{AuditLog}(\text{Action}) \quad \forall \text{ State Transitions}$ | Unlogged mutations fail transaction commit |

---

## 13. Fairness & Scarcity Allocation Mechanism

When government central depots experience unexpected grain shortfalls (e.g., procurement delays or rail transit disruptions), the system **DOES NOT** penalize isolated or peripheral FPS shops to optimize transport efficiency.

### Fair-Share Rationing Model
1. **Protected Statutory Floor:** Every FPS receives a mandatory statutory minimum floor ($85\%$ of baseline).
2. **Proportional Deficit Sharing:** Any unavoidable deficit is distributed equitably based on active household counts, ensuring no single FPS experiences complete stockout.
3. **Transparent Notification:** The system explicitly notifies Fair Price Shop dealers and beneficiaries of temporary quota reductions, with automated priority replenishment scheduled for the subsequent cycle.

---

## 14. Government Entitlement & Biometric Simulation

### 14.1 Authoritative Entitlement Derivation
- Beneficiaries **CANNOT** arbitrarily enter grain quantities in the UI.
- Quotas are derived server-side strictly from government card categories:
  - **Priority Household (PHH):** $5\text{ kg}$ per family member per month ($4\text{ members} = 16\text{ kg Rice} + 4\text{ kg Wheat} = 20\text{ kg Total}$).
  - **Antyodaya Anna Yojana (AAY):** Fixed statutory allocation of $35\text{ kg}$ per household ($25\text{ kg Rice} + 10\text{ kg Wheat}$).
- The UI displays entitlement as verified read-only institutional data.

### 14.2 Privacy-Preserving Biometric Simulation
- In real-world PDS, physical distribution requires biometric authentication via e-PoS fingerprint/iris scanners.
- For prototype demonstrations, biometric handover is **strictly simulated**:
  - The UI presents an interactive biometric scanning modal for FPS dealer pickup and doorstep delivery.
  - **ZERO raw biometrics (fingerprints, images, templates) are captured or stored.**
  - Verification uses a mock cryptographic authorization token to demonstrate operational workflow without privacy violations.

---

## 15. Target Database Architecture & Entity Schema

The target production schema is structured for **PostgreSQL with PostGIS extensions** (local development supports SQLite with WAL mode):

```
┌────────────────────────────────────────────────────────────────────────┐
│                        CORE ENTITY RELATIONSHIPS                       │
│                                                                        │
│  BENEFICIARIES ──◄ INTENT ──► FAIR_PRICE_SHOPS ──► INVENTORY           │
│       │               │              ▲                                 │
│       │               ▼              │                                 │
│       ├─────────► CITIZEN_REQUESTS ──┤                                 │
│       │                              │                                 │
│       ▼                              ▼                                 │
│  BENEFICIARY_CYCLE_RECEIPTS     DEMAND_SNAPSHOTS                       │
│                                      │                                 │
│                                      ▼                                 │
│  VEHICLES ──◄ DISPATCH_MANIFESTS ──► FORECASTS                         │
│       ▲               │                                                │
│       │               ▼                                                │
│  DEPOTS ◄────── MANIFEST_ITEMS ──► GOVERNANCE_AUDIT_LOGS               │
└────────────────────────────────────────────────────────────────────────┘
```

### Core Entity Definitions
1. `beneficiaries`: Pseudonymous citizen IDs, card types (PHH/AAY), family size, registered FPS, language preference.
2. `fps`: Fair Price Shop locations (Lat/Lng), storage capacities (kg), historical stockout rates, regional corridors.
3. `depots`: Central FCI godowns, commodity bulk reserves (Rice/Wheat MT), daily loading throughput.
4. `planning_cycles`: Cycle identifiers (`2026-09`), planning day ($1 \dots 31$), status flags (`CHOICE_WINDOW_OPEN`, `DEMAND_LOCKED`).
5. `intent`: Forward-looking citizen declarations for cycle, intended FPS, commodity, and service mode.
6. `citizen_requests`: Formal review queue tracking officer approvals, redirections, and transport fee breakdowns.
7. `beneficiary_cycle_receipts`: **Durable receipt ledger** tracking receipt confirmations, timestamps, and blocking duplicate requests per cycle.
8. `demand_snapshots`: Immutable Day 25 baseline aggregates, serialized demand vectors, and SHA-256 seals.
9. `forecasts`: Statistical demand forecasts per FPS, commodity, and cycle, with factor breakdowns.
10. `vehicles`: Fleet inventory, truck models, payload ceilings ($10,000\text{ kg}$), operating cost/km, assigned corridors.
11. `routes`: Corridor stops, sequenced FPS waypoints, road distances, and estimated travel times.
12. `manifests`: Cryptographically sealed loading sheets, assigned truck IDs, total tonnage, and gatepass hashes.
13. `manifest_items`: Line-item grain allocations per destination Fair Price Shop.
14. `delivery_disputes`: Citizen-reported shortfall disputes, forensic metrics, and officer resolution logs.
15. `governance_audit_logs`: Append-only, tamper-evident record of all administrative actions and lifecycle transitions.

---

## 16. Target REST API Architecture

All endpoints follow RESTful conventions under `/api/v1`:

```
/api/v1/auth
  POST   /login                           -> Authenticate user (Citizen / Officer)
  POST   /logout                          -> Revoke token session

/api/v1/beneficiary
  GET    /{id}                            -> Retrieve profile & registered FPS
  GET    /{id}/entitlement-summary        -> Authoritative statutory quota & receipt status
  GET    /{id}/delivery-records           -> Order lifecycle tracking & timeline status
  POST   /{id}/confirm-delivery           -> "I Received My Ration" receipt & dispute action

/api/v1/planning-cycle
  GET    /status                          -> Public query for active day & choice window state
  POST   /advance-day                     -> Administrative day advancement (Days 21-25)

/api/v1/intent
  POST   /                                -> Submit/update monthly forward preference signal
  GET    /list                            -> Query declared intent signals (filtered by cycle/FPS)

/api/v1/admin
  GET    /dashboard                       -> Aggregate district KPIs, demand summary, FPS matrix
  POST   /choice-window/close             -> Trigger Day 25 Demand Lock & generate SHA-256 seal
  GET    /demand-snapshot                 -> Retrieve frozen baseline snapshot & cryptographic hash
  POST   /pipeline/run                    -> Execute 4-stage Pre-Dispatch Intelligence Pipeline
  GET    /citizen-requests                -> Review queue with 8 filtered state tabs
  POST   /citizen-requests/{id}/authorize -> DSO decision (Approve, Partial Floor, Redirect, Defer)
  POST   /dispatch/delay                  -> Apply temporary 1-2 day stock delay
  POST   /dispatch/resume                 -> Resume logistics once buffer stock arrives
  POST   /manifests/{id}/lock             -> Lock loading manifest and seal Digital Gatepass
  GET    /audit-trail                     -> Query immutable governance audit events
  GET    /evaluation                      -> Compute forecast vs. actual offtake accuracy metrics
```

---

## 17. Frontend Architecture: Two Distinct Portals

### 17.1 Beneficiary Portal (Citizen-Facing)
- **Design Aesthetic:** High-clarity, high-contrast, accessible typography with large touch targets.
- **Trilingual Localization:** Reactive switching between English, Hindi, and Kannada without page reload.
- **Core Screens:**
  1. *Citizen Home:* Displays verified ration card header, family quota card, and active delivery timeline.
  2. *Plan Collection (Service Choice):* Two primary options: Free FPS Self-Collection vs. Assisted Doorstep Delivery.
  3. *Portability Selection:* Interactive FPS finder with live distance calculation and capacity status.
  4. *Order Review & Submission:* Transparent fee audit (₹0 grain cost + distance fee) and statutory notice.
  5. *Receipt State (Post-Confirmation):* Replaces application controls with a clear status banner:
     > **"Ration Received — Wait for Next Cycle"**  
     > *"You have already received your ration for the current cycle. Please wait until the next distribution cycle."*

### 17.2 Admin Command Center (Institutional / DSO-Facing)
- **Design Aesthetic:** High-density institutional dashboard (dark navy palette `#1E293B`, crisp metric cards, real-time indicators).
- **Core Views:**
  1. *District Logistics KPIs:* Active declared intent vs. historical baseline vs. recommended dispatch.
  2. *Planning Timeline Stepper:* Day 21–24 Choice Window active status $\to$ Day 25 Demand Lock trigger.
  3. *Citizen Review Queue:* Tabbed adjudication interface for officer reviews, partial quotas, and dispute cases.
  4. *Pre-Dispatch Analysis Dialog:* 4-stage sequential execution modal (Forecast $\to$ Validate $\to$ Optimize $\to$ Manifest).
  5. *Corridor Optimization Map:* Geospatial visualization of 4 vehicle corridors with live simulated GPS telemetry.
  6. *Digital Gatepass Modal:* QR code verification viewer with SHA-256 cryptographic proof.
  7. *Readiness & Broadcast Center:* Multi-channel WhatsApp/SMS dealer broadcast and citizen delay alert tools.

---

## 18. Hackathon MVP: The 15 Must-Have Features

For a winning hackathon demonstration, the following 15 features represent the mandatory core loop:

1. **Persona-Based Login:** Instant access as Beneficiary (`BEN-KA-0001`) or District Supply Officer (`dso_admin`).
2. **Trilingual Localization:** English, Hindi, Kannada reactive toggling across all screens.
3. **Household Entitlement Calculator:** Automatic $N \times 5\text{ kg}$ computation from card type.
4. **Day 21–24 Choice Window:** Free citizen preference submission and portability FPS selection.
5. **Real-Time Demand Aggregation:** Live aggregation of citizen signals on DSO dashboard.
6. **Day 25 Demand Lock:** Administrative button sealing demand into an immutable snapshot.
7. **SHA-256 Snapshot Seal:** Cryptographic hash generation and verification modal.
8. **Post-Lock Beneficiary Rejection:** Automatic backend rejection of preference edits after lock.
9. **Multi-Factor Forecasting:** Composite demand projection blending intent with history.
10. **9-Invariant Statutory Constraint Audit:** Automated verification of depot stock, FPS space, and truck capacity.
11. **Capacitated Corridor Optimization:** Multi-stop vehicle routing across 4 fleet corridors.
12. **Sealed Digital Gatepass:** Cryptographic manifest with QR code and driver trip ticket.
13. **Stock Shortage Delay Workflow:** 1–2 day delay simulation with citizen delay banner.
14. **Biometric Handover Simulation:** Privacy-preserving simulated fingerprint scan at delivery.
15. **Receipt Confirmation Rule:** "I Received My Ration" action recording durable receipt and blocking repeat applications.

---

## 19. Secondary Features (Deferred to Post-MVP)

The following capabilities are architecturally designed but deferred until the core loop is fully verified:
- Real-time WhatsApp Business API integration (mocked in prototype).
- Interactive Voice Response (IVR) telephony gateway for basic feature phones.
- Advanced machine learning anomaly detection (outlier fraud detection).
- Live physical IoT GPS hardware tracking (simulated in prototype).
- Multi-district inter-state ONORC settlement clearing engine.

---

## 20. Security, Privacy & Integrity Architecture

1. **Authentication & Session Security:** Stateless JWT tokens signed with HMAC-SHA256, strictly validated per request.
2. **Zero Raw Biometric Storage:** No citizen fingerprints, minutiae points, or biometric templates are captured, transmitted, or stored.
3. **Tamper-Evident Demand Snapshot:** The Day 25 baseline is hashed using SHA-256; any database modification invalidates the hash.
4. **Single Source of Truth Backend:** All business rules (choice window, lock day, single receipt) are enforced at the API layer, never relying on client-side state.
5. **Append-Only Audit Trail:** Administrative decisions write irreversible records to `governance_audit_logs`.
6. **CORS & Input Hardening:** Strict origin filtering, Pydantic data validation, and parameter sanitization preventing injection attacks.

---

## 21. Testing Strategy & Verification Pipeline

```
┌────────────────────────────────────────────────────────────────────────┐
│                      PDS-PREDICT TEST HARNESS                          │
├────────────────────┬────────────────────┬──────────────────────────────┤
│ 1. Pytest Suite    │ 2. Flutter Analyze │ 3. Automated E2E Flow        │
│    284 Unit/API    │    Zero Lint /     │    Beneficiary -> Day 25 -> │
│    Contract Tests  │    Type Errors     │    Manifest -> Receipt       │
└────────────────────┴────────────────────┴──────────────────────────────┘
```

### Critical End-to-End Test Journey:
1. Citizen logs in during Days 21–24 $\to$ submits FPS portability preference.
2. DSO opens dashboard $\to$ advances cycle to Day 25 $\to$ executes Demand Lock.
3. Citizen attempts to modify FPS preference $\to$ API rejects with HTTP 400 Bad Request.
4. DSO runs Pre-Dispatch Pipeline $\to$ Forecast generated $\to$ Constraints verified $\to$ Manifest sealed with SHA-256.
5. Delivery simulated $\to$ Beneficiary clicks "I Received My Ration".
6. Beneficiary attempts direct API request $\to$ API rejects with *"Ration already received for this cycle"*.

---

## 22. End-to-End Demo Scenario for Judges

### The Bengaluru Urban Pilot Scenario:
- **Location:** Bengaluru Urban District (Central Depot: Hebbal FCI Godown; 20 Fair Price Shops).
- **The Challenge:** Peenya Industrial Area (`FPS-KA-BLR-004`) faces an influx of 180 migrant workers exercising ONORC portability, while Malleshwaram (`FPS-KA-BLR-001`) has stable demand.
- **The Walkthrough:**
  1. *Step 1 (Citizen Signal):* Migrant worker Sunita Devi opens the portal in Kannada, selects Peenya FPS, and submits her preference for 25 kg grain during Day 22.
  2. *Step 2 (DSO Dashboard):* DSO Srinivas Murthy reviews the dashboard; Peenya reflects a +38% demand surge.
  3. *Step 3 (Day 25 Lock):* DSO advances the day to 25 and locks demand. An immutable SHA-256 snapshot is generated.
  4. *Step 4 (Pre-Dispatch Pipeline):* DSO clicks "Run Pre-Dispatch Analysis". The system validates stock, recalculates Peenya's truck payload from 6 MT to 9.2 MT, and generates Corridor 1 manifest.
  5. *Step 5 (Digital Gatepass):* A sealed digital gatepass with QR code is generated for Truck `DEMO-KA-04-E-1021`.
  6. *Step 6 (Handover & Receipt):* The truck completes delivery. Beneficiary confirms receipt. The portal transitions to *"Ration Received — Wait for Next Cycle"*.

---

## 23. Failure Scenarios & Explainable Responses

The system handles real-world supply chain anomalies with explainable, policy-compliant outcomes:

1. **Central Godown Stock Shortage:**
   - *Behavior:* Pipeline pauses at VALIDATE stage; informs DSO of deficit; offers "Delay Dispatch (1–2 Days)" option; broadcasts reassuring SMS to citizens; never cancels entitlement.
2. **FPS Storage Capacity Exceeded:**
   - *Behavior:* Detects that destination shop headroom is $< 10\%$; caps delivery to maximum safe storage; diverts remainder to secondary buffer node.
3. **Vehicle Gross Payload Violation:**
   - *Behavior:* Detected payload $> 10,000\text{ kg}$; splits corridor load across two carrier trucks automatically.
4. **Post-Lock Citizen Mutation Attempt:**
   - *Behavior:* Returns HTTP 400 with explanation: *"Choice window closed. Demand is permanently locked into dispatch logistics."*
5. **Post-Receipt Duplicate Claim Attempt:**
   - *Behavior:* Returns HTTP 400 with explanation: *"Ration already received for this cycle. Please wait for the next distribution cycle."*
6. **En-Route Mechanical Breakdown:**
   - *Behavior:* Driver flags incident; DSO control center marks vehicle `IN_MAINTENANCE` and generates emergency replacement haulier.
7. **Delivery Quantity Dispute:**
   - *Behavior:* Citizen reports weighment deficit; system logs dispute, flags dealer record, and forwards case to DSO forensic review queue.

---

## 24. Real System Metrics (No Fabricated Impact Claims)

PDS DemandSync evaluates operational performance through measurable engineering telemetry:

| Category | Metric Name | Definition & Formula |
|---|---|---|
| **Demand Precision** | **MAPE (Mean Absolute Percentage Error)** | $\frac{1}{N} \sum \left\| \frac{\text{Actual} - \text{Forecast}}{\text{Actual}} \right\| \times 100$ |
| **Logistics Integrity** | **Manifest Variance Rate** | Difference between sealed manifest tonnage and counter disbursement |
| **Pre-Dispatch Safety** | **Exception Interception Rate** | Number of capacity/over-payload violations caught before truck exit |
| **Fleet Efficiency** | **Average Vehicle Utilization (%)** | $\frac{\text{Actual Payload Carried}}{\text{Vehicle Rated Capacity}} \times 100$ |
| **Citizen Governance**| **Choice Window Participation Rate** | Percentage of active cardholders declaring advance preferences |
| **Cycle Timeliness** | **Planning Resolution Duration** | Elapsed time from Day 25 demand lock to sealed manifest completion |
| **Dispute Auditing** | **Dispute Reconciliation Time** | Hours taken for DSO to resolve citizen shortfall complaints |

---

## 25. Current Prototype Status: Ground-Truth Audit

An honest, rigorous audit of the current prototype implementation:

| Functional Area | Current Status | Implemented Details |
|---|:---:|---|
| **Beneficiary Authentication** | **IMPLEMENTED** | JWT session authentication with verified demo personas |
| **Trilingual Localization** | **IMPLEMENTED** | Reactive English, Hindi, and Kannada switching across UI |
| **Household Quota Derivation** | **IMPLEMENTED** | Server-enforced $N \times 5\text{ kg}$ statutory calculation |
| **Day 21–24 Choice Window** | **IMPLEMENTED** | Real-time state query, open window validation, preference submission |
| **Day 25 Demand Lock** | **IMPLEMENTED** | DSO lock button, immutable snapshot storage, SHA-256 seal |
| **Post-Lock Modification Guard**| **IMPLEMENTED** | Rejection of edits after lock at backend API gateway |
| **Post-Receipt Re-Apply Guard** | **IMPLEMENTED** | Durable receipt table, single-cycle enforcement, UI locked banner |
| **Multi-Factor Forecasting** | **IMPLEMENTED** | Linear composite engine blending intent, history, seasonality, portability |
| **Statutory Constraint Audit** | **IMPLEMENTED** | 9 invariant mathematical checks across stock, storage, and vehicles |
| **Fleet Route Optimization** | **IMPLEMENTED** | Multi-stop TSP corridor sequencing for 4 truck routes |
| **Digital Gatepass & QR** | **IMPLEMENTED** | SHA-256 manifest hash calculation with modal viewer |
| **Stock Shortage Delay Flow** | **IMPLEMENTED** | Scenario B pause, 1–2 day delay transition, citizen alert card |
| **Biometric Simulation Modal** | **IMPLEMENTED** | Client-side mock fingerprint sensor dialog (zero raw biometric storage) |
| **Citizen Review Queue** | **IMPLEMENTED** | DSO queue with 8 filtered tabs and 4 officer authorization actions |
| **Full Backend Test Suite** | **IMPLEMENTED** | **284 automated tests passing (100% pass rate)** |
| **Flutter Web Build** | **IMPLEMENTED** | Compiles cleanly to production web bundle |
| **Real WhatsApp/SMS Gateway** | **PARTIAL** | Mocked in notification engine with operational telemetry |
| **Live Physical GPS Hardware** | **PARTIAL** | Simulated real-time coordinate movement along corridors |
| **PostgreSQL / PostGIS** | **PARTIAL** | SQLite3 (WAL mode) used for local prototype; schema ready for Postgres |

---

## 26. Hackathon Target Architecture vs. Current Prototype

```
┌─────────────────────────────────┐     ┌─────────────────────────────────┐
│       CURRENT PROTOTYPE         │     │    HACKATHON TARGET (CLEAN)     │
├─────────────────────────────────┤     ├─────────────────────────────────┤
│ • SQLite with WAL Mode          │     │ • PostgreSQL with PostGIS       │
│ • Monolithic API Routers        │ ──► │ • Clean Domain-Driven Services  │
│ • Local In-Memory Timers        │     │ • Distributed Worker Queue      │
│ • CanvasKit Web Compilation     │     │ • Optimized Responsive Flutter  │
│ • Synthetic Bengaluru Dataset   │     │ • Multi-District Modular Seed   │
└─────────────────────────────────┘     └─────────────────────────────────┘
```

The next hackathon development phase will cleanly separate the core decision pipeline from UI presentation layers, providing hardened database constraints, asynchronous worker queues, and clean micro-service boundaries.

---

## 27. Technology Stack

Only technologies actually implemented and planned for the baseline:

- **Frontend Application:** Flutter (Dart 3.x), targeting Web and Mobile, using Provider / InheritedWidget architecture with zero external CSS frameworks.
- **Backend Service:** Python 3.12+ with FastAPI, Pydantic v2 schemas, and Uvicorn ASGI server.
- **Database Layer:** 
  - *Current Prototype:* SQLite3 with Write-Ahead Logging (WAL) and enforced foreign keys (`PRAGMA foreign_keys = ON`).
  - *Target Architecture:* PostgreSQL 16+ with PostGIS spatial extension.
- **Optimization Engine:** Google OR-Tools (Capacitated Vehicle Routing Problem / TSP).
- **Machine Learning & Analytics:** Python NumPy, Pandas, Scikit-learn (Ridge Regression, Gradient Boosting).
- **Security & Cryptography:** Python `hashlib` (SHA-256 canonical digest), `pyjwt` (JSON Web Tokens).
- **Testing Frameworks:** Pytest 9.x, `pytest-asyncio`, `httpx` ASGI test client, Flutter Test framework.
- **Version Control & Repository:** Git with GitHub remote (`https://github.com/Prajwal20p6/PDS.git`).

---

## 28. Core Engineering & Development Principles

1. **Core Workflow Before Secondary Features:** Never allow peripheral features (WhatsApp, voice bots, decorative charts) to distract from the core loop: *Signal $\to$ Lock $\to$ Validate $\to$ Manifest $\to$ Confirm*.
2. **Backend is Single Source of Truth:** Never trust client-side state. Every permission, calculation, and constraint is authoritatively enforced by the API.
3. **No Fake UI State:** If the backend rejects an action, the UI must accurately reflect the failure with explainable feedback.
4. **Deterministic Constraints Around ML:** AI models predict; deterministic rules approve; optimization schedules. ML never holds unilateral dispatch authority.
5. **Immutability of Demand Snapshots:** Once Day 25 arrives, demand is cast in stone. The cryptographic seal guarantees auditability.
6. **Cycle-Specific Rules:** Restrictions (such as post-receipt locks) are scoped strictly to the current cycle. Citizens participate fresh when the new calendar month begins.
7. **Complete Auditability:** Every administrative modification leaves an immutable forensic log.

---

## 29. Technical Defense: Anticipated Judge Questions & Defensible Answers

### Q1: "Why is this needed if ONORC (One Nation One Ration Card) already exists?"
**Answer:** ONORC solves the *statutory right* to lift grain anywhere in India, but it creates a severe *physical supply chain vulnerability*. ONORC transactions occur at the e-PoS counter on the spot. If 200 migrant workers show up at a shop that only stocked grain for 50 local families, the shop stocks out in hours. ONORC clears the transaction; PDS-PREDICT coordinates the grain *before the truck departs*.

### Q2: "Why is this needed if route optimization software already exists?"
**Answer:** Commercial route optimization focuses on *how to drive the truck between stops*. It assumes the cargo inside the truck is already correct. In PDS, if the truck is carrying 40 bags of rice to a shop that actually needs 90 bags due to migration, finding the shortest driving route is useless. PDS-PREDICT optimizes *what goes into the truck* based on locked citizen signals.

### Q3: "Why use Machine Learning instead of simply adding up declared intent?"
**Answer:** Citizen participation in voluntary portals is never 100%. In practice, 30–60% of citizens declare active preferences during the choice window. The ML model takes these active signals as high-confidence sample vectors and composites them with historical rolling consumption, seasonal festival surges, and local portability trends to forecast the complete 100% demand baseline accurately.

### Q4: "What happens when the prediction is wrong?"
**Answer:** The system is protected by 9 invariant safety constraints. Most importantly, Invariant 04 guarantees a statutory minimum floor ($85\%$ of card entitlement) to every shop regardless of forecast errors. Furthermore, buffer depots hold contingency stocks, and forecast-vs-actual evaluations run monthly to calibrate model weights continuously.

### Q5: "What happens when government godowns have insufficient stock?"
**Answer:** The system executes the policy-compliant **Stock Shortage Workflow**. Unlike commercial delivery apps that cancel orders, PDS DemandSync halts dispatch, transitions orders to `DELAYED (1–2 Days)`, broadcasts official delay notices, and guarantees citizen quota preservation until buffer replenishment arrives.

### Q6: "Can a beneficiary alter their quota after Day 25?"
**Answer:** No. On Day 25, the Demand Lock freezes all preferences into an immutable SHA-256 sealed snapshot. Any post-lock edit attempt is rejected at the API gateway with HTTP 400 Bad Request.

### Q7: "How is beneficiary privacy protected during biometric simulation?"
**Answer:** The platform adheres to zero-knowledge privacy principles. The biometric verification modal demonstrates counter handover using a mock client-side authorization token. No fingerprints, images, or biometric minutiae are ever captured, transmitted, or stored.

### Q8: "How does a state government deploy this alongside existing legacy portals?"
**Answer:** PDS-PREDICT operates as an augmentation layer via read-only APIs. It extracts registered household data from state food portals, runs the pre-dispatch decision cycle during Days 21–25, and pushes approved loading manifests into existing depot management systems without altering core e-PoS or NIC infrastructure.

---

## 30. Final Core Principle

> **"The product is not the prediction model alone. The product is the pre-dispatch decision chain that turns beneficiary demand signals into a validated, optimized and auditable dispatch plan before physical movement."**

---
*End of Master Project Specification — PDS DemandSync Prototype Baseline v0.1*
