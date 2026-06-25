# syntax=docker/dockerfile:1
###############################################################################
# FreeBindCraft — arm64 / aarch64 image for NVIDIA Blackwell (GB10, GH200, etc.)
#
# Adapted from FreeBindCraft's own Dockerfile (x86-only, conda-installed jax/PyRosetta) and
# from the arm64 work done for upstream BindCraft (see bindcraft/nv-cuda13-arm64 in this repo).
#
# --- Why this differs from the upstream (x86) Dockerfile --------------------
# The upstream Dockerfile installs jax/jaxlib from conda and uses the bundled x86-64
# functions/{dssp,sc,FASPR,DAlphaBall.gcc} binaries. None of that works on aarch64:
#   * there are no aarch64 conda CUDA jax builds                -> jax is installed via pip.
#   * dssp/sc/FASPR/DAlphaBall.gcc are x86-64 binaries           -> all are replaced/rebuilt for
#     aarch64 by install_bindcraft_arm64.sh (dssp via conda-forge's mkdssp; sc and FASPR built
#     from source — both have zero native deps, so they cross-compile trivially; DAlphaBall.gcc
#     rebuilt from source, same as for upstream BindCraft, only when WITH_PYROSETTA=true).
#   * PyRosetta has no pip build for aarch64                     -> installed from the
#     RosettaCommons conda channel when WITH_PYROSETTA=true (off by default — that's the "Free"
#     in FreeBindCraft: OpenMM + sc-rs + FASPR replace PyRosetta relax/scoring/repacking).
#
# --- About the CUDA version (read this) -------------------------------------
# The target is Blackwell (sm_120 / sm_121), which needs CUDA >= 12.8.
# Ideally we would use jax[cuda13], but on aarch64 that is NOT possible today:
#   * jax with CUDA 13 requires Python >= 3.11, and
#   * PyRosetta (when WITH_PYROSETTA=true) only ships aarch64 builds for Python 3.9 / 3.10.
# So we pin Python 3.10 and use jax[cuda12]==0.6.0 (matching upstream FreeBindCraft's own pin),
# whose cuda12 plugin bundles CUDA 12.9 -- this fully supports Blackwell and is verified working
# on a GB10. jax brings its own CUDA wheels, so the base image's CUDA only provides the
# system/userspace + driver-matching layer; we still use a CUDA 13 base here to match Blackwell
# hosts (CUDA 13 driver).
#
# OpenMM is configured to prefer OpenCL (NVIDIA ships an aarch64 OpenCL ICD with the driver),
# falling back to CUDA -- same as upstream.
#
# --- Two image variants via DOWNLOAD_WEIGHTS --------------------------------
# The expensive install is a single shared layer; a separate, cheap layer bakes in the ~5.3 GB
# AlphaFold2 weights only when DOWNLOAD_WEIGHTS=1. Building both variants only re-runs the
# weights layer.
#
#   just build freebindcraft/nv-cuda13-arm64 "--build-arg DOWNLOAD_WEIGHTS=1"  # weights baked in
#   just build freebindcraft/nv-cuda13-arm64 "--build-arg DOWNLOAD_WEIGHTS=0"  # mount params/ at runtime
#
# To build with PyRosetta instead of the OpenMM/sc-rs/FASPR stack:
#   just build freebindcraft/nv-cuda13-arm64 "--build-arg WITH_PYROSETTA=true"
#
# --- Run (needs the NVIDIA Container Toolkit on the host) -------------------
#   docker run --rm --gpus all -v "$PWD/work:/work" \
#       ghcr.io/australian-protein-design-initiative/containers/freebindcraft:nv-cuda13-arm64 \
#       --settings /work/mytarget.json --no-pyrosetta
###############################################################################

ARG CUDA=13.0.1
FROM nvidia/cuda:${CUDA}-cudnn-devel-ubuntu24.04

LABEL org.opencontainers.image.title="FreeBindCraft (arm64 / Blackwell)"
LABEL org.opencontainers.image.description="FreeBindCraft for aarch64 + NVIDIA Blackwell GPUs (jax CUDA 12.9, Python 3.10, PyRosetta optional)"
LABEL org.australian-protein-design-initiative.image.platforms="linux/arm64"

ARG TARGETARCH
# Pin the FreeBindCraft repo + commit for reproducibility; bump this when the fork's
# master branch moves.
ARG GIT_REPO=https://github.com/Australian-Protein-Design-Initiative/FreeBindCraft.git
ARG GIT_REF=ac2c128

ENV DEBIAN_FRONTEND=noninteractive
SHELL ["/bin/bash", "-o", "pipefail", "-c"]

# This image targets arm64 only. Fail fast on other architectures so the wrong
# jax/PyRosetta combination is never produced.
RUN if [ "${TARGETARCH}" != "arm64" ]; then \
      echo "ERROR: freebindcraft/nv-cuda13-arm64 only supports linux/arm64 (got TARGETARCH='${TARGETARCH}'). Use the upstream x86 Dockerfile for amd64." >&2; \
      exit 1; \
    fi

# System packages:
#  - build-essential: g++ to build FASPR (C++) for aarch64.
#  - ocl-icd-libopencl1 + clinfo + the nvidia.icd file: OpenCL support for OpenMM (NVIDIA's
#    driver provides libnvidia-opencl.so.1 on aarch64 too; the container toolkit mounts it in).
RUN apt-get update --quiet \
    && apt-get upgrade -y --quiet \
    && apt-get install --no-install-recommends --yes --quiet \
       ca-certificates \
       git \
       wget \
       curl \
       bzip2 \
       file \
       build-essential \
       ocl-icd-libopencl1 \
       clinfo \
    && mkdir -p /etc/OpenCL/vendors \
    && echo "libnvidia-opencl.so.1" > /etc/OpenCL/vendors/nvidia.icd \
    && rm -rf /var/lib/apt/lists/* \
    && apt-get autoremove --yes \
    && apt-get clean

# Rust/cargo via rustup: build sc (sc-rs) for aarch64. apt's cargo (1.75) is too old for sc-rs's
# dependencies (rayon-core needs rustc >=1.80), so we install current stable instead.
ENV RUSTUP_HOME=/usr/local/rustup \
    CARGO_HOME=/usr/local/cargo \
    PATH=/usr/local/cargo/bin:$PATH
RUN curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y --default-toolchain stable --profile minimal \
    && rustc --version && cargo --version

# Miniforge (conda-forge by default — avoids the Anaconda defaults-channel ToS
# and matches the channels the arm64 install script expects).
RUN wget -q -O /tmp/miniforge.sh \
       https://github.com/conda-forge/miniforge/releases/latest/download/Miniforge3-Linux-aarch64.sh \
    && bash /tmp/miniforge.sh -b -p /opt/conda \
    && rm /tmp/miniforge.sh

ENV PATH="/opt/conda/bin:${PATH}"

# Clone FreeBindCraft at the pinned revision, then drop in the arm64 installer
# (which is not part of the upstream repo).
RUN git clone ${GIT_REPO} /app/FreeBindCraft \
    && cd /app/FreeBindCraft \
    && git checkout ${GIT_REF}

COPY install_bindcraft_arm64.sh /app/FreeBindCraft/install_bindcraft_arm64.sh

WORKDIR /app/FreeBindCraft

# Install everything EXCEPT the AlphaFold2 weights (BINDCRAFT_SKIP_PARAMS=1) so this expensive
# layer is shared by both image variants and cached. mamba is far faster than conda at solving.
# BINDCRAFT_SKIP_GPU_CHECK=1: docker build has no GPU; the GPU is verified at runtime by bindcraft.py.
ARG WITH_PYROSETTA=false
RUN PYROSETTA_FLAG=""; if [ "${WITH_PYROSETTA}" = "true" ]; then PYROSETTA_FLAG="--with-pyrosetta"; fi; \
    BINDCRAFT_SKIP_PARAMS=1 BINDCRAFT_SKIP_GPU_CHECK=1 \
    bash install_bindcraft_arm64.sh --pkg_manager mamba ${PYROSETTA_FLAG}

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
ENV NVIDIA_VISIBLE_DEVICES=all
ENV NVIDIA_DRIVER_CAPABILITIES=compute,utility

# Prefer OpenCL (fallback to CUDA) in OpenMM by default, matching upstream.
ENV OPENMM_PLATFORM_ORDER=OpenCL,CUDA \
    OPENMM_DEFAULT_PLATFORM=OpenCL \
    PYTHONUNBUFFERED=1 \
    BINDCRAFT_HOME=/app/FreeBindCraft

# Reuse FreeBindCraft's own entrypoint (raises the open-files limit, then execs the given command).
# It's part of the cloned repo already (not COPY'd from the build context). The upstream script
# hardcodes "cd /app" (where its own Dockerfile COPYs the repo); we clone to /app/FreeBindCraft.
RUN sed 's#cd /app#cd /app/FreeBindCraft#' /app/FreeBindCraft/docker-entrypoint.sh > /usr/local/bin/bindcraft-entrypoint.sh \
    && chmod +x /usr/local/bin/bindcraft-entrypoint.sh
ENTRYPOINT ["/usr/local/bin/bindcraft-entrypoint.sh"]

CMD ["python", "bindcraft.py", "--help"]
