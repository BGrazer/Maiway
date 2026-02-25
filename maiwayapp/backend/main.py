import os
import sys
import asyncio
from urllib.parse import quote
from flask import Flask, request, jsonify
from flask_cors import CORS
from asgiref.wsgi import WsgiToAsgi
import requests

# Add routing directory to path
routing_path = os.path.join(os.path.dirname(__file__), 'routing')
if os.path.exists(routing_path):
    sys.path.insert(0, routing_path)

# Import your custom logic
import rfr
import chatbot as chatbot_module
from crowd_analysis import analyze_route_with_reference_model

# Import routing components
try:
    from maiwayrouting.core_route_service import UnifiedRouteService  # type: ignore
    from maiwayrouting.config import config  # type: ignore
    from maiwayrouting.loaders.fares import load_fares  # type: ignore
    from maiwayrouting.google_adapter import find_routes_google_hybrid  # type: ignore
    from maiwayrouting.bus_jeep_overlap import create_bus_jeep_substitute_fn  # type: ignore
    ROUTING_AVAILABLE = True
except Exception as e:
    print(f"Warning: Routing not available: {e}", flush=True)
    ROUTING_AVAILABLE = False

app = Flask(__name__)
CORS(app)

# Initialize routing service
route_service = None
fare_tables = {}

if ROUTING_AVAILABLE:
    try:
        config.validate()
        route_service = UnifiedRouteService(config.data_dir)
        fare_tables = load_fares(config.data_dir)
        print("Routing service initialized", flush=True)
    except Exception as e:
        print(f"Routing init failed: {e}", flush=True)

# Initialize chatbot
print("Starting MAIWAY Unified Backend...", flush=True)
chatbot = chatbot_module.init_chatbot()
print("Chatbot initialized successfully!", flush=True)

@app.route('/')
def health():
    print("Health check called", flush=True)
    return {"status": "MAIWAY System Online", "version": "1.0.0"}

# --- CHATBOT ROUTES ---
@app.route('/chat', methods=['POST'])
async def chat():
    print("Chat endpoint called", flush=True)
    data = request.json
    if not data or 'message' not in data:
        print("ERROR: No message in request", flush=True)
        return jsonify({"error": "No message"}), 400
    print(f"Received message: {data['message']}", flush=True)
    response = await chatbot.get_response(data['message'])  # type: ignore
    print(f"Sending response: {response}", flush=True)
    return jsonify({"response": response})

@app.route('/dynamic_suggestions', methods=['GET'])
def suggestions():
    query = request.args.get('query', '')
    if not query: return jsonify({"suggestions": []})
    results = chatbot.get_matching_questions(query)  # type: ignore
    return jsonify({"suggestions": results})

# --- FARE (RFR) ROUTES ---
@app.route('/predict_fare', methods=['POST'])
def predict_fare():
    print("Predict fare endpoint called", flush=True)
    data = request.json
    if not data:
        return jsonify({"error": "No data provided"}), 400
    try:
        result = rfr.check_fare_anomaly(
            data.get('vehicle_type'),
            float(data.get('distance_km', 0)),
            float(data.get('charged_fare', 0)),
            bool(data.get('discounted', False))
        )
        return jsonify(result)
    except Exception as e:
        print(f"ERROR in predict_fare: {e}", flush=True)
        return jsonify({"error": str(e)}), 400

# --- CROWD ANALYSIS ROUTE ---
@app.route('/run_analysis', methods=['GET'])
def run_analysis():
    analyze_route_with_reference_model()
    return jsonify({"message": "Crowd analysis triggered and logged."})

# --- ROUTING ENDPOINT ---
@app.route('/route', methods=['POST', 'OPTIONS'])
def route():
    if request.method == 'OPTIONS':
        return '', 200
    try:
        data = request.json
        if not data:
            return jsonify({'error': 'No data provided'}), 400
        
        if not ROUTING_AVAILABLE or not route_service:
            return jsonify({'error': 'Routing not available'}), 503
        
        start_coords = data.get('start', {})
        end_coords = data.get('end', {})
        preferences = data.get('preferences', ['fastest'])
        modes = data.get('modes', ['jeepney', 'bus', 'lrt', 'walking'])
        passenger_type = data.get('passenger_type', 'regular')
        
        if not start_coords or not end_coords:
            return jsonify({'error': 'Start and end coordinates required'}), 400
        
        start_lat = float(start_coords.get('lat', 0))
        start_lon = float(start_coords.get('lon', 0))
        end_lat = float(end_coords.get('lat', 0))
        end_lon = float(end_coords.get('lon', 0))
        
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
            response = format_route_response(result, preferences)
            key = data.get('mode', preferences[0])
            selected_segments = response.get(key, []) or []
            return jsonify({
                key: selected_segments,
                'summary': response.get('summary', {}),
                'stops': response.get('stops', []),
            })
        
        key = data.get('mode', preferences[0])
        return jsonify({
            key: [],
            'summary': {'fare_breakdown': {}, 'total_cost': 0.0, 'total_distance': 0.0},
            'stops': [],
        }), 200
    except Exception as e:
        print(f"Route error: {e}", flush=True)
        import traceback
        traceback.print_exc()
        return jsonify({'error': str(e)}), 500

def format_route_response(result, preferences):
    mode_map = {'Jeep': 'jeepney', 'Bus': 'bus', 'LRT': 'lrt', 'Walking': 'walking', 'Tricycle': 'tricycle'}
    out = {p: [] for p in preferences}
    all_stops = set()
    summary = {'total_cost': 0.0, 'total_distance': 0.0, 'fare_breakdown': {}}
    
    for pref in preferences:
        route = result.get(pref)
        if not isinstance(route, dict) or not route.get('segments'):
            continue
        segments = []
        for seg in route['segments']:
            mode = mode_map.get((seg.get('mode', '') or '').capitalize(), (seg.get('mode', '') or '').lower())
            from_stop = seg.get('from_stop', {})
            to_stop = seg.get('to_stop', {})
            
            from_name = from_stop.get('name', 'Origin') if isinstance(from_stop, dict) else str(from_stop)
            to_name = to_stop.get('name', 'Destination') if isinstance(to_stop, dict) else str(to_stop)
            from_lat = from_stop.get('lat', 0) if isinstance(from_stop, dict) else 0
            from_lon = from_stop.get('lon', 0) if isinstance(from_stop, dict) else 0
            to_lat = to_stop.get('lat', 0) if isinstance(to_stop, dict) else 0
            to_lon = to_stop.get('lon', 0) if isinstance(to_stop, dict) else 0
            
            segment_obj = {
                'mode': mode,
                'instruction': seg.get('instruction', f'Take {mode}'),
                'name': seg.get('name', mode.capitalize()),
                'distance': seg.get('distance', 0.0),
                'fare': seg.get('fare', 0.0),
                'from_stop': {'name': from_name, 'lat': from_lat, 'lon': from_lon},
                'to_stop': {'name': to_name, 'lat': to_lat, 'lon': to_lon},
                'detailed_instructions': seg.get('detailed_instructions', [])
            }
            if seg.get('polyline'):
                segment_obj['polyline'] = seg['polyline']
            segments.append(segment_obj)
            
            if mode not in summary['fare_breakdown']:
                summary['fare_breakdown'][mode] = 0.0
            summary['fare_breakdown'][mode] += seg.get('fare', 0.0)
            summary['total_cost'] += seg.get('fare', 0.0)
            summary['total_distance'] += seg.get('distance', 0.0)
        out[pref] = segments
    
    out['summary'] = summary  # type: ignore
    out['stops'] = []  # type: ignore
    return out

# --- PLACES API ROUTES ---
MANILA_BOUNDS = {
    'low': {'latitude': 14.557, 'longitude': 120.9371},
    'high': {'latitude': 14.639, 'longitude': 121.026},
}

def _google_api_key():
    return os.environ.get('GOOGLE_MAPS_API_KEY') or os.environ.get('GOOGLE_API_KEY') or ''

def _place_lat_lng(place_id: str, key: str):
    place_id = (place_id or '').strip().replace('places/', '')
    if not place_id:
        return None
    try:
        url = 'https://places.googleapis.com/v1/places/' + quote(place_id)
        r = requests.get(url, headers={'X-Goog-Api-Key': key, 'X-Goog-FieldMask': 'location'}, timeout=5)
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
    return (14.557 <= lat <= 14.639 and 120.9371 <= lng <= 121.026)

@app.route('/places/autocomplete', methods=['GET'])
def places_autocomplete():
    key = _google_api_key()
    if not key:
        return jsonify({'predictions': []}), 200
    query = (request.args.get('q') or request.args.get('input') or '').strip()
    if not query:
        return jsonify({'predictions': []}), 200
    url = 'https://places.googleapis.com/v1/places:autocomplete'
    headers = {'Content-Type': 'application/json', 'X-Goog-Api-Key': key}
    body = {'input': query, 'locationRestriction': {'rectangle': MANILA_BOUNDS}, 'includedRegionCodes': ['ph']}
    try:
        r = requests.post(url, json=body, headers=headers, timeout=8)
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
            coords = _place_lat_lng(place_id, key)
            if coords is None:
                continue
            lat, lng = coords
            if not _is_inside_manila(lat, lng):
                continue
            out.append({'description': description, 'place_id': place_id})
        return jsonify({'predictions': out})
    except Exception:
        return jsonify({'predictions': []}), 200

@app.route('/places/details', methods=['GET'])
def places_details():
    key = _google_api_key()
    if not key:
        return jsonify({'error': 'No API key'}), 400
    place_id = (request.args.get('place_id') or '').strip().replace('places/', '')
    if not place_id:
        return jsonify({'error': 'Missing place_id'}), 400
    url = f'https://places.googleapis.com/v1/places/{quote(place_id)}'
    headers = {'X-Goog-Api-Key': key, 'X-Goog-FieldMask': 'location,formattedAddress'}
    try:
        r = requests.get(url, headers=headers, timeout=8)
        data = r.json() if r.ok else {}
        loc = data.get('location') or {}
        lat = loc.get('latitude')
        lng = loc.get('longitude')
        if lat is None or lng is None:
            return jsonify({'error': 'No geometry'}), 404
        return jsonify({'lat': float(lat), 'lng': float(lng), 'formatted_address': data.get('formattedAddress') or ''})
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@app.route('/places/reverse', methods=['GET'])
def places_reverse():
    try:
        lat = float(request.args.get('lat', 0))
        lng = float(request.args.get('lng', 0))
    except (TypeError, ValueError):
        return jsonify({'address': 'Current location'}), 200
    if not (-90 <= lat <= 90 and -180 <= lng <= 180):
        return jsonify({'address': 'Current location'}), 200
    key = _google_api_key()
    if key:
        try:
            url = f'https://maps.googleapis.com/maps/api/geocode/json?latlng={lat},{lng}&key={key}'
            r = requests.get(url, timeout=5)
            data = r.json() if r.ok else {}
            results = data.get('results') or []
            if results:
                address = (results[0].get('formatted_address') or '').strip()
                if address:
                    return jsonify({'address': address}), 200
        except Exception:
            pass
    return jsonify({'address': 'Current location'}), 200

if __name__ == "__main__":
    port = int(os.environ.get("PORT", 10000))
    print(f"Starting unified server on port {port}", flush=True)
    print("Services: Chatbot ✓ | RFR ✓ | Routing ✓ | Places API ✓", flush=True)
    print("Menu", flush=True)
    app.run(host='0.0.0.0', port=port, debug=False)
