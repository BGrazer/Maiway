import os
from flask import Flask, request, jsonify, send_from_directory
from flask_cors import CORS
from chatbot_model import ChatbotModel
import asyncio

chatbot = None

def create_app():
    """
    Factory function to create and configure the Flask app.
    This ensures that chatbot_model is initialized within the app's context.
    """
    global chatbot 
    app = Flask(__name__)
    CORS(app)

    if chatbot is None:
        print("DEBUG: Initializing ChatbotModel inside create_app()...")
        chatbot = ChatbotModel()
        print("DEBUG: ChatbotModel initialized inside create_app().")

    @app.route('/chat', methods=['POST'])
    async def chat():
        if request.json is None:
            return jsonify({"error": "Request body must be JSON"}), 400

        user_message = request.json.get('message')
        if not user_message:
            return jsonify({"error": "No 'message' key provided in JSON body or message is empty"}), 400

        if chatbot is None:
            return jsonify({"error": "Chatbot is not yet initialized. Please wait."}), 503

        response = await chatbot.get_response(user_message)
        return jsonify({"response": response})

    @app.route('/dynamic_suggestions', methods=['GET'])
    def get_dynamic_suggestions():
        try:
            query = request.args.get('query', '')
            if not query:
                return jsonify({"suggestions": []})
            
            if chatbot is None:
                return jsonify({"error": "Chatbot is not yet initialized. Please wait."}), 503

            suggestions = chatbot.get_matching_questions(query)
            return jsonify({"suggestions": suggestions})
        except Exception as e:
            return jsonify({"error": f"An unexpected server error occurred: {e}"}), 500

    @app.route('/admin/add_faq', methods=['POST'])
    def add_faq():
        if request.json is None:
            return jsonify({"error": "Request body must be JSON for FAQ addition"}), 400

        data = request.json
        question = data.get('question')
        answer = data.get('answer')

        if not question or not answer:
            return jsonify({"error": "Both 'question' and 'answer' are required."}), 400
        
        if chatbot is None:
            return jsonify({"error": "Chatbot is not yet initialized. Please wait."}), 503

        success = chatbot.add_faq(question, answer)
        if success:
            return jsonify({"message": "FAQ added and chatbot knowledge base updated."}), 200
        else:
            return jsonify({"message": "FAQ (or similar question) already exists."}), 200

    @app.route('/admin/reload_chatbot', methods=['POST'])
    def reload_chatbot():
        if chatbot is None:
            return jsonify({"error": "Chatbot is not yet initialized. Cannot reload."}), 503
        chatbot.reload_data()
        return jsonify({"message": "Chatbot data reloaded successfully."})

    @app.route('/data/faq_data.json')
    def serve_faq_data():
        return send_from_directory(os.path.join(app.root_path, 'data'), 'faq_data.json')

    return app

app = create_app()

if __name__ == '__main__':
    import socket
    local_ip = socket.gethostbyname(socket.gethostname())
    print(f"\n🤖 Chatbot backend running at: http://{local_ip}:5001\n")
    app.run(host='0.0.0.0', port=5001, debug=False)