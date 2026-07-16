# Build like:
#   docker build -t proteinmpnn_dl_binder_design:latest .
# Skip optional weight downloads:
#   docker build --build-arg DOWNLOAD_WEIGHTS=false -t proteinmpnn_dl_binder_design:latest .

FROM condaforge/miniforge3:latest

LABEL org.opencontainers.image.source="https://github.com/Australian-Protein-Design-Initiative/containers" \
      org.opencontainers.image.title="ProteinMPNN / FastRelax (APDI fork)" \
      org.opencontainers.image.description="ProteinMPNN interface design with Rosetta FastRelax (dl_binder_design APDI fork) — includes HyperMPNN and PottsMPNN weights" \
      org.opencontainers.image.version="7f813d9" \
      org.opencontainers.image.revision="7f813d9" \
      org.opencontainers.image.licenses="MIT" \
      org.opencontainers.image.vendor="Australian Protein Design Initiative" \
      org.opencontainers.image.base.name="docker.io/condaforge/miniforge3:latest" \
      org.opencontainers.image.base.digest="sha256:dd98082ef7bf222373c5d35c12da61c00f9d546d8d17e8dd3bc2fd8cc5feb6f1" \
      org.opencontainers.image.usage="docker run --rm --gpus all -v \$(pwd)/workdir:/workspace proteinmpnn_dl_binder_design:latest python /app/dl_binder_design/mpnn_fr/dl_interface_design.py"

ARG GIT_REPO=https://github.com/Australian-Protein-Design-Initiative/dl_binder_design
# main with ipTM, ipSAE added
ARG GIT_REF=7f813d9
ARG PROTEINMPNN_REPO=https://github.com/dauparas/ProteinMPNN.git
ARG PROTEINMPNN_REF=8907e66

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y --no-install-recommends \
    git \
    wget \
    && rm -rf /var/lib/apt/lists/*

# Install into a dedicated env (not base): PyRosetta pins zlib <1.3, which
# conflicts with Miniforge base's mamba/zstd stack. Pin MKL 2023.2.0 so
# libtorch_cpu.so can resolve iJIT_NotifyEvent (newer MKL breaks conda torch).
RUN mamba create -y -n proteinmpnn python=3.11.9 \
    && mamba install -y -n proteinmpnn \
        -c https://conda.rosettacommons.org \
        -c pytorch \
        -c nvidia \
        -c conda-forge \
        pytorch=2.0.1 \
        pytorch-cuda=11.8 \
        biopython=1.81 \
        ml-collections=1.0.0 \
        pyrosetta=2024.42+release.3366cf78a3 \
        "numpy<2" \
        mkl=2023.2.0 \
    && mamba clean -afy

ENV PATH="/opt/conda/envs/proteinmpnn/bin:${PATH}"

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
