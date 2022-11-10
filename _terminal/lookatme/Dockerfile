FROM python:3.11
## Find latest version: https://github.com/d0c-s4vage/lookatme/releases
ARG LOOKATME_VERSION=v2.5.0
## https://github.com/d0c-s4vage/lookatme.contrib.qrcode/tags
ARG LOOKATME_QRCODE_VERSION=v2.2.0
## https://github.com/d0c-s4vage/lookatme.contrib.image_ueberzug/tags
ARG LOOKATME_IMAGE_UEBERZUG_VERSION=v1.1.0
RUN pip install https://github.com/d0c-s4vage/lookatme/archive/refs/tags/${LOOKATME_VERSION}.zip && \
    pip install https://github.com/d0c-s4vage/lookatme.contrib.qrcode/archive/refs/tags/${LOOKATME_QRCODE_VERSION}.zip && \
    pip install https://github.com/d0c-s4vage/lookatme.contrib.image_ueberzug/archive/refs/tags/${LOOKATME_IMAGE_UEBERZUG_VERSION}.zip

CMD lookatme
