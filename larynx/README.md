# Larynx

[Larynx](https://github.com/rhasspy/larynx) is the text-to-speech engine for the
[Rhasspy](https://rhasspy.readthedocs.io/en/latest/) project. It runs as a
service, so you can send text and get a .wav file back in return.

Copy `.env-dist` to `.env` and edit the variables:

 * `LARYNX_TRAEFIK_HOST` - the domain name for the larynx service
 * `LARYNX_HTTP_AUTH` - the htpasswd encrypted username and password to access the service.

To generate the username / password run the following:

```
Run: docker run --rm -it httpd htpasswd -nB USERNAME
```

Replace `USERNAME` with the new username you wish to use. It will prompt to
enter the new password. Copy the encrypted output into your `.env` file as
`LARYNX_HTTP_AUTH`.


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
