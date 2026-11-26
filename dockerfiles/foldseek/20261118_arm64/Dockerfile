# syntax=docker/dockerfile:1.4
# Build like:
#   just build foldseek/20261118_arm64 --pull
#
# FoldSeek static build dated 2026-11-18 (commit 4f5c00ccb5590f08a261b9144fd9a5d28a71fa0e)
# for arm64 / aarch64 (eg DGX Spark GB10). The amd64 sibling is foldseek/20261118.
#
# This is the prebuilt binary published at https://mmseqs.com/foldseek/foldseek-linux-arm64.tar.gz,
# not a compile of the git tree. `foldseek version` on the matching amd64 tarball prints the
# commit above, and both tarballs were published together on 2026-11-18. The URL is a rolling
# "latest" build, so the sha256 pins this snapshot.
#
# Upstream also publishes foldseek-linux-gpu-arm64.tar.gz. The searches these images are used
# for are CPU ones, so this image uses the generic arm64 binary.
#
# The rest of the packages are what the nf-binder-design FoldSeek process scripts call directly:
# wget (cath-names download), curl and jq (the search.foldseek.com REST API), GNU grep for
# `grep -oP`, bash for `[[ =~ ]]` tests, and aria2 plus rsync, which `foldseek databases` uses
# to fetch a database when they are present.

ARG GIT_REPO=https://github.com/steineggerlab/foldseek.git
ARG GIT_REF=4f5c00ccb5590f08a261b9144fd9a5d28a71fa0e
ARG FOLDSEEK_VERSION=20261118
ARG FOLDSEEK_SHA256=6d96f0374e23bae7dfe78364fc878ab4ff1748d14890866b2a40bcf8601b09cd
ARG BASE_IMAGE=debian:trixie-slim

FROM ${BASE_IMAGE}

ARG GIT_REPO
ARG GIT_REF
ARG FOLDSEEK_VERSION
ARG FOLDSEEK_SHA256

LABEL org.opencontainers.image.source=https://github.com/Australian-Protein-Design-Initiative/containers
LABEL org.opencontainers.image.url="${GIT_REPO}"
LABEL org.opencontainers.image.documentation="https://github.com/steineggerlab/foldseek#readme"
LABEL org.opencontainers.image.title="FoldSeek (arm64)"
LABEL org.opencontainers.image.description="FoldSeek static arm64 build from 2026-11-18 (commit 4f5c00c) for aarch64 structural search"
LABEL org.opencontainers.image.licenses="GPL-3.0"
LABEL org.opencontainers.image.version="${FOLDSEEK_VERSION}"
LABEL org.opencontainers.image.revision="${GIT_REF}"
LABEL org.opencontainers.image.base.name="docker.io/library/debian:trixie-slim"
LABEL org.opencontainers.image.usage="docker run --rm -v \$(pwd):/data -w /data foldseek:20261118_arm64 foldseek easy-search query.pdb db res.tsv tmp"
LABEL org.australian-protein-design-initiative.image.platforms="linux/arm64"

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
    if [ "${ARCH}" != "arm64" ]; then echo "This Dockerfile is the arm64 build; got ${ARCH}" >&2; exit 1; fi && \
    curl -fsSL -o /tmp/foldseek.tar.gz \
        "https://mmseqs.com/foldseek/foldseek-linux-arm64.tar.gz" && \
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
    && echo "foldseek arm64 image ok"

RUN cat > /README.md <<'EOF'
# FoldSeek (arm64)

[FoldSeek](https://github.com/steineggerlab/foldseek) static build from 2026-11-18, for arm64 / aarch64.

The binary is the arm64 tarball from https://mmseqs.com/foldseek/, pinned by checksum.
The matching amd64 binary reports `foldseek version` as `4f5c00ccb5590f08a261b9144fd9a5d28a71fa0e`.

The amd64 image is `ghcr.io/australian-protein-design-initiative/containers/foldseek:20261118`.

## Contents

- `foldseek`, the prebuilt static arm64 binary
- The utilities the nf-binder-design FoldSeek steps call: `wget`, `curl`, `jq`, GNU `grep` (for
  `grep -oP`), `bash`, `aria2c` and `rsync`

## CPU build

Upstream also publishes `foldseek-linux-gpu-arm64.tar.gz`. This image carries the generic arm64
binary, so FoldSeek runs on CPU.

## Use

```bash
docker run --rm -v "$(pwd)":/data -w /data \
  ghcr.io/australian-protein-design-initiative/containers/foldseek:20261118_arm64 \
  foldseek easy-search query.pdb targetdb result.tsv tmp
```
EOF

WORKDIR /data

CMD ["foldseek"]
