# syntax=docker/dockerfile:1.4
# Protenix at upstream commit 85767b8 (v2.0.0-14-g85767b8, 2026-09-21), for arm64 / aarch64 +
# Blackwell (GB10 / GB100) with CUDA 13.3. arm64 counterpart of ../2026-09-21_85767b8_weights.
#
# Differences from the amd64 build, and why:
#
#  - Base is nvidia/cuda:13.3.0-cudnn-devel-ubuntu24.04. GB10 reports compute capability 12.1
#    (sm_121), which CUDA 12.x toolchains cannot JIT for ("nvrtc: error: invalid value for
#    --gpu-architecture"), so CUDA 13.x and a cu130 torch are mandatory here. nvcc is still
#    needed for the Protenix fast layer-norm JIT kernel / DeepSpeed.
#  - torch comes from download.pytorch.org/whl/cu130: the aarch64 CUDA wheels are not on PyPI.
#    Upstream pins torch==2.7.1 (cu126), which has no sm_121 support, so torch, torchvision,
#    torchaudio and triton are taken out of requirements.txt and installed from that index first.
#  - cuequivariance-ops-torch-cu12 is swapped for its cu13 build, to match the CUDA 13 runtime.
#  - micromamba is the linux-aarch64 build.
#
# Build like:
#   just build protenix/2026-09-21_85767b8_nv-cuda13-arm64_weights --pull

ARG GIT_REPO=https://github.com/bytedance/Protenix.git
ARG GIT_REF=85767b811c40ed46e73a9b39519cf6bfca8701ba
ARG DOWNLOAD_WEIGHTS=true

FROM nvidia/cuda:13.3.0-cudnn-devel-ubuntu24.04

ARG GIT_REPO
ARG GIT_REF
ARG DOWNLOAD_WEIGHTS
ARG GEMMI_VERSION
# protenix-v2.pt on the ByteDance CDN returns 403 outside China
# (github.com/bytedance/Protenix/issues/296). If the CDN download fails, this URL is tried.
# Override with --build-arg PROTENIX_V2_WEIGHT_URL=... if the default mirror is unavailable.
ARG PROTENIX_V2_WEIGHT_URL=https://huggingface.co/nickrb/protenij/resolve/main/protenix-v2.pt
ARG PROTENIX_V2_SHA256=8f931f9774a396b67033d0e58628e1834f4a1448165e04254b40a780b0c0d599
# cu130 = compiled against CUDA 13.0, forward-compatible with the 13.3 runtime above
ARG TORCH_VERSION=2.13.0
ARG TORCH_INDEX_URL=https://download.pytorch.org/whl/cu130
# Upstream pins gemmi==0.6.7, which has no aarch64 wheel on PyPI or conda-forge, so pip compiles
# it from C++ source. That is tolerable on a native arm64 host but not under the emulation CI
# builds this image with, where it ran for over 45 minutes without finishing. 0.7.3 is the
# earliest release with a cp311 aarch64 manylinux wheel. Nothing in Protenix imports gemmi; its
# only consumer here is pdbeccdutils, which asks for gemmi>=0.6.6 and so accepts this.
ARG GEMMI_VERSION=0.7.3

LABEL org.opencontainers.image.source=https://github.com/Australian-Protein-Design-Initiative/containers
LABEL org.opencontainers.image.url="${GIT_REPO}"
LABEL org.opencontainers.image.title="Protenix (arm64 / Blackwell)"
LABEL org.opencontainers.image.description="Protenix (bytedance/Protenix @ 85767b8) biomolecular structure prediction"
LABEL org.opencontainers.image.licenses="Apache-2.0"
LABEL org.opencontainers.image.revision="${GIT_REF}"
LABEL org.opencontainers.image.version="2026-09-21_85767b8_nv-cuda13-arm64"
LABEL org.opencontainers.image.base.name="docker.io/nvidia/cuda:13.3.0-cudnn-devel-ubuntu24.04"
LABEL org.australian-protein-design-initiative.image.platforms="linux/arm64"

ARG DEBIAN_FRONTEND=noninteractive
SHELL ["/bin/bash", "-lc"]

RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt,sharing=locked \
    apt-get update && apt-get install -y --no-install-recommends \
      ca-certificates \
      curl \
      wget \
      bzip2 \
      git \
      g++ \
      gcc \
      libc6-dev \
      make \
      postgresql \
      hmmer \
      kalign \
    && rm -rf /var/lib/apt/lists/*

ENV CUDA_HOME=/usr/local/cuda \
    LC_ALL=C.UTF-8 \
    LANG=C.UTF-8 \
    PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PIP_DISABLE_PIP_VERSION_CHECK=1 \
    CUTLASS_PATH=/opt/cutlass \
    PROTENIX_ROOT_DIR=/weights/protenix \
    MAMBA_ROOT_PREFIX=/opt/conda \
    MAMBA_NO_BANNER=1

RUN curl -Ls https://micro.mamba.pm/api/micromamba/linux-aarch64/latest | \
    tar -xj -C /usr/local/bin --strip-components=1 bin/micromamba

# Protenix requires Python>=3.11
RUN --mount=type=cache,target=/opt/conda/pkgs \
    micromamba create -y -n protenix -c conda-forge python=3.11 && \
    micromamba clean -a -y

ENV PATH=/opt/conda/envs/protenix/bin:${PATH}

WORKDIR /app

RUN git clone "${GIT_REPO}" /app && \
    git checkout "${GIT_REF}"

# torch first so packages that import it at build time (deepspeed) can find it
RUN --mount=type=cache,target=/root/.cache/pip \
    set -euxo pipefail; \
    pip install --upgrade pip wheel setuptools; \
    pip install --index-url "${TORCH_INDEX_URL}" "torch==${TORCH_VERSION}" torchvision torchaudio; \
    grep -vE '^(torch|torchvision|torchaudio|triton)==' requirements.txt \
      | sed 's/^cuequivariance-ops-torch-cu12/cuequivariance-ops-torch-cu13/' \
      | sed "s/^gemmi==.*/gemmi==${GEMMI_VERSION}/" > /tmp/requirements-arm64.txt; \
    grep -q "^gemmi==${GEMMI_VERSION}\$" /tmp/requirements-arm64.txt; \
    pip install --only-binary=gemmi "gemmi==${GEMMI_VERSION}"; \
    pip install -r /tmp/requirements-arm64.txt; \
    pip install --no-deps .; \
    protenix --help >/dev/null

RUN git clone --depth 1 -b v3.5.1 https://github.com/NVIDIA/cutlass.git /opt/cutlass

# Protenix expects checkpoints under ${PROTENIX_ROOT_DIR}/checkpoint and data caches under
# ${PROTENIX_ROOT_DIR}/common (configs/configs_inference.py, configs/configs_data.py).
# URLs come from protenix.web_service.dependency_url; downloads keep the CDN path layout
# (checkpoint/*, common/*), use a build cache mount, then are copied into the image layer.
RUN --mount=type=cache,target=/root/.cache/protenix \
    set -euxo pipefail; \
    mkdir -p "${PROTENIX_ROOT_DIR}"; \
    if [ "${DOWNLOAD_WEIGHTS}" = "true" ]; then \
      python -c 'from protenix.web_service.dependency_url import URL; [print(u) for u in URL.values()]' | \
      while read -r url; do \
        relpath="${url#*://}"; relpath="${relpath#*/}"; \
        cache="/root/.cache/protenix/${relpath}"; \
        dest="${PROTENIX_ROOT_DIR}/${relpath}"; \
        mkdir -p "$(dirname "${cache}")" "$(dirname "${dest}")"; \
        if [ ! -s "${cache}" ]; then \
          if ! wget -q -O "${cache}" "${url}"; then \
            if [ "$(basename "${url}")" = "protenix-v2.pt" ] && wget -q -O "${cache}" "${PROTENIX_V2_WEIGHT_URL}"; then \
              :; \
            else \
              rm -f "${cache}"; echo "Failed to download ${url}" >&2; exit 8; \
            fi; \
          fi; \
        fi; \
        if [ "$(basename "${url}")" = "protenix-v2.pt" ]; then \
          echo "${PROTENIX_V2_SHA256}  ${cache}" | sha256sum -c - || { rm -f "${cache}"; exit 9; }; \
        fi; \
        cp "${cache}" "${dest}"; \
      done; \
      chmod -R a+rX /weights; \
    else \
      echo "Skipping Protenix weight download (DOWNLOAD_WEIGHTS=${DOWNLOAD_WEIGHTS})"; \
      chmod a+rwx "${PROTENIX_ROOT_DIR}"; \
    fi; \
    ln -sfn /weights /models

RUN cat > /README.md <<'EOF'
# Protenix

[Protenix](https://github.com/bytedance/Protenix) - a trainable PyTorch reproduction of AlphaFold 3
(protein, nucleic acid and ligand structure prediction).

## Provenance

- Source: https://github.com/bytedance/Protenix.git @ 85767b811c40ed46e73a9b39519cf6bfca8701ba
  (v2.0.0-14-g85767b8, 2026-09-21)
- Installed into `/app` (micromamba env `protenix`, Python 3.11, torch 2.13.0+cu130, arm64)
- CUTLASS v3.5.1 at `/opt/cutlass` (`CUTLASS_PATH`)

## Weights

`PROTENIX_ROOT_DIR=/weights/protenix` (`/models` is a symlink to `/weights`).

- `_weights` images: all checkpoints listed in `protenix.web_service.dependency_url`
  are baked in under `/weights/protenix/checkpoint` (protenix-v2, v1.0.0 base models,
  v0.5.0 models, ESM2-3B / ISM), plus data caches under `/weights/protenix/common`
  (CCD components, PDB clusters, release-date caches).
- `_no-weights` images: Protenix downloads missing files to `$PROTENIX_ROOT_DIR` on first use.
  Under Apptainer, bind a writable directory there, or point `PROTENIX_ROOT_DIR` elsewhere:

  ```bash
  apptainer exec --nv -B /path/to/protenix_data:/weights/protenix protenix.sif protenix pred ...
  ```

## Usage

```bash
docker run --gpus all -it --rm -v "$(pwd)":/work -w /work \
  ghcr.io/australian-protein-design-initiative/containers/protenix:2026-09-21_85767b8_nv-cuda13-arm64_weights \
  protenix pred -i /app/examples/example.json -o ./output -n protenix-v2
```

Run `protenix --help` / `protenix pred --help` for options. Example inputs are in `/app/examples`.
EOF

# The fused layer-norm extension is JIT-built for sm_70 to sm_100 only, so on GB10 (sm_121) it
# fails at the first call with "no kernel image is available". Add sm_120 and sm_121 to its
# architecture list and rebuild it (nvcc is enough, no GPU is needed at build time).
RUN set -euxo pipefail; \
    LN=/opt/conda/envs/protenix/lib/python3.11/site-packages/protenix/model/layer_norm; \
    sed -i 's/^\(\s*\)("100", "100"),/&\n\1("120", "120"),\n\1("121", "121"),/' "${LN}/torch_ext_compile.py"; \
    grep -q '("121", "121")' "${LN}/torch_ext_compile.py"; \
    rm -f "${LN}/fast_layer_norm_cuda_v2.so"; \
    cd /; python -c "import protenix.model.layer_norm.layer_norm"; \
    test -f "${LN}/fast_layer_norm_cuda_v2.so"

CMD ["protenix", "--help"]
