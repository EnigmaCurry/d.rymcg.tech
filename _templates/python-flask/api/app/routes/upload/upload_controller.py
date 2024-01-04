from flask import request, Blueprint, session, abort, redirect
from jinja2 import TemplateNotFound
from models.upload import (
    create_tables_upload,
    get_user_uploads,
    register_upload
)
from lib.template import render
from lib.config import UPLOAD_FOLDER

from datetime import datetime
import logging
import uuid
import os

log = logging.getLogger(__name__)

# upload is an example Flask Blueprint which organizes a group of
# related routes together into a single module. This example is built
# using a model-view-controller (MVC) abstraction; with separate
# layers for data, template, and logic..

upload = Blueprint("upload", __name__, template_folder="templates")


@upload.record_once
def init(context):
    """Initialize the upload module on app startup"""
    create_tables_upload()

@upload.route("/", methods=["GET"])
def index():
    return render(f"upload/upload.html")

@upload.route("/", methods=["POST"])
def upload_file():
    # check if the post request has the file part
    if 'upload_file' not in request.files:
        return redirect(request.url)
    # The only file is named 'upload_file'
    file = request.files['upload_file']
    # If the user does not select a file, the browser submits an
    # empty file without a filename.
    if file.filename == '':
        return redirect(request.url)
    ## generate a unique filename and save the file:
    filename=os.path.join(str(UPLOAD_FOLDER), str(uuid.uuid4()))
    file.save(filename)
    ## Record the upload in the database:
    register_upload(uploader="bob", original_filename="foo.txt",
                    upload_date=datetime.now(), upload_path=filename,
                    status="uploaded")
    return render(f"upload/success.html")
    
@upload.route("/uploads/<user>")
def user_uploads(user):
    return render(f"upload/user_uploads.html", user=user)
