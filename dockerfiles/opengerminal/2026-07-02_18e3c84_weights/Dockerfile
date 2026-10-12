# syntax=docker/dockerfile:1
# Build like:
#   just build opengerminal/2026-07-02_18e3c84_weights
#   just build opengerminal/2026-07-02_18e3c84_weights --variant no-weights
#
# Adapted from OpenGerminal Dockerfile.free (PyRosetta-free) at GIT_REF.
# AF-Multimer parameter download follows OpenGerminal's Dockerfile.
# Chai-1 and AbLang weights are baked in as well; upstream mounts those at runtime.

FROM nvidia/cuda:12.4.1-cudnn-runtime-ubuntu22.04@sha256:0bb88834d973ca1b450fcc2a05333c6fe45510bee289912a5391274c351c4a4d

LABEL org.opencontainers.image.source=https://github.com/Australian-Protein-Design-Initiative/containers
LABEL org.opencontainers.image.url=https://github.com/teaninja/OpenGerminal
LABEL org.opencontainers.image.documentation=https://github.com/teaninja/OpenGerminal/blob/18e3c84875b190b5df732fcb21b917276f1c1a36/README.md
LABEL org.opencontainers.image.title="OpenGerminal"
LABEL org.opencontainers.image.description="PyRosetta-free Germinal antibody design pipeline (VHH and scFv), with AF-Multimer, Chai-1, and AbLang weights."
LABEL org.opencontainers.image.licenses="Apache-2.0"
LABEL org.opencontainers.image.version="18e3c84"
LABEL org.opencontainers.image.revision="18e3c84875b190b5df732fcb21b917276f1c1a36"
LABEL org.opencontainers.image.vendor="Australian Protein Design Initiative"
LABEL org.opencontainers.image.base.name="docker.io/nvidia/cuda:12.4.1-cudnn-runtime-ubuntu22.04"
LABEL org.opencontainers.image.base.digest="sha256:0bb88834d973ca1b450fcc2a05333c6fe45510bee289912a5391274c351c4a4d"
LABEL org.opencontainers.image.usage="docker run --gpus all --rm -v \"\$PWD/results:/workspace/results\" -w /workspace ghcr.io/australian-protein-design-initiative/containers/opengerminal:2026-07-02_18e3c84_weights python run_germinal.py target=pdl1 experiment_name=demo structure_model=chai"

ARG GIT_REPO=https://github.com/teaninja/OpenGerminal.git
ARG GIT_REF=18e3c84

ENV DEBIAN_FRONTEND=noninteractive
SHELL ["/bin/bash", "-lc"]

RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt,sharing=locked \
    apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates curl git bzip2 aria2 ffmpeg procps tini \
    build-essential libssl-dev

ENV MAMBA_ROOT_PREFIX=/opt/conda
ENV MAMBA_NO_BANNER=1
RUN curl -Ls https://micro.mamba.pm/api/micromamba/linux-64/latest | \
    tar -xvj -C /usr/local/bin --strip-components=1 bin/micromamba

ENV CONDA_ENV=germinal
RUN --mount=type=cache,target=/opt/conda/pkgs,sharing=locked \
    micromamba create -y -n ${CONDA_ENV} -c conda-forge python=3.10 pip

ENV PATH=/opt/conda/envs/${CONDA_ENV}/bin:${PATH}
ENV PYTHONUNBUFFERED=1 MPLBACKEND=Agg HYDRA_FULL_ERROR=1

RUN --mount=type=cache,target=/opt/conda/pkgs,sharing=locked \
    micromamba install -y -n ${CONDA_ENV} -c conda-forge openmm pdbfixer

RUN --mount=type=cache,target=/root/.cache/pip \
    --mount=type=cache,target=/root/.cache/uv \
    python -m pip install --upgrade pip wheel setuptools && python -m pip install uv

RUN --mount=type=cache,target=/root/.cache/pip \
    --mount=type=cache,target=/root/.cache/uv \
    uv pip install --system \
    pandas matplotlib numpy biopython scipy seaborn tqdm ffmpeg py3dmol \
    chex dm-haiku==0.0.13 dm-tree joblib ml-collections immutabledict \
    optax cvxopt mdtraj colabfold ipsae==1.0.1 freesasa MDAnalysis

RUN --mount=type=cache,target=/root/.cache/pip \
    --mount=type=cache,target=/root/.cache/uv \
    uv pip install --system \
    --index-url https://download.pytorch.org/whl/cu124 \
    "torch==2.6.0" "torchvision==0.21.0" "torchaudio==2.6.0"

RUN --mount=type=cache,target=/root/.cache/pip \
    --mount=type=cache,target=/root/.cache/uv \
    uv pip install --system torchtyping==0.1.5

RUN --mount=type=cache,target=/root/.cache/pip \
    --mount=type=cache,target=/root/.cache/uv \
    PYG_URL="https://data.pyg.org/whl/torch-2.6.0%2Bcu124.html" && \
    uv pip install --system "torch_geometric==2.6.*" -f "${PYG_URL}"

RUN --mount=type=cache,target=/root/.cache/pip \
    --mount=type=cache,target=/root/.cache/uv \
    uv pip install --system ablang && \
    uv pip install --system ablang2==0.2.1 --no-deps && \
    uv pip install --system rotary_embedding_torch==0.8.9 --no-deps && \
    uv pip install --system chai-lab==0.6.1

RUN --mount=type=cache,target=/root/.cache/pip \
    --mount=type=cache,target=/root/.cache/uv \
    uv pip install --system jax==0.5.3 && \
    uv pip install --system hydra-core omegaconf && \
    uv pip install --system "jax[cuda12_pip]==0.5.3" \
    -f https://storage.googleapis.com/jax-releases/jax_cuda_releases.html

WORKDIR /workspace

RUN git clone "${GIT_REPO}" . && git checkout "${GIT_REF}" && git rev-parse HEAD

RUN chmod a+x /workspace/params/dssp /workspace/params/DAlphaBall.gcc && \
    mkdir -p /workspace/pdbs /workspace/results

RUN --mount=type=cache,target=/root/.cache/pip \
    --mount=type=cache,target=/root/.cache/uv \
    uv pip install --system -e /workspace/colabdesign && \
    uv pip install --system -e .

# Point the pipeline at baked-in weights. Upstream leaves af_params_dir empty and
# resolves "params/<file>" from the working directory.
RUN python - <<'PY'
from pathlib import Path
p = Path("/workspace/configs/config.yaml")
text = p.read_text()
replacements = {
    'af_params_dir: ""': 'af_params_dir: "/weights/alphafold"',
    'dssp_path: "params/dssp"': 'dssp_path: "/workspace/params/dssp"',
    'dalphaball_path: "params/DAlphaBall.gcc"': 'dalphaball_path: "/workspace/params/DAlphaBall.gcc"',
    'pdb_dir: "pdbs"': 'pdb_dir: "/workspace/pdbs"',
}
for old, new in replacements.items():
    if old not in text:
        raise SystemExit(f"config pattern not found: {old}")
    text = text.replace(old, new, 1)
p.write_text(text)
PY

RUN python /workspace/validate_install.py

# Chai-1 reads CHAI_DOWNLOADS_DIR (chai_lab.utils.paths). AbLang2 reads
# model-weights-* inside its package directory, so those paths are symlinked.
ENV CHAI_DOWNLOADS_DIR=/weights/chai
ARG DOWNLOAD_WEIGHTS=true

RUN --mount=type=cache,target=/opt/cache/weights,sharing=locked \
    set -euxo pipefail; \
    mkdir -p /weights/alphafold \
      /weights/chai/models_v2 \
      /weights/chai/esm \
      /weights/ablang/model-weights-ablang1-heavy \
      /weights/ablang/model-weights-ablang2-paired; \
    ln -sfn /weights /models; \
    ABLANG2_DIR="$(python -c 'import ablang2, os; print(os.path.dirname(ablang2.__file__))')"; \
    ln -sfn /weights/ablang/model-weights-ablang1-heavy "${ABLANG2_DIR}/model-weights-ablang1-heavy"; \
    ln -sfn /weights/ablang/model-weights-ablang2-paired "${ABLANG2_DIR}/model-weights-ablang2-paired"; \
    if [ "${DOWNLOAD_WEIGHTS}" != "true" ]; then \
      echo "DOWNLOAD_WEIGHTS=${DOWNLOAD_WEIGHTS}; skipping weight download"; \
      exit 0; \
    fi; \
    cache=/opt/cache/weights; \
    mkdir -p "${cache}"; \
    fetch() { \
      local url="$1" dest="$2"; \
      local name; name="$(basename "${dest}")"; \
      aria2c -c -x 16 -s 16 --summary-interval=30 -d "${cache}" -o "${name}" "${url}"; \
      if [ "${cache}/${name}" != "${dest}" ]; then \
        cp -a "${cache}/${name}" "${dest}"; \
      fi; \
    }; \
    fetch https://storage.googleapis.com/alphafold/alphafold_params_2022-12-06.tar \
      "${cache}/alphafold_params_2022-12-06.tar"; \
    tar -xf "${cache}/alphafold_params_2022-12-06.tar" -C /weights/alphafold; \
    if [ ! -f /weights/alphafold/params_model_1_multimer_v3.npz ]; then \
      found="$(find /weights/alphafold -name params_model_1_multimer_v3.npz -type f | head -1)"; \
      test -n "${found}"; \
      dir="$(dirname "${found}")"; \
      find "${dir}" -maxdepth 1 -name 'params_*.npz' -exec cp -a {} /weights/alphafold/ \;; \
    fi; \
    test -f /weights/alphafold/params_model_1_multimer_v3.npz; \
    for f in /weights/alphafold/params_*.npz; do \
      ln -sfn "${f}" "/workspace/params/$(basename "${f}")"; \
    done; \
    fetch https://chaiassets.com/chai1-inference-depencencies/conformers_v1.apkl \
      /weights/chai/conformers_v1.apkl; \
    for comp in feature_embedding token_embedder trunk diffusion_module confidence_head; do \
      fetch "https://chaiassets.com/chai1-inference-depencencies/models_v2/${comp}.pt" \
        "/weights/chai/models_v2/${comp}.pt"; \
    done; \
    fetch https://chaiassets.com/chai1-inference-depencencies/esm2/traced_sdpa_esm2_t36_3B_UR50D_fp16.pt \
      /weights/chai/esm/traced_sdpa_esm2_t36_3B_UR50D_fp16.pt; \
    extract_ablang() { \
      local name="$1" url="$2" expected="$3"; \
      local dest="/weights/ablang/model-weights-${name}"; \
      local archive="${cache}/${name}.tar.gz"; \
      if [ ! -s "${archive}" ]; then \
        rm -f "${archive}" "${archive}.aria2"; \
        echo "Downloading ${url}"; \
        curl -fL --retry 8 --retry-all-errors --retry-delay 5 \
          -A "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36" \
          -o "${archive}" "${url}"; \
      else \
        echo "Using cached ${archive}"; \
      fi; \
      tar -zxf "${archive}" -C "${dest}"; \
      if [ ! -f "${dest}/${expected}" ]; then \
        found="$(find "${dest}" -name "${expected}" -type f | head -1)"; \
        test -n "${found}"; \
        dir="$(dirname "${found}")"; \
        if [ "${dir}" != "${dest}" ]; then \
          find "${dir}" -maxdepth 1 -mindepth 1 -exec mv {} "${dest}/" \;; \
        fi; \
      fi; \
      test -f "${dest}/${expected}"; \
    }; \
    extract_ablang ablang1-heavy \
      https://opig.stats.ox.ac.uk/data/downloads/ablang-heavy.tar.gz amodel.pt; \
    extract_ablang ablang2-paired \
      https://zenodo.org/records/10185169/files/ablang2-weights.tar.gz model.pt; \
    chmod -R a+rX /weights /workspace/params

RUN cat > /README.md <<'EOF'
# OpenGerminal

PyRosetta-free Germinal antibody design pipeline (VHH nanobodies and scFv).

- Source: https://github.com/teaninja/OpenGerminal
- Commit: 18e3c84875b190b5df732fcb21b917276f1c1a36 (`18e3c84`, 2026-07-02)
- Image source: https://github.com/Australian-Protein-Design-Initiative/containers

This image follows upstream `Dockerfile.free` (OpenMM, FreeSASA, AbLang, Chai-1; no PyRosetta, no IgLM).
AF-Multimer parameters are included the same way as upstream `Dockerfile`.

## Weights

Baked in when `DOWNLOAD_WEIGHTS=true` (the default for this tag):

| Weights | Path |
| --- | --- |
| AF-Multimer parameters | `/weights/alphafold` (also linked from `/workspace/params/params_*.npz`) |
| Chai-1 v0.6.1 | `/weights/chai` (`CHAI_DOWNLOADS_DIR`) |
| AbLang1-heavy and AbLang2-paired | `/weights/ablang` (symlinked into the `ablang2` package) |

`/models` is a symlink to `/weights`. `configs/config.yaml` sets `af_params_dir` to `/weights/alphafold`.

A no-weights build leaves those directories empty. Mount populated directories at the same paths.

## Usage

Example PDBs ship in the image under `/workspace/pdbs` (`pdl1.pdb`, `nb.pdb`, `il3.pdb`, `insulin.pdb`, `scfv.pdb`).

```bash
docker run --gpus all --rm \
  -v "$PWD/results:/workspace/results" \
  -w /workspace \
  ghcr.io/australian-protein-design-initiative/containers/opengerminal:2026-07-02_18e3c84_weights \
  python run_germinal.py target=pdl1 experiment_name=demo structure_model=chai
```

Mount your own target YAML and PDB, and keep the working directory at `/workspace` so relative config paths resolve:

```bash
docker run --gpus all --rm \
  -v "$PWD/results:/workspace/results" \
  -v "$PWD/pdbs:/workspace/pdbs" \
  -v "$PWD/my_target.yaml:/workspace/configs/target/my_target.yaml" \
  -w /workspace \
  ghcr.io/australian-protein-design-initiative/containers/opengerminal:2026-07-02_18e3c84_weights \
  python run_germinal.py target=my_target experiment_name=demo structure_model=chai
```

Needs an NVIDIA GPU with about 40 GB of VRAM (A100 or similar). `python run_germinal.py --help` lists Hydra options.
EOF

CMD ["bash"]
