# Larynx

[Larynx](https://github.com/rhasspy/larynx) is the text-to-speech engine for the
[Rhasspy](https://rhasspy.readthedocs.io/en/latest/) project. It runs as a
service, so you can send text and get a .wav file back in return.

FYI: last time I tried this, it was broken and there were no voices
available. If you know how to fix it, please send a PR.

Run `make config` to configure the larynx domain name and
username/password.

Run `make install` to deploy the app.

Run `make open` to open the page in your browser.

Larynx serves a web browser test page, but you can also use the service API
directly:

```
curl https://larynx.example.com/api/tts \
  -u larynx:password \
  -G \
  --data-urlencode 'text=this is a test' \
  --data-urlencode 'voice=en-us/mary_ann-glow_tts' \
  --data-urlencode 'vocoder=hifi_gan/universal_large' \
  --data-urlencode 'denoiserStrength=0.002' \
  --data-urlencode 'noiseScale=0.333' \
  --data-urlencode 'lengthScale=1' \
  --data-urlencode 'textLanguage=' \
  --data-urlencode 'inlinePronunciations=true' \
  --compressed | aplay -r 22050 -c 1 -f S16_LE
```
