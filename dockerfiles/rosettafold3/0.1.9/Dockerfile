FROM python:3.12

LABEL org.opencontainers.image.source https://github.com/Australian-Protein-Design-Initiative/containers

#ARG GIT_REPO=https://github.com/RosettaCommons/modelforge.git
ARG GIT_REF=0.1.9

ARG DOWNLOAD_MODELS=true

ENV FOUNDRY_CHECKPOINT_DIRS=/models/foundry
ENV DEBIAN_FRONTEND=noninteractive \
    PIP_NO_CACHE_DIR=1 \
    PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1

RUN mkdir -p /models/foundry

RUN pip install "rc-foundry[rf3]==${GIT_REF}"

# RUN git clone https://github.com/RosettaCommons/modelforge.git /apps/rosettafold3 \
#   && cd /apps/rosettafold3 \
#   && pip install -e ".[rf3]"

RUN if [ "$DOWNLOAD_MODELS" = "true" ]; then \
        foundry install rf3 --checkpoint-dir ${FOUNDRY_CHECKPOINT_DIRS}; \
        chmod -R a+rx ${FOUNDRY_CHECKPOINT_DIRS}; \
    fi

RUN groupadd -g 1000 rf3user && \
    useradd -m -u 1000 -g 1000 -s /bin/bash rf3user

USER rf3user

CMD ["rfd3", "--help"]
