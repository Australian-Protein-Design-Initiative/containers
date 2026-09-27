# syntax=docker/dockerfile:1.4
# Build like:
#   just build openfold3/0.5.0_nv-cuda12_weights
#   docker buildx build -t openfold3:0.5.0_nv-cuda12_weights -f Dockerfile .
# Skip model-parameter download (~2 GB):
#   docker build --build-arg DOWNLOAD_WEIGHTS=false -t openfold3:0.5.0_nv-cuda12_no-weights .
#
# Based on upstream docker/Dockerfile.pixi (recommended OpenFold3 image):
#   https://github.com/aqlaboratory/openfold-3/blob/v0.5.0/docker/Dockerfile.pixi
#   https://openfold-3.readthedocs.io/en/latest/Installation.html#openfold3-docker-image

ARG GIT_REPO=https://github.com/aqlaboratory/openfold-3.git
ARG GIT_REF=v0.5.0
ARG DOWNLOAD_WEIGHTS=true
ARG PIXI_VERSION=v0.76.0
ARG PIXI_ENV=openfold3-cuda12
ARG BASE_IMAGE=ubuntu:22.04

FROM ${BASE_IMAGE}

ARG GIT_REPO
ARG GIT_REF
ARG DOWNLOAD_WEIGHTS
ARG PIXI_VERSION
ARG PIXI_ENV

LABEL org.opencontainers.image.source=https://github.com/Australian-Protein-Design-Initiative/containers
LABEL org.opencontainers.image.url="${GIT_REPO}"
LABEL org.opencontainers.image.documentation="https://openfold-3.readthedocs.io/en/latest/"
LABEL org.opencontainers.image.title="OpenFold3"
LABEL org.opencontainers.image.description="OpenFold3 v0.5.0 biomolecular structure prediction (OpenBind-0) with CUDA 12, cuEquivariance/DeepSpeed kernels, and baked-in model parameters"
LABEL org.opencontainers.image.licenses="Apache-2.0"
LABEL org.opencontainers.image.revision="${GIT_REF}"
LABEL org.opencontainers.image.version="0.5.0"
LABEL org.opencontainers.image.base.name="docker.io/library/ubuntu:22.04"
LABEL org.opencontainers.image.base.digest="sha256:281c5745f657873d78e5531fc5ba8575f46ab7769b94550ac99543f122679986"
LABEL org.opencontainers.image.usage="docker run --gpus all --rm -v \$(pwd):/data -w /data openfold3:0.5.0_nv-cuda12_weights run_openfold predict --query-json query.json --output-dir /data/output"
LABEL org.australian-protein-design-initiative.image.platforms="linux/amd64"

ENV DEBIAN_FRONTEND=noninteractive \
    LANG=C.UTF-8 \
    LC_ALL=C.UTF-8 \
    PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1 \
    PATH="/root/.pixi/bin:${PATH}" \
    KMP_AFFINITY=none \
    TORCH_CUDA_ARCH_LIST="8.0;8.6;9.0" \
    OPENFOLD_CACHE=/models/openfold3 \
    NVIDIA_VISIBLE_DEVICES=all \
    NVIDIA_DRIVER_CAPABILITIES=compute,utility

RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt,sharing=locked \
    apt-get update && apt-get install -y --no-install-recommends \
      ca-certificates \
      curl \
      git \
      wget \
      libaio-dev \
    && rm -rf /var/lib/apt/lists/*

# Pixi manages CUDA toolkit, cuDNN, CUTLASS, PyTorch, DeepSpeed, and cuEquivariance
# from conda-forge (no nvidia/cuda base image). See docker/DOCKER.md upstream.
RUN curl -fsSL https://pixi.sh/install.sh | PIXI_VERSION=${PIXI_VERSION} bash

WORKDIR /opt/openfold3

RUN git clone --depth 1 --branch "${GIT_REF}" "${GIT_REPO}" .

# Bypass GPU detection during build: cuda12/cuda13 environments declare a `cuda`
# system requirement that pixi validates against the host. Advertise a matching
# CUDA version via CONDA_OVERRIDE_CUDA so the frozen install is accepted.
# --frozen installs exactly from pixi.lock.
RUN --mount=type=cache,target=/root/.cache/rattler \
    --mount=type=cache,target=/root/.cache/pixi \
    case "${PIXI_ENV}" in \
      *cuda12*) export CONDA_OVERRIDE_CUDA=12.0 ;; \
      *cuda13*) export CONDA_OVERRIDE_CUDA=13.0 ;; \
    esac && \
    pixi install --frozen -e "${PIXI_ENV}"

# Isolate DeepSpeed / Triton JIT caches inside the pixi env (pixi.toml deepspeed-build).
RUN mkdir -p \
      "/opt/openfold3/.pixi/envs/${PIXI_ENV}/caches/triton" \
      "/opt/openfold3/.pixi/envs/${PIXI_ENV}/caches/torch_extensions"

RUN case "${PIXI_ENV}" in \
      *cuda12*) export CONDA_OVERRIDE_CUDA=12.0 ;; \
      *cuda13*) export CONDA_OVERRIDE_CUDA=13.0 ;; \
    esac && \
    pixi shell-hook -e "${PIXI_ENV}" -s bash > /opt/activate.sh && \
    echo "source /opt/activate.sh" >> /root/.bashrc

RUN bash -c "source /opt/activate.sh && pip install --no-deps --editable ."

# Canonical cache is /models/openfold3; ~/.openfold3 is a fallback symlink so
# the default Path.home() / ".openfold3" resolution also works.
RUN mkdir -p /models/openfold3 && \
    ln -sfn /models/openfold3 /root/.openfold3 && \
    echo "/models/openfold3" > /models/openfold3/ckpt_root

# Default OpenBind-0 parameters (~2 GB) plus Biotite CCD.
# Skip with --build-arg DOWNLOAD_WEIGHTS=false and mount at runtime:
#   -v /path/to/openfold3:/models/openfold3
RUN --mount=type=cache,target=/var/cache/openfold3-weights \
    set -eux; \
    if [ "${DOWNLOAD_WEIGHTS}" = "true" ]; then \
      WEIGHT_FILE="of3-ob-2025-06-30-174k.pt"; \
      WEIGHT_URL="https://openfold3-data.s3.amazonaws.com/openfold3-parameters/${WEIGHT_FILE}"; \
      mkdir -p /var/cache/openfold3-weights; \
      wget --tries=20 --retry-connrefused --timeout=60 --continue \
        --progress=dot:giga -O "/var/cache/openfold3-weights/${WEIGHT_FILE}" "${WEIGHT_URL}"; \
      cp -a "/var/cache/openfold3-weights/${WEIGHT_FILE}" "/models/openfold3/${WEIGHT_FILE}"; \
      printf '%s\n' \
        '{' \
        '  "openfold_cache": "/models/openfold3",' \
        '  "param_directory": "/models/openfold3",' \
        '  "selected_parameters": "default",' \
        '  "force_download_parameters": false,' \
        '  "run_integration_tests": false' \
        '}' \
        > /tmp/openfold_setup.json; \
      bash -c "source /opt/activate.sh && setup_openfold --config /tmp/openfold_setup.json"; \
      chmod -R a+rX /models/openfold3; \
      rm -f /tmp/openfold_setup.json; \
    else \
      echo "Skipping weight download (DOWNLOAD_WEIGHTS=${DOWNLOAD_WEIGHTS}); mount parameters at /models/openfold3"; \
    fi

RUN cat > /README.md <<'EOF'
# OpenFold3

Biomolecular structure prediction with [OpenFold3](https://github.com/aqlaboratory/openfold-3)
v0.5.0 (OpenBind-0 default parameters). Fully open source AlphaFold3 reproduction
(Apache 2.0).

## Provenance

- Source: https://github.com/aqlaboratory/openfold-3.git @ v0.5.0 (c477165, 2026-08-21)
- Docs: https://openfold-3.readthedocs.io/en/latest/
- Base image: ubuntu:22.04 (CUDA 12 toolchain via pixi / conda-forge)
- Environment: pixi `openfold3-cuda12` (PyTorch, DeepSpeed, cuEquivariance, CUTLASS)
- Recipe adapted from upstream `docker/Dockerfile.pixi`

## Weights

When built with `DOWNLOAD_WEIGHTS=true` (default), artifacts live under
`OPENFOLD_CACHE=/models/openfold3` (`~/.openfold3` is a symlink to the same path):

- `of3-ob-2025-06-30-174k.pt` — OpenBind-0 checkpoint (default for openfold3 >= 0.5.0)
- `ckpt_root` — points at this directory so `run_openfold` finds the checkpoint
- Biotite CCD is also fetched by `setup_openfold`

For a no-weights build, mount a populated directory at `/models/openfold3` or run
`setup_openfold` at runtime. Manual download:

```bash
aws s3 cp s3://openfold3-data/openfold3-parameters/of3-ob-2025-06-30-174k.pt \
  /models/openfold3/ --no-sign-request
```

## GPU

NVIDIA GPU with CUDA 12.1+ and >= 32 GB memory. Tested upstream on A100 40 GB.

```bash
docker run --gpus all --rm \
  -v "$(pwd)":/data -w /data \
  ghcr.io/australian-protein-design-initiative/containers/openfold3:0.5.0_nv-cuda12_weights \
  run_openfold predict \
    --query-json query.json \
    --output-dir /data/output
```

Ubiquitin example shipped in the image (ColabFold MSA server; needs network):

```bash
docker run --gpus all --rm \
  -v "$(pwd)":/data -w /data \
  ghcr.io/australian-protein-design-initiative/containers/openfold3:0.5.0_nv-cuda12_weights \
  run_openfold predict \
    --query-json /opt/openfold3/examples/example_inference_inputs/query_ubiquitin.json \
    --output-dir /data/of3_output
```

MSA-free (no ColabFold server):

```bash
docker run --gpus all --rm \
  -v "$(pwd)":/data -w /data \
  ghcr.io/australian-protein-design-initiative/containers/openfold3:0.5.0_nv-cuda12_weights \
  run_openfold predict \
    --query-json query.json \
    --use-msa-server=False \
    --output-dir /data/output
```

List commands:

```bash
docker run --rm \
  ghcr.io/australian-protein-design-initiative/containers/openfold3:0.5.0_nv-cuda12_weights \
  run_openfold --help
```

Query JSON format and runner.yml options:
https://openfold-3.readthedocs.io/en/latest/inference.html
EOF

WORKDIR /data

# Activate the pixi environment before running any command.
ENTRYPOINT ["/bin/bash", "-c", "source /opt/activate.sh && exec \"$@\"", "--"]
CMD ["run_openfold", "--help"]
