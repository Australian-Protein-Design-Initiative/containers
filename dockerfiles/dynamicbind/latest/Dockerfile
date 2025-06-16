FROM nvidia/cuda:11.7.1-cudnn8-runtime-ubuntu22.04

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    git \
    wget \
    build-essential \
    python3-dev \
    libssl-dev \
    libffi-dev \
    libxrender1 \
    libsm6 \
    libxext6 \
    unzip \
    && rm -rf /var/lib/apt/lists/*

RUN wget https://github.com/conda-forge/miniforge/releases/download/23.3.1-1/Mambaforge-23.3.1-1-Linux-x86_64.sh -O /tmp/mamba.sh && \
    bash /tmp/mamba.sh -b -p /opt/mamba && \
    rm /tmp/mamba.sh

ENV PATH="/opt/mamba/bin:$PATH"

# Create the dynamicbind environment based on provided environment.yml
# Use specific versions and channels to ensure compatibility
# RUN mamba create -n dynamicbind python=3.10.12 -c pyg -c pytorch -c nvidia -c conda-forge -c defaults -y && \
#     mamba install -n dynamicbind -y \
#     pytorch=2.0.1 \
#     torchvision \
#     torchaudio \
#     pytorch-cuda=11.7 \
#     pyg \
#     rdkit \
#     pyyaml \
#     biopython \
#     tqdm \
#     mkl \
#     intel-openmp \
#     mkl_fft \
#     mkl_random \
#     -c pyg -c pytorch -c nvidia -c conda-forge -c defaults && \
#     mamba clean -a -y

ENV PATH="/opt/mamba/envs/dynamicbind/bin:$PATH"

# Install remaining pip packages (PyG components are handled by mamba)
# RUN pip install --no-cache-dir e3nn fair-esm spyrmsd

# Create the relax environment with pdbfixer (using Python 3.8 which is compatible with PDBFixer)
RUN mamba create -y -n relax python=3.8 && \
    mamba install -n relax -y -c conda-forge openmm pdbfixer=1.8.1 libstdcxx-ng openmmforcefields openff-toolkit ambertools=22 compilers biopython && \
    mamba clean -a -y

# Create directories for App and ESM models/checkpoints to avoid runtime errors
RUN mkdir -p /app && \
    git clone https://github.com/luwei0917/DynamicBind.git /app/DynamicBind && \
    mkdir -p /app/DynamicBind/esm_models/checkpoints

WORKDIR /app/DynamicBind

RUN cd /app/DynamicBind && mamba env create -f environment.yml

# Precompute/download necessary files during build to avoid runtime read-only errors
# TODO: We should probably be doing this like:
# import torch; torch.hub.load("facebookresearch/esm:main", "esm2_t33_650M_UR50D")
# ..maybe
RUN /opt/mamba/envs/dynamicbind/bin/python -c "import utils.so3; import utils.torus" && \
    wget -P /app/DynamicBind/esm_models/checkpoints/ https://dl.fbaipublicfiles.com/fair-esm/models/esm2_t33_650M_UR50D.pt && \
    wget -P /app/DynamicBind/esm_models/checkpoints/ https://dl.fbaipublicfiles.com/fair-esm/regression/esm2_t33_650M_UR50D-contact-regression.pt

# Download v2 model checkpoint
RUN wget -O workdir.zip "https://zenodo.org/records/10183369/files/workdir.zip?download=1" && \
    unzip workdir.zip && \
    rm workdir.zip

# Set MKL threading layer to GNU to potentially resolve libgomp conflicts
ENV MKL_THREADING_LAYER=GNU

# Create the wrapper script
RUN echo '#!/bin/bash\n\
    exec /opt/mamba/envs/dynamicbind/bin/python /app/DynamicBind/run_single_protein_inference.py --python /opt/mamba/envs/dynamicbind/bin/python --relax_python /opt/mamba/envs/relax/bin/python "$@"\n\
    ' > /usr/bin/dynamicbind && \
    chmod +x /usr/bin/dynamicbind

ENTRYPOINT ["/usr/bin/dynamicbind"]