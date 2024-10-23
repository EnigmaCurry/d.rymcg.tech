import sys
import gradio as gr
import requests
import json

from config import get_logger, TRAEFIK_HOST, CHATBOT_API
log = get_logger("app")

# Function to stream responses from the LLM, maintaining context
def query_llm(input_text, history):
    # Include the entire conversation history in the payload
    messages = [{"role": "user", "content": user_message} if i % 2 == 0 else {"role": "assistant", "content": assistant_message}
                for i, (user_message, assistant_message) in enumerate(history)]

    # Add the new user input to the conversation history
    messages.append({"role": "user", "content": input_text})

    # Create the payload to send to the LLM
    payload = {
        "model": "your-model-identifier",
        "messages": messages,
        "stream": True  # Enable streaming
    }

    # Make a POST request to the LLM API with streaming enabled
    response = requests.post(CHATBOT_API, json=payload, stream=True)

    # Check if the response is valid
    if response.status_code == 200:
        partial_response = ""
        
        # Stream the response in chunks
        for line in response.iter_lines():
            if line:
                # Decode and load the JSON from each 'data:' chunk
                line_str = line.decode('utf-8')
                
                # Skip the DONE message
                if line_str.strip() == "data: [DONE]":
                    break
                
                if line_str.startswith("data:"):
                    data_json = line_str[6:]  # Remove 'data: ' prefix
                    data = json.loads(data_json)
                    
                    # Extract and append content from the "delta"
                    delta_content = data["choices"][0]["delta"].get("content", "")
                    partial_response += delta_content
                    
                    # Yield the partial response so far
                    yield partial_response
    else:
        yield f"Error: {response.status_code}"

# Using gr.ChatInterface to handle streaming
chatbot = gr.ChatInterface(fn=query_llm, title="LM Studio Chat")

print("Launching gradio interface ...")
sys.stdout.flush()
    
chatbot.launch(server_name="0.0.0.0", server_port=7860)
