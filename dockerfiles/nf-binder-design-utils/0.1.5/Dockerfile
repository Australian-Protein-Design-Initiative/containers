FROM python:3.13-slim
LABEL org.opencontainers.image.source=https://github.com/Australian-Protein-Design-Initiative/containers

# This image has various miscellaneous packages and tools used for parts of the
# nf-binder-design workflow (https://github.com/Australian-Protein-Design-Initiative/nf-binder-design)
# (eg, end-of-pipeline reporting, general Python scripts)
# We also add Jupyterlab and Marimo to allow for development of interactive analysis in the
# same environment.

ARG QUARTO_VERSION=1.8.25
ARG MDANALYSIS_VERSION=2.10.0
ARG BIOTITE_VERSION=1.5.0

# Set environment variables
ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    DEBIAN_FRONTEND=noninteractive

# Install system dependencies and Node.js 20.x
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    git \
    libopenmpi-dev \
    curl \
    gnupg \
    ca-certificates \
    procps \
    pandoc \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

RUN curl -L -o quarto-${QUARTO_VERSION}-linux-amd64.deb https://github.com/quarto-dev/quarto-cli/releases/download/v${QUARTO_VERSION}/quarto-${QUARTO_VERSION}-linux-amd64.deb && \
    dpkg -i quarto-${QUARTO_VERSION}-linux-amd64.deb && \
    rm quarto-${QUARTO_VERSION}-linux-amd64.deb

# Install Node.js 20.x
RUN curl -fsSL https://deb.nodesource.com/setup_20.x | bash - && \
    apt-get install -y nodejs && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* 

# Verify Node.js installation
RUN node --version && npm --version

# Install csvtk
RUN curl -L https://github.com/shenwei356/csvtk/releases/download/v0.35.0/csvtk_linux_amd64.tar.gz | \
    tar -xvz -C /usr/bin/ csvtk && \
    chmod +x /usr/bin/csvtk

# Install pdbtk
RUN curl -L https://github.com/pansapiens/pdbtk/releases/download/v0.1.1/pdbtk-linux-amd64 >/usr/bin/pdbtk \
    && chmod +x /usr/bin/pdbtk

# Upgrade pip and install Python packages globally
RUN pip install --upgrade pip && \
    pip install --no-cache-dir \
    MDAnalysis[analysis]==${MDANALYSIS_VERSION} \
    biotite==${BIOTITE_VERSION} \
    pandas \
    biopython \
    altair \
    seaborn\
    matplotlib \
    scipy \
    scikit-learn \
    plotly \
    statsmodels \
    itables

RUN pip install --no-cache-dir \
    jupyterlab \
    ipywidgets \
    jupyter_core \
    matplotlib-inline

RUN pip install --no-cache-dir \
    "marimo[recommended]"

# Install Jupyter widget extension
RUN jupyter labextension install @jupyter-widgets/jupyterlab-manager

# Create a non-root user to run the application
RUN useradd -m nfbd-user
WORKDIR /home/nfbd-user/app

# Set proper ownership for the working directory
RUN chown -R nfbd-user:nfbd-user /home/nfbd-user/app

# Switch to non-root user for running the application
USER nfbd-user

# Set default port for Jupyter
EXPOSE 8888

# Set the entrypoint to jupyter
CMD ["jupyter", "lab", "--ip=0.0.0.0", "--no-browser"]
