import sys
import os
from flask import Flask

from .database import db
from . import lib

app = Flask(__name__)
