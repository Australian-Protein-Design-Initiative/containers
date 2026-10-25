# Boltz-2 for arm64 / aarch64 + Blackwell (GB10 / GB100) with CUDA 13.3
#
# arm64 counterpart of ../v2.2.1-2. Differences from the amd64 build, and why:
#
#  - Base is nvidia/cuda:13.3.0-cudnn-devel-ubuntu24.04 rather than plain ubuntu:24.04.
#    The amd64 image relies on the CUDA libraries bundled in PyPI's x86_64 torch wheels;
#    the aarch64 CUDA wheels live on download.pytorch.org, not PyPI, so we pull torch
#    from the cu130 index and want a matching CUDA userspace present.
#  - GB10 reports compute capability 12.1 (sm_121). CUDA 12.x toolchains can't JIT for
#    it ("nvrtc: error: invalid value for --gpu-architecture"), so CUDA 13.x / cu130
#    torch is mandatory here, not merely preferred.
#  - The [cuda] extra's cuequivariance_ops_*_cu12 packages are swapped to their _cu13
#    equivalents to match that runtime, otherwise they fail to load at import time
#    (libnvrtc.so.12: cannot open shared object file). Same sed patch the arm64 boltzgen
#    image uses.
#  - Python 3.12 (Ubuntu 24.04 system python) instead of 3.11 - boltz allows
#    >=3.10,<3.13, and every pinned dependency has cp312 aarch64 wheels. Only
#    gemmi==0.6.5 has no aarch64 wheel and is built from source, hence cmake/g++ below.
#
# Build like:
#   just push boltz/v2.2.1-2_nv-cuda13-arm64 --pull
# (--pull is required on this builder - see the arm64 handoff notes; stale BuildKit
#  cache for a mutable base tag otherwise surfaces as "exec /bin/sh: exec format error")

FROM nvidia/cuda:13.3.0-cudnn-devel-ubuntu24.04

LABEL org.opencontainers.image.source=https://github.com/Australian-Protein-Design-Initiative/containers
LABEL org.australian-protein-design-initiative.image.platforms="linux/arm64"
LABEL org.opencontainers.image.title="Boltz-2 (arm64 / Blackwell)"
LABEL org.opencontainers.image.description="Boltz-2 structure/affinity prediction for arm64 + NVIDIA Blackwell (GB10/GB100) - CUDA 13.3, PyTorch cu130, with the boltz-2 weights, CCD and mols cache baked in"
LABEL org.opencontainers.image.url="https://github.com/jwohlwend/boltz"
LABEL org.opencontainers.image.licenses="MIT"
LABEL org.opencontainers.image.version="2.2.1"
LABEL org.opencontainers.image.revision="v2.2.1"
LABEL org.opencontainers.image.base.name="docker.io/nvidia/cuda:13.3.0-cudnn-devel-ubuntu24.04"
LABEL org.opencontainers.image.usage="docker run --gpus all --rm -v \$(pwd):/data -w /data boltz:v2.2.1-2_nv-cuda13-arm64 boltz predict input.yaml --use_msa_server"

ARG GIT_REF=v2.2.1
ARG CCD_URL="https://huggingface.co/boltz-community/boltz-1/resolve/main/ccd.pkl"
ARG MOL_URL="https://huggingface.co/boltz-community/boltz-2/resolve/main/mols.tar"
ARG BOLTZ2_WEIGHTS_URL="https://huggingface.co/boltz-community/boltz-2/resolve/main/boltz2_conf.ckpt"
ARG BOLTZ2_AFFINITY_WEIGHTS_URL="https://huggingface.co/boltz-community/boltz-2/resolve/main/boltz2_aff.ckpt"

# cu130 = compiled against CUDA 13.0, forward-compatible with the 13.3 runtime above
ARG TORCH_VERSION=2.13.0
ARG TORCH_INDEX_URL=https://download.pytorch.org/whl/cu130

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
    libopenblas-dev \
    liblapack-dev \
    zlib1g-dev \
    && rm -rf /var/lib/apt/lists/*

RUN addgroup --system boltz && adduser --system --ingroup boltz boltz

WORKDIR /app

RUN git clone https://github.com/jwohlwend/boltz.git boltz && \
    cd boltz && \
    git checkout ${GIT_REF} && \
    chown -R boltz:boltz /app

WORKDIR /app/boltz

# Pre-cache boltz-2 models
# HACK: After unpacking, we replace the mols.tar with an empty tarball, since Boltz-2 doesn't
#       cleanup up it's tarball download after unpacking and attempts to
#       download mols.tar again if it doesn't exist.
# --no-same-owner: mols.tar bakes in uid/gid values that can't be mapped under rootless
#                  Docker ("Cannot change ownership to uid ...: Invalid argument").
ENV BOLTZ_CACHE=/app/boltz/cache
RUN mkdir -p ${BOLTZ_CACHE} && \
    cd ${BOLTZ_CACHE} && \
    curl -L -o ccd.pkl ${CCD_URL} && \
    curl -L -o mols.tar ${MOL_URL} && \
    tar --no-same-owner -xf mols.tar && \
    rm mols.tar && \
    tar -cf mols.tar --files-from /dev/null && \
    curl -L -o boltz2_conf.ckpt ${BOLTZ2_WEIGHTS_URL} && \
    curl -L -o boltz2_aff.ckpt ${BOLTZ2_AFFINITY_WEIGHTS_URL}

ENV PIP_BREAK_SYSTEM_PACKAGES=1 \
    PIP_NO_CACHE_DIR=1

# boltz decorates a featuriser with @numba.njit(cache=True). Numba writes that cache next to the
# source file, which is under /usr/local and not writable by the unprivileged `boltz` user this
# image runs as, and it fails at import with "cannot cache function ... no locator available"
# rather than falling back, so these have to point somewhere writable.
#
# The directories are created here with the sticky world-writable mode /tmp itself uses, and the
# smoke test below reopens the tree after it has populated it. Both halves are needed: numba puts
# its entries in a per-module subdirectory, and `boltz --help` during that root-run smoke test
# creates one owned by root, which the `boltz` user then cannot write into. Under Nextflow or
# Apptainer the container commonly runs as the invoking user rather than as `boltz`, so the cache
# has to stay writable for an arbitrary uid rather than for one known account.
ENV NUMBA_CACHE_DIR=/tmp/numba_cache \
    MPLCONFIGDIR=/tmp/matplotlib

# Run as an arbitrary uid without a passwd entry - which is how Apptainer runs the image, and how
# Docker runs it under `-u $(id -u)` - and HOME resolves to /, so anything reaching for ~/.cache
# dies with "Permission denied: '/.cache'" part way through a prediction. Point HOME and the XDG
# cache at /tmp instead. The model weights are unaffected: BOLTZ_CACHE is set explicitly above.
ENV HOME=/tmp \
    XDG_CACHE_HOME=/tmp/.cache

RUN mkdir -p /tmp/numba_cache /tmp/matplotlib /tmp/.cache \
    && chmod 1777 /tmp/numba_cache /tmp/matplotlib /tmp/.cache

# Install the CUDA-13 torch build explicitly and FIRST. boltz only asks for
# `torch>=2.2`, so leaving this to the resolver risks it picking PyPI's aarch64 wheel
# (no CUDA support) over the cu130 one. Installed up front, the later `pip install .`
# sees the requirement already satisfied and leaves it alone.
RUN pip install --index-url ${TORCH_INDEX_URL} "torch==${TORCH_VERSION}"

# Swap the [cuda] extra's cu12 cuequivariance ops for cu13 builds matching this
# image's CUDA runtime. boltz imports `cuequivariance_torch` (pure Python); the
# cu12/cu13 ops packages are backends discovered at runtime, so this is transparent.
RUN sed -i \
        -e 's/cuequivariance_ops_cu12/cuequivariance_ops_cu13/g' \
        -e 's/cuequivariance_ops_torch_cu12/cuequivariance_ops_torch_cu13/g' \
        pyproject.toml

# gemmi==0.6.5 has no aarch64 wheel and is compiled from source here (~few min).
RUN pip install .[cuda]

# Pin the pure-Python cuequivariance packages to the same version as the compiled cu13
# ops backend. boltz's [cuda] extra only says >=0.5.0, so the resolver takes the newest
# cuequivariance/cuequivariance_torch from PyPI (0.11.0) while the newest *cu13* ops
# build available is 0.10.0. That mismatch is not benign: cuequivariance_torch 0.11.0
# dispatches triangle_attention to the backend with a `kv_lengths=` kwarg that the
# 0.10.0 op doesn't accept, so every prediction dies with
#   TypeError: triangle_attention() got an unexpected keyword argument 'kv_lengths'
# once the first batch reaches the GPU (not at import time).
# Deriving the pin from the installed ops version rather than hardcoding it means this
# self-corrects when cu13 builds of 0.11.0+ eventually appear.
RUN CUEQ_OPS_VERSION=$(pip show cuequivariance-ops-torch-cu13 | sed -n 's/^Version: //p') && \
    echo "Pinning cuequivariance python packages to ops version ${CUEQ_OPS_VERSION}" && \
    pip install \
        "cuequivariance==${CUEQ_OPS_VERSION}" \
        "cuequivariance_torch==${CUEQ_OPS_VERSION}"

RUN pip install \
    pyyaml \
    biotite==1.4.0 \
    pandas \
    biopython

# Import the pieces that only fail at run time if the CUDA/cuequivariance versions drift
# apart, rather than discovering it part way through a prediction. No GPU is present
# during the build, so this checks loadability, not execution.
#
# The ops package is checked through its metadata rather than by importing it: the extension
# needs libcuda.so.1, which is not present during a build, so an import would fail here on a
# machine where it will work at run time. Checking the distribution name is also the stronger
# test, since both CUDA variants install under the same import name `cuequivariance_ops_torch`
# and an import would not reveal a silent fall back to the cu12 wheel. The two pure-Python
# packages are checked against its version, which is the mismatch that otherwise only shows up
# once a prediction reaches the GPU.
RUN python3 -c "import torch, boltz, cuequivariance, cuequivariance_torch, gemmi, biotite, pandas, Bio, yaml; print('torch', torch.__version__); print('cuequivariance', cuequivariance.__version__)" \
    && python3 -c "\
import importlib.metadata as m;\
ops = m.version('cuequivariance-ops-torch-cu13');\
assert m.version('cuequivariance') == ops, 'cuequivariance %s != ops %s' % (m.version('cuequivariance'), ops);\
assert m.version('cuequivariance-torch') == ops, 'cuequivariance_torch %s != ops %s' % (m.version('cuequivariance-torch'), ops);\
print('cuequivariance_ops_torch cu13', ops, 'ok')" \
    && boltz --help > /dev/null \
    && test -s ${BOLTZ_CACHE}/boltz2_conf.ckpt \
    && test -s ${BOLTZ_CACHE}/boltz2_aff.ckpt \
    && test -s ${BOLTZ_CACHE}/ccd.pkl \
    && chmod -R a+rwX /tmp/numba_cache /tmp/matplotlib

RUN cat > /README.md <<'EOF'
# Boltz-2 (arm64 / Blackwell)

[Boltz-2](https://github.com/jwohlwend/boltz) v2.2.1 structure and affinity prediction, built for
arm64 / aarch64 with CUDA 13.3. The amd64 sibling tag is `v2.2.1-2`.

## Why a separate arm64 build

- The amd64 image relies on the CUDA libraries bundled into PyPI's x86_64 torch wheels. The
  aarch64 CUDA wheels are published on download.pytorch.org instead, so torch comes from the
  cu130 index here and the image carries a matching CUDA userspace.
- GB10 reports compute capability 12.1 (sm_121). CUDA 12.x toolchains cannot JIT for it, so
  CUDA 13.x / cu130 torch is required, not merely preferred.
- The `[cuda]` extra's `cuequivariance_ops_*_cu12` packages are swapped for their `_cu13`
  equivalents to match that runtime, and the pure-Python `cuequivariance` packages are pinned to
  the same version as the compiled ops backend. Without that pin the resolver takes a newer
  `cuequivariance_torch` than the newest available cu13 ops build, and every prediction fails with
  `TypeError: triangle_attention() got an unexpected keyword argument 'kv_lengths'` once the first
  batch reaches the GPU.

## Baked-in cache

`BOLTZ_CACHE=/app/boltz/cache` holds `boltz2_conf.ckpt`, `boltz2_aff.ckpt`, `ccd.pkl` and the
unpacked `mols/`, so a prediction needs no downloads. MSA generation with `--use_msa_server` still
reaches the ColabFold server; supply your own MSA to run fully offline.

## Use `--num_workers 0`

Boltz's dataloader worker processes deadlock on this platform. The run reaches
`Predicting: 0/?` and then sits there with the GPU at 0%, indefinitely, rather than failing, so it
looks like a slow model load. With `--num_workers 0` the same prediction completes in seconds.

```bash
docker run --gpus all --rm -v "$(pwd)":/data -w /data \
  ghcr.io/australian-protein-design-initiative/containers/boltz:v2.2.1-2_nv-cuda13-arm64 \
  boltz predict input.yaml --use_msa_server --num_workers 0 --out_dir ./out
```

Requires an NVIDIA GPU with a CUDA 13 driver (580+).

## Running as another user

`HOME`, `XDG_CACHE_HOME`, `NUMBA_CACHE_DIR` and `MPLCONFIGDIR` all point into `/tmp`, and those
directories are world-writable, so the image works when run as an arbitrary uid with no passwd
entry - which is how Apptainer runs it, and how Docker runs it under `-u $(id -u)`. Without that,
`HOME` resolves to `/` and a prediction dies part way through on `Permission denied: '/.cache'`,
while numba refuses to import at all.
EOF

USER boltz

# Importing boltz.main is what triggers the @numba.njit(cache=True) decorator, so this is the
# check that the numba cache directory is usable. It has to run after USER: as root the cache
# falls back to the package directory and the problem is invisible. Run as a third uid as well,
# since that is how Nextflow and Apptainer usually invoke the image.
RUN python3 -c "import boltz.main; print('boltz.main imports as uid', __import__('os').getuid())"
USER 12345
RUN python3 -c "import boltz.main; print('boltz.main imports as uid', __import__('os').getuid())"
USER boltz

CMD ["boltz"]
