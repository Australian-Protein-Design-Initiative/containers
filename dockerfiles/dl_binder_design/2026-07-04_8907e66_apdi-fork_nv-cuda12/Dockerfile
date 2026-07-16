# Build like:
#   docker build -t dl_binder_design:apdi-fork_nv-cuda12 .
# Skip optional weight downloads (~3.5 GB AlphaFold params + HyperMPNN/PottsMPNN):
#   docker build --build-arg DOWNLOAD_WEIGHTS=false -t dl_binder_design:apdi-fork_nv-cuda12 .

ARG CUDA=12.2.2
ARG GIT_REPO=https://github.com/Australian-Protein-Design-Initiative/dl_binder_design
# main with ipTM, ipSAE added
ARG GIT_REF=7f813d9
ARG PROTEINMPNN_REPO=https://github.com/dauparas/ProteinMPNN.git
ARG PROTEINMPNN_REF=8907e66

FROM nvidia/cuda:${CUDA}-cudnn8-runtime-ubuntu20.04

LABEL org.opencontainers.image.source="https://github.com/Australian-Protein-Design-Initiative/containers" \
      org.opencontainers.image.title="dl_binder_design (AF2 Initial Guess + ProteinMPNN, APDI fork)" \
      org.opencontainers.image.description="Combined dl_binder_design APDI fork: AlphaFold2 initial guess (JAX/TF) and ProteinMPNN/FastRelax (PyTorch) — CUDA 12.2" \
      org.opencontainers.image.version="7f813d9" \
      org.opencontainers.image.revision="7f813d9" \
      org.opencontainers.image.licenses="MIT" \
      org.opencontainers.image.vendor="Australian Protein Design Initiative" \
      org.opencontainers.image.base.name="docker.io/nvidia/cuda:12.2.2-cudnn8-runtime-ubuntu20.04" \
      org.opencontainers.image.base.digest="sha256:1da6cf17f9c651323905c8cf5fd63a781a9a2fc0d28a477ca21df80a7bfaa00c" \
      org.opencontainers.image.usage="docker run --rm --gpus all -it -v \$(pwd)/workdir:/workspace dl_binder_design:apdi-fork_nv-cuda12 bash"

ARG CUDA
ARG GIT_REPO
ARG GIT_REF
ARG PROTEINMPNN_REPO
ARG PROTEINMPNN_REF

ENV DEBIAN_FRONTEND=noninteractive

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

RUN apt-get update --quiet \
  && apt-get install --no-install-recommends --yes --quiet \
  build-essential \
  cmake \
  cuda-command-line-tools-$(cut -f1,2 -d- <<< ${CUDA//./-}) \
  git \
  tzdata \
  wget \
  && rm -rf /var/lib/apt/lists/* \
  && apt-get autoremove --yes \
  && apt-get clean

# Miniforge (conda-forge by default — avoids the Anaconda defaults-channel ToS).
RUN wget -q -O /tmp/miniforge.sh \
       https://github.com/conda-forge/miniforge/releases/latest/download/Miniforge3-Linux-x86_64.sh \
    && bash /tmp/miniforge.sh -b -p /opt/conda \
    && rm /tmp/miniforge.sh

ENV PATH="/opt/conda/bin:${PATH}"

# Two dedicated envs (not base): PyRosetta pins zlib <1.3, which conflicts with
# Miniforge base's mamba/zstd stack. af2ig (JAX/TF) and proteinmpnn (PyTorch)
# are kept separate because their pip/conda stacks do not combine cleanly.
RUN mamba create -y -n af2ig python=3.11.9 \
    && mamba install -y -n af2ig \
        -c https://conda.rosettacommons.org \
        -c pytorch \
        -c nvidia \
        -c conda-forge \
        pip \
        biopython=1.81 \
        ml-collections=1.0.0 \
        ml_dtypes=0.3.2 \
        pyrosetta=2024.42+release.3366cf78a3 \
        mock=5.1.0 \
        nvidia::cuda=${CUDA} \
        openmm=8.0.0 \
        pdbfixer \
    && mamba create -y -n proteinmpnn python=3.11.9 \
    && mamba install -y -n proteinmpnn \
        -c https://conda.rosettacommons.org \
        -c pytorch \
        -c nvidia \
        -c conda-forge \
        pytorch=2.0.1 \
        pytorch-cuda=11.8 \
        biopython=1.81 \
        ml-collections=1.0.0 \
        pyrosetta=2024.42+release.3366cf78a3 \
        "numpy<2" \
    && mamba clean -afy

RUN conda run -n af2ig pip install --no-cache-dir \
        "dm-haiku==0.0.13" \
        "dm-tree==0.1.8" \
        "flax" \
        "tensorflow[and-cuda]" \
        "absl-py==1.0.0" \
        "chex==0.1.86" \
        "docker==5.0.0" \
        "immutabledict==2.0.0" \
        "jax==0.4.26" \
        "numpy==1.24.3" \
        "pandas==2.0.3" \
        "setuptools<72.0.0" \
        "scipy==1.11.1" \
        "tensorflow-cpu==2.16.1" \
    && conda run -n af2ig pip install --upgrade --no-cache-dir \
        --find-links https://storage.googleapis.com/jax-releases/jax_cuda_releases.html \
        "jax[cuda12_pip]==0.4.26" \
        "jaxlib==0.4.26+cuda12.cudnn89"

# Currently needed to avoid undefined_symbol error in the af2ig env.
RUN ln -sf /usr/lib/x86_64-linux-gnu/libffi.so.7 /opt/conda/envs/af2ig/lib/libffi.so.7

WORKDIR /app

RUN git clone ${GIT_REPO} /app/dl_binder_design \
    && cd /app/dl_binder_design \
    && git checkout ${GIT_REF}

RUN git clone ${PROTEINMPNN_REPO} /app/dl_binder_design/mpnn_fr/ProteinMPNN \
    && cd /app/dl_binder_design/mpnn_fr/ProteinMPNN \
    && git checkout ${PROTEINMPNN_REF}

RUN conda run -n af2ig python /app/dl_binder_design/include/importtests/af2_importtest.py \
    && conda run -n proteinmpnn python /app/dl_binder_design/include/importtests/proteinmpnn_importtest.py

# ProteinMPNN vanilla/soluble/ca weights ship with the ProteinMPNN clone.
RUN mkdir -p /models/ProteinMPNN \
    && ln -s /app/dl_binder_design/mpnn_fr/ProteinMPNN/vanilla_model_weights /models/ProteinMPNN/vanilla_model_weights \
    && ln -s /app/dl_binder_design/mpnn_fr/ProteinMPNN/soluble_model_weights /models/ProteinMPNN/soluble_model_weights \
    && ln -s /app/dl_binder_design/mpnn_fr/ProteinMPNN/ca_model_weights /models/ProteinMPNN/ca_model_weights \
    && mkdir -p /models/af2_initial_guess/model_weights/params \
    && mkdir -p /app/dl_binder_design/af2_initial_guess/model_weights \
    && ln -s /models/af2_initial_guess/model_weights/params /app/dl_binder_design/af2_initial_guess/model_weights/params

# Download AlphaFold params (~3.5 GB), HyperMPNN, and PottsMPNN weights at build time.
# Skip with --build-arg DOWNLOAD_WEIGHTS=false and mount at runtime instead.
ARG DOWNLOAD_WEIGHTS=true
RUN if [ "${DOWNLOAD_WEIGHTS}" = "true" ]; then \
        cd /models/af2_initial_guess/model_weights/params \
        && wget https://storage.googleapis.com/alphafold/alphafold_params_2022-12-06.tar \
        && tar --extract --verbose --file=alphafold_params_2022-12-06.tar \
        && rm alphafold_params_2022-12-06.tar \
        && mkdir -p /models/HyperMPNN \
        && cd /models/HyperMPNN \
        && wget https://github.com/meilerlab/HyperMPNN/raw/refs/heads/main/retrained_models/v48_002_epoch240_hyper.pt \
        && wget https://github.com/meilerlab/HyperMPNN/raw/refs/heads/main/retrained_models/v48_010_epoch300_hyper.pt \
        && wget https://github.com/meilerlab/HyperMPNN/raw/refs/heads/main/retrained_models/v48_020_epoch300_hyper.pt \
        && wget https://github.com/meilerlab/HyperMPNN/raw/refs/heads/main/retrained_models/v48_030_epoch300_hyper.pt \
        && mkdir -p /models/PottsMPNN \
        && cd /models/PottsMPNN \
        && wget https://github.com/KeatingLab/PottsMPNN/raw/refs/heads/main/proteinmpnn_compatible_model_weights/pottsmpnn_20.pt \
        && wget https://github.com/KeatingLab/PottsMPNN/raw/refs/heads/main/proteinmpnn_compatible_model_weights/pottsmpnn_30.pt \
        && wget https://github.com/KeatingLab/PottsMPNN/raw/refs/heads/main/proteinmpnn_compatible_model_weights/pottsmpnn_msa_20.pt \
        && wget https://github.com/KeatingLab/PottsMPNN/raw/refs/heads/main/proteinmpnn_compatible_model_weights/sol_pottsmpnn_20.pt \
        && wget https://github.com/KeatingLab/PottsMPNN/raw/refs/heads/main/proteinmpnn_compatible_model_weights/sol_pottsmpnn_30.pt \
        && wget https://github.com/KeatingLab/PottsMPNN/raw/refs/heads/main/proteinmpnn_compatible_model_weights/sol_pottsmpnn_msa_20.pt; \
    fi

RUN conda init bash

RUN cat > /README.md <<'READMEEOF'
# dl_binder_design — AF2 Initial Guess + ProteinMPNN (APDI fork)

**Source repository:** https://github.com/Australian-Protein-Design-Initiative/dl_binder_design (commit: 7f813d9)
**ProteinMPNN:** https://github.com/dauparas/ProteinMPNN (commit: 8907e66)
**Container source:** https://github.com/Australian-Protein-Design-Initiative/containers

Combined image for both workflows from the APDI `dl_binder_design` fork (ipTM / ipSAE):
AlphaFold2 initial guess and ProteinMPNN interface design with Rosetta FastRelax.

## Conda environments

This image ships two separate conda envs (PyRosetta and the JAX vs PyTorch stacks do not
combine cleanly in one environment):

| Env | Use for |
|-----|---------|
| `af2ig` | AlphaFold2 initial guess (`af2_initial_guess/predict.py`) — JAX, TensorFlow, OpenMM |
| `proteinmpnn` | ProteinMPNN / FastRelax (`mpnn_fr/dl_interface_design.py`) — PyTorch |

Activate interactively with `conda activate af2ig` or `conda activate proteinmpnn`, or use
`conda run -n <env> python ...` for one-off commands.

## Model weights

When built with `DOWNLOAD_WEIGHTS=true` (default):

- **AlphaFold params** (~3.5 GB): `/models/af2_initial_guess/model_weights/params`
- **ProteinMPNN** (from clone): `/models/ProteinMPNN/{vanilla,soluble,ca}_model_weights`
- **HyperMPNN**: `/models/HyperMPNN/*.pt`
- **PottsMPNN**: `/models/PottsMPNN/*.pt`

Build without baked-in weights:

```bash
docker build --build-arg DOWNLOAD_WEIGHTS=false -t dl_binder_design:apdi-fork_nv-cuda12 .
```

Mount at runtime, e.g.:

```bash
-v $(pwd)/af2_params:/models/af2_initial_guess/model_weights/params
-v $(pwd)/HyperMPNN:/models/HyperMPNN
-v $(pwd)/PottsMPNN:/models/PottsMPNN
```

## Usage

Interactive shell (default):

```bash
mkdir -p workdir
docker run --rm --gpus all -it \
  -v $(pwd)/workdir:/workspace \
  dl_binder_design:apdi-fork_nv-cuda12
```

### AlphaFold2 initial guess

```bash
docker run --rm --gpus all \
  -v $(pwd)/workdir:/workspace \
  dl_binder_design:apdi-fork_nv-cuda12 \
  conda run -n af2ig python /app/dl_binder_design/af2_initial_guess/predict.py
```

Or inside an interactive shell:

```bash
conda activate af2ig
python /app/dl_binder_design/af2_initial_guess/predict.py
```

### ProteinMPNN / FastRelax interface design

```bash
docker run --rm --gpus all \
  -v $(pwd)/workdir:/workspace \
  dl_binder_design:apdi-fork_nv-cuda12 \
  conda run -n proteinmpnn python /app/dl_binder_design/mpnn_fr/dl_interface_design.py
```

Or inside an interactive shell:

```bash
conda activate proteinmpnn
python /app/dl_binder_design/mpnn_fr/dl_interface_design.py
```

See the upstream `dl_binder_design` repository for script arguments and example inputs.
READMEEOF

CMD ["/bin/bash"]
