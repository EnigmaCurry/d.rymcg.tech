from dia.model import Dia


model = Dia.from_pretrained("nari-labs/Dia-1.6B-0626", compute_dtype="float16")

# You should put the transcript of the voice you want to clone
# We will use the audio created by running simple.py as an example.
# Note that you will be REQUIRED TO RUN simple.py for the script to work as-is.
clone_from_text = "[S1] Dia is an open weights text to dialogue model. [S2] You get full control over scripts and voices. [S1] Wow. Amazing. (laughs) [S2] Try it now on Git hub or Hugging Face."

# For your custom needs, replace above with below and add your audio file to this directory:
# clone_from_text = "[S1] ... [S2] ... [S1] ... corresponding to your_audio_name.mp3"
# clone_from_audio = "your_audio_name.mp3"

# Text to generate
text_to_generate = "[S1] Dia is an open weights text to dialogue model. [S2] You get full control over scripts and voices. [S1] Wow. Amazing. (laughs) [S2] Try it now on Git hub or Hugging Face."

clone_from_audios = [f"simple_{i}.mp3" for i in range(10)]

texts = [clone_from_text + text_to_generate for _ in range(10)]

# It will only return the audio from the text_to_generate
output = model.generate(texts, audio_prompt=clone_from_audios, use_torch_compile=True, verbose=True, max_tokens=2000)

for i, o in enumerate(output):
    model.save_audio(f"voice_clone_{i}.mp3", o)
