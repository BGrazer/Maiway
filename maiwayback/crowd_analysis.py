import firebase_admin
from firebase_admin import credentials, firestore
import numpy as np
from sklearn.ensemble import RandomForestRegressor

# ✅ Firebase Init (reuse this for app.py if you want)
cred = credentials.Certificate("your-service-account.json")
firebase_admin.initialize_app(cred)
db = firestore.client()

def analyze_route(route_taken, vehicle_type, passenger_type):
    docs = db.collection('trip_surveys') \
             .where('route_taken', '==', route_taken) \
             .where('vehicle_type', '==', vehicle_type) \
             .where('passenger_type', '==', passenger_type) \
             .stream()

    distances, fares = [], []

    for doc in docs:
        data = doc.to_dict()
        distances.append(data['distance_km'])
        fares.append(data['charged_fare'])

    if len(distances) < 5:
        print("Not enough samples for community analysis.")
        return

    X = np.array(distances).reshape(-1, 1)
    y = np.array(fares)

    model = RandomForestRegressor(n_estimators=100)
    model.fit(X, y)

    predicted = model.predict(X)
    errors = abs(predicted - y)
    threshold = np.mean(errors) + 3 * np.std(errors)

    print(f"[Route: {route_taken}]")
    print(f"Sample Size: {len(fares)}")
    print(f"Community Average Fare: ₱{np.mean(fares):.2f}")
    print(f"Community Threshold: ₱{threshold:.2f}")
    print(f"Model Accuracy: {model.score(X, y) * 100:.2f}%")

# 🔍 Example usage
analyze_route("Blumentritt-Divisoria", "Jeep", "Discounted")
