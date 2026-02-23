import numpy as np
import pandas as pd
from flask import Flask, request, jsonify
from flask_cors import CORS
from sklearn.ensemble import RandomForestRegressor
import socket

# Load Fare Data
df_jeep = pd.read_csv("jeep_fare.csv")
df_bus = pd.read_csv("bus_fare.csv")

# Train Models
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

# Jeep training
X_jeep = df_jeep[['Distance (km)']].values
y_jeep_regular = df_jeep['Regular Fare (₱)'].to_numpy()
y_jeep_discounted = df_jeep['Discounted Fare (₱)'].to_numpy()
models['Jeep']['Regular'].fit(X_jeep, y_jeep_regular)
models['Jeep']['Discounted'].fit(X_jeep, y_jeep_discounted)

# Bus training
X_bus = df_bus[['Distance (km)']].values
y_bus_regular = df_bus['Regular Fare (₱)'].to_numpy()
y_bus_discounted = df_bus['Discounted Fare (₱)'].to_numpy()
models['Bus']['Regular'].fit(X_bus, y_bus_regular)
models['Bus']['Discounted'].fit(X_bus, y_bus_discounted)

# Threshold Calculation
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

def custom_round(value):
    integer_part = int(value)
    decimal_part = value - integer_part
    return float(integer_part + 1) if decimal_part >= 0.5 else float(integer_part)

# --- THE MAIN LOGIC FUNCTION ---
def check_fare_anomaly(vehicle_type, distance_km, charged_fare, discounted):
    fare_type = 'Discounted' if discounted else 'Regular'
    model = models[vehicle_type][fare_type]
    threshold = thresholds[vehicle_type][fare_type]

    predicted_fare_raw = model.predict([[distance_km]])[0]
    predicted_fare = custom_round(predicted_fare_raw)
    charged_fare = custom_round(charged_fare)
    difference = custom_round(abs(charged_fare - predicted_fare))
    is_anomalous = abs(charged_fare - predicted_fare_raw) > threshold

    return {
        'vehicle_type': vehicle_type,
        'fare_type': fare_type,
        'predicted_fare': predicted_fare,
        'charged_fare': charged_fare,
        'difference': difference,
        'threshold': round(threshold, 2),
        'is_anomalous': bool(is_anomalous),
    }

# This prevents the script from starting a second server when main.py imports it
if __name__ == '__main__':
    app = Flask(__name__)
    CORS(app)
    @app.route('/predict_fare', methods=['POST'])
    def predict_fare():
        data = request.json
        if not data:
            return jsonify({"error": "No data provided"}), 400
        result = check_fare_anomaly(data.get('vehicle_type'), float(data.get('distance_km')), float(data.get('charged_fare')), bool(data.get('discounted')))
        return jsonify(result)
    app.run(host='0.0.0.0', port=5002)