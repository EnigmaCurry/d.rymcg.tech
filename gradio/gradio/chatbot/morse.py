import wave
import numpy as np
import re
from MorseCodePy import encode as morse_encode, decode as morse_decode
from tempfile import NamedTemporaryFile


def process_markdown_morse_code(md_text):
    def replace_morse_block(match):
        morse_text = match.group(1)
        return "```morse\n" + morse_encode(morse_text, language="english") + "\n```"

    # Regex pattern to find code blocks of type 'morse'
    morse_block_pattern = "```morse\n(.*?)\n```"

    # Substitute matched morse code blocks with the translated text
    return re.sub(morse_block_pattern, replace_morse_block, md_text, flags=re.DOTALL)


def extract_morse_code(markdown_text):
    # Regex pattern to find all "morse" code blocks
    morse_block_pattern = r"```morse\n(.*?)\n```"

    # Find all matches and return the contents as a list
    morse_contents = re.findall(morse_block_pattern, markdown_text, flags=re.DOTALL)

    return morse_contents


# Morse timing constants
DOT_LENGTH_MS = 1200  # milliseconds (1.2 seconds at 1 WPM)
FREQUENCY = 700  # Hertz (tone frequency)
SAMPLE_RATE = 44100  # Samples per second

# Define morse code symbols for reference
MORSE_CODE_DICT = {".": "dot", "-": "dash", " ": "space"}


def get_morse_timing(wpm, dot_length):
    dot_duration = dot_length / wpm
    dash_duration = 3 * dot_duration
    space_duration = 7 * dot_duration
    return dot_duration, dash_duration, space_duration


def generate_sine_wave(frequency, duration_ms, sample_rate=SAMPLE_RATE):
    """Generate a sine wave for a given frequency and duration in ms."""
    duration_sec = duration_ms / 1000
    t = np.linspace(0, duration_sec, int(sample_rate * duration_sec), False)
    wave_data = 0.5 * np.sin(2 * np.pi * frequency * t)
    return (wave_data * 32767).astype(np.int16)


def generate_morse_code_audio(
    morse_code_text, wpm=20, tone=FREQUENCY, dot_length=DOT_LENGTH_MS
):
    dot_duration, dash_duration, space_duration = get_morse_timing(wpm, dot_length)

    audio_frames = []
    silent_frame = np.zeros(int(SAMPLE_RATE * dot_duration / 1000), dtype=np.int16)

    for symbol in morse_code_text:
        if symbol == ".":
            audio_frames.append(generate_sine_wave(tone, dot_duration))
        elif symbol == "-":
            audio_frames.append(generate_sine_wave(tone, dash_duration))
        elif symbol == " ":
            audio_frames.append(silent_frame * 7)  # Add a longer silence between words
        audio_frames.append(silent_frame)  # Short silence between symbols

    if not audio_frames:
        print("Warning: No Morse code symbols found; returning empty audio.")
        return None

    # Concatenate all frames into a single array
    audio_waveform = np.concatenate(audio_frames)

    # Use NamedTemporaryFile to create a temporary .wav file
    with NamedTemporaryFile(delete=False, suffix=".wav") as temp_file:
        with wave.open(temp_file.name, "wb") as wav_file:
            wav_file.setnchannels(1)  # Mono
            wav_file.setsampwidth(2)  # 2 bytes per sample
            wav_file.setframerate(SAMPLE_RATE)  # 44100 samples per second
            wav_file.writeframes(audio_waveform.tobytes())

        return temp_file.name


# Example usage
# morse_text = "... --- ..."
# generate_morse_code_audio(morse_text, wpm=10)
