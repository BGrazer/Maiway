import numpy as np
import pandas as pd
from sklearn.ensemble import RandomForestRegressor
from collections import defaultdict

# 🔄 1. Load fare matrix from CSV (replace with your file path)
fare_matrix = pd.read_csv("jeep_fare.csv")  # Make sure this has 'Distance (km)' and 'Regular Fare (₱)' columns

# 🧠 2. Train Random Forest model
X = fare_matrix[["Distance (km)"]].values
y = fare_matrix["Regular Fare (₱)"].values
model = RandomForestRegressor(n_estimators=100, random_state=42)
model.fit(X, y)

# ⚠️ 3. Calculate anomaly threshold
predicted = model.predict(X)
errors = abs(predicted - y)
threshold = np.mean(errors) + 3 * np.std(errors)

# 🧪 4. Simulated Firebase data (replace this with actual Firebase fetch later)
firebase_data = [
    {"username": "user01", "route": "Blumentritt to Balut", "distance": 5, "fare_given": 11.2, "passengerType": "discounted"},
    {"username": "user02", "route": "Blumentritt to Balut", "distance": 5, "fare_given": 13.0, "passengerType": "regular"},
    {"username": "user03", "route": "Blumentritt to Balut", "distance": 5, "fare_given": 25.0, "passengerType": "regular"},
    {"username": "user04", "route": "Monumento to Divisoria", "distance": 9, "fare_given": 18.7, "passengerType": "discounted"},
    {"username": "user05", "route": "Monumento to Divisoria", "distance": 9, "fare_given": 28.0, "passengerType": "regular"},
    {"username": "user06", "route": "Espana to Morayta", "distance": 2, "fare_given": 13.0, "passengerType": "regular"},
    {"username": "user07", "route": "Espana to Morayta", "distance": 2, "fare_given": 13.0, "passengerType": "regular"},
    {"username": "user08", "route": "Blumentritt to Balut", "distance": 5, "fare_given": 30.0, "passengerType": "regular"},
    {"username": "user09", "route": "Monumento to Divisoria", "distance": 9, "fare_given": 26.0, "passengerType": "regular"},
    {"username": "user10", "route": "Espana to Morayta", "distance": 2, "fare_given": 13.0, "passengerType": "regular"},
    # Add more entries as needed
]

# 📊 5. Analyze each route group
route_stats = defaultdict(lambda: {"total": 0, "anomalous": 0})

for entry in firebase_data:
    route = entry["route"]
    distance = entry["distance"]
    fare_given = entry["fare_given"]
    passenger_type = entry["passengerType"].lower()

    predicted_fare = model.predict([[distance]])[0]

    # 🧮 Apply 20% discount if discounted
    if passenger_type == "discounted":
        predicted_fare *= 0.80

    is_anomalous = abs(fare_given - predicted_fare) > threshold

    route_stats[route]["total"] += 1
    if is_anomalous:
        route_stats[route]["anomalous"] += 1

# 📋 6. Build result summary
summary = []
for route, stats in route_stats.items():
    total = stats["total"]
    anomalous = stats["anomalous"]
    if anomalous == 0:
        summary.append(f"📍 {route} — No Overcharging Detected (0/{total} Reports)")
    else:
        percent = round((anomalous / total) * 100)
        summary.append(f"📍 {route} — {percent}% Overcharging ({anomalous}/{total} Reports)")

# ✅ Sort alphabetically for frontend consistency
summary.sort()

# 📤 7. Output (replace with Firebase push or API return later)
print("\n📊 Crowd Validation Summary Report\n")
print("\n".join(summary))
