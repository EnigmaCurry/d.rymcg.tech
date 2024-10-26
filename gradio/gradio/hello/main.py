import sys
import gradio as gr


def greet(name, intensity):
    return "Hello, " + name + "!" * int(intensity)


if __name__ == "__main__":
    demo = gr.Interface(
        fn=greet,
        inputs=["text", "slider"],
        outputs=["text"],
    )
    print("Launching gradio interface ...")
    sys.stdout.flush()
    demo.launch(server_name="0.0.0.0", server_port=7860)
