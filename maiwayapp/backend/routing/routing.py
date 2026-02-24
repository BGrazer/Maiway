#!/usr/bin/env python3
"""
MaiWay Routing Engine - Flask Web API
Multi-criteria routing system for commuter app
"""

# Load .env from backend/routing or parent backend/ so GOOGLE_MAPS_API_KEY is available
import os as _os
_env_dir = _os.path.dirname(_os.path.abspath(__file__))
for _path in [_env_dir, _os.path.join(_env_dir, "..")]:
    _env_file = _os.path.join(_path, ".env")
    if _os.path.isfile(_env_file):
        try:
            with open(_env_file, "r", encoding="utf-8") as _f:
                for _line in _f:
                    _line = _line.strip()
                    if _line and not _line.startswith("#") and "=" in _line:
                        _k, _, _v = _line.partition("=")
                        _k, _v = _k.strip(), _v.strip().strip('"').strip("'")
                        if _k and _k not in _os.environ:
                            _os.environ[_k] = _v
        except Exception:
            pass
        break

from flask import Flask, request, jsonify
import logging
logging.basicConfig(level=logging.DEBUG)
print(">>> routing.py started!", flush=True)
from flask_cors import CORS
import json
import time
import math
import sys
import requests as _requests
from typing import Dict, Any, Optional, List
from maiwayrouting.core_route_service import UnifiedRouteService
from maiwayrouting.config import config
from maiwayrouting.logger import logger
from maiwayrouting.exceptions import MaiWayError, RouteNotFoundError, InvalidCoordinatesError
from maiwayrouting.loaders.fares import load_fares

# Global route service (stops + trike terminals) and fare tables
route_service: Optional[UnifiedRouteService] = None
fare_tables = {}

def create_app():
    """
    Factory function to create and configure the Flask app.
    This ensures route service initialization happens within app context.
    """
    global route_service
    global fare_tables
    
    app = Flask(__name__)
    CORS(app)  # Enable CORS for all routes
    
    # Initialize route service
    try:
        config.validate()
        route_service = UnifiedRouteService(config.data_dir)
        fare_tables = load_fares(config.data_dir)
        logger.info("Route service (Google Hybrid) initialized successfully")
    except Exception as e:
        logger.error(f"Failed to initialize route service: {e}")
        raise

    def validate_coordinates(lat: float, lon: float) -> bool:
        """Validate coordinate bounds"""
        return -90 <= lat <= 90 and -180 <= lon <= 180

    def clean_nan_values(obj):
        """Recursively clean NaN values from objects to make them JSON serializable"""
        if isinstance(obj, dict):
            return {k: clean_nan_values(v) for k, v in obj.items()}
        elif isinstance(obj, list):
            return [clean_nan_values(item) for item in obj]
        elif isinstance(obj, float) and math.isnan(obj):
            return None
        elif isinstance(obj, (int, float)) and math.isinf(obj):
            return None
        else:
            return obj

    @app.route('/health', methods=['GET'])
    def health_check():
        """Health check endpoint"""
        try:
            if route_service is None:
                return jsonify({'status': 'error', 'message': 'Route service not initialized'}), 500
            
            return jsonify({
                'status': 'healthy',
                'message': 'MaiWay Routing Engine is running',
                'timestamp': time.time()
            })
        except Exception as e:
            logger.error(f"Health check failed: {e}")
            return jsonify({'status': 'error', 'message': str(e)}), 500

    @app.route('/', methods=['GET'])
    def index():
        """Root endpoint"""
        return jsonify({
            'name': 'MaiWay Routing Engine',
            'version': '1.0.0',
            'description': 'Multi-criteria routing system for commuter app',
            'endpoints': {
                'health': '/health',
                'route': '/route',
                'route_google': '/route-google',
                'routes_multicriteria': '/routes-multicriteria',
                'search_stops': '/search-stops'
            }
        })


    @app.route('/route', methods=['POST'])
    def route():
        """Route endpoint (legacy, now uses multicriteria engine and returns 'fastest' route)"""
        try:
            data = request.get_json()
            print("[DEBUG] Incoming request data:", data)
            if not data:
                return jsonify({'error': 'No data provided'}), 400
            start_coords = data.get('start', {})
            end_coords = data.get('end', {})
            preferences = data.get('preferences', ['fastest'])
            modes = data.get('modes', ['jeepney', 'bus', 'lrt', 'walking'])
            passenger_type = data.get('passenger_type', 'regular')
            debug = data.get('debug', False)
            if not start_coords or not end_coords:
                return jsonify({'error': 'Start and end coordinates required'}), 400
            start_lat = float(start_coords.get('lat', 0))
            start_lon = float(start_coords.get('lon', 0))
            end_lat = float(end_coords.get('lat', 0))
            end_lon = float(end_coords.get('lon', 0))
            if not validate_coordinates(start_lat, start_lon) or not validate_coordinates(end_lat, end_lon):
                return jsonify({'error': 'Invalid coordinates'}), 400

            # Google Hybrid only (no local routing engine)
            try:
                from maiwayrouting.google_adapter import find_routes_google_hybrid
                from maiwayrouting.bus_jeep_overlap import create_bus_jeep_substitute_fn
                bus_jeep_fn = create_bus_jeep_substitute_fn(passenger_type)
                stops_raw = getattr(route_service, "stops", None) or []
                stops = list(stops_raw.values()) if isinstance(stops_raw, dict) else (stops_raw or [])
                trike_terminals = getattr(route_service, "trike_terminals", None) or []
                result = find_routes_google_hybrid(
                    start_lat, start_lon, end_lat, end_lon,
                    fare_type=passenger_type,
                    preferences=preferences,
                    bus_jeep_substitute_fn=bus_jeep_fn,
                    stops=stops,
                    fare_tables=fare_tables,
                    trike_terminals=trike_terminals,
                    modes=modes,
                )
                if any(isinstance(result.get(p), dict) and (result.get(p) or {}).get('segments') for p in preferences):
                    response = format_multicriteria_response(result, preferences)
                    response = clean_nan_values(response)
                    key = data.get('mode', preferences[0])
                    selected_segments = response.get(key, []) or []
                    out = {
                        key: selected_segments,
                        "summary": {
                            "total_cost": sum(seg.get("fare", 0.0) for seg in selected_segments),
                            "total_distance": sum(seg.get("distance", 0.0) for seg in selected_segments),
                            "fare_breakdown": calculate_fare_breakdown(selected_segments),
                        },
                        "stops": response.get("stops", []),
                    }
                    return jsonify(out)
                # Google returned no routes
                key = data.get('mode', preferences[0])
                return jsonify({
                    key: [],
                    "summary": {"fare_breakdown": {}, "total_cost": 0.0, "total_distance": 0.0},
                    "stops": [],
                }), 200
            except Exception as e:
                logger.error(f"Google hybrid error: {e}")
                return jsonify({
                    'error': str(e),
                    (data.get('mode') or preferences[0]): [],
                    "summary": {"fare_breakdown": {}, "total_cost": 0.0, "total_distance": 0.0},
                    "stops": [],
                }), 200

        except Exception as e:
            logger.error(f"/route error: {e}")
            # Return a 500 with a clear error message
            return jsonify({'error': str(e)}), 500


    @app.route('/route-google', methods=['POST'])
    def route_google():
        """Route endpoint using Google Directions API (transit) + MaiWay inference layer.
        Always returns three route types: fastest, cheapest, convenient.
        Requires GOOGLE_MAPS_API_KEY or GOOGLE_API_KEY environment variable."""
        try:
            data = request.get_json()
            if not data:
                return jsonify({'error': 'No data provided'}), 400
            start_coords = data.get('start', {})
            end_coords = data.get('end', {})
            preferences = data.get('preferences', ['fastest', 'cheapest', 'convenient'])
            passenger_type = data.get('passenger_type', 'regular')
            if not start_coords or not end_coords:
                return jsonify({'error': 'Start and end coordinates required'}), 400
            start_lat = float(start_coords.get('lat', 0))
            start_lon = float(start_coords.get('lon', 0))
            end_lat = float(end_coords.get('lat', 0))
            end_lon = float(end_coords.get('lon', 0))
            if not validate_coordinates(start_lat, start_lon) or not validate_coordinates(end_lat, end_lon):
                return jsonify({'error': 'Invalid coordinates'}), 400

            from maiwayrouting.google_adapter import find_routes_google_hybrid
            from maiwayrouting.bus_jeep_overlap import create_bus_jeep_substitute_fn

            bus_jeep_fn = create_bus_jeep_substitute_fn(passenger_type)
            stops_raw = getattr(route_service, "stops", None) or []
            stops = list(stops_raw.values()) if isinstance(stops_raw, dict) else (stops_raw or [])
            trike_terminals = getattr(route_service, "trike_terminals", None) or []
            modes = data.get('modes', ['jeepney', 'bus', 'lrt', 'walking'])
            result = find_routes_google_hybrid(
                start_lat, start_lon, end_lat, end_lon,
                fare_type=passenger_type,
                preferences=preferences,
                bus_jeep_substitute_fn=bus_jeep_fn,
                stops=stops,
                fare_tables=fare_tables,
                trike_terminals=trike_terminals,
                modes=modes,
            )
            if not any(isinstance(result.get(p), dict) and (result.get(p) or {}).get('segments') for p in preferences):
                return jsonify({
                    'error': 'No transit routes found. Google may not have transit data for this area.',
                    'fastest': [], 'cheapest': [], 'convenient': [],
                    'summary': {'total_cost': 0, 'total_distance': 0, 'fare_breakdown': {}},
                    'stops': [],
                }), 200
            response = format_multicriteria_response(result, preferences)
            response = clean_nan_values(response)
            return jsonify(response)
        except Exception as e:
            logger.error(f"/route-google error: {e}")
            return jsonify({'error': str(e)}), 500


    @app.route('/search-stops', methods=['GET'])
    def search_stops():
        """Search for stops by name"""
        try:
            if route_service is None:
                return jsonify({'error': 'Route service not initialized'}), 500

            query = request.args.get('q', '').strip()
            if not query:
                return jsonify({'suggestions': []})

            # Get stops: route_service.stops is dict {stop_id: {name, lat, lon, ...}}
            stops = route_service.stops

            # Filter stops by name (case-insensitive)
            suggestions = []
            query_lower = query.lower()
            for stop_id, stop_info in stops.items():
                stop_name = (stop_info.get('name') or '').lower()
                if query_lower in stop_name:
                    suggestions.append({
                        'id': stop_id,
                        'name': stop_info.get('name'),
                        'lat': stop_info.get('lat'),
                        'lon': stop_info.get('lon')
                    })
                    if len(suggestions) >= 10:  # Limit results
                        break

            return jsonify({'suggestions': suggestions})

        except Exception as e:
            logger.error(f"Error in search stops: {e}")
            return jsonify({'error': 'Internal server error'}), 500

    @app.route('/routes-multicriteria', methods=['POST'])
    def routes_multicriteria():
        """Return fastest, convenient, and cheapest routes between coordinates, with real fares and summary."""
        try:
            data = request.get_json()
            if not data:
                return jsonify({'error': 'No data provided'}), 400
            start_coords = data.get('start', {})
            end_coords = data.get('end', {})
            preferences = data.get('preferences', ['fastest', 'cheapest', 'convenient'])
            modes = data.get('modes', ['jeepney', 'bus', 'lrt', 'walking'])
            passenger_type = data.get('passenger_type', 'regular')
            if not start_coords or not end_coords:
                return jsonify({'error': 'Start and end coordinates required'}), 400
            start_lat = float(start_coords.get('lat', 0))
            start_lon = float(start_coords.get('lon', 0))
            end_lat = float(end_coords.get('lat', 0))
            end_lon = float(end_coords.get('lon', 0))
            if not validate_coordinates(start_lat, start_lon) or not validate_coordinates(end_lat, end_lon):
                return jsonify({'error': 'Invalid coordinates'}), 400

            # Google Hybrid only (no local routing engine)
            try:
                from maiwayrouting.google_adapter import find_routes_google_hybrid
                from maiwayrouting.bus_jeep_overlap import create_bus_jeep_substitute_fn
                bus_jeep_fn = create_bus_jeep_substitute_fn(passenger_type)
                stops_raw = getattr(route_service, "stops", None) or []
                stops = list(stops_raw.values()) if isinstance(stops_raw, dict) else (stops_raw or [])
                trike_terminals = getattr(route_service, "trike_terminals", None) or []
                result = find_routes_google_hybrid(
                    start_lat, start_lon, end_lat, end_lon,
                    fare_type=passenger_type,
                    preferences=preferences,
                    bus_jeep_substitute_fn=bus_jeep_fn,
                    stops=stops,
                    fare_tables=fare_tables,
                    trike_terminals=trike_terminals,
                    modes=modes,
                )
                if any(isinstance(result.get(p), dict) and (result.get(p) or {}).get('segments') for p in preferences):
                    response = format_multicriteria_response(result, preferences)
                    response = clean_nan_values(response)
                    return jsonify(response)
                empty = {p: [] for p in preferences}
                empty['summary'] = {'total_cost': 0, 'total_distance': 0, 'fare_breakdown': {}}
                empty['stops'] = []
                return jsonify(empty)
            except Exception as e:
                logger.error(f"Google hybrid error: {e}")
                err_out = {p: [] for p in preferences}
                err_out['error'] = str(e)
                err_out['summary'] = {'total_cost': 0, 'total_distance': 0, 'fare_breakdown': {}}
                err_out['stops'] = []
                return jsonify(err_out), 200
        except Exception as e:
            logger.error(f"/routes-multicriteria error: {e}")
            return jsonify({'error': str(e)}), 500


    @app.errorhandler(404)
    def not_found(error):
        return jsonify({'error': 'Endpoint not found'}), 404

    @app.errorhandler(500)
    def internal_error(error):
        return jsonify({'error': 'Internal server error'}), 500

    def generate_instruction(segment: Dict[str, Any]) -> str:
        """Generate instruction text for a route segment (robust to string/dict)"""
        mode = segment.get('mode', 'Walking')
        from_stop = segment.get('from_stop', 'Unknown')
        to_stop = segment.get('to_stop', 'Unknown')
        # Handle case where from_stop/to_stop might be strings or dictionaries
        if isinstance(from_stop, dict):
            from_stop_name = from_stop.get('name', from_stop.get('id', 'Unknown'))
        else:
            from_stop_name = str(from_stop)
        if isinstance(to_stop, dict):
            to_stop_name = to_stop.get('name', to_stop.get('id', 'Unknown'))
        else:
            to_stop_name = str(to_stop)
        if mode == 'Walking':
            if segment.get('reason') == 'first_mile':
                return f"Walk from origin to {to_stop_name}"
            elif segment.get('reason') == 'last_mile':
                return f"Walk from {from_stop_name} to destination"
            else:
                return f"Walk from {from_stop_name} to {to_stop_name}"
        else:
            return f"Take {mode} from {from_stop_name} to {to_stop_name}"

    def calculate_fare_breakdown(segments: List[Dict[str, Any]]) -> Dict[str, float]:
        """Calculate fare breakdown by mode"""
        breakdown = {}
        for segment in segments:
            mode = segment.get('mode', 'Walking')
            fare = segment.get('fare', 0.0)
            if mode not in breakdown:
                breakdown[mode] = 0.0
            breakdown[mode] += fare
        return breakdown

    def format_multicriteria_response(result, preferences):
        # Normalize mode names for frontend
        mode_map = {
            'Jeep': 'jeepney',
            'Bus': 'bus',
            'LRT': 'lrt',
            'Walking': 'walking',
            'Tricycle': 'tricycle',
            'walk': 'walking',
            'jeep': 'jeepney',
            'bus': 'bus',
            'lrt': 'lrt',
            'tricycle': 'tricycle',
        }
        out = {p: [] for p in preferences}
        all_stops = set()
        summary = {
            'total_cost': 0.0,
            'total_distance': 0.0,
            'fare_breakdown': {}
        }
        for pref in preferences:
            route = result.get(pref)
            if not isinstance(route, dict) or not route.get('segments'):
                out[pref] = []
                continue
            segments = []
            for seg in route['segments']:
                mode = mode_map.get(seg.get('mode', '').lower().capitalize(), seg.get('mode', '').lower())
                from_stop = seg.get('from_stop', {})
                to_stop = seg.get('to_stop', {})

                # Robustly extract stop names and coordinates whether stop is a dict or plain string token (e.g. "ORIGIN")
                def _stop_info(stop_val, fallback_prefix):
                    if isinstance(stop_val, dict):
                        name = stop_val.get('name', stop_val.get('id', fallback_prefix))
                        lat = stop_val.get('lat', seg.get(f'{fallback_prefix}_lat', 0.0))
                        lon = stop_val.get('lon', seg.get(f'{fallback_prefix}_lon', 0.0))
                    else:
                        # Plain string such as 'ORIGIN' or 'DESTINATION'
                        name = str(stop_val)
                        lat = seg.get(f'{fallback_prefix}_lat', 0.0)
                        lon = seg.get(f'{fallback_prefix}_lon', 0.0)
                    return name, lat, lon

                from_name, from_lat, from_lon = _stop_info(from_stop, 'from')
                to_name, to_lat, to_lon = _stop_info(to_stop, 'to')
                # Compose instruction and details
                instruction = seg.get('instruction') or generate_instruction(seg)
                detailed_instructions = seg.get('detailed_instructions', [instruction])
                name = seg.get('name') or seg.get('route_id') or mode.capitalize()
                segment_obj = {
                    'mode': mode,
                    'instruction': instruction,
                    'name': name,
                    'distance': seg.get('distance', 0.0),
                    'fare': seg.get('fare', 0.0),
                    'from_stop': {
                        'name': from_name,
                        'lat': from_lat,
                        'lon': from_lon
                    },
                    'to_stop': {
                        'name': to_name,
                        'lat': to_lat,
                        'lon': to_lon
                    },
                    'detailed_instructions': detailed_instructions
                }
                # Attach polyline directly to segment if available
                if seg.get('polyline'):
                    segment_obj['polyline'] = seg['polyline']
                segments.append(segment_obj)
                all_stops.add((segment_obj['from_stop']['name'], segment_obj['from_stop']['lat'], segment_obj['from_stop']['lon']))
                all_stops.add((segment_obj['to_stop']['name'], segment_obj['to_stop']['lat'], segment_obj['to_stop']['lon']))
                # Fare breakdown
                if mode not in summary['fare_breakdown']:
                    summary['fare_breakdown'][mode] = 0.0
                summary['fare_breakdown'][mode] += seg.get('fare', 0.0)
                summary['total_cost'] += seg.get('fare', 0.0)
                summary['total_distance'] += seg.get('distance', 0.0)
            out[pref] = segments
        out['summary'] = summary
        out['stops'] = [
            {'name': name, 'lat': lat, 'lon': lon}
            for (name, lat, lon) in all_stops
        ]
        return out


    # ---------------------------------------------------------------------------
    # Google Places Autocomplete & Details (for search suggestions)
    # Requires GOOGLE_MAPS_API_KEY or GOOGLE_API_KEY in .env (backend or backend/routing)
    # Enable "Places API" and "Places API (New)" or "Places API" in Google Cloud.
    # ---------------------------------------------------------------------------
    def _google_api_key():
        return _os.environ.get('GOOGLE_MAPS_API_KEY') or _os.environ.get('GOOGLE_API_KEY') or ''

    # Bounding box of the City of Manila red border (from lib/city_boundary.dart getManilaBoundary).
    # Min/max lat/lon of that polygon so autocomplete only returns places inside the map boundary.
    MANILA_BOUNDS = {
        'low': {'latitude': 14.557, 'longitude': 120.9371},
        'high': {'latitude': 14.639, 'longitude': 121.026},
    }

    MANILA_LAT_MIN = MANILA_BOUNDS['low']['latitude']
    MANILA_LAT_MAX = MANILA_BOUNDS['high']['latitude']
    MANILA_LON_MIN = MANILA_BOUNDS['low']['longitude']
    MANILA_LON_MAX = MANILA_BOUNDS['high']['longitude']

    def _place_lat_lng(place_id: str, key: str) -> Optional[tuple]:
        """Fetch place lat/lng from Google Places API (New). Returns (lat, lng) or None."""
        place_id = (place_id or '').strip().replace('places/', '')
        if not place_id:
            return None
        try:
            url = 'https://places.googleapis.com/v1/places/' + _requests.utils.quote(place_id)
            r = _requests.get(url, headers={
                'X-Goog-Api-Key': key,
                'X-Goog-FieldMask': 'location',
            }, timeout=5)
            if not r.ok:
                return None
            data = r.json()
            loc = data.get('location') or {}
            lat, lng = loc.get('latitude'), loc.get('longitude')
            if lat is None or lng is None:
                return None
            return (float(lat), float(lng))
        except Exception:
            return None

    def _is_inside_manila(lat: float, lng: float) -> bool:
        """Hard block: True only if (lat, lng) is inside the Manila red-border bbox."""
        return (MANILA_LAT_MIN <= lat <= MANILA_LAT_MAX and
                MANILA_LON_MIN <= lng <= MANILA_LON_MAX)


    @app.route('/places/autocomplete', methods=['GET'])
    def places_autocomplete():
        """Google Places API (New) Autocomplete. Hard block: only return suggestions inside Manila (red border)."""
        key = _google_api_key()
        if not key:
            logger.warning('Places autocomplete: no GOOGLE_MAPS_API_KEY in env')
            return jsonify({'predictions': []}), 200
        query = (request.args.get('q') or request.args.get('input') or '').strip()
        if not query:
            return jsonify({'predictions': []}), 200
        url = 'https://places.googleapis.com/v1/places:autocomplete'
        headers = {
            'Content-Type': 'application/json',
            'X-Goog-Api-Key': key,
        }
        body = {
            'input': query,
            'locationRestriction': {
                'rectangle': MANILA_BOUNDS,
            },
            'includedRegionCodes': ['ph'],
        }
        try:
            r = _requests.post(url, json=body, headers=headers, timeout=8)
            data = r.json() if r.ok else {}
            suggestions = data.get('suggestions') or []
            out = []
            for s in suggestions:
                pp = s.get('placePrediction') or {}
                place_id = (pp.get('placeId') or pp.get('place', '').replace('places/', '')) or ''
                text_obj = pp.get('text') or {}
                description = (text_obj.get('text') or '').strip()
                if not place_id or not description:
                    continue
                # Hard block: only include suggestions whose coordinates are inside Manila
                coords = _place_lat_lng(place_id, key)
                if coords is None:
                    continue
                lat, lng = coords
                if not _is_inside_manila(lat, lng):
                    continue
                out.append({'description': description, 'place_id': place_id})
            if out:
                logger.info('Places autocomplete (New): q=%r -> %d results (Manila only)', query, len(out))
            return jsonify({'predictions': out})
        except Exception as e:
            logger.warning('Places autocomplete error: %s', e)
            return jsonify({'predictions': []}), 200


    @app.route('/places/details', methods=['GET'])
    def places_details():
        """Google Places API (New) Place Details for lat/lng and address. Query param: place_id."""
        key = _google_api_key()
        if not key:
            return jsonify({'error': 'No API key'}), 400
        place_id = (request.args.get('place_id') or '').strip().replace('places/', '')
        if not place_id:
            return jsonify({'error': 'Missing place_id'}), 400
        url = f'https://places.googleapis.com/v1/places/{_requests.utils.quote(place_id)}'
        headers = {
            'X-Goog-Api-Key': key,
            'X-Goog-FieldMask': 'location,formattedAddress',
        }
        try:
            r = _requests.get(url, headers=headers, timeout=8)
            data = r.json() if r.ok else {}
            loc = data.get('location') or {}
            lat = loc.get('latitude')
            lng = loc.get('longitude')
            if lat is None or lng is None:
                return jsonify({'error': 'No geometry'}), 404
            return jsonify({
                'lat': float(lat),
                'lng': float(lng),
                'formatted_address': data.get('formattedAddress') or '',
            })
        except Exception as e:
            logger.warning('Places details error: %s', e)
            return jsonify({'error': str(e)}), 500

    def _reverse_geocode_nominatim(lat: float, lng: float) -> Optional[str]:
        """Fallback reverse geocode using OpenStreetMap Nominatim (no API key required)."""
        try:
            url = (
                'https://nominatim.openstreetmap.org/reverse'
                '?lat=' + str(lat) + '&lon=' + str(lng) + '&format=json'
            )
            r = _requests.get(
                url,
                timeout=5,
                headers={'User-Agent': 'MaiWayRouteApp/1.0 (https://github.com/maiway)'},
            )
            if not r.ok:
                return None
            data = r.json()
            return (data.get('display_name') or '').strip() or None
        except Exception as e:
            logger.warning('Nominatim reverse geocode error: %s', e)
            return None

    def _reverse_geocode_mapbox(lat: float, lng: float) -> Optional[str]:
        """Fallback reverse geocode using Mapbox Geocoding API (MAPBOX_TOKEN in .env)."""
        token = (_os.environ.get('MAPBOX_TOKEN') or '').strip()
        if not token:
            return None
        try:
            # Mapbox expects longitude,latitude
            url = (
                'https://api.mapbox.com/geocoding/v5/mapbox.places/'
                + str(lng) + ',' + str(lat) + '.json?access_token=' + token
            )
            r = _requests.get(url, timeout=5)
            if not r.ok:
                return None
            data = r.json()
            features = data.get('features') or []
            if features:
                return (features[0].get('place_name') or '').strip() or None
            return None
        except Exception as e:
            logger.warning('Mapbox reverse geocode error: %s', e)
            return None

    @app.route('/places/reverse', methods=['GET'])
    def places_reverse():
        """Reverse geocode lat,lng to address using Google Geocoding API, with Nominatim fallback."""
        try:
            lat = float(request.args.get('lat', 0))
            lng = float(request.args.get('lng', 0))
        except (TypeError, ValueError):
            return jsonify({'address': 'Current location'}), 200
        if not (-90 <= lat <= 90 and -180 <= lng <= 180):
            return jsonify({'address': 'Current location'}), 200

        address = None
        key = _google_api_key()
        if key:
            try:
                url = (
                    'https://maps.googleapis.com/maps/api/geocode/json'
                    '?latlng=' + str(lat) + ',' + str(lng) + '&key=' + key
                )
                r = _requests.get(url, timeout=5)
                data = r.json() if r.ok else {}
                results = data.get('results') or []
                if results:
                    address = (results[0].get('formatted_address') or '').strip() or None
            except Exception as e:
                logger.warning('Places reverse (Google) error: %s', e)

        if not address:
            address = _reverse_geocode_nominatim(lat, lng)
        if not address:
            address = _reverse_geocode_mapbox(lat, lng)

        return jsonify({'address': address or 'Current location'}), 200

    return app

app = create_app()


if __name__ == '__main__':
    import socket
    local_ip = socket.gethostbyname(socket.gethostname())
    print(f"\n🟦 Routing backend running at: http://{local_ip}:5000\n")
    app.run(host='0.0.0.0', port=5000) 