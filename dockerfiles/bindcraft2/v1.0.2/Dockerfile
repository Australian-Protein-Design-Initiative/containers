# syntax=docker/dockerfile:1
# Build like:
#   just build bindcraft2/v1.0.2
#   just build bindcraft2/v1.0.2 --variant no-weights
#   docker buildx build -t bindcraft2:v1.0.2 -f Dockerfile --build-arg DOWNLOAD_WEIGHTS=true .
#
# Adapted from upstream containers/Dockerfile (v1.0.2), which installs the cuda13 extra
# on plain Ubuntu. The JAX CUDA 13 wheels carry CUDA and cuDNN, so the host only needs
# an NVIDIA driver and the container toolkit.
# https://github.com/PacesaLab/BindCraft2/blob/v1.0.2/containers/Dockerfile
#
# DOWNLOAD_WEIGHTS=true bakes the AlphaFold parameters (~5.3 GB) into the image
# (upstream ALPHAFOLD_PARAMETERS=bake). false leaves them for the first campaign,
# or for a mount via BINDCRAFT_AF2_PARAMS.

ARG GIT_REPO=https://github.com/PacesaLab/BindCraft2.git
ARG GIT_REF=v1.0.2
ARG DOWNLOAD_WEIGHTS=true
ARG BASE_IMAGE=ubuntu:24.04

FROM ${BASE_IMAGE}

ARG GIT_REPO
ARG GIT_REF
ARG BASE_IMAGE

LABEL org.opencontainers.image.source=https://github.com/Australian-Protein-Design-Initiative/containers
LABEL org.opencontainers.image.url="${GIT_REPO}"
LABEL org.opencontainers.image.documentation="https://github.com/PacesaLab/BindCraft2/blob/v1.0.2/docs/installation.md"
LABEL org.opencontainers.image.title="BindCraft2"
LABEL org.opencontainers.image.description="BindCraft2 v1.0.2 protein binder design (JAX CUDA 13 wheels, ProteinMPNN included, optional baked AlphaFold parameters)"
LABEL org.opencontainers.image.licenses="LicenseRef-BindCraft2-Hosting-Restricted"
LABEL org.opencontainers.image.revision="${GIT_REF}"
LABEL org.opencontainers.image.version="1.0.2"
LABEL org.opencontainers.image.vendor="Australian Protein Design Initiative"
LABEL org.opencontainers.image.base.name="docker.io/library/ubuntu:24.04"
LABEL org.opencontainers.image.base.digest="sha256:496754492fb28b4d3049432f2ca787449331e23fb14f0dd3fffea86bf5a93eb4"
LABEL org.opencontainers.image.usage="docker run --gpus all --rm -v \$(pwd):/work -w /work ghcr.io/australian-protein-design-initiative/containers/bindcraft2:v1.0.2 design /work/design.json"
LABEL org.australian-protein-design-initiative.image.platforms="linux/amd64"

ENV DEBIAN_FRONTEND=noninteractive \
    LANG=C.UTF-8 \
    LC_ALL=C.UTF-8 \
    PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1 \
    PIP_BREAK_SYSTEM_PACKAGES=1 \
    NVIDIA_VISIBLE_DEVICES=all \
    NVIDIA_DRIVER_CAPABILITIES=compute,utility \
    XLA_PYTHON_CLIENT_PREALLOCATE=false

# biotraj (via biotite) has no aarch64 wheel, so the compiler stays in the image
# rather than being removed out from under whatever links against it.
RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt,sharing=locked \
    apt-get update && apt-get install -y --no-install-recommends \
      python3 \
      python3-pip \
      python3-dev \
      build-essential \
      ca-certificates \
      git

# Editable install, as in install.sh: settings/ and scaffolds/ live at the repository
# root and are resolved relative to the package, so the source tree has to stay in place.
WORKDIR /opt/bindcraft

RUN git clone --depth 1 --branch "${GIT_REF}" "${GIT_REPO}" .

RUN --mount=type=cache,target=/root/.cache/pip \
    python3 -m pip install -e "/opt/bindcraft[cuda13]"

# JAX CUDA 13 wheels keep libraries under nvidia/*/lib inside site-packages, where
# the dynamic linker does not look. Register them. The NVIDIA container hook injects
# the host driver only when NVIDIA_VISIBLE_DEVICES and NVIDIA_DRIVER_CAPABILITIES
# are set (done above); a CUDA base image would have set those, plain Ubuntu does not.
RUN python3 -c "import nvidia, pathlib; print('\n'.join(sorted(str(path) for root in nvidia.__path__ for path in pathlib.Path(root).glob('*/lib'))))" > /etc/ld.so.conf.d/bindcraft-cuda.conf \
    && ldconfig && ldconfig -p | grep -q libcupti

# Fail the build if the wheels or shipped ProteinMPNN checkpoints do not line up.
# Run from / so the installed package is what is tested, not a checkout on PYTHONPATH via cwd.
WORKDIR /
RUN python3 -c "import jax, bindcraft.proteinmpnn; print('jax', jax.__version__)" \
    && bindcraft --help > /dev/null \
    && python3 -m bindcraft.selfcheck cuda13 --shipped-only

# Package weights live at bindcraft/weights (ProteinMPNN shipped; alphafold/ is the
# bake location). Expose that tree at /weights/bindcraft and /models/bindcraft.
RUN mkdir -p /weights \
    && ln -sfn /opt/bindcraft/bindcraft/weights /weights/bindcraft \
    && ln -sfn /weights /models

ARG DOWNLOAD_WEIGHTS=true
RUN if [ "${DOWNLOAD_WEIGHTS}" = "true" ]; then \
      BINDCRAFT_WEIGHTS="$(python3 -c 'from bindcraft.model_weights import SHIPPED_WEIGHTS; print(SHIPPED_WEIGHTS)')" \
      bindcraft fetch-weights \
      && python3 -m bindcraft.selfcheck cuda13; \
    else \
      echo "DOWNLOAD_WEIGHTS=${DOWNLOAD_WEIGHTS}: AlphaFold parameters left for first campaign or BINDCRAFT_AF2_PARAMS"; \
    fi

RUN cat > /README.md <<EOF
# BindCraft2

Protein binder design (de novo miniproteins, scaffolds, peptides, multistate design).
Source: ${GIT_REPO} @ ${GIT_REF}
Upstream container recipe: ${GIT_REPO%.git}/blob/${GIT_REF}/containers/Dockerfile

The image installs the \`cuda13\` extra. ProteinMPNN checkpoints ship inside the package.
AlphaFold parameters (~5.3 GB, CC-BY-4.0) are baked into
\`/opt/bindcraft/bindcraft/weights/alphafold\` when DOWNLOAD_WEIGHTS=true (the default).
The same directory is linked at \`/weights/bindcraft\` and \`/models/bindcraft\`.

## Run

\`\`\`bash
docker run --gpus all --rm -v "\$PWD:/work" -w /work \\
  ghcr.io/australian-protein-design-initiative/containers/bindcraft2:v1.0.2 \\
  design /work/design.json
\`\`\`

\`bindcraft\` is the entrypoint, so further arguments are subcommands
(\`design\`, \`rank\`, \`filter\`, \`fetch-weights\`, \`--help\`).

A shipped-target example lives in the image:

\`\`\`bash
docker run --gpus all --rm -v "\$PWD:/work" -w /work \\
  ghcr.io/australian-protein-design-initiative/containers/bindcraft2:v1.0.2 \\
  design /opt/bindcraft/examples/pdl1.json --set 'project_folder=/work/results/pdl1'
\`\`\`

## Weights not baked in

Build with \`just build bindcraft2/v1.0.2 --variant no-weights\`, then either let the
first campaign download parameters (needs network) or mount a copy:

\`\`\`bash
docker run --gpus all --rm \\
  -e BINDCRAFT_AF2_PARAMS=/weights/alphafold \\
  -v /path/to/alphafold_params:/weights/alphafold \\
  -v "\$PWD:/work" -w /work \\
  ghcr.io/australian-protein-design-initiative/containers/bindcraft2:v1.0.2_no-weights \\
  design /work/design.json
\`\`\`

\`BINDCRAFT_AF2_PARAMS\` must be a directory containing \`params_*.npz\` (or \`params/params_*.npz\`).

## GPU visibility

The campaign reads \`CUDA_VISIBLE_DEVICES\`. Request the cards (\`--gpus all\`, or
\`--gpus-per-node=N\` / \`--gres=gpu:N\` under Slurm). JAX falls back to CPU with a single
warning if the driver is not injected. Check with:

\`\`\`bash
docker run --gpus all --rm --entrypoint python3 \\
  ghcr.io/australian-protein-design-initiative/containers/bindcraft2:v1.0.2 \\
  -c "import jax; print(jax.devices())"
\`\`\`

One \`CudaDevice\` per card is the expected answer.
EOF

WORKDIR /work
ENTRYPOINT ["bindcraft"]
CMD ["--help"]
