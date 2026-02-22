from __future__ import annotations

"""GTFS CSV loaders returning dictionaries/lists used by RouteService.

This file was re-added after accidental deletion.
"""

from pathlib import Path
from typing import Dict, Any, List, Tuple

import pandas as pd

__all__ = [
    "load_stops",
    "load_routes",
    "load_trips",
    "load_stop_times",
    "load_transfers",
]


def load_stops(data_dir: str) -> Dict[str, Dict[str, Any]]:
    df = pd.read_csv(Path(data_dir) / "stops.txt")
    out: Dict[str, Dict[str, Any]] = {}
    for _, row in df.iterrows():
        if pd.isna(row["stop_id"]):
            continue
        out[str(row["stop_id"])] = {
            "name": row.get("stop_name", ""),
            "lat": float(row["stop_lat"]),
            "lon": float(row["stop_lon"]),
            "zone_id": row.get("zone_id", ""),
        }
    return out


def load_routes(data_dir: str) -> Dict[str, Dict[str, Any]]:
    df = pd.read_csv(Path(data_dir) / "routes.txt")
    out: Dict[str, Dict[str, Any]] = {}
    for _, row in df.iterrows():
        out[str(row["route_id"])] = {
            "short_name": row.get("route_short_name", ""),
            "long_name": row.get("route_long_name", ""),
            "route_type": int(row.get("route_type", 3)),
            "agency_id": row.get("agency_id", ""),
        }
    return out


def load_trips(data_dir: str) -> Dict[str, Dict[str, Any]]:
    df = pd.read_csv(Path(data_dir) / "trips.txt")
    out: Dict[str, Dict[str, Any]] = {}
    for _, row in df.iterrows():
        out[str(row["trip_id"])] = {
            "route_id": str(row["route_id"]),
            "shape_id": str(row.get("shape_id", "")),
            "direction_id": int(row.get("direction_id", 0)),
        }
    return out


def load_stop_times(data_dir: str) -> List[Dict[str, Any]]:
    df = pd.read_csv(Path(data_dir) / "stop_times.txt")
    out: List[Dict[str, Any]] = []
    for _, row in df.iterrows():
        out.append(
            {
                "trip_id": str(row["trip_id"]),
                "stop_sequence": int(row["stop_sequence"]),
                "stop_id": str(row["stop_id"]),
                "pickup_type": int(row.get("pickup_type", 0)),
                "drop_off_type": int(row.get("drop_off_type", 0)),
            }
        )
    return out


def load_transfers(data_dir: str) -> List[Tuple[str, str]]:
    path = Path(data_dir) / "transfers.txt"
    if not path.exists():
        return []
    df = pd.read_csv(path)
    return [(str(row["from_stop_id"]), str(row["to_stop_id"])) for _, row in df.iterrows()] 