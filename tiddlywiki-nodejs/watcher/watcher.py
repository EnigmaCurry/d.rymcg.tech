import socketserver
import time
import re
import queue
import threading
import boto3
import os
import magic
import requests

task_re = re.compile("syncer-server-filesystem: Dispatching '(\w+)' task: (.+)")

task_queue = queue.Queue()

def wait_for_file(path, tries=10, wait=0.1):
    attempts = 0
    while not os.path.exists(path):
        if attempts > tries:
            logging.warn(f"File does not exist: {path}")
            return False
        time.sleep(wait)
    #time.sleep(1)
    return True

def task_worker():
    boto_session = boto3.session.Session()
    s3_resource = boto_session.resource(
        service_name="s3",
        aws_access_key_id=os.environ["S3_ACCESS_KEY_ID"],
        aws_secret_access_key=os.environ["S3_SECRET_KEY"],
        endpoint_url=f"https://{os.environ['S3_ENDPOINT']}"
    )
    while True:
        task, title = task_queue.get()
        if task == "save" and title.lower().endswith(".jpg"):
            img_path = os.path.join("/tiddlywiki/tiddlers",title)
            key = img_path.replace("/tiddlywiki/tiddlers/","")
            print("## Retrieving original tiddler")
            json = requests.get(
                f"http://tiddlywiki-nodejs:8080/recipes/default/tiddlers/{key}",
            ).json()
            if "_canonical_uri" not in json.get("fields", []) and wait_for_file(img_path):
                print("## Uploading jpg to S3")
                s3_resource.Object(os.environ['S3_BUCKET'], key).upload_file(Filename=img_path)
                print("## Deleting original image")
                res = requests.delete(
                    f"http://tiddlywiki-nodejs:8080/bags/default/tiddlers/{key}",
                    headers={"X-Requested-With": "TiddlyWiki"})
                print("## Creating new tid file with image link")
                json["text"] = ""
                if "data" in json:
                    del json["data"]
                json["fields"] = {
                    "_canonical_uri": f"https://{os.environ['TIDDLYWIKI_HOST']}/s3-proxy/{key}"
                }
                res = requests.put(
                    f"http://tiddlywiki-nodejs:8080/recipes/default/tiddlers/{title}",
                    headers={"X-Requested-With": "TiddlyWiki"},
                    json=json
                )
        task_queue.task_done()

class MyUDPHander(socketserver.BaseRequestHandler):
    def handle(self):
        data = self.request[0].strip().decode("utf-8")
        #print(f"data: {repr(data)}")
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
        print("Starting socket server on {}:{}".format(HOST, PORT))
        server.serve_forever()
    print("joining last worker queue ...")
    task_queue.join()
    print("All work completed.")

if __name__ == "__main__":
    main()
