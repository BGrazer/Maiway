import numpy as np
import pandas as pd
from sklearn.ensemble import RandomForestRegressor
from datetime import datetime

def analyze_route_with_reference_model():
    print("🔍 Running crowd anomaly analysis for route: Balut to Divisoria (Jeep)")

    # 🚨 Load reference fare data (clean data only!)
    try:
        df_ref = pd.read_csv("jeep_fare.csv")
        df_ref.columns = df_ref.columns.str.strip()  # Ensure clean column names
    except Exception as e:
        print(f"❌ Failed to load jeep_fare.csv: {e}")
        return

    # Train model using only official fare matrix
    X_train = df_ref[['Distance (km)']].values
    y_train = df_ref['Regular Fare (₱)'].values

    model = RandomForestRegressor(n_estimators=100, random_state=42)
    model.fit(X_train, y_train)

    # Calculate anomaly threshold from reference data
    ref_predictions = model.predict(X_train)
    ref_errors = abs(ref_predictions - y_train)
    threshold = np.mean(ref_errors) + 3 * np.std(ref_errors)

    # 🧪 Simulated 30 crowd survey reports (14 normal, 16 overcharged)
    dummy_data = [
        # Normal fares
        (2.0, 20), (2.5, 25), (1.8, 18), (3.0, 30), (2.2, 22),
        (1.5, 15), (2.3, 23), (2.1, 21), (1.9, 19), (2.4, 24),
        (2.0, 20), (2.5, 25), (1.7, 17), (3.0, 30),

        # Overcharged fares
        (2.0, 40), (2.5, 50), (1.8, 35), (3.0, 55), (2.2, 45),
        (1.5, 30), (2.3, 42), (2.1, 38), (1.9, 36), (2.4, 48),
        (2.0, 39), (2.5, 49), (1.7, 33), (3.0, 50), (2.6, 47),
        (2.8, 52)
    ]

    distances = [d[0] for d in dummy_data]
    fares = [d[1] for d in dummy_data]
    X_crowd = np.array(distances).reshape(-1, 1)

    predicted = model.predict(X_crowd)
    errors = abs(predicted - fares)

    # Compile reports with anomaly flag
    reports = []
    for i in range(len(dummy_data)):
        reports.append({
            'distance_km': distances[i],
            'charged_fare': fares[i],
            'predicted_fare': round(predicted[i], 2),
            'is_anomalous': errors[i] > threshold,
            'timestamp': datetime.now().isoformat()
        })

    # Count anomaly
    overcharged_count = sum(r['is_anomalous'] for r in reports)
    total_count = len(reports)
    ratio = overcharged_count / total_count

    # Route tagging logic
    if total_count < 10:
        route_tag = "⚪ Not enough reports to evaluate this route."
    elif ratio >= 0.5:
        route_tag = "🟥 OVERCHARGE ALERT: Systemic overpricing detected on this route."
    elif ratio >= 0.3:
        route_tag = "🟠 WARNING: Some reports show fare irregularities."
    else:
        route_tag = "🟢 Normal fare behavior observed."

    # 🔎 Summary
    print("\n📊 CROWD VALIDATION SUMMARY")
    print(f"📍 Route: Balut to Divisoria")
    print(f"🚌 Vehicle: Jeep")
    print(f"📦 Sample Size: {total_count}")
    print(f"💸 Avg Reported Fare: ₱{np.mean(fares):.2f}")
    print(f"📉 Reference Model Accuracy: {model.score(X_train, y_train) * 100:.2f}%")
    print(f"🚨 Anomaly Threshold: ₱{threshold:.2f}")
    print(f"⚠️ Overcharged Reports: {overcharged_count}/{total_count}")
    print(f"🏷️ Route Status: {route_tag}")

    # Detailed reports (optional)
    print("\n🧾 Detailed Reports:")
    for r in reports:
        print(r)

# Run it
if __name__ == "__main__":
    analyze_route_with_reference_model()
