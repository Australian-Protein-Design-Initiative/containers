# arm64 / NVIDIA GB10 (Blackwell) build.
#
# PyRosetta's aarch64 conda builds only go up to 2023.11 (py39/py310 - no py311,
# unlike the amd64 build which uses 2024.42+py3.11), so this env pins python=3.10.
# The amd64 build pins old jax==0.4.26/jaxlib+cuda12.cudnn89 wheels that don't
# exist for aarch64 - this uses current jax/jaxlib/jax-cuda12-plugin instead,
# which do publish aarch64 wheels and support GB10 out of the box. TensorFlow is
# only used by AlphaFold's tf.data preprocessing pipeline (not GPU compute, which
# is JAX/Haiku), so tensorflow-cpu avoids pulling in TF's own CUDA stack entirely.
#
# Build like:
#   docker build -t af2_initial_guess:arm64_py310 .
# Skip optional weight downloads:
#   docker build --build-arg DOWNLOAD_WEIGHTS=false -t af2_initial_guess:arm64_py310 .

FROM condaforge/miniforge3:latest

LABEL org.opencontainers.image.source="https://github.com/Australian-Protein-Design-Initiative/containers" \
      org.opencontainers.image.title="AF2 Initial Guess (APDI fork, arm64/GB10)" \
      org.opencontainers.image.description="AlphaFold2 initial guess (dl_binder_design APDI fork with ipTM/ipSAE) - arm64/GB10 build, PyTorch/JAX" \
      org.opencontainers.image.version="7f813d9" \
      org.opencontainers.image.revision="7f813d9" \
      org.opencontainers.image.licenses="MIT" \
      org.opencontainers.image.vendor="Australian Protein Design Initiative" \
      org.opencontainers.image.base.name="docker.io/condaforge/miniforge3:latest" \
      org.opencontainers.image.usage="docker run --rm --gpus all -v \$(pwd)/workdir:/workspace af2_initial_guess:arm64_py310 python /app/dl_binder_design/af2_initial_guess/predict.py"

LABEL org.australian-protein-design-initiative.image.platforms="linux/arm64"

ARG GIT_REPO=https://github.com/Australian-Protein-Design-Initiative/dl_binder_design
# main with ipTM, ipSAE added
ARG GIT_REF=7f813d9

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    git \
    wget \
    && rm -rf /var/lib/apt/lists/*

# Install into a dedicated env (not base): PyRosetta pins zlib <1.3, which
# conflicts with Miniforge base's mamba/zstd stack.
RUN mamba create -y -n af2ig python=3.10 \
    && mamba install -y -n af2ig \
        -c https://conda.rosettacommons.org \
        -c conda-forge \
        pyrosetta=2023.11+release.fe5f8333f1c \
        ml-collections=1.0.0 \
        mock=5.1.0 \
        openmm=8.0.0 \
        pdbfixer \
        "numpy<2" \
    && mamba clean -afy

ENV PATH="/opt/conda/envs/af2ig/bin:${PATH}"
ENV LD_LIBRARY_PATH="/opt/conda/envs/af2ig/lib:${LD_LIBRARY_PATH}"

# biopython 1.81 has no aarch64 conda-forge build for py310 - install via pip
# (built from sdist).
RUN pip install --no-cache-dir "biopython==1.81"

# jax/jaxlib aarch64 wheels (unlike the old 0.4.26 pin, which has none) with the
# cuda12 plugin for GB10 support. Pinned to 0.5.3, not latest: this codebase's
# alphafold/model/modules.py calls jax.tree_map, which was removed outright in
# jax 0.6.0 (AttributeError at runtime, only surfaces once a real structure is
# processed - the flag says "auto" but no compiled kernels are actually called
# until inference). flax is NOT imported anywhere in this codebase and is
# dropped entirely, since flax>=0.10 requires jax>=0.6.0 and would force the
# broken jax back in. tensorflow-cpu has no py310/aarch64 wheels published, so
# this uses plain tensorflow - modern TF releases fall back to CPU-only cleanly
# when no compatible GPU stack is found, and GPU compute here is JAX/Haiku's
# job, not TF's.
RUN pip install --no-cache-dir \
        "dm-haiku" \
        "dm-tree" \
        "tensorflow" \
        "chex" \
        "docker==5.0.0" \
        "immutabledict" \
        "pandas" \
        "scipy" \
        "jax[cuda12]==0.5.3"

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
        && tar --no-same-owner --extract --verbose --file=alphafold_params_2022-12-06.tar \
        && rm alphafold_params_2022-12-06.tar; \
    fi

CMD ["python", "/app/dl_binder_design/af2_initial_guess/predict.py"]
