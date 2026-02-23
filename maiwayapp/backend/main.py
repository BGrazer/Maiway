import os
import asyncio
from flask import Flask, request, jsonify
from flask_cors import CORS

# Import your custom logic from your files
import rfr
import chatbot as chatbot_module
from crowd_analysis import analyze_route_with_reference_model

app = Flask(__name__)
CORS(app)

# Initialize systems on startup
print("Starting MAIWAY Unified Backend...")
chatbot = chatbot_module.init_chatbot()

@app.route('/')
def health():
    return {"status": "MAIWAY System Online", "version": "1.0.0"}

# --- CHATBOT ROUTES ---
@app.route('/chat', methods=['POST'])
async def chat():
    data = request.json
    if not data or 'message' not in data:
        return jsonify({"error": "No message"}), 400
    response = await chatbot.get_response(data['message'])  # type: ignore
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
        return jsonify({"error": str(e)}), 400

# --- CROWD ANALYSIS ROUTE ---
@app.route('/run_analysis', methods=['GET'])
def run_analysis():
    # This runs the logic from your crowd_analysis.py
    analyze_route_with_reference_model()
    return jsonify({"message": "Crowd analysis triggered and logged."})

if __name__ == "__main__":
    # Render assigns a port via environment variable. Default to 10000 for Render.
    port = int(os.environ.get("PORT", 10000))
    app.run(host='0.0.0.0', port=port)