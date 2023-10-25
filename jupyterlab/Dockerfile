ARG JUPYTERLAB_IMAGE
FROM jupyter/scipy-notebook
#FROM jupyter/minimal-notebook

USER root
RUN apt update -y && apt install less

USER jovyan
ENV port 8888
#RUN jupyter labextension install jupyterlab-emacskeys
RUN mkdir -p $HOME/.jupyter/lab/user-settings/@jupyterlab/apputils-extension
COPY themes.jupyterlab-settings $HOME/.jupyter/lab/user-settings/@jupyterlab/apputils-extension/
COPY commands.jupyterlab-settings $HOME/.jupyter/lab/user-settings/@jupyterlab/codemirror-extension/
COPY shortcuts.jupyterlab-settings $HOME/.jupyter/lab/user-settings/@jupyterlab/shortcuts-extension/
CMD jupyter lab --allow-root --no-browser --port ${port} --NotebookApp.password='argon2:$argon2id$v=19$m=10240,t=10,p=8$JdAN3fe9J45NvK/EPuGCvA$O/tbxglbwRpOFuBNTYrymAEH6370Q2z+eS1eF4GM6Do'

EXPOSE 8888

