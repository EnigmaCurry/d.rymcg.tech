# Gradio

[Gradio](https://www.gradio.app/) is an open-source Python library
that enables creating customizable and shareable user interfaces for
machine learning models, making it easier to demo your applications
with minimal coding effort. It offers features like text inputs, image
uploads, data tables, and real-time feedback outputs, allowing users
to interactively explore ML models in their web browsers.

This configuration includes the following prebuilt apps:

 * [hello](gradio/hello) - a simple greeting app.
 * [chatbot](gradio/chatbot) - a streaming chatbot agent for a remote
   [LM Studio](https://lmstudio.ai/) instance.


## Config

```
make config
```

Choose a host name for the gradio instance:

```stdout
GRADIO_TRAEFIK_HOST: Enter the gradio domain name (eg. gradio.example.com)
: gradio.example.com
```

Choose the app to install:

```
? Choose the gradio app to install
  chatbot
> hello
```

Enable sentry authorization:

```
? Do you want to enable sentry authorization in front of this app (effectively making the entire site private)?  
  No
> Yes, with HTTP Basic Authentication
  Yes, with Oauth2
  Yes, with Mutual TLS (mTLS)
  
Enter the username for HTTP Basic Authentication
: private
Enter the passphrase for private (leave blank to generate a random passphrase)
: hunter2

> Would you like to create additional usernames (for the same access privilege)? No

> Would you like to export the usernames and cleartext passwords to the file passwords.json? No
```

## Install

```
make install wait
```

## Open

```
make open
```

or open your web browser to the `GRADIO_TRAEFIK_HOST` you set, and
enter the username and password when prompted.

## Chatbot app

If you choose the `chatbot` app in the config:

```
? Choose the gradio app to install  
> chatbot
  hello
```

You must set the remote URL for your LM Studio instance.

 * Download LM Studio on a machine that has a GPU.
   * The Docker server must have a network route to the LM Studio
     machine.
 * In LM studio, go to the `Developer` tab.
 * Enter a server port: `1234`.
 * Enable `Serve on Local Network`.
 * Enable `Verbose logging`.
 * Click `Start`.

Enter the URL in the config, using the LAN IP address of the machine
running LM Studio:

```
http://192.168.1.2:1234/v1/chat/completions
```

This will let Gradio use your LM Studio instance as its backend agent.
