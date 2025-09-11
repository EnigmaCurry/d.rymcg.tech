# ComfyUI

[ComfyUI](https://github.com/comfyanonymous/ComfyUI) is a modular
visual AI engine and application that lets you design and execute
advanced stable diffusion pipelines using a graph/nodes/flowchart
based interface. It can create images, videos, audio, and 3D models
(and can edit/inpaint images) starting from text, audio, or image
prompts.

## Config

```
make config
```

This will ask you to enter the domain name to use.
It automatically saves your responses into the configuration file
`.env_{DOCKER_CONTEXT}_{INSTANCE}`.

### Where to Store Models

By default, all models will be stored in the container's named Docker
volume. If you want to store them elsewhere on the host, you will be
asked to provide an absolute path on the host where you'd like them
saved.

The same is true for output files (e.g., images, video, audio): by
default they will be saved in the container's named Docker volume, but
you choose to save them elsewhere on the host.

The output and models paths on the host should be different from each
other.

### GPU hardware

ComfyUI is compatible with AMD, Nvidia, and Intel GPU architectures,
as well as being able to run on CPU only. This installer hasn't been
tested with Intel GPUs. If you encounter a problem installing ComfyUI
for an Intel GPU, please [submit an
issue](https://github.com/EnigmaCurry/d.rymcg.tech/issues/new/choose):
https://github.com/EnigmaCurry/d.rymcg.tech/issues/new/choose

### Authentication and Authorization

See [AUTH.md](../AUTH.md) for information on adding external authentication on
top of your app.

## Install

```
make install
```

The initial installation can take anywhere from a couple minutes up to
about 10 minutes, depending on your hardware and internet speed.

### Models

You can manually download models from sources like Huggingface and
place them into `/ComfyUI/models/<model_type>/` in the container, or
you can use the following Make targets:

```
make add-model
```

This will ask you for a model type and the URL to download the model,
and will place it in the appropriate subdirectory in the container.

TIP: when you start creating somethine from a template in ComfyUI, if
it requires models that you don't have installed, ComfyUI will show
what type of models they are and provide a "Copy URL" button. For each
model, copy the URL and run `make add-model` (be sure to select the
correct model_type for each model).

```
make remove-model
```

This will ask you for a model type and then you can select one of the
existing models of that type and it will be permanently deleted.

## Open

```
make open
```

This will automatically open the page in your web browser, and will
prefill the HTTP Basic Authentication password if you enabled it
(and chose to store it in `passwords.json`).

## Destroy

```
make destroy
```

This completely removes the container and deletes all its volumes.
