FROM ubuntu:24.04
# FROM pytorch/pytorch:2.7.1-cuda11.8-cudnn9-devel
# FROM nvcr.io/nvidia/cuda:11.8.0-cudnn8-devel-ubuntu22.04
LABEL org.opencontainers.image.source=https://github.com/Australian-Protein-Design-Initiative/containers
LABEL org.australian-protein-design-initiative.image.platforms="linux/amd64"

ARG GIT_REF=v2.1.1
ARG CCD_URL="https://huggingface.co/boltz-community/boltz-1/resolve/main/ccd.pkl"
ARG MOL_URL="https://huggingface.co/boltz-community/boltz-2/resolve/main/mols.tar"
ARG BOLTZ2_WEIGHTS_URL="https://huggingface.co/boltz-community/boltz-2/resolve/main/boltz2_conf.ckpt"
ARG BOLTZ2_AFFINITY_WEIGHTS_URL="https://huggingface.co/boltz-community/boltz-2/resolve/main/boltz2_aff.ckpt"

ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    gfortran \
    cmake \
    pkg-config \
    curl \
    git \
    adduser \
    libpng-dev \
    python3-pip \
    python3-dev \
    libpng-dev \
    libopenblas-dev \
    liblapack-dev \
    && rm -rf /var/lib/apt/lists/*

RUN addgroup --system boltz && adduser --system --ingroup boltz boltz

WORKDIR /app

RUN git clone https://github.com/jwohlwend/boltz.git boltz && \
    cd boltz && \
    git checkout ${GIT_REF} && \
    chown -R boltz:boltz /app

WORKDIR /app/boltz

# Pre-cache boltz-2 models
ENV BOLTZ_CACHE=/app/boltz/cache
RUN mkdir -p ${BOLTZ_CACHE} && \
    cd ${BOLTZ_CACHE} && \
    curl -L -o ccd.pkl ${CCD_URL} && \
    curl -L -o mols.tar ${MOL_URL} && \
    tar -xvf mols.tar && \
    rm mols.tar && \
    curl -L -o boltz2_conf.ckpt ${BOLTZ2_WEIGHTS_URL} && \
    curl -L -o boltz2_aff.ckpt ${BOLTZ2_AFFINITY_WEIGHTS_URL}

ENV PIP_BREAK_SYSTEM_PACKAGES=1
RUN pip install --no-cache-dir .

USER boltz

CMD ["boltz"]