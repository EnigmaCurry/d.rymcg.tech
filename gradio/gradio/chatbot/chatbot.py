from config import *
import markdown
import requests
import threading
from fastapi import FastAPI, Request
import httpx
import multiprocessing

from proxy import proxy_request
from prompts import CHARACTER_PROMPTS, OBJECTIVE_PROMPTS, STATIC_PROMPT
from voices import VOICES
from css import CSS
from script import PAGE_SCRIPT
from morse import (
    process_markdown_morse_code,
    extract_morse_code,
    generate_morse_code_audio,
)

log = get_logger(__name__)

CHATBOT_API = get_config("CHATBOT_API")
MODELS = get_config("CHATBOT_MODELS").split(",")


# Function to query LLM with a preamble and history, limiting context to the last 3 exchanges
def query_llm(
    input_text,
    history=None,
    model=MODELS[0],
    character_prompt="shakespearean",
    objective="tutor",
):
    if history is None:
        history = []

    log.debug(f"User Input: {input_text}")

    # Limit the history to the last 3 exchanges to avoid over-sensitivity
    context_length = 3
    truncated_history = history[-context_length:]

    # Start the conversation with the selected system prompt
    preamble_prompt = (
        STATIC_PROMPT
        + OBJECTIVE_PROMPTS[objective]
        + " "
        + CHARACTER_PROMPTS[character_prompt]
    )
    messages = [{"role": "system", "content": preamble_prompt}]

    # Append the user and assistant messages from the conversation history
    messages += [
        (
            {"role": "user", "content": user_message}
            if i % 2 == 0
            else {"role": "assistant", "content": assistant_message}
        )
        for i, (user_message, assistant_message) in enumerate(truncated_history)
    ]

    # Add the current user input to the conversation
    messages.append({"role": "user", "content": f"Current question: {input_text}"})

    if model == None:
        raise AssertionError("Model cannot be None.")
    payload = {"model": model, "messages": messages, "stream": True}

    log.debug(
        "Sending message to LM Studio: {payload}".format(
            payload=json.dumps(payload).replace("'", "\\'")
        )
    )
    response = requests.post(CHATBOT_API, json=payload, stream=True)

    if response.status_code == 200:
        full_response = ""
        for line in response.iter_lines():
            if line:
                line_str = line.decode("utf-8")
                if line_str.strip() == "data: [DONE]":
                    break
                if line_str.startswith("data:"):
                    data_json = line_str[6:]
                    data = json.loads(data_json)
                    delta_content = data["choices"][0]["delta"].get("content", "")
                    full_response += delta_content
        log.debug(f"Assistant Full Response: {full_response}")
        full_response = process_markdown_morse_code(full_response)

        history.append((input_text, full_response))
        return full_response, history
    else:
        error_message = f"Error: {response.status_code}"
        log.error(error_message)
        return error_message, history


def generate_tts(text, voice_model):
    try:
        with NamedTemporaryFile(suffix=".wav", delete=False) as temp_wav:
            command = ["piper", "--model", voice_model, "--output_file", temp_wav.name]

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
        llm_response_html = markdown.markdown(llm_response, extensions=["fenced_code"])
        user_msg = user_msg.replace("\n", "<br/>")
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
    # Check if the textarea is blank; if so, keep the submit button disabled
    submit_button_interactive = gr.update(interactive=False)
    reset_button_interactive = gr.update(interactive=False)
    return (
        "",  # Chat history
        gr.update(value=None, visible=False),  # Audio output
        [],  # History state
        gr.update(value=""),  # Textbox cleared
        gr.update(visible=True),  # Voice dropdown remains visible
        submit_button_interactive,  # Submit button stays disabled if no input
        reset_button_interactive,  # Reset button disabled after reset
    )


# Function to validate input and update reset and submit button interactivity
def check_input_validity(input_text, history):
    # Reset button should be interactive if there is history or the input is not empty
    reset_button_interactive = bool(history) or bool(input_text.strip())
    # Submit button should only be interactive if there is valid input
    submit_button_interactive = bool(input_text.strip())
    return gr.update(interactive=submit_button_interactive), gr.update(
        interactive=reset_button_interactive
    )


def chat(
    input_text,
    history,
    model,
    speech_synthesis_enabled,
    voice,
    character_prompt,
    objective,
):
    if not input_text.strip():
        # Disable the submit button if input is invalid
        return (
            gr.update(value=""),
            gr.update(),
            gr.update(),
            gr.update(value=""),
            gr.update(interactive=False),
            gr.update(interactive=False),
        )

    submit_button_interactive = gr.update(interactive=False)
    reset_button_interactive = gr.update(interactive=False)

    response_text, updated_history = query_llm(
        input_text, history, model, character_prompt, objective
    )

    audio_path = None
    audio_visible = False
    if objective == "telegrapher":
        clean_text_for_morse_code = "\n\n".join(extract_morse_code(response_text))
        audio_path = generate_morse_code_audio(clean_text_for_morse_code)
    elif speech_synthesis_enabled:
        clean_text_for_tts = "... " + clean_markdown(response_text)
        audio_path = (
            generate_tts(clean_text_for_tts, VOICES[voice]) if voice in VOICES else None
        )
        audio_visible = True if audio_path else False

    chat_history_html = format_chat_history(updated_history)

    # Enable buttons again after processing
    submit_button_interactive = gr.update(interactive=True)
    reset_button_interactive = gr.update(interactive=True)

    audio_block = gr.update(value=audio_path, visible=audio_visible)
    return (
        gr.update(value=chat_history_html),
        audio_block,
        updated_history,
        "",
        submit_button_interactive,
        reset_button_interactive,
    )


with gr.Blocks(title="Voice chat with LM Studio", css=CSS) as interface:
    with gr.Row(elem_id="input-box"):
        textbox = gr.Textbox(
            lines=1,
            placeholder="What's on your mind?",
            show_label=False,
            elem_id="input-textarea",
        )
        with gr.Column(elem_id="submit-wrapper"):
            submit_button = gr.Button(
                "Submit", elem_id="submit-btn", interactive=False
            )  # Initially non-interactive

    history = gr.State()  # Stores conversation history

    # Chat history display using HTML
    chat_history = gr.HTML(label="Chat History")

    # Collapsible settings section
    with gr.Accordion("Settings", open=False):

        def show_model_dropdown(objective=None):
            if len(MODELS) <= 1:
                return gr.Dropdown(
                    label="Model (be patient when switching)",
                    choices=MODELS,
                    value=MODELS[0],
                    visible=False,
                )
            else:
                return gr.Dropdown(
                    label="Model (be patient when switching)",
                    choices=MODELS,
                    value=MODELS[0],
                    visible=True,
                )

        def show_voice_dropdown(objective=None):
            if objective == "telegrapher":
                return gr.Dropdown(visible=False)
            else:
                return gr.Dropdown(
                    label="Voice",
                    choices=list(VOICES.keys()),
                    value="en_US-john-medium",
                    visible=True,
                )

        def show_speech_synthesis_toggle(objective=None):
            if objective == "telegrapher":
                return gr.Checkbox(visible=False, value=False)
            else:
                return gr.Checkbox(label="Speech Synthesis", value=True, visible=True)

        def show_character_prompt(objective=None):
            if objective == "telegrapher":
                return gr.Dropdown(visible=False)
            else:
                return gr.Dropdown(
                    label="Character prompt",
                    choices=list(CHARACTER_PROMPTS.keys()),
                    value="shakespearean",
                )

        objective_dropdown = gr.Dropdown(
            label="Objective", choices=list(OBJECTIVE_PROMPTS.keys()), value="tutor"
        )
        model_dropdown = show_model_dropdown()
        character_prompt_dropdown = show_character_prompt()
        speech_synthesis_toggle = show_speech_synthesis_toggle()
        voice_dropdown = show_voice_dropdown()

        objective_dropdown.input(
            fn=show_voice_dropdown, inputs=objective_dropdown, outputs=voice_dropdown
        )
        objective_dropdown.input(
            fn=show_speech_synthesis_toggle,
            inputs=objective_dropdown,
            outputs=speech_synthesis_toggle,
        )
        objective_dropdown.input(
            fn=show_character_prompt,
            inputs=objective_dropdown,
            outputs=character_prompt_dropdown,
        )
        objective_dropdown.input(
            fn=show_model_dropdown,
            inputs=objective_dropdown,
            outputs=model_dropdown,
        )

        def toggle_voice_dropdown(speech_synthesis_enabled):
            return gr.update(visible=speech_synthesis_enabled)

        speech_synthesis_toggle.change(
            toggle_voice_dropdown,
            inputs=speech_synthesis_toggle,
            outputs=voice_dropdown,
        )

    # Audio output for generated speech
    audio_output = gr.Audio(
        type="filepath", autoplay=True, label="Generated Speech", visible=False
    )

    # Buttons to reset chat
    reset_button = gr.Button("Reset", interactive=False)  # Initially non-interactive

    # Reset chat
    reset_button.click(
        reset_chat,
        outputs=[
            chat_history,
            audio_output,
            history,
            textbox,
            speech_synthesis_toggle,
            voice_dropdown,
            submit_button,
            reset_button,
        ],
    )

    # Validate input and update the submit button and reset button interactivity
    textbox.change(
        check_input_validity,
        inputs=[textbox, history],
        outputs=[submit_button, reset_button],
    )

    # Submit button triggers the chat
    submit_button.click(
        chat,
        inputs=[
            textbox,
            history,
            model_dropdown,
            speech_synthesis_toggle,
            voice_dropdown,
            character_prompt_dropdown,
            objective_dropdown,
        ],
        outputs=[
            chat_history,
            audio_output,
            history,
            textbox,
            submit_button,
            reset_button,
        ],
    )

    # Submit on Enter key
    textbox.submit(
        chat,
        inputs=[
            textbox,
            history,
            model_dropdown,
            speech_synthesis_toggle,
            voice_dropdown,
            character_prompt_dropdown,
            objective_dropdown,
        ],
        outputs=[
            chat_history,
            audio_output,
            history,
            textbox,
            submit_button,
            reset_button,
        ],
    )


def run_gradio():
    launch(interface)
