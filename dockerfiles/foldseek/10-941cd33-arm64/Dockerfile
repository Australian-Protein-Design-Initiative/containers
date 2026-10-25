# syntax=docker/dockerfile:1.4
# Build like:
#   just build foldseek/10-941cd33-arm64 --pull
#
# FoldSeek 10-941cd33 for arm64 / aarch64 (eg DGX Spark GB10).
#
# nf-binder-design runs FOLDSEEK_DOWNLOAD_DB, FOLDSEEK_LOCAL_SEARCH, FOLDSEEK_REMOTE_SEARCH and
# FOLDSEEK_DOWNLOAD_CATH_NAMES from quay.io/biocontainers/foldseek:10.941cd33--h5021889_1, which
# is amd64 only and fails with `exec format error` on an arm64 host. This image is the arm64
# stand-in at the same upstream version.
#
# Upstream publishes a prebuilt static arm64 binary for this release, so FoldSeek itself is not
# compiled here. Note that it is the generic arm64 build: the avx2 and gpu tarballs are x86_64
# only, so there is no GPU-accelerated FoldSeek on this platform. The searches nf-binder-design
# runs are CPU ones, so that costs speed rather than function.
#
# The rest of the packages are what the pipeline's FoldSeek process scripts call directly, rather
# than a general-purpose toolbox: wget (cath-names download), curl and jq (the search.foldseek.com
# REST API in FOLDSEEK_REMOTE_SEARCH), GNU grep for `grep -oP` on that API's JSON, bash for the
# `[[ =~ ]]` tests in FOLDSEEK_LOCAL_SEARCH, and aria2 plus rsync, which `foldseek databases` uses
# to fetch a database when they are present.

ARG FOLDSEEK_VERSION=10-941cd33
ARG BASE_IMAGE=debian:trixie-slim

FROM ${BASE_IMAGE}

ARG FOLDSEEK_VERSION

LABEL org.opencontainers.image.source=https://github.com/Australian-Protein-Design-Initiative/containers
LABEL org.opencontainers.image.url="https://github.com/steineggerlab/foldseek"
LABEL org.opencontainers.image.documentation="https://github.com/steineggerlab/foldseek#readme"
LABEL org.opencontainers.image.title="FoldSeek (arm64)"
LABEL org.opencontainers.image.description="FoldSeek 10-941cd33 structural search for arm64 / aarch64, the arm64 stand-in for quay.io/biocontainers/foldseek:10.941cd33--h5021889_1"
LABEL org.opencontainers.image.licenses="GPL-3.0"
LABEL org.opencontainers.image.version="${FOLDSEEK_VERSION}"
LABEL org.opencontainers.image.revision="${FOLDSEEK_VERSION}"
LABEL org.opencontainers.image.base.name="docker.io/library/debian:trixie-slim"
LABEL org.opencontainers.image.usage="docker run --rm -v \$(pwd):/data -w /data foldseek:10-941cd33-arm64 foldseek easy-search query.pdb db res.tsv tmp"
LABEL org.australian-protein-design-initiative.image.platforms="linux/arm64"

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y --no-install-recommends \
    bash \
    ca-certificates \
    curl \
    wget \
    jq \
    grep \
    gzip \
    tar \
    procps \
    aria2 \
    rsync \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# The release tarball unpacks to foldseek/{bin,...}; only the binary is kept.
RUN ARCH=$(dpkg --print-architecture) && \
    if [ "${ARCH}" != "arm64" ]; then echo "This Dockerfile is the arm64 build; got ${ARCH}" >&2; exit 1; fi && \
    curl -fsSL -o /tmp/foldseek.tar.gz \
        "https://github.com/steineggerlab/foldseek/releases/download/${FOLDSEEK_VERSION}/foldseek-linux-arm64.tar.gz" && \
    tar -xzf /tmp/foldseek.tar.gz -C /tmp && \
    install -m 0755 /tmp/foldseek/bin/foldseek /usr/local/bin/foldseek && \
    rm -rf /tmp/foldseek /tmp/foldseek.tar.gz

# Confirm the binary actually runs on this architecture, and that the specific utilities the
# pipeline's process scripts depend on are present with the behaviour those scripts assume.
RUN foldseek version \
    && foldseek easy-search --help > /dev/null \
    && foldseek databases --help > /dev/null \
    && foldseek createdb --help > /dev/null \
    && echo '{"status":"COMPLETE"}' | grep -oP '"status":"\K[^"]+' \
    && echo '{"a":1}' | jq -r '.a' > /dev/null \
    && bash -c '[[ "x_ca" =~ _ca$ ]]' \
    && command -v wget curl > /dev/null \
    && echo "foldseek arm64 image ok"

RUN cat > /README.md <<'EOF'
# FoldSeek (arm64)

[FoldSeek](https://github.com/steineggerlab/foldseek) 10-941cd33, built for arm64 / aarch64.

This is the arm64 stand-in for `quay.io/biocontainers/foldseek:10.941cd33--h5021889_1`, which
[nf-binder-design](https://github.com/Australian-Protein-Design-Initiative/nf-binder-design) uses
and which is published for amd64 only. The FoldSeek version is the same.

## Contents

- `foldseek`, the prebuilt static arm64 binary from the upstream release
- The utilities the pipeline's FoldSeek steps call: `wget`, `curl`, `jq`, GNU `grep` (for
  `grep -oP`), `bash`, `aria2c` and `rsync`

## No GPU build on arm64

Upstream publishes its avx2 and gpu tarballs for x86_64 only, so this image carries the generic
arm64 binary. FoldSeek runs on CPU here. The searches nf-binder-design performs are CPU searches,
so this is a difference in speed rather than in what works.

## Use

```bash
docker run --rm -v "$(pwd)":/data -w /data \
  ghcr.io/australian-protein-design-initiative/containers/foldseek:10-941cd33-arm64 \
  foldseek easy-search query.pdb targetdb result.tsv tmp
```

To use it from nf-binder-design on an arm64 host, point the FoldSeek processes at this image:

```groovy
process {
    withName: 'FOLDSEEK_DOWNLOAD_DB|FOLDSEEK_LOCAL_SEARCH|FOLDSEEK_REMOTE_SEARCH|FOLDSEEK_DOWNLOAD_CATH_NAMES' {
        container = 'ghcr.io/australian-protein-design-initiative/containers/foldseek:10-941cd33-arm64'
    }
}
```
EOF

WORKDIR /data

CMD ["foldseek"]
