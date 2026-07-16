# Use a modern NVIDIA PyTorch base image (CUDA 12.x compatible with Blackwell GB200/G200)
FROM nvcr.io/nvidia/pytorch:25.01-py3

LABEL org.opencontainers.image.source="https://github.com/Australian-Protein-Design-Initiative/containers"

ARG GIT_REF=0.2.0
ARG DOWNLOAD_MODELS=true

# Environment variables for Python, pip, local model paths, and unmasking Hydra errors
# FIX: Changed CCD_MIRROR_PATH from a file path to the directory container path
ENV DEBIAN_FRONTEND=noninteractive \
    PIP_NO_CACHE_DIR=1 \
    PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1 \
    FOUNDRY_CHECKPOINT_DIRS=/models/foundry \
    CCD_MIRROR_PATH=/weights \
    HYDRA_FULL_ERROR=1

# Install build essentials and wget (excluding curl to satisfy static analysis)
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    cmake \
    git \
    wget \
    && rm -rf /var/lib/apt/lists/*

# Setup internal directory structure and symlink
RUN mkdir -p /models/foundry \
    && ln -s /models/foundry /weights

# Upgrade pip, install build tools, and ADD JUPYTERLAB
RUN pip install --upgrade pip setuptools wheel jupyterlab

# Resolve NVIDIA DALI dependency conflicts to keep build logs clean
RUN pip install "packaging<=24.2" "six==1.16.0"

# Install rc-foundry using standard pip
RUN pip install "rc-foundry[all]==${GIT_REF}"

# --- FIX: REMOVE BRITTLE APEX PACKAGE ---
# Purge apex completely to force rc-foundry to safely use the stable native PyTorch fallback
RUN pip uninstall apex -y

# --- DOWNLOAD CHUNK 1: Core Foundry Models ---
RUN if [ "$DOWNLOAD_MODELS" = "true" ]; then \
        foundry install \
          rfd3 \
          proteinmpnn \
          ligandmpnn \
          solublempnn \
          rf3 \
          --checkpoint-dir ${FOUNDRY_CHECKPOINT_DIRS}; \
    fi

# --- DOWNLOAD CHUNK 2: Protein & Ligand MPNN ---
RUN if [ "$DOWNLOAD_MODELS" = "true" ]; then \
        cd /weights && \
        wget -q https://files.ipd.uw.edu/pub/ligandmpnn/proteinmpnn_v_48_002.pt && \
        wget -q https://files.ipd.uw.edu/pub/ligandmpnn/proteinmpnn_v_48_010.pt && \
        wget -q https://files.ipd.uw.edu/pub/ligandmpnn/proteinmpnn_v_48_030.pt && \
        wget -q https://files.ipd.uw.edu/pub/ligandmpnn/ligandmpnn_v_32_005_25.pt && \
        wget -q https://files.ipd.uw.edu/pub/ligandmpnn/ligandmpnn_v_32_020_25.pt && \
        wget -q https://files.ipd.uw.edu/pub/ligandmpnn/ligandmpnn_v_32_030_25.pt; \
    fi

# --- DOWNLOAD CHUNK 3: Soluble MPNN ---
RUN if [ "$DOWNLOAD_MODELS" = "true" ]; then \
        cd /weights && \
        wget -q https://files.ipd.uw.edu/pub/ligandmpnn/solublempnn_v_48_002.pt && \
        wget -q https://files.ipd.uw.edu/pub/ligandmpnn/solublempnn_v_48_010.pt && \
        wget -q https://files.ipd.uw.edu/pub/ligandmpnn/solublempnn_v_48_030.pt; \
    fi

# --- DOWNLOAD CHUNK 4: Hyper MPNN ---
RUN if [ "$DOWNLOAD_MODELS" = "true" ]; then \
        cd /weights && \
        wget -q https://github.com/meilerlab/HyperMPNN/raw/refs/heads/main/retrained_models/v48_002_epoch240_hyper.pt && \
        wget -q https://github.com/meilerlab/HyperMPNN/raw/refs/heads/main/retrained_models/v48_010_epoch300_hyper.pt && \
        wget -q https://github.com/meilerlab/HyperMPNN/raw/refs/heads/main/retrained_models/v48_020_epoch300_hyper.pt && \
        wget -q https://github.com/meilerlab/HyperMPNN/raw/refs/heads/main/retrained_models/v48_030_epoch300_hyper.pt; \
    fi

# --- DOWNLOAD CHUNK 5: CCD CIF and Permissions ---
RUN if [ "$DOWNLOAD_MODELS" = "true" ]; then \
        wget -q -O /weights/components.cif https://files.wwpdb.org/pub/pdb/data/monomers/components.cif && \
        chmod -R a+rx /models/foundry /weights; \
    fi

# Create non-root user (UID/GID 1100 to prevent NVIDIA base image collisions)
RUN groupadd -g 1100 rosettauser && \
    useradd -m -u 1100 -g 1100 -s /bin/bash rosettauser

# Set workspace as the default directory for Jupyter
WORKDIR /workspace
RUN chown -R rosettauser:rosettauser /workspace

# Switch to the non-root user for execution
USER rosettauser

CMD ["rfd3", "--help"]
