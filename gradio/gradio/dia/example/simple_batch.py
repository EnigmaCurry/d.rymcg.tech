from dia.model import Dia


model = Dia.from_pretrained("nari-labs/Dia-1.6B-0626", compute_dtype="float16")

text = "[S1] Dia is an open weights text to dialogue model. [S2] You get full control over scripts and voices. [S1] Wow. Amazing. (laughs) [S2] Try it now on Git hub or Hugging Face."
texts = [text for _ in range(10)]

output = model.generate(texts, use_torch_compile=True, verbose=True, max_tokens=1500)

for i, o in enumerate(output):
    model.save_audio(f"simple_{i}.mp3", o)
