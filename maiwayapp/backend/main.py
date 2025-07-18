import subprocess
import os
import sys
import time
import signal # Import signal for graceful shutdown (optional but good practice)

print("INFO: main.py started.")

# --- Start other background processes ---
# Assuming rfr.py and crowd_analysis.py are truly background tasks
# that do not expose web interfaces or need their own specific ports.
# Using sys.executable ensures the correct Python interpreter is used.

# Example: Launching rfr.py and crowd_analysis.py
# You might want to add more robust error handling or logging for these
print("INFO: Launching rfr.py in background...")
rfr_process = subprocess.Popen([sys.executable, "rfr.py"])

print("INFO: Launching crowd_analysis.py in background...")
crowd_analysis_process = subprocess.Popen([sys.executable, "crowd_analysis.py"])

# --- Hand over control to Hypercorn ---
# This is the crucial part. os.execv REPLACES the current main.py process
# with the Hypercorn process. main.py WILL STOP RUNNING after this line.
# Hypercorn will then become the primary process of the Docker container.

# Construct the Hypercorn command arguments
hypercorn_args = [
    sys.executable,               # The Python executable
    "-m", "hypercorn",            # Run hypercorn as a module
    "chatbot:app",                # Your application object (app in chatbot.py)
    "--bind", f"0.0.0.0:{os.getenv('PORT', '5001')}", # Bind to Railway's assigned port
    "--worker-class", "asyncio",  # Use the asyncio worker class
    "--access-logk", "-",         # Log access to stdout
    "--error-log", "-"            # Log errors to stdout
]

print(f"INFO: Replacing current process with Hypercorn: {' '.join(hypercorn_args)}")

try:
    # Use os.execv to replace the current process with Hypercorn
    # The first argument is the path to the executable (sys.executable)
    # The second argument is a list of arguments, where the first element
    # is conventionally the name of the program being executed (e.g., 'python' or 'hypercorn')
    os.execv(sys.executable, hypercorn_args)
except Exception as e:
    print(f"FATAL: Failed to exec into Hypercorn: {e}")
    # You might want to log this error more persistently or alert
    sys.exit(1) # Exit with an error code if exec fails

# This part of main.py will NEVER be reached if os.execv is successful.
print("ERROR: main.py should not reach here if exec was successful.")