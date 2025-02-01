ARG CUDA=12.2.2
FROM nvidia/cuda:${CUDA}-cudnn8-runtime-ubuntu20.04
LABEL org.opencontainers.image.source=https://github.com/Australian-Protein-Design-Initiative/containers

# FROM directive resets ARGS, so we specify again (the value is retained if
# previously set).
ARG CUDA

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

RUN wget -q -P /tmp \
  https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh \
    && bash /tmp/Miniconda3-latest-Linux-x86_64.sh -b -p /opt/conda \
    && rm /tmp/Miniconda3-latest-Linux-x86_64.sh

ENV PATH="/opt/conda/bin:$PATH"
ENV LD_LIBRARY_PATH="/opt/conda/lib:$LD_LIBRARY_PATH"

# ROSETTA_PASSWORD must be provided via a docker secret
ARG ROSETTACOMMONS_USER=Academic_User
RUN --mount=type=secret,id=rosetta_password \
    ROSETTA_PW=$(cat /run/secrets/rosetta_password) && \
    conda install -y \
    -c https://${ROSETTACOMMONS_USER}:${ROSETTA_PW}@conda.rosettacommons.org \
    -c pytorch \
    -c nvidia \
    -c conda-forge \
    -c defaults \
    pip \
    python=3.11.9 \
    biopython=1.81 \
    ml-collections=1.0.0 \
    ml_dtypes=0.3.2 \
    pyrosetta=2024.42+release.3366cf78a3 \
    mock=5.1.0 \
    nvidia::cuda=${CUDA_VERSION} \
    conda-forge::openmm=8.0.0 \
    conda-forge::pdbfixer \
    && conda clean --all --force-pkgs-dirs --yes

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
RUN ln -sf /usr/lib/x86_64-linux-gnu/libffi.so.7 /opt/conda/lib/libffi.so.7

WORKDIR /app

RUN git clone https://github.com/nrbennet/dl_binder_design && \
    cd dl_binder_design && \
    git checkout cafa385

RUN python /app/dl_binder_design/include/importtests/af2_importtest.py

CMD ["python", "/app/dl_binder_design/af2_initial_guess/predict.py"]
