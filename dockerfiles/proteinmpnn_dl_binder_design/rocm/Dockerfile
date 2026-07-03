ARG DLBINDER_COMMIT=cafa385
ARG PROTEINMPNN_COMMIT=8907e66

FROM quay.io/pawsey/pytorch:2.7.1-rocm6.3.3
LABEL org.opencontainers.image.source https://github.com/Australian-Protein-Design-Initiative/containers

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y \
    git \
    wget \
    && rm -rf /var/lib/apt/lists/*

RUN pip install pyrosetta --find-links https://west.rosettacommons.org/pyrosetta/quarterly/release

RUN pip install \
   "numpy<2" \
   biopython==1.81 \
   ml-collections

WORKDIR /app

RUN git clone https://github.com/nrbennet/dl_binder_design && \
    cd dl_binder_design && \
    git checkout ${DLBINDER_COMMIT}

RUN cd /app/dl_binder_design/mpnn_fr && \
    git clone https://github.com/dauparas/ProteinMPNN.git && \
    cd ProteinMPNN && \
    git checkout ${PROTEINMPNN_COMMIT}

RUN ln -s /usr/bin/python3 /usr/bin/python

RUN python /app/dl_binder_design/include/importtests/proteinmpnn_importtest.py

# Make the weights available under /models/ProteinMPNN
RUN mkdir -p /models/ProteinMPNN && \
    ln -s /app/dl_binder_design/mpnn_fr/ProteinMPNN/vanilla_model_weights /models/ProteinMPNN/vanilla_model_weights && \
    ln -s /app/dl_binder_design/mpnn_fr/ProteinMPNN/soluble_model_weights /models/ProteinMPNN/soluble_model_weights && \
    ln -s /app/dl_binder_design/mpnn_fr/ProteinMPNN/ca_model_weights /models/ProteinMPNN/ca_model_weights

# Download the HyperMPNN weights to /models/HyperMPNN
RUN mkdir -p /models/HyperMPNN && \
    cd /models/HyperMPNN && \
    wget https://github.com/meilerlab/HyperMPNN/raw/refs/heads/main/retrained_models/v48_002_epoch240_hyper.pt && \
    wget https://github.com/meilerlab/HyperMPNN/raw/refs/heads/main/retrained_models/v48_010_epoch300_hyper.pt && \
    wget https://github.com/meilerlab/HyperMPNN/raw/refs/heads/main/retrained_models/v48_020_epoch300_hyper.pt && \
    wget https://github.com/meilerlab/HyperMPNN/raw/refs/heads/main/retrained_models/v48_030_epoch300_hyper.pt

CMD ["python", "/app/dl_binder_design/mpnn_fr/dl_interface_design.py"]