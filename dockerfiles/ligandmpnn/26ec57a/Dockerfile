FROM python:3.11
LABEL org.opencontainers.image.source https://github.com/Australian-Protein-Design-Initiative/containers

ARG BRANCH=26ec57a

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y \
    git \
    wget \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

RUN mkdir -p /app && \
    cd /app && \
    git clone https://github.com/dauparas/LigandMPNN.git && \
    cd LigandMPNN && \
    pip3 install -r requirements.txt && \
    sed -i '1s;^;#!/usr/bin/env python\n;' /app/LigandMPNN/run.py && \
    chmod +x /app/LigandMPNN/run.py

WORKDIR /app/LigandMPNN

RUN /usr/bin/bash ./get_model_params.sh /app/LigandMPNN/model_params && \
    mkdir -p /models && \
    ln -s /app/LigandMPNN/model_params /models/LigandMPNN

# Download the HyperMPNN weights to /models/HyperMPNN
RUN mkdir -p /models/HyperMPNN && \
    cd /models/HyperMPNN && \
    wget https://github.com/meilerlab/HyperMPNN/raw/refs/heads/main/retrained_models/v48_002_epoch240_hyper.pt && \
    wget https://github.com/meilerlab/HyperMPNN/raw/refs/heads/main/retrained_models/v48_010_epoch300_hyper.pt && \
    wget https://github.com/meilerlab/HyperMPNN/raw/refs/heads/main/retrained_models/v48_020_epoch300_hyper.pt && \
    wget https://github.com/meilerlab/HyperMPNN/raw/refs/heads/main/retrained_models/v48_030_epoch300_hyper.pt

CMD ["python", "/app/LigandMPNN/run.py"]