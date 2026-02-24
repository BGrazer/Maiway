import os
import sys
import asyncio
from urllib.parse import quote
from flask import Flask, request, jsonify
from flask_cors import CORS
from asgiref.wsgi import WsgiToAsgi
import requests

# Import your custom logic
import rfr
import chatbot as chatbot_module
from crowd_analysis import analyze_route_with_reference_model

app = Flask(__name__)
CORS(app)

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
    print(f"Starting server on port {port}", flush=True)
    print("Menu", flush=True)
    app.run(host='0.0.0.0', port=port, debug=False)
