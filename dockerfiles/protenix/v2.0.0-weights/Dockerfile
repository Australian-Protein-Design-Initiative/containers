# syntax=docker/dockerfile:1.4
# Build like:
#   docker buildx build -t protenix:v2.0.0-weights -f Dockerfile .
#
# GPU devel base with CUDA + cuDNN (nvcc needed for Protenix layer-norm JIT / DeepSpeed),
# following the Protenix install approach used in germinal/20260611-104bbdd7.
FROM nvidia/cuda:12.4.1-cudnn-devel-ubuntu22.04

LABEL org.opencontainers.image.source=https://github.com/Australian-Protein-Design-Initiative/containers
LABEL org.opencontainers.image.description="Protenix v2.0.0 with baked-in model weights"
LABEL org.australian-protein-design-initiative.image.platforms="linux/amd64"

ARG PROTENIX_VERSION=2.0.0
ARG DOWNLOAD_WEIGHTS=true
# protenix-v2 on the ByteDance CDN often returns 403 outside China
# (github.com/bytedance/Protenix/issues/296).
ARG PROTENIX_V2_WEIGHT_URL=https://huggingface.co/TMF001/protenix-v2-weights/resolve/main/protenix-v2.pt
ARG PROTENIX_STORE=/opt/protenix

ARG DEBIAN_FRONTEND=noninteractive
SHELL ["/bin/bash", "-lc"]

RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates \
    curl \
    wget \
    git \
    g++ \
    gcc \
    libc6-dev \
    make \
    postgresql \
    hmmer \
    kalign \
  && rm -rf /var/lib/apt/lists/*

ENV CUDA_HOME=/usr/local/cuda \
    LC_ALL=C.UTF-8 \
    LANG=C.UTF-8 \
    PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PIP_NO_CACHE_DIR=1 \
    CUTLASS_PATH=/opt/cutlass \
    PROTENIX_ROOT_DIR=/models/protenix \
    MAMBA_ROOT_PREFIX=/opt/conda \
    MAMBA_NO_BANNER=1

RUN curl -Ls https://micro.mamba.pm/api/micromamba/linux-64/latest | \
    tar -xvj -C /usr/local/bin --strip-components=1 bin/micromamba

# protenix>=0.6 requires Python>=3.11
ENV CONDA_ENV=protenix
RUN --mount=type=cache,target=/opt/conda/pkgs \
  micromamba create -y -n ${CONDA_ENV} python=3.11 && \
  micromamba clean -a -y

ENV PATH=/opt/conda/envs/protenix/bin:/opt/conda/bin:${PATH}

WORKDIR /app

RUN --mount=type=cache,target=/opt/conda/pkgs \
  --mount=type=cache,target=/root/.cache/pip \
  set -euxo pipefail; \
  micromamba run -n ${CONDA_ENV} pip install --upgrade pip wheel setuptools; \
  micromamba run -n ${CONDA_ENV} pip install "protenix==${PROTENIX_VERSION}"; \
  micromamba clean -a -y; \
  protenix pred --help >/dev/null

RUN git clone -b v3.5.1 https://github.com/NVIDIA/cutlass.git /opt/cutlass

# Protenix v2 expects checkpoints under ${PROTENIX_ROOT_DIR}/checkpoint and data caches under
# ${PROTENIX_ROOT_DIR}/common (see configs_inference.py / configs_data.py). Weights are baked in
# for read-only runtimes (e.g. Apptainer). Downloads preserve CDN path layout (checkpoint/*, common/*),
# use a build cache mount, then are copied into the image layer. Exposed at /models/protenix via symlinks.
RUN --mount=type=cache,target=/root/.cache/protenix \
  set -euxo pipefail; \
  if [ "${DOWNLOAD_WEIGHTS}" = "true" ]; then \
    python -c 'from protenix.web_service.dependency_url import URL; [print(u) for u in URL.values()]' | \
    while read -r url; do \
      relpath="${url#*://}"; relpath="${relpath#*/}"; \
      cache="/root/.cache/protenix/${relpath}"; \
      dest="${PROTENIX_STORE}/${relpath}"; \
      mkdir -p "$(dirname "${cache}")" "$(dirname "${dest}")"; \
      if [ ! -f "${cache}" ]; then \
        if ! wget -q -O "${cache}" "${url}"; then \
          if [ "$(basename "${url}")" = "protenix-v2.pt" ]; then \
            wget -q -O "${cache}" "${PROTENIX_V2_WEIGHT_URL}"; \
          else \
            rm -f "${cache}"; exit 8; \
          fi; \
        fi; \
      fi; \
      cp "${cache}" "${dest}"; \
    done; \
    chmod -R a+rX "${PROTENIX_STORE}"; \
    mkdir -p "${PROTENIX_ROOT_DIR}"; \
    ln -sfn "${PROTENIX_STORE}/checkpoint" "${PROTENIX_ROOT_DIR}/checkpoint"; \
    ln -sfn "${PROTENIX_STORE}/common" "${PROTENIX_ROOT_DIR}/common"; \
  else \
    echo "Skipping Protenix weight download (DOWNLOAD_WEIGHTS=${DOWNLOAD_WEIGHTS})"; \
  fi

CMD ["protenix"]
