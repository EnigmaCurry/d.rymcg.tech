from config import *
from fastapi import FastAPI, Request
from proxy import proxy_request

log = get_logger(__name__)

if MODE == "proxy":
    app = FastAPI()

    # @app.get("/")
    # def read_main():
    #     return {"message": "This is the main app"}

    # Proxy route for Gradio
    @app.api_route(
        "/{path:path}",
        methods=["GET", "POST", "PUT", "DELETE", "OPTIONS", "HEAD"],
    )
    async def proxy_chatbot(request: Request, path: str):
        target_url = f"http://gradio:7860/{path}"
        return await proxy_request(request, target_url, "/")

elif __name__ == "__main__":
    from chatbot import *

    run_gradio()
