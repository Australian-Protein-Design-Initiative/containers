# Build like:
#   just build lmi4boltz/v1.0.0
#   docker build -t lmi4boltz:v1.0.0 dockerfiles/lmi4boltz/v1.0.0
#
# Low-memory inference fork of Boltz (https://github.com/tlitfin/lmi4boltz).
# Based on boltz/v2.2.1-2; install is still `pip install .[cuda]` and the CLI is `boltz`.
# Layout matches existing Boltz wrappers: BOLTZ_CACHE=/app/boltz/cache

ARG GIT_REPO=https://github.com/tlitfin/lmi4boltz.git
ARG GIT_REF=v1.0.0

FROM ubuntu:24.04

LABEL org.opencontainers.image.source=https://github.com/Australian-Protein-Design-Initiative/containers
LABEL org.opencontainers.image.title="LMI4Boltz"
LABEL org.opencontainers.image.description="Low-memory inference for Boltz (tlitfin/lmi4boltz) with CUDA 12 extras and pre-cached Boltz-2 weights"
LABEL org.opencontainers.image.version="v1.0.0"
LABEL org.opencontainers.image.licenses="MIT"
LABEL org.australian-protein-design-initiative.image.platforms="linux/amd64"

ARG GIT_REPO
ARG GIT_REF
ARG CCD_URL="https://huggingface.co/boltz-community/boltz-1/resolve/main/ccd.pkl"
ARG MOL_URL="https://huggingface.co/boltz-community/boltz-2/resolve/main/mols.tar"
ARG BOLTZ2_WEIGHTS_URL="https://huggingface.co/boltz-community/boltz-2/resolve/main/boltz2_conf.ckpt"
ARG BOLTZ2_AFFINITY_WEIGHTS_URL="https://huggingface.co/boltz-community/boltz-2/resolve/main/boltz2_aff.ckpt"
ARG DOWNLOAD_WEIGHTS=true

ENV DEBIAN_FRONTEND=noninteractive
RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt,sharing=locked \
    apt-get update && apt-get install -y --no-install-recommends \
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
    libopenblas-dev \
    liblapack-dev \
    && rm -rf /var/lib/apt/lists/*

RUN addgroup --system boltz && adduser --system --ingroup boltz boltz

WORKDIR /app

# Clone into /app/boltz so existing wrappers that set BOLTZ_CACHE=/app/boltz/cache keep working.
RUN git clone ${GIT_REPO} boltz && \
    cd boltz && \
    git checkout ${GIT_REF} && \
    chown -R boltz:boltz /app

WORKDIR /app/boltz

# Pre-cache boltz-2 models (same layout/workaround as boltz/v2.2.1-2)
# HACK: After unpacking, replace mols.tar with an empty tarball — Boltz-2 does not
#       clean up the tarball after unpacking and re-downloads if it is missing.
ENV BOLTZ_CACHE=/app/boltz/cache \
    PYTHONNOUSERSITE=1
RUN --mount=type=cache,target=/var/cache/lmi4boltz-weights \
    if [ "${DOWNLOAD_WEIGHTS}" = "true" ]; then \
        mkdir -p ${BOLTZ_CACHE} /var/cache/lmi4boltz-weights && \
        cd /var/cache/lmi4boltz-weights && \
        curl -L -o ccd.pkl ${CCD_URL} && \
        curl -L -o mols.tar ${MOL_URL} && \
        curl -L -o boltz2_conf.ckpt ${BOLTZ2_WEIGHTS_URL} && \
        curl -L -o boltz2_aff.ckpt ${BOLTZ2_AFFINITY_WEIGHTS_URL} && \
        cp ccd.pkl boltz2_conf.ckpt boltz2_aff.ckpt ${BOLTZ_CACHE}/ && \
        cp mols.tar ${BOLTZ_CACHE}/ && \
        cd ${BOLTZ_CACHE} && \
        tar -xvf mols.tar && \
        rm mols.tar && \
        tar -cf mols.tar --files-from /dev/null && \
        chown -R boltz:boltz ${BOLTZ_CACHE}; \
    else \
        echo "Skipping weight download (DOWNLOAD_WEIGHTS=${DOWNLOAD_WEIGHTS})"; \
        mkdir -p ${BOLTZ_CACHE} && chown -R boltz:boltz ${BOLTZ_CACHE}; \
    fi

# System user has no home by default; give a fallback home for interactive runs.
# Production wrappers typically override NUMBA/XDG/TRITON caches to pwd-relative dirs.
RUN mkdir -p /home/boltz/.cache/numba && \
    usermod -d /home/boltz boltz && \
    chown -R boltz:boltz /home/boltz

# cuequivariance extras are CUDA 12; pin torch to a matching cu126 wheel
# (plain `pip install torch` currently resolves to cu130 on PyPI).
ENV PIP_BREAK_SYSTEM_PACKAGES=1
RUN --mount=type=cache,target=/root/.cache/pip \
    pip install torch --index-url https://download.pytorch.org/whl/cu126 && \
    pip install .[cuda] && \
    pip install --force-reinstall --no-deps torch --index-url https://download.pytorch.org/whl/cu126

RUN --mount=type=cache,target=/root/.cache/pip \
    pip install \
    pyyaml \
    biotite==1.4.0 \
    pandas \
    biopython

# Set HOME for the runtime user only after root pip installs (avoids breaking pip cache).
# Wrappers may override NUMBA_CACHE_DIR / XDG_CONFIG_HOME / TRITON_CACHE_DIR to $(pwd)/...
ENV HOME=/home/boltz \
    NUMBA_CACHE_DIR=/home/boltz/.cache/numba

RUN cat > /README.md <<'EOF'
# LMI4Boltz container

**Source:** https://github.com/tlitfin/lmi4boltz (tag: v1.0.0)

Low-memory inference fork of Boltz. The CLI remains `boltz`; use the extra
chunking flags documented upstream to reduce peak VRAM.

## Paths / env (wrapper-compatible)

| Variable | Default in image | Typical wrapper override |
|----------|------------------|--------------------------|
| `BOLTZ_CACHE` | `/app/boltz/cache` | same |
| `PYTHONNOUSERSITE` | `1` | same |
| `NUMBA_CACHE_DIR` | `/home/boltz/.cache/numba` | `$(pwd)/.numba_cache` |
| `XDG_CONFIG_HOME` | (unset) | `$(pwd)/.config` |
| `TRITON_CACHE_DIR` | (unset) | `$(pwd)/.triton_cache` |

When built with `DOWNLOAD_WEIGHTS=true` (default), Boltz-2 CCD/mols/checkpoints
are cached under `$BOLTZ_CACHE`.

To skip baking weights in and mount them at runtime:

```bash
docker build --build-arg DOWNLOAD_WEIGHTS=false -t lmi4boltz:v1.0.0 .
docker run --rm --gpus all \
  -v /path/to/boltz-cache:/app/boltz/cache \
  -v $(pwd)/workdir:/workdir \
  lmi4boltz:v1.0.0 \
  boltz predict /workdir/input.yaml --use_msa_server
```

## Example

```bash
docker run --rm --gpus all \
  -v $(pwd)/workdir:/workdir \
  lmi4boltz:v1.0.0 \
  boltz predict /workdir/input.yaml --use_msa_server
```
EOF

USER boltz

CMD ["boltz"]
