ARG CUDA=12.4.1
FROM nvidia/cuda:${CUDA}-cudnn-devel-ubuntu22.04
LABEL org.opencontainers.image.source=https://github.com/Australian-Protein-Design-Initiative/containers
#LABEL org.australian-protein-design-initiative.image.platforms="linux/arm64,linux/amd64"
LABEL org.australian-protein-design-initiative.image.platforms="linux/amd64"

# FROM directive resets ARGS, so we specify again (the value is retained if
# previously set).
ARG CUDA
ARG TARGETARCH
ARG BRANCH=05702c4

ENV DEBIAN_FRONTEND=noninteractive

# Use bash to support string substitution.
SHELL ["/bin/bash", "-o", "pipefail", "-c"]

RUN apt-get update --quiet \
    && apt-get upgrade -y --quiet \
    && apt-get install --no-install-recommends --yes --quiet \
    build-essential \
    cmake \
    cuda-command-line-tools-$(cut -f1,2 -d- <<< ${CUDA//./-}) \
    git \
    tzdata \
    wget \
    ffmpeg \
    && rm -rf /var/lib/apt/lists/* \
    && apt-get autoremove --yes \
    && apt-get clean

# Install Miniconda based on architecture
RUN if [ "$TARGETARCH" = "arm64" ]; then \
    wget -q -P /tmp https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-aarch64.sh && \
    bash /tmp/Miniconda3-latest-Linux-aarch64.sh -b -p /opt/conda && \
    rm /tmp/Miniconda3-latest-Linux-aarch64.sh; \
    else \
    wget -q -P /tmp https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh && \
    bash /tmp/Miniconda3-latest-Linux-x86_64.sh -b -p /opt/conda && \
    rm /tmp/Miniconda3-latest-Linux-x86_64.sh; \
    fi; \
    /opt/conda/bin/conda tos accept --override-channels --channel https://repo.anaconda.com/pkgs/main && \
    /opt/conda/bin/conda tos accept --override-channels --channel https://repo.anaconda.com/pkgs/r && \
    /opt/conda/bin/conda config --remove channels defaults && \
    /opt/conda/bin/conda install -c conda-forge mamba && \
    /opt/conda/bin/conda install -c conda-forge ncurses

ENV PATH="/opt/conda/bin:$PATH"
ENV LD_LIBRARY_PATH="/opt/conda/lib:$LD_LIBRARY_PATH"

RUN git clone https://github.com/martinpacesa/BindCraft /app/BindCraft && \
    cd /app/BindCraft && \
    git checkout ${BRANCH}

WORKDIR /app/BindCraft/

RUN bash install_bindcraft.sh --cuda ${CUDA} --pkg_manager 'mamba' && \
    /opt/conda/bin/mamba install --force-reinstall -n BindCraft -c conda-forge ncurses

ENV LD_LIBRARY_PATH=/opt/conda/lib

WORKDIR /app/BindCraft/
CMD ["/opt/conda/envs/BindCraft/bin/python", "/app/BindCraft/bindcraft.py"]