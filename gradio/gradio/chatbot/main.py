from config import *
import json
import requests
import subprocess
import os
from tempfile import NamedTemporaryFile
import gradio as gr

# Function to stream responses from the LLM, maintaining context
def query_llm(input_text, history=[]):
    log.debug(f"User Input: {input_text}")

    # Include the entire conversation history in the payload
    messages = [{"role": "user", "content": user_message} if i % 2 == 0 else {"role": "assistant", "content": assistant_message}
                for i, (user_message, assistant_message) in enumerate(history)]

    # Add the new user input to the conversation history
    messages.append({"role": "user", "content": input_text})

    # Create the payload to send to the LLM
    payload = {
        "model": "codestral-22b-v0.1",  # Updated model identifier
        "messages": messages,
        "stream": True  # Enable streaming
    }

    # Make a POST request to the LLM API with streaming enabled
    response = requests.post(CHATBOT_API, json=payload, stream=True)

    # Check if the response is valid
    if response.status_code == 200:
        full_response = ""

        # Stream the response in chunks and accumulate the full response as a string
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
                    full_response += delta_content

        log.debug(f"Assistant Full Response: {full_response}")
        return full_response  # Return full response as a string
    else:
        error_message = f"Error: {response.status_code}"
        log.error(error_message)
        return error_message

def generate_tts(text):
    try:
        # Temporary file to store the TTS output
        with NamedTemporaryFile(suffix=".wav", delete=False) as temp_wav:
            # Command to call Piper
            command = [
                "piper",  # Piper binary
                "--model", "/app/piper_models/en_US-amy-low.onnx",  # Adjust the path to your model
                "--output_file", temp_wav.name  # Correct flag for the output file
            ]

            # Log the command being run
            logging.info(f"Running Piper command: {' '.join(command)}")

            # Run the Piper command and pass the text via stdin
            result = subprocess.run(command, input=text, text=True, capture_output=True)

            # Log the stdout and stderr from Piper
            logging.info(f"Piper stdout: {result.stdout}")
            logging.error(f"Piper stderr: {result.stderr}")

            # Check if Piper succeeded in generating the file
            if os.path.getsize(temp_wav.name) == 0:
                logging.error("Generated audio file is empty.")
                return None

            # Return the path to the generated WAV file
            return temp_wav.name

    except subprocess.CalledProcessError as e:
        logging.error(f"Error generating TTS: {e}")
        return None
    
# Gradio function to handle both text and audio responses
def chat_with_tts(input_text):
    # Initialize conversation history
    history = []  # Optionally, store this in session state for full conversation

    # Get the LLM response
    response_text = query_llm(input_text, history)

    # Generate the audio using Piper
    audio_path = generate_tts(response_text)

    # Return the response text and the audio file path for Gradio
    return response_text, audio_path  # Return the audio file path only

# Set up the Gradio interface using gr.Interface for handling both text and audio
interface = gr.Interface(
    fn=chat_with_tts,
    inputs=[gr.Textbox(lines=2, placeholder="Enter text...")],
    outputs=[gr.Textbox(), gr.Audio(type="filepath")],  # Explicitly specify filepath
    title="LM Studio Chat with TTS"
)

# Launch the interface
launch(interface)
