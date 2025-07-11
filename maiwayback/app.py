import numpy as np
from sklearn.ensemble import RandomForestRegressor

def analyze_route_simulated():
    # Dummy crowd survey: 30 samples (16 overcharged, 14 normal)
    # Format: (distance_km, charged_fare)
    dummy_data = [
        # Non-overcharged (based on regular fare ~10 per km)
        (2.0, 20), (2.5, 25), (1.8, 18), (3.0, 30), (2.2, 22),
        (1.5, 15), (2.3, 23), (2.1, 21), (1.9, 19), (2.4, 24),
        (2.0, 20), (2.5, 25), (1.7, 17), (3.0, 30),

        # Overcharged
        (2.0, 40), (2.5, 50), (1.8, 35), (3.0, 55), (2.2, 45),
        (1.5, 30), (2.3, 42), (2.1, 38), (1.9, 36), (2.4, 48),
        (2.0, 39), (2.5, 49), (1.7, 33), (3.0, 50), (2.6, 47),
        (2.8, 52)
    ]

    distances = [d[0] for d in dummy_data]
    fares = [d[1] for d in dummy_data]

    X = np.array(distances).reshape(-1, 1)
    y = np.array(fares)

    # Train crowd model
    model = RandomForestRegressor(n_estimators=100, random_state=42)
    model.fit(X, y)

    # Predict and compute errors
    predicted = model.predict(X)
    errors = abs(predicted - y)

    # Dynamic anomaly threshold (same logic as backend)
    threshold = np.mean(errors) + 3 * np.std(errors)

    # Count anomalies
    overcharged_count = np.sum(errors > threshold)
    total_count = len(dummy_data)

    print(f"\n🚌 [Crowd Validation Result: Jeep - Balut to Divisoria]")
    print(f"📊 Sample Size: {total_count}")
    print(f"💸 Community Average Fare: ₱{np.mean(fares):.2f}")
    print(f"📉 Model Accuracy (R²): {model.score(X, y) * 100:.2f}%")
    print(f"🚨 Anomaly Threshold: ₱{threshold:.2f}")
    print(f"⚠️ Detected Overcharged Reports: {overcharged_count}/{total_count}")

    if overcharged_count / total_count >= 0.5:
        print("🟡 ALERT: Possible systemic overpricing on this route!")
    else:
        print("🟢 Route pricing appears within normal range.")

# Run simulation
analyze_route_simulated()
