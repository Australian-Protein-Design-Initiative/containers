# syntax=docker/dockerfile:1
###############################################################################
# BindCraft — arm64 / aarch64 image for NVIDIA Blackwell (GB10, GH200, etc.)
#
# Adapted from the Australian Protein Design Initiative's nv-cuda12 Dockerfile:
#   https://github.com/Australian-Protein-Design-Initiative/containers/blob/main/dockerfiles/bindcraft/nv-cuda12/Dockerfile
#
# --- Why this differs from the upstream (x86) image -------------------------
# The upstream image runs install_bindcraft.sh, which installs jax/jaxlib from
# conda. There are no aarch64 conda CUDA jax builds, and the bundled
# functions/{dssp,DAlphaBall.gcc} are x86-64 binaries. This image instead runs
# install_bindcraft_arm64.sh, which:
#   * installs jax via pip (CUDA bundled), rebuilds DAlphaBall for aarch64,
#     installs mkdssp from conda-forge, and installs PyRosetta from the
#     RosettaCommons aarch64 channel.
#
# --- About the CUDA version (read this) -------------------------------------
# The target is Blackwell (sm_120 / sm_121), which needs CUDA >= 12.8.
# Ideally we would use jax[cuda13], but on aarch64 that is NOT possible today:
#   * jax with CUDA 13 requires Python >= 3.11, and
#   * PyRosetta only ships aarch64 builds for Python 3.9 / 3.10.
# So we pin Python 3.10 and use jax[cuda12]==0.5.3, whose cuda12 plugin bundles
# CUDA 12.9 — which fully supports Blackwell and is verified working on a GB10.
# jax brings its own CUDA wheels, so the base image's CUDA only provides the
# system/userspace + driver-matching layer; we still use a CUDA 13 base here to
# match Blackwell hosts (CUDA 13 driver).
#
# --- Two image variants via DOWNLOAD_WEIGHTS --------------------------------
# The expensive install is a single shared layer; a separate, cheap layer bakes
# in the ~5.3 GB AlphaFold2 weights only when DOWNLOAD_WEIGHTS=1. Building both
# variants therefore only re-runs the weights layer.
#
#   just build bindcraft/nv-cuda13-arm64 "--build-arg DOWNLOAD_WEIGHTS=1"   # weights baked in (~20 GB)
#   just build bindcraft/nv-cuda13-arm64 "--build-arg DOWNLOAD_WEIGHTS=0"  # no weights (~14 GB; mount params/ at runtime)
#
# (DOWNLOAD_WEIGHTS defaults to 1, so a plain `just build bindcraft/nv-cuda13-arm64` bakes weights in.)
#
# --- Run (needs the NVIDIA Container Toolkit on the host) -------------------
#   # weights baked in:
#   docker run --rm --gpus all -v "$PWD/work:/work" \
#       ghcr.io/australian-protein-design-initiative/containers/bindcraft:nv-cuda13-arm64 \
#       --settings /work/mytarget.json
#
#   # weights mounted (no-weights image):
#   docker run --rm --gpus all -v "$PWD/params:/app/BindCraft/params" \
#       -v "$PWD/work:/work" \
#       ghcr.io/australian-protein-design-initiative/containers/bindcraft:nv-cuda13-arm64 \
#       --settings /work/mytarget.json
###############################################################################

ARG CUDA=13.0.1
FROM nvidia/cuda:${CUDA}-cudnn-devel-ubuntu24.04

LABEL org.opencontainers.image.title="BindCraft (arm64 / Blackwell)"
LABEL org.opencontainers.image.description="BindCraft for aarch64 + NVIDIA Blackwell GPUs (jax CUDA 12.9, PyRosetta 2023.11, Python 3.10)"
LABEL org.australian-protein-design-initiative.image.platforms="linux/arm64"

ARG TARGETARCH
# Use the Australian-Protein-Design-Initiative fork (adds prescreen_soft_iterations and arm64
# support on top of upstream martinpacesa/BindCraft). Pinned to a specific commit for a
# reproducible build; bump this when the fork's main branch moves.
ARG GIT_REPO=https://github.com/Australian-Protein-Design-Initiative/BindCraft.git
ARG GIT_REF=40eb303

ENV DEBIAN_FRONTEND=noninteractive
SHELL ["/bin/bash", "-o", "pipefail", "-c"]

# This image targets arm64 only. Fail fast on other architectures so the wrong
# jax/PyRosetta combination is never produced.
RUN if [ "${TARGETARCH}" != "arm64" ]; then \
      echo "ERROR: bindcraft/nv-cuda13-arm64 only supports linux/arm64 (got TARGETARCH='${TARGETARCH}'). Use bindcraft/nv-cuda12 for amd64." >&2; \
      exit 1; \
    fi

# Minimal system packages. The compiler toolchain (gcc/gfortran/gmp) used to
# build DAlphaBall comes from conda-forge inside the install script, so we only
# need git/wget + cert/bzip2 plumbing here.
RUN apt-get update --quiet \
    && apt-get upgrade -y --quiet \
    && apt-get install --no-install-recommends --yes --quiet \
       ca-certificates \
       git \
       wget \
       bzip2 \
       file \
    && rm -rf /var/lib/apt/lists/* \
    && apt-get autoremove --yes \
    && apt-get clean

# Miniforge (conda-forge by default — avoids the Anaconda defaults-channel ToS
# and matches the channels the arm64 install script expects).
RUN wget -q -O /tmp/miniforge.sh \
       https://github.com/conda-forge/miniforge/releases/latest/download/Miniforge3-Linux-aarch64.sh \
    && bash /tmp/miniforge.sh -b -p /opt/conda \
    && rm /tmp/miniforge.sh

ENV PATH="/opt/conda/bin:${PATH}"

# Clone BindCraft at the pinned revision, then drop in the arm64 installer
# (which is not part of the upstream repo).
RUN git clone ${GIT_REPO} /app/BindCraft \
    && cd /app/BindCraft \
    && git checkout ${GIT_REF}

COPY install_bindcraft_arm64.sh /app/BindCraft/install_bindcraft_arm64.sh

WORKDIR /app/BindCraft

# Install everything EXCEPT the AlphaFold2 weights (BINDCRAFT_SKIP_PARAMS=1) so
# this expensive layer is shared by both image variants and cached. mamba is far
# faster than conda at solving against the PyRosetta channel.
# BINDCRAFT_SKIP_GPU_CHECK=1: docker build has no GPU; the GPU is verified at runtime by bindcraft.py.
RUN BINDCRAFT_SKIP_PARAMS=1 BINDCRAFT_SKIP_GPU_CHECK=1 \
    bash install_bindcraft_arm64.sh --pkg_manager mamba

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

# Put the BindCraft env first on PATH so `python` is the right interpreter, and
# make the GPU visible to the NVIDIA container runtime.
ENV PATH="/opt/conda/envs/BindCraft/bin:${PATH}"
ENV NVIDIA_VISIBLE_DEVICES=all
ENV NVIDIA_DRIVER_CAPABILITIES=compute,utility

# Run bindcraft.py by default; pass --settings/--filters/--advanced as `docker run` args.
ENTRYPOINT ["/opt/conda/envs/BindCraft/bin/python", "-u", "/app/BindCraft/bindcraft.py"]
CMD ["--help"]
