import subprocess
import sys
import time

# Use same Python as main.py (so venv packages are available in all children)
py = sys.executable

subprocess.Popen([py, "rfr.py"])
subprocess.Popen([py, "crowd_analysis.py"])
subprocess.Popen([py, "chatbot.py"])
subprocess.Popen([py, "routing/routing.py"])

# Keep container alive
while True:
    time.sleep(10)