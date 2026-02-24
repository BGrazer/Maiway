import os
import sys
import asyncio
from flask import Flask, request, jsonify
from flask_cors import CORS
from asgiref.wsgi import WsgiToAsgi

# Import your custom logic
import rfr
import chatbot as chatbot_module
from crowd_analysis import analyze_route_with_reference_model

app = Flask(__name__)
CORS(app)

# Initialize chatbot
print("Starting MAIWAY Unified Backend...", flush=True)
chatbot = chatbot_module.init_chatbot()
print("Chatbot initialized successfully!", flush=True)

@app.route('/')
def health():
    print("Health check called", flush=True)
    return {"status": "MAIWAY System Online", "version": "1.0.0"}

# --- CHATBOT ROUTES ---
@app.route('/chat', methods=['POST'])
async def chat():
    print("Chat endpoint called", flush=True)
    data = request.json
    if not data or 'message' not in data:
        print("ERROR: No message in request", flush=True)
        return jsonify({"error": "No message"}), 400
    print(f"Received message: {data['message']}", flush=True)
    response = await chatbot.get_response(data['message'])  # type: ignore
    print(f"Sending response: {response}", flush=True)
    return jsonify({"response": response})

@app.route('/dynamic_suggestions', methods=['GET'])
def suggestions():
    query = request.args.get('query', '')
    if not query: return jsonify({"suggestions": []})
    results = chatbot.get_matching_questions(query)  # type: ignore
    return jsonify({"suggestions": results})

# --- FARE (RFR) ROUTES ---
@app.route('/predict_fare', methods=['POST'])
def predict_fare():
    print("Predict fare endpoint called", flush=True)
    data = request.json
    if not data:
        return jsonify({"error": "No data provided"}), 400
    try:
        result = rfr.check_fare_anomaly(
            data.get('vehicle_type'),
            float(data.get('distance_km', 0)),
            float(data.get('charged_fare', 0)),
            bool(data.get('discounted', False))
        )
        return jsonify(result)
    except Exception as e:
        print(f"ERROR in predict_fare: {e}", flush=True)
        return jsonify({"error": str(e)}), 400

# --- CROWD ANALYSIS ROUTE ---
@app.route('/run_analysis', methods=['GET'])
def run_analysis():
    analyze_route_with_reference_model()
    return jsonify({"message": "Crowd analysis triggered and logged."})

if __name__ == "__main__":
    port = int(os.environ.get("PORT", 10000))
    print(f"Starting server on port {port}", flush=True)
    app.run(host='0.0.0.0', port=port, debug=False)
