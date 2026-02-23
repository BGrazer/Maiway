import os
from flask import Flask, request, jsonify, send_from_directory
from flask_cors import CORS
from chatbot_model import ChatbotModel
import asyncio

# Global instance
chatbot_instance = None

def init_chatbot():
    global chatbot_instance
    if chatbot_instance is None:
        print("DEBUG: Initializing ChatbotModel...")
        chatbot_instance = ChatbotModel()
    return chatbot_instance

# We keep your original routes here, but they will be used by the main app
def create_app():
    app = Flask(__name__)
    CORS(app)
    # The routes are now handled in main.py to avoid port conflicts
    return app

if __name__ == '__main__':
    init_chatbot()
    app = create_app()
    # (Your existing local run code)
    app.run(host='0.0.0.0', port=5001)