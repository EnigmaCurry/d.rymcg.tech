from config import *

log = get_logger(__name__)

def query_llm(input_text, history=None):
    if history is None:
        history = []

    log.debug(f"User Input: {input_text}")

    # Append the current user input to the history before sending the request
    messages = [{"role": "user", "content": user_message} if i % 2 == 0 else {"role": "assistant", "content": assistant_message}
                for i, (user_message, assistant_message) in enumerate(history)]

    messages.append({"role": "user", "content": input_text})

    payload = {
        "model": "codestral-22b-v0.1",
        "messages": messages,
        "stream": True
    }

    response = requests.post(CHATBOT_API, json=payload, stream=True)

    if response.status_code == 200:
        full_response = ""
        for line in response.iter_lines():
            if line:
                line_str = line.decode('utf-8')
                if line_str.strip() == "data: [DONE]":
                    break
                if line_str.startswith("data:"):
                    data_json = line_str[6:]
                    data = json.loads(data_json)
                    delta_content = data["choices"][0]["delta"].get("content", "")
                    full_response += delta_content

        log.debug(f"Assistant Full Response: {full_response}")

        # Append the LLM's response to the history
        history.append((input_text, full_response))

        return full_response, history  # Return the full response and the updated history
    else:
        error_message = f"Error: {response.status_code}"
        log.error(error_message)
        return error_message, history

def generate_tts(text):
    try:
        with NamedTemporaryFile(suffix=".wav", delete=False) as temp_wav:
            command = [
                "piper",
                "--model", "/app/piper_models/en_US-amy-low.onnx",
                "--output_file", temp_wav.name
            ]

            logging.info(f"Running Piper command: {' '.join(command)}")
            result = subprocess.run(command, input=text, text=True, capture_output=True)

            logging.info(f"Piper stdout: {result.stdout}")
            logging.error(f"Piper stderr: {result.stderr}")

            if os.path.getsize(temp_wav.name) == 0:
                logging.error("Generated audio file is empty.")
                return None

            return temp_wav.name

    except subprocess.CalledProcessError as e:
        logging.error(f"Error generating TTS: {e}")
        return None

def chat_with_tts(input_text, history):
    if not input_text.strip():
        return gr.update(value=""), gr.update(), gr.update(), gr.update(value="")  # Clear everything

    # Get the LLM's response and the updated history
    response_text, updated_history = query_llm(input_text, history)

    # Generate the audio using Piper
    audio_path = generate_tts(response_text)

    return response_text, audio_path, updated_history, ""  # Return the updated history and clear the textbox

with gr.Blocks(title="Voice chat with LM Studio") as interface:
    textbox = gr.Textbox(
        lines=1,  # Single-line input
        placeholder="Type your question here and press Enter to submit",
        show_label=True,
        label="Ask LM Studio"
    )
    history = gr.State()  # This keeps track of the conversation history

    output_text = gr.Textbox(label="LLM Response")
    audio_output = gr.Audio(type="filepath", autoplay=True, label="Generated Speech")

    # When the input is submitted, chat_with_tts is called and the history is updated
    textbox.submit(chat_with_tts, inputs=[textbox, history], outputs=[output_text, audio_output, history, textbox])

launch(interface)
