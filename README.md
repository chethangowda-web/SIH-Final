# PDS DemandSync
> **Forward-Looking Beneficiary Intent for Pre-Dispatch PDS Demand Forecasting**
> *Smart India Hackathon (SIH) 2026 Prototype — Demo V1*

---

## 🏛️ Executive Summary

The Public Distribution System (PDS) in India supports over 800 million citizens through a nationwide network of Fair Price Shops (FPS). Under the **One Nation One Ration Card (ONORC)** initiative, beneficiaries possess portability to lift food grains from any FPS across the country. 

However, supply allocation and grain dispatch to FPS dealers currently rely primarily on **historical static quotas** and lagging indicators. When seasonal migration, festivals, local labor shifts, or urbanization occur, static supply fails to match dynamic demand—resulting in **stockouts in migrant hubs** and **excess inventory / spoilage in source regions**.

**PDS DemandSync** is a decision-support overlay that introduces a **lightweight, non-binding forward-looking beneficiary intent signal** collected prior to the dispatch cycle. It combines:
1. Historical FPS lifting patterns
2. Declared beneficiary intent signals
3. Dynamic intent confidence scoring
4. Buffer stock & FPS storage capacity
5. Contextual calendar / seasonal flags

to generate high-precision, pre-dispatch demand forecasts, closing the loop with actual ePoS distribution reconciliation and self-calibrating machine learning models.

---

## 🔄 The Closed-Loop Workflow

```
┌────────────────────────┐
│   BENEFICIARY INTENT   │  (Voluntary, non-binding signal via web / kiosk / app)
└───────────┬────────────┘
            │
            ▼
┌────────────────────────┐
│   INTENT VALIDATION    │  (Confidence scoring, outlier filter, historical cross-check)
└───────────┬────────────┘
            │
            ▼
┌────────────────────────┐
│     DEMAND FORECAST    │  (ML-driven prediction combining intent + history + features)
└───────────┬────────────┘
            │
            ▼
┌────────────────────────┐
│      FORECAST LOCK     │  (District Admin approves final pre-dispatch quotas)
└───────────┬────────────┘
            │
            ▼
┌────────────────────────┐
│  DISPATCH SIMULATION   │  (Simulated FCI/State Godown to FPS allocation & transit)
└───────────┬────────────┘
            │
            ▼
┌────────────────────────┐
│ ACTUAL ePoS DISTRIB.   │  (Simulated point-of-sale biometric transaction logs)
└───────────┬────────────┘
            │
            ▼
┌────────────────────────┐
│   FORECAST vs ACTUAL   │  (Variance analysis, MAPE, stockout prevention metrics)
└───────────┬────────────┘
            │
            ▼
┌────────────────────────┐
│     MODEL LEARNING     │  (Calibration of weights & confidence for next cycle)
└────────────────────────┘
```

---

## ⚖️ Core Product Principles

- **Planning Signal Only**: Beneficiary intent is **not** an entitlement modification, **not** a permanent FPS lock, and **not** an ONORC replacement. A citizen can still collect from any FPS regardless of declared intent.
- **Privacy-by-Design & Synthetic Data**: Zero real citizen or Aadhaar data is stored or processed. All demonstration data uses pseudonymous synthetic identifiers (e.g., `BEN-KA-09412`).
- **No Complex External Dependencies in V1**: Operates 100% locally with zero paid APIs or proprietary hardware requirements.
- **Modern GovTech Design Language**: Clean, high-contrast, professional, data-rich interface adhering to National Informatics Centre (NIC) and Digital India usability standards.

---

## 💻 Tech Stack

| Layer | Technology | Purpose |
|---|---|---|
| **Frontend** | Flutter (Web & Desktop) + Dart | Cross-platform, responsive GovTech UI |
| **Backend** | Python 3.12 + FastAPI | High-performance asynchronous REST API |
| **Database** | SQLite 3 + SQLAlchemy / aiosqlite | Lightweight, self-contained relational storage |
| **Data Engine** | Pandas + NumPy | Data processing, aggregation, variance computation |
| **ML Engine** | scikit-learn | Multi-variate demand forecasting & calibration |
| **Visualization** | fl_chart / Custom Canvas | FPS load heatmaps, variance charts, trend lines |

---

## 📁 Repository Structure

```
rationcard/
├── backend/
│   ├── app/
│   │   ├── api/          # REST route handlers (health, intent, forecast, dispatch, actuals)
│   │   ├── core/         # Settings, database connection, GovTech constants
│   │   ├── models/       # Relational schemas & Pydantic request/response models
│   │   ├── services/     # Forecasting engine, dispatch simulator, calibration engine
│   │   └── data/         # Seed synthetic dataset (beneficiaries, FPS shops, history)
│   ├── main.py           # FastAPI application entrypoint
│   └── requirements.txt  # Python backend dependencies
├── frontend/
│   ├── lib/
│   │   ├── core/         # GovTech design tokens, theme, constants, API client
│   │   ├── models/       # Dart domain models
│   │   ├── screens/      # Beneficiary portal, District Admin dashboard, Simulation
│   │   └── widgets/      # Reusable GovTech UI components (metric cards, status chips)
│   ├── pubspec.yaml      # Flutter package configuration
│   └── web/              # Web application entrypoint & assets
├── docs/
│   ├── ARCHITECTURE.md   # Detailed technical design & mathematical formulations
│   └── TODO.md           # Step-by-step implementation milestones
└── README.md             # Project documentation
```

---

## 🚀 Quickstart Guide

### Prerequisites
- Python 3.10+
- Flutter SDK (3.x+) & Chrome / Edge for web preview
- Git

### 1. Backend Setup
```bash
# Navigate to backend directory
cd backend

# Create and activate virtual environment
python -m venv .venv
# On Windows:
.venv\Scripts\activate
# On Linux/macOS:
source .venv/bin/activate

# Install dependencies
pip install -r requirements.txt

# Start FastAPI server
uvicorn app.main:app --reload --host 127.0.0.1 --port 8000
```
- **API Swagger Docs**: Visit [http://127.0.0.1:8000/docs](http://127.0.0.1:8000/docs)
- **Health Check**: Visit [http://127.0.0.1:8000/api/health](http://127.0.0.1:8000/api/health)

### 2. Frontend Setup
```bash
# Navigate to frontend directory
cd frontend

# Get Flutter packages
flutter pub get

# Run on Chrome
flutter run -d chrome
```

---

## 📊 Demo V1 User Roles

1. **Beneficiary Portal**:
   - Rapid 3-click intent declaration (Target FPS, Month, Household commodity intent).
   - Real-time confirmation with non-binding disclaimer.
2. **District Civil Supplies Admin Dashboard**:
   - District-level FPS demand projection overview.
   - Comparison: Baseline Static Allocation vs Intent-Augmented Demand Forecast.
   - Simulation controls: Trigger Forecast Lock → Dispatch Simulation → Actual ePoS Ingestion → Model Calibration.

---

## 🛡️ Disclaimer
*This prototype is developed exclusively for demonstration purposes as part of Smart India Hackathon 2026. All data is synthetically generated. No real government databases, APIs, or citizen personal identifiable information (PII) are used.*
