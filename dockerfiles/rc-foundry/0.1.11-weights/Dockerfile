FROM python:3.12

LABEL org.opencontainers.image.source https://github.com/Australian-Protein-Design-Initiative/containers

#ARG GIT_REPO=https://github.com/RosettaCommons/foundry.git
ARG GIT_REF=0.1.11

ARG DOWNLOAD_MODELS=true

ENV FOUNDRY_CHECKPOINT_DIRS=/models/foundry
ENV DEBIAN_FRONTEND=noninteractive \
    PIP_NO_CACHE_DIR=1 \
    PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1

RUN mkdir -p /models/foundry \
    && ln -s /models/foundry /weights

RUN pip install "rc-foundry[all]==${GIT_REF}"

RUN if [ "$DOWNLOAD_MODELS" = "true" ]; then \
        foundry install \
          rfd3 \
          proteinmpnn \
          ligandmpnn \
          solublempnn \
          rf3 \
          --checkpoint-dir ${FOUNDRY_CHECKPOINT_DIRS}; \
        chmod -R a+rx ${FOUNDRY_CHECKPOINT_DIRS}; \
        cd /weights && \
        wget https://files.ipd.uw.edu/pub/ligandmpnn/proteinmpnn_v_48_002.pt && \
        wget https://files.ipd.uw.edu/pub/ligandmpnn/proteinmpnn_v_48_010.pt && \
        wget https://files.ipd.uw.edu/pub/ligandmpnn/proteinmpnn_v_48_030.pt; \
        wget https://files.ipd.uw.edu/pub/ligandmpnn/ligandmpnn_v_32_005_25.pt && \
        wget https://files.ipd.uw.edu/pub/ligandmpnn/ligandmpnn_v_32_020_25.pt && \
        wget https://files.ipd.uw.edu/pub/ligandmpnn/ligandmpnn_v_32_030_25.pt; \
        wget https://files.ipd.uw.edu/pub/ligandmpnn/solublempnn_v_48_002.pt && \
        wget https://files.ipd.uw.edu/pub/ligandmpnn/solublempnn_v_48_010.pt && \
        wget https://files.ipd.uw.edu/pub/ligandmpnn/solublempnn_v_48_030.pt; \
        wget https://github.com/meilerlab/HyperMPNN/raw/refs/heads/main/retrained_models/v48_002_epoch240_hyper.pt && \
        wget https://github.com/meilerlab/HyperMPNN/raw/refs/heads/main/retrained_models/v48_010_epoch300_hyper.pt && \
        wget https://github.com/meilerlab/HyperMPNN/raw/refs/heads/main/retrained_models/v48_020_epoch300_hyper.pt && \
        wget https://github.com/meilerlab/HyperMPNN/raw/refs/heads/main/retrained_models/v48_030_epoch300_hyper.pt; \
    fi

RUN groupadd -g 1000 rosettauser && \
    useradd -m -u 1000 -g 1000 -s /bin/bash rosettauser

USER rosettauser

CMD ["rfd3", "--help"]
