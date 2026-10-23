# syntax=docker/dockerfile:1.4
# Build like:
#   just build rfd4-proteina/0.0.3-aaccdd2_nv-cuda13 --pull
# Skip the weight download (~1.7 GB):
#   just build rfd4-proteina/0.0.3-aaccdd2_nv-cuda13 --variant no-weights
#
# RFD4-Proteina 0.0.3 at upstream commit aaccdd2, with CUDA 13 / PyTorch cu130, for amd64 / x86_64.
# The arm64 sibling is rfd4-proteina/0.0.3-aaccdd2_nv-cuda13-arm64, and the two differ only in the
# base image digest.
#
# NOT YET BUILT OR TESTED: the only hardware available when this was written was arm64, so this file
# has been written to match the proven arm64 build rather than verified on an amd64 host.
#
# Upstream ships its own Dockerfile and Apptainer definition on a python:3.12-slim base, relying on
# the CUDA libraries that come with the PyTorch wheels. This image uses the CUDA 13 devel base
# instead, to keep it identical to the arm64 build and because torch.compile (on by default here)
# invokes a CUDA toolchain at run time. Upstream's base is the alternative if a smaller image
# matters more than that: see https://github.com/RosettaCommons/RFD4-Proteina/blob/main/Dockerfile.
#
# Installed from the upstream source tree at a pinned commit rather than the PyPI wheel, following
# upstream's own apptainer/rfd4-proteina.def: dependencies resolved from pyproject.toml, then the
# package itself with --no-deps.
#
# Bakes in the nvidia/RFD4-Proteina model bundle - config.json and model.safetensors, ~1.7 GB -
# at the Hub revision pinned by configs/inference.yaml, so a run needs no Hub access.

ARG RFD4_VERSION=0.0.3
ARG RFD4_REPO=https://github.com/RosettaCommons/RFD4-Proteina.git
ARG RFD4_COMMIT=aaccdd2
ARG HF_MODEL_REPO=nvidia/RFD4-Proteina
ARG HF_MODEL_REVISION=a06e2509c7033b010fc43614e9fd840303588502
ARG DOWNLOAD_WEIGHTS=true
# Minimum uv is 0.13.4, the first release with the emSign CA fix (python.org announcement, 2026-10-20).
ARG UV_VERSION=0.13.5
ARG BASE_IMAGE=nvidia/cuda:13.0.1-cudnn-devel-ubuntu24.04

FROM ${BASE_IMAGE}

ARG RFD4_VERSION
ARG RFD4_REPO
ARG RFD4_COMMIT
ARG HF_MODEL_REPO
ARG HF_MODEL_REVISION
ARG DOWNLOAD_WEIGHTS
ARG UV_VERSION

LABEL org.opencontainers.image.source=https://github.com/Australian-Protein-Design-Initiative/containers
LABEL org.opencontainers.image.url="https://github.com/RosettaCommons/RFD4-Proteina"
LABEL org.opencontainers.image.documentation="https://rfd4-proteina.org/latest/"
LABEL org.opencontainers.image.title="RFD4-Proteina"
LABEL org.opencontainers.image.description="RFD4-Proteina 0.0.3 (upstream aaccdd2) flow-matching biomolecular design with CUDA 13 on amd64, cuEquivariance and BioIR kernels, and baked-in nvidia/RFD4-Proteina weights"
LABEL org.opencontainers.image.licenses="BSD-3-Clause"
LABEL org.opencontainers.image.version="${RFD4_VERSION}"
LABEL org.opencontainers.image.revision="${RFD4_COMMIT}"
LABEL org.opencontainers.image.base.name="docker.io/nvidia/cuda:13.0.1-cudnn-devel-ubuntu24.04"
LABEL org.opencontainers.image.base.digest="sha256:5a2d3b02eb7412847d051d0f2b0f0a5031057a0172d9ca78743cc41cfc5d037f"
LABEL org.opencontainers.image.usage="docker run --gpus all --rm -v \$(pwd):/data -w /data rfd4-proteina:0.0.3-aaccdd2_nv-cuda13 rfd4-generate inference_experiment=quickstart inputs=binder.yaml out_dir=./runs/first"
LABEL org.australian-protein-design-initiative.image.platforms="linux/amd64"

ENV DEBIAN_FRONTEND=noninteractive \
    LANG=C.UTF-8 \
    LC_ALL=C.UTF-8 \
    PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1 \
    PYTHONNOUSERSITE=1 \
    PIP_DISABLE_PIP_VERSION_CHECK=1 \
    VIRTUAL_ENV=/opt/venv \
    PATH="/opt/venv/bin:${PATH}" \
    UV_SYSTEM_CERTS=1 \
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
# ca-certificates is refreshed so the system trust store is the newest the distro offers; the
# eMudhra/emSign CA was distrusted in October 2026 and UV_SYSTEM_CERTS=1 makes uv use this store.
# Upstream additionally reinstalls pip, because its python:3.12-slim base bundles a certifi that
# still trusts that CA. Nothing here installs through pip, so that step has no equivalent.
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
    curl -LsSf "https://astral.sh/uv/${UV_VERSION}/install.sh" | sh \
    && . "$HOME/.local/bin/env" \
    && uv --version \
    && uv venv --python /usr/bin/python3 --no-python-downloads "${VIRTUAL_ENV}"

RUN git clone --filter=blob:none "${RFD4_REPO}" /opt/rfd4 \
    && git -C /opt/rfd4 checkout --detach "${RFD4_COMMIT}" \
    && git -C /opt/rfd4 rev-parse HEAD > /opt/rfd4-commit.txt \
    && rm -rf /opt/rfd4/.git

# --no-sources is upstream's own flag: it ignores [tool.uv.sources], so nothing is pulled from Git
# and no credentials are needed. TMol and its operator packages must come from published wheels.
# The certifi floor stops any resolution installing a copy that still trusts the distrusted CA; it
# is a constraint, so it only applies when certifi is pulled in and never adds the package itself.
RUN --mount=type=cache,target=/root/.cache/uv \
    . "$HOME/.local/bin/env" \
    && printf 'certifi>=2026.10.19\n' > /tmp/rfd4-constraints.txt \
    && uv pip install --no-sources -c /tmp/rfd4-constraints.txt \
        --only-binary tmol,tmol-ops-cu13 --torch-backend cu130 \
        --extra all-cuda13 -r /opt/rfd4/pyproject.toml \
    && uv pip install --no-sources --no-deps /opt/rfd4 \
    && uv pip install -c /tmp/rfd4-constraints.txt hf_transfer \
    && rm -f /tmp/rfd4-constraints.txt \
    && uv pip list | grep -iE '^(certifi|torch|rfd4-proteina|tmol) ' || true

RUN mkdir -p /weights/huggingface /data \
    && ln -sfn /weights /models

# snapshot_download rather than loading the model: constructing it needs a GPU, which a build has not.
COPY <<'PY' /tmp/download_weights.py
import os

from huggingface_hub import snapshot_download

# The same allow_patterns rfproteina.utils.hub.load_pretrained_bundle uses, so the run-time
# call is satisfied from this cache and never reaches the network. The whole repository is
# 82 GB, nearly all of it amd64 Apptainer images for the AlphaFold 2 / OpenFold 3 refolding
# environments, which this image has no use for: the inline metrics group is not run here.
PATTERNS = ["config.json", "model.safetensors"]

repo_id = os.environ["HF_MODEL_REPO"]
revision = os.environ["HF_MODEL_REVISION"]
print(f"Downloading {repo_id}@{revision} ({', '.join(PATTERNS)})...")
path = snapshot_download(repo_id=repo_id, revision=revision, allow_patterns=PATTERNS)
print(f"Cached {repo_id} -> {path}")
for name in PATTERNS:
    full = os.path.join(path, name)
    if not os.path.isfile(full):
        raise SystemExit(f"Expected {name} in the snapshot, but it is missing")
    print(f"  {name}: {os.path.getsize(full) / 1e9:.3f} GB")
print("Weight download complete")
PY

# Downloaded straight into the image rather than into a build cache and copied across.
# With Xet storage on, the entries under <repo>/blobs/ are themselves symlinks into a chunk
# cache at <hub>/blobs/, outside the repo directory, so copying the repo directory alone
# leaves an image whose weights are dangling symlinks - a fault that shows up only at run
# time, and only where there is no network access to silently re-download them. No cache
# mount here means no layout to get wrong; the disadvantage is that a rebuild of this layer
# re-fetches the bundle. HF_HUB_DISABLE_XET additionally keeps the tree in the classic
# layout, so the whole /weights directory stays self-contained and relocatable.
RUN set -eux; \
    if [ "${DOWNLOAD_WEIGHTS}" = "true" ]; then \
      export HF_HOME=/weights/huggingface \
             HUGGINGFACE_HUB_CACHE=/weights/huggingface/hub \
             HF_HUB_DISABLE_XET=1 \
             HF_MODEL_REPO="${HF_MODEL_REPO}" \
             HF_MODEL_REVISION="${HF_MODEL_REVISION}"; \
      python /tmp/download_weights.py; \
      chmod -R a+rX /weights; \
      broken="$(find /weights -xtype l | head -20)"; \
      if [ -n "${broken}" ]; then \
        echo "Baked weights have dangling symlinks:" >&2; echo "${broken}" >&2; exit 1; \
      fi; \
      du -shL /weights/huggingface/hub/models--nvidia--RFD4-Proteina; \
    else \
      echo "Skipping weight download (DOWNLOAD_WEIGHTS=${DOWNLOAD_WEIGHTS}); mount weights at /weights or set HF_HOME"; \
    fi; \
    rm -f /tmp/download_weights.py

# Imports, the TMol CUDA operators, OpenBabel, the BioIR runtime and the CLIs. This is upstream's
# apptainer/smoke_test.py minus the torch.compile check, which needs a GPU that a build does not have.
RUN python -c 'import torch, atomworks, rfproteina; \
from importlib.metadata import distributions; \
from openbabel import pybel; \
from tmol.score.ljlk.potentials._compiled import ljlk_pose_scores; \
from bionemo_ir._torch.layers.transformers.blocks import ConditionedTransformerBlock; \
assert torch.__version__.endswith("+cu130"), torch.__version__; \
assert pybel.readstring("smi", "CCO").OBMol.NumAtoms() == 3; \
assert callable(ljlk_pose_scores); \
ops = {d.metadata["Name"].lower().replace("_", "-") for d in distributions()}; \
assert "tmol-ops-cu13" in ops' \
    && rfd4-generate --help > /dev/null \
    && rfd4-evaluate --help > /dev/null

RUN cat > /README.md <<'EOF'
# RFD4-Proteina

Flow-matching biomolecular design with [RFD4-Proteina](https://github.com/RosettaCommons/RFD4-Proteina)
0.0.3, built for amd64 / x86_64 with CUDA 13.

This image is the amd64 counterpart of the `_nv-cuda13-arm64` tag, which is the one that has been
run end to end. The two Dockerfiles differ only in the base image digest.

## Provenance

- Source: the upstream repository at commit `aaccdd2`, installed as upstream's own Apptainer
  definition does (dependencies from `pyproject.toml` with the `all-cuda13` extra, then the package
  with `--no-deps`). The source tree is left at `/opt/rfd4` and the resolved commit at
  `/opt/rfd4-commit.txt`.
- Weights: `nvidia/RFD4-Proteina` at revision `a06e2509c7033b010fc43614e9fd840303588502`
  (the commit pinned by `configs/inference.yaml`), cached under `HF_HOME=/weights/huggingface`
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
  ghcr.io/australian-protein-design-initiative/containers/rfd4-proteina:0.0.3-aaccdd2_nv-cuda13 \
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
- `rfd4-generate` can deadlock on its dataloader when it uses worker processes; pass
  `num_workers=0` if a run hangs before the first sampling step with the GPU idle.
- See the [CLI options reference](https://rfd4-proteina.org/latest/reference/cli-options.html) and
  the [condition-spec reference](https://rfd4-proteina.org/latest/reference/yaml-json.html).
EOF

WORKDIR /data

CMD ["rfd4-generate", "--help"]
