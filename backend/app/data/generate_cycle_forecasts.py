"""Generate authoritative forecasts for all 628 Fair Price Shops for active planning cycle."""

import sqlite3
from datetime import datetime

import os
from pathlib import Path

DEFAULT_DB = Path(__file__).resolve().parent.parent.parent / "pds_demandsync.db"


def generate_full_forecasts(db_path: str = None, cycle_id: str = "2026-09"):
    target_path = db_path or str(DEFAULT_DB)
    db = sqlite3.connect(target_path)
    db.row_factory = sqlite3.Row
    cursor = db.cursor()

    cursor.execute("SELECT fps_id, name, capacity_kg FROM fps ORDER BY id ASC;")
    all_fps = cursor.fetchall()

    commodities = ["Rice", "Wheat"]
    w = 0.65
    inserted = 0
    total_forecast_kg = 0.0

    print(
        f"Generating forecasts for {len(all_fps)} FPS across {commodities} for cycle {cycle_id}..."
    )

    for fps in all_fps:
        fid = fps["fps_id"]
        cap = float(fps["capacity_kg"] or 50000.0)

        for comm in commodities:
            # 1. Historical baseline H (6-cycle average)
            cursor.execute(
                """
            SELECT COALESCE(SUM(actual_quantity_kg) / 6.0, 0.0)
            FROM historical_demand WHERE fps_id = ? AND commodity = ?;
            """,
                (fid, comm),
            )
            hist_avg = float(cursor.fetchone()[0])

            # If historical demand is missing for this FPS, compute from registered beneficiaries
            if hist_avg <= 0.0:
                col = "monthly_rice_kg" if comm == "Rice" else "monthly_wheat_kg"
                cursor.execute(
                    f"SELECT COALESCE(SUM({col}), 0.0) FROM beneficiaries WHERE registered_fps_id = ?;",
                    (fid,),
                )
                hist_avg = float(cursor.fetchone()[0])
                if hist_avg <= 0.0:
                    hist_avg = 150.0 if comm == "Rice" else 60.0

            # 2. Intent I and confidence C
            cursor.execute(
                """
            SELECT COALESCE(SUM(declared_quantity_kg), 0.0), COUNT(DISTINCT beneficiary_id), COALESCE(AVG(confidence), 0.95)
            FROM intent WHERE intended_fps_id = ? AND cycle_id = ? AND commodity = ?;
            """,
                (fid, cycle_id, comm),
            )
            i_row = cursor.fetchone()
            intent_kg = float(i_row[0])
            avg_conf = float(i_row[2])

            # 3. Forecast formula
            if intent_kg > 0.0:
                alpha = round(w * avg_conf, 4)
                forecast_kg = round(((1.0 - alpha) * hist_avg) + (alpha * intent_kg), 1)
            else:
                forecast_kg = round(hist_avg, 1)

            total_forecast_kg += forecast_kg

            # 4. Inventory S
            cursor.execute(
                "SELECT COALESCE(available_quantity_kg, 0.0) FROM inventory WHERE fps_id = ? AND commodity = ?;",
                (fid, comm),
            )
            inv_row = cursor.fetchone()
            curr_stock = float(inv_row[0]) if inv_row else 0.0

            # 5. Recommended dispatch
            rec_dispatch = max(0.0, round(forecast_kg * 1.05 - curr_stock, 1))

            # 6. Risk level evaluation
            if curr_stock < (0.2 * forecast_kg) or (
                intent_kg > 1.35 * hist_avg and intent_kg > 0
            ):
                risk = "CRITICAL"
            elif curr_stock < (0.5 * forecast_kg) or (
                intent_kg > 1.15 * hist_avg and intent_kg > 0
            ):
                risk = "HIGH"
            elif curr_stock > (1.8 * forecast_kg):
                risk = "LOW"
            else:
                risk = "NORMAL"

            cursor.execute(
                """
            INSERT OR REPLACE INTO forecast (
                fps_id, cycle_id, commodity, historical_component, intent_component,
                inventory_component, predicted_quantity_kg, recommended_dispatch_kg,
                confidence, risk_level, model_version, created_at, status
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 'v1.0-weighted-linear', CURRENT_TIMESTAMP, 'DRAFT');
            """,
                (
                    fid,
                    cycle_id,
                    comm,
                    hist_avg,
                    intent_kg,
                    curr_stock,
                    forecast_kg,
                    rec_dispatch,
                    avg_conf,
                    risk,
                ),
            )
            inserted += 1

    db.commit()
    cursor.close()
    db.close()
    print(
        f"SUCCESS: Persisted {inserted} forecast records for {len(all_fps)} FPS. Total Forecast: {total_forecast_kg:,.1f} kg"
    )


if __name__ == "__main__":
    generate_full_forecasts()
