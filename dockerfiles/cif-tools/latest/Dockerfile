FROM debian:bookworm-slim

LABEL org.opencontainers.image.source=https://github.com/Australian-Protein-Design-Initiative/containers
LABEL org.australian-protein-design-initiative.image.platforms="linux/amd64"

RUN apt-get update && \
    apt-get install -y cif-tools && \
    rm -rf /var/lib/apt/lists/*

CMD ["pdb2cif"]