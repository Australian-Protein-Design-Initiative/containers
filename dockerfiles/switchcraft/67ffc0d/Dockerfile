# Build:
#   docker buildx build -t switchcraft --build-arg GIT_REF=67ffc0d .
# With model weights:
#   docker buildx build -t switchcraft --build-arg GIT_REF=67ffc0d --build-arg DOWNLOAD_WEIGHTS=true .

ARG GIT_REPO=https://github.com/bjing2016/switchcraft.git
ARG GIT_REF=67ffc0d
ARG DOWNLOAD_WEIGHTS=false

FROM nvidia/cuda:12.6.0-runtime-ubuntu22.04

LABEL org.opencontainers.image.source=https://github.com/Australian-Protein-Design-Initiative/containers
LABEL org.australian-protein-design-initiative.image.platforms="linux/amd64"
LABEL org.opencontainers.image.description="SwitchCraft: A Programmatic Framework for Designing State Switching Proteins"

ARG GIT_REPO
ARG GIT_REF
ARG DOWNLOAD_WEIGHTS

ENV DEBIAN_FRONTEND=noninteractive \
    PYTHONUNBUFFERED=1

RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt,sharing=locked \
    apt-get update && apt-get install -y --no-install-recommends \
    python3 \
    python3-pip \
    python3-dev \
    python3-venv \
    git \
    wget \
    ca-certificates \
    curl \
    build-essential \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Clone repository and checkout specified ref
RUN git clone ${GIT_REPO} . --depth 1 && git checkout ${GIT_REF}

# Install Boltz package and remaining dependencies.
# Note: boltz/pyproject.toml uses src/ layout but lacks [tool.setuptools.packages.find] config,
# so we patch it before building. Also ensure setuptools is recent enough for proper src discovery.
# ProDy 2.4.1 requires numpy<1.24 and biopython<=1.79, which conflicts with boltz.
# Install prody first, then reinstall boltz-compatible versions of numpy/biopython/scipy.
RUN --mount=type=cache,target=/root/.cache/pip \
    pip3 install --no-cache-dir "torch==2.7.1+cu126" --index-url https://download.pytorch.org/whl/cu126 && \
    rm -rf boltz/src/boltz.egg-info boltz/build boltz/*.egg-info && \
    printf '\n[tool.setuptools.packages.find]\nwhere = ["src"]\n' >> boltz/pyproject.toml && \
    pip3 install --no-cache-dir "setuptools>=61.0" wheel cuequivariance-torch && \
    pip3 install --no-cache-dir prody && \
    pip3 install --no-cache-dir --no-build-isolation boltz/

# Download model weights to /models/switchcraft/ and symlink into repo tree where source expects them:
#   boltz/ccd.pkl              -> /models/switchcraft/ccd.pkl
#   boltz/boltz1_conf.ckpt     -> /models/switchcraft/boltz1_conf.ckpt
#   LigandMPNN/model_params/   -> /models/switchcraft/model_params/
RUN mkdir -p /models/switchcraft && \
    curl -L -o /models/switchcraft/ccd.pkl https://huggingface.co/boltz-community/boltz-1/resolve/main/ccd.pkl && \
    ln -s /models/switchcraft/ccd.pkl boltz/ccd.pkl && \
    echo "CCD ligand database downloaded." && \
    if [ "$DOWNLOAD_WEIGHTS" = "true" ]; then \
        echo "Downloading Boltz model weights..." && \
        curl -L -o /models/switchcraft/boltz1_conf.ckpt https://huggingface.co/boltz-community/boltz-1/resolve/main/boltz1_conf.ckpt && \
        ln -s /models/switchcraft/boltz1_conf.ckpt boltz/boltz1_conf.ckpt && \
        echo "Boltz model weights downloaded." && \
        echo "Downloading LigandMPNN model weights..." && \
        cd LigandMPNN && bash get_model_params.sh ./model_params && cd .. && \
        cp -r LigandMPNN/model_params /models/switchcraft/ && \
        rm -rf LigandMPNN/model_params && \
        ln -s /models/switchcraft/model_params LigandMPNN/model_params && \
        echo "LigandMPNN model weights downloaded."; \
    else \
        echo "DOWNLOAD_WEIGHTS not set to true - skipping Boltz and LigandMPNN model weight downloads."; \
    fi

# Create output directory for design results
RUN mkdir -p /output

# Generate internal README documentation (must run as root before USER switch)
COPY README.container.md /README.md

# Non-root user (project convention)
ARG USER_UID=1000
ARG USER_GID=1000
RUN groupadd -g ${USER_GID} switchcraft && \
    useradd -m -u ${USER_UID} -g ${USER_GID} -s /bin/bash switchcraft && \
    chown -R ${USER_UID}:${USER_GID} /app /models /output

USER switchcraft

# Use CMD for CLI tool (allows users to override or pass arguments)
CMD ["python3", "switchcraft.py", "--help"]
