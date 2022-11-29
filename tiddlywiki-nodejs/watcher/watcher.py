import socketserver
import time
import re
import queue
import threading
import os
import json
import tempfile
import logging
import shutil
import uuid

import requests
from rclone_python import rclone
from rclone_python.utils import run_cmd
from tenacity import retry, wait_fixed, stop_after_delay
from bs4 import BeautifulSoup
from escapejson import escapejson
from PIL import Image


logging.basicConfig()
logger = logging.getLogger("watcher")
logger.setLevel(level=logging.INFO)


@retry(wait=wait_fixed(1), stop=stop_after_delay(60))
def wait_for_file(path):
    logger.info(f"Waiting for file: {path} ...")
    stat = os.stat(path)
    if stat.st_size == 0:
        raise AssertionError("File is empty")
    return True


################################################################################
### Load environment variables and set defaults
################################################################################
def require_env_vars(vars, allow_blank=False):
    errors = [
        f"Environment variable {var} is blank."
        for (var, val) in [(var, os.environ.get(var, "")) for var in vars]
        if (val == "" and not allow_blank)
    ]
    if len(errors):
        [logger.error(err) for err in errors]
        raise AssertionError("Could not load all required envrionment variables")
    for var in vars:
        try:
            # Try to read value as an integer:
            globals()[var] = int(os.environ.get(var, ""))
        except ValueError:
            try:
                # Try to read value as a float:
                globals()[var] = float(os.environ.get(var, ""))
            except ValueError:
                # If all else fails, read value as a string:
                globals()[var] = os.environ.get(var, "")


def default_env_vars(defaults):
    require_env_vars(defaults.keys(), allow_blank=True)
    for var, default in defaults.items():
        if globals().get(var, "") == "":
            globals()[var] = default


require_env_vars(
    [
        "TIDDLYWIKI_PUBLIC_ALLOWED_TAGS",
        "TIDDLYWIKI_PUBLIC_DEFAULT_TIDDLERS",
        "TIDDLYWIKI_HOST",
        "S3_ACCESS_KEY_ID",
        "S3_SECRET_KEY",
        "S3_ENDPOINT",
        "S3_BUCKET",
    ]
)
default_env_vars(
    {
        "TIDDLYWIKI_NODEJS_EXTERNAL_CANONICAL_URI": f"https://{TIDDLYWIKI_HOST}/s3-proxy",
        "SLEEP": 5,
        "IMAGE_THUMBNAIL_WIDTH": 128,
        "IMAGE_RESIZE_WIDTH": 640,
    }
)

################################################################################
### Render worker is a single thread to publish the static wiki snapshot.
### Other threads may call publish_static_wiki() and the render worker will do it
################################################################################
class RenderSchedule:
    def __init__(self):
        self.lock = threading.Lock()
        self.scheduled = False

    def schedule(self, value=True):
        with self.lock:
            self.scheduled = value

    def get_work(self, sleep=0.2):
        while True:
            if self.scheduled:
                self.schedule(False)
                return True
            time.sleep(sleep)


render_schedule = RenderSchedule()


def publish_static_wiki():
    print("Queueing render ...")
    render_schedule.schedule()


def render_worker():
    def render_static_wiki(
        tiddler_filter="[!is[system]]", template="$:/core/templates/static.tiddler.html"
    ):
        command = "tiddlywiki --build"
        process = run_cmd(command)
        if process.returncode == 0:
            logger.info(f"Wrote static site")
        else:
            logger.error(f"{command} failed! \n{process.stderr}")

    def get_html_tiddlers(wiki_html="/tiddlywiki/output/index.html"):
        """Get the Tiddler data from a rendered HTML file"""
        with open(wiki_html, "rb") as f:
            soup = BeautifulSoup(f.read().decode("utf-8"), features="html.parser")
            data = json.loads(
                soup.find_all("script", class_="tiddlywiki-tiddler-store")[0].text
            )
            tiddlers = {x.get("title", ""): x for x in data}
        return tiddlers

    def edit_html_tiddlers(
        default_tiddlers=TIDDLYWIKI_PUBLIC_DEFAULT_TIDDLERS,
        wiki_html="/tiddlywiki/output/index.html",
        allowed_tags=re.findall(r"(\w+|\[\[.*\]\])", TIDDLYWIKI_PUBLIC_ALLOWED_TAGS),
    ):
        tiddlers = get_html_tiddlers(wiki_html)
        default_tid = tiddlers.get(
            "$:/DefaultTiddlers", {"title": "$:/DefaultTiddlers"}
        )
        default_tid["text"] = default_tiddlers
        tiddlers["$:/DefaultTiddlers"] = default_tid
        tiddlers_filtered = []
        for t in tiddlers.values():
            tags = set(re.findall(r"(\w+|\[\[.*\]\])", t.get("tags", "")))
            if (
                (
                    t["title"].startswith("$:/")
                    or len(tags.intersection(allowed_tags)) > 0
                )
                and not t["title"].startswith("Draft of")
                and not t["title"].startswith("$:/trashbin/")
            ):
                tiddlers_filtered.append(t)
        with open(wiki_html, "rb") as f:
            soup = BeautifulSoup(f.read().decode("utf-8"), features="html.parser")
        soup.find_all("script", class_="tiddlywiki-tiddler-store")[
            0
        ].string = escapejson(
            json.dumps(list(tiddlers_filtered), sort_keys=True, indent=4)
        )
        tmp_dir = tempfile.mkdtemp()
        tmp_file = os.path.join(tmp_dir, "tmp.html")
        with open(tmp_file, "w", encoding="utf-8") as f:
            f.write(str(soup))
        return tmp_file

    #    def edit_html_javascript_disabled_warning()

    while True:
        render_schedule.get_work()
        logger.info("Running render ...")
        render_static_wiki()
        edited_wiki_path = edit_html_tiddlers()
        shutil.copyfile(edited_wiki_path, "/www/index.html")
        os.remove(edited_wiki_path)
        os.rmdir(os.path.dirname(edited_wiki_path))
        logger.info(f"Sleeping for (at least) {SLEEP} seconds ...")
        time.sleep(SLEEP)


################################################################################
### Task worker is a single thread to manipulate and export embedded media:
### (Image files only right now)
###  * Remove image data from tiddlers
###  * Resize images
###  * Strip EXIF metadata
###  * Set tiddler fields:
###     _canonical_uri (resized to IMAGE_RESIZE_WIDTH)
###     _canonical_uri_thumbnail (resized to IMAGE_THUMBNAIL_WIDTH)
###     _canonical_uri_original (original size)
###  * Upload files to S3
################################################################################
task_re = re.compile("syncer-server-filesystem: Dispatching '(\w+)' task: (.+)")
task_queue = queue.Queue()
media_file_extensions = ["jpg", "png", "gif"]


def task_worker():
    def create_rclone_config(
        type="s3",
        provider="Minio",
        access_key_id=S3_ACCESS_KEY_ID,
        secret_key=S3_SECRET_KEY,
        endpoint=S3_ENDPOINT,
    ):
        content = f"""[s3]
type = {type}
provider = {provider}
access_key_id = {access_key_id}
secret_access_key = {secret_key}
endpoint = {endpoint}"""
        parent = os.path.join(os.path.expanduser("~"), ".config", "rclone")
        os.makedirs(parent, exist_ok=True)
        with open(os.path.join(parent, "rclone.conf"), "w") as f:
            f.write(content)

    def metadata_anonymize(path):
        command = f"mat2 --inplace -L {path}"
        process = run_cmd(command)
        if process.returncode == 0:
            logger.info(f"Removed metadata: {path}")
        else:
            logger.error(f"{command} failed! \n{process.stderr}")

    def rclone_sync_s3(remote="s3"):
        command = f"rclone sync /tiddlywiki {remote}:{S3_BUCKET}/tiddlywiki"
        process = run_cmd(command)
        if process.returncode == 0:
            logger.info("Successfully synced to S3")
        else:
            logger.error(f"S3 sync failed! \n{process.stderr}")

    def resize_image(img_path):
        def save(img, name):
            img.save(
                os.path.join(
                    os.path.dirname(img_path),
                    os.path.join("/tiddlywiki/files/", name),
                )
            )

        with Image.open(img_path) as img:
            aspect = img.size[1] / img.size[0]
            if img.size[0] > IMAGE_RESIZE_WIDTH:
                resized = img.resize(
                    (IMAGE_RESIZE_WIDTH, int(IMAGE_RESIZE_WIDTH * aspect))
                )
                resized_name = f"{uuid.uuid4()}.jpg"
                save(resized, resized_name)
            thumbnail = img.copy()
            thumbnail.thumbnail((IMAGE_THUMBNAIL_WIDTH, IMAGE_THUMBNAIL_WIDTH))
            thumbnail_name = f"{uuid.uuid4()}.jpg"
            save(thumbnail, thumbnail_name)
        return {"resized": resized_name, "thumbnail": thumbnail_name}

    create_rclone_config()
    publish_static_wiki()
    os.makedirs("/tiddlywiki/files", exist_ok=True)
    while True:
        task, title = task_queue.get()
        tiddler_path = os.path.join("/tiddlywiki/tiddlers", title)
        file_path = os.path.join("/tiddlywiki/files", title)
        key = tiddler_path.replace("/tiddlywiki/tiddlers/", "")
        extension = key.split(".")[-1]
        canonical_name = f"{uuid.uuid4()}.{extension}"
        if task == "delete" and title.lower().split(".")[-1] in media_file_extensions:
            if os.path.exists(file_path):
                logger.info(f"Deleting original file: {file_path}")
                os.remove(file_path)
        if task == "save" and title.lower().split(".")[-1] in media_file_extensions:
            logger.info("Retrieving original tiddler")
            json = requests.get(
                f"http://tiddlywiki-nodejs:8080/recipes/default/tiddlers/{key}",
            ).json()
            if "_canonical_uri_resized" not in json.get("fields", []) and wait_for_file(
                tiddler_path
            ):
                metadata_anonymize(tiddler_path)
                resized_names = resize_image(tiddler_path)
                os.rename(tiddler_path, f"/tiddlywiki/files/{canonical_name}")
                if wait_for_file(f"{tiddler_path}.meta"):
                    os.remove(f"{tiddler_path}.meta")
                logger.info("Creating new tid file with image link")
                json["type"] = "text/vnd.tiddlywiki"
                json["text"] = (
                    '<a href={{!!_canonical_uri_original}} target="_blank">'
                    + "<img src={{!!_canonical_uri_resized}} /></a>"
                )
                if "data" in json:
                    del json["data"]
                json["fields"] = {
                    "_canonical_uri_resized": f"{TIDDLYWIKI_NODEJS_EXTERNAL_CANONICAL_URI}/{resized_names['resized']}",
                    "_canonical_uri_thumbnail": f"{TIDDLYWIKI_NODEJS_EXTERNAL_CANONICAL_URI}/{resized_names['thumbnail']}",
                    "_canonical_uri_original": f"{TIDDLYWIKI_NODEJS_EXTERNAL_CANONICAL_URI}/{canonical_name}",
                }
                res = requests.put(
                    f"http://tiddlywiki-nodejs:8080/recipes/default/tiddlers/{title}",
                    headers={"X-Requested-With": "TiddlyWiki"},
                    json=json,
                )
        rclone_sync_s3()
        publish_static_wiki()
        task_queue.task_done()


class MyUDPHander(socketserver.BaseRequestHandler):
    def handle(self):
        data = self.request[0].strip().decode("utf-8")
        # logger.info(f"data: {repr(data)}")
        task_m = task_re.search(data)
        if task_m:
            task, title = task_m.group(1, 2)
            if (
                title != "$:/StoryList"
                and not title.startswith("$:/trashbin/")
                and not title.startswith("Draft of")
                and task in ("save", "delete")
            ):
                task_queue.put((task, title))
            else:
                # Don't publish anything for small changes like StoryList and Drafts:
                # publish_static_wiki()
                pass


def main():
    threading.Thread(target=task_worker, daemon=True).start()
    threading.Thread(target=render_worker, daemon=True).start()
    HOST, PORT = "0.0.0.0", 2000
    with socketserver.UDPServer((HOST, PORT), MyUDPHander) as server:
        logger.info("Starting socket server on {}:{}".format(HOST, PORT))
        server.serve_forever()
    logger.info("joining last worker queue ...")
    task_queue.join()
    logger.info("All work completed.")


if __name__ == "__main__":
    main()
