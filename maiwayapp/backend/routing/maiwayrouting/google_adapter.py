"""
MaiWay Google Directions API Adapter

Calls Google Directions API (transit + walking) and maps response to MaiWay segment format.
Supports three-route synthesis (FASTEST, CHEAPEST, MOST CONVENIENT) and bus→jeepney substitution.
"""

import os
import json
import logging
import urllib.parse
import urllib.request
from typing import Dict, List, Any, Optional, Tuple

from .fares.calculator import calculate_real_fare
from .geojson_route_matcher import match_route, match_lrt_route, get_corridors

logger = logging.getLogger(__name__)

# Fare tables are loaded in `routing.py` and passed into `find_routes_google_hybrid`.
# Keep a module-level fallback so the adapter can remain stateless for callers.
FARE_TABLES: Dict[str, Any] = {}

# Max walk distance (km) to a transit stop when fallback "walk then transit" is used
WALK_TO_TRANSIT_MAX_KM = 1.5

# Perturb origin/destination by this radius (m) when we need different route options
# Use 500m so we get meaningfully different routes; override with env PERTURB_RADIUS_M.
PERTURB_RADIUS_M = 500


def _haversine_km(lat1: float, lon1: float, lat2: float, lon2: float) -> float:
    """Approximate distance in km between two points (WGS84)."""
    import math
    R = 6371.0
    a = math.radians(lat2 - lat1)
    b = math.radians(lon2 - lon1)
    x = math.sin(a / 2) ** 2 + math.cos(math.radians(lat1)) * math.cos(math.radians(lat2)) * math.sin(b / 2) ** 2
    return 2 * R * math.asin(math.sqrt(min(1.0, x)))


def _nearest_stop(
    origin_lat: float, origin_lon: float,
    stops: List[Dict],
    max_km: float = WALK_TO_TRANSIT_MAX_KM,
) -> Optional[Tuple[float, float, str]]:
    """Return (lat, lon, name) of nearest stop within max_km, or None."""
    if not stops:
        return None
    best = None
    best_km = max_km
    for s in stops:
        slat = s.get("lat") if isinstance(s.get("lat"), (int, float)) else None
        slon = s.get("lon") if isinstance(s.get("lon"), (int, float)) else None
        if slat is None or slon is None:
            continue
        d = _haversine_km(origin_lat, origin_lon, slat, slon)
        if d < best_km:
            best_km = d
            name = s.get("name") or s.get("id") or "Transit stop"
            best = (slat, slon, name)
    return best


def _is_walking_only(route: Dict) -> bool:
    """True if the route has no transit segments."""
    for seg in route.get("segments", []):
        if seg.get("mode") and str(seg.get("mode")).lower() != "walking":
            return False
    return True


def _route_allowed_by_modes(route: Dict, allowed_modes: List[str]) -> bool:
    """
    True if the route uses only modes allowed by the user's travel preferences.
    Walking is always allowed since first/last mile walking is unavoidable.
    """
    allowed = {str(m).strip().lower() for m in (allowed_modes or [])}
    if not allowed:
        return True

    for seg in route.get("segments", []):
        mode_raw = str(seg.get("mode") or "").strip().lower()
        if not mode_raw:
            continue
        if mode_raw in {"walking", "walk"}:
            continue
        if mode_raw in {"bus"}:
            if "bus" not in allowed:
                return False
            continue
        if mode_raw in {"jeep", "jeepney"}:
            if "jeepney" not in allowed and "jeep" not in allowed:
                return False
            continue
        if mode_raw in {"lrt", "rail", "subway", "metro", "tram", "train"}:
            if "lrt" not in allowed:
                return False
            continue
        if mode_raw in {"tricycle"}:
            if "tricycle" not in allowed:
                return False
            continue
        # Unknown transit mode: be conservative and treat it as disallowed
        return False

    return True


def _random_offset_m(lat: float, lon: float, radius_m: float = PERTURB_RADIUS_M) -> Tuple[float, float]:
    """Return (lat', lon') a random point within radius_m meters of (lat, lon)."""
    import math
    import random
    # 1 deg lat ≈ 111 km; 1 deg lon ≈ 111*cos(lat) km
    d_deg = radius_m / (111_000.0 * max(0.1, math.cos(math.radians(lat))))
    angle = random.uniform(0, 2 * math.pi)
    dlat = d_deg * math.cos(angle)
    dlon = d_deg * math.sin(angle) / max(0.1, math.cos(math.radians(lat)))
    return (lat + dlat, lon + dlon)


def _re_anchor_route(
    route: Dict,
    real_origin_lat: float, real_origin_lon: float,
    real_dest_lat: float, real_dest_lon: float,
) -> Dict:
    """
    Re-anchor a route so it starts at real origin and ends at real destination.
    If first segment is walking: set its start to real origin and recompute polyline.
    If first segment is transit: prepend a walking segment from real origin to first stop.
    Same for last segment (walking vs transit) and real destination.
    """
    segs = list(route.get("segments", []))
    if not segs:
        return route

    new_segs = []
    first = dict(segs[0])
    last = dict(segs[-1])

    # Start: real origin
    if first.get("mode") == "Walking":
        first["from_stop"] = {"name": "Origin", "lat": real_origin_lat, "lon": real_origin_lon, "id": "ORIGIN"}
        poly = _call_mapbox_walking_polyline(real_origin_lat, real_origin_lon, first["to_stop"]["lat"], first["to_stop"]["lon"])
        if not poly:
            poly = _call_google_walking_polyline(real_origin_lat, real_origin_lon, first["to_stop"]["lat"], first["to_stop"]["lon"])
        if poly:
            first["polyline"] = poly
        first["distance"] = _haversine_km(real_origin_lat, real_origin_lon, first["to_stop"]["lat"], first["to_stop"]["lon"])
        new_segs.append(first)
    else:
        # Prepend walk from real origin to first transit stop
        to_lat = first["from_stop"].get("lat", 0)
        to_lon = first["from_stop"].get("lon", 0)
        to_name = first["from_stop"].get("name", "Transit stop")
        poly = _call_mapbox_walking_polyline(real_origin_lat, real_origin_lon, to_lat, to_lon)
        if not poly:
            poly = _call_google_walking_polyline(real_origin_lat, real_origin_lon, to_lat, to_lon)
        if not poly:
            poly = [[real_origin_lon, real_origin_lat], [to_lon, to_lat]]
        walk_km = _haversine_km(real_origin_lat, real_origin_lon, to_lat, to_lon)
        new_segs.append({
            "mode": "Walking",
            "route_id": None,
            "name": None,
            "instruction": f"Walk to {to_name}",
            "from_stop": {"name": "Origin", "lat": real_origin_lat, "lon": real_origin_lon, "id": "ORIGIN"},
            "to_stop": {"name": to_name, "lat": to_lat, "lon": to_lon, "id": to_name},
            "distance": walk_km,
            "fare": 0.0,
            "polyline": poly,
        })
        new_segs.append(first)

    # Middle segments unchanged
    for s in segs[1:-1]:
        new_segs.append(dict(s))

    # End: real destination
    if last.get("mode") == "Walking":
        last["to_stop"] = {"name": "Destination", "lat": real_dest_lat, "lon": real_dest_lon, "id": "DESTINATION"}
        poly = _call_mapbox_walking_polyline(last["from_stop"]["lat"], last["from_stop"]["lon"], real_dest_lat, real_dest_lon)
        if not poly:
            poly = _call_google_walking_polyline(last["from_stop"]["lat"], last["from_stop"]["lon"], real_dest_lat, real_dest_lon)
        if poly:
            last["polyline"] = poly
        last["distance"] = _haversine_km(last["from_stop"]["lat"], last["from_stop"]["lon"], real_dest_lat, real_dest_lon)
        new_segs.append(last)
    else:
        new_segs.append(last)
        # Append walk from last transit stop to real destination
        from_lat = last["to_stop"].get("lat", 0)
        from_lon = last["to_stop"].get("lon", 0)
        from_name = last["to_stop"].get("name", "Transit stop")
        poly = _call_mapbox_walking_polyline(from_lat, from_lon, real_dest_lat, real_dest_lon)
        if not poly:
            poly = _call_google_walking_polyline(from_lat, from_lon, real_dest_lat, real_dest_lon)
        if not poly:
            poly = [[from_lon, from_lat], [real_dest_lon, real_dest_lat]]
        walk_km = _haversine_km(from_lat, from_lon, real_dest_lat, real_dest_lon)
        new_segs.append({
            "mode": "Walking",
            "route_id": None,
            "name": None,
            "instruction": "Walk to your destination",
            "from_stop": {"name": from_name, "lat": from_lat, "lon": from_lon, "id": from_name},
            "to_stop": {"name": "Destination", "lat": real_dest_lat, "lon": real_dest_lon, "id": "DESTINATION"},
            "distance": walk_km,
            "fare": 0.0,
            "polyline": poly,
        })

    total_dist = sum(s.get("distance", 0) for s in new_segs)
    total_cost = sum(s.get("fare", 0) for s in new_segs)
    return {
        "segments": new_segs,
        "total_distance": total_dist,
        "total_cost": total_cost,
        "total_time_min": route.get("total_time_min", 0),
    }

# Route names and IDs: bus/jeep/LRT from routes-geojson, tricycle from tricycle_terminals.geojson
def _geo_aliases(kind: str) -> List[Tuple[str, List[str]]]:
    out: List[Tuple[str, List[str]]] = []
    for c in get_corridors(kind):
        rid = c.get("route_id") or ""
        name = (c.get("name") or "").strip()
        aliases = [name] if name else []
        if rid:
            aliases.append(rid)
        if rid and aliases:
            out.append((rid, aliases))
    return out


BUS_GEOJSON_ALIASES: List[Tuple[str, List[str]]] = _geo_aliases("bus")
JEEP_GEOJSON_ALIASES: List[Tuple[str, List[str]]] = _geo_aliases("jeep")
LRT_GEOJSON_ALIASES: List[Tuple[str, List[str]]] = _geo_aliases("lrt")


def _trike_geo_aliases() -> List[Tuple[str, List[str]]]:
    """(route_id, [name]) from routing_data/tricycle_terminals.geojson for TODA names."""
    out: List[Tuple[str, List[str]]] = []
    data_dir = os.path.join(os.path.dirname(__file__), "..", "routing_data")
    path = os.path.join(data_dir, "tricycle_terminals.geojson")
    if not os.path.isfile(path):
        return out
    try:
        with open(path, "r", encoding="utf-8") as f:
            geo = json.load(f)
    except Exception as e:
        logger.warning("Could not load tricycle_terminals.geojson: %s", e)
        return out
    for feat in geo.get("features", []):
        if feat.get("geometry", {}).get("type") != "Point":
            continue
        props = feat.get("properties", {}) or {}
        name = (props.get("name") or props.get("Name") or "").strip()
        if not name:
            continue
        slug = name.replace(" ", "_").replace("-", "_").replace("/", "_")
        slug = "".join(c for c in slug if c.isalnum() or c == "_").strip("_")[:40] or "UNKNOWN"
        rid = f"TRIKE_{slug}"
        out.append((rid, [name, rid]))
    return out


TRIKE_GEOJSON_ALIASES: List[Tuple[str, List[str]]] = _trike_geo_aliases()


def _get_google_api_key() -> Optional[str]:
    return os.getenv("GOOGLE_MAPS_API_KEY") or os.getenv("GOOGLE_API_KEY")


def _normalize_route_id(mode: str, raw_name: str) -> str:
    """Map raw line/route name to canonical route_id. Bus/jeepney use names from routes-geojson."""
    raw_lower = (raw_name or "").strip().lower()
    if mode == "bus":
        for canon_id, aliases in BUS_GEOJSON_ALIASES:
            for alias in aliases:
                if alias and (alias.lower() in raw_lower or raw_lower in alias.lower()):
                    return canon_id
        return f"BUS_{raw_name.replace(' ', '_')[:30]}" if raw_name else "BUS_UNKNOWN"
    if mode == "lrt":
        for canon_id, aliases in LRT_GEOJSON_ALIASES:
            for alias in aliases:
                if alias and (alias.lower() in raw_lower or raw_lower in alias.lower()):
                    return canon_id
        return "LRT1_UNKNOWN" if raw_lower else "LRT1_UNKNOWN"
    if mode == "jeepney":
        for canon_id, aliases in JEEP_GEOJSON_ALIASES:
            for alias in aliases:
                if alias and (alias.lower() in raw_lower or raw_lower in alias.lower()):
                    return canon_id
        return f"JEEP_{raw_name.replace(' ', '_')[:25]}" if raw_name else "JEEP_UNKNOWN"
    if mode == "tricycle":
        for canon_id, aliases in TRIKE_GEOJSON_ALIASES:
            for alias in aliases:
                if alias and (alias.lower() in raw_lower or raw_lower in alias.lower()):
                    return canon_id
        return f"TRIKE_{raw_name.replace(' ', '_')[:20]}" if raw_name else "TRIKE_UNKNOWN"
    return "UNKNOWN"


def _decode_polyline(encoded: str) -> List[List[float]]:
    """Decode Google's encoded polyline to [[lon, lat], ...]."""
    if not encoded:
        return []
    try:
        import polyline
        decoded = polyline.decode(encoded)
        return [[p[1], p[0]] for p in decoded]  # [lat,lon] -> [lon,lat] for GeoJSON
    except Exception:
        return []


def _get_mapbox_token() -> Optional[str]:
    return os.getenv("MAPBOX_TOKEN", "").strip() or None


def _call_mapbox_walking_polyline(
    from_lat: float, from_lon: float,
    to_lat: float, to_lon: float,
) -> List[List[float]]:
    """
    Call Mapbox Directions API with walking profile for road-following polyline.
    Uses MAPBOX_TOKEN so we don't stress Google. Returns [[lon, lat], ...] or [].
    """
    token = _get_mapbox_token()
    if not token:
        return []
    try:
        # Mapbox: coordinates as lon,lat; semicolon-separated
        coords = f"{from_lon},{from_lat};{to_lon},{to_lat}"
        url = f"https://api.mapbox.com/directions/v5/mapbox/walking/{coords}"
        params = urllib.parse.urlencode({
            "geometries": "geojson",
            "overview": "full",
            "access_token": token,
        })
        full_url = f"{url}?{params}"
        r = urllib.request.Request(full_url, headers={"User-Agent": "MaiWay/1.0"})
        with urllib.request.urlopen(r, timeout=10) as resp:
            data = json.loads(resp.read().decode())
    except Exception as e:
        logger.debug(f"Mapbox walking directions error: {e}")
        return []
    routes = data.get("routes")
    if not routes:
        return []
    geom = routes[0].get("geometry")
    if not geom or geom.get("type") != "LineString":
        return []
    coords_list = geom.get("coordinates", [])
    # GeoJSON is [lon, lat]
    return [[float(c[0]), float(c[1])] for c in coords_list]


def _call_google_walking_polyline(
    from_lat: float, from_lon: float,
    to_lat: float, to_lon: float,
) -> List[List[float]]:
    """
    Fallback: Google Directions API mode=walking. Used only if Mapbox fails or no token.
    Returns [[lon, lat], ...] or empty list.
    """
    key = _get_google_api_key()
    if not key:
        return []
    origin = f"{from_lat},{from_lon}"
    dest = f"{to_lat},{to_lon}"
    params = {
        "origin": origin,
        "destination": dest,
        "mode": "walking",
        "key": key,
    }
    url = "https://maps.googleapis.com/maps/api/directions/json?" + urllib.parse.urlencode(params)
    try:
        req = urllib.request.Request(url, headers={"User-Agent": "MaiWay/1.0"})
        with urllib.request.urlopen(req, timeout=10) as resp:
            data = json.loads(resp.read().decode())
    except Exception as e:
        logger.debug(f"Google walking directions error: {e}")
        return []
    if data.get("status") != "OK" or not data.get("routes"):
        return []
    points: List[List[float]] = []
    for leg in data["routes"][0].get("legs", []):
        for step in leg.get("steps", []):
            enc = step.get("polyline", {}).get("points", "")
            decoded = _decode_polyline(enc)
            if decoded:
                if points and decoded[0] == points[-1]:
                    points.extend(decoded[1:])
                else:
                    points.extend(decoded)
    return points if points else []


def _call_google_directions(
    origin_lat: float, origin_lon: float,
    dest_lat: float, dest_lon: float,
    alternatives: bool = True,
    transit_routing_preference: Optional[str] = None,
) -> Optional[Dict]:
    """Call Google Directions API with transit mode."""
    key = _get_google_api_key()
    if not key:
        logger.warning("GOOGLE_MAPS_API_KEY or GOOGLE_API_KEY not set")
        return None

    origin = f"{origin_lat},{origin_lon}"
    dest = f"{dest_lat},{dest_lon}"
    params = {
        "origin": origin,
        "destination": dest,
        "mode": "transit",
        "alternatives": "true" if alternatives else "false",
        "key": key,
    }
    if transit_routing_preference:
        params["transit_routing_preference"] = transit_routing_preference

    url = "https://maps.googleapis.com/maps/api/directions/json?" + urllib.parse.urlencode(params)
    try:
        req = urllib.request.Request(url, headers={"User-Agent": "MaiWay/1.0"})
        with urllib.request.urlopen(req, timeout=15) as resp:
            data = json.loads(resp.read().decode())
    except Exception as e:
        logger.error(f"Google Directions API error: {e}")
        return None

    if data.get("status") != "OK":
        logger.warning(f"Google Directions status: {data.get('status')} - {data.get('error_message', '')}")
        return None

    return data


def _google_route_to_segments(route: Dict, passenger_type: str = "regular") -> Tuple[List[Dict], float, float]:
    """
    Convert one Google route to MaiWay segment format.
    Returns (segments, total_distance_km, total_fare).
    """
    segments = []
    total_dist = 0.0
    total_fare = 0.0

    for leg in route.get("legs", []):
        for step in leg.get("steps", []):
            dist_m = step.get("distance", {}).get("value", 0) or 0
            dist_km = dist_m / 1000.0
            total_dist += dist_km

            start = step.get("start_location", {})
            end = step.get("end_location", {})
            from_lat = start.get("lat", 0) or start.get("latitude", 0)
            from_lon = start.get("lng", 0) or start.get("lon", 0) or start.get("longitude", 0)
            to_lat = end.get("lat", 0) or end.get("latitude", 0)
            to_lon = end.get("lng", 0) or end.get("lon", 0) or end.get("longitude", 0)

            td = step.get("transit_details", {})
            polyline_enc = (step.get("polyline") or {}).get("points", "")
            polyline_coords = _decode_polyline(polyline_enc)
            # For walking steps: use Mapbox walking (then Google fallback) for road-following path
            if not td and (from_lat or from_lon or to_lat or to_lon):
                if len(polyline_coords) <= 2:
                    walking_poly = _call_mapbox_walking_polyline(from_lat, from_lon, to_lat, to_lon)
                    if not walking_poly:
                        walking_poly = _call_google_walking_polyline(from_lat, from_lon, to_lat, to_lon)
                    if walking_poly:
                        polyline_coords = walking_poly
                if not polyline_coords:
                    polyline_coords = [[from_lon, from_lat], [to_lon, to_lat]]
            elif not polyline_coords and (from_lat or to_lat):
                polyline_coords = [[from_lon, from_lat], [to_lon, to_lat]]

            if td:
                line = td.get("line", {})
                vehicle = line.get("vehicle", {})
                vtype = (vehicle.get("type") or "").upper()
                short_name = line.get("short_name", "") or line.get("name", "")
                dep_stop = td.get("departure_stop") or td.get("departureStop", {})
                arr_stop = td.get("arrival_stop") or td.get("arrivalStop", {})
                from_name = dep_stop.get("name", "Departure")
                to_name = arr_stop.get("name", "Arrival")

                if "RAIL" in vtype or "SUBWAY" in vtype or "METRO" in vtype or "TRAM" in vtype:
                    mode = "LRT"
                else:
                    mode = "Bus"

                route_id = _normalize_route_id(mode.lower(), short_name)
                seg_name = short_name or route_id

                # Prefer naming (and polyline for LRT) from our GeoJSON when possible
                if mode == "Bus" and polyline_coords and len(polyline_coords) >= 2:
                    # When multiple bus routes overlap, pick one at random (e.g. Biñan–Lawton vs others)
                    allow_random = os.getenv("GEOJSON_ROUTE_RANDOM", "true").strip().lower() in {"1", "true", "yes"}
                    matched = match_route(polyline_coords, kind="bus", allow_random=allow_random)
                    if matched:
                        route_id, seg_name, _score = matched
                elif mode == "LRT" and polyline_coords and len(polyline_coords) >= 2:
                    lrt_match = match_lrt_route(
                        polyline_coords,
                        from_lat=from_lat,
                        from_lon=from_lon,
                        to_lat=to_lat,
                        to_lon=to_lon,
                    )
                    if lrt_match:
                        route_id, seg_name, geo_coords = lrt_match
                        polyline_coords = geo_coords  # use GeoJSON curvature, same segment length as Google
                # CSV-based fare calculation. We use stop names as IDs for LRT matching.
                fare = calculate_real_fare(
                    mode=mode,
                    from_stop_id=from_name,
                    to_stop_id=to_name,
                    distance_km=dist_km,
                    fare_type=passenger_type,
                    fare_tables=FARE_TABLES,
                    stops={from_name: {"name": from_name}, to_name: {"name": to_name}},
                )
                total_fare += fare

                dep_id = dep_stop.get("name") or dep_stop.get("id", from_name)
                arr_id = arr_stop.get("name") or arr_stop.get("id", to_name)
                # Instruction with route name in parentheses (like jeepney) for display
                instruction = f"Take {mode} ({seg_name}) from {from_name} to {to_name}" if seg_name else f"Take {mode} from {from_name} to {to_name}"
                seg = {
                    "mode": mode,
                    "route_id": route_id,
                    "name": seg_name,
                    "instruction": instruction,
                    "from_stop": {"name": from_name, "lat": from_lat, "lon": from_lon, "id": dep_id},
                    "to_stop": {"name": to_name, "lat": to_lat, "lon": to_lon, "id": arr_id},
                    "distance": dist_km,
                    "fare": fare,
                    "polyline": polyline_coords,
                }
            else:
                from_name = step.get("html_instructions", "Walk")[:50] or "Walk"
                to_name = "Next"
                seg = {
                    "mode": "Walking",
                    "route_id": None,
                    "instruction": from_name if "Walk" in str(from_name) else f"Walk to next",
                    "from_stop": {"name": "Start", "lat": from_lat, "lon": from_lon, "id": "WALK"},
                    "to_stop": {"name": "End", "lat": to_lat, "lon": to_lon, "id": "WALK"},
                    "distance": dist_km,
                    "fare": 0.0,
                    "polyline": polyline_coords,
                }

            segments.append(seg)

    return segments, total_dist, total_fare


def fetch_google_routes(
    start_lat: float, start_lon: float,
    end_lat: float, end_lon: float,
    passenger_type: str = "regular",
    stops: Optional[List[Dict]] = None,
) -> List[Dict]:
    """
    Fetch up to 3 route alternatives from Google.
    Each item: {"segments": [...], "total_distance": float, "total_cost": float, "total_time_min": float}
    If all routes are walking-only and stops are provided, tries "walk to nearest transit stop then Google"
    to get transit options.
    """
    # First call: default (time-optimized)
    data1 = _call_google_directions(start_lat, start_lon, end_lat, end_lon, alternatives=True)
    routes = []

    if not data1 or not data1.get("routes"):
        return routes

    for route in data1.get("routes", [])[:3]:
        total_time_sec = sum(
            leg.get("duration", {}).get("value", 0) or 0
            for leg in route.get("legs", [])
        )
        segs, dist, fare = _google_route_to_segments(route, passenger_type)
        if segs:
            routes.append({
                "segments": segs,
                "total_distance": dist,
                "total_cost": fare,
                "total_time_min": total_time_sec / 60.0,
            })

    # If we got < 2 routes, try different transit preference for more variety
    if len(routes) < 2:
        data2 = _call_google_directions(
            start_lat, start_lon, end_lat, end_lon,
            alternatives=False,
            transit_routing_preference="fewer_transfers",
        )
        if data2 and data2.get("routes"):
            r = data2["routes"][0]
            total_time_sec = sum(leg.get("duration", {}).get("value", 0) or 0 for leg in r.get("legs", []))
            segs, dist, fare = _google_route_to_segments(r, passenger_type)
            if segs and not _route_signature_match(routes, segs):
                routes.append({
                    "segments": segs,
                    "total_distance": dist,
                    "total_cost": fare,
                    "total_time_min": total_time_sec / 60.0,
                })

    # Bypass: if every route is walking-only and we have stops, try "walk to nearest stop then transit"
    if routes and all(_is_walking_only(r) for r in routes) and stops:
        nearest = _nearest_stop(start_lat, start_lon, stops)
        if nearest:
            stop_lat, stop_lon, stop_name = nearest
            data3 = _call_google_directions(stop_lat, stop_lon, end_lat, end_lon, alternatives=False)
            if data3 and data3.get("routes"):
                r = data3["routes"][0]
                segs, dist, fare = _google_route_to_segments(r, passenger_type)
                if segs and not _is_walking_only({"segments": segs}):
                    # Prepend walk from origin to stop
                    walk_poly = _call_mapbox_walking_polyline(start_lat, start_lon, stop_lat, stop_lon)
                    if not walk_poly:
                        walk_poly = _call_google_walking_polyline(start_lat, start_lon, stop_lat, stop_lon)
                    if not walk_poly:
                        walk_poly = [[start_lon, start_lat], [stop_lon, stop_lat]]
                    walk_km = _haversine_km(start_lat, start_lon, stop_lat, stop_lon)
                    walk_seg = {
                        "mode": "Walking",
                        "route_id": None,
                        "instruction": f"Walk to {stop_name}",
                        "from_stop": {"name": "Origin", "lat": start_lat, "lon": start_lon, "id": "ORIGIN"},
                        "to_stop": {"name": stop_name, "lat": stop_lat, "lon": stop_lon, "id": stop_name},
                        "distance": walk_km,
                        "fare": 0.0,
                        "polyline": walk_poly,
                    }
                    combined_segs = [walk_seg] + segs
                    total_dist = walk_km + sum(s.get("distance", 0) for s in segs)
                    total_fare = sum(s.get("fare", 0) for s in segs)
                    total_time_sec = sum(leg.get("duration", {}).get("value", 0) or 0 for leg in r.get("legs", []))
                    # Add a rough 15 min for walking to stop
                    total_time_min = total_time_sec / 60.0 + 15.0
                    if not _route_signature_match(routes, combined_segs):
                        routes.append({
                            "segments": combined_segs,
                            "total_distance": total_dist,
                            "total_cost": total_fare,
                            "total_time_min": total_time_min,
                        })
                        logger.info("Added walk-to-transit fallback route to %s", stop_name)
    return routes


def _stop_name_safe(stop: Any) -> str:
    """Get stop name from segment from_stop/to_stop; handles dict or string (e.g. 'ORIGIN')."""
    if isinstance(stop, dict):
        return stop.get("name", "") or stop.get("id", "") or ""
    return str(stop) if stop is not None else ""


def _route_signature_match(existing: List[Dict], new_segs: List[Dict]) -> bool:
    """Check if new route is essentially same as any existing."""
    def sig(segs):
        return tuple((_stop_name_safe(s.get("from_stop")), _stop_name_safe(s.get("to_stop")), s.get("mode")) for s in segs)
    ns = sig(new_segs)
    for r in existing:
        segs = r.get("segments", []) if isinstance(r, dict) else []
        if sig(segs) == ns:
            return True
    return False


def synthesize_three_routes(
    google_routes: List[Dict],
    bus_jeep_substitute_fn=None,
    allowed_modes: Optional[List[str]] = None,
) -> Dict[str, Dict]:
    """
    Ensure we have exactly three routes: fastest, cheapest, convenient.
    When Google returns 1 or 2, synthesize variants via bus→jeep substitution.
    Pure walking routes are only used when *all* routes are walking-only; if at
    least one route has transit, fastest/cheapest/convenient are chosen from the
    transit-capable set so we don't surface "walk 2 km for ₱0" as the main
    alternatives when real transit exists.
    """
    result = {"fastest": {}, "cheapest": {}, "convenient": {}}
    if not google_routes:
        return result

    # Apply bus→jeep substitution if provided
    augmented = []
    for r in google_routes:
        augmented.append(r)
        if bus_jeep_substitute_fn:
            variant = bus_jeep_substitute_fn(r)
            if variant and not _route_signature_match(augmented, variant.get("segments", [])):
                augmented.append(variant)

    # Enforce user travel-preference mode filtering (walking always allowed).
    if allowed_modes:
        augmented = [r for r in augmented if _route_allowed_by_modes(r, allowed_modes)]

    if not augmented:
        return result

    # Prefer routes that actually use transit; fall back to walking-only set
    # only when *every* candidate is walking-only.
    transit_candidates = [r for r in augmented if not _is_walking_only(r)]
    ranking_pool = transit_candidates or augmented

    # Rank by time, fare, convenience
    by_time = sorted(ranking_pool, key=lambda x: x.get("total_time_min", float("inf")))
    by_fare = sorted(ranking_pool, key=lambda x: x.get("total_cost", float("inf")))
    by_convenience = sorted(
        ranking_pool,
        key=lambda x: (
            -len([s for s in x.get("segments", []) if s.get("mode") not in ("Walking",)]),  # fewer transit legs = more convenient
            x.get("total_time_min", float("inf")),
        ),
    )

    result["fastest"] = _route_to_response(by_time[0]) if by_time else {}
    result["cheapest"] = _route_to_response(by_fare[0]) if by_fare else {}
    result["convenient"] = _route_to_response(by_convenience[0]) if by_convenience else {}

    # Ensure distinctness: if cheapest == fastest, use next cheapest
    if result["cheapest"] and result["fastest"] and _same_route(result["cheapest"], result["fastest"]):
        for r in by_fare[1:]:
            cand = _route_to_response(r)
            if cand and not _same_route(cand, result["fastest"]):
                result["cheapest"] = cand
                break

    # If convenient == fastest, use next
    if result["convenient"] and result["fastest"] and _same_route(result["convenient"], result["fastest"]):
        for r in by_convenience[1:]:
            cand = _route_to_response(r)
            if cand and not _same_route(cand, result["fastest"]):
                result["convenient"] = cand
                break

    return result


def _route_to_response(route: Dict) -> Dict:
    """Convert internal route dict to MaiWay API response format."""
    segs = route.get("segments", [])
    if not segs:
        return {}
    total_cost = sum(s.get("fare", 0) for s in segs)
    total_dist = sum(s.get("distance", 0) for s in segs)
    return {
        "segments": segs,
        "total_distance": total_dist,
        "total_cost": total_cost,
        "summary": {
            "total_distance": total_dist,
            "total_cost": total_cost,
            "fare_breakdown": _fare_breakdown(segs),
        },
        "stops": _extract_stops(segs),
    }


def _fare_breakdown(segs: List[Dict]) -> Dict[str, float]:
    out = {}
    for s in segs:
        m = s.get("mode", "Walking")
        if m not in out:
            out[m] = 0.0
        out[m] += s.get("fare", 0)
    return out


def _extract_stops(segs: List[Dict]) -> List[Dict]:
    seen = set()
    stops = []
    for s in segs:
        for key in ("from_stop", "to_stop"):
            st = s.get(key, {})
            if isinstance(st, dict):
                name = st.get("name", "")
                lat = st.get("lat", 0)
                lon = st.get("lon", 0)
                if name and (name, lat, lon) not in seen:
                    seen.add((name, lat, lon))
                    stops.append({"name": name, "lat": lat, "lon": lon})
    return stops


def _same_route(a: Dict, b: Dict) -> bool:
    sa = a.get("segments", []) if isinstance(a, dict) else []
    sb = b.get("segments", []) if isinstance(b, dict) else []
    if len(sa) != len(sb):
        return False
    for i, seg_a in enumerate(sa):
        seg_b = sb[i] if i < len(sb) else {}
        if seg_a.get("mode") != seg_b.get("mode"):
            return False
        if _stop_name_safe(seg_a.get("from_stop")) != _stop_name_safe(seg_b.get("from_stop")):
            return False
    return True


def _first_transit_stop(segs: List[Dict]) -> Optional[Dict]:
    """Return from_stop of the first non-walking segment, or None."""
    for s in segs:
        if str(s.get("mode", "")).lower() != "walking":
            return s.get("from_stop") if isinstance(s.get("from_stop"), dict) else None
    return None


def _last_transit_stop(segs: List[Dict]) -> Optional[Dict]:
    """Return to_stop of the last non-walking segment, or None."""
    for s in reversed(segs):
        if str(s.get("mode", "")).lower() != "walking":
            return s.get("to_stop") if isinstance(s.get("to_stop"), dict) else None
    return None


def _is_stop_near(to_stop: Any, lat: float, lon: float, tol_km: float = 0.05) -> bool:
    """True if to_stop (dict with lat/lon or id) is at/near (lat, lon)."""
    if not isinstance(to_stop, dict):
        return False
    slat = to_stop.get("lat") if isinstance(to_stop.get("lat"), (int, float)) else None
    slon = to_stop.get("lon") if isinstance(to_stop.get("lon"), (int, float)) else None
    if slat is None or slon is None:
        return to_stop.get("id") == "DESTINATION" or (to_stop.get("name") or "").lower() == "destination"
    return _haversine_km(slat, slon, lat, lon) <= tol_km


def _strip_trailing_walk_to_destination(
    segs: List[Dict], dest_lat: float, dest_lon: float,
) -> Tuple[List[Dict], float, float]:
    """
    Remove trailing walking segments that go to the destination so we can inject
    tricycle between last transit and destination. Returns (stripped_segs, cost_removed, dist_removed).
    """
    removed_cost = 0.0
    removed_dist = 0.0
    while segs and str(segs[-1].get("mode", "")).lower() == "walking":
        last = segs[-1]
        to_stop = last.get("to_stop")
        if _is_stop_near(to_stop, dest_lat, dest_lon):
            segs = segs[:-1]
            removed_cost += last.get("fare", 0)
            removed_dist += last.get("distance", 0)
        else:
            break
    return segs, removed_cost, removed_dist


def _strip_leading_walk_to_first_transit(segs: List[Dict]) -> Tuple[List[Dict], float, float]:
    """
    Remove leading walking segments up to the first transit leg. This is used when
    injecting first-mile tricycle so we don't keep the original "walk to stop"
    segment(s) in addition to walk→terminal + trike→stop.
    Returns (stripped_segs, cost_removed, dist_removed).
    """
    removed_cost = 0.0
    removed_dist = 0.0
    out = list(segs)
    while out and str(out[0].get("mode", "")).lower() == "walking":
        first = out[0]
        removed_cost += first.get("fare", 0) or 0.0
        removed_dist += first.get("distance", 0) or 0.0
        out = out[1:]
    return out, removed_cost, removed_dist


# Spatial awareness: use terminal only when it's favorable (on the way, short walk).
WALK_TERMINAL_TO_DEST_MAX_KM = 0.4   # max walk from terminal to dest to use terminal
TERMINAL_DETOUR_MAX_RATIO = 1.25     # max ratio (last_stop→terminal)/(last_stop→dest) to use terminal
FIRST_MILE_DETOUR_MAX_RATIO = 1.3    # max (origin→term + term→first_stop)/(origin→first_stop) for first-mile


def _inject_tricycle_convenient(
    convenient_route: Dict,
    origin_lat: float, origin_lon: float,
    dest_lat: float, dest_lon: float,
    trike_terminals: List[Dict],
) -> Dict:
    """
    If the convenient route and origin/destination allow, inject first-mile and/or
    last-mile tricycle using tricycle_terminals.geojson (same logic as old engine).
    User walks to terminal, trike to next transport (or from last transport to terminal, then walk to destination).
    """
    if not trike_terminals or not convenient_route.get("segments"):
        return convenient_route

    try:
        from maiwayrouting.utils.trike_utils import (
            nearest_terminal,
            build_trike_segment,
            TRIKE_CATCHMENT_KM,
            TRIKE_MIN_DISTANCE_KM,
            TRIKE_MAX_DISTANCE_KM,
            TRIKE_MIN_SAVING_KM,
        )
    except ImportError:
        return convenient_route

    segs = list(convenient_route["segments"])
    total_cost = sum(s.get("fare", 0) for s in segs)
    total_dist = sum(s.get("distance", 0) for s in segs)
    injected_first = False
    injected_last = False

    # --- First-mile: origin near terminal, terminal within 0.5–2 km of first transit stop ---
    # Spatial awareness: use terminal only if it's on the way (not a big detour).
    term_res = nearest_terminal(origin_lat, origin_lon, trike_terminals, max_km=TRIKE_CATCHMENT_KM)
    first_stop = _first_transit_stop(segs)
    if term_res is not None and first_stop is not None:
        terminal, walk_km_to_terminal = term_res
        stop_lat = first_stop.get("lat") if isinstance(first_stop.get("lat"), (int, float)) else None
        stop_lon = first_stop.get("lon") if isinstance(first_stop.get("lon"), (int, float)) else None
        if stop_lat is not None and stop_lon is not None:
            trike_km = _haversine_km(terminal["lat"], terminal["lon"], stop_lat, stop_lon)
            direct_origin_to_stop = _haversine_km(origin_lat, origin_lon, stop_lat, stop_lon)
            via_terminal_dist = walk_km_to_terminal + trike_km
            # Only use terminal if origin→terminal→first_stop is not a big detour
            # and walking to terminal is at least TRIKE_MIN_SAVING_KM shorter than walking direct to stop
            walk_saving_km = direct_origin_to_stop - walk_km_to_terminal if direct_origin_to_stop > 0 else 0
            if (
                TRIKE_MIN_DISTANCE_KM <= trike_km <= TRIKE_MAX_DISTANCE_KM
                and direct_origin_to_stop > 0
                and via_terminal_dist <= direct_origin_to_stop * FIRST_MILE_DETOUR_MAX_RATIO
                and walk_km_to_terminal < direct_origin_to_stop
                and walk_saving_km >= TRIKE_MIN_SAVING_KM
            ):
                # Remove existing "walk to first stop" segments; the injected
                # walk→terminal + trike→first_stop replaces them.
                segs, removed_cost, removed_dist = _strip_leading_walk_to_first_transit(segs)
                total_cost -= removed_cost
                total_dist -= removed_dist

                # Walk origin → terminal
                walk_poly = _call_mapbox_walking_polyline(origin_lat, origin_lon, terminal["lat"], terminal["lon"])
                if not walk_poly:
                    walk_poly = _call_google_walking_polyline(origin_lat, origin_lon, terminal["lat"], terminal["lon"])
                if not walk_poly:
                    walk_poly = [[origin_lon, origin_lat], [terminal["lon"], terminal["lat"]]]
                walk_seg = {
                    "mode": "Walking",
                    "route_id": None,
                    "name": None,
                    "instruction": f"Walk to {terminal.get('name', 'Tricycle terminal')}",
                    "from_stop": {"name": "Origin", "lat": origin_lat, "lon": origin_lon, "id": "ORIGIN"},
                    "to_stop": {"name": terminal.get("name", "Tricycle terminal"), "lat": terminal["lat"], "lon": terminal["lon"], "id": terminal.get("id", "")},
                    "distance": walk_km_to_terminal,
                    "fare": 0.0,
                    "polyline": walk_poly,
                }
                # Tricycle terminal → first transit stop
                trike_seg = build_trike_segment(
                    {"id": terminal.get("id", ""), "name": terminal.get("name", "Tricycle terminal"), "lat": terminal["lat"], "lon": terminal["lon"]},
                    {"id": first_stop.get("id", ""), "name": first_stop.get("name", "Transit stop"), "lat": stop_lat, "lon": stop_lon},
                )
                trike_seg["instruction"] = f"Take Tricycle ({terminal.get('name', 'Tricycle')}) to {first_stop.get('name', 'transit stop')}"
                trike_seg["name"] = terminal.get("name", "Tricycle")
                trike_seg["route_id"] = trike_seg.get("route_id", "TRICYCLE")
                segs = [walk_seg, trike_seg] + segs
                total_cost += walk_seg.get("fare", 0) + trike_seg.get("fare", 0)
                total_dist += walk_seg.get("distance", 0) + trike_seg.get("distance", 0)
                injected_first = True
                logger.info("Injected first-mile tricycle: %s -> %s", terminal.get("name"), first_stop.get("name"))

    # --- Last-mile: inject tricycle BETWEEN last transit stop and destination.
    # Correct flow: get off at last stop → WALK to tricycle terminal → RIDE trike to destination.
    # Only inject tricycle if there's a terminal walkable from the last stop AND terminal→dest is in trike range.
    # If no terminal, do NOT inject tricycle (let normal walk-to-destination remain).
    if not injected_first:
        last_stop = _last_transit_stop(segs)
        if last_stop is not None:
            stop_lat = last_stop.get("lat") if isinstance(last_stop.get("lat"), (int, float)) else None
            stop_lon = last_stop.get("lon") if isinstance(last_stop.get("lon"), (int, float)) else None
            if stop_lat is not None and stop_lon is not None:
                # Check if there's a terminal walkable from the last stop
                term_res_from_stop = nearest_terminal(stop_lat, stop_lon, trike_terminals, max_km=TRIKE_CATCHMENT_KM)
                if term_res_from_stop is not None:
                    terminal, walk_km_stop_to_terminal = term_res_from_stop
                    trike_km_terminal_to_dest = _haversine_km(terminal["lat"], terminal["lon"], dest_lat, dest_lon)
                    direct_walk_km = _haversine_km(stop_lat, stop_lon, dest_lat, dest_lon)
                    # Deny if walk to terminal >= direct walk; allow only if direct walk is ≥200 m longer
                    walk_saving_km = direct_walk_km - walk_km_stop_to_terminal if direct_walk_km > 0 else 0
                    # Only inject tricycle if terminal→dest is within trike range (0.5–2 km)
                    # and walking to terminal is at least 200 m shorter than walking straight to destination
                    if (
                        TRIKE_MIN_DISTANCE_KM <= trike_km_terminal_to_dest <= TRIKE_MAX_DISTANCE_KM
                        and walk_km_stop_to_terminal < direct_walk_km
                        and walk_saving_km >= TRIKE_MIN_SAVING_KM
                    ):
                        # Remove trailing walk-to-destination so we can inject walk-to-terminal + trike-to-dest
                        segs, removed_cost, removed_dist = _strip_trailing_walk_to_destination(segs, dest_lat, dest_lon)
                        total_cost -= removed_cost
                        total_dist -= removed_dist

                        # Last-mile via terminal: last_stop → WALK to terminal → TRIKE to destination
                        walk_poly = _call_mapbox_walking_polyline(stop_lat, stop_lon, terminal["lat"], terminal["lon"])
                        if not walk_poly:
                            walk_poly = _call_google_walking_polyline(stop_lat, stop_lon, terminal["lat"], terminal["lon"])
                        if not walk_poly:
                            walk_poly = [[stop_lon, stop_lat], [terminal["lon"], terminal["lat"]]]
                        walk_seg = {
                            "mode": "Walking",
                            "route_id": None,
                            "name": None,
                            "instruction": f"Walk to {terminal.get('name', 'Tricycle terminal')}",
                            "from_stop": {"name": last_stop.get("name", "Transit stop"), "lat": stop_lat, "lon": stop_lon, "id": last_stop.get("id", "")},
                            "to_stop": {"name": terminal.get("name", "Tricycle terminal"), "lat": terminal["lat"], "lon": terminal["lon"], "id": terminal.get("id", "")},
                            "distance": walk_km_stop_to_terminal,
                            "fare": 0.0,
                            "polyline": walk_poly,
                        }
                        trike_seg = build_trike_segment(
                            {"id": terminal.get("id", ""), "name": terminal.get("name", "Tricycle terminal"), "lat": terminal["lat"], "lon": terminal["lon"]},
                            {"id": "DESTINATION", "name": "Destination", "lat": dest_lat, "lon": dest_lon},
                        )
                        trike_seg["instruction"] = f"Take Tricycle ({terminal.get('name', 'Tricycle')}) to your destination"
                        trike_seg["name"] = terminal.get("name", "Tricycle")
                        trike_seg["route_id"] = trike_seg.get("route_id", "TRICYCLE")
                        trike_seg["reason"] = "last_mile"
                        segs = segs + [walk_seg, trike_seg]
                        total_cost += walk_seg.get("fare", 0) + trike_seg.get("fare", 0)
                        total_dist += walk_seg.get("distance", 0) + trike_seg.get("distance", 0)
                        logger.info("Injected last-mile tricycle: walk %s -> %s, then trike to destination", last_stop.get("name"), terminal.get("name"))
                        injected_last = True

    if not injected_first and not injected_last:
        return convenient_route

    return {
        "segments": segs,
        "total_distance": total_dist,
        "total_cost": total_cost,
        "summary": {
            "total_distance": total_dist,
            "total_cost": total_cost,
            "fare_breakdown": _fare_breakdown(segs),
        },
        "stops": _extract_stops(segs),
    }


def _all_three_identical(synthesized: Dict[str, Dict]) -> bool:
    """
    True only if fastest, cheapest, and convenient are the same route (super identical).
    Routes with different modes (e.g. Jeep vs Bus) or different stops are not identical;
    only when segment count, mode per segment, and from_stop names all match do we perturb.
    """
    f = synthesized.get("fastest", {})
    c = synthesized.get("cheapest", {})
    v = synthesized.get("convenient", {})
    if not f.get("segments") or not c.get("segments") or not v.get("segments"):
        return False
    return _same_route(f, c) and _same_route(c, v)


def find_routes_google_hybrid(
    start_lat: float, start_lon: float,
    end_lat: float, end_lon: float,
    fare_type: str = "regular",
    preferences: List[str] = None,
    bus_jeep_substitute_fn=None,
    stops: Optional[List[Dict]] = None,
    fare_tables: Optional[Dict[str, Any]] = None,
    trike_terminals: Optional[List[Dict]] = None,
    modes: Optional[List[str]] = None,
) -> Dict[str, Any]:
    """
    Main entry: fetch Google routes, synthesize three, return MaiWay format.
    If stops is provided and Google returns only walking routes, a "walk to nearest
    transit stop then transit" route is tried and added when available.
    When all three routes are super identical (same modes and stops), we perturb O/D by 500 m,
    fetch more options, re-anchor them to real O/D, and re-synthesize for variety.
    Tricycle is injected on the convenient route only when modes includes "tricycle"
    (travel preference) and trike_terminals is provided.
    """
    if preferences is None:
        preferences = ["fastest", "cheapest", "convenient"]
    if modes is None:
        modes = []

    global FARE_TABLES
    if fare_tables is not None:
        FARE_TABLES = fare_tables

    google_routes = fetch_google_routes(
        start_lat, start_lon, end_lat, end_lon,
        fare_type,
        stops=stops,
    )
    synthesized = synthesize_three_routes(google_routes, bus_jeep_substitute_fn, allowed_modes=modes)

    # If all three are the same route, try perturbed O/D to get different options
    if _all_three_identical(synthesized) and google_routes:
        radius_m = float(os.getenv("PERTURB_RADIUS_M", PERTURB_RADIUS_M))
        if radius_m > 0:
            extra = []
            # Perturbed origin, same destination
            o_lat, o_lon = _random_offset_m(start_lat, start_lon, radius_m)
            routes_perturb_o = fetch_google_routes(o_lat, o_lon, end_lat, end_lon, fare_type, stops=stops)
            for r in routes_perturb_o:
                reanchored = _re_anchor_route(r, start_lat, start_lon, end_lat, end_lon)
                if not _route_signature_match(extra, reanchored.get("segments", [])):
                    extra.append(reanchored)
            # Same origin, perturbed destination
            d_lat, d_lon = _random_offset_m(end_lat, end_lon, radius_m)
            routes_perturb_d = fetch_google_routes(start_lat, start_lon, d_lat, d_lon, fare_type, stops=stops)
            for r in routes_perturb_d:
                reanchored = _re_anchor_route(r, start_lat, start_lon, end_lat, end_lon)
                if not _route_signature_match(extra, reanchored.get("segments", [])):
                    extra.append(reanchored)
            # Merge with existing (avoid duplicates by signature)
            for r in extra:
                if not _route_signature_match(google_routes, r.get("segments", [])):
                    google_routes.append(r)
            if len(google_routes) > 1:
                synthesized = synthesize_three_routes(google_routes, bus_jeep_substitute_fn, allowed_modes=modes)
                logger.info("Perturb+re-anchor added variety: %s unique routes", len(google_routes))

    # Tricycle injection for convenient route only when user has tricycle in travel preferences
    convenient = synthesized.get("convenient")
    if (
        trike_terminals
        and modes
        and "tricycle" in [str(m).lower() for m in modes]
        and "convenient" in preferences
        and isinstance(convenient, dict)
        and convenient.get("segments")
    ):
        synthesized["convenient"] = _inject_tricycle_convenient(
            convenient,
            start_lat, start_lon,
            end_lat, end_lon,
            trike_terminals,
        )

    out = {}
    for pref in preferences:
        out[pref] = synthesized.get(pref, {})

    return out
