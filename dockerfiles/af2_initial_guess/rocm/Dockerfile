# AMD ROCm Container for dl_binder_design
# Based on AlphaFold v2.3.2 + ROCm 6.2.4
# 
# Build: docker build --network=host -t dl_binder_design-rocm:latest .
# Run:   docker run --rm -it --device /dev/kfd --device /dev/dri \
#                   --group-add video --network=host \
#                   dl_binder_design-rocm:latest \
#                     python /app/dl_binder_design/af2_initial_guess/predict.py --help
#
# Apptainer build: 
#            apptainer build dl_binder_design-rocm-latest.sif \
#	                           docker-daemon://dl_binder_design-rocm:latest
#
# Then run like:
#            apptainer run --rocm \
#           	 --env ROCBLAS_TENSILE_LIBPATH=/opt/rocm/lib/rocblas/library \
#	             --bind /opt/rocm/lib/rocblas/library:/opt/rocm/lib/rocblas/library \
#	             dl_binder_design-rocm-latest.sif \
#	               python /app/dl_binder_design/af2_initial_guess/predict.py --help

#FROM ubuntu:24.04
FROM quay.io/pawsey/pytorch:2.7.1-rocm6.3.3

LABEL org.opencontainers.image.source=https://github.com/Australian-Protein-Design-Initiative/containers

ENV DEBIAN_FRONTEND=noninteractive

# Use bash to support string substitution.
SHELL ["/bin/bash", "-o", "pipefail", "-c"]

# Base system packages
RUN apt-get update --quiet \
  && apt-get install --no-install-recommends --yes --quiet \
  build-essential \
  ca-certificates \
  cmake \
  git \
  rsync \
  tzdata \
  wget \
  && rm -rf /var/lib/apt/lists/* \
  && apt-get autoremove --yes \
  && apt-get clean

# Install ROCm 6.2.4
RUN update-ca-certificates 2>/dev/null || true \
  && wget --no-check-certificate -q -P /tmp \
  https://repo.radeon.com/amdgpu-install/6.2.4/ubuntu/noble/amdgpu-install_6.2.60204-1_all.deb \
  && apt-get update --quiet \
  && dpkg -i /tmp/amdgpu-install_6.2.60204-1_all.deb \
  && apt-get install -f --yes --quiet \
  && amdgpu-install --usecase=hiplibsdk,rocm,hip --yes --no-dkms \
  && rm /tmp/amdgpu-install_6.2.60204-1_all.deb \
  && rm -rf /var/lib/apt/lists/* \
  && apt-get autoremove --yes \
  && apt-get clean

ENV ROCM_PATH=/opt/rocm
ENV PATH=$ROCM_PATH/bin:$ROCM_PATH/llvm/bin:$PATH
ENV JAX_PLATFORMS=rocm,cpu

# Install Miniforge3 (conda-forge mamba distribution)
RUN wget -q -P /tmp \
  https://github.com/conda-forge/miniforge/releases/latest/download/Miniforge3-$(uname)-$(uname -m).sh \
  && bash /tmp/Miniforge3-$(uname)-$(uname -m).sh -b -p /opt/miniforge3 \
  && rm /tmp/Miniforge3-$(uname)-$(uname -m).sh

ENV PATH="/opt/miniforge3/bin:$PATH"
ENV LD_LIBRARY_PATH="/opt/miniforge3/lib"

# Install conda packages
# Use openmm from conda-forge (stable) with OpenCL support for AMD GPU
# openmm-hip from streamhpc requires openmm=8.0.0beta which is unavailable
RUN mamba install -y -c https://conda.rosettacommons.org -c conda-forge \
    pip \
    python=3.11 \
    biopython=1.81 \
    ml-collections=1.0.0 \
    pyrosetta=2024.42+release.3366cf78a3 \
    mock=5.1.0 \
    openmm \
    pdbfixer \
    && mamba clean -afy

# Install pip packages + ROCm JAX 0.4.34 wheels
# tensorflow is required by alphafold.model.model import
RUN pip install --no-cache-dir --break-system-packages --only-binary :all: \
        "dm-haiku==0.0.13" \
        "dm-tree==0.1.8" \
        "flax" \
        "absl-py==1.0.0" \
        "chex==0.1.86" \
        "docker==5.0.0" \
        "immutabledict==2.0.0" \
        "numpy==1.24.3" \
        "pandas==2.0.3" \
        "setuptools<72.0.0" \
        "scipy==1.11.1" \
    && pip install --no-cache-dir --break-system-packages --only-binary :all: \
        "tensorflow==2.15.*" \
    && pip install --no-cache-dir --break-system-packages \
        https://github.com/ROCm/jax/releases/download/rocm-jax-v0.4.34/jaxlib-0.4.34-cp311-cp311-manylinux_2_28_x86_64.whl \
        https://github.com/ROCm/jax/releases/download/rocm-jax-v0.4.34/jax_rocm60_pjrt-0.4.34-py3-none-manylinux_2_28_x86_64.whl \
        https://github.com/ROCm/jax/releases/download/rocm-jax-v0.4.34/jax_rocm60_plugin-0.4.34-cp311-cp311-manylinux_2_28_x86_64.whl \
        https://github.com/ROCm/jax/archive/refs/tags/rocm-jax-v0.4.34.tar.gz

# Currently needed to avoid undefined_symbol error.
RUN ln -sf /usr/lib/x86_64-linux-gnu/libffi.so.7 /opt/miniforge3/lib/libffi.so.7

WORKDIR /app

# Copy local source (already patched for ROCm)
COPY . /app/dl_binder_design

RUN JAX_PLATFORMS=cpu python /app/dl_binder_design/include/importtests/af2_importtest.py

# Download AlphaFold model weights
RUN mkdir -p /models/af2_initial_guess/model_weights/params \
    && mkdir -p /app/dl_binder_design/af2_initial_guess/model_weights \
    && cd /models/af2_initial_guess/model_weights/params \
    && ln -s /models/af2_initial_guess/model_weights/params /app/dl_binder_design/af2_initial_guess/model_weights/params \
    && wget https://storage.googleapis.com/alphafold/alphafold_params_2022-12-06.tar \
    && tar --extract --verbose --file=alphafold_params_2022-12-06.tar \
    && rm alphafold_params_2022-12-06.tar

CMD ["python", "/app/dl_binder_design/af2_initial_guess/predict.py"]
