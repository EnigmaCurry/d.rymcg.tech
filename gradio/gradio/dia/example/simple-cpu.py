import torch

from dia.model import Dia


# Select device: CPU
device = torch.device("cpu")
print(f"Using device: {device}")

# Load model
model = Dia.from_pretrained(
    "nari-labs/Dia-1.6B-0626", compute_dtype="float32", device=device
)  # Float32 works better than float16 on CPU - you can also test with float16

text = "[S1] Dia is an open weights text to dialogue model. [S2] You get full control over scripts and voices. [S1] Wow. Amazing. (laughs) [S2] Try it now on Git hub or Hugging Face."

output = model.generate(text, use_torch_compile=False, verbose=True)

model.save_audio("simple.mp3", output)
