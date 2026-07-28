# Build like:
#   docker buildx build -t engens:2024-11-22_b097882_py311 -f Dockerfile --build-arg GIT_REF=b097882 .
#   # or: just build engens/2024-11-22_b097882_py311
#

ARG GIT_REPO=https://github.com/KavrakiLab/EnGens.git
ARG GIT_REF=b097882
ARG QUARTO_VERSION=1.9.38

FROM mambaorg/micromamba:2.0.2

ARG GIT_REPO
ARG GIT_REF
ARG QUARTO_VERSION

LABEL org.opencontainers.image.source=https://github.com/Australian-Protein-Design-Initiative/containers
LABEL org.opencontainers.image.url="${GIT_REPO}"
LABEL org.opencontainers.image.title="EnGens"
LABEL org.opencontainers.image.description="EnGens (Python 3.11): computational framework for generation and analysis of representative protein conformational ensembles (with Quarto)"
LABEL org.opencontainers.image.licenses="MIT"
LABEL org.opencontainers.image.revision="${GIT_REF}"
LABEL org.opencontainers.image.version="${GIT_REF}"
LABEL org.opencontainers.image.base.name="docker.io/mambaorg/micromamba:2.0.2"
LABEL org.opencontainers.image.base.digest="sha256:8a7b771b3c3c73bf4c8f814ef080afa267aa2f151126e8fe45b59ffde25874ae"
LABEL org.opencontainers.image.usage="docker run -it --rm -p 8888:8888 -v \$(pwd):/home/mambauser/work engens:2024-11-22_b097882_py311"

ENV DEBIAN_FRONTEND=noninteractive \
    MAMBA_DOCKERFILE_ACTIVATE=1 \
    LD_LIBRARY_PATH=/opt/conda/lib

USER root
RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt,sharing=locked \
    apt-get update && apt-get install -y --no-install-recommends \
    git \
    curl \
    ca-certificates \
    procps \
    && rm -rf /var/lib/apt/lists/*

# Install Quarto CLI
RUN curl -fsSL -o /tmp/quarto-${QUARTO_VERSION}-linux-amd64.deb \
    "https://github.com/quarto-dev/quarto-cli/releases/download/v${QUARTO_VERSION}/quarto-${QUARTO_VERSION}-linux-amd64.deb" && \
    dpkg -i /tmp/quarto-${QUARTO_VERSION}-linux-amd64.deb && \
    rm /tmp/quarto-${QUARTO_VERSION}-linux-amd64.deb && \
    quarto --version

USER $MAMBA_USER
WORKDIR /app

# Clone EnGens at the pinned ref
RUN git clone "${GIT_REPO}" . && git checkout "${GIT_REF}"

# Replace upstream Python 3.6 environment.yml with a modern Python 3.11 stack
COPY --chown=$MAMBA_USER:$MAMBA_USER environment.yml /tmp/environment.yml
RUN --mount=type=cache,target=/opt/conda/pkgs,sharing=locked \
    micromamba install -y -n base -f /tmp/environment.yml && \
    micromamba clean --all --yes

RUN python --version

# pytraj has no Python 3.11 wheels; use mdtraj + nglview.show_mdtraj instead
RUN python - <<'PY'
from pathlib import Path

engen = Path("engens_code/engens/core/EnGens.py")
text = engen.read_text()
text = text.replace("import pytraj as pt\n", "")
old = """        pt_traj = pt.load(self.traj_name, self.ref, stride=stride)
        widget = ngl.show_pytraj(pt_traj, gui=True)"""
new = """        md_traj = mdtraj.load(self.traj_name, top=self.ref)
        if stride is not None:
            md_traj = md_traj[::stride]
        widget = ngl.show_mdtraj(md_traj, gui=True)"""
if old not in text:
    raise SystemExit("EnGens.py: expected pytraj block not found")
engen.write_text(text.replace(old, new).replace(
    "widget: NGLWidget object with loaded pytraj",
    "widget: NGLWidget object with loaded mdtraj",
))

plot = Path("engens_code/engens/core/PlotUtils.py")
text = plot.read_text()
text = text.replace("import pytraj as pt\n", "")
old = "view = nv.show_pytraj(pt.load(self.engen.full_traj_name, self.engen.full_ref))"
new = "view = nv.show_mdtraj(mdtraj.load(self.engen.full_traj_name, top=self.engen.full_ref))"
if old not in text:
    raise SystemExit("PlotUtils.py: expected pytraj call not found")
plot.write_text(text.replace(old, new))
print("pytraj -> mdtraj patches applied")
PY

# PyEMMA 2.5 still does mdtraj.version.version; mdtraj >=1.10 only exposes __version__.
RUN python - <<'PY'
from pathlib import Path
import mdtraj
init = Path(mdtraj.__file__)
text = init.read_text()
marker = "# pyemma mdtraj.version compat"
if marker not in text:
    init.write_text(
        text.rstrip()
        + "\n\n"
        + marker
        + "\n"
        + "from types import SimpleNamespace as _SimpleNamespace\n"
        + "version = _SimpleNamespace(version=__version__)  # noqa: F821\n"
    )
    print(f"patched {init}")
else:
    print(f"already patched {init}")
# smoke check
import importlib
importlib.reload(mdtraj)
assert mdtraj.version.version == mdtraj.__version__
print("mdtraj.version.version =", mdtraj.version.version)
PY

# Install engens from the checked-out (and patched) source
RUN --mount=type=cache,target=/home/mambauser/.cache/pip \
    pip install ./engens_code ipymolstar

# Install patched HDE (as in upstream Dockerfile / linux_setup.sh)
# Restrict package exports to HDE — molgen/propagator need obsolete Keras APIs
# that EnGens does not use.
RUN --mount=type=cache,target=/home/mambauser/.cache/pip \
    git clone https://github.com/hsidky/hde.git /tmp/hde && \
    cp hde.patch /tmp/hde/hde.patch && \
    cd /tmp/hde && git apply hde.patch && \
    pip install /tmp/hde && \
    printf '%s\n' 'from .hde import *' 'from . import analysis' \
      > /opt/conda/lib/python3.11/site-packages/hde/__init__.py && \
    rm -rf /tmp/hde

# Install mTM-align from the repo-bundled archive
RUN tar -xvf dependencies/mTM-align.tar.bz2 -C /tmp/ && \
    cp /tmp/mTM-align/src/mTM-align "${CONDA_PREFIX}/bin/mTM-align" && \
    rm -rf /tmp/mTM-align

# Place workflow notebooks in the mambauser home (matches upstream ${HOME})
USER root
RUN cp -a /app/notebooks/. /home/mambauser/ && \
    mkdir -p /home/mambauser/work && \
    chown -R "${MAMBA_USER}:${MAMBA_USER}" /home/mambauser
USER $MAMBA_USER

COPY --chown=$MAMBA_USER:$MAMBA_USER README.container.md /README.md

WORKDIR /home/mambauser
EXPOSE 8888

CMD ["jupyter", "notebook", "--ip=0.0.0.0", "--port=8888", "--no-browser"]
