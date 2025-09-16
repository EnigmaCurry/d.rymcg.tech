set -e

source get_audio.sh

echo 'Hello from a pipe!' | gradio_tts
