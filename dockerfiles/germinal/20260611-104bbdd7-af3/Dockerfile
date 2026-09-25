# syntax=docker/dockerfile:1.4
# GPU devel base with CUDA 12.4 + cuDNN on Ubuntu 22.04 (nvcc for Protenix/DeepSpeed)
FROM nvidia/cuda:12.4.1-cudnn-devel-ubuntu22.04

LABEL org.opencontainers.image.source=https://github.com/Australian-Protein-Design-Initiative/containers

ARG GIT_REPO=https://github.com/pansapiens/germinal.git
# fix/protenix-pae-matrix-output
ARG GIT_REF=104bbdd7
ARG DOWNLOAD_WEIGHTS=true
ENV CHAI_DOWNLOADS_DIR=/workspace/params

ARG DEBIAN_FRONTEND=noninteractive
SHELL ["/bin/bash", "-lc"]

RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates curl wget git bzip2 aria2 ffmpeg procps tini \
  && rm -rf /var/lib/apt/lists/*

ENV CUDA_HOME=/usr/local/cuda
ENV LC_ALL=C.UTF-8 LANG=C.UTF-8

ENV MAMBA_ROOT_PREFIX=/opt/conda
ENV MAMBA_NO_BANNER=1
RUN curl -Ls https://micro.mamba.pm/api/micromamba/linux-64/latest | \
    tar -xvj -C /usr/local/bin --strip-components=1 bin/micromamba

# base root prefix: install conda CLI at /opt/conda/bin/conda (e.g. conda run -n protenix)
RUN --mount=type=cache,target=/opt/conda/pkgs \
  micromamba install -y -r "${MAMBA_ROOT_PREFIX}" -c conda-forge conda && \
  micromamba clean -a -y

# create conda env
ENV CONDA_ENV=germinal
RUN micromamba create -y -n ${CONDA_ENV} python=3.10 && micromamba clean -a -y

ENV PATH=/opt/conda/envs/germinal/bin:/opt/conda/bin:${PATH}
ENV PYTHONUNBUFFERED=1 MPLBACKEND=Agg HYDRA_FULL_ERROR=1 PIP_NO_CACHE_DIR=1

WORKDIR /workspace

RUN git clone ${GIT_REPO} . && git checkout ${GIT_REF} \
  && python -m compileall -q /workspace/germinal

ARG TORCH_VERSION=2.6.0
ARG TORCHVISION_VERSION=0.21.0
ARG TORCHAUDIO_VERSION=2.6.0
ARG CUDA_SUFFIX=cu124                    # use 'cpu' for CPU-only builds
ARG JAX_CUDA=true                        # 'false' for CPU-only JAX
ARG TORCH_INDEX_URL=https://download.pytorch.org/whl/${CUDA_SUFFIX}

# install pip/uv packages (cache pip/uv directories between builds)
RUN --mount=type=cache,target=/root/.cache/pip \
  --mount=type=cache,target=/root/.cache/uv \
  set -euxo pipefail; \
  python -m pip install --upgrade pip wheel setuptools; \
  python -m pip install uv; \
  uv pip install --system pandas matplotlib numpy biopython scipy seaborn tqdm ffmpeg py3dmol \
    chex dm-haiku dm-tree joblib ml-collections immutabledict optax cvxopt mdtraj colabfold ipsae==1.0.1; \
  uv pip install --system -e /workspace/colabdesign; \
  uv pip install --system --index-url "${TORCH_INDEX_URL}" \
    "torch==${TORCH_VERSION}" \
    "torchvision==${TORCHVISION_VERSION}" \
    "torchaudio==${TORCHAUDIO_VERSION}"; \
  uv pip install --system torchtyping==0.1.5; \
  if [ "${CUDA_SUFFIX}" = "cpu" ]; then \
    PYG_URL="https://data.pyg.org/whl/torch-${TORCH_VERSION}+cpu.html"; \
  else \
    PYG_URL="https://data.pyg.org/whl/torch-${TORCH_VERSION}%2B${CUDA_SUFFIX}.html"; \
  fi; \
  uv pip install --system "torch_geometric==2.6.*" -f "${PYG_URL}"; \
  uv pip install --system iglm chai-lab==0.6.1; \
  true

# pin jax version to 0.5.3 (reuse uv cache between builds)
RUN --mount=type=cache,target=/root/.cache/pip \
  --mount=type=cache,target=/root/.cache/uv \
  set -euxo pipefail; \
  uv pip install --system jax==0.5.3; \
  uv pip install --system dm-haiku==0.0.13; \
  uv pip install --system hydra-core omegaconf; \
  if [ "${JAX_CUDA}" = "true" ]; then \
    uv pip install --system "jax[cuda12_pip]==0.5.3" -f https://storage.googleapis.com/jax-releases/jax_cuda_releases.html; \
  fi; \
  uv pip install ablang2==0.2.1 --system --no-deps; \
  uv pip install rotary_embedding_torch==0.8.9 --system --no-deps; \
  true

# pre-cache AbLang weights into site-packages (VHH: ablang1-heavy, scFv: ablang2-paired)
RUN --mount=type=cache,target=/root/.cache/ablang2 \
  set -euxo pipefail; \
  if [ "${DOWNLOAD_WEIGHTS}" = "true" ]; then \
    ABLANG2_DIR="$(python -c 'import ablang2, os; print(os.path.dirname(ablang2.__file__))')"; \
    download_ablang_weights() { \
      local model="$1" url="$2" expected="$3"; \
      local dest="${ABLANG2_DIR}/model-weights-${model}"; \
      mkdir -p "${dest}"; \
      if [ -f "${dest}/${expected}" ]; then return 0; fi; \
      mkdir -p /root/.cache/ablang2; \
      tmp="${dest}/tmp.tar.gz"; \
      if [ -f "/root/.cache/ablang2/${model}.tar.gz" ]; then \
        cp "/root/.cache/ablang2/${model}.tar.gz" "${tmp}"; \
      else \
        wget -q -O "${tmp}" "${url}"; \
        cp "${tmp}" "/root/.cache/ablang2/${model}.tar.gz"; \
      fi; \
      tar -zxf "${tmp}" -C "${dest}"; \
      rm -f "${tmp}"; \
    }; \
    download_ablang_weights ablang1-heavy \
      https://opig.stats.ox.ac.uk/data/downloads/ablang-heavy.tar.gz amodel.pt; \
    download_ablang_weights ablang2-paired \
      https://zenodo.org/records/10185169/files/ablang2-weights.tar.gz model.pt; \
    chmod -R a+rX "${ABLANG2_DIR}"/model-weights-*; \
  fi

# download pyrosetta (cache installer wheels between builds)
RUN --mount=type=cache,target=/root/.cache/pip \
  --mount=type=cache,target=/root/.cache/uv \
  set -euxo pipefail; \
  uv pip install --system pyrosetta-installer; \
  python -c "import pyrosetta_installer; pyrosetta_installer.install_pyrosetta()"; \
  true

RUN --mount=type=cache,target=/root/.cache/pip \
  --mount=type=cache,target=/root/.cache/uv \
  uv pip install --system -e .

# download multimer parameters (cache params tar/contents between builds)
RUN set -euxo pipefail; \
  if [ "${DOWNLOAD_WEIGHTS}" = "true" ]; then \
    mkdir -p /workspace/params; \
    cd /workspace/params; \
    aria2c -q -x 16 https://storage.googleapis.com/alphafold/alphafold_params_2022-12-06.tar; \
    tar -xf alphafold_params_2022-12-06.tar -C /workspace/params; \
    rm -f alphafold_params_2022-12-06.tar; \
    chmod -R a+rX /workspace/params; \
  fi;

# get chai-1 weights
# RUN set -euxo pipefail; \
#   if [ "${DOWNLOAD_WEIGHTS}" = "true" ]; then \
#     mkdir -p ${CHAI_DOWNLOADS_DIR}/esm; \
#     mkdir -p ${CHAI_DOWNLOADS_DIR}/models_v2; \
#     aria2c -q -x 16 "https://chaiassets.com/chai1-inference-depencencies/esm2/traced_sdpa_esm2_t36_3B_UR50D_fp16.pt" -o ${CHAI_DOWNLOADS_DIR}/esm/traced_sdpa_esm2_t36_3B_UR50D_fp16.pt; \
#     aria2c -q -x 16 "https://chaiassets.com/chai1-inference-depencencies/conformers_v1.apkl" -o ${CHAI_DOWNLOADS_DIR}/conformers_v1.apkl; \
#     aria2c -q -x 16 "https://chaiassets.com/chai1-inference-depencencies/models_v2/feature_embedding.pt" -o ${CHAI_DOWNLOADS_DIR}/models_v2/feature_embedding.pt; \
#     aria2c -q -x 16 "https://chaiassets.com/chai1-inference-depencencies/models_v2/token_embedder.pt" -o ${CHAI_DOWNLOADS_DIR}/models_v2/token_embedder.pt; \
#     aria2c -q -x 16 "https://chaiassets.com/chai1-inference-depencencies/models_v2/trunk.pt" -o ${CHAI_DOWNLOADS_DIR}/models_v2/trunk.pt; \
#     aria2c -q -x 16 "https://chaiassets.com/chai1-inference-depencencies/models_v2/diffusion_module.pt" -o ${CHAI_DOWNLOADS_DIR}/models_v2/diffusion_module.pt; \
#     aria2c -q -x 16 "https://chaiassets.com/chai1-inference-depencencies/models_v2/confidence_head.pt" -o ${CHAI_DOWNLOADS_DIR}/models_v2/confidence_head.pt; \
#     chmod -R a+rX ${CHAI_DOWNLOADS_DIR}; \
#   fi

# get chai-1 weights
RUN python -c "\
import torch; \
from chai_lab.utils.paths import chai1_component, downloads_path; \
from chai_lab.data.dataset.embeddings.esm import esm_model; \
import chai_lab.utils.paths as paths; \
from transformers import EsmTokenizer, EsmModel; \
components = ['feature_embedding', 'token_embedder', 'trunk', 'diffusion_module', 'confidence_head']; \
[chai1_component(component + '.pt') for component in components]; \
paths.cached_conformers.get_path(); \
esm_model(device=torch.device('cpu')); \
"

# protenix environment and package (reuse conda package cache between builds)
# Germinal 018c75f calls `protenix pred` with -i/-o/-n/-e/-c/-p (CLI unified in >=1.0; `pred` alias in >=1.0).
# protenix_model_name protenix-v2 requires protenix>=2.0 (see dependency_url.URL).
# protenix>=0.6 requires Python>=3.11 (germinal env stays on 3.10).
ARG PROTENIX_VERSION=2.0.0
RUN --mount=type=cache,target=/opt/conda/pkgs \
  --mount=type=cache,target=/root/.cache/pip \
  set -euxo pipefail; \
  micromamba create -y -n protenix python=3.11; \
  micromamba run -n protenix pip install "protenix==${PROTENIX_VERSION}"; \
  micromamba clean -a -y; \
  conda run -n protenix protenix pred --help >/dev/null; \
  true

RUN mkdir -p /workspace/pdbs /workspace/results

# runtime PATH: germinal python first, then conda CLI, then protenix env
ENV PATH=/opt/conda/envs/germinal/bin:/opt/conda/bin:/opt/conda/envs/protenix/bin:${PATH}

RUN python validate_install.py

# Protenix v2 expects checkpoints under ${PROTENIX_ROOT_DIR}/checkpoint and data caches under
# ${PROTENIX_ROOT_DIR}/common (see configs_inference.py / configs_data.py). The runtime image is
# read-only (Apptainer) so weights must be baked in; nothing is downloaded at runtime.
# All models from protenix.web_service.dependency_url are fetched (checkpoint/* and common/*,
# including the esm2_t36_3B weights needed by the mini_esm / mini_ism models). They are stored at
# ${PROTENIX_STORE} and exposed at /models/protenix via symlinks, matching the /models/<tool>
# convention used by the other containers in the pipeline. Downloads use a build cache mount,
# then are copied into the image layer so they persist.
ENV PROTENIX_ROOT_DIR=/models/protenix
ARG PROTENIX_STORE=/opt/protenix
# protenix-v2 on the ByteDance CDN often returns 403 outside China (github.com/bytedance/Protenix/issues/296).
ARG PROTENIX_V2_WEIGHT_URL=https://huggingface.co/TMF001/protenix-v2-weights/resolve/main/protenix-v2.pt
RUN --mount=type=cache,target=/root/.cache/protenix \
  set -euxo pipefail; \
  if [ "${DOWNLOAD_WEIGHTS}" = "true" ]; then \
    micromamba run -n protenix python -c 'from protenix.web_service.dependency_url import URL; [print(u) for u in URL.values()]' | \
    while read -r url; do \
      relpath="${url#*://}"; relpath="${relpath#*/}"; \
      cache="/root/.cache/protenix/${relpath}"; \
      dest="${PROTENIX_STORE}/${relpath}"; \
      mkdir -p "$(dirname "${cache}")" "$(dirname "${dest}")"; \
      if [ ! -f "${cache}" ]; then \
        if ! wget -q -O "${cache}" "${url}"; then \
          if [ "$(basename "${url}")" = "protenix-v2.pt" ]; then \
            wget -q -O "${cache}" "${PROTENIX_V2_WEIGHT_URL}"; \
          else \
            rm -f "${cache}"; exit 8; \
          fi; \
        fi; \
      fi; \
      cp "${cache}" "${dest}"; \
    done; \
    chmod -R a+rX "${PROTENIX_STORE}"; \
    mkdir -p "${PROTENIX_ROOT_DIR}"; \
    ln -sfn "${PROTENIX_STORE}/checkpoint" "${PROTENIX_ROOT_DIR}/checkpoint"; \
    ln -sfn "${PROTENIX_STORE}/common" "${PROTENIX_ROOT_DIR}/common"; \
  fi

# AlphaFold 3 (after Protenix so earlier layers stay cached).
# Weights are not baked in: request them from Google and mount at /root/models.
# Germinal's filters/af3.py always runs:
#   singularity exec ... python /root/alphafold3/run_alphafold.py
# so the repo is exposed at that path and a singularity shim dispatches into
# this venv (germinal's python stays first on PATH).
ARG AF3_GIT_REPO=https://github.com/google-deepmind/alphafold3.git
ARG AF3_GIT_REF=v3.0.4
COPY --from=ghcr.io/astral-sh/uv:0.9.24 /uv /uvx /bin/

RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt,sharing=locked \
    apt-get update --quiet \
    && apt-get install --yes --quiet --no-install-recommends \
        gcc \
        g++ \
        make \
        patch \
        zlib1g-dev \
        zstd \
    && rm -rf /var/lib/apt/lists/*

# Standalone CPython 3.12 (AF3 requires >=3.12; the germinal env stays on 3.10).
# UV_PROJECT_ENVIRONMENT is scoped to these RUNs so later uv use is unaffected.
RUN /bin/uv python install 3.12 \
    && /bin/uv venv --python 3.12 /alphafold3_venv

RUN mkdir /hmmer_build /hmmer \
    && wget http://eddylab.org/software/hmmer/hmmer-3.4.tar.gz --directory-prefix /hmmer_build \
    && (cd /hmmer_build && echo "ca70d94fd0cf271bd7063423aabb116d42de533117343a9b27a65c17ff06fbf3 hmmer-3.4.tar.gz" | sha256sum --check) \
    && (cd /hmmer_build && tar zxf hmmer-3.4.tar.gz && rm hmmer-3.4.tar.gz)

RUN cat > /hmmer_build/jackhmmer_seq_limit.patch <<'EOF'
--- hmmer-3.4/src/jackhmmer.c
+++ hmmer-3.4/src/jackhmmer.c
@@ -73,6 +73,7 @@ static ESL_OPTIONS options[] = {
   { "--noali",      eslARG_NONE,        FALSE, NULL, NULL,      NULL,    NULL,  NULL,            "don't output alignments, so output is smaller",                2 },
   { "--notextw",    eslARG_NONE,         NULL, NULL, NULL,      NULL,    NULL, "--textw",        "unlimit ASCII text output line width",                         2 },
   { "--textw",      eslARG_INT,         "120", NULL, "n>=120",  NULL,    NULL, "--notextw",      "set max width of ASCII text output lines",                     2 },
+  { "--seq_limit",  eslARG_INT,          NULL, NULL, NULL,      NULL,    NULL, "--seq_limit",    "if set, truncate all hits after this value is reached",        2 },
 /* Control of scoring system */
   { "--popen",      eslARG_REAL,       "0.02", NULL, "0<=x<0.5",NULL,    NULL,  NULL,            "gap open probability",                                         3 },
   { "--pextend",    eslARG_REAL,        "0.4", NULL, "0<=x<1",  NULL,    NULL,  NULL,            "gap extend probability",                                       3 },
@@ -298,6 +299,7 @@ output_header(FILE *ofp, ESL_GETOPTS *go
   if (esl_opt_IsUsed(go, "--noali")      && fprintf(ofp, "# show alignments in output:       no\n")                                                   < 0) ESL_EXCEPTION_SYS(eslEWRITE, "write failed");
   if (esl_opt_IsUsed(go, "--notextw")    && fprintf(ofp, "# max ASCII text line length:      unlimited\n")                                            < 0) ESL_EXCEPTION_SYS(eslEWRITE, "write failed");
   if (esl_opt_IsUsed(go, "--textw")      && fprintf(ofp, "# max ASCII text line length:      %d\n",             esl_opt_GetInteger(go, "--textw"))    < 0) ESL_EXCEPTION_SYS(eslEWRITE, "write failed");
+  if (esl_opt_IsUsed(go, "--seq_limit")  && fprintf(ofp, "# set max sequence hits to return: %d\n",             esl_opt_GetInteger(go, "--seq_limit")) < 0) ESL_EXCEPTION_SYS(eslEWRITE, "write failed");
   if (esl_opt_IsUsed(go, "--popen")      && fprintf(ofp, "# gap open probability:            %f\n",             esl_opt_GetReal   (go, "--popen"))    < 0) ESL_EXCEPTION_SYS(eslEWRITE, "write failed");
   if (esl_opt_IsUsed(go, "--pextend")    && fprintf(ofp, "# gap extend probability:          %f\n",             esl_opt_GetReal   (go, "--pextend"))  < 0) ESL_EXCEPTION_SYS(eslEWRITE, "write failed");
   if (esl_opt_IsUsed(go, "--mx")         && fprintf(ofp, "# subst score matrix (built-in):   %s\n",             esl_opt_GetString (go, "--mx"))       < 0) ESL_EXCEPTION_SYS(eslEWRITE, "write failed");
@@ -674,6 +676,13 @@ serial_master(ESL_GETOPTS *go, struct cf
 	  /* Print the results. */
 	  p7_tophits_SortBySortkey(info->th);
 	  p7_tophits_Threshold(info->th, info->pli);
+	  /* Limit the number of hits if specified. */
+	  if (esl_opt_IsOn(go, "--seq_limit"))
+	  {
+	    int seq_limit = esl_opt_GetInteger(go, "--seq_limit");
+	    info->th->N = ESL_MIN(info->th->N, seq_limit);
+	  }
+
 	  p7_tophits_CompareRanking(info->th, kh, &nnew_targets);
 	  p7_tophits_Targets(ofp, info->th, info->pli, textw); if (fprintf(ofp, "\n\n") < 0) ESL_EXCEPTION_SYS(eslEWRITE, "write failed");
 	  p7_tophits_Domains(ofp, info->th, info->pli, textw); if (fprintf(ofp, "\n\n") < 0) ESL_EXCEPTION_SYS(eslEWRITE, "write failed");
EOF

RUN (cd /hmmer_build && patch -p0 < jackhmmer_seq_limit.patch) \
    && (cd /hmmer_build/hmmer-3.4 && ./configure --prefix /hmmer) \
    && (cd /hmmer_build/hmmer-3.4 && make -j) \
    && (cd /hmmer_build/hmmer-3.4 && make install) \
    && (cd /hmmer_build/hmmer-3.4/easel && make install) \
    && rm -R /hmmer_build

RUN git clone "${AF3_GIT_REPO}" /app/alphafold \
    && git -C /app/alphafold checkout "${AF3_GIT_REF}" \
    && git config --global --add safe.directory /app/alphafold

ARG UV_EXTRAS=""
RUN --mount=type=cache,target=/root/.cache/uv \
    UV_COMPILE_BYTECODE=1 \
    UV_PROJECT_ENVIRONMENT=/alphafold3_venv \
    UV_LINK_MODE=copy \
    /bin/uv sync --frozen --all-groups --no-editable --directory /app/alphafold ${UV_EXTRAS}

RUN UV_PROJECT_ENVIRONMENT=/alphafold3_venv /bin/uv run --directory /app/alphafold build_data

# Germinal hardcodes `python /root/alphafold3/run_alphafold.py` and
# `--model_dir=/root/models` / `--db_dir=/root/public_databases`.
RUN ln -sfn /app/alphafold /root/alphafold3 \
    && mkdir -p /root/models /root/public_databases \
    && sed -i \
        -e 's|^af3_repo_path:.*|af3_repo_path: "/app/alphafold"|' \
        -e 's|^af3_sif_path:.*|af3_sif_path: "/usr/local/bin/singularity"|' \
        -e 's|^af3_model_dir:.*|af3_model_dir: "/root/models"|' \
        -e 's|^af3_db_dir:.*|af3_db_dir: "/root/public_databases"|' \
        /workspace/configs/run/*.yaml

# Shim for germinal/filters/af3.py. Honour weight/database binds; keep the
# baked-in repo at /root/alphafold3. Do not export the caller's LD_LIBRARY_PATH
# (that value is for the upstream AF3 image, not this CUDA devel base).
RUN cat > /usr/local/bin/singularity <<'EOF'
#!/bin/bash
set -euo pipefail
if [[ "${1:-}" != "exec" ]]; then
  echo "singularity shim: only 'exec' is supported in this image" >&2
  exit 1
fi
shift
while [[ $# -gt 0 ]]; do
  case "$1" in
    --nv|--contain|--cleanenv|--no-home|--writable) shift ;;
    --env)
      key="${2%%=*}"
      val="${2#*=}"
      if [[ "${key}" != "LD_LIBRARY_PATH" ]]; then
        export "${key}=${val}"
      fi
      shift 2
      ;;
    --bind|-B)
      spec="$2"
      shift 2
      src="${spec%%:*}"
      dest="${spec#*:}"
      dest="${dest%%:*}"
      if [[ "${dest}" == "/root/alphafold3" || "${src}" == "${dest}" ]]; then
        continue
      fi
      if [[ -d "${src}" && ( "${dest}" == "/root/models" || "${dest}" == "/root/public_databases" ) ]]; then
        rm -rf "${dest}"
        ln -sfn "${src}" "${dest}"
      fi
      ;;
    --*) shift ;;
    *) break ;;
  esac
done
# Discard the image path (AF3 is installed in this container).
shift
if [[ "${1:-}" == "python" || "${1:-}" == "python3" ]]; then
  shift
  set -- /alphafold3_venv/bin/python "$@"
fi
export PATH="/hmmer/bin:/alphafold3_venv/bin:${PATH}"
export XLA_FLAGS="${XLA_FLAGS:---xla_gpu_enable_triton_gemm=false}"
export XLA_PYTHON_CLIENT_PREALLOCATE="${XLA_PYTHON_CLIENT_PREALLOCATE:-true}"
export XLA_CLIENT_MEM_FRACTION="${XLA_CLIENT_MEM_FRACTION:-0.95}"
exec "$@"
EOF
# absl app.run exits 1 after printing --help; require the usage text instead.
RUN chmod 755 /usr/local/bin/singularity \
    && /alphafold3_venv/bin/python /root/alphafold3/run_alphafold.py --help > /tmp/af3-help.txt \
    || grep -q -- '--json_path' /tmp/af3-help.txt \
    && test -x /hmmer/bin/jackhmmer \
    && rm -f /tmp/af3-help.txt

ENV PATH="/opt/conda/envs/germinal/bin:/opt/conda/bin:/opt/conda/envs/protenix/bin:/hmmer/bin:${PATH}"
WORKDIR /workspace

CMD ["bash"]
