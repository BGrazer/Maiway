"""
GeoJSON Route Matcher

Loads bus/jeep corridor GeoJSON LineStrings and matches an arbitrary polyline
([[lon, lat], ...]) to the best-aligned corridor. Used to label Google legs
with MaiWay route names (from GeoJSON) and to pick a corridor when multiple
overlap.
"""

from __future__ import annotations

import json
import logging
import os
import random
from typing import Dict, List, Optional, Tuple

logger = logging.getLogger(__name__)

_ROUTES_DIR = os.path.join(os.path.dirname(__file__), "..", "routing_data", "routes-geojson")
_DATA_DIR = os.path.join(os.path.dirname(__file__), "..", "routing_data")

# Default matching parameters
BUFFER_KM = 0.06          # how close points must be to a corridor
MIN_MATCH_RATIO = 0.35    # minimum fraction of points near corridor to accept
LRT_MIN_MATCH_RATIO = 0.25  # LRT often has fewer points; accept looser match

# If multiple corridors score within this delta of best, we can random-pick among them (optional)
TOP_DELTA = 0.03


def _point_to_line_distance(px: float, py: float, line_coords: List) -> float:
    """Approximate distance from point (lon, lat) to line segment in km."""
    if not line_coords or len(line_coords) < 2:
        return 999.0
    min_d = 999.0
    for i in range(len(line_coords) - 1):
        x1, y1 = line_coords[i][0], line_coords[i][1]
        x2, y2 = line_coords[i + 1][0], line_coords[i + 1][1]
        dx = x2 - x1
        dy = y2 - y1
        if dx == 0 and dy == 0:
            d = ((px - x1) ** 2 + (py - y1) ** 2) ** 0.5
        else:
            t = max(0.0, min(1.0, ((px - x1) * dx + (py - y1) * dy) / (dx * dx + dy * dy + 1e-10)))
            qx = x1 + t * dx
            qy = y1 + t * dy
            d = ((px - qx) ** 2 + (py - qy) ** 2) ** 0.5
        # Rough km: 1 deg ≈ 111 km at equator
        d_km = d * 111.0
        if d_km < min_d:
            min_d = d_km
    return min_d


def _overlap_ratio(polyline: List[List[float]], corridor_coords: List) -> float:
    """Fraction of polyline points within BUFFER_KM of the corridor."""
    if not polyline:
        return 0.0
    near = 0
    for pt in polyline:
        if len(pt) < 2:
            continue
        if _point_to_line_distance(pt[0], pt[1], corridor_coords) <= BUFFER_KM:
            near += 1
    return near / max(1, len(polyline))


def _canonical_id(prefix: str, name: str) -> str:
    slug = (name or "").strip().replace(" ", "_").replace("-", "_").replace("/", "_")
    slug = "".join(ch for ch in slug if ch.isalnum() or ch in {"_"}).strip("_")
    return f"{prefix}_{slug[:40] or 'UNKNOWN'}"


def _get_feature_name(props: dict, fname: str) -> str:
    """Get route name from feature properties; never return raw filename like 'jeep2.geojson'."""
    name = props.get("name") or props.get("Name")
    if name and (name := (name or "").strip()):
        return name
    # Some GeoJSON have "name " (trailing space)
    for k, v in (props or {}).items():
        if k.strip().lower() == "name" and v and (v := (v or "").strip()):
            return v
    # Fallback: human-readable from filename (e.g. jeep2.geojson -> Jeep 2)
    base = fname.replace(".geojson", "").replace(".GeoJSON", "").strip()
    if not base:
        return "Route"
    if base.lower().startswith("jeep"):
        return base[:4].title() + " " + base[4:] if len(base) > 4 else base.title()
    if base.lower().startswith("bus"):
        return base[:3].title() + " " + base[3:] if len(base) > 3 else base.title()
    return base.replace("_", " ").title()


def _load_corridors(kind: str) -> List[Dict]:
    """Load corridor LineStrings for 'bus', 'jeep', or 'lrt'."""
    kind_l = (kind or "").lower()
    out: List[Dict] = []

    # LRT: load lrtroutes.geojson from routes-geojson/ (fallback: routing_data/)
    if kind_l == "lrt":
        for base in (_ROUTES_DIR, _DATA_DIR):
            path = os.path.join(base, "lrtroutes.geojson")
            if not os.path.isfile(path):
                continue
            try:
                with open(path, "r", encoding="utf-8") as f:
                    data = json.load(f)
            except Exception as e:
                logger.debug("Could not load lrtroutes.geojson from %s: %s", base, e)
                continue
            for feat in data.get("features", []):
                geom = feat.get("geometry", {})
                if geom.get("type") != "LineString":
                    continue
                coords = geom.get("coordinates", [])
                if not coords:
                    continue
                props = feat.get("properties", {}) or {}
                name = props.get("name") or props.get("Name") or "LRT-1 Route"
                rid = _canonical_id("LRT", name)
                out.append({"kind": "lrt", "name": name, "route_id": rid, "coords": coords, "mode": "rail"})
            break
        return out

    if not os.path.isdir(_ROUTES_DIR):
        return []

    for fname in os.listdir(_ROUTES_DIR):
        if not fname.lower().endswith(".geojson"):
            continue
        f_l = fname.lower()
        if kind_l == "bus" and not f_l.startswith("bus"):
            continue
        if kind_l == "jeep" and not f_l.startswith("jeep"):
            continue

        path = os.path.join(_ROUTES_DIR, fname)
        try:
            with open(path, "r", encoding="utf-8") as f:
                data = json.load(f)
        except Exception as e:
            logger.debug("Could not load geojson %s: %s", fname, e)
            continue

        for feat in data.get("features", []):
            geom = feat.get("geometry", {})
            if geom.get("type") != "LineString":
                continue
            coords = geom.get("coordinates", [])
            if not coords:
                continue
            props = feat.get("properties", {}) or {}
            name = _get_feature_name(props, fname)
            mode = props.get("type") or props.get("Type") or kind_l
            if kind_l == "bus":
                rid = _canonical_id("BUS", name)
            else:
                rid = _canonical_id("JEEP", name)
            out.append({"kind": kind_l, "name": name, "route_id": rid, "coords": coords, "mode": mode})

    return out


_cache: Dict[str, List[Dict]] = {}


def get_corridors(kind: str) -> List[Dict]:
    kind_l = (kind or "").lower()
    if kind_l not in _cache:
        _cache[kind_l] = _load_corridors(kind_l)
    return _cache[kind_l]


def match_route(
    polyline: List[List[float]],
    kind: str,
    allow_random: bool = False,
) -> Optional[Tuple[str, str, float]]:
    """
    Return (route_id, name, score) for the best matching corridor, or None.

    If allow_random is True, and multiple corridors are within TOP_DELTA of the best score,
    returns a random one from that set.
    """
    corridors = get_corridors(kind)
    if not corridors or not polyline:
        return None

    scored: List[Tuple[float, Dict]] = []
    for c in corridors:
        score = _overlap_ratio(polyline, c["coords"])
        if score >= MIN_MATCH_RATIO:
            scored.append((score, c))
    if not scored:
        return None

    scored.sort(key=lambda x: x[0], reverse=True)
    best_score = scored[0][0]
    top = [c for (s, c) in scored if (best_score - s) <= TOP_DELTA]

    if allow_random and len(top) > 1:
        choice = random.choice(top)
    else:
        # deterministic: pick best name/route_id ordering among top
        top.sort(key=lambda c: (-( _overlap_ratio(polyline, c["coords"]) ), c.get("route_id", "")))
        choice = top[0]

    return choice["route_id"], choice["name"], best_score


def _point_to_point_dist_deg(lon1: float, lat1: float, lon2: float, lat2: float) -> float:
    """Approx distance in degree units (for comparing which vertex is closest)."""
    return (lon2 - lon1) ** 2 + (lat2 - lat1) ** 2


def _slice_corridor_between(
    corridor: List[List[float]],
    from_lon: float,
    from_lat: float,
    to_lon: float,
    to_lat: float,
) -> List[List[float]]:
    """
    Slice the corridor LineString so it runs from the point nearest (from_lon, from_lat)
    to the point nearest (to_lon, to_lat). Keeps the same start/end as the segment
    but follows the corridor curvature (e.g. LRT track) instead of a straight line.
    """
    if not corridor or len(corridor) < 2:
        return corridor or []
    best_i = 0
    best_j = 0
    best_d_from = 1e9
    best_d_to = 1e9
    for idx, pt in enumerate(corridor):
        if len(pt) < 2:
            continue
        lon, lat = pt[0], pt[1]
        d_from = _point_to_point_dist_deg(from_lon, from_lat, lon, lat)
        d_to = _point_to_point_dist_deg(to_lon, to_lat, lon, lat)
        if d_from < best_d_from:
            best_d_from = d_from
            best_i = idx
        if d_to < best_d_to:
            best_d_to = d_to
            best_j = idx
    if best_i <= best_j:
        seg = list(corridor[best_i : best_j + 1])
    else:
        seg = list(corridor[best_j : best_i + 1])
        seg.reverse()
    # Snap first/last to exact from/to so segment aligns with Google start/end
    if seg:
        seg[0] = [from_lon, from_lat]
        seg[-1] = [to_lon, to_lat]
    return seg


def match_lrt_route(
    polyline: List[List[float]],
    from_lat: Optional[float] = None,
    from_lon: Optional[float] = None,
    to_lat: Optional[float] = None,
    to_lon: Optional[float] = None,
) -> Optional[Tuple[str, str, List]]:
    """
    Match an LRT segment polyline to our LRT GeoJSON corridor.
    Returns (route_id, name, polyline_coords). If from_* and to_* are provided,
    the returned coords are sliced to run between those points along the corridor
    (same length as Google segment but following LRT curvature).
    """
    corridors = get_corridors("lrt")
    if not corridors or not polyline:
        return None

    best_score = 0.0
    best_c = None
    for c in corridors:
        score = _overlap_ratio(polyline, c["coords"])
        if score >= LRT_MIN_MATCH_RATIO and score > best_score:
            best_score = score
            best_c = c
    if not best_c:
        return None

    coords = list(best_c["coords"])
    if from_lat is not None and from_lon is not None and to_lat is not None and to_lon is not None:
        coords = _slice_corridor_between(coords, from_lon, from_lat, to_lon, to_lat)
    return best_c["route_id"], best_c["name"], coords

