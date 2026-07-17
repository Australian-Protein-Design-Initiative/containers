# arm64 / NVIDIA GB10 (Blackwell) build.
#
# PyRosetta's aarch64 conda builds only go up to 2023.11 (py39/py310 - no py311,
# unlike the amd64 build which uses 2024.42+py3.11), so this env pins python=3.10.
# conda's pytorch-cuda channel only goes up to 11.8 on aarch64 (no GB10 support),
# so PyTorch is installed via pip from the cu130 wheel index instead - the same
# fix used for rc-foundry/boltzgen's GB10 (sm_121) support. biopython 1.81 has no
# aarch64 conda-forge build for py310, so it's installed via pip (built from sdist).
#
# Build like:
#   docker build -t proteinmpnn_dl_binder_design:arm64_py310 .
# Skip optional weight downloads:
#   docker build --build-arg DOWNLOAD_WEIGHTS=false -t proteinmpnn_dl_binder_design:arm64_py310 .

FROM condaforge/miniforge3:latest

LABEL org.opencontainers.image.source="https://github.com/Australian-Protein-Design-Initiative/containers" \
      org.opencontainers.image.title="ProteinMPNN / FastRelax (APDI fork, arm64/GB10)" \
      org.opencontainers.image.description="ProteinMPNN interface design with Rosetta FastRelax (dl_binder_design APDI fork) — arm64/GB10 build, includes HyperMPNN and PottsMPNN weights" \
      org.opencontainers.image.version="7f813d9" \
      org.opencontainers.image.revision="7f813d9" \
      org.opencontainers.image.licenses="MIT" \
      org.opencontainers.image.vendor="Australian Protein Design Initiative" \
      org.opencontainers.image.base.name="docker.io/condaforge/miniforge3:latest" \
      org.opencontainers.image.usage="docker run --rm --gpus all -v \$(pwd)/workdir:/workspace proteinmpnn_dl_binder_design:arm64_py310 python /app/dl_binder_design/mpnn_fr/dl_interface_design.py"

LABEL org.australian-protein-design-initiative.image.platforms="linux/arm64"

ARG GIT_REPO=https://github.com/Australian-Protein-Design-Initiative/dl_binder_design
# main with ipTM, ipSAE added
ARG GIT_REF=7f813d9
ARG PROTEINMPNN_REPO=https://github.com/dauparas/ProteinMPNN.git
ARG PROTEINMPNN_REF=8907e66

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    git \
    wget \
    && rm -rf /var/lib/apt/lists/*

# Install into a dedicated env (not base): PyRosetta pins zlib <1.3, which
# conflicts with Miniforge base's mamba/zstd stack.
RUN mamba create -y -n proteinmpnn python=3.10 \
    && mamba install -y -n proteinmpnn \
        -c https://conda.rosettacommons.org \
        -c conda-forge \
        pyrosetta=2023.11+release.fe5f8333f1c \
        ml-collections=1.0.0 \
        "numpy<2" \
    && mamba clean -afy

ENV PATH="/opt/conda/envs/proteinmpnn/bin:${PATH}"

# biopython 1.81 has no aarch64 conda-forge build for py310 - install via pip
# (built from sdist).
RUN pip install --no-cache-dir "biopython==1.81"

# PyTorch via pip cu130 wheel index for GB10 (sm_121) support - see note above.
RUN pip install --no-cache-dir torch --index-url https://download.pytorch.org/whl/cu130

WORKDIR /app

RUN git clone ${GIT_REPO} /app/dl_binder_design && \
    cd /app/dl_binder_design && \
    git checkout ${GIT_REF}

RUN git clone ${PROTEINMPNN_REPO} /app/dl_binder_design/mpnn_fr/ProteinMPNN && \
    cd /app/dl_binder_design/mpnn_fr/ProteinMPNN && \
    git checkout ${PROTEINMPNN_REF}

RUN python /app/dl_binder_design/include/importtests/proteinmpnn_importtest.py

# ProteinMPNN weights ship with the ProteinMPNN clone; expose them under /models/ProteinMPNN
RUN mkdir -p /models/ProteinMPNN && \
    ln -s /app/dl_binder_design/mpnn_fr/ProteinMPNN/vanilla_model_weights /models/ProteinMPNN/vanilla_model_weights && \
    ln -s /app/dl_binder_design/mpnn_fr/ProteinMPNN/soluble_model_weights /models/ProteinMPNN/soluble_model_weights && \
    ln -s /app/dl_binder_design/mpnn_fr/ProteinMPNN/ca_model_weights /models/ProteinMPNN/ca_model_weights

# Download HyperMPNN and PottsMPNN weights into the image at build time.
# Skip this layer and mount weights at runtime by using --build-arg DOWNLOAD_WEIGHTS=false
# (then pass -v /path/to/HyperMPNN:/models/HyperMPNN and
#  -v /path/to/PottsMPNN:/models/PottsMPNN at docker run time).
ARG DOWNLOAD_WEIGHTS=true
RUN if [ "${DOWNLOAD_WEIGHTS}" = "true" ]; then \
        mkdir -p /models/HyperMPNN && \
        cd /models/HyperMPNN && \
        wget https://github.com/meilerlab/HyperMPNN/raw/refs/heads/main/retrained_models/v48_002_epoch240_hyper.pt && \
        wget https://github.com/meilerlab/HyperMPNN/raw/refs/heads/main/retrained_models/v48_010_epoch300_hyper.pt && \
        wget https://github.com/meilerlab/HyperMPNN/raw/refs/heads/main/retrained_models/v48_020_epoch300_hyper.pt && \
        wget https://github.com/meilerlab/HyperMPNN/raw/refs/heads/main/retrained_models/v48_030_epoch300_hyper.pt && \
        mkdir -p /models/PottsMPNN && \
        cd /models/PottsMPNN && \
        wget https://github.com/KeatingLab/PottsMPNN/raw/refs/heads/main/proteinmpnn_compatible_model_weights/pottsmpnn_20.pt && \
        wget https://github.com/KeatingLab/PottsMPNN/raw/refs/heads/main/proteinmpnn_compatible_model_weights/pottsmpnn_30.pt && \
        wget https://github.com/KeatingLab/PottsMPNN/raw/refs/heads/main/proteinmpnn_compatible_model_weights/pottsmpnn_msa_20.pt && \
        wget https://github.com/KeatingLab/PottsMPNN/raw/refs/heads/main/proteinmpnn_compatible_model_weights/sol_pottsmpnn_20.pt && \
        wget https://github.com/KeatingLab/PottsMPNN/raw/refs/heads/main/proteinmpnn_compatible_model_weights/sol_pottsmpnn_30.pt && \
        wget https://github.com/KeatingLab/PottsMPNN/raw/refs/heads/main/proteinmpnn_compatible_model_weights/sol_pottsmpnn_msa_20.pt; \
    fi

CMD ["python", "/app/dl_binder_design/mpnn_fr/dl_interface_design.py"]
