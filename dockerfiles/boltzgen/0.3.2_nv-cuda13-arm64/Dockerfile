# syntax=docker/dockerfile:1

# BoltzGen for arm64 / aarch64 + Blackwell (GB10 / GB100) with CUDA 13.3
#
# Build like:
#   docker buildx build --platform linux/arm64 -t boltzgen:arm64-blackwell .
# Or natively on an arm64 host:
#   docker build -t boltzgen:arm64-blackwell .
#
# Run like:
#   mkdir -p workdir models
#   docker run --rm --gpus all \
#     -v $(pwd)/workdir:/workspace \
#     -v $(pwd)/models:/models/boltzgen \
#     -v $(pwd)/example:/example \
#     boltzgen:arm64-blackwell \
#     run /example/vanilla_protein/1g13prot.yaml \
#     --output /workspace/out --protocol protein-anything --num_designs 2

ARG GIT_REPO=https://github.com/HannesStark/boltzgen.git
ARG GIT_REF=v0.3.2

FROM nvidia/cuda:13.3.0-cudnn-devel-ubuntu22.04

LABEL org.australian-protein-design-initiative.image.platforms="linux/arm64"

LABEL org.opencontainers.image.source="https://github.com/Australian-Protein-Design-Initiative/containers" \
      org.opencontainers.image.title="BoltzGen (arm64 / Blackwell)" \
      org.opencontainers.image.description="BoltzGen protein design for arm64 / Blackwell (GB10/GB100) — CUDA 13.3, PyTorch cu130" \
      org.opencontainers.image.version="0.3.2" \
      org.opencontainers.image.revision="v0.3.2" \
      org.opencontainers.image.licenses="MIT" \
      org.opencontainers.image.vendor="Australian Protein Design Initiative" \
      org.opencontainers.image.base.name="docker.io/nvidia/cuda:13.3.0-cudnn-devel-ubuntu22.04" \
      org.opencontainers.image.base.digest="sha256:a437eea362ece5c1c92ae8460f95b450c41f974d3f0a65b02b3e1a462b5b32f8" \
      org.opencontainers.image.usage="docker run --rm --gpus all -v \$(pwd)/workdir:/workspace boltzgen:arm64-blackwell run <input.yaml> --output /workspace/out"

ENV DEBIAN_FRONTEND=noninteractive \
    PIP_NO_CACHE_DIR=1 \
    PYTHONNOUSERSITE=1 \
    PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    CUDA_HOME=/usr/local/cuda \
    # cu130 = compiled against CUDA 13.0, forward-compatible with CUDA 13.3
    PIP_EXTRA_INDEX_URL=https://download.pytorch.org/whl/cu130 \
    HF_HOME=/models/boltzgen

# System packages: software-properties-common first for add-apt-repository,
# then deadsnakes PPA for Python 3.11 on Ubuntu 22.04 arm64.
RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt,sharing=locked \
    apt-get update && apt-get install -y --no-install-recommends \
        software-properties-common \
        curl \
    && add-apt-repository -y ppa:deadsnakes/ppa \
    && apt-get update && apt-get install -y --no-install-recommends \
        python3.11 \
        python3.11-dev \
        python3.11-venv \
        build-essential \
        git \
        cmake \
        pkg-config \
        libffi-dev \
        libssl-dev \
        libxml2-dev \
        libxslt-dev \
        libgl1 \
        libhdf5-dev \
        libboost-all-dev

RUN update-alternatives --install /usr/bin/python python /usr/bin/python3.11 1 && \
    update-alternatives --install /usr/bin/python3 python3 /usr/bin/python3.11 1 && \
    curl -sS https://bootstrap.pypa.io/get-pip.py | python3.11 && \
    python3.11 -m pip install --upgrade pip setuptools setuptools_scm wheel

# Re-declare build args after FROM (ARGs before FROM are consumed by the FROM itself)
ARG GIT_REPO
ARG GIT_REF

# Clone and patch cu12 → cu13 cuequivariance deps so they match the CUDA 13.x runtime.
# The boltzgen Python code imports cuequivariance_torch (pure Python); cu12/cu13 ops
# packages are backends discovered at runtime — the swap is transparent.
RUN git clone ${GIT_REPO} /app && \
    cd /app && \
    git checkout ${GIT_REF} && \
    sed -i \
        -e 's/cuequivariance_ops_torch_cu12/cuequivariance_ops_torch_cu13/g' \
        -e 's/cuequivariance_ops_cu12/cuequivariance_ops_cu13/g' \
        pyproject.toml

WORKDIR /app

RUN --mount=type=cache,target=/root/.cache/pip \
    pip install -e /app

RUN --mount=type=cache,target=/root/.cache/pip \
    pip install jupyterlab

# Download all model weights (~6 GB) into the image at build time.
# Skip this layer and mount weights at runtime by using --build-arg DOWNLOAD_WEIGHTS=false
# (then pass -v /path/to/weights:/models/boltzgen at docker run time).
ARG DOWNLOAD_WEIGHTS=true
RUN if [ "${DOWNLOAD_WEIGHTS}" = "true" ]; then \
        mkdir -p /models/boltzgen && \
        boltzgen download all --cache /models/boltzgen --force_download; \
    fi

# Create non-root runtime user
ARG USERNAME=boltzgen
ARG USER_UID=1000
ARG USER_GID=1000

RUN groupadd --gid ${USER_GID} ${USERNAME} && \
    useradd --uid ${USER_UID} --gid ${USER_GID} --create-home --shell /bin/bash ${USERNAME} && \
    mkdir -p /models/boltzgen && \
    chown -R ${USER_UID}:${USER_GID} /models

RUN cat > /README.md <<'READMEEOF'
# BoltzGen — arm64 / Blackwell (GB10 / GB100) Container

**Source repository:** https://github.com/HannesStark/boltzgen (tag: v0.3.2)
**Container source:** https://github.com/Australian-Protein-Design-Initiative/containers

BoltzGen is a protein design tool that uses a diffusion model to generate novel
protein structures. This image is built for arm64 / aarch64 + NVIDIA Blackwell
(GB10 / GB100) GPUs, using CUDA 13.3 and PyTorch cu130.

## Key differences from the x86_64 image

- Base: `nvidia/cuda:13.3.0-cudnn-devel-ubuntu22.04` (arm64)
- PyTorch from the `cu130` wheel index
- `cuequivariance_ops_cu13` / `cuequivariance_ops_torch_cu13` replace the
  `cu12` variants so CUDA kernels match the 13.x runtime
- Model weights are NOT baked in by default; mount or download at runtime

## External data / model weights (~6 GB)

Weights are downloaded from Hugging Face on first run into `$HF_HOME`
(default: `/models/boltzgen`).  Mount a host directory to cache them:

```bash
mkdir -p models
docker run --rm --gpus all \
  -v $(pwd)/models:/models/boltzgen \
  boltzgen:arm64-blackwell \
  download all
```

To bake weights into the image at build time:

```bash
docker build --build-arg DOWNLOAD_WEIGHTS=true -t boltzgen:arm64-blackwell-weights .
```

## Usage examples

### Run a design job

```bash
mkdir -p workdir models

docker run --rm --gpus all \
  -v $(pwd)/workdir:/workspace \
  -v $(pwd)/models:/models/boltzgen \
  -v $(pwd)/example:/example \
  boltzgen:arm64-blackwell \
  run /example/vanilla_protein/1g13prot.yaml \
  --output /workspace/out \
  --protocol protein-anything \
  --num_designs 2
```

### JupyterLab

```bash
docker run --rm --gpus all -p 8888:8888 \
  -v $(pwd)/workdir:/workspace \
  -v $(pwd)/models:/models/boltzgen \
  --entrypoint jupyter \
  boltzgen:arm64-blackwell \
  lab --ip=0.0.0.0 --no-browser --notebook-dir=/workspace
```

### Download weights only

```bash
docker run --rm --gpus all \
  -v $(pwd)/models:/models/boltzgen \
  boltzgen:arm64-blackwell \
  download all
```
READMEEOF

USER ${USERNAME}
WORKDIR /workspace

ENTRYPOINT ["boltzgen"]
CMD ["--help"]
