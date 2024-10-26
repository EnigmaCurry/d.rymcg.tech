import os

with open(os.path.join(os.path.dirname(__file__), "script.js"), "r") as script:
    PAGE_SCRIPT = script.read()
