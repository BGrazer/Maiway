import os
import json
import numpy as np
import pandas as pd
from flask import Flask, request, jsonify, send_from_directory
from flask_cors import CORS
from sklearn.ensemble import RandomForestRegressor
from chatbot_model import ChatbotModel
import socket

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
y_jeep_regular = np.array(df_jeep['Regular Fare (₱)'].values)
y_jeep_discounted = np.array(df_jeep['Discounted Fare (₱)'].values)
models['Jeep']['Regular'].fit(X_jeep, y_jeep_regular)
models['Jeep']['Discounted'].fit(X_jeep, y_jeep_discounted)

# Train Bus model
X_bus = df_bus[['Distance (km)']].values
y_bus_regular = np.array(df_bus['Regular Fare (₱)'].values)
y_bus_discounted = np.array(df_bus['Discounted Fare (₱)'].values)
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
        'predicted_fare': round(predicted_fare, 2),
        'charged_fare': round(charged_fare, 2),
        'difference': round(difference, 2),
        'threshold': round(threshold, 2),
        'is_anomalous': bool(is_anomalous),
    }

# ----------------------------------
# API ROUTES: FARE
# ----------------------------------
@app.route('/predict_fare', methods=['POST'])
def predict_fare():
    if request.json is None:
        return jsonify({"error": "Request body must be JSON"}), 400

    data = request.json
    vehicle_type = data.get('vehicle_type')
    distance_km = float(data.get('distance_km', 0))
    charged_fare = float(data.get('charged_fare', 0))
    discounted = bool(data.get('discounted', False))  # Defaults to False if not provided

    if not vehicle_type or not distance_km or not charged_fare:
        return jsonify({"error": "Missing required fields"}), 400

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
# Server Entry Point
# ----------------------------------
if __name__ == '__main__':
    print(f"\n🚀 MAIWAY backend running at: http://{local_ip}:5000\n")
    app.run(host='0.0.0.0', port=5000, debug=True)
