import numpy as np
import pandas as pd
from sklearn.ensemble import RandomForestRegressor
from flask import Flask, request, jsonify
from flask_cors import CORS

# Init Flask
app = Flask(__name__)
CORS(app)

# Load and clean Jeep fare data
df_jeep = pd.read_csv("jeep_fare.csv")
df_jeep.columns = df_jeep.columns.str.strip()

# Train Jeep model (Regular Fare only)
model_jeep = RandomForestRegressor(n_estimators=100, random_state=42)
X_jeep = df_jeep[['Distance (km)']].values
y_jeep = df_jeep['Regular Fare (₱)'].values
model_jeep.fit(X_jeep, y_jeep)

# Calculate anomaly threshold
def calculate_threshold(model, X, y):
    predictions = model.predict(X)
    errors = abs(y - predictions)
    return np.mean(errors) + 3 * np.std(errors)

threshold_jeep = calculate_threshold(model_jeep, X_jeep, y_jeep)

# Fare anomaly check for Jeep
def check_fare_anomaly(distance_km, charged_fare):
    predicted_fare = model_jeep.predict([[distance_km]])[0]
    difference = abs(charged_fare - predicted_fare)
    is_anomalous = difference > threshold_jeep

    return {
        'vehicle_type': 'Jeep',
        'predicted_fare': str(round(predicted_fare)),
        'charged_fare': str(round(charged_fare)),
        'difference': str(round(difference)),
        'threshold': str(round(threshold_jeep)),
        'is_anomalous': bool(is_anomalous),
    }

@app.route('/predict_fare', methods=['POST'])
def predict_fare():
    data = request.json
    distance_km = float(data['distance_km'])
    charged_fare = float(data['charged_fare'])

    result = check_fare_anomaly(distance_km, charged_fare)
    return jsonify(result)

# Run server
if __name__ == '__main__':
    app.run(host='0.0.0.0', port=49945, debug=True)
 