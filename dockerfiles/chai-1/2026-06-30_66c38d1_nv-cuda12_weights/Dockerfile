# syntax=docker/dockerfile:1.4
# Build like:
#   just build chai-1/2026-06-30_66c38d1_nv-cuda12_weights
#   docker buildx build -t chai-1:2026-06-30_66c38d1_nv-cuda12_weights -f Dockerfile .
# Skip weight downloads (~7 GB including ESM-2):
#   docker build --build-arg DOWNLOAD_WEIGHTS=false -t chai-1:2026-06-30_66c38d1_nv-cuda12_no-weights .
#
# Based on upstream Dockerfile.chailab (uv + Python 3.10 + kalign) and the
# nf-core/proteinfold chai1 CUDA base image pattern.

ARG GIT_REPO=https://github.com/chaidiscovery/chai-lab.git
ARG GIT_REF=66c38d1
ARG DOWNLOAD_WEIGHTS=true
ARG CUDA=12.6.0

FROM nvidia/cuda:${CUDA}-base-ubuntu22.04

ARG GIT_REPO
ARG GIT_REF
ARG DOWNLOAD_WEIGHTS
ARG CUDA

LABEL org.opencontainers.image.source=https://github.com/Australian-Protein-Design-Initiative/containers
LABEL org.opencontainers.image.url="${GIT_REPO}"
LABEL org.opencontainers.image.title="Chai-1"
LABEL org.opencontainers.image.description="Chai-1 multi-modal molecular structure prediction (chai-lab) with baked-in model weights"
LABEL org.opencontainers.image.licenses="Apache-2.0"
LABEL org.opencontainers.image.revision="${GIT_REF}"
LABEL org.opencontainers.image.version="2026-06-30_66c38d1"
LABEL org.opencontainers.image.base.name="docker.io/nvidia/cuda:${CUDA}-base-ubuntu22.04"
LABEL org.opencontainers.image.base.digest="sha256:5a05e85d68056b2b095db5fae15d633335d6447f05fd82e3d9450f4977b6fd3e"
LABEL org.opencontainers.image.usage="docker run --gpus all --rm -v \$(pwd):/data -w /data chai-1:2026-06-30_66c38d1_nv-cuda12_weights chai-lab fold input.fasta output_folder"
LABEL org.australian-protein-design-initiative.image.platforms="linux/amd64"

ENV DEBIAN_FRONTEND=noninteractive \
    LANG=C.UTF-8 \
    LC_ALL=C.UTF-8 \
    PYTHONUNBUFFERED=TRUE \
    PYTHONFAULTHANDLER=1 \
    PYTHONPYCACHEPREFIX=/tmp/.chai_lab_pycache \
    UV_HTTP_TIMEOUT=1000 \
    VIRTUAL_ENV=/opt/venv \
    PATH="/opt/venv/bin:${PATH}" \
    CHAI_DOWNLOADS_DIR=/models/chai \
    LD_LIBRARY_PATH="/usr/local/cuda/lib64/stubs/:${LD_LIBRARY_PATH:-}"

RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt,sharing=locked \
    apt-get update && apt-get install -y --no-install-recommends \
      ca-certificates \
      curl \
      git \
      wget \
      build-essential \
      libstdc++6 \
      python3.10 \
      python3.10-dev \
      python3.10-venv \
      # templates / MSA helpers
      kalign \
      # RDKit runtime libs
      libxrender1 \
      libxext6 \
      libsm6 \
      libgomp1 \
    && rm -rf /var/lib/apt/lists/* \
    && git config --global --add safe.directory "*" \
    # cuda softlinking is needed in podman, but not docker (from upstream Dockerfile.chailab)
    && ln -sf /lib/x86_64-linux-gnu/libcuda.so.1 /lib/x86_64-linux-gnu/libcuda.so \
    && ldconfig /lib/x86_64-linux-gnu/ || true

# Install uv and create a Python 3.10 virtualenv (matches upstream Dockerfile.chailab)
RUN --mount=type=cache,target=/root/.cache/uv \
    curl -LsSf https://astral.sh/uv/0.5.4/install.sh | sh \
    && . "$HOME/.local/bin/env" \
    && uv venv --python /usr/bin/python3.10 --no-python-downloads "${VIRTUAL_ENV}"

WORKDIR /app

RUN git clone "${GIT_REPO}" . && git checkout "${GIT_REF}"

# Install CUDA 12 PyTorch first (PyPI defaults to CUDA 13), then chai_lab.
RUN --mount=type=cache,target=/root/.cache/uv \
    --mount=type=cache,target=/root/.cache/pip \
    . "$HOME/.local/bin/env" \
    && . "${VIRTUAL_ENV}/bin/activate" \
    && uv pip install uv pip \
    && uv pip install torch --index-url https://download.pytorch.org/whl/cu126 \
    && uv pip install -e .

# Pre-download Chai-1 components, conformers cache, and ESM-2 embedding model (~7 GB).
# Use wget with resume/retries (chai_lab's requests downloader does not resume large files).
# Layout under CHAI_DOWNLOADS_DIR matches chai_lab.utils.paths / embeddings.esm.
RUN --mount=type=cache,target=/var/cache/chai-weights \
    set -eux; \
    mkdir -p "${CHAI_DOWNLOADS_DIR}" /var/cache/chai-weights; \
    if [ "${DOWNLOAD_WEIGHTS}" = "true" ]; then \
      download() { \
        rel="$1"; \
        url="$2"; \
        expected="$3"; \
        cache="/var/cache/chai-weights/${rel}"; \
        dest="${CHAI_DOWNLOADS_DIR}/${rel}"; \
        mkdir -p "$(dirname "${cache}")" "$(dirname "${dest}")"; \
        if [ ! -f "${cache}" ] || [ "$(stat -c%s "${cache}")" != "${expected}" ]; then \
          wget --tries=20 --retry-connrefused --timeout=60 --continue \
            --progress=dot:giga -O "${cache}" "${url}"; \
        fi; \
        actual="$(stat -c%s "${cache}")"; \
        if [ "${actual}" != "${expected}" ]; then \
          echo "ERROR: ${rel} size ${actual}, expected ${expected}" >&2; \
          rm -f "${cache}"; \
          exit 1; \
        fi; \
        cp -a "${cache}" "${dest}"; \
      }; \
      BASE="https://chaiassets.com/chai1-inference-depencencies"; \
      download "conformers_v1.apkl" "${BASE}/conformers_v1.apkl" 124726115; \
      download "models_v2/feature_embedding.pt" "${BASE}/models_v2/feature_embedding.pt" 4587962; \
      download "models_v2/bond_loss_input_proj.pt" "${BASE}/models_v2/bond_loss_input_proj.pt" 5502; \
      download "models_v2/token_embedder.pt" "${BASE}/models_v2/token_embedder.pt" 6286772; \
      download "models_v2/trunk.pt" "${BASE}/models_v2/trunk.pt" 633042135; \
      download "models_v2/diffusion_module.pt" "${BASE}/models_v2/diffusion_module.pt" 476546304; \
      download "models_v2/confidence_head.pt" "${BASE}/models_v2/confidence_head.pt" 55259496; \
      download \
        "esm/traced_sdpa_esm2_t36_3B_UR50D_fp16.pt" \
        "${BASE}/esm2/traced_sdpa_esm2_t36_3B_UR50D_fp16.pt" \
        5678940466; \
      chmod -R a+rX "${CHAI_DOWNLOADS_DIR}"; \
      echo "Chai-1 weight download complete under ${CHAI_DOWNLOADS_DIR}"; \
      find "${CHAI_DOWNLOADS_DIR}" -type f -printf '%10s  %p\n' | sort; \
    else \
      echo "Skipping weight download (DOWNLOAD_WEIGHTS=${DOWNLOAD_WEIGHTS}); set CHAI_DOWNLOADS_DIR or mount /models/chai"; \
    fi

RUN cat > /README.md <<'EOF'
# Chai-1

Multi-modal molecular structure prediction with
[chai-lab](https://github.com/chaidiscovery/chai-lab) (Chai-1).

## Provenance

- Source: https://github.com/chaidiscovery/chai-lab.git @ 66c38d1 (2026-06-30)
- Base image: nvidia/cuda:12.6.0-base-ubuntu22.04
- Install style follows upstream `Dockerfile.chailab` (uv + Python 3.10 + kalign)
  and the nf-core/proteinfold Chai-1 CUDA image pattern

## Weights

When built with `DOWNLOAD_WEIGHTS=true` (default), inference assets are baked into
`/models/chai` (`CHAI_DOWNLOADS_DIR`):

- `conformers_v1.apkl`
- `models_v2/{feature_embedding,bond_loss_input_proj,token_embedder,trunk,diffusion_module,confidence_head}.pt`
- `esm/traced_sdpa_esm2_t36_3B_UR50D_fp16.pt`

Total payload is roughly 7 GB. For a no-weights build, mount a populated directory
at `/models/chai` or set `CHAI_DOWNLOADS_DIR` at runtime.

## Usage

```bash
docker run --gpus all --rm \
  -v "$(pwd)":/data -w /data \
  ghcr.io/australian-protein-design-initiative/containers/chai-1:2026-06-30_66c38d1_nv-cuda12_weights \
  chai-lab fold input.fasta output_folder
```

With ColabFold MSAs / templates:

```bash
docker run --gpus all --rm \
  -v "$(pwd)":/data -w /data \
  ghcr.io/australian-protein-design-initiative/containers/chai-1:2026-06-30_66c38d1_nv-cuda12_weights \
  chai-lab fold --use-msa-server --use-templates-server input.fasta output_folder
```

Requires a CUDA GPU with bfloat16 support (A100 / H100 / L40S recommended).
EOF

WORKDIR /data

CMD ["chai-lab", "--help"]
