# syntax=docker/dockerfile:1.4
# Build like:
#   just build rfd4-proteina/0.0.3_nv-cuda13-arm64 --pull
# Skip the weight download (~1.7 GB):
#   just build rfd4-proteina/0.0.3_nv-cuda13-arm64 --variant no-weights
#
# RFD4-Proteina 0.0.3 with CUDA 13 / PyTorch cu130, for arm64 / aarch64 (e.g. DGX Spark GB10, sm_121).
#
# Upstream ships its own Dockerfile on a python:3.12-slim base, relying on the CUDA libraries that
# come with the PyTorch wheels. This image uses the CUDA 13 devel base instead: GB10 reports compute
# capability 12.1 (sm_121), which CUDA 12 toolchains cannot JIT for, and torch.compile (on by default
# here) invokes a CUDA toolchain at run time. Every binary dependency - tmol, tmol-ops-cu13,
# bionemo-ir, the cuequivariance cu13 ops, nvidia-cutlass-dsl-libs-base, cuda-core, apache-tvm-ffi,
# openbabel - publishes aarch64 wheels, so the standard `all-cuda13` extra installs unmodified.
#
# Bakes in the nvidia/RFD4-Proteina model bundle (denoiser + autoencoder) at the Hub revision pinned
# by configs/inference.yaml for 0.0.3, so a run needs no Hub access.

ARG RFD4_VERSION=0.0.3
ARG HF_MODEL_REPO=nvidia/RFD4-Proteina
ARG HF_MODEL_REVISION=a06e2509c7033b010fc43614e9fd840303588502
ARG DOWNLOAD_WEIGHTS=true
ARG BASE_IMAGE=nvidia/cuda:13.0.1-cudnn-devel-ubuntu24.04

FROM ${BASE_IMAGE}

ARG RFD4_VERSION
ARG HF_MODEL_REPO
ARG HF_MODEL_REVISION
ARG DOWNLOAD_WEIGHTS

LABEL org.opencontainers.image.source=https://github.com/Australian-Protein-Design-Initiative/containers
LABEL org.opencontainers.image.url="https://github.com/RosettaCommons/RFD4-Proteina"
LABEL org.opencontainers.image.documentation="https://rfd4-proteina.org/latest/"
LABEL org.opencontainers.image.title="RFD4-Proteina (arm64)"
LABEL org.opencontainers.image.description="RFD4-Proteina 0.0.3 flow-matching biomolecular design with CUDA 13 on arm64, cuEquivariance and BioIR kernels, and baked-in nvidia/RFD4-Proteina weights"
LABEL org.opencontainers.image.licenses="BSD-3-Clause"
LABEL org.opencontainers.image.version="${RFD4_VERSION}"
LABEL org.opencontainers.image.base.name="docker.io/nvidia/cuda:13.0.1-cudnn-devel-ubuntu24.04"
LABEL org.opencontainers.image.base.digest="sha256:6fd95f7235f228fc7cff6f45d7b2d16ed93bddff4e80a94288731c6c7cea81d7"
LABEL org.opencontainers.image.usage="docker run --gpus all --rm -v \$(pwd):/data -w /data rfd4-proteina:0.0.3_nv-cuda13-arm64 rfd4-generate inference_experiment=quickstart inputs=binder.yaml out_dir=./runs/first"
LABEL org.australian-protein-design-initiative.image.platforms="linux/arm64"

ENV DEBIAN_FRONTEND=noninteractive \
    LANG=C.UTF-8 \
    LC_ALL=C.UTF-8 \
    PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1 \
    PYTHONNOUSERSITE=1 \
    PIP_DISABLE_PIP_VERSION_CHECK=1 \
    VIRTUAL_ENV=/opt/venv \
    PATH="/opt/venv/bin:${PATH}" \
    CUDA_HOME=/usr/local/cuda \
    DATA_PATH=/data \
    HF_HOME=/weights/huggingface \
    HUGGINGFACE_HUB_CACHE=/weights/huggingface/hub \
    HF_HUB_ENABLE_HF_TRANSFER=1 \
    TMOL_DISABLE_WHEEL_FETCH=1 \
    TMOL_JIT_FALLBACK=0 \
    TMOL_USE_JIT=0 \
    NVIDIA_VISIBLE_DEVICES=all \
    NVIDIA_DRIVER_CAPABILITIES=compute,utility

# build-essential: torch.compile (Inductor/Triton) compiles C++ glue at run time.
# The lib* packages are runtime dependencies of OpenBabel.
RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt,sharing=locked \
    apt-get update && apt-get install -y --no-install-recommends \
      ca-certificates \
      curl \
      git \
      python3 \
      python3-dev \
      python3-venv \
      build-essential \
      pkg-config \
      libxrender1 \
      libx11-6 \
      libxext6 \
    && rm -rf /var/lib/apt/lists/* \
    && ln -sf /usr/bin/python3 /usr/bin/python

RUN --mount=type=cache,target=/root/.cache/uv \
    curl -LsSf https://astral.sh/uv/install.sh | sh \
    && . "$HOME/.local/bin/env" \
    && uv venv --python /usr/bin/python3 --no-python-downloads "${VIRTUAL_ENV}"

# --no-sources is upstream's own flag: it ignores [tool.uv.sources], so nothing is pulled from Git
# and no credentials are needed. TMol and its operator packages must come from published wheels.
RUN --mount=type=cache,target=/root/.cache/uv \
    . "$HOME/.local/bin/env" \
    && uv pip install --no-sources --only-binary tmol,tmol-ops-cu13 \
        --torch-backend cu130 "rfd4-proteina[all-cuda13]==${RFD4_VERSION}" hf_transfer

RUN mkdir -p /weights/huggingface /data \
    && ln -sfn /weights /models

# snapshot_download rather than loading the model: constructing it needs a GPU, which a build has not.
COPY <<'PY' /tmp/download_weights.py
import os

from huggingface_hub import snapshot_download

repo_id = os.environ["HF_MODEL_REPO"]
revision = os.environ["HF_MODEL_REVISION"]
print(f"Downloading {repo_id}@{revision}...")
path = snapshot_download(repo_id=repo_id, revision=revision)
print(f"Cached {repo_id} -> {path}")
print("Weight download complete")
PY

RUN --mount=type=cache,target=/root/.cache/huggingface \
    set -eux; \
    if [ "${DOWNLOAD_WEIGHTS}" = "true" ]; then \
      export HF_HOME=/root/.cache/huggingface \
             HUGGINGFACE_HUB_CACHE=/root/.cache/huggingface/hub \
             HF_MODEL_REPO="${HF_MODEL_REPO}" \
             HF_MODEL_REVISION="${HF_MODEL_REVISION}"; \
      python /tmp/download_weights.py; \
      hub_src="/root/.cache/huggingface/hub/models--nvidia--RFD4-Proteina"; \
      mkdir -p /weights/huggingface/hub; \
      rm -rf /weights/huggingface/hub/models--nvidia--RFD4-Proteina; \
      cp -a "${hub_src}" /weights/huggingface/hub/; \
      chmod -R a+rX /weights; \
    else \
      echo "Skipping weight download (DOWNLOAD_WEIGHTS=${DOWNLOAD_WEIGHTS}); mount weights at /weights or set HF_HOME"; \
    fi; \
    rm -f /tmp/download_weights.py

# Imports, the TMol CUDA operators, OpenBabel, the BioIR runtime and the CLI.
# torch.compile is not exercised: Inductor needs a GPU, which a build does not have.
RUN python -c 'import torch, atomworks, rfproteina; \
from openbabel import pybel; \
from tmol.score.ljlk.potentials._compiled import ljlk_pose_scores; \
from bionemo_ir._torch.layers.transformers.blocks import ConditionedTransformerBlock; \
assert torch.__version__.endswith("+cu130"), torch.__version__; \
assert pybel.readstring("smi", "CCO").OBMol.NumAtoms() == 3; \
assert callable(ljlk_pose_scores)' \
    && rfd4-generate --help > /dev/null \
    && rfd4-evaluate --help > /dev/null

RUN cat > /README.md <<'EOF'
# RFD4-Proteina (arm64)

Flow-matching biomolecular design with [RFD4-Proteina](https://github.com/RosettaCommons/RFD4-Proteina)
0.0.3, built for arm64 / aarch64 with CUDA 13.

## Provenance

- Source: `rfd4-proteina[all-cuda13]==0.0.3` from PyPI
- Weights: `nvidia/RFD4-Proteina` at revision `a06e2509c7033b010fc43614e9fd840303588502`
  (the commit pinned by `configs/inference.yaml` for 0.0.3), cached under `HF_HOME=/weights/huggingface`
- Base image: nvidia/cuda:13.0.1-cudnn-devel-ubuntu24.04
- PyTorch cu130, cuEquivariance cu13 ops, TMol cu13 operators, and the BioIR runtime
  (`inference_backend=bioir`)

## GPU

NVIDIA GPU with a CUDA 13 driver (580+). Memory use scales with the number of tokens and the
batch size; confirm the longest input fits at `batch_size=1` before raising it.

```bash
cat > binder.yaml <<'YAML'
pdl1_binder:
  input: 5o45_cropped.cif.zst
  contig: "50-120, /0, A17-131"
  conditions:
    C_CRDGRP: {1: [{select: "sel('A/*/*/[N,CA,C,O]')"}]}
    C_SEQ: {true: [{select: "sel('A')"}]}
    C_HOT: {true: [{select: "sel('A/*/56/[CG,OH]')"}]}
YAML

docker run --gpus all --rm \
  -v "$(pwd)":/data -w /data \
  ghcr.io/australian-protein-design-initiative/containers/rfd4-proteina:0.0.3_nv-cuda13-arm64 \
  rfd4-generate inputs=binder.yaml num_replicates=4 batch_size=1 out_dir=./runs/binder '~metrics'
```

`'~metrics'` skips inline scoring, which otherwise needs an AlphaFold 3 / OpenFold3 refolding
environment that is not part of this image. `inference_experiment=quickstart` additionally skips
the `torch.compile` warm-up, which is worth it for a first smoke test and not for a real run.

Designs land in `runs/binder/inference_samples/` as `{example_id}_generated.cif`, with the
conditioned input saved alongside as `{example_id}_input.cif`.

## Notes

- `DATA_PATH=/data` and `HF_HOME=/weights/huggingface` are set in the image. The weights are baked
  in, so `hf_ckpt_path` resolves from the local cache without Hub access.
- Hydra writes its own config snapshot to `./hydra_outputs` in the working directory.
- See the [CLI options reference](https://rfd4-proteina.org/latest/reference/cli-options.html) and
  the [condition-spec reference](https://rfd4-proteina.org/latest/reference/yaml-json.html).
EOF

WORKDIR /data

CMD ["rfd4-generate", "--help"]
