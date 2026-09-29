import sys
import os

# --- THE PYINSTALLER NOCONSOLE PATCH ---
# If the terminal is hidden, redirect all prints and logs into a black hole (devnull)
# so Uvicorn doesn't crash trying to print colored text!
if sys.stdout is None:
    sys.stdout = open(os.devnull, "w")
if sys.stderr is None:
    sys.stderr = open(os.devnull, "w")

import uvicorn
from main import app

if __name__ == "__main__":
    uvicorn.run(app, host="0.0.0.0", port=8000)