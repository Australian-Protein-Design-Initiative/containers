# Build like:
#   just build iggm/2026-05-28_06abc56_nv-cuda11_weights
#   docker build -t iggm:2026-05-28_06abc56_nv-cuda11_weights .
# Skip weight downloads:
#   docker build --build-arg DOWNLOAD_WEIGHTS=false -t iggm:2026-05-28_06abc56_nv-cuda11_no-weights .

FROM condaforge/miniforge3:latest

LABEL org.opencontainers.image.source="https://github.com/Australian-Protein-Design-Initiative/containers" \
      org.opencontainers.image.url="https://github.com/TencentAI4S/IgGM" \
      org.opencontainers.image.title="IgGM" \
      org.opencontainers.image.description="IgGM: generative foundation model for antibody and nanobody design (structure prediction, CDR design, inverse design, affinity maturation, humanization)" \
      org.opencontainers.image.version="06abc56" \
      org.opencontainers.image.revision="06abc56" \
      org.opencontainers.image.licenses="MIT" \
      org.opencontainers.image.vendor="Australian Protein Design Initiative" \
      org.opencontainers.image.base.name="docker.io/condaforge/miniforge3:latest" \
      org.opencontainers.image.base.digest="sha256:9b8b865717cbc861a565fb938f99ee32ec672b186f92b8ec8c17cd2fa9150ad6" \
      org.opencontainers.image.usage="docker run --rm --gpus all -v \$(pwd)/workdir:/workdir -w /workdir iggm:2026-05-28_06abc56_nv-cuda11_weights python /app/design.py --fasta /workdir/input.fasta --antigen /workdir/antigen.pdb" \
      org.australian-protein-design-initiative.image.platforms="linux/amd64"

ARG GIT_REPO=https://github.com/TencentAI4S/IgGM.git
ARG GIT_REF=06abc56

ENV DEBIAN_FRONTEND=noninteractive \
    PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1

RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt,sharing=locked \
    apt-get update && apt-get install -y --no-install-recommends \
        build-essential \
        git \
        wget \
        ca-certificates \
        procps \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

RUN git clone "${GIT_REPO}" . && git checkout "${GIT_REF}"

# Upstream pinned env: Python 3.10 + PyTorch 2.0.1 + CUDA 11.7
# Skip mamba clean while /opt/conda/pkgs is a cache mount (Device or resource busy).
RUN --mount=type=cache,target=/opt/conda/pkgs \
    mamba env create -n IgGM -f environment.yaml

ENV ENV_DIR=/opt/conda/envs/IgGM
ENV PATH="${ENV_DIR}/bin:${PATH}"
ENV LD_LIBRARY_PATH="${ENV_DIR}/lib"
# Prefer conda libstdc++ over the host/glibc copy (GLIBCXX mismatches with torch/CUDA)
ENV LD_PRELOAD="${ENV_DIR}/lib/libstdc++.so.6"
# environment.yaml only pulls in the CUDA runtime (cudatoolkit), not nvcc, so
# deepspeed's op_builder can't find $CUDA_HOME/bin/nvcc and raises
# MissingCUDAException on import (crashes GatedMultiheadAttention's
# `from deepspeed.ops.deepspeed4science import ...`, which only catches
# ImportError). Install cuda-nvcc to match and point CUDA_HOME at the env.
ENV CUDA_HOME="${ENV_DIR}"

# Pip deps from environment.yaml (timm/deepspeed/etc.) can upgrade torch past the
# pinned CUDA 11.7 build; restore the upstream stack and keep setuptools with
# pkg_resources (needed by pdbfixer).
RUN --mount=type=cache,target=/opt/conda/pkgs \
    --mount=type=cache,target=/root/.cache/pip \
    pip uninstall -y torch torchvision torchaudio 2>/dev/null || true \
    && mamba install -y -n IgGM --force-reinstall \
        "pytorch=2.0.1" "pytorch-cuda=11.7" "cuda-nvcc=11.7" \
        -c pytorch -c nvidia \
    && pip install --force-reinstall --no-cache-dir "setuptools>=69,<81" \
    && pip install --no-deps --no-cache-dir \
        pyg_lib torch_scatter torch_sparse torch_cluster torch_spline_conv \
        -f https://data.pyg.org/whl/torch-2.0.1+cu117.html

# Optional PyRosetta for --relax (side-chain packing / FastRelax)
ARG INSTALL_PYROSETTA=false
RUN --mount=type=cache,target=/root/.cache/pip \
    if [ "${INSTALL_PYROSETTA}" = "true" ]; then \
        pip install --no-cache-dir \
            "https://west.rosettacommons.org/pyrosetta/release/release/PyRosetta4.Release.python310.ubuntu.wheel/pyrosetta-2025.37+release.df75a9c48e-cp310-cp310-linux_x86_64.whl"; \
    fi

# Pretrained weights from Zenodo → /app/checkpoints (BuildKit cache speeds rebuilds)
ARG DOWNLOAD_WEIGHTS=true
RUN --mount=type=cache,target=/var/cache/iggm-weights \
    mkdir -p /app/checkpoints /models/iggm /var/cache/iggm-weights \
    && if [ "${DOWNLOAD_WEIGHTS}" = "true" ]; then \
        for f in \
            antibody_design_trunk.pth \
            antibody_fr_design_trunk.pth \
            antibody_inverse_design_trunk.pth \
            esm_ppi_650m_ab.pth \
            igso3_buffer.pth; do \
            if [ ! -s "/var/cache/iggm-weights/${f}" ]; then \
                wget -O "/var/cache/iggm-weights/${f}" \
                    "https://zenodo.org/records/16909543/files/${f}?download=1"; \
            fi; \
            cp "/var/cache/iggm-weights/${f}" "/app/checkpoints/${f}"; \
        done \
        && ln -s /app/checkpoints /models/iggm/checkpoints; \
    else \
        echo "Skipping weight download (DOWNLOAD_WEIGHTS=${DOWNLOAD_WEIGHTS}); mount weights at /app/checkpoints"; \
        ln -s /app/checkpoints /models/iggm/checkpoints; \
    fi

RUN cat > /README.md <<'READMEEOF'
# IgGM

Image for https://github.com/TencentAI4S/IgGM (GIT_REF pinned in the Dockerfile).

Generative foundation model for antibody / nanobody design: structure prediction,
CDR design, inverse design, affinity maturation, and framework (humanization) design.

## Weights

When built with DOWNLOAD_WEIGHTS=true (default), Zenodo checkpoints are baked into
/app/checkpoints:

- esm_ppi_650m_ab.pth
- antibody_design_trunk.pth
- antibody_inverse_design_trunk.pth
- antibody_fr_design_trunk.pth
- igso3_buffer.pth

Source: https://zenodo.org/records/16909543

For a no-weights build, mount host checkpoints at /app/checkpoints.

## Usage

```bash
docker run --rm --gpus all \
  -v "$(pwd)/workdir:/workdir" \
  -w /workdir \
  ghcr.io/australian-protein-design-initiative/containers/iggm:2026-05-28_06abc56_nv-cuda11_weights \
  python /app/design.py \
    --fasta /workdir/input.fasta \
    --antigen /workdir/antigen.pdb \
    --output /workdir/outputs
```

Optional --relax requires rebuilding with --build-arg INSTALL_PYROSETTA=true.

## Notes

- CUDA 11.7 / PyTorch 2.0.1 via the upstream environment.yaml (amd64).
- LD_PRELOAD forces the conda env libstdc++.so.6 to avoid GLIBCXX mismatches.
READMEEOF

WORKDIR /app
CMD ["python", "design.py", "--help"]
