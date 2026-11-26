# syntax=docker/dockerfile:1.4
# Build like:
#   just build foldseek/20261118 --pull
#
# FoldSeek static build dated 2026-11-18 (commit 4f5c00ccb5590f08a261b9144fd9a5d28a71fa0e)
# for amd64 / x86_64. amd64 is the default architecture, so the tag has no architecture suffix.
# The arm64 sibling is foldseek/20261118_arm64.
#
# This is the prebuilt binary published at https://mmseqs.com/foldseek/foldseek-linux-avx2.tar.gz,
# not a compile of the git tree. `foldseek version` on that tarball prints the commit above.
# The URL is a rolling "latest" build, so the sha256 pins this 2026-11-18 snapshot.
#
# The avx2 tarball is the CPU build. Upstream also publishes a gpu tarball for x86_64; the
# searches these images are used for are CPU ones, so this image uses avx2.
#
# The rest of the packages are what the nf-binder-design FoldSeek process scripts call directly:
# wget (cath-names download), curl and jq (the search.foldseek.com REST API), GNU grep for
# `grep -oP`, bash for `[[ =~ ]]` tests, and aria2 plus rsync, which `foldseek databases` uses
# to fetch a database when they are present.

ARG GIT_REPO=https://github.com/steineggerlab/foldseek.git
ARG GIT_REF=4f5c00ccb5590f08a261b9144fd9a5d28a71fa0e
ARG FOLDSEEK_VERSION=20261118
ARG FOLDSEEK_SHA256=fd942cf05f922600f20c9a56d2f63c5bf41810106039752c5f806f922b342e84
ARG BASE_IMAGE=debian:trixie-slim

FROM ${BASE_IMAGE}

ARG GIT_REPO
ARG GIT_REF
ARG FOLDSEEK_VERSION
ARG FOLDSEEK_SHA256

LABEL org.opencontainers.image.source=https://github.com/Australian-Protein-Design-Initiative/containers
LABEL org.opencontainers.image.url="${GIT_REPO}"
LABEL org.opencontainers.image.documentation="https://github.com/steineggerlab/foldseek#readme"
LABEL org.opencontainers.image.title="FoldSeek"
LABEL org.opencontainers.image.description="FoldSeek static avx2 build from 2026-11-18 (commit 4f5c00c) for amd64 / x86_64 structural search"
LABEL org.opencontainers.image.licenses="GPL-3.0"
LABEL org.opencontainers.image.version="${FOLDSEEK_VERSION}"
LABEL org.opencontainers.image.revision="${GIT_REF}"
LABEL org.opencontainers.image.base.name="docker.io/library/debian:trixie-slim"
LABEL org.opencontainers.image.usage="docker run --rm -v \$(pwd):/data -w /data foldseek:20261118 foldseek easy-search query.pdb db res.tsv tmp"
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
        "https://mmseqs.com/foldseek/foldseek-linux-avx2.tar.gz" && \
    echo "${FOLDSEEK_SHA256}  /tmp/foldseek.tar.gz" | sha256sum --check && \
    tar -xzf /tmp/foldseek.tar.gz -C /tmp && \
    install -m 0755 /tmp/foldseek/bin/foldseek /usr/local/bin/foldseek && \
    rm -rf /tmp/foldseek /tmp/foldseek.tar.gz

# Confirm the binary is the pinned commit, and that the utilities the pipeline's process
# scripts depend on are present with the behaviour those scripts assume.
RUN test "$(foldseek version)" = "${GIT_REF}" \
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

[FoldSeek](https://github.com/steineggerlab/foldseek) static build from 2026-11-18, for amd64 / x86_64.

The binary is the avx2 tarball from https://mmseqs.com/foldseek/, pinned by checksum.
`foldseek version` prints `4f5c00ccb5590f08a261b9144fd9a5d28a71fa0e`.

amd64 is the default architecture, so this tag has no architecture suffix. The arm64 image is
`ghcr.io/australian-protein-design-initiative/containers/foldseek:20261118_arm64`.

## Contents

- `foldseek`, the prebuilt static avx2 binary
- The utilities the nf-binder-design FoldSeek steps call: `wget`, `curl`, `jq`, GNU `grep` (for
  `grep -oP`), `bash`, `aria2c` and `rsync`

## CPU build

Upstream also publishes a gpu tarball for x86_64. This image carries the avx2 binary.

## Use

```bash
docker run --rm -v "$(pwd)":/data -w /data \
  ghcr.io/australian-protein-design-initiative/containers/foldseek:20261118 \
  foldseek easy-search query.pdb targetdb result.tsv tmp
```
EOF

WORKDIR /data

CMD ["foldseek"]
