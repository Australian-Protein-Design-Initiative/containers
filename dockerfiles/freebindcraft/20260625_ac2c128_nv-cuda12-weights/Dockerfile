# syntax=docker/dockerfile:1
###############################################################################
# FreeBindCraft — amd64 / x86_64 image
#
# Adapted from FreeBindCraft's own Dockerfile (conda-installed jax, bundled x86-64
# binaries) and from our bindcraft/nv-cuda12 container image layout (pinned git
# clone, cudnn-devel CUDA base, separate weights layer).
#
# FreeBindCraft defaults to no PyRosetta (OpenMM + sc-rs + FASPR instead). Pass
# WITH_PYROSETTA=true to install PyRosetta from the RosettaCommons conda channel.
#
# --- Two image variants via DOWNLOAD_WEIGHTS --------------------------------
# The expensive install is a single shared layer; a separate, cheap layer bakes in
# the ~5.3 GB AlphaFold2 weights only when DOWNLOAD_WEIGHTS=1. Building both variants
# only re-runs the weights layer.
#
#   just build freebindcraft/20260625_ac2c128_nv-cuda12-weights "--build-arg DOWNLOAD_WEIGHTS=1"  # weights baked in
#   just build freebindcraft/20260625_ac2c128_nv-cuda12-weights "--build-arg DOWNLOAD_WEIGHTS=0"  # mount params/ at runtime
#
# To build with PyRosetta instead of the OpenMM/sc-rs/FASPR stack:
#   just build freebindcraft/20260625_ac2c128_nv-cuda12-weights "--build-arg WITH_PYROSETTA=true"
#
# --- Run (needs the NVIDIA Container Toolkit on the host) -------------------
#   docker run --rm --gpus all -v "$PWD/work:/work" \
#       ghcr.io/australian-protein-design-initiative/containers/freebindcraft:20260625_ac2c128_nv-cuda12-weights \
#       python bindcraft.py --settings /work/mytarget.json --no-pyrosetta
###############################################################################

ARG CUDA=12.4.1
FROM nvidia/cuda:${CUDA}-cudnn-devel-ubuntu22.04

LABEL org.opencontainers.image.source=https://github.com/Australian-Protein-Design-Initiative/containers
LABEL org.opencontainers.image.title="FreeBindCraft (amd64)"
LABEL org.opencontainers.image.description="FreeBindCraft for x86_64 GPUs (jax 0.6.0 via conda, Python 3.10, PyRosetta optional)"
LABEL org.australian-protein-design-initiative.image.platforms="linux/amd64"

# FROM directive resets ARGS, so we specify again (the value is retained if
# previously set).
ARG CUDA
ARG TARGETARCH
# Pin the FreeBindCraft repo + commit for reproducibility; bump this when the fork's
# master branch moves.
ARG GIT_REPO=https://github.com/Australian-Protein-Design-Initiative/FreeBindCraft.git
ARG GIT_REF=ac2c128

ENV DEBIAN_FRONTEND=noninteractive
SHELL ["/bin/bash", "-o", "pipefail", "-c"]

# This image targets amd64 only. Fail fast on other architectures.
RUN if [ "${TARGETARCH}" != "amd64" ]; then \
      echo "ERROR: freebindcraft/20260625_ac2c128_nv-cuda12-weights only supports linux/amd64 (got TARGETARCH='${TARGETARCH}'). Use freebindcraft/nv-cuda13-arm64 for arm64." >&2; \
      exit 1; \
    fi

# System packages:
#  - cuda-command-line-tools: nvcc and friends for conda jax/cuda-nvcc.
#  - ocl-icd-libopencl1 + clinfo + the nvidia.icd file: OpenCL support for OpenMM.
RUN apt-get update --quiet \
    && apt-get upgrade -y --quiet \
    && apt-get install --no-install-recommends --yes --quiet \
       ca-certificates \
       git \
       wget \
       curl \
       build-essential \
       cmake \
       cuda-command-line-tools-$(cut -f1,2 -d- <<< ${CUDA//./-}) \
       ffmpeg \
       ocl-icd-libopencl1 \
       clinfo \
    && mkdir -p /etc/OpenCL/vendors \
    && echo "libnvidia-opencl.so.1" > /etc/OpenCL/vendors/nvidia.icd \
    && rm -rf /var/lib/apt/lists/* \
    && apt-get autoremove --yes \
    && apt-get clean

# Miniforge (conda-forge by default — avoids the Anaconda defaults-channel ToS
# and matches the upstream FreeBindCraft Dockerfile).
RUN wget -q -O /tmp/miniforge.sh \
       https://github.com/conda-forge/miniforge/releases/latest/download/Miniforge3-Linux-x86_64.sh \
    && bash /tmp/miniforge.sh -b -p /opt/conda \
    && rm /tmp/miniforge.sh

ENV PATH="/opt/conda/bin:${PATH}"

RUN conda config --set channel_priority strict \
    && conda config --set always_yes yes \
    && conda update -n base -c conda-forge conda \
    && conda clean -afy

# Clone FreeBindCraft at the pinned revision.
RUN git clone ${GIT_REPO} /app/FreeBindCraft \
    && cd /app/FreeBindCraft \
    && git checkout ${GIT_REF}

WORKDIR /app/FreeBindCraft

# Patch install_bindcraft.sh so BINDCRAFT_SKIP_PARAMS=1 skips the weights download
# (same semantics as install_bindcraft_arm64.sh). This lets the expensive install
# layer be shared between weights/no-weights image variants.
RUN perl -i -0pe 's/(# AlphaFold2 weights\n)(.*?)(\n# chmod executables)/$1if [ "\${BINDCRAFT_SKIP_PARAMS:-0}" = "1" ]; then\n  echo -e "BINDCRAFT_SKIP_PARAMS=1 set — skipping AlphaFold2 weights download.\\n";\nelse\n$2fi$3/s' install_bindcraft.sh

# Install everything EXCEPT the AlphaFold2 weights (BINDCRAFT_SKIP_PARAMS=1) so this
# expensive layer is shared by both image variants and cached. mamba is far faster
# than conda at solving.
ARG WITH_PYROSETTA=false
RUN PYROSETTA_FLAG="--no-pyrosetta"; \
    if [ "${WITH_PYROSETTA}" = "true" ]; then PYROSETTA_FLAG=""; fi; \
    BINDCRAFT_SKIP_PARAMS=1 \
    bash install_bindcraft.sh --pkg_manager mamba --cuda ${CUDA} ${PYROSETTA_FLAG}

# AlphaFold2 weights — separate, cheap layer. DOWNLOAD_WEIGHTS=1 bakes them in;
# DOWNLOAD_WEIGHTS=0 leaves params/ empty so it can be mounted at runtime.
ARG DOWNLOAD_WEIGHTS=1
RUN if [ "${DOWNLOAD_WEIGHTS}" = "1" ]; then \
      echo "Baking AlphaFold2 weights into the image (DOWNLOAD_WEIGHTS=1)..." && \
      mkdir -p params && \
      wget -nv -c -O params/alphafold_params_2022-12-06.tar \
        "https://storage.googleapis.com/alphafold/alphafold_params_2022-12-06.tar" && \
      tar -xf params/alphafold_params_2022-12-06.tar --no-same-owner -C params && \
      test -f params/params_model_5_ptm.npz && \
      rm params/alphafold_params_2022-12-06.tar && \
      echo "AlphaFold2 weights installed."; \
    else \
      echo "DOWNLOAD_WEIGHTS=0 — AlphaFold2 weights NOT baked in. Mount them at /app/FreeBindCraft/params at runtime."; \
    fi

# Put the BindCraft env first on PATH so `python` is the right interpreter, and
# make the GPU visible to the NVIDIA container runtime (compute + OpenCL via "utility").
ENV PATH="/opt/conda/envs/BindCraft/bin:${PATH}"
ENV LD_LIBRARY_PATH="/opt/conda/envs/BindCraft/lib:${LD_LIBRARY_PATH}"
ENV NVIDIA_VISIBLE_DEVICES=all
ENV NVIDIA_DRIVER_CAPABILITIES=compute,utility

# Prefer OpenCL (fallback to CUDA) in OpenMM by default, matching upstream.
ENV OPENMM_PLATFORM_ORDER=OpenCL,CUDA \
    OPENMM_DEFAULT_PLATFORM=OpenCL \
    PYTHONUNBUFFERED=1 \
    BINDCRAFT_HOME=/app/FreeBindCraft

CMD ["/opt/conda/envs/BindCraft/bin/python", "/app/FreeBindCraft/bindcraft.py"]
