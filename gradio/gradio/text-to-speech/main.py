from config import *
log = get_logger(__name__)

def start_speech(text):
    return None

# Define the JavaScript function directly in the js argument
js = """
function speakText(text) {
    if (!text || text.trim() === '') {
        console.log("No text provided.");
        return;
    }

    const synth = window.speechSynthesis;
    const utterance = new SpeechSynthesisUtterance(text);

    function updateText() {
        // Find the div with id "component-2" and update its textarea
        const component = document.querySelector('#component-2 textarea');
        if (component) {
            component.value = text;  // Update the textarea with the spoken text
        } else {
            console.log("Component not found!");
        }
     }

    utterance.onstart = () => {
        console.log("Speech synthesis started.");
        updateText();
     }

    utterance.onend = () => {
        console.log("Speech synthesis ended.");
        updateText();
    };

    synth.speak(utterance);
}
"""

with gr.Blocks() as interface:
    inp = gr.Textbox(placeholder="Enter text to speak", show_label=False)
    out = gr.Textbox(show_label=False)
    btn = gr.Button("Speak")

    # Trigger when the button is clicked
    btn.click(fn=start_speech, inputs=inp, js=js)

    # Trigger when the Enter key is pressed in the input box
    inp.submit(fn=start_speech, inputs=inp, js=js)

log.warn("warning")
launch(interface)
