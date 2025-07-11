import numpy as np
import pandas as pd
from sklearn.ensemble import RandomForestRegressor
from flask import Flask, request, jsonify
from flask_cors import CORS

# Init Flask
app = Flask(__name__)
CORS(app)

# -------------------------------
# Load Fare Matrices
# -------------------------------
df_jeep = pd.read_csv("jeep_fare.csv")
df_lrt1 = pd.read_csv("lrt1_fare.csv")

models = {
    'Jeep': {
        'Regular': RandomForestRegressor(n_estimators=100, random_state=42),
        'Discounted': RandomForestRegressor(n_estimators=100, random_state=42),
    },
    'LRT 1': {
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

# Train LRT 1 model
X_lrt1 = df_lrt1[['Distance_km']].values
y_lrt1 = df_lrt1['Fare_PHP'].values
models['LRT 1']['Regular'].fit(X_lrt1, y_lrt1)
models['LRT 1']['Discounted'].fit(X_lrt1, y_lrt1)

# Calculate thresholds
def calculate_threshold(model, X, y):
    predictions = model.predict(X)
    errors = abs(y - predictions)
    return np.mean(errors) + 3 * np.std(errors)

thresholds = {
    'Jeep': {
        'Regular': calculate_threshold(models['Jeep']['Regular'], X_jeep, y_jeep_regular),
        'Discounted': calculate_threshold(models['Jeep']['Discounted'], X_jeep, y_jeep_discounted),
    },
    'LRT 1': {
        'Regular': calculate_threshold(models['LRT 1']['Regular'], X_lrt1, y_lrt1),
        'Discounted': calculate_threshold(models['LRT 1']['Discounted'], X_lrt1, y_lrt1),
    }
}

# Core logic
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

# API endpoint
@app.route('/predict_fare', methods=['POST'])
def predict_fare():
    data = request.json
    vehicle_type = data['vehicle_type']
    distance_km = float(data['distance_km'])
    charged_fare = float(data['charged_fare'])
    discounted = bool(data['discounted'])

    result = check_fare_anomaly(vehicle_type, distance_km, charged_fare, discounted)
    return jsonify(result)

# Run server
if __name__ == '__main__':
    app.run(host='0.0.0.0', port=49945, debug=True)
