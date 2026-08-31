# PDS DemandSync — Production Deployment & Operations Guide

This document outlines the authoritative deployment instructions, configuration parameters, operational procedures, and backup workflows for the **PDS DemandSync** platform.

---

## 1. System Architecture & Components

PDS DemandSync is packaged as a unified service:
- **Backend**: FastAPI / Python 3.11+ application exposing canonical REST APIs under `/api/`, asynchronous coroutines, ML forecasting and scarcity engines, SQLite in WAL mode with PRAGMA integrity verification, and structured observability logging.
- **Frontend**: Flutter Web (CanvasKit / HTML) compiled SPA statically mounted and served at `/app/` directly by the backend application or an external reverse proxy.

---

## 2. Production Environment Variables Reference

All application parameters can be configured through process environment variables or an external `.env` file:

| Environment Variable | Type | Default (Dev) | Production Required | Description |
|---|---|---|---|---|
| `ENVIRONMENT` | string | `development` | **YES** | Set to `production` for live instances. Activates strict security validation at startup. |
| `SECRET_KEY` | string | *default dev key* | **YES** | Cryptographic secret for signing HMAC-SHA256 bearer tokens. Must be unique and $\ge 32$ characters in production. |
| `DB_PATH` | path | `pds_demandsync.db` | Optional | Absolute or relative path to the operational SQLite database file. Parent directory is created automatically. |
| `STATIC_DIR` | path | `../frontend/build/web` | Optional | Absolute or relative path to the compiled Flutter web static assets directory. |
| `CORS_ORIGINS` | string | `http://localhost,http://127.0.0.1...` | Optional | Comma-separated list of allowed origins. Wildcard `*` is strictly forbidden in production. |
| `LOG_LEVEL` | string | `INFO` | Optional | Application log verbosity (`DEBUG`, `INFO`, `WARNING`, `ERROR`). |
| `LOG_FORMAT` | string | `text` | Optional | `json` for structured cloud log ingestion or `text` for formatted console logging. |
| `HOST` | string | `0.0.0.0` | Optional | Server network interface bind address. |
| `PORT` | integer | `8000` | Optional | Server listening port. |
| `ALLOW_TEST_AUTH_MOCK`| boolean| `True` (Dev) | **Forced False** | Test bypass flag. In `production`, this is unconditionally disabled regardless of environment setting. |
| `ALLOW_DEMO_RESET` | boolean| `True` (Dev) | `False` | Protects `/api/admin/demo/reset`. Must remain `False` in production to prevent data wiping. |
| `INTENT_WEIGHT` | float | `0.65` | Optional | Parameter $w$: Weight given to forward-looking citizen intent in demand forecasting. |
| `SAFETY_BUFFER_PCT` | float | `0.05` | Optional | Safety stock buffer percentage added to statutory requirements ($0.05 = 5\%$). |

---

## 3. Pre-Deployment Validation & Testing

Run the automated test suites to ensure 100% test coverage before building deployment artifacts:

```bash
# 1. Run Complete Backend Test Suite (259 Tests)
cd backend
python -m pytest tests/ -v

# 2. Run Static Analysis & Unit Tests on Frontend (25 Tests)
cd ../frontend
flutter analyze
flutter test
```

---

## 4. Build & Production Startup Commands

### Step 1: Compile the Flutter Web Client
```bash
cd frontend
flutter build web --release --base-href "/app/"
```

### Step 2: Set Production Environment & Start Service
```bash
# Example Linux / macOS
export ENVIRONMENT="production"
export SECRET_KEY="a_very_long_secure_random_production_secret_key_minimum_32_characters"
export CORS_ORIGINS="https://pds.karnataka.gov.in,https://demandsync.nic.in"
export LOG_FORMAT="json"
export LOG_LEVEL="INFO"
export DB_PATH="/var/data/pds/pds_demandsync.db"
export ALLOW_DEMO_RESET="false"

cd backend
python server.py
```

```powershell
# Example Windows PowerShell
$env:ENVIRONMENT="production"
$env:SECRET_KEY="a_very_long_secure_random_production_secret_key_minimum_32_characters"
$env:CORS_ORIGINS="https://pds.karnataka.gov.in,https://demandsync.nic.in"
$env:LOG_FORMAT="json"
$env:LOG_LEVEL="INFO"
$env:DB_PATH="E:\rationcard\production_data\pds_demandsync.db"
$env:ALLOW_DEMO_RESET="false"

cd backend
python server.py
```

---

## 5. Health Probes & Monitoring

The service exposes standardized Kubernetes/Cloud health endpoints:

### Liveness Probe
- **Endpoint**: `GET /api/health/live` (or root alias `GET /health/live`)
- **Status**: Returns `200 OK`
```json
{
  "status": "live",
  "service": "PDS DemandSync",
  "version": "1.0.0-demo-v1",
  "timestamp": "2026-08-30T14:15:00.000000Z"
}
```

### Readiness Probe
- **Endpoint**: `GET /api/health/ready` (or root alias `GET /health/ready`)
- **Status**: Returns `200 OK` when DB is connected and `PRAGMA integrity_check` passes; returns `503 Service Unavailable` if database is unreachable or corrupted.
```json
{
  "status": "ready",
  "database": "connected",
  "integrity": "ok",
  "tables_count": 27,
  "timestamp": "2026-08-30T14:15:00.000000Z"
}
```

### Operational Status Telemetry
- **Endpoint**: `GET /api/health/status` (or `GET /api/admin/operations/status`)
- **Status**: Returns `200 OK` with active planning cycle, workflow stage, blocked conditions, and uptime without leaking secrets.

---

## 6. Database Backup & Disaster Recovery Procedure

The SQLite database operates in **Write-Ahead Logging (WAL)** mode. Backups must use the integrated vacuum backup engine or SQLite online backup API to ensure ACID consistency without taking the service offline.

### Create Online Hot Backup
```python
# Programmatic hot backup using core database service
from app.core.database import create_database_backup
backup_file = create_database_backup()
print(f"Hot backup created at: {backup_file}")
```

### Manual CLI Hot Backup
```bash
# SQLite .backup command executes an atomic online hot backup
sqlite3 pds_demandsync.db ".backup 'backups/pds_demandsync_manual_$(date +%Y%m%d_%H%M%S).bak'"
```

### Database Restoration & Integrity Verification
```python
# Programmatic restore with automated pre-flight integrity check
from app.core.database import restore_database_from_backup
restore_database_from_backup("backups/pds_demandsync_20260830_120000.bak")
```
Or via CLI:
```bash
# 1. Stop backend service
# 2. Verify backup integrity
sqlite3 backups/pds_demandsync_backup.bak "PRAGMA integrity_check;"

# 3. Replace active DB file with verified backup
cp backups/pds_demandsync_backup.bak pds_demandsync.db

# 4. Restart backend service
```

---

## 7. Security Hardening Checklist

- [x] Insecure/default development `SECRET_KEY` rejected at production startup.
- [x] `CORS_ORIGINS` wildcard `*` rejected at production startup when credentials enabled.
- [x] Test auth bypass mock (`PDS_TEST_AUTH_MOCK`) hard-disabled in `production` mode.
- [x] Administrative demo reset endpoint (`/api/admin/demo/reset`) locked in production unless `ALLOW_DEMO_RESET=true` is explicitly set.
- [x] Passwords, tokens, HMAC secrets, and hashes are automatically redacted from logs.
- [x] Strict security headers (`X-Content-Type-Options: nosniff`, `X-Frame-Options: DENY`, `X-XSS-Protection: 1; mode=block`, `Referrer-Policy: strict-origin-when-cross-origin`) applied to all responses.
- [x] Sensitive DB credentials or internal file paths excluded from health check responses.
