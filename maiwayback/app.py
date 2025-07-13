import numpy as np
import pandas as pd
from sklearn.ensemble import RandomForestRegressor
from flask import Flask, request, jsonify
from flask_cors import CORS

# Init Flask
app = Flask(__name__)
CORS(app)

# --- Load and clean Jeep fare data ---
df_jeep = pd.read_csv("jeep_fare.csv")
df_jeep.columns = df_jeep.columns.str.strip()

# --- Train Jeep models ---
X_jeep = df_jeep[['Distance (km)']].values
y_jeep_regular = df_jeep['Regular Fare (₱)'].values
y_jeep_discounted = df_jeep['Discounted Fare (₱)'].values

model_jeep_regular = RandomForestRegressor(n_estimators=100, random_state=42)
model_jeep_discounted = RandomForestRegressor(n_estimators=100, random_state=42)
model_jeep_regular.fit(X_jeep, y_jeep_regular)
model_jeep_discounted.fit(X_jeep, y_jeep_discounted)

# --- Load and clean Bus fare data ---
df_bus = pd.read_csv("bus_fare.csv")
df_bus.columns = df_bus.columns.str.strip()

# --- Train Bus models ---
X_bus = df_bus[['Distance (km)']].values
y_bus_regular = df_bus['Regular Fare (₱)'].values
y_bus_discounted = df_bus['Discounted Fare (₱)'].values

model_bus_regular = RandomForestRegressor(n_estimators=100, random_state=42)
model_bus_discounted = RandomForestRegressor(n_estimators=100, random_state=42)
model_bus_regular.fit(X_bus, y_bus_regular)
model_bus_discounted.fit(X_bus, y_bus_discounted)

# --- Function to calculate anomaly threshold ---
def calculate_threshold(model, X, y):
    predictions = model.predict(X)
    errors = abs(y - predictions)
    return np.mean(errors) + 3 * np.std(errors)

thresholds = {
    'jeep_regular': calculate_threshold(model_jeep_regular, X_jeep, y_jeep_regular),
    'jeep_discounted': calculate_threshold(model_jeep_discounted, X_jeep, y_jeep_discounted),
    'bus_regular': calculate_threshold(model_bus_regular, X_bus, y_bus_regular),
    'bus_discounted': calculate_threshold(model_bus_discounted, X_bus, y_bus_discounted),
}

# --- General fare anomaly checker ---
def check_fare_anomaly(vehicle_type, passenger_type, distance_km, charged_fare):
    vehicle_type = vehicle_type.lower()
    passenger_type = passenger_type.lower()

    key = f"{vehicle_type}_{passenger_type}"

    model_map = {
        'jeep_regular': model_jeep_regular,
        'jeep_discounted': model_jeep_discounted,
        'bus_regular': model_bus_regular,
        'bus_discounted': model_bus_discounted
    }

    if key not in model_map:
        return {'error': f"Invalid combination: vehicle_type={vehicle_type}, passenger_type={passenger_type}"}

    model = model_map[key]
    threshold = thresholds[key]

    predicted_fare = model.predict([[distance_km]])[0]
    difference = abs(charged_fare - predicted_fare)
    is_anomalous = difference > threshold

    return {
        'vehicle_type': vehicle_type.capitalize(),
        'passenger_type': passenger_type.capitalize(),
        'predicted_fare': str(round(predicted_fare)),
        'charged_fare': str(round(charged_fare)),
        'difference': str(round(difference)),
        'threshold': str(round(threshold)),
        'is_anomalous': bool(is_anomalous),
    }

# --- API Endpoint ---
@app.route('/predict_fare', methods=['POST'])
def predict_fare():
    data = request.json
    vehicle_type = data['vehicle_type']         # 'Jeep' or 'Bus'
    passenger_type = data['passenger_type']     # 'Regular' or 'Discounted'
    distance_km = float(data['distance_km'])
    charged_fare = float(data['charged_fare'])

    result = check_fare_anomaly(vehicle_type, passenger_type, distance_km, charged_fare)
    return jsonify(result)

# Run server
if __name__ == '__main__':
    app.run(host='0.0.0.0', port=49945, debug=True)
