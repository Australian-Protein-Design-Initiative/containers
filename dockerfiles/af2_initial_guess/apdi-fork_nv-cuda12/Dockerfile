ARG CUDA=12.2.2

FROM nvidia/cuda:${CUDA}-cudnn8-runtime-ubuntu20.04

LABEL org.opencontainers.image.source="https://github.com/Australian-Protein-Design-Initiative/containers" \
      org.opencontainers.image.title="AF2 Initial Guess (APDI fork, CUDA 12)" \
      org.opencontainers.image.description="AlphaFold2 initial guess (dl_binder_design APDI fork with ipTM/ipSAE) — CUDA 12.2, PyTorch/JAX" \
      org.opencontainers.image.version="7f813d9" \
      org.opencontainers.image.revision="7f813d9" \
      org.opencontainers.image.licenses="MIT" \
      org.opencontainers.image.vendor="Australian Protein Design Initiative" \
      org.opencontainers.image.base.name="docker.io/nvidia/cuda:12.2.2-cudnn8-runtime-ubuntu20.04" \
      org.opencontainers.image.base.digest="sha256:1da6cf17f9c651323905c8cf5fd63a781a9a2fc0d28a477ca21df80a7bfaa00c" \
      org.opencontainers.image.usage="docker run --rm --gpus all -v \$(pwd)/workdir:/workspace af2_initial_guess:apdi-fork_nv-cuda12 python /app/dl_binder_design/af2_initial_guess/predict.py"

# FROM directive resets ARGS, so we specify again (the value is retained if
# previously set).
ARG CUDA
ARG GIT_REPO=https://github.com/Australian-Protein-Design-Initiative/dl_binder_design
# main with ipTM, ipSAE added
ARG GIT_REF=7f813d9

ENV DEBIAN_FRONTEND=noninteractive

# Use bash to support string substitution.
SHELL ["/bin/bash", "-o", "pipefail", "-c"]

RUN apt-get update --quiet \
  && apt-get install --no-install-recommends --yes --quiet \
  build-essential \
  cmake \
  cuda-command-line-tools-$(cut -f1,2 -d- <<< ${CUDA//./-}) \
  git \
  tzdata \
  wget \
  && rm -rf /var/lib/apt/lists/* \
  && apt-get autoremove --yes \
  && apt-get clean

# Miniforge (conda-forge by default — avoids the Anaconda defaults-channel ToS).
RUN wget -q -O /tmp/miniforge.sh \
       https://github.com/conda-forge/miniforge/releases/latest/download/Miniforge3-Linux-x86_64.sh \
    && bash /tmp/miniforge.sh -b -p /opt/conda \
    && rm /tmp/miniforge.sh

ENV PATH="/opt/conda/bin:$PATH"

# Install into a dedicated env (not base): PyRosetta pins zlib <1.3, which
# conflicts with Miniforge base's mamba/zstd stack.
RUN mamba create -y -n af2ig python=3.11.9 \
    && mamba install -y -n af2ig \
        -c https://conda.rosettacommons.org \
        -c pytorch \
        -c nvidia \
        -c conda-forge \
        pip \
        biopython=1.81 \
        ml-collections=1.0.0 \
        ml_dtypes=0.3.2 \
        pyrosetta=2024.42+release.3366cf78a3 \
        mock=5.1.0 \
        nvidia::cuda=${CUDA} \
        openmm=8.0.0 \
        pdbfixer \
    && mamba clean -afy

ENV PATH="/opt/conda/envs/af2ig/bin:${PATH}"
ENV LD_LIBRARY_PATH="/opt/conda/envs/af2ig/lib:${LD_LIBRARY_PATH}"

#    tensorflow=2.16.1 \
# Install pip packages with exact versions from environment file
RUN pip install --no-cache-dir \
        "dm-haiku==0.0.13" \
        "dm-tree==0.1.8" \
        "flax" \
        "tensorflow[and-cuda]" \
        "absl-py==1.0.0" \
        "chex==0.1.86" \
        "docker==5.0.0" \
        "immutabledict==2.0.0" \
        "jax==0.4.26" \
        "numpy==1.24.3" \
        "pandas==2.0.3" \
        "setuptools<72.0.0" \
        "scipy==1.11.1" \
        "tensorflow-cpu==2.16.1" \
    && pip install --upgrade --no-cache-dir \
      --find-links https://storage.googleapis.com/jax-releases/jax_cuda_releases.html \
      "jax[cuda12_pip]==0.4.26" \
      "jaxlib==0.4.26+cuda12.cudnn89"

# Currently needed to avoid undefined_symbol error.
RUN ln -sf /usr/lib/x86_64-linux-gnu/libffi.so.7 /opt/conda/envs/af2ig/lib/libffi.so.7

WORKDIR /app

RUN git clone ${GIT_REPO} /app/dl_binder_design && \
    cd /app/dl_binder_design && \
    git checkout ${GIT_REF}

RUN python /app/dl_binder_design/include/importtests/af2_importtest.py

# Download AlphaFold params (~3.5 GB) into the image at build time.
# Skip this layer and mount weights at runtime by using --build-arg DOWNLOAD_WEIGHTS=false
# (then pass -v /path/to/params:/models/af2_initial_guess/model_weights/params at docker run time).
ARG DOWNLOAD_WEIGHTS=true
RUN mkdir -p /models/af2_initial_guess/model_weights/params \
    && mkdir -p /app/dl_binder_design/af2_initial_guess/model_weights \
    && ln -s /models/af2_initial_guess/model_weights/params /app/dl_binder_design/af2_initial_guess/model_weights/params \
    && if [ "${DOWNLOAD_WEIGHTS}" = "true" ]; then \
        cd /models/af2_initial_guess/model_weights/params \
        && wget https://storage.googleapis.com/alphafold/alphafold_params_2022-12-06.tar \
        && tar --extract --verbose --file=alphafold_params_2022-12-06.tar \
        && rm alphafold_params_2022-12-06.tar; \
    fi

CMD ["python", "/app/dl_binder_design/af2_initial_guess/predict.py"]
