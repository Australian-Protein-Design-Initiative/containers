# syntax=docker/dockerfile:1.4

# Use Ubuntu as base image
FROM ubuntu:22.04
LABEL org.opencontainers.image.source=https://github.com/Australian-Protein-Design-Initiative/containers

# Set build arguments
ARG GIT_REF=cc35dc1

# Set environment variables
ENV DEBIAN_FRONTEND=noninteractive

# Set work directory
WORKDIR /app

# Create Hugging Face cache directory
RUN mkdir -p /models/huggingface

# Set Hugging Face cache environment variables
ENV HF_HOME=/models/huggingface
ENV TRANSFORMERS_CACHE=/models/huggingface/transformers
ENV HUGGINGFACE_HUB_CACHE=/models/huggingface/hub

# Install basic dependencies
RUN apt-get update && apt-get install -y \
    git \
    wget \
    bash \
    curl \
    zip \
    unzip \
    && rm -rf /var/lib/apt/lists/*

# Clone the GhostFold repository
RUN git clone https://github.com/brineylab/ghostfold.git . && \
    git checkout ${GIT_REF}

# Make scripts executable
RUN chmod +x install_localcolabfold.sh ghostfold.sh

# Install Mamba
RUN wget -q https://github.com/conda-forge/miniforge/releases/latest/download/Miniforge3-Linux-x86_64.sh -O miniforge.sh && \
    bash miniforge.sh -b -p /opt/mamba && \
    rm miniforge.sh

# Initialize mamba for bash
ENV PATH=/opt/mamba/bin:$PATH
RUN /opt/mamba/bin/conda init bash

# Create mamba environment with base Python
RUN --mount=type=cache,target=/opt/mamba/pkgs \
    /opt/mamba/bin/mamba create -n ghostfold python=3.10 -y

# Install PyTorch
RUN --mount=type=cache,target=/opt/mamba/pkgs \
    /opt/mamba/bin/mamba run -n ghostfold mamba install -y pytorch=2.9.1 pytorch-cuda=12.4 torchvision torchaudio -c pytorch -c nvidia

# Install Transformers and Sentencepiece
RUN --mount=type=cache,target=/opt/mamba/pkgs \
    /opt/mamba/bin/mamba run -n ghostfold mamba install -y transformers=4.57.3 sentencepiece=0.2.1 pytorch -c pytorch -c conda-forge

# Install BioPython for sequence processing
RUN --mount=type=cache,target=/opt/mamba/pkgs \
    /opt/mamba/bin/mamba run -n ghostfold mamba install -y -c conda-forge -c bioconda biopython=1.86 rich=14.2.0 scikit-learn=1.7.2 matplotlib=3.10.8

# Install LocalColabFold
RUN --mount=type=cache,target=/app/localcolabfold/colabfold/params \
    /opt/mamba/bin/mamba run -n ghostfold bash ./install_localcolabfold.sh

# Pre-cache Rostlab/ProstT5 model (HF_TOKEN will be used for authentication if provided)
RUN --mount=type=cache,target=${HUGGINGFACE_HUB_CACHE} \
    --mount=type=secret,id=HF_TOKEN,target=/run/secrets/HF_TOKEN \
    if [ -f /run/secrets/HF_TOKEN ]; then \
        HF_TOKEN=$(cat /run/secrets/HF_TOKEN) /opt/mamba/bin/mamba run -n ghostfold hf download Rostlab/ProstT5; \
    else \
        /opt/mamba/bin/mamba run -n ghostfold hf download Rostlab/ProstT5; \
    fi

# Create non-root user
RUN groupadd -g 1000 ghostuser && \
    useradd -m -u 1000 -g 1000 -s /bin/bash ghostuser

# Change ownership of the app and models directories
RUN chown -R ghostuser:ghostuser /app /models

# Switch to non-root user
USER ghostuser

# Set the working directory for the user
WORKDIR /app

# Set up mamba environment for the user
ENV PATH=/opt/mamba/envs/ghostfold/bin:/opt/mamba/bin:$PATH
SHELL ["/bin/bash", "-c"]

# Default command
CMD ["./ghostfold.sh", "--help"]
