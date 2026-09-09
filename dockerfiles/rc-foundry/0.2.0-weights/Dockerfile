FROM python:3.12

LABEL org.opencontainers.image.source="https://github.com/Australian-Protein-Design-Initiative/containers"

#ARG GIT_REPO=https://github.com/RosettaCommons/foundry.git
ARG GIT_REF=0.2.0

ARG DOWNLOAD_WEIGHTS=true

# Checkpoint registry location. get_default_checkpoint_dirs() reads this
# colon-separated variable and searches those directories BEFORE the built-in
# ~/.foundry/checkpoints default, so /models/foundry takes precedence at runtime
# for every model in REGISTERED_CHECKPOINTS. `foundry install --checkpoint-dir`
# below writes here, and /weights is a symlink to the same directory so the
# direct wget downloads land alongside them.
ENV FOUNDRY_CHECKPOINT_DIRS=/models/foundry
ENV DEBIAN_FRONTEND=noninteractive \
    PIP_NO_CACHE_DIR=1 \
    PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1

RUN mkdir -p /models/foundry \
    && ln -s /models/foundry /weights

RUN pip install "rc-foundry[all]==${GIT_REF}"

# Model weights are fetched in several small RUN steps rather than one large one.
# Each RUN is a separate image layer, so this gives the registry several
# independently-addressable blobs instead of a single multi-GB one: layers can be
# pulled in parallel, and a dropped connection only costs the layer in flight
# rather than the whole download. It also means a change to one weight URL does
# not invalidate the build cache for all the others.

# --- WEIGHTS 1: RFdiffusion3 ---
RUN if [ "${DOWNLOAD_WEIGHTS}" = "true" ]; then \
        touch /tmp/.perm-stamp \
        && foundry install \
          rfd3 \
          --checkpoint-dir ${FOUNDRY_CHECKPOINT_DIRS} \
        && find ${FOUNDRY_CHECKPOINT_DIRS} -newer /tmp/.perm-stamp -exec chmod a+rX {} + \
        && rm -f /tmp/.perm-stamp; \
    fi

# --- WEIGHTS 2: RFdiffusion3-NA (nucleic acid) ---
RUN if [ "${DOWNLOAD_WEIGHTS}" = "true" ]; then \
        touch /tmp/.perm-stamp \
        && foundry install \
          rfd3na \
          --checkpoint-dir ${FOUNDRY_CHECKPOINT_DIRS} \
        && find ${FOUNDRY_CHECKPOINT_DIRS} -newer /tmp/.perm-stamp -exec chmod a+rX {} + \
        && rm -f /tmp/.perm-stamp; \
    fi

# --- WEIGHTS 3: RosettaFold3 ---
RUN if [ "${DOWNLOAD_WEIGHTS}" = "true" ]; then \
        touch /tmp/.perm-stamp \
        && foundry install \
          rf3 \
          --checkpoint-dir ${FOUNDRY_CHECKPOINT_DIRS} \
        && find ${FOUNDRY_CHECKPOINT_DIRS} -newer /tmp/.perm-stamp -exec chmod a+rX {} + \
        && rm -f /tmp/.perm-stamp; \
    fi

# --- WEIGHTS 4: MPNN family via foundry ---
RUN if [ "${DOWNLOAD_WEIGHTS}" = "true" ]; then \
        touch /tmp/.perm-stamp \
        && foundry install \
          proteinmpnn \
          ligandmpnn \
          solublempnn \
          --checkpoint-dir ${FOUNDRY_CHECKPOINT_DIRS} \
        && find ${FOUNDRY_CHECKPOINT_DIRS} -newer /tmp/.perm-stamp -exec chmod a+rX {} + \
        && rm -f /tmp/.perm-stamp; \
    fi

# NOTE: there is deliberately no separate wget for
# https://files.ipd.uw.edu/pub/rfdiffusion3na/rfd3na-1190.ckpt.
# "foundry install rfd3na" (WEIGHTS 2 above) already fetches that exact URL --
# see REGISTERED_CHECKPOINTS["rfd3na"] in
# src/foundry/inference_engines/checkpoint_registry.py at rc-foundry v0.2.0 --
# and stores it as rfd3na_1190.ckpt (underscore), which is the filename
# RegisteredCheckpoint.get_default_path() resolves at runtime. Fetching the URL
# separately would download the same ~2.7 GB a second time under a hyphenated
# name that foundry never looks for.

# --- WEIGHTS 5: ProteinMPNN and LigandMPNN ---
RUN if [ "${DOWNLOAD_WEIGHTS}" = "true" ]; then \
        touch /tmp/.perm-stamp \
        && cd /weights \
        && wget https://files.ipd.uw.edu/pub/ligandmpnn/proteinmpnn_v_48_002.pt \
        && wget https://files.ipd.uw.edu/pub/ligandmpnn/proteinmpnn_v_48_010.pt \
        && wget https://files.ipd.uw.edu/pub/ligandmpnn/proteinmpnn_v_48_030.pt \
        && wget https://files.ipd.uw.edu/pub/ligandmpnn/ligandmpnn_v_32_005_25.pt \
        && wget https://files.ipd.uw.edu/pub/ligandmpnn/ligandmpnn_v_32_020_25.pt \
        && wget https://files.ipd.uw.edu/pub/ligandmpnn/ligandmpnn_v_32_030_25.pt \
        && find ${FOUNDRY_CHECKPOINT_DIRS} -newer /tmp/.perm-stamp -exec chmod a+rX {} + \
        && rm -f /tmp/.perm-stamp; \
    fi

# --- WEIGHTS 6: SolubleMPNN ---
RUN if [ "${DOWNLOAD_WEIGHTS}" = "true" ]; then \
        touch /tmp/.perm-stamp \
        && cd /weights \
        && wget https://files.ipd.uw.edu/pub/ligandmpnn/solublempnn_v_48_002.pt \
        && wget https://files.ipd.uw.edu/pub/ligandmpnn/solublempnn_v_48_010.pt \
        && wget https://files.ipd.uw.edu/pub/ligandmpnn/solublempnn_v_48_030.pt \
        && find ${FOUNDRY_CHECKPOINT_DIRS} -newer /tmp/.perm-stamp -exec chmod a+rX {} + \
        && rm -f /tmp/.perm-stamp; \
    fi

# --- WEIGHTS 7: HyperMPNN ---
RUN if [ "${DOWNLOAD_WEIGHTS}" = "true" ]; then \
        touch /tmp/.perm-stamp \
        && cd /weights \
        && wget https://github.com/meilerlab/HyperMPNN/raw/refs/heads/main/retrained_models/v48_002_epoch240_hyper.pt \
        && wget https://github.com/meilerlab/HyperMPNN/raw/refs/heads/main/retrained_models/v48_010_epoch300_hyper.pt \
        && wget https://github.com/meilerlab/HyperMPNN/raw/refs/heads/main/retrained_models/v48_020_epoch300_hyper.pt \
        && wget https://github.com/meilerlab/HyperMPNN/raw/refs/heads/main/retrained_models/v48_030_epoch300_hyper.pt \
        && find ${FOUNDRY_CHECKPOINT_DIRS} -newer /tmp/.perm-stamp -exec chmod a+rX {} + \
        && rm -f /tmp/.perm-stamp; \
    fi

# --- WEIGHTS 8: PottsMPNN ---
RUN if [ "${DOWNLOAD_WEIGHTS}" = "true" ]; then \
        touch /tmp/.perm-stamp \
        && cd /weights \
        && wget https://github.com/KeatingLab/PottsMPNN/raw/refs/heads/main/proteinmpnn_compatible_model_weights/pottsmpnn_20.pt \
        && wget https://github.com/KeatingLab/PottsMPNN/raw/refs/heads/main/proteinmpnn_compatible_model_weights/pottsmpnn_30.pt \
        && wget https://github.com/KeatingLab/PottsMPNN/raw/refs/heads/main/proteinmpnn_compatible_model_weights/pottsmpnn_msa_20.pt \
        && wget https://github.com/KeatingLab/PottsMPNN/raw/refs/heads/main/proteinmpnn_compatible_model_weights/sol_pottsmpnn_20.pt \
        && wget https://github.com/KeatingLab/PottsMPNN/raw/refs/heads/main/proteinmpnn_compatible_model_weights/sol_pottsmpnn_30.pt \
        && wget https://github.com/KeatingLab/PottsMPNN/raw/refs/heads/main/proteinmpnn_compatible_model_weights/sol_pottsmpnn_msa_20.pt \
        && find ${FOUNDRY_CHECKPOINT_DIRS} -newer /tmp/.perm-stamp -exec chmod a+rX {} + \
        && rm -f /tmp/.perm-stamp; \
    fi

# --- WEIGHTS 9: verify permissions (read-only, so it costs no layer space) ---
# This used to be `chmod -R a+rx ${FOUNDRY_CHECKPOINT_DIRS}`, which cost 8.10 GB --
# a byte-for-byte second copy of every checkpoint above, and the only layer in the
# image over 5 GB. overlayfs copies a file up on ANY setattr, so a recursive chmod
# in its own RUN re-materialises every file it touches into that layer, even when
# the mode does not change (measured: a no-op `chmod -R a+rX` still produced a full
# layer). It also defeated the whole point of splitting the downloads above, since
# a dropped connection then cost 8 GB rather than the layer in flight.
#
# Each weights step now runs `find -newer <stamp> -exec chmod a+rX` on just the
# files it created, which is free: the copy-up lands in the layer that already
# holds those bytes. What remains here is a check, not a fix -- `find` only reads,
# so this layer is 0 B, and the build fails loudly if anything is unreadable.
#
# a+rX, not a+rx: X sets the execute bit on directories only, never on a .pt or
# .ckpt weight file, which has no business being executable.
RUN if [ "${DOWNLOAD_WEIGHTS}" = "true" ]; then \
        bad="$(find ${FOUNDRY_CHECKPOINT_DIRS} \
                 \( -type f ! -perm -o=r \) -o \( -type d ! -perm -o=x \) | head -n 20)"; \
        [ -z "$bad" ] || { echo "ERROR: not world-readable under ${FOUNDRY_CHECKPOINT_DIRS}:"; \
                           echo "$bad"; exit 1; }; \
    fi

# --- WEIGHTS 10: verify the checkpoint registry resolves under /models/foundry ---
# Asserts through foundry's own lookup (not just `test -f`) that FOUNDRY_CHECKPOINT_DIRS
# is honoured, that it takes precedence over ~/.foundry/checkpoints, and that every
# model installed above is actually findable at runtime. Fails the build otherwise.
RUN if [ "${DOWNLOAD_WEIGHTS}" = "true" ]; then \
        test "$(readlink -f /weights)" = "/models/foundry" \
          || { echo "ERROR: /weights does not resolve to /models/foundry"; exit 1; }; \
        python -c "from foundry.inference_engines.checkpoint_registry import REGISTERED_CHECKPOINTS as R, get_default_checkpoint_dirs as D; \
dirs=[str(p) for p in D()]; \
names=('rfd3','rfd3na','rf3','proteinmpnn','ligandmpnn','solublempnn'); \
missing=[n for n in names if not R[n].get_default_path().exists()]; \
print('checkpoint search dirs:', dirs); \
assert dirs[0]=='${FOUNDRY_CHECKPOINT_DIRS}', 'FOUNDRY_CHECKPOINT_DIRS not first: %s' % dirs; \
assert not missing, 'unresolved checkpoints: %s' % missing; \
print('OK: all checkpoints resolve under ${FOUNDRY_CHECKPOINT_DIRS}')"; \
    fi

RUN groupadd -g 1000 rosettauser && \
    useradd -m -u 1000 -g 1000 -s /bin/bash rosettauser

USER rosettauser

CMD ["rfd3", "--help"]
