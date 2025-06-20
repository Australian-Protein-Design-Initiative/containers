# To build:
#
# cd dl_binder_design
#
# docker build -f ../Dockerfile.proteinmpnn_fastrelax 
#   -t proteinmpnn_fastrelax:latest . 
#

ARG DLBINDER_COMMIT=cafa385
ARG PROTEINMPNN_COMMIT=8907e66

FROM continuumio/miniconda3:latest
LABEL org.opencontainers.image.source https://github.com/Australian-Protein-Design-Initiative/containers

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y \
    git \
    wget \
    && rm -rf /var/lib/apt/lists/*

RUN conda install -y \
    -c https://conda.rosettacommons.org \
    -c pytorch \
    -c nvidia \
    -c conda-forge \
    -c defaults \
    python=3.11.9 \
    pytorch=2.0.1 \
    pytorch-cuda=11.8 \
    biopython=1.81 \
    ml-collections=1.0.0 \
    pyrosetta=2024.42+release.3366cf78a3 \
    "numpy<2"

WORKDIR /app

RUN git clone https://github.com/nrbennet/dl_binder_design && \
    cd dl_binder_design && \
    git checkout ${DLBINDER_COMMIT}

RUN cd /app/dl_binder_design/mpnn_fr && \
    git clone https://github.com/dauparas/ProteinMPNN.git && \
    cd ProteinMPNN && \
    git checkout ${PROTEINMPNN_COMMIT}

RUN python /app/dl_binder_design/include/importtests/proteinmpnn_importtest.py

CMD ["python", "/app/dl_binder_design/mpnn_fr/dl_interface_design.py"] 