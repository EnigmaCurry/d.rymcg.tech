from config import *
import markdown  # For converting markdown to HTML
import requests

log = get_logger(__name__)

VOICES = {voice: f"/app/piper_models/{voice}.onnx" for voice in ["en_US-lessac-medium", "en_US-danny-low", "en_US-amy-low", "en_US-john-medium"]}

OBJECTIVE_PROMPTS = {
    "tutor": """
You are an assistant that provides helpful, friendly, and informative responses. Your goal is to assist with coding, math, problem-solving, and general knowledge.
"""
    }
    
CHARACTER_PROMPTS = {
    "drill-seargent": """Your linguistic traits are that of Drill seargent who speaks extremely conscisely and straight to the point and will berate you for any mistakes. Coding is life and death.
                      """,
    "shakespearean": """Your linguistic traits are that of a Shakespearean thespian and rennaissance teacher who uses dry wit and humor as a form of education. You always answer with rhyme and meter.
                     """,
    "teacher": """You are an expert programmer in dozens of computer languages. You enjoy teaching and you are eager to share with students who bring thoughtful questions to you. You should use language that offers consise description, and polite professional exchange.
               """,
    "ELI5": """You explain things in simple concepts and basic english, like to a five year old.
            """,
    "asimov": """You are Isaac Asimov and you explain all technical concepts through fictional dialog sequences written for two actors : Robot and Human.
              """
}

# Function to query LLM with a preamble and history, limiting context to the last 3 exchanges
def query_llm(input_text, history=None, model="codestral-22b-v0.1", character_prompt="shakespearean-tutor"):
    if history is None:
        history = []

    log.debug(f"User Input: {input_text}")

    # Limit the history to the last 3 exchanges to avoid over-sensitivity
    context_length = 3
    truncated_history = history[-context_length:]

    # Start the conversation with the selected system prompt
    preamble_prompt = OBJECTIVE_PROMPTS['tutor'] + CHARACTER_PROMPTS[character_prompt]
    messages = [{"role": "system", "content": preamble_prompt}]

    # Append the user and assistant messages from the conversation history
    messages += [{"role": "user", "content": user_message} if i % 2 == 0 else {"role": "assistant", "content": assistant_message}
                 for i, (user_message, assistant_message) in enumerate(truncated_history)]

    # Add the current user input to the conversation
    messages.append({"role": "user", "content": f"Current question: {input_text}"})

    payload = {
        "model": model,
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

        history.append((input_text, full_response))
        return full_response, history
    else:
        error_message = f"Error: {response.status_code}"
        log.error(error_message)
        return error_message, history

# Function to generate TTS (unchanged)
def generate_tts(text, voice_model):
    try:
        with NamedTemporaryFile(suffix=".wav", delete=False) as temp_wav:
            command = [
                "piper",
                "--model", voice_model,
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

# Function to format chat history with chat bubble styling and markdown rendering
def format_chat_history(history):
    history_html = "<div id='history'>"
    for user_msg, llm_response in reversed(history):  # Most recent at the top
        # Convert the LLM response from markdown to HTML, including code blocks
        llm_response_html = markdown.markdown(llm_response, extensions=['fenced_code'])

        history_html += f"""
            <div class="message llm">
                <div class="llm_response">{llm_response_html}</div>
            </div>
            <div class="message user">
                <div class="user_query">{user_msg}</div>
            </div>
        """
    history_html += "</div>"
    return history_html

# Reset function
def reset_chat():
    return "", gr.update(value=None, visible=False), [], gr.update(value=""), gr.update(visible=True), gr.update(js="stopAudioAndFocus()")

# Function to validate input
def check_input_validity(input_text):
    return gr.update(visible=bool(input_text.strip()))  # Show button only if valid input

# Set global CSS with chat bubble style and scrollable chat history
css = """
#history {
    max-height: 300px;
    overflow-y: auto;
    padding: 10px;
    margin-bottom: 15px;
    border: 1px solid #ccc;
    border-radius: 8px;
}

#history .message {
    margin: 10px 0;
}

#history .message.user {
    text-align: right;
}

#history .message.llm {
    text-align: left;
}

#history .message .user_query {
    display: inline-block;
    max-width: 70%;
    background-color: rgb(174, 200, 148);
    color: black;
    padding: 10px;
    border-radius: 15px;
    margin-left: 10px;
}

#history .message .llm_response {
    display: inline-block;
    max-width: 90%;
    background-color: #ffe4c4;
    color: black;
    padding: 10px;
    border-radius: 15px;
    margin-right: 10px;
}

gradio-app {
    background-color: #625d5d !important;
}

/* Dark Mode Specific Styles */
@media (prefers-color-scheme: dark) {
    #history .message .llm_response *,
    #history .message .llm_response pre code,
    #history .message .llm_response pre,
    #history .message .llm_response p {
        color: black !important;
    }
}
"""

def chat_with_tts(input_text, history, model, speech_synthesis_enabled, voice, character_prompt):
    if not input_text.strip():
        return gr.update(value=""), gr.update(), gr.update(), gr.update(value="")  # Clear everything

    # Hide the submit button when submitting
    submit_button_visibility = gr.update(visible=False)

    response_text, updated_history = query_llm(input_text, history, model, character_prompt)
    clean_text_for_tts = "... " + clean_markdown(response_text)
    audio_path = None
    audio_visible = False
    if speech_synthesis_enabled:
        audio_path = generate_tts(clean_text_for_tts, VOICES[voice]) if voice in VOICES else None
        audio_visible = True if audio_path else False

    chat_history_html = format_chat_history(updated_history)

    # Show the submit button again once the response is received
    submit_button_visibility = gr.update(visible=True)

    return (
        gr.update(value=chat_history_html),
        gr.update(value=audio_path, visible=audio_visible),
        updated_history,
        "",
        submit_button_visibility
    )

# Build the Gradio interface
with gr.Blocks(title="Voice chat with LM Studio", css=css) as interface:
    textbox = gr.Textbox(
        lines=1,
        placeholder="Type your question and then press Enter.",
        show_label=True,
        label="What's on your mind?"
    )
    history = gr.State()  # Stores conversation history

    # Chat history display using HTML
    chat_history = gr.HTML(label="Chat History")

    # Collapsible settings section
    with gr.Accordion("Settings", open=False):
        model_dropdown = gr.Dropdown(label="Model (be patient when switching)", choices=MODELS, value=MODELS[0])
        character_prompt_dropdown = gr.Dropdown(label="Character prompt", choices=list(CHARACTER_PROMPTS.keys()), value="shakespearean-tutor")
        speech_synthesis_toggle = gr.Checkbox(label="Speech Synthesis", value=True)
        voice_dropdown = gr.Dropdown(label="Voice", choices=list(VOICES.keys()), value="en_US-john-medium", visible=True)
      
    # Audio output for generated speech
    audio_output = gr.Audio(type="filepath", autoplay=True, label="Generated Speech", visible=False)

    # Buttons to submit and reset chat
    submit_button = gr.Button("Submit", visible=False)
    reset_button = gr.Button("Reset")

    # Toggle visibility of the voice dropdown
    def toggle_voice_dropdown(speech_synthesis_enabled):
        return gr.update(visible=speech_synthesis_enabled)

    speech_synthesis_toggle.change(toggle_voice_dropdown, inputs=speech_synthesis_toggle, outputs=voice_dropdown)

    # Show submit button when input is valid
    textbox.change(check_input_validity, inputs=textbox, outputs=submit_button)

    # Reset chat
    reset_button.click(reset_chat, outputs=[chat_history, audio_output, history, textbox, voice_dropdown])

    # Submit button triggers the chat
    submit_button.click(chat_with_tts, inputs=[textbox, history, model_dropdown, speech_synthesis_toggle, voice_dropdown, character_prompt_dropdown],
                        outputs=[chat_history, audio_output, history, textbox, submit_button])

    # Submit on Enter key
    textbox.submit(chat_with_tts, inputs=[textbox, history, model_dropdown, speech_synthesis_toggle, voice_dropdown, character_prompt_dropdown],
                   outputs=[chat_history, audio_output, history, textbox, submit_button])

launch(interface)
