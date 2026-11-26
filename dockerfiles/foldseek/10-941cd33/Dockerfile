# syntax=docker/dockerfile:1.4
# Build like:
#   just build foldseek/10-941cd33 --pull
#
# FoldSeek 10-941cd33 for amd64 / x86_64. amd64 is the default architecture, so the tag has
# no architecture suffix. The arm64 sibling is foldseek/10-941cd33-arm64.
#
# nf-binder-design runs FOLDSEEK_DOWNLOAD_DB, FOLDSEEK_LOCAL_SEARCH, FOLDSEEK_REMOTE_SEARCH and
# FOLDSEEK_DOWNLOAD_CATH_NAMES from quay.io/biocontainers/foldseek:10.941cd33--h5021889_1. This
# image is the same FoldSeek version, published from this repo for amd64.
#
# Upstream publishes a prebuilt static avx2 binary for this release, so FoldSeek itself is not
# compiled here. The gpu tarball is also x86_64, but the searches nf-binder-design runs are CPU
# ones, so this image uses the avx2 build.
#
# The rest of the packages are what the pipeline's FoldSeek process scripts call directly, rather
# than a general-purpose toolbox: wget (cath-names download), curl and jq (the search.foldseek.com
# REST API in FOLDSEEK_REMOTE_SEARCH), GNU grep for `grep -oP` on that API's JSON, bash for the
# `[[ =~ ]]` tests in FOLDSEEK_LOCAL_SEARCH, and aria2 plus rsync, which `foldseek databases` uses
# to fetch a database when they are present.

ARG FOLDSEEK_VERSION=10-941cd33
ARG FOLDSEEK_SHA256=e6a3e3860e76b0b7b858736f627fe680d4d7f0fc7298301d8a92b9f711d74ac7
ARG BASE_IMAGE=debian:trixie-slim

FROM ${BASE_IMAGE}

ARG FOLDSEEK_VERSION
ARG FOLDSEEK_SHA256

LABEL org.opencontainers.image.source=https://github.com/Australian-Protein-Design-Initiative/containers
LABEL org.opencontainers.image.url="https://github.com/steineggerlab/foldseek"
LABEL org.opencontainers.image.documentation="https://github.com/steineggerlab/foldseek#readme"
LABEL org.opencontainers.image.title="FoldSeek"
LABEL org.opencontainers.image.description="FoldSeek 10-941cd33 structural search for amd64 / x86_64, matching quay.io/biocontainers/foldseek:10.941cd33--h5021889_1"
LABEL org.opencontainers.image.licenses="GPL-3.0"
LABEL org.opencontainers.image.version="${FOLDSEEK_VERSION}"
LABEL org.opencontainers.image.revision="${FOLDSEEK_VERSION}"
LABEL org.opencontainers.image.base.name="docker.io/library/debian:trixie-slim"
LABEL org.opencontainers.image.usage="docker run --rm -v \$(pwd):/data -w /data foldseek:10-941cd33 foldseek easy-search query.pdb db res.tsv tmp"
LABEL org.australian-protein-design-initiative.image.platforms="linux/amd64"

ENV DEBIAN_FRONTEND=noninteractive

RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt,sharing=locked \
    apt-get update && apt-get install -y --no-install-recommends \
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
    if [ "${ARCH}" != "amd64" ]; then echo "This Dockerfile is the amd64 build; got ${ARCH}" >&2; exit 1; fi && \
    curl -fsSL -o /tmp/foldseek.tar.gz \
        "https://github.com/steineggerlab/foldseek/releases/download/${FOLDSEEK_VERSION}/foldseek-linux-avx2.tar.gz" && \
    echo "${FOLDSEEK_SHA256}  /tmp/foldseek.tar.gz" | sha256sum --check && \
    tar -xzf /tmp/foldseek.tar.gz -C /tmp && \
    install -m 0755 /tmp/foldseek/bin/foldseek /usr/local/bin/foldseek && \
    rm -rf /tmp/foldseek /tmp/foldseek.tar.gz

# Confirm the binary actually runs on this architecture, and that the specific utilities the
# pipeline's process scripts depend on are present with the behaviour those scripts assume.
RUN foldseek version \
    && foldseek easy-search --help > /dev/null \
    && foldseek databases --help > /dev/null \
    && foldseek createdb --help > /dev/null \
    && foldseek easy-cluster --help > /dev/null \
    && echo '{"status":"COMPLETE"}' | grep -oP '"status":"\K[^"]+' \
    && echo '{"a":1}' | jq -r '.a' > /dev/null \
    && bash -c '[[ "x_ca" =~ _ca$ ]]' \
    && command -v wget curl > /dev/null \
    && echo "foldseek amd64 image ok"

RUN cat > /README.md <<'EOF'
# FoldSeek

[FoldSeek](https://github.com/steineggerlab/foldseek) 10-941cd33, built for amd64 / x86_64.

amd64 is the default architecture, so this tag has no architecture suffix. The arm64 image is
`ghcr.io/australian-protein-design-initiative/containers/foldseek:10-941cd33-arm64`.

This matches `quay.io/biocontainers/foldseek:10.941cd33--h5021889_1`, which
[nf-binder-design](https://github.com/Australian-Protein-Design-Initiative/nf-binder-design) uses.
The FoldSeek version is the same.

## Contents

- `foldseek`, the prebuilt static avx2 binary from the upstream release
- The utilities the pipeline's FoldSeek steps call: `wget`, `curl`, `jq`, GNU `grep` (for
  `grep -oP`), `bash`, `aria2c` and `rsync`

## CPU build

Upstream also publishes a gpu tarball for x86_64. The searches nf-binder-design performs are CPU
searches, so this image carries the avx2 binary.

## Use

```bash
docker run --rm -v "$(pwd)":/data -w /data \
  ghcr.io/australian-protein-design-initiative/containers/foldseek:10-941cd33 \
  foldseek easy-search query.pdb targetdb result.tsv tmp
```

To use it from nf-binder-design on an amd64 host, point the FoldSeek processes at this image:

```groovy
process {
    withName: 'FOLDSEEK_DOWNLOAD_DB|FOLDSEEK_LOCAL_SEARCH|FOLDSEEK_REMOTE_SEARCH|FOLDSEEK_DOWNLOAD_CATH_NAMES' {
        container = 'ghcr.io/australian-protein-design-initiative/containers/foldseek:10-941cd33'
    }
}
```
EOF

WORKDIR /data

CMD ["foldseek"]
