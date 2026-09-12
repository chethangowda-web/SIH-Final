# Implementation Plan: 6 Essential Feature Enhancements for PDS DemandSync

This document outlines the detailed architecture, database updates, backend services, and frontend UI components to implement the 6 key capabilities requested for **PDS DemandSync**.

---

## 📋 Comprehensive Analysis & Proposed Implementation

### 1. 💬 Feedback Mechanism (Officer $\leftrightarrow$ Beneficiary & Officer $\leftrightarrow$ FPS Dealer)
- **Problem**: Lack of a 2-way feedback loop between DSO Officers and Citizens/Dealers.
- **Proposed Architecture**:
  - **Citizen $\rightarrow$ Officer Feedback**: Ration card holders can submit feedback, delivery rating, short-weight complaints, or shop closure reports from the Beneficiary portal.
  - **FPS Dealer $\rightarrow$ Officer Feedback**: FPS dealers can log storage damage, early stockout warnings, or transport delay reports.
  - **Officer Triage Portal**: Integrated **"District Feedback & Dispute Management"** tab on the Admin Dashboard allowing Officers to review, reply, assign priority, and resolve feedback items with automated status updates back to the sender.

---

### 2. 🔗 Direct Officer $\leftrightarrow$ Beneficiary Communication Link
- **Problem**: No direct connection/ticket link between District Supply Officers and citizens.
- **Proposed Architecture**:
  - **Direct Citizen Support Line / Case Ticket System**:
    - Links pseudonymous card ID directly to DSO case queues.
    - Enables citizens to check live status (`RECEIVED` $\rightarrow$ `UNDER_OFFICER_REVIEW` $\rightarrow$ `ACTION_TAKEN` / `RESOLVED`).
    - Gives DSO officers 1-click ability to send broadcast or direct SMS/WhatsApp notifications to specific cardholders regarding their requests or entitlement issues.

---

### 3. 🛡️ Multi-Point AI Fraud & Diversion Detection System
- **Problem**: Preventing grain diversion, ghost card intent manipulation, and black-market hoarding.
- **Proposed Architecture**:
  - Extend [anomaly_engine.py](file:///d:/SIH%20FINAL/backend/app/services/anomaly_engine.py) to run real-time checks across 4 operational touchpoints:
    1. **Ghost Card Intent Clustering Fraud**: Flags rapid suspicious intent submissions originating from identical IPs or unusual hours.
    2. **Hoarding & Black-Market Diversion Risk**: Flags FPS dealers reporting frequent stockouts despite receiving 100%+ allocation.
    3. **ePoS Biometric Shortfall Discrepancy**: Flags shops where ePoS biometric lifting logs mismatch declared citizen receipts.
    4. **Depot Weighbridge Tamper Fraud**: Compares vehicle tare weight against gatepass manifest.
  - **UI Widget**: Add an **"AI Fraud & Diversion Shield"** modal on the Admin Dashboard with 1-click **"Freeze Allocation"** or **"Dispatch Audit Team"** options.

---

### 4. 🚚 Route Checking & GPS Location Reached Verification
- **Problem**: No real-time verification of whether a dispatch truck has arrived at the correct FPS location.
- **Proposed Architecture**:
  - Extend [vrp_solver.py](file:///d:/SIH%20FINAL/backend/app/services/vrp_solver.py) and [routing.py](file:///d:/SIH%20FINAL/backend/app/api/routing.py):
    - Compute real-time Haversine distance between truck GPS telemetry and assigned target FPS coordinates.
    - **Geofence Arrival Trigger**: Automatically status update to **`ARRIVED_AT_TARGET_FPS`** when truck is within 100m radius of target shop.
    - **Route Deviation Alert**: Throws **`UNAUTHORIZED_LOCATION_STOP`** if truck deviates >2 km off optimized VRP corridor or offloads grain at an unassigned location.
  - **UI Component**: Interactive **"Live Truck Route & Geofence Tracker"** map view on the Admin Dashboard.

---

### 5. 🎛️ Officer Manual Override & Administrative Controls
- **Problem**: Officers need full flexibility to modify quotas, dispatch quantities, buffers, and truck assignments.
- **Proposed Architecture**:
  - Add an **"Officer Manual Override & Quota Adjustment"** panel across Admin Dashboard FPS rows, Forecast Detail, and Dispatch Decision screens.
  - Officers can override:
    1. Base Rice/Wheat allocation quantity ($\text{kg}$).
    2. Safety Buffer percentage ($0\% - 30\%$).
    3. Fleet Carrier Truck assignment.
    4. Priority Status (`NORMAL` $\rightarrow$ `EMERGENCY_OVERRIDE`).
  - Automatically log all manual adjustments into the immutable `governance_trail` audit table.

---

### 6. 🤖 AI Pre-Dispatch Stock Headroom Advisor & Automated Shortage Notifications
- **Problem**: AI must check Godown stock availability before dispatch and automatically notify stakeholders if stock is insufficient.
- **Proposed Architecture**:
  - **AI Pre-Dispatch Stock Headroom Check**:
    - During Stage 1 & Stage 3 pre-dispatch evaluation, the AI engine compares central godown inventory against aggregated district demand.
    - If $\text{Godown Stock} < \text{Required Demand}$, AI flags **`CRITICAL_STOCK_DEFICIT_DETECTED`** and calculates max achievable allocation.
  - **Automated Multi-Channel Notification Engine**:
    - Automatically sends SMS / WhatsApp / System alerts to affected FPS dealers and beneficiaries:
      > *"⚠️ PDS DemandSync Notice: Stock availability deficit detected at Central FCI Depot. Allocation adjusted. Estimated dispatch delay: 1-2 days."*

---

## 🛠️ Proposed File Changes

### Backend
- **[NEW] `backend/app/api/feedback.py`**: Endpoints for Citizen/Dealer feedback submission (`POST /api/feedback`), DSO triage (`GET /api/feedback/list`), and resolution (`POST /api/feedback/{id}/resolve`).
- **[MODIFY] `backend/app/api/intent.py`**: Add fraud detection checks during intent submission.
- **[MODIFY] `backend/app/services/anomaly_engine.py`**: Add multi-point fraud detection algorithms (Ghost intent, Hoarding, Weighbridge mismatch).
- **[MODIFY] `backend/app/services/ai_request_advisor.py`**: Implement AI Pre-Dispatch Stock Availability check & deficit notification trigger.
- **[MODIFY] `backend/app/api/routing.py`**: Add `/api/routing/verify-arrival` GPS geofence checker.
- **[MODIFY] `backend/app/api/admin.py`**: Add Officer Manual Override endpoint `/api/admin/fps/{id}/override`.

### Frontend
- **[NEW] `frontend/lib/widgets/feedback_triage_dialog.dart`**: Officer <-> Beneficiary <-> FPS Feedback & Dispute management modal.
- **[NEW] `frontend/lib/widgets/fraud_shield_dialog.dart`**: AI Fraud Detection & Diversion Alert dashboard dialog.
- **[NEW] `frontend/lib/widgets/truck_geofence_tracker_dialog.dart`**: Route checking & target location arrival verification map modal.
- **[MODIFY] `frontend/lib/screens/admin/fps_dispatch_decision_dialog.dart`**: Add Officer Manual Override controls.
- **[MODIFY] `frontend/lib/screens/admin/admin_dashboard_screen.dart`**: Add Feedback, Fraud Shield, Route Checking, and AI Stock Check triggers.
- **[MODIFY] `frontend/lib/screens/beneficiary/beneficiary_home_screen.dart`**: Add Citizen Feedback & Support Ticket submission form.

---

## 🧪 Verification & Test Plan

1. **Automated Backend Tests**:
   - Write pytest cases in `backend/tests/test_new_sih_features.py` testing feedback CRUD, fraud scan rules, GPS geofence arrival, officer overrides, and AI stock deficit alerts.
   - Update `backend/test_all_apis.py` to cover all new endpoints.
2. **End-to-End System Test**:
   - Simulate citizen feedback submission $\rightarrow$ Officer resolution.
   - Simulate AI stock availability check under stock deficit scenario $\rightarrow$ Verify automated notification broadcast.
   - Run full 16-test API harness ensuring 100% pass rate.
