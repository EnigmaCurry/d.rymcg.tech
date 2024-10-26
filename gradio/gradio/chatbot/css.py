import os

with open(os.path.join(os.path.dirname(__file__), "style.css"), "r") as style:
    CSS = style.read()
