from flask import Flask
import subprocess

app = Flask(__name__)

@app.route('/')
def hello():
    return "Backend is running"

if __name__ == "__main__":
    subprocess.Popen(["python", "rfr.py"])
    subprocess.Popen(["python", "crowd_analysis.py"])
    subprocess.Popen(["python", "chatbot.py"])
    app.run(host='0.0.0.0', port=5000)