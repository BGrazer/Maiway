from __future__ import annotations

"""High-level fare calculator used by RouteService.

Keeps the heavy CSV-table lookup logic in one place so that
`core_route_service` is thin.  Falls back to the simple
`utils.fare_utils.calculate_fare` buckets when tabular data is missing.
"""

from typing import Dict, Any
import math
import pandas as pd
from maiwayrouting.utils.fare_utils import calculate_fare as fallback_calculate_fare

__all__ = ["calculate_real_fare"]

def _is_discounted_fare(fare_type: str) -> bool:
    ft = (fare_type or "").strip().lower()
    return ft in {"discounted", "student", "senior", "pwd", "sp", "discount"}


def _is_stored_value_fare(fare_type: str) -> bool:
    ft = (fare_type or "").strip().lower()
    return ft in {"stored", "stored_value", "storedvalue", "sv", "stored_valuecard", "storedvaluecard"}


def calculate_real_fare(
    mode: str,
    from_stop_id: str,
    to_stop_id: str,
    distance_km: float,
    fare_type: str,
    fare_tables: Dict[str, Any],
    stops: Dict[str, Dict[str, Any]],
) -> float:
    """Return fare in PHP using loaded fare tables; fallback to buckets."""

    mode_norm = (mode or "").capitalize()

    # Walking stays free
    if mode_norm == "Walking":
        return 0.0

    if not fare_tables:
        return fallback_calculate_fare(mode_norm, distance_km, fare_type)

    # Bus / Jeep distance tables ------------------------------------------------
    if mode_norm in {"Bus", "Jeep"}:
        table: pd.DataFrame | None = fare_tables.get(mode_norm)
        if table is not None and not table.empty:
            # Use actual distance, not just ceiling - more accurate pricing
            km = max(0.1, distance_km)  # Minimum 100m for fare calculation
            
            # For better interpolation, find the right fare bracket
            matching_rows = table[table["distance"] >= km]
            if not matching_rows.empty:
                row = matching_rows.head(1)
                col = "discounted" if _is_discounted_fare(fare_type) else "regular"
                base_fare = float(row.iloc[0][col])
                return base_fare

    # LRT station matrix --------------------------------------------------------
    if mode_norm == "Lrt":
        if _is_stored_value_fare(fare_type):
            df = fare_tables.get("LRT_STORED")
        elif _is_discounted_fare(fare_type):
            df = fare_tables.get("LRT_DISCOUNTED")
        else:
            df = fare_tables.get("LRT_REG")
        if df is not None and not df.empty:
            from_raw = stops.get(from_stop_id, {}).get("name", "")
            to_raw = stops.get(to_stop_id, {}).get("name", "")

            def _match(name_raw: str):
                """Return first station in df index that appears inside the raw name (case-insensitive)."""
                for st in df.index:
                    if st.lower() in name_raw.lower():
                        return st
                return None

            from_name = _match(from_raw)
            to_name = _match(to_raw)
            if from_name and to_name and from_name in df.index and to_name in df.columns:
                val = df.loc[from_name, to_name]
                if pd.notna(val):
                    return float(val)
        # fallback flat fare
        return 15.0

    # Default bucket fallback ---------------------------------------------------
    return fallback_calculate_fare(mode_norm, distance_km, fare_type) 