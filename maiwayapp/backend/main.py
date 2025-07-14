from flask import Flask
from flask_cors import CORS
from rfr import rfr_bp
from chatbot import chatbot_bp
import os

app = Flask(__name__)
CORS(app)

# Register Blueprints
app.register_blueprint(rfr_bp)
app.register_blueprint(chatbot_bp)

if __name__ == '__main__':
    port = int(os.environ.get('PORT', 5000))
    app.run(host='0.0.0.0', port=port)