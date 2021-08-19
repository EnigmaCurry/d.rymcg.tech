FROM jupyter/scipy-notebook

USER root
RUN apt update -y && apt install less

USER jovyan
ENV port 10000
# RUN jupyter labextension install jupyterlab-emacskeys && \
#     mkdir -p $HOME/.jupyter/lab/user-settings/@jupyterlab/apputils-extension
COPY themes.jupyterlab-settings $HOME/.jupyter/lab/user-settings/@jupyterlab/apputils-extension/
COPY commands.jupyterlab-settings $HOME/.jupyter/lab/user-settings/@jupyterlab/codemirror-extension/
COPY shortcuts.jupyterlab-settings $HOME/.jupyter/lab/user-settings/@jupyterlab/shortcuts-extension/
CMD jupyter lab --allow-root --no-browser --port ${port}

RUN git clone https://github.com/syl20bnr/spacemacs $HOME/.emacs.d && \
    git -C $HOME/.emacs.d/ checkout develop && \
    git clone https://github.com/EnigmaCurry/emacs $HOME/git/vendor/enigmacurry/emacs && \
    ln -s $HOME/git/vendor/enigmacurry/emacs/spacemacs.el $HOME/.spacemacs
