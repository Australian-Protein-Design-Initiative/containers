# Build like:
#  docker buildx build -t cf-random:latest -f Dockerfile --build-arg GIT_REPO=https://github.com/ncbi/CF-random_software --build-arg GIT_REF=main .

FROM mambaorg/micromamba:latest

# Re-define ARGs after FROM (ARGs before FROM are reset)
ARG GIT_REPO=https://github.com/ncbi/CF-random_software
ARG GIT_REF=main
ARG LOCALCOLABFOLD_REPO=https://github.com/YoshitakaMo/localcolabfold
ARG LOCALCOLABFOLD_REF=main
LABEL org.opencontainers.image.source="${GIT_REPO}"
LABEL org.opencontainers.image.title="CF-random"
LABEL org.opencontainers.image.description="Predict alternative protein conformations and fold-switching proteins using AlphaFold2-based sequence association"
LABEL org.opencontainers.image.version="1.0"
LABEL org.opencontainers.image.authors="NCBI"
LABEL org.opencontainers.image.licenses="See LICENSE.md"

# Install system dependencies
RUN micromamba install -y -c conda-forge \
    wget \
    git \
    curl \
    ca-certificates \
    && micromamba clean -a -y

USER root
RUN apt-get update && apt-get install -y --no-install-recommends \
    procps \
    && rm -rf /var/lib/apt/lists/*
USER mambauser

# Set up conda environment
ENV PATH="/opt/conda/bin:$PATH"
ENV CONDA_DIR="/opt/conda"

# Create conda environment for CF-random with Python 3.10
RUN micromamba create -y -p /opt/conda/envs/cf-random \
    python=3.10 \
    gxx_linux-64 \
    gcc_linux-64 \
    gfortran_linux-64 \
    binutils_linux-64 \
    openmm==8.2.0 \
    pdbfixer==1.10 \
    kalign2==2.04 \
    hhsuite==3.3.0 \
    mmseqs2 \
    foldseek \
    -c conda-forge -c bioconda \
    && micromamba clean -a -y

# Clone LocalColabFold repository (using base shell)
RUN git clone ${LOCALCOLABFOLD_REPO} /tmp/localcolabfold && \
    cd /tmp/localcolabfold && \
    git checkout ${LOCALCOLABFOLD_REF}

# Clone CF-random repository as mambauser
USER mambauser
WORKDIR /home/mambauser/app
RUN git clone ${GIT_REPO} .

# Activate the environment for Python operations
SHELL ["micromamba", "run", "-n", "cf-random", "/bin/bash", "-c"]

# Install ColabFold and JAX with CUDA support
RUN pip install --no-warn-conflicts \
    "colabfold[alphafold-minus-jax] @ git+https://github.com/sokrypton/ColabFold" && \
    pip install "colabfold[alphafold]" && \
    pip install --upgrade "jax[cuda12]==0.5.3" && \
    pip install --upgrade tensorflow && \
    pip install silence_tensorflow

# Install CF-random Python dependencies
RUN pip install \
    textalloc \
    tmtools \
    adjustText \
    thefuzz \
    mdtraj \
    biopython \
    seaborn \
    MDAnalysis \
    scikit-learn

# Install pymol-open-source from conda-forge
RUN micromamba install -y -c conda-forge pymol-open-source && \
    micromamba clean -a -y

# Switch back to base shell for operations that need root permissions
SHELL ["/bin/bash", "-c"]

# Switch to root user for creating directories
USER root

# Copy CF-random code to /opt/cf-random for easy access
RUN mkdir -p /opt/cf-random && \
    cp -r /home/mambauser/app/code /opt/cf-random/ && \
    chmod +x /opt/cf-random/code/*.py

# Switch to micromamba shell for Python operations
USER mambauser
SHELL ["micromamba", "run", "-n", "cf-random", "/bin/bash", "-c"]

# Modify ColabFold for non-GUI backend and suppress TensorFlow warnings
RUN sed -i -e "1s#^#import matplotlib\\nmatplotlib.use('Agg')\\n#" \
    /opt/conda/envs/cf-random/lib/python*/site-packages/colabfold/plot.py && \
    sed -i -e "s#from io import StringIO#from io import StringIO\\nfrom silence_tensorflow import silence_tensorflow\\nsilence_tensorflow()#g" \
    /opt/conda/envs/cf-random/lib/python*/site-packages/colabfold/batch.py

# Modify default params directory in download.py
RUN sed -i -e "s#appdirs.user_cache_dir(__package__ or \"colabfold\")#\"/opt/conda/params\"#g" \
    /opt/conda/envs/cf-random/lib/python*/site-packages/colabfold/download.py

# Remove cache directory
RUN rm -rf /opt/conda/envs/cf-random/lib/python*/site-packages/colabfold/__pycache__

# Switch to root for directory creation (keep micromamba shell)
SHELL ["/bin/bash", "-c"]
USER root

# Download AlphaFold2 weights (non-interactive)
RUN /opt/conda/envs/cf-random/bin/python -m colabfold.download

# Create foldseek directory and download PDB database
RUN mkdir -p /opt/foldseek && \
    /opt/conda/envs/cf-random/bin/foldseek databases PDB /opt/foldseek/pdb /tmp/foldseek-tmp && \
    rm -rf /tmp/foldseek-tmp

# Switch back to mambauser and micromamba shell
USER mambauser
SHELL ["micromamba", "run", "-n", "cf-random", "/bin/bash", "-c"]

# Set environment variables
ENV PATH="/opt/conda/envs/cf-random/bin:$PATH"
ENV CONDA_DEFAULT_ENV="cf-random"

# Switch to root for final setup
SHELL ["/bin/bash", "-c"]
USER root

# Set working directory
WORKDIR /workspace

# Create directories for data and databases
RUN mkdir -p /workspace/data /workspace/databases /workspace/output

# Copy internal README.md
COPY README.container.md /README.md

# Switch to mambauser for runtime with correct PATH
USER mambauser
SHELL ["micromamba", "run", "-n", "cf-random", "/bin/bash", "-c"]

# Default command shows help
CMD ["python", "/opt/cf-random/code/main.py", "--help"]
