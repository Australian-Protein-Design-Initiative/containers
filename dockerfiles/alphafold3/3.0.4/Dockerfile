# syntax=docker/dockerfile:1.4
# Build like:
#   just build alphafold3/3.0.4
#   docker buildx build -t alphafold3:3.0.4 -f Dockerfile .
#
# Based on the upstream AlphaFold 3 Docker recipe:
#   https://github.com/google-deepmind/alphafold3/tree/v3.0.4/docker
#
# Model parameters are not baked in. Request them from Google and mount at
# /root/models. See https://github.com/google-deepmind/alphafold3
#
# Copyright 2024 DeepMind Technologies Limited
#
# AlphaFold 3 source code is licensed under the Apache License, Version 2.0
# (the "License"); you may not use this file except in compliance with the
# License. You may obtain a copy of the License at
#
# http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#
# To request access to the AlphaFold 3 model parameters, follow the process set
# out at https://github.com/google-deepmind/alphafold3. You may only use these
# if received directly from Google. Use is subject to terms of use available at
# https://github.com/google-deepmind/alphafold3/blob/main/WEIGHTS_TERMS_OF_USE.md

ARG GIT_REPO=https://github.com/google-deepmind/alphafold3.git
ARG GIT_REF=v3.0.4
ARG DOWNLOAD_WEIGHTS=false

FROM nvidia/cuda:12.6.3-base-ubuntu24.04

ARG GIT_REPO
ARG GIT_REF
ARG DOWNLOAD_WEIGHTS

LABEL org.opencontainers.image.source=https://github.com/Australian-Protein-Design-Initiative/containers
LABEL org.opencontainers.image.url="${GIT_REPO}"
LABEL org.opencontainers.image.title="AlphaFold 3"
LABEL org.opencontainers.image.description="AlphaFold 3 biomolecular structure prediction (v3.0.4). Model parameters and genetic databases are not included; mount them at runtime."
LABEL org.opencontainers.image.licenses="Apache-2.0"
LABEL org.opencontainers.image.revision="${GIT_REF}"
LABEL org.opencontainers.image.version="3.0.4"
LABEL org.opencontainers.image.base.name="docker.io/nvidia/cuda:12.6.3-base-ubuntu24.04"
LABEL org.opencontainers.image.base.digest="sha256:6b3201183858bad08441837f5a5efc2c75290135cc25fcc87d9ff763190cfd09"
LABEL org.opencontainers.image.usage="docker run --gpus all --rm -v \$HOME/af_input:/root/af_input -v \$HOME/af_output:/root/af_output -v <MODEL_PARAMETERS_DIR>:/root/models -v <DB_DIR>:/root/public_databases alphafold3:3.0.4 python run_alphafold.py --json_path=/root/af_input/fold_input.json --model_dir=/root/models --output_dir=/root/af_output"
LABEL org.australian-protein-design-initiative.image.platforms="linux/amd64"

ENV DEBIAN_FRONTEND=noninteractive \
    LANG=C.UTF-8 \
    LC_ALL=C.UTF-8 \
    PYTHONUNBUFFERED=1 \
    UV_COMPILE_BYTECODE=1 \
    UV_PROJECT_ENVIRONMENT=/alphafold3_venv \
    PATH="/hmmer/bin:/alphafold3_venv/bin:${PATH}" \
    XLA_FLAGS="--xla_gpu_enable_triton_gemm=false" \
    XLA_PYTHON_CLIENT_PREALLOCATE=true \
    XLA_CLIENT_MEM_FRACTION=0.95

# * git is required for pyproject.toml toolchain's use of CMakeLists.txt.
# * gcc, g++, make, patch are required for compiling HMMER and AlphaFold 3 libraries.
# * zlib is a required dependency of AlphaFold 3.
RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt,sharing=locked \
    apt-get update --quiet \
    && apt-get install --yes --quiet --no-install-recommends \
        ca-certificates \
        python3.12 \
        python3.12-dev \
        git \
        wget \
        gcc \
        g++ \
        make \
        patch \
        zlib1g-dev \
        zstd \
    && rm -rf /var/lib/apt/lists/*

# Install uv from the official repository. The version is pinned for
# reproducibility (matches upstream docker/Dockerfile at v3.0.4).
COPY --from=ghcr.io/astral-sh/uv:0.9.24 /uv /uvx /bin/

RUN uv venv "${UV_PROJECT_ENVIRONMENT}"

# Install HMMER from source so we can pin the version and apply the sequence
# limit patch. eddylab.org does not support HTTPS; the GitHub tarball is not
# recommended for building from source.
RUN mkdir /hmmer_build /hmmer \
    && wget http://eddylab.org/software/hmmer/hmmer-3.4.tar.gz --directory-prefix /hmmer_build \
    && (cd /hmmer_build && echo "ca70d94fd0cf271bd7063423aabb116d42de533117343a9b27a65c17ff06fbf3 hmmer-3.4.tar.gz" | sha256sum --check) \
    && (cd /hmmer_build && tar zxf hmmer-3.4.tar.gz && rm hmmer-3.4.tar.gz)

COPY jackhmmer_seq_limit.patch /hmmer_build/

RUN (cd /hmmer_build && patch -p0 < jackhmmer_seq_limit.patch) \
    && (cd /hmmer_build/hmmer-3.4 && ./configure --prefix /hmmer) \
    && (cd /hmmer_build/hmmer-3.4 && make -j) \
    && (cd /hmmer_build/hmmer-3.4 && make install) \
    && (cd /hmmer_build/hmmer-3.4/easel && make install) \
    && rm -R /hmmer_build

WORKDIR /app/alphafold

RUN git clone "${GIT_REPO}" . \
    && git checkout "${GIT_REF}" \
    && git config --global --add safe.directory /app/alphafold

# Install the exact dependency tree using uv and cache the build artifacts.
# --frozen: do not update the lockfile during build.
# --all-groups: install development/test dependencies defined in pyproject.toml.
# --no-editable: install as a static package.
# GCS path support: --build-arg UV_EXTRAS="--extra gcsfs"
ARG UV_EXTRAS=""
RUN --mount=type=cache,target=/root/.cache/uv \
    UV_LINK_MODE=copy uv sync --frozen --all-groups --no-editable ${UV_EXTRAS}

# Build chemical components database (this binary was installed by uv sync).
RUN uv run build_data

# AlphaFold 3 model parameters cannot be redistributed. Request them from Google
# and mount at /root/models (see WEIGHTS_TERMS_OF_USE.md in the upstream repo).
RUN if [ "${DOWNLOAD_WEIGHTS}" = "true" ]; then \
        echo "DOWNLOAD_WEIGHTS=true is not supported: AlphaFold 3 parameters must be obtained from Google and mounted at /root/models." >&2; \
        exit 1; \
    fi

RUN cat > /README.md <<'EOF'
# AlphaFold 3

Biomolecular structure prediction with
[AlphaFold 3](https://github.com/google-deepmind/alphafold3) v3.0.4.

## Provenance

- Source: https://github.com/google-deepmind/alphafold3.git @ v3.0.4 (85c4d20, 2026-07-28)
- Base image: nvidia/cuda:12.6.3-base-ubuntu24.04
- Docker recipe adapted from upstream `docker/Dockerfile`

## Weights and databases (not included)

Model parameters are **not** baked into this image. You may only use AlphaFold 3
parameters if received directly from Google. Download them to a host directory
and mount that directory at `/root/models`:

- https://storage.googleapis.com/alphafold3/af3.bin.zst
- Terms: https://github.com/google-deepmind/alphafold3/blob/v3.0.4/WEIGHTS_TERMS_OF_USE.md

Genetic databases (~630 GB uncompressed) are also not included. Fetch them with
upstream `fetch_databases.sh` and mount the directory at `/root/public_databases`.

## Usage

```bash
docker run --gpus all --rm \
  -v "$HOME/af_input:/root/af_input" \
  -v "$HOME/af_output:/root/af_output" \
  -v "<MODEL_PARAMETERS_DIR>:/root/models" \
  -v "<DB_DIR>:/root/public_databases" \
  ghcr.io/australian-protein-design-initiative/containers/alphafold3:3.0.4 \
  python run_alphafold.py \
  --json_path=/root/af_input/fold_input.json \
  --model_dir=/root/models \
  --output_dir=/root/af_output
```

List flags:

```bash
docker run --rm \
  ghcr.io/australian-protein-design-initiative/containers/alphafold3:3.0.4 \
  python run_alphafold.py --help
```

Requires an NVIDIA GPU with CUDA compute capability 8.0+ (A100 / H100 verified).
For CUDA capability 7 GPUs, override `XLA_FLAGS`:

```
--xla_disable_hlo_passes=custom-kernel-fusion-rewriter
```
EOF

CMD ["uv", "run", "python3", "run_alphafold.py"]
