import socketserver
import time
import re
import queue
import threading
import os
import requests
from rclone_python import rclone, utils as rclone_utils
from tenacity import retry, wait_fixed, stop_after_delay

import logging
logging.basicConfig()
logger = logging.getLogger("watcher")
logger.setLevel(level=logging.INFO)

task_re = re.compile("syncer-server-filesystem: Dispatching '(\w+)' task: (.+)")
image_types = ['jpg', 'png', 'gif']
task_queue = queue.Queue()
canonical_uri_prefix = os.environ.get("TIDDLYWIKI_NODEJS_EXTERNAL_CANONICAL_URI","")
if canonical_uri_prefix == "":
    canonical_uri_prefix = f"https://{os.environ['TIDDLYWIKI_HOST']}/s3-proxy"

@retry(wait=wait_fixed(1), stop=stop_after_delay(60))
def wait_for_file(path):
    logger.info(f"## Waiting for file: {path} ...")
    stat = os.stat(path)
    if stat.st_size == 0:
        raise AssertionError("File is empty")
    return True

def create_rclone_config(type="s3", provider="Minio", access_key_id=os.environ['S3_ACCESS_KEY_ID'],
                         secret_key=os.environ['S3_SECRET_KEY'], endpoint=os.environ['S3_ENDPOINT']):
    content=f"""[s3]
type = {type}
provider = {provider}
access_key_id = {access_key_id}
secret_access_key = {secret_key}
endpoint = {endpoint}
"""
    parent = os.path.join(os.path.expanduser("~"), ".config","rclone")
    os.makedirs(parent, exist_ok=True)
    with open(os.path.join(parent,"rclone.conf"), "w") as f:
        f.write(content)

def rclone_sync(remote="s3"):
    command = f"rclone sync /tiddlywiki {remote}:{os.environ['S3_BUCKET']}/tiddlywiki"
    process = rclone_utils.run_cmd(command)
    if process.returncode == 0:
        logger.info("Successfully synced to S3")
    else:
        raise Exception(f"S3 sync failed! \n{process.stderr}")

def task_worker():
    create_rclone_config()
    rclone_sync()
    os.makedirs("/tiddlywiki/files", exist_ok=True)
    while True:
        task, title = task_queue.get()
        tiddler_path = os.path.join("/tiddlywiki/tiddlers",title)
        file_path = os.path.join("/tiddlywiki/files",title)
        key = tiddler_path.replace("/tiddlywiki/tiddlers/","")
        if task == "delete" and title.lower().split(".")[-1] in image_types:
            if os.path.exists(file_path):
                logger.info(f"## Deleting original image: {file_path}")
                os.remove(file_path)
        if task == "save" and title.lower().split(".")[-1] in image_types:
            logger.info("## Retrieving original tiddler")
            json = requests.get(
                f"http://tiddlywiki-nodejs:8080/recipes/default/tiddlers/{key}",
            ).json()
            if "_canonical_uri" not in json.get("fields", []) and wait_for_file(tiddler_path):
                os.rename(tiddler_path, f"/tiddlywiki/files/{os.path.basename(tiddler_path)}")
                if wait_for_file(f"{tiddler_path}.meta"):
                    os.remove(f"{tiddler_path}.meta")
                logger.info("## Creating new tid file with image link")
                json["text"] = ""
                if "data" in json:
                    del json["data"]
                json["fields"] = {
                    "_canonical_uri": f"{canonical_uri_prefix}/{key}"
                }
                res = requests.put(
                    f"http://tiddlywiki-nodejs:8080/recipes/default/tiddlers/{title}",
                    headers={"X-Requested-With": "TiddlyWiki"},
                    json=json
                )
                if wait_for_file(f"{tiddler_path}.meta"):
                    pass
        rclone_sync()
        task_queue.task_done()

class MyUDPHander(socketserver.BaseRequestHandler):
    def handle(self):
        data = self.request[0].strip().decode("utf-8")
        #logger.info(f"data: {repr(data)}")
        task_m = task_re.search(data)
        if task_m:
            task,title = task_m.group(1,2)
            if (title != "$:/StoryList"
                and not title.startswith("Draft of")
                and task in ('save','delete')):
                task_queue.put((task,title))
def main():
    threading.Thread(target=task_worker, daemon=True).start()
    HOST, PORT = "0.0.0.0", 2000
    with socketserver.UDPServer((HOST, PORT), MyUDPHander) as server:
        logger.info("Starting socket server on {}:{}".format(HOST, PORT))
        server.serve_forever()
    logger.info("joining last worker queue ...")
    task_queue.join()
    logger.info("All work completed.")

if __name__ == "__main__":
    main()
