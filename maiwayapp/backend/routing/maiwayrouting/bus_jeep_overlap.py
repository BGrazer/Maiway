"""
MaiWay Bus–Jeepney Overlap Detection and Substitution

When a bus leg from Google overlaps a known jeepney corridor, optionally substitute
with jeepney leg for CHEAPEST / MOST CONVENIENT variants.
"""

import os
import json
import logging
from typing import Dict, List, Any, Optional, Tuple

logger = logging.getLogger(__name__)

# Load jeepney route geometries for overlap check
_ROUTES_DIR = os.path.join(os.path.dirname(__file__), "..", "routing_data", "routes-geojson")
_JEEP_FILES = ["Jeep1.geojson", "jeep2.geojson", "jeep3.geojson", "jeep4.geojson", "jeep5.geojson",
               "jeep6.geojson", "jeep7.geojson", "jeep8.geojson", "jeep9.geojson"]

# Overlap threshold: if bus segment overlaps jeepney corridor by this fraction, allow substitution
OVERLAP_THRESHOLD = 0.6

# Max distance (km) to consider two points "on" the same corridor
BUFFER_KM = 0.05


def _jeep_feature_name(props: dict, fname: str) -> str:
    """Get route name from feature properties; avoid raw filename like 'jeep2.geojson'."""
    name = props.get("name") or props.get("Name")
    if name and (name := (name or "").strip()):
        return name
    for k, v in (props or {}).items():
        if k.strip().lower() == "name" and v and (v := (v or "").strip()):
            return v
    base = fname.replace(".geojson", "").replace(".GeoJSON", "").strip()
    if not base:
        return "Jeepney Route"
    if base.lower().startswith("jeep"):
        return base[:4].title() + " " + base[4:] if len(base) > 4 else base.title()
    return base.replace("_", " ").title()


def _load_jeepney_linestrings() -> List[Dict]:
    """Load jeepney route LineStrings from GeoJSON."""
    lines = []
    for fname in _JEEP_FILES:
        path = os.path.join(_ROUTES_DIR, fname)
        if not os.path.exists(path):
            continue
        try:
            with open(path, "r", encoding="utf-8") as f:
                data = json.load(f)
            for feat in data.get("features", []):
                geom = feat.get("geometry", {})
                if geom.get("type") == "LineString":
                    coords = geom.get("coordinates", [])
                    props = feat.get("properties", {}) or {}
                    name = _jeep_feature_name(props, fname)
                    if coords:
                        lines.append({"name": name, "coords": coords})
        except Exception as e:
            logger.debug(f"Could not load {fname}: {e}")
    return lines


def _point_to_line_distance(px: float, py: float, line_coords: List) -> float:
    """Approximate distance from point (lon, lat) to line segment in km."""
    if not line_coords or len(line_coords) < 2:
        return 999.0
    min_d = 999.0
    for i in range(len(line_coords) - 1):
        x1, y1 = line_coords[i][0], line_coords[i][1]
        x2, y2 = line_coords[i + 1][0], line_coords[i + 1][1]
        # Vector from p to line segment
        dx = x2 - x1
        dy = y2 - y1
        if dx == 0 and dy == 0:
            d = ((px - x1) ** 2 + (py - y1) ** 2) ** 0.5
        else:
            t = max(0, min(1, ((px - x1) * dx + (py - y1) * dy) / (dx * dx + dy * dy + 1e-10)))
            qx = x1 + t * dx
            qy = y1 + t * dy
            d = ((px - qx) ** 2 + (py - qy) ** 2) ** 0.5
        # Rough km: 1 deg ≈ 111 km at equator
        d_km = d * 111.0
        min_d = min(min_d, d_km)
    return min_d


def _segment_overlap_ratio(
    seg_coords: List[List[float]],
    jeep_line: Dict,
) -> float:
    """
    Estimate overlap: fraction of segment points within BUFFER_KM of jeepney line.
    seg_coords: [[lon, lat], ...]
    """
    if not seg_coords or len(seg_coords) < 2:
        return 0.0
    line_coords = jeep_line.get("coords", [])
    if not line_coords:
        return 0.0
    near = 0
    for pt in seg_coords:
        if len(pt) >= 2:
            d = _point_to_line_distance(pt[0], pt[1], line_coords)
            if d <= BUFFER_KM:
                near += 1
    return near / len(seg_coords)


def find_overlapping_jeepney(
    bus_segment: Dict,
    jeepney_lines: List[Dict],
) -> Optional[Tuple[str, str]]:
    """
    If bus segment overlaps one or more jeepney corridors, return (jeepney_route_id, jeepney_name).
    When multiple jeepney routes overlap (e.g. Frisco and others), pick one at random so it's not always the same.
    """
    import random
    polyline = bus_segment.get("polyline", [])
    if not polyline or len(polyline) < 2:
        return None

    overlapping: List[Tuple[str, str]] = []
    for jl in jeepney_lines:
        ratio = _segment_overlap_ratio(polyline, jl)
        if ratio >= OVERLAP_THRESHOLD:
            name = jl.get("name", "Unknown")
            route_id = f"JEEP_{name.replace(' ', '_').replace('-', '_')[:30]}"
            overlapping.append((route_id, name))

    if not overlapping:
        return None
    return random.choice(overlapping)


# Cache jeepney lines
_jeepney_lines_cache: Optional[List[Dict]] = None


def get_jeepney_lines() -> List[Dict]:
    global _jeepney_lines_cache
    if _jeepney_lines_cache is None:
        _jeepney_lines_cache = _load_jeepney_linestrings()
    return _jeepney_lines_cache


def create_bus_jeep_substitute_fn(passenger_type: str = "regular"):
    """
    Returns a function that takes a route dict and returns a variant with bus→jeepney
    substitution applied where overlap exists (for CHEAPEST preference).
    """

    from .fares.calculator import calculate_real_fare

    def substitute(route: Dict) -> Optional[Dict]:
        segments = route.get("segments", [])
        if not segments:
            return None
        jeep_lines = get_jeepney_lines()
        if not jeep_lines:
            return None

        new_segs = []
        changed = False
        for seg in segments:
            mode = (seg.get("mode") or "").upper()
            if mode != "BUS":
                new_segs.append(seg)
                continue

            overlap = find_overlapping_jeepney(seg, jeep_lines)
            if overlap:
                route_id, jname = overlap
                dist = seg.get("distance", 0)
                # CSV-based fare calculation (distance table). from/to IDs are unused for jeep.
                from_stop = seg.get("from_stop")
                to_stop = seg.get("to_stop")
                from_name = from_stop.get("name", "Departure") if isinstance(from_stop, dict) else "Departure"
                to_name = to_stop.get("name", "Arrival") if isinstance(to_stop, dict) else "Arrival"
                fare = calculate_real_fare(
                    mode="Jeep",
                    from_stop_id=from_name,
                    to_stop_id=to_name,
                    distance_km=dist,
                    fare_type=passenger_type,
                    fare_tables=getattr(__import__("maiwayrouting.google_adapter", fromlist=["FARE_TABLES"]), "FARE_TABLES", {}),
                    stops={from_name: {"name": from_name}, to_name: {"name": to_name}},
                )
                from_n = from_stop if isinstance(from_stop, dict) else {"name": from_name}
                to_n = to_stop if isinstance(to_stop, dict) else {"name": to_name}
                new_seg = {
                    "mode": "Jeep",
                    "route_id": route_id,
                    "name": jname,
                    "instruction": f"Take Jeepney ({jname}) from {from_name} to {to_name}",
                    "from_stop": from_n,
                    "to_stop": to_n,
                    "distance": dist,
                    "fare": fare,
                    "polyline": seg.get("polyline", []),
                }
                new_segs.append(new_seg)
                changed = True
            else:
                new_segs.append(seg)

        if not changed:
            return None

        total_cost = sum(s.get("fare", 0) for s in new_segs)
        total_dist = sum(s.get("distance", 0) for s in new_segs)
        return {
            "segments": new_segs,
            "total_distance": total_dist,
            "total_cost": total_cost,
            "total_time_min": route.get("total_time_min", 0),
        }

    return substitute
