# syntax=docker/dockerfile:1
###############################################################################
# BindCraft — amd64 / x86_64 image (CUDA 12.x, weights baked in)
#
# Adapted from dockerfiles/bindcraft/0366085-nv-cuda120 and informed by recent
# improvements in bindcraft/nv-cuda13-arm64 (APDI fork, pinned commit, separate
# weights layer, NVIDIA runtime env vars).
#
# --- Two image variants via DOWNLOAD_WEIGHTS --------------------------------
# The expensive install is a single shared layer; a separate, cheap layer bakes
# in the ~5.3 GB AlphaFold2 weights only when DOWNLOAD_WEIGHTS=1. Building both
# variants therefore only re-runs the weights layer.
#
#   just build bindcraft/20260625_40eb303_nv-cuda-12-weights "--build-arg DOWNLOAD_WEIGHTS=1"   # weights baked in (~20 GB)
#   just build bindcraft/20260625_40eb303_nv-cuda-12-weights "--build-arg DOWNLOAD_WEIGHTS=0"  # no weights (~14 GB; mount params/ at runtime)
#
# (DOWNLOAD_WEIGHTS defaults to 1 — this directory name reflects the weights variant.)
#
# --- Run (needs the NVIDIA Container Toolkit on the host) -------------------
#   # weights baked in:
#   docker run --rm --gpus all -v "$PWD/work:/work" \
#       ghcr.io/australian-protein-design-initiative/containers/bindcraft:20260625_40eb303_nv-cuda-12-weights \
#       python bindcraft.py --settings /work/mytarget.json
#
#   # weights mounted (no-weights image):
#   docker run --rm --gpus all -v "$PWD/params:/app/BindCraft/params" \
#       -v "$PWD/work:/work" \
#       ghcr.io/australian-protein-design-initiative/containers/bindcraft:20260625_40eb303_nv-cuda-12-weights \
#       python bindcraft.py --settings /work/mytarget.json
###############################################################################

ARG CUDA=12.4.1
FROM nvidia/cuda:${CUDA}-cudnn-devel-ubuntu22.04

LABEL org.opencontainers.image.source=https://github.com/Australian-Protein-Design-Initiative/containers
LABEL org.opencontainers.image.title="BindCraft (amd64 / CUDA 12)"
LABEL org.opencontainers.image.description="BindCraft for x86_64 GPUs (conda jax, PyRosetta, Python 3.10) — commit 40eb303"
LABEL org.australian-protein-design-initiative.image.platforms="linux/amd64"

# FROM directive resets ARGS, so we specify again (the value is retained if
# previously set).
ARG CUDA
ARG TARGETARCH
# Use the Australian-Protein-Design-Initiative fork (adds prescreen_soft_iterations and
# arm64 support on top of upstream martinpacesa/BindCraft).
ARG GIT_REPO=https://github.com/Australian-Protein-Design-Initiative/BindCraft.git
ARG GIT_REF=40eb303

ENV DEBIAN_FRONTEND=noninteractive
SHELL ["/bin/bash", "-o", "pipefail", "-c"]

# This image targets amd64 only. Fail fast on other architectures.
RUN if [ "${TARGETARCH}" != "amd64" ]; then \
      echo "ERROR: bindcraft/20260625_40eb303_nv-cuda-12-weights only supports linux/amd64 (got TARGETARCH='${TARGETARCH}'). Use bindcraft/nv-cuda13-arm64 for arm64." >&2; \
      exit 1; \
    fi

RUN apt-get update --quiet \
    && apt-get upgrade -y --quiet \
    && apt-get install --no-install-recommends --yes --quiet \
       build-essential \
       cmake \
       cuda-command-line-tools-$(cut -f1,2 -d- <<< ${CUDA//./-}) \
       git \
       tzdata \
       wget \
       ffmpeg \
    && rm -rf /var/lib/apt/lists/* \
    && apt-get autoremove --yes \
    && apt-get clean

# Miniforge (conda-forge by default — includes mamba; avoids Anaconda defaults-channel ToS
# and the sqlite lock errors seen installing mamba into recent Miniconda base).
RUN wget -q -O /tmp/miniforge.sh \
       https://github.com/conda-forge/miniforge/releases/latest/download/Miniforge3-Linux-x86_64.sh \
    && bash /tmp/miniforge.sh -b -p /opt/conda \
    && rm /tmp/miniforge.sh \
    && /opt/conda/bin/mamba install -c conda-forge ncurses

ENV PATH="/opt/conda/bin:${PATH}"
ENV LD_LIBRARY_PATH="/opt/conda/lib:${LD_LIBRARY_PATH}"

RUN git clone ${GIT_REPO} /app/BindCraft \
    && cd /app/BindCraft \
    && git checkout ${GIT_REF}

WORKDIR /app/BindCraft

# Patch install_bindcraft.sh so BINDCRAFT_SKIP_PARAMS=1 skips the weights download
# This lets the expensive install layer be shared between weights/no-weights image variants.
RUN perl -i -0pe 's/(# AlphaFold2 weights\n)(.*?)(\n# chmod executables)/$1if [ "\${BINDCRAFT_SKIP_PARAMS:-0}" = "1" ]; then\n  echo -e "BINDCRAFT_SKIP_PARAMS=1 set — skipping AlphaFold2 weights download.\\n";\nelse\n$2fi$3/s' install_bindcraft.sh

# Install everything EXCEPT the AlphaFold2 weights (BINDCRAFT_SKIP_PARAMS=1) so
# this expensive layer is shared by both image variants and cached. mamba is far
# faster than conda at solving.
RUN BINDCRAFT_SKIP_PARAMS=1 \
    bash install_bindcraft.sh --cuda ${CUDA} --pkg_manager mamba \
    && /opt/conda/bin/mamba install --force-reinstall -n BindCraft -c conda-forge ncurses

# AlphaFold2 weights — separate, cheap layer. DOWNLOAD_WEIGHTS=1 bakes them in
# (the "-weights" variant); DOWNLOAD_WEIGHTS=0 leaves params/ empty so it can be
# mounted at runtime (the "-no-weights" variant).
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
      echo "DOWNLOAD_WEIGHTS=0 — AlphaFold2 weights NOT baked in. Mount them at /app/BindCraft/params at runtime."; \
    fi

ENV LD_LIBRARY_PATH=/opt/conda/lib
ENV PATH="/opt/conda/envs/BindCraft/bin:${PATH}"
ENV NVIDIA_VISIBLE_DEVICES=all
ENV NVIDIA_DRIVER_CAPABILITIES=compute,utility
ENV PYTHONUNBUFFERED=1

WORKDIR /app/BindCraft/
CMD ["/opt/conda/envs/BindCraft/bin/python", "/app/BindCraft/bindcraft.py"]
