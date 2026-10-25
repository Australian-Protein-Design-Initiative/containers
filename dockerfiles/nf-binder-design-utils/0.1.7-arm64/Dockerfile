# syntax=docker/dockerfile:1.4
# Build like:
#   just build nf-binder-design-utils/0.1.7-arm64 --pull
#
# The nf-binder-design utility image for arm64 / aarch64 (eg DGX Spark GB10). The amd64 sibling is
# nf-binder-design-utils/0.1.7.
#
# Contents are identical to the amd64 image: 0.1.7 already selects its downloads with
# `dpkg --print-architecture`, and quarto, csvtk and pdbtk all publish linux arm64 builds, so no
# source changes were needed. This directory exists because `just build` takes the platform from
# the image's own platforms label, so a second architecture needs a second tag.
#
# Several nf-binder-design processes run here - PREPARE_RFD4_INPUT, RFD4_FILTER_DESIGNS,
# COMBINE_RFD4_SCORES, the FoldSeek and reporting steps - and on an arm64 host the amd64 image
# fails them with `exec format error`.

ARG QUARTO_VERSION=1.8.25
ARG MDANALYSIS_VERSION=2.10.0
ARG BIOTITE_VERSION=1.5.0
ARG BASE_IMAGE=python:3.13-slim

FROM ${BASE_IMAGE}

ARG QUARTO_VERSION
ARG MDANALYSIS_VERSION
ARG BIOTITE_VERSION

LABEL org.opencontainers.image.source=https://github.com/Australian-Protein-Design-Initiative/containers
LABEL org.opencontainers.image.url="https://github.com/Australian-Protein-Design-Initiative/nf-binder-design"
LABEL org.opencontainers.image.title="nf-binder-design-utils (arm64)"
LABEL org.opencontainers.image.description="Miscellaneous Python, structure and reporting tools used by the nf-binder-design workflow, built for arm64 / aarch64, with JupyterLab and Marimo for interactive analysis"
LABEL org.opencontainers.image.version="0.1.7"
LABEL org.opencontainers.image.base.name="docker.io/library/python:3.13-slim"
LABEL org.opencontainers.image.base.digest="sha256:fdc02ec63f6f10b14a31159fbccb15b7b85a990ec27d7bf120e725a70fb256d7"
LABEL org.opencontainers.image.usage="docker run --rm -v \$(pwd):/data -w /data nf-binder-design-utils:0.1.7-arm64 python my_script.py"
LABEL org.australian-protein-design-initiative.image.platforms="linux/arm64"

# This image has various miscellaneous packages and tools used for parts of the
# nf-binder-design workflow (https://github.com/Australian-Protein-Design-Initiative/nf-binder-design)
# (eg, end-of-pipeline reporting, general Python scripts)
# We also add Jupyterlab and Marimo to allow for development of interactive analysis in the
# same environment.

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
    gemmi \
    openbabel \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

RUN ARCH=$(dpkg --print-architecture) && \
    curl -L -o quarto-${QUARTO_VERSION}-linux-${ARCH}.deb https://github.com/quarto-dev/quarto-cli/releases/download/v${QUARTO_VERSION}/quarto-${QUARTO_VERSION}-linux-${ARCH}.deb && \
    dpkg -i quarto-${QUARTO_VERSION}-linux-${ARCH}.deb && \
    rm quarto-${QUARTO_VERSION}-linux-${ARCH}.deb

# Install Node.js 20.x
RUN curl -fsSL https://deb.nodesource.com/setup_20.x | bash - && \
    apt-get install -y nodejs && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Verify Node.js installation
RUN node --version && npm --version

# Install csvtk
RUN ARCH=$(dpkg --print-architecture) && \
    curl -L https://github.com/shenwei356/csvtk/releases/download/v0.35.0/csvtk_linux_${ARCH}.tar.gz | \
    tar -xvz -C /usr/bin/ csvtk && \
    chmod +x /usr/bin/csvtk

# Install pdbtk
RUN ARCH=$(dpkg --print-architecture) && \
    curl -L https://github.com/pansapiens/pdbtk/releases/download/v0.1.1/pdbtk-linux-${ARCH} >/usr/bin/pdbtk \
    && chmod +x /usr/bin/pdbtk

# Upgrade pip and install Python packages globally
RUN pip install --upgrade pip && \
    pip install --no-cache-dir \
    MDAnalysis[analysis]==${MDANALYSIS_VERSION} \
    biotite==${BIOTITE_VERSION} \
    gemmi \
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

# Confirm the arch-dependent tools are actually runnable, rather than finding out in a pipeline run
RUN quarto --version \
    && csvtk version \
    && pdbtk --help > /dev/null \
    && python -c "import MDAnalysis, biotite, gemmi, pandas, Bio, numpy, scipy, sklearn, matplotlib, seaborn, altair, plotly, statsmodels, itables; print('python stack ok')"

RUN cat > /README.md <<'EOF'
# nf-binder-design-utils (arm64)

Utility image for the
[nf-binder-design](https://github.com/Australian-Protein-Design-Initiative/nf-binder-design)
workflow, built for arm64 / aarch64. The amd64 sibling tag is `0.1.7`.

The contents match the amd64 image. This tag exists only so that arm64 hosts (eg DGX Spark GB10)
can run the workflow's post-processing steps, which otherwise fail with `exec format error`.

## Contents

- Python 3.13 with pandas, numpy, scipy, scikit-learn, statsmodels, biopython, MDAnalysis,
  biotite and gemmi
- Plotting and reporting: matplotlib, seaborn, altair, plotly, itables, pandoc, Quarto
- Structure and table command line tools: `pdbtk`, `csvtk`, `gemmi`, `openbabel`
- JupyterLab and Marimo, for interactive analysis in the same environment

## Use

```bash
docker run --rm -v "$(pwd)":/data -w /data \
  ghcr.io/australian-protein-design-initiative/containers/nf-binder-design-utils:0.1.7-arm64 \
  python my_script.py
```

JupyterLab is the default command, on port 8888:

```bash
docker run --rm -p 8888:8888 -v "$(pwd)":/data -w /data \
  ghcr.io/australian-protein-design-initiative/containers/nf-binder-design-utils:0.1.7-arm64
```

To use it from nf-binder-design on an arm64 host, override the container for the processes that
use this image, for example in a config file:

```groovy
process {
    withName: '.*' {
        container = { task.container?.contains('nf-binder-design-utils')
            ? 'ghcr.io/australian-protein-design-initiative/containers/nf-binder-design-utils:0.1.7-arm64'
            : task.container }
    }
}
```
EOF

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
