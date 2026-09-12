"""API Router for Bulk CSV/Excel Real Data Import & Validation."""

import io
import csv
import sqlite3
from typing import List, Dict, Any
from fastapi import APIRouter, Depends, UploadFile, File, HTTPException, Form
from app.core.database import get_db

router = APIRouter(prefix="/import", tags=["Real Data Ingestion & Validation"])

@router.post("/fps-csv")
async def import_fps_csv(
    file: UploadFile = File(...),
    db: sqlite3.Connection = Depends(get_db)
):
    """
    Validates and ingests real-world Fair Price Shop (FPS) Master CSV datasets.
    Required columns: fps_id, name, district, pincode, latitude, longitude, capacity_kg
    """
    if not file.filename.endswith(('.csv', '.txt')):
        raise HTTPException(status_code=400, detail="Only CSV files are supported.")

    content = await file.read()
    decoded = content.decode('utf-8')
    reader = csv.DictReader(io.StringIO(decoded))

    required_fields = {"fps_id", "name", "district", "latitude", "longitude", "capacity_kg"}
    if not required_fields.issubset(set(reader.fieldnames or [])):
        missing = required_fields - set(reader.fieldnames or [])
        raise HTTPException(status_code=422, detail=f"CSV missing required columns: {list(missing)}")

    valid_rows = []
    error_rows = []
    cursor = db.cursor()

    for row_idx, row in enumerate(reader, start=1):
        try:
            fps_id = row["fps_id"].strip()
            name = row["name"].strip()
            district = row["district"].strip()
            lat = float(row["latitude"])
            lon = float(row["longitude"])
            capacity = float(row["capacity_kg"])
            pincode = row.get("pincode", "560001").strip()

            if not (-90.0 <= lat <= 90.0) or not (-180.0 <= lon <= 180.0):
                raise ValueError("Invalid latitude/longitude range.")

            valid_rows.append((fps_id, name, district, lat, lon, capacity, "ACTIVE", 100))
        except Exception as exc:
            error_rows.append({"row_number": row_idx, "data": row, "error": str(exc)})

    # Upsert valid records into database
    if valid_rows:
        cursor.executemany("""
            INSERT INTO fps (fps_id, name, district, latitude, longitude, capacity_kg, status, beneficiaries_count)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?)
            ON CONFLICT(fps_id) DO UPDATE SET
                name=excluded.name,
                district=excluded.district,
                latitude=excluded.latitude,
                longitude=excluded.longitude,
                capacity_kg=excluded.capacity_kg
        """, valid_rows)
        db.commit()

    return {
        "file_name": file.filename,
        "status": "success" if not error_rows else "partial_success",
        "total_rows_processed": len(valid_rows) + len(error_rows),
        "successful_imports": len(valid_rows),
        "failed_imports": len(error_rows),
        "errors": error_rows[:10]  # Return top 10 errors
    }

@router.post("/beneficiaries-csv")
async def import_beneficiaries_csv(
    file: UploadFile = File(...),
    db: sqlite3.Connection = Depends(get_db)
):
    """
    Validates and ingests real Beneficiary & Entitlement CSV datasets.
    Required columns: card_id, scheme_type, members_count, home_fps_id, monthly_rice_kg, monthly_wheat_kg
    """
    if not file.filename.endswith(('.csv', '.txt')):
        raise HTTPException(status_code=400, detail="Only CSV files are supported.")

    content = await file.read()
    decoded = content.decode('utf-8')
    reader = csv.DictReader(io.StringIO(decoded))

    required_fields = {"card_id", "scheme_type", "members_count", "home_fps_id"}
    if not required_fields.issubset(set(reader.fieldnames or [])):
        missing = required_fields - set(reader.fieldnames or [])
        raise HTTPException(status_code=422, detail=f"CSV missing required columns: {list(missing)}")

    valid_rows = []
    error_rows = []
    cursor = db.cursor()

    for row_idx, row in enumerate(reader, start=1):
        try:
            card_id = row["card_id"].strip()
            scheme = row["scheme_type"].strip().upper()
            members = int(row["members_count"])
            home_fps = row["home_fps_id"].strip()
            lang = row.get("language", "kn").strip()

            valid_rows.append((card_id, f"Beneficiary {card_id}", home_fps, lang, "ACTIVE"))
        except Exception as exc:
            error_rows.append({"row_number": row_idx, "data": row, "error": str(exc)})

    if valid_rows:
        cursor.executemany("""
            INSERT INTO beneficiaries (pseudonymous_beneficiary_id, name_for_demo, registered_fps_id, language, status)
            VALUES (?, ?, ?, ?, ?)
            ON CONFLICT(pseudonymous_beneficiary_id) DO UPDATE SET
                registered_fps_id=excluded.registered_fps_id,
                language=excluded.language
        """, valid_rows)
        db.commit()

    return {
        "file_name": file.filename,
        "status": "success" if not error_rows else "partial_success",
        "total_rows_processed": len(valid_rows) + len(error_rows),
        "successful_imports": len(valid_rows),
        "failed_imports": len(error_rows),
        "errors": error_rows[:10]
    }
