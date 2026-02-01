# https://github.com/yehlincho/Protein-Hunter/
#
# Build like:
#  docker build -t protein-hunter:latest --build-arg GIT_REF=main .
#
# Run like:
#  docker run --gpus all -v $(pwd)/results_boltz:/app/results_boltz -it --rm protein-hunter python boltz_ph/design.py --num_designs 3 --num_cycles 7 --protein_seqs AFTVTVPKDLYVVEYGSNMTIECKFPVEKQLDLAALIVYWEMEDKNIIQFVHGEEDLKVQHSSYRQRARLLKDQLSLGNAALQITDVKLQDAGVYRCMISYGGADYKRITVKVNAPYAAALE --msa_mode "mmseqs" --gpu_id 0 --name PDL1_mix_aa_all_X --percent_X 100 --min_protein_length 90 --max_protein_length 150 --high_iptm_threshold 0.7 --plot
#

ARG GIT_REPO=https://github.com/yehlincho/Protein-Hunter.git
ARG GIT_REF=d4bd951

FROM continuumio/miniconda3

LABEL org.opencontainers.image.source=https://github.com/Australian-Protein-Design-Initiative/containers
LABEL org.opencontainers.image.description="Protein Hunter: exploiting structure hallucination within diffusion for protein design"
LABEL org.opencontainers.image.title="Protein Hunter"
LABEL org.opencontainers.image.authors="Andrew Perry <andrew.perry@monash.edu>"
LABEL org.opencontainers.image.licenses="MIT"
LABEL org.opencontainers.image.vendor="containerbot"

# Set working directory to a temp location first
WORKDIR /tmp

# Install system dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    git \
    wget \
    curl \
    build-essential \
    gcc \
    g++ \
    && rm -rf /var/lib/apt/lists/*

# Clone repository
RUN git clone https://github.com/yehlincho/Protein-Hunter.git Protein-Hunter && \
    cd Protein-Hunter && \
    git checkout ${GIT_REF}

# Move to final location
WORKDIR /app
RUN cp -r /tmp/Protein-Hunter/* /app/ && \
    rm -rf /tmp/Protein-Hunter

# Create conda environment with Python 3.10
RUN conda create -n proteinhunter python=3.10 -y && \
    echo "conda activate proteinhunter" >> ~/.bashrc

# Activate environment and set PATH
ENV PATH="/opt/conda/envs/proteinhunter/bin:${PATH}"

# Install Boltz
RUN cd boltz_ph && pip install -e . && cd ..

# Install Python dependencies
RUN pip install --no-cache-dir \
    matplotlib \
    seaborn \
    prody \
    tqdm \
    PyYAML \
    requests \
    pypdb \
    py3Dmol \
    "logmd==0.1.45" \
    ml_collections

# Install PyRosetta
RUN pip install pyrosettacolabsetup pyrosetta-installer && \
    python -c 'import pyrosetta_installer; pyrosetta_installer.install_pyrosetta()'

# Fix NumPy/Numba compatibility
RUN pip install --no-cache-dir --upgrade "numpy>=1.24,<1.27" numba

# Download Boltz weights
RUN python -c "from boltz.main import download_boltz2; from pathlib import Path; cache = Path('~/.boltz').expanduser(); cache.mkdir(parents=True, exist_ok=True); download_boltz2(cache)"

# Setup LigandMPNN
RUN cd LigandMPNN && bash get_model_params.sh "./model_params" && cd ..

# Make DAlphaBall.gcc executable
RUN chmod +x utils/DAlphaBall.gcc

# Install Chai Lab
RUN pip install --no-deps \
    git+https://github.com/sokrypton/chai-lab.git \
    'gemmi~=0.6.3' \
    'jaxtyping>=0.2.25' \
    'pandera>=0.24' \
    'antipickle==0.2.0' \
    'rdkit~=2024.9.5' \
    'modelcif>=1.0' \
    'biopython>=1.83' \
    typing_inspect \
    beartype \
    typeguard \
    ihm \
    mypy_extensions \
    equinox \
    wadler_lindig \
    py3Dmol

# Create py2Dmol compatibility module that persists
RUN mkdir -p /opt/conda/envs/proteinhunter/lib/python3.10/site-packages/py2Dmol && \
    echo 'import py3Dmol' > /opt/conda/envs/proteinhunter/lib/python3.10/site-packages/py2Dmol/__init__.py && \
    echo '__all__ = ["view"]' >> /opt/conda/envs/proteinhunter/lib/python3.10/site-packages/py2Dmol/__init__.py && \
    echo 'view = py3Dmol.view' >> /opt/conda/envs/proteinhunter/lib/python3.10/site-packages/py2Dmol/__init__.py && \
    echo 'show = lambda *args, **kwargs: None' >> /opt/conda/envs/proteinhunter/lib/python3.10/site-packages/py2Dmol/__init__.py && \
    echo 'loadModel = lambda *args, **kwargs: None' >> /opt/conda/envs/proteinhunter/lib/python3.10/site-packages/py2Dmol/__init__.py

# Verify chai-lab installation with py2Dmol compatibility
RUN python -c "import chai_lab; import py2Dmol; print('Chai-lab and py2Dmol compatibility verified')"

# Install Jupyter kernel for optional notebook usage
RUN pip install ipykernel && \
    python -m ipykernel install --user --name=proteinhunter --display-name="Protein Hunter"

# Create directories for outputs
RUN mkdir -p /app/output /app/data

# Set environment variables
ENV PYTHONPATH="/app:${PYTHONPATH}"
ENV PROTEIN_HUNTER_HOME="/app"

# Default command: show help for Boltz design script
CMD ["python", "boltz_ph/design.py", "--help"]