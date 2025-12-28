# syntax=docker/dockerfile:1.4
FROM condaforge/miniforge3:25.11.0-0 AS base

LABEL org.opencontainers.image.source https://github.com/Australian-Protein-Design-Initiative/containers

# Build arguments
ARG DOWNLOAD_MODELS=true
ARG GIT_REF=f4c9c14

# Set environment variables
ENV DEBIAN_FRONTEND=noninteractive \
    PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1 \
    CUDA_HOME=/usr/local/cuda \
    PATH=/opt/conda/bin:$PATH \
    PROTPARDELLE_OUTPUT_DIR=/tmp \
    PROJECT_ROOT_DIR=/app/protpardelle-1c \
    PROTPARDELLE_MODEL_PARAMS=/app/protpardelle-1c/model_params

# Install system dependencies
RUN apt-get update && apt-get install -y \
    build-essential \
    wget \
    curl \
    git \
    aria2 \
    && rm -rf /var/lib/apt/lists/*

# Install huggingface-hub for model downloads
RUN --mount=type=cache,target=/root/.cache/pip \
    pip install "huggingface_hub[cli]"

# Install Foldseek
RUN wget https://mmseqs.com/foldseek/foldseek-linux-gpu.tar.gz && \
    tar -xzf foldseek-linux-gpu.tar.gz && \
    mv foldseek/bin/foldseek /usr/bin/ && \
    rm -rf foldseek-linux-gpu.tar.gz foldseek

ENV FOLDSEEK_BIN=/usr/bin/foldseek

WORKDIR /app

# Clone the repository
RUN git clone https://github.com/ProteinDesignLab/protpardelle-1c.git /app/protpardelle-1c && \
    cd /app/protpardelle-1c && \
    git checkout ${GIT_REF}

# Setup Python environment and install dependencies
RUN --mount=type=cache,target=/root/.cache/pip \
    cd /app/protpardelle-1c && \
    pip install torch && \
    pip install -e .

# Download model weights (conditional)
RUN --mount=type=cache,target=/models \
    if [ "$DOWNLOAD_MODELS" = "true" ]; then \
        cd /app/protpardelle-1c && \
        # Zenodo seems the be blocking aria2c, so we patch to use wget instead
        sed -i 's/aria2c \-x16 \-s16 \-o/wget -O/' download_model_params.sh && \
        echo "Downloading model weights..." && \
        bash download_model_params.sh && \
        mkdir -p /models && \
        ln -s /app/protpardelle-1c/model_params /models/protpardelle-1c && \
        chmod -R a+r /app/protpardelle-1c/model_params && \
        find /app/protpardelle-1c/model_params -type d -exec chmod a+x {} \;; \
    else \
        echo "Skipping model weights download - to use this container please pre-download models to the host and bind them as a volume at /app/protpardelle-1c/model_params"; \
    fi

# Create wrapper scripts
RUN printf '#!/bin/sh\nexec python -m protpardelle.sample "$@"\n' > /usr/local/bin/protpardelle-sample && \
    printf '#!/bin/sh\nexec python -m protpardelle.train "$@"\n' > /usr/local/bin/protpardelle-train && \
    printf '#!/bin/sh\nexec python -m protpardelle.likelihood "$@"\n' > /usr/local/bin/protpardelle-likelihood && \
    chmod +x /usr/local/bin/protpardelle-*

# Create non-root user
RUN useradd -m -u 1001 protpardelle && \
    mkdir -p /app && \
    chown -R protpardelle:protpardelle /app

# Switch back to non-root user for final execution
USER protpardelle

CMD ["protpardelle-sample", "--help"]
