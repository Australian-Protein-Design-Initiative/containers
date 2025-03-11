FROM python:3.11-slim

# Set environment variables
ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    DEBIAN_FRONTEND=noninteractive

# Install system dependencies and Node.js 20.x
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    libopenmpi-dev \
    curl \
    gnupg \
    ca-certificates \
    procps \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Install Node.js 20.x
RUN curl -fsSL https://deb.nodesource.com/setup_20.x | bash - && \
    apt-get install -y nodejs && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* 

# Verify Node.js installation
RUN node --version && npm --version

# Upgrade pip and install Python packages globally
RUN pip install --upgrade pip && \
    pip install --no-cache-dir \
    MDAnalysis[analysis] \
    pandas \
    biopython \
    jupyterlab \
    ipywidgets \
    jupyter_core

# Install Jupyter widget extension
RUN jupyter labextension install @jupyter-widgets/jupyterlab-manager

# Create a non-root user to run the application
RUN useradd -m mda-user
WORKDIR /home/mda-user/app

# Set proper ownership for the working directory
RUN chown -R mda-user:mda-user /home/mda-user/app

# Switch to non-root user for running the application
USER mda-user

# Set default port for Jupyter
EXPOSE 8888

# Set the entrypoint to jupyter
CMD ["jupyter", "lab", "--ip=0.0.0.0", "--no-browser"]
