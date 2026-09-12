# 📊 PDS DemandSync — Real-World Dataset Requirements & Schema Specifications

> **System Target**: Transitioning PDS DemandSync from Synthetic Prototype to Production/State GovTech Deployment  
> **Applicable Standard**: National Food Security Act (NFSA), One Nation One Ration Card (ONORC), DPDP Act 2023  
> **Document Version**: `v1.0-production-spec` | **Date**: September 2026

---

## 🏛️ Executive Summary

**PDS DemandSync** is an AI-assisted decision support overlay for the Public Distribution System (PDS). It converts voluntary, forward-looking beneficiary intent signals into high-precision pre-dispatch demand forecasts, preventing migrant stockouts and godown holding losses.

To deploy PDS DemandSync with **real-world state government datasets** (e.g., State Food & Civil Supplies Department database), **5 core datasets** are required. This document outlines the schema specifications, field definitions, data privacy rules, and ingestion guidelines for data engineers and system integrators.

---

## 📁 The 5 Core Datasets

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                          PDS DEMANDSYNC DATA ENGINE                         │
│                                                                             │
│  [1. FPS Master]    [2. Beneficiary Cards]    [3. Historical ePoS Logs]    │
│         │                      │                          │                 │
│         └──────────────────────┼──────────────────────────┘                 │
│                                ▼                                            │
│                 ┌─────────────────────────────┐                             │
│                 │   [4. Live Intent Stream]   │                             │
│                 └──────────────┬──────────────┘                             │
│                                ▼                                            │
│                  ┌───────────────────────────┐                              │
│                  │  DEMAND FORECASTING ENGINE │                             │
│                  └─────────────┬─────────────┘                              │
│                                ▼                                            │
│                 [5. Warehouse & Logistics Fleet]                            │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## 📋 1. Dataset Specifications & Schemas

### 1.1. Fair Price Shop (FPS) Master Directory
* **Purpose**: Maps all distribution centers across the district/state, physical storage limits, and geographic coordinates for route optimization.
* **Target File/Table**: `fps_shops` (CSV / PostgreSQL / SQLite)

| Field Name | Data Type | Constraint | Description | Real-World Example |
|---|---|---|---|---|
| `fps_id` | String | Primary Key, Not Null | Unique ePoS FPS Dealer / Center Code | `FPS-29-BLR-0012` |
| `name` | String | Not Null | Shop Name / Licensee / Seva Kendra Name | `Malleshwaram Fair Price Shop #12` |
| `district` | String | Not Null | Administrative District | `Bengaluru Urban` |
| `taluk` / `sub_district` | String | Not Null | Sub-District / Taluk / Ward Zone | `North Ward 3` |
| `pincode` | String | 6 Digits, Regex `^[1-9][0-9]{5}$` | Postal Area Code | `560003` |
| `latitude` | Float | Range: `[-90.0, 90.0]` | GPS Latitude (for map UI & GIS logistics) | `13.0031` |
| `longitude` | Float | Range: `[-180.0, 180.0]` | GPS Longitude (for map UI & GIS logistics) | `77.5684` |
| `capacity_kg` | Float | `> 0.0` | Maximum physical storage capacity (in kg) | `15000.0` (15 MT) |
| `registered_cards_count` | Integer | `>= 0` | Baseline tagged home ration cards | `450` |

#### Sample CSV Format (`fps_master.csv`)
```csv
fps_id,name,district,taluk,pincode,latitude,longitude,capacity_kg,registered_cards_count
FPS-29-BLR-0012,Malleshwaram FPS #12,Bengaluru Urban,North Ward 3,560003,13.0031,77.5684,15000.0,450
FPS-29-BLR-0044,Peenya Migrant Hub FPS,Bengaluru Urban,Industrial Zone,560058,13.0321,77.5211,25000.0,820
```

---

### 1.2. Beneficiary & Entitlement Master
* **Purpose**: Verifies card validity, calculates statutory monthly grain quotas (Rice/Wheat), and handles portability.
* **Target File/Table**: `beneficiaries` (CSV / Parquet / SQL)

| Field Name | Data Type | Constraint | Description | Real-World Example |
|---|---|---|---|---|
| `card_id` | String | Primary Key, Pseudonymized | Hashed / Pseudonymized Ration Card Number | `RC-KA-990142` |
| `scheme_type` | Enum | `AAY` / `PHH` / `NPHH` | Ration card welfare classification category | `PHH` (Priority Household) |
| `members_count` | Integer | `>= 1` | Number of family members listed on card | `4` |
| `home_fps_id` | String | Foreign Key (`fps_shops.fps_id`) | Default registered home Fair Price Shop | `FPS-29-BLR-0012` |
| `monthly_rice_kg` | Float | `>= 0.0` | Monthly entitled statutory rice allocation | `20.0` (5 kg/member) |
| `monthly_wheat_kg` | Float | `>= 0.0` | Monthly entitled statutory wheat allocation | `5.0` |
| `language` | String | Default: `en` | Preferred communication language for SMS/IVR | `kn` (Kannada), `hi`, `en` |

#### Sample CSV Format (`beneficiaries_master.csv`)
```csv
card_id,scheme_type,members_count,home_fps_id,monthly_rice_kg,monthly_wheat_kg,language
RC-KA-990142,PHH,4,FPS-29-BLR-0012,20.0,5.0,kn
RC-KA-881023,AAY,5,FPS-29-BLR-0044,35.0,0.0,hi
```

---

### 1.3. Historical ePoS Distribution Transactions (Lifting History)
* **Purpose**: Provides baseline lifting patterns and seasonal trends for the ML forecasting model (minimum 6–12 months of historical cycles).
* **Target File/Table**: `historical_demand` (CSV / SQL)

| Field Name | Data Type | Constraint | Description | Real-World Example |
|---|---|---|---|---|
| `fps_id` | String | Foreign Key (`fps_shops.fps_id`) | Fair Price Shop ID | `FPS-29-BLR-0012` |
| `cycle_id` | String | Format: `YYYY-MM` | Allocation Year-Month Cycle | `2026-08` |
| `commodity` | String | `Rice` / `Wheat` / `Coarse Grains` | Commodity type | `Rice` |
| `lifted_quantity_kg` | Float | `>= 0.0` | Actual grain quantity disbursed via ePoS biometrics | `4250.0` |
| `allocated_quota_kg` | Float | `>= 0.0` | Total quota allocated to shop for that month | `4500.0` |
| `portability_inflow_kg` | Float | `>= 0.0` | Grain lifted by non-home / migrant cardholders | `650.0` |
| `portability_outflow_kg`| Float | `>= 0.0` | Quota unlifted because home cardholders collected elsewhere | `400.0` |

#### Sample CSV Format (`historical_epos_logs.csv`)
```csv
fps_id,cycle_id,commodity,lifted_quantity_kg,allocated_quota_kg,portability_inflow_kg,portability_outflow_kg
FPS-29-BLR-0012,2026-08,Rice,4250.0,4500.0,650.0,400.0
FPS-29-BLR-0012,2026-08,Wheat,1050.0,1125.0,120.0,80.0
```

---

### 1.4. Live Beneficiary Intent Signal Stream
* **Purpose**: Captures forward-looking beneficiary collection preferences prior to monthly dispatch locking.
* **Sources**: Mobile App, Web Portal, WhatsApp Bot, IVR Voice System, SMS Gateway, or CSC Kiosks.
* **Target File/Table**: `intent_signals` (REST API JSON Payload / Streaming Queue)

| Field Name | Data Type | Constraint | Description | Real-World Example |
|---|---|---|---|---|
| `intent_id` | String / UUID | Primary Key | Unique intent record identifier | `INT-2026-09-8812` |
| `card_id` | String | Foreign Key (`beneficiaries.card_id`) | Ration Card Identifier | `RC-KA-990142` |
| `cycle_id` | String | Format: `YYYY-MM` | Upcoming target planning cycle | `2026-10` |
| `intended_fps_id` | String | Foreign Key (`fps_shops.fps_id`) | Chosen FPS shop for collection | `FPS-29-BLR-0044` |
| `delivery_mode` | Enum | `FPS_COLLECTION` / `HOME_DELIVERY` | Preferred distribution channel | `FPS_COLLECTION` |
| `timestamp` | ISO-8601 Datetime | UTC Timestamp | Intent registration time | `2026-09-09T14:30:00Z` |

#### Sample JSON API Payload (`POST /api/intent`)
```json
{
  "beneficiary_id": "RC-KA-990142",
  "cycle_id": "2026-10",
  "intended_fps_id": "FPS-29-BLR-0044",
  "commodity": "Rice",
  "delivery_mode": "FPS_COLLECTION"
}
```

---

### 1.5. Godown & Logistics Fleet Master (Optional for Dispatch Simulation)
* **Purpose**: Maps FCI depots, state godowns, and transport vehicles to run automated dispatch allocation models.
* **Target File/Table**: `godowns` & `truck_fleet`

| Field Name | Data Type | Description | Example |
|---|---|---|---|
| `godown_id` | String | FCI Depot / State Warehouse Code | `GDN-BLR-NORTH` |
| `godown_name` | String | Name and Location | `Yelahanka FCI Central Depot` |
| `capacity_mt` | Float | Total holding capacity in Metric Tons | `5000.0` |
| `truck_id` | String | Vehicle Registration Number | `KA-01-EQ-4491` |
| `payload_capacity_mt` | Float | Vehicle load limit in Metric Tons | `10.0` |

---

## 🛡️ 2. Privacy, Security & Legal Compliance (DPDP Act 2023)

1. **Aadhaar & PII Privacy**:
   - **Zero Plaintext Citizen Data**: Real citizen Aadhaar numbers or unencrypted phone numbers **must never** be stored in the PDS DemandSync engine.
   - All `card_id` references must be salt-hashed using **SHA-256** (e.g. `hash(Aadhaar + StateSalt)`).
2. **Voluntary & Non-Binding Guarantee**:
   - Beneficiary intent declarations are strictly **planning signals**.
   - Failure to declare intent **does not** forfeit or modify a citizen's statutory rights under ONORC. Citizens can collect grain from any shop regardless of declared intent.
3. **Role-Based Access Control (RBAC)**:
   - District Civil Supplies Officers see aggregated district metrics.
   - FPS Dealers view shop-level expected demand totals without seeing individual card numbers.

---

## ⚙️ 3. Data Integration & Ingestion Architecture

```
┌────────────────────────┐      ┌────────────────────────┐      ┌────────────────────────┐
│  State PDS / ePoS DB   │      │   Beneficiary Inputs   │      │  State Logistics (LMS) │
│ (NIC / NIC-ePoS API)   │      │ (App/Web/IVR/WhatsApp) │      │  (FCI Depot Stocks)    │
└───────────┬────────────┘      └───────────┬────────────┘      └───────────┬────────────┘
            │                               │                               │
            │ REST API / SQL Dump           │ Webhook / JSON                │ CSV / JSON
            ▼                               ▼                               ▼
┌────────────────────────────────────────────────────────────────────────────────────────┐
│                              PDS DEMANDSYNC INGESTION PIPELINE                         │
│                                                                                        │
│   1. Validation Layer   ──►  Check Lat/Long, Pincodes, Scheme Types & Duplicate Cards │
│   2. Anonymization      ──►  Hash PII & Convert to Pseudonymous Tokens                 │
│   3. SQLite / Postgres  ──►  Upsert into system relational tables                      │
└────────────────────────────────────────────────────────────────────────────────────────┘
```

---

## 🔄 4. Quickstart: Replacing Demo Data with Real Datasets

To plug real CSV files into the existing codebase:

1. Place your exported CSV files inside `backend/app/data/real_data/`:
   - `fps_master.csv`
   - `beneficiaries_master.csv`
   - `historical_epos_logs.csv`

2. Modify `backend/app/data/seed_data.py` to ingest CSVs via Pandas:
   ```python
   import pandas as pd

   def load_real_fps_data(db_conn, csv_path):
       df = pd.read_csv(csv_path)
       df.to_sql("fps", db_conn, if_exists="append", index=False)
   ```

3. Restart the FastAPI backend server:
   ```bash
   python server.py
   ```

---

*This specification is ready to be shared with State Food & Civil Supplies IT teams, NIC engineers, and hackathon evaluators.*
