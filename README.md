# containers
Docker / Apptainer containers for protein design tools

> NOTE: Some of these containers use PyRosetta/Rosetta, which is free for non-commercial use, however commercial use requires a paid license agreement with University of Washington: https://github.com/RosettaCommons/rosetta/blob/main/LICENSE.md and https://rosettacommons.org/software/licensing-faq/

## Building locally

```bash
# Build a specific container and version locally
just build rfdiffusion cuda11

# Build and push a specific container and version to registry
just push rfdiffusion cuda11

# Build all containers locally
just build-all

# Build and push all containers to registry
just push-all

# Build and push, ignoring the Docker build cache (other docker build args can be passed also)
just push boltz latest --no-cache
```

## Testing Github Actions locally with act

```bash
curl -s https://raw.githubusercontent.com/nektos/act/master/install.sh | bash

cat << 'EOF' > event.json
{
    "inputs": {
        "container": "rfdiffusion",
        "version": "dgl2407"
    }
}
EOF

./bin/act workflow_dispatch -W .github/workflows/docker-build-test.yml -e event.json
```