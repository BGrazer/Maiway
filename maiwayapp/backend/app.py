import os
import json
import numpy as np
import pandas as pd
from flask import Flask, request, jsonify, send_from_directory
from flask_cors import CORS
from sklearn.ensemble import RandomForestRegressor
from chatbot_model import ChatbotModel
import socket
from typing import Dict, Any, Optional, List
from maiwayrouting.core_route_service import UnifiedRouteService
from maiwayrouting.config import config
from maiwayrouting.logger import logger
from maiwayrouting.core_shape_generator import CoreShapeGenerator

# ----------------------------------
# Auto-get local IP for printing
# ----------------------------------
hostname = socket.gethostname()
local_ip = socket.gethostbyname(hostname)

# ----------------------------------
# Initialize Flask App
# ----------------------------------
app = Flask(__name__, static_folder='../frontend', static_url_path='/')
CORS(app)

# ----------------------------------
# Initialize Chatbot
# ----------------------------------
chatbot = ChatbotModel()

# ----------------------------------
# Initialize MaiWay Routing Engine
# ----------------------------------
route_service: Optional[UnifiedRouteService] = None
unified_shape_generator = CoreShapeGenerator()


def initialize_route_service():
    """Spin-up GTFS + graph builder once at startup"""
    global route_service, unified_shape_generator
    try:
        config.validate()
        route_service = UnifiedRouteService(config.data_dir)
        unified_shape_generator.set_stops_cache(route_service.stops)
        logger.info("Unified route service initialized successfully")
    except Exception as e:
        logger.error(f"Failed to initialize unified route service: {e}")
        raise


# Call immediately so routes are ready when the server comes up
initialize_route_service()

# ----------------------------------
# Load Fare Matrices and Train Models
# ----------------------------------
df_jeep = pd.read_csv("jeep_fare.csv")
df_bus = pd.read_csv("bus_fare.csv")

models = {
    'Jeep': {
        'Regular': RandomForestRegressor(n_estimators=100, random_state=42),
        'Discounted': RandomForestRegressor(n_estimators=100, random_state=42),
    },
    'Bus': {
        'Regular': RandomForestRegressor(n_estimators=100, random_state=42),
        'Discounted': RandomForestRegressor(n_estimators=100, random_state=42),
    }
}

# Train Jeep model
X_jeep = df_jeep[['Distance (km)']].values
y_jeep_regular = df_jeep['Regular Fare (₱)'].values
y_jeep_discounted = df_jeep['Discounted Fare (₱)'].values
models['Jeep']['Regular'].fit(X_jeep, y_jeep_regular)
models['Jeep']['Discounted'].fit(X_jeep, y_jeep_discounted)

# Train Bus model
X_bus = df_bus[['Distance (km)']].values
y_bus_regular = df_bus['Regular Fare (₱)'].values
y_bus_discounted = df_bus['Discounted Fare (₱)'].values
models['Bus']['Regular'].fit(X_bus, y_bus_regular)
models['Bus']['Discounted'].fit(X_bus, y_bus_discounted)

# ----------------------------------
# Threshold Calculation
# ----------------------------------
def calculate_threshold(model, X, y):
    predictions = model.predict(X)
    errors = abs(y - predictions)
    return np.mean(errors) + 3 * np.std(errors)

thresholds = {
    'Jeep': {
        'Regular': calculate_threshold(models['Jeep']['Regular'], X_jeep, y_jeep_regular),
        'Discounted': calculate_threshold(models['Jeep']['Discounted'], X_jeep, y_jeep_discounted),
    },
    'Bus': {
        'Regular': calculate_threshold(models['Bus']['Regular'], X_bus, y_bus_regular),
        'Discounted': calculate_threshold(models['Bus']['Discounted'], X_bus, y_bus_discounted),
    }
}

# ----------------------------------
# Fare Anomaly Checker
# ----------------------------------
def check_fare_anomaly(vehicle_type, distance_km, charged_fare, discounted):
    fare_type = 'Discounted' if discounted else 'Regular'
    model = models[vehicle_type][fare_type]
    threshold = thresholds[vehicle_type][fare_type]

    predicted_fare = model.predict([[distance_km]])[0]
    difference = abs(charged_fare - predicted_fare)
    is_anomalous = difference > threshold

    return {
        'vehicle_type': vehicle_type,
        'fare_type': fare_type,
        'predicted_fare': str(round(predicted_fare)),
        'charged_fare': str(round(charged_fare)),
        'difference': str(round(difference)),
        'threshold': str(round(threshold)),
        'is_anomalous': bool(is_anomalous),
    }

# ----------------------------------
# Helper utilities (routing)
# ----------------------------------

def validate_coordinates(lat: float, lon: float) -> bool:
    """Validate latitude/longitude bounds"""
    return -90 <= lat <= 90 and -180 <= lon <= 180


def clean_nan_values(obj):
    """Recursively replace NaN/Inf with None so JSON serialises"""
    import math
    if isinstance(obj, dict):
        return {k: clean_nan_values(v) for k, v in obj.items()}
    elif isinstance(obj, list):
        return [clean_nan_values(v) for v in obj]
    elif isinstance(obj, float) and math.isnan(obj):
        return None
    elif isinstance(obj, (int, float)) and math.isinf(obj):
        return None
    return obj

# ----------------------------------
# ROUTING API ENDPOINTS  (copied from original MaiWay app)
# ----------------------------------

@app.route('/health', methods=['GET'])
def health_check():
    """Simple liveness probe"""
    if route_service is None:
        return jsonify({'status': 'error', 'message': 'Route service not initialised'}), 500
    return jsonify({'status': 'healthy', 'message': 'MaiWay engine ready'})


@app.route('/route', methods=['POST'])
def single_preference_route():
    """Legacy /route endpoint – returns first preference only"""
    data = request.get_json() or {}
    start = data.get('start', {})
    end = data.get('end', {})
    preferences = data.get('preferences', ['fastest'])
    modes = data.get('modes', ['jeepney', 'bus', 'lrt', 'walking'])
    passenger_type = data.get('passenger_type', 'regular')

    # Validate
    try:
        slat, slon = float(start.get('lat', 0)), float(start.get('lon', 0))
        elat, elon = float(end.get('lat', 0)), float(end.get('lon', 0))
    except Exception:
        return jsonify({'error': 'Invalid coordinate format'}), 400
    if not (validate_coordinates(slat, slon) and validate_coordinates(elat, elon)):
        return jsonify({'error': 'Coordinates out of bounds'}), 400

    result = route_service.find_all_routes_with_coordinates(
        slat, slon, elat, elon,
        fare_type=passenger_type,
        preferences=preferences,
        allowed_modes=modes,
    )
    if result is None or (isinstance(result, dict) and result.get('error')):
        key = data.get('mode', preferences[0])
        return jsonify({key: [], 'summary': {}, 'stops': []})

    response = format_multicriteria_response(result, preferences)
    key = data.get('mode', preferences[0])
    return jsonify({key: response.get(key, []), 'summary': response.get('summary', {}), 'stops': response.get('stops', [])})


@app.route('/search-stops', methods=['GET'])
def search_stops():
    query = (request.args.get('q') or '').strip().lower()
    if not query:
        return jsonify({'suggestions': []})
    suggestions = []
    for stop_id, stop in route_service.stops.items():
        name = stop.get('name', '').lower()
        if query in name:
            suggestions.append({'id': stop_id, 'name': stop.get('name'), 'lat': stop.get('lat'), 'lon': stop.get('lon')})
            if len(suggestions) >= 10:
                break
    return jsonify({'suggestions': suggestions})


@app.route('/routes-multicriteria', methods=['POST'])
def routes_multicriteria():
    data = request.get_json() or {}
    start = data.get('start', {})
    end = data.get('end', {})
    preferences = data.get('preferences', ['fastest', 'cheapest', 'convenient'])
    modes = data.get('modes', ['jeepney', 'bus', 'lrt', 'walking'])
    passenger_type = data.get('passenger_type', 'regular')

    try:
        slat, slon = float(start.get('lat', 0)), float(start.get('lon', 0))
        elat, elon = float(end.get('lat', 0)), float(end.get('lon', 0))
    except Exception:
        return jsonify({'error': 'Invalid coordinate format'}), 400
    if not (validate_coordinates(slat, slon) and validate_coordinates(elat, elon)):
        return jsonify({'error': 'Coordinates out of bounds'}), 400

    result = route_service.find_all_routes_with_coordinates(
        slat, slon, elat, elon,
        fare_type=passenger_type,
        preferences=preferences,
        allowed_modes=modes,
    )
    response = format_multicriteria_response(result, preferences)
    return jsonify(clean_nan_values(response))

# -------- Instruction & formatting helpers --------

def generate_instruction(segment: Dict[str, Any]) -> str:
    mode = segment.get('mode', 'Walking')
    from_stop = segment.get('from_stop', 'Unknown')
    to_stop = segment.get('to_stop', 'Unknown')
    if isinstance(from_stop, dict):
        from_stop_name = from_stop.get('name', from_stop.get('id', 'Unknown'))
    else:
        from_stop_name = str(from_stop)
    if isinstance(to_stop, dict):
        to_stop_name = to_stop.get('name', to_stop.get('id', 'Unknown'))
    else:
        to_stop_name = str(to_stop)
    if mode.lower() == 'walking':
        if segment.get('reason') == 'first_mile':
            return f"Walk from origin to {to_stop_name}"
        elif segment.get('reason') == 'last_mile':
            return f"Walk from {from_stop_name} to destination"
        return f"Walk from {from_stop_name} to {to_stop_name}"
    return f"Take {mode} from {from_stop_name} to {to_stop_name}"


def calculate_fare_breakdown(segments: List[Dict[str, Any]]) -> Dict[str, float]:
    breakdown: Dict[str, float] = {}
    for seg in segments:
        mode = seg.get('mode', 'Walking')
        breakdown[mode] = breakdown.get(mode, 0.0) + seg.get('fare', 0.0)
    return breakdown


def format_multicriteria_response(result, preferences):
    mode_map = {'Jeep': 'jeepney', 'Bus': 'bus', 'LRT': 'lrt', 'Walking': 'walking', 'Tricycle': 'tricycle'}
    out = {p: [] for p in preferences}
    all_stops, summary = set(), {'total_cost': 0.0, 'total_distance': 0.0, 'estimated_time': 0, 'fare_breakdown': {}}
    for pref in preferences:
        route = result.get(pref) if isinstance(result, dict) else None
        if not route:
            continue
        segments = []
        est_time = route.get('estimated_time', 0)
        if est_time and (summary['estimated_time'] == 0 or est_time < summary['estimated_time']):
            summary['estimated_time'] = est_time
        for seg in route.get('segments', []):
            mode = mode_map.get(seg.get('mode', ''), seg.get('mode', '')).lower()
            instr = seg.get('instruction') or generate_instruction(seg)
            seg_obj = {
                'mode': mode,
                'instruction': instr,
                'distance': seg.get('distance', 0.0),
                'fare': seg.get('fare', 0.0),
                'from_stop': seg.get('from_stop'),
                'to_stop': seg.get('to_stop'),
            }
            if seg.get('polyline'):
                seg_obj['polyline'] = seg['polyline']
            segments.append(seg_obj)
            summary['fare_breakdown'][mode] = summary['fare_breakdown'].get(mode, 0.0) + seg.get('fare', 0.0)
            summary['total_cost'] += seg.get('fare', 0.0)
            summary['total_distance'] += seg.get('distance', 0.0)
            # Track stops for map display
            for stop_key in ('from_stop', 'to_stop'):
                st = seg.get(stop_key)
                if isinstance(st, dict):
                    all_stops.add((st.get('name'), st.get('lat'), st.get('lon')))
        out[pref] = segments
    out['summary'] = summary
    out['stops'] = [{'name': n, 'lat': lat, 'lon': lon} for (n, lat, lon) in all_stops]
    return out

# ----------------------------------
# API ROUTES: FARE
# ----------------------------------
@app.route('/predict_fare', methods=['POST'])
def predict_fare():
    data = request.json
    vehicle_type = data['vehicle_type']
    distance_km = float(data['distance_km'])
    charged_fare = float(data['charged_fare'])
    discounted = bool(data['discounted'])

    result = check_fare_anomaly(vehicle_type, distance_km, charged_fare, discounted)
    return jsonify(result)

# ----------------------------------
# API ROUTES: CHATBOT
# ----------------------------------
@app.route('/chat', methods=['POST'])
def chat():
    if request.json is None:
        return jsonify({"error": "Request body must be JSON"}), 400

    user_message = request.json.get('message')
    if not user_message:
        return jsonify({"error": "No 'message' key provided in JSON body or message is empty"}), 400

    response = chatbot.get_response(user_message)
    return jsonify({"response": response})

@app.route('/dynamic_suggestions', methods=['GET'])
def get_dynamic_suggestions():
    try:
        query = request.args.get('query', '')
        if not query:
            return jsonify({"suggestions": []})
        suggestions = chatbot.get_matching_questions(query)
        return jsonify({"suggestions": suggestions})
    except Exception as e:
        return jsonify({"error": f"An unexpected server error occurred: {e}"}), 500

@app.route('/admin/add_faq', methods=['POST'])
def add_faq():
    if request.json is None:
        return jsonify({"error": "Request body must be JSON for FAQ addition"}), 400

    data = request.json
    question = data.get('question')
    answer = data.get('answer')

    if not question or not answer:
        return jsonify({"error": "Both 'question' and 'answer' are required."}), 400

    success = chatbot.add_faq(question, answer)
    if success:
        return jsonify({"message": "FAQ added and chatbot knowledge base updated."}), 200
    else:
        return jsonify({"message": "FAQ (or similar question) already exists."}), 200

@app.route('/admin/reload_chatbot', methods=['POST'])
def reload_chatbot():
    chatbot.reload_data()
    return jsonify({"message": "Chatbot data reloaded successfully."})

@app.route('/data/faq_data.json')
def serve_faq_data():
    return send_from_directory(os.path.join(app.root_path, 'data'), 'faq_data.json')

# ----------------------------------
# Update 404 / 500 handlers for whole app
# ----------------------------------

@app.errorhandler(404)
def _not_found(e):
    return jsonify({'error': 'Endpoint not found'}), 404


@app.errorhandler(500)
def _server_error(e):
    return jsonify({'error': 'Internal server error'}), 500

# ----------------------------------
# Server Entry Point
# ----------------------------------
if __name__ == '__main__':
    print(f"\n🚀 MAIWAY backend running at: http://{local_ip}:5000\n")
    app.run(host='0.0.0.0', port=5000, debug=False)
