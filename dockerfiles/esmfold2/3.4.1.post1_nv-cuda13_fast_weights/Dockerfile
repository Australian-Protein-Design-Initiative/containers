# syntax=docker/dockerfile:1.4
# Build like:
#   just build esmfold2/3.4.1.post1_nv-cuda13_fast_weights
#   docker buildx build -t esmfold2:3.4.1.post1_nv-cuda13_fast_weights -f Dockerfile .
# Skip weight download (~25 GB):
#   just build esmfold2/3.4.1.post1_nv-cuda13_fast_weights --variant no-weights
#
# ESM 3.4.1.post1 with CUDA 13 / PyTorch 2.11 cu130.
# Bakes in biohub/ESMFold2-Fast (single-sequence, self-contained checkpoint).
# Sibling image: esmfold2:3.4.1.post1_nv-cuda13_full_weights
# Also fetches ccd.pkl from biohub/ESMFold2 (~0.4 GB; not shipped with Fast).

ARG GIT_REPO=https://github.com/Biohub/esm.git
ARG GIT_REF=v3.4.1.post1
ARG DOWNLOAD_WEIGHTS=true
ARG HF_MODEL_REPO=biohub/ESMFold2-Fast
ARG HF_MODEL_NAME=ESMFold2-Fast
ARG BASE_IMAGE=nvidia/cuda:13.0.1-cudnn-devel-ubuntu24.04

FROM ${BASE_IMAGE}

ARG GIT_REPO
ARG GIT_REF
ARG DOWNLOAD_WEIGHTS
ARG HF_MODEL_REPO
ARG HF_MODEL_NAME

LABEL org.opencontainers.image.source=https://github.com/Australian-Protein-Design-Initiative/containers
LABEL org.opencontainers.image.url="${GIT_REPO}"
LABEL org.opencontainers.image.documentation="https://github.com/Biohub/esm#esmfold2"
LABEL org.opencontainers.image.title="ESMFold2-Fast"
LABEL org.opencontainers.image.description="ESMFold2-Fast structure prediction (esm 3.4.1.post1) with CUDA 13, cuEquivariance, fused Triton kernels, and baked-in biohub/ESMFold2-Fast weights"
LABEL org.opencontainers.image.licenses="MIT"
LABEL org.opencontainers.image.revision="${GIT_REF}"
LABEL org.opencontainers.image.version="3.4.1.post1"
LABEL org.opencontainers.image.base.name="docker.io/nvidia/cuda:13.0.1-cudnn-devel-ubuntu24.04"
LABEL org.opencontainers.image.base.digest="sha256:8b2705ea7a8653ad3451b46ab835eced92d77b44e671b9cf3ad4f95fbb2efe5e"
LABEL org.opencontainers.image.usage="docker run --gpus all --rm -v \$(pwd):/data -w /data esmfold2:3.4.1.post1_nv-cuda13_fast_weights esmfold2 -s MQIFVKTLTGKTITLEVEPSDTIENVKAKIQDKEGIPPDQQRLIFAGKQLEDGRTLSDYNIQKESTLHLVLRLRGG -o ubq.cif"
LABEL org.australian-protein-design-initiative.image.platforms="linux/amd64"

ENV DEBIAN_FRONTEND=noninteractive \
    LANG=C.UTF-8 \
    LC_ALL=C.UTF-8 \
    PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1 \
    PIP_DISABLE_PIP_VERSION_CHECK=1 \
    VIRTUAL_ENV=/opt/venv \
    PATH="/opt/venv/bin:${PATH}" \
    CUDA_HOME=/usr/local/cuda \
    HF_HOME=/weights/huggingface \
    HUGGINGFACE_HUB_CACHE=/weights/huggingface/hub \
    HF_HUB_ENABLE_HF_TRANSFER=1 \
    HF_XET_HIGH_PERFORMANCE=1 \
    ESMCFOLD_CCD_PATH=/weights/esmfold2/ccd.pkl \
    ESMFOLD2_DEFAULT_MODEL=biohub/ESMFold2-Fast \
    NVIDIA_VISIBLE_DEVICES=all \
    NVIDIA_DRIVER_CAPABILITIES=compute,utility

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
      libxext6 \
      libsm6 \
      libglib2.0-0 \
      libgomp1 \
    && rm -rf /var/lib/apt/lists/* \
    && ln -sf /usr/bin/python3 /usr/bin/python

RUN --mount=type=cache,target=/root/.cache/uv \
    curl -LsSf https://astral.sh/uv/install.sh | sh \
    && . "$HOME/.local/bin/env" \
    && uv venv --python /usr/bin/python3 --no-python-downloads "${VIRTUAL_ENV}"

WORKDIR /app

RUN git clone --depth 1 --branch "${GIT_REF}" "${GIT_REPO}" .

# PyTorch 2.11 CUDA 13 wheels (required by esm 3.4.1), then esm[fused].
RUN --mount=type=cache,target=/root/.cache/pip \
    --mount=type=cache,target=/root/.cache/uv \
    . "$HOME/.local/bin/env" \
    && uv pip install torch==2.11.0 --index-url https://download.pytorch.org/whl/cu130 \
    && uv pip install ".[fused]" hf_transfer huggingface_hub \
    && uv pip install \
         "https://github.com/evolutionaryscale/wheels/releases/download/py312-pt211-cu13-sm80-90/flash_attn-2.7.4.post1-cp312-cp312-linux_x86_64.whl"

RUN mkdir -p /weights/esmfold2 /weights/huggingface \
    && ln -sfn /weights /models

# snapshot_download (not from_pretrained): importing fused Triton kernels needs a GPU.
# Fast does not ship ccd.pkl; pull that single file from biohub/ESMFold2.
COPY <<'PY' /tmp/download_weights.py
import os
import shutil
from pathlib import Path

from huggingface_hub import hf_hub_download, snapshot_download

repo_id = os.environ["HF_MODEL_REPO"]
name = os.environ["HF_MODEL_NAME"]
print(f"Downloading {repo_id}...")
path = snapshot_download(repo_id=repo_id)
print(f"Cached {repo_id} -> {path}")

ccd = hf_hub_download(repo_id="biohub/ESMFold2", filename="ccd.pkl")
dest = Path("/weights/esmfold2/ccd.pkl")
dest.parent.mkdir(parents=True, exist_ok=True)
shutil.copy2(ccd, dest)
print(f"Copied ccd.pkl -> {dest}")
print("Weight download complete")
PY

# Copy only this variant's hub repo out of the shared BuildKit HF cache.
# A blanket `cp -a` of the cache would also bake in ESMFold2 / ESMC-6B from
# earlier builds that share the same mount (~78 GB).
RUN --mount=type=cache,target=/root/.cache/huggingface \
    set -eux; \
    if [ "${DOWNLOAD_WEIGHTS}" = "true" ]; then \
      export HF_HOME=/root/.cache/huggingface \
             HUGGINGFACE_HUB_CACHE=/root/.cache/huggingface/hub \
             HF_MODEL_REPO="${HF_MODEL_REPO}" \
             HF_MODEL_NAME="${HF_MODEL_NAME}"; \
      python /tmp/download_weights.py; \
      hub_src="/root/.cache/huggingface/hub/models--biohub--${HF_MODEL_NAME}"; \
      mkdir -p /weights/huggingface/hub; \
      rm -rf "/weights/huggingface/hub/models--biohub--${HF_MODEL_NAME}"; \
      cp -a "${hub_src}" /weights/huggingface/hub/; \
      snap=$(ls -d /weights/huggingface/hub/models--biohub--${HF_MODEL_NAME}/snapshots/* | head -1); \
      ln -sfn "${snap}" "/weights/esmfold2/${HF_MODEL_NAME}"; \
      # ccd.pkl already written to /weights/esmfold2/ccd.pkl by download script
      chmod -R a+rX /weights; \
    else \
      echo "Skipping weight download (DOWNLOAD_WEIGHTS=${DOWNLOAD_WEIGHTS}); mount weights at /weights or set HF_HOME"; \
    fi; \
    rm -f /tmp/download_weights.py

# Offline after bake-in so runtime never phones home (and avoids read-only cache warnings).
# Set after the download RUN so build-time snapshot_download can still reach the Hub.
ENV HF_HUB_OFFLINE=1 \
    TRANSFORMERS_OFFLINE=1

RUN cat > /usr/local/bin/esmfold2 <<'EOF'
#!/usr/bin/env python
"""Fold protein sequences with ESMFold2-Fast."""

from __future__ import annotations

import argparse
import logging
import os
import sys
from pathlib import Path

logging.basicConfig(level=logging.INFO, format="%(levelname)s: %(message)s", stream=sys.stderr)
log = logging.getLogger("esmfold2")

MODEL_ALIASES = {
    "fast": "biohub/ESMFold2-Fast",
    "esmfold2-fast": "biohub/ESMFold2-Fast",
    "full": "biohub/ESMFold2",
    "esmfold2": "biohub/ESMFold2",
    "biohub/esmfold2-fast": "biohub/ESMFold2-Fast",
    "biohub/esmfold2": "biohub/ESMFold2",
}


def _resolve_model(name: str) -> str:
    key = name.strip()
    return MODEL_ALIASES.get(key.lower(), key)


def _read_fasta(path: Path) -> list[tuple[str, str]]:
    from Bio import SeqIO

    records = [(rec.id, str(rec.seq).replace(" ", "").replace("\n", "")) for rec in SeqIO.parse(path, "fasta")]
    if not records:
        raise SystemExit(f"no FASTA records in {path}")
    return records


def _write_text(path: str, text: str) -> None:
    if path == "-":
        sys.stdout.write(text)
        if not text.endswith("\n"):
            sys.stdout.write("\n")
        return
    out = Path(path)
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(text)
    log.info("wrote %s", out)


def main() -> None:
    default_model = os.environ.get("ESMFOLD2_DEFAULT_MODEL", "biohub/ESMFold2-Fast")
    parser = argparse.ArgumentParser(description="ESMFold2-Fast structure prediction")
    parser.add_argument("fasta", nargs="?", help="FASTA file (one or more protein chains)")
    parser.add_argument("-s", "--sequence", help="Single amino-acid sequence (chain A)")
    parser.add_argument("-o", "--output", default="pred.cif", help="Output mmCIF path, or - for stdout")
    parser.add_argument(
        "--model",
        default=default_model,
        help=f"Hub id or alias (default: {default_model})",
    )
    parser.add_argument(
        "--backend",
        default="cuequivariance",
        choices=["none", "fused", "cuequivariance"],
        help="Kernel backend (default: cuequivariance)",
    )
    parser.add_argument("--num-loops", type=int, default=3)
    parser.add_argument("--num-sampling-steps", type=int, default=50)
    parser.add_argument("--seed", type=int, default=0)
    parser.add_argument("--device", default="cuda")
    args = parser.parse_args()

    if args.sequence and args.fasta:
        parser.error("pass either a FASTA file or --sequence, not both")
    if not args.sequence and not args.fasta:
        parser.error("a FASTA file or --sequence is required")

    from esm.models.esmfold2 import (
        ESMFold2InputBuilder,
        EsmFold2Model,
        ProteinInput,
        StructurePredictionInput,
    )

    if args.sequence:
        chains = [("A", args.sequence.strip())]
    else:
        chains = _read_fasta(Path(args.fasta))

    repo = _resolve_model(args.model)
    backend = None if args.backend == "none" else args.backend
    log.info("loading %s on %s (backend=%s)", repo, args.device, backend)
    model = EsmFold2Model.from_pretrained(repo, device=args.device).eval()
    model.set_kernel_backend(backend)

    spi = StructurePredictionInput(
        sequences=[ProteinInput(id=chain_id, sequence=seq) for chain_id, seq in chains]
    )
    result = ESMFold2InputBuilder().fold(
        model,
        spi,
        num_loops=args.num_loops,
        num_sampling_steps=args.num_sampling_steps,
        num_diffusion_samples=1,
        seed=args.seed,
    )
    log.info(
        "pLDDT mean: %.3f  pTM: %.3f  ipTM: %.3f",
        float(result.plddt.mean()),
        float(result.ptm),
        float(result.iptm),
    )
    _write_text(args.output, result.complex.to_mmcif())


if __name__ == "__main__":
    main()
EOF
RUN chmod +x /usr/local/bin/esmfold2

RUN cat > /README.md <<'EOF'
# ESMFold2-Fast

Protein / biomolecule structure prediction with [ESMFold2-Fast](https://huggingface.co/biohub/ESMFold2-Fast)
from [Biohub/esm](https://github.com/Biohub/esm) 3.4.1.post1.

## Provenance

- Source: https://github.com/Biohub/esm.git @ v3.4.1.post1
- Weights: `biohub/ESMFold2-Fast` (~25 GB self-contained, single-sequence) under `HF_HOME=/weights/huggingface`
- CCD pickle (from biohub/ESMFold2): `ESMCFOLD_CCD_PATH=/weights/esmfold2/ccd.pkl`
- Base image: nvidia/cuda:13.0.1-cudnn-devel-ubuntu24.04
- PyTorch 2.11 (cu130) + cuequivariance-ops-torch-cu13 + fused Triton kernels + FlashAttention 2.7.4
- Full / MSA-capable variant: `esmfold2:3.4.1.post1_nv-cuda13_full_weights`
- Runtime: `HF_HUB_OFFLINE=1` / `TRANSFORMERS_OFFLINE=1` (baked weights; no Hub access required)

## GPU

NVIDIA GPU with CUDA 13 driver (580+) and plenty of VRAM (typically 40–80 GB).

```bash
docker run --gpus all --rm \
  -v "$(pwd)":/data -w /data \
  ghcr.io/australian-protein-design-initiative/containers/esmfold2:3.4.1.post1_nv-cuda13_fast_weights \
  esmfold2 -s MQIFVKTLTGKTITLEVEPSDTIENVKAKIQDKEGIPPDQQRLIFAGKQLEDGRTLSDYNIQKESTLHLVLRLRGG \
    -o ubq.cif
```

Kernel backends: `--backend cuequivariance` (default), `fused` (Triton), or `none` (PyTorch).

## Python usage

```python
from esm.models.esmfold2 import ESMFold2InputBuilder, EsmFold2Model, ProteinInput, StructurePredictionInput

model = EsmFold2Model.from_pretrained("biohub/ESMFold2-Fast", device="cuda").eval()
model.set_kernel_backend("cuequivariance")
spi = StructurePredictionInput(sequences=[ProteinInput(id="A", sequence="MQIFVKTLTGKT...")])
result = ESMFold2InputBuilder().fold(model, spi, num_loops=3, num_sampling_steps=50, seed=0)
open("pred.cif", "w").write(result.complex.to_mmcif())
```

See the [upstream README](https://github.com/Biohub/esm#esmfold2) and
[tutorial](https://github.com/Biohub/esm/blob/v3.4.1/cookbook/tutorials/esmfold2.ipynb).
EOF

WORKDIR /data

CMD ["esmfold2", "--help"]
