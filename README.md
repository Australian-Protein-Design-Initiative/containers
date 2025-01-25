# containers
Docker / Apptainer containers for tools


## Building locally

If you need to build containers that require secrets, copy the example environment file and edit it:

```bash
cp .env.example .env
# Edit .env with your secrets:
# - ROSETTA_PASSWORD for building containers with RosettaCommons
# - GITHUB_TOKEN for pushing to container registry
```

Then build containers:

```bash
# Build a specific container and version locally
just build rfdiffusion cuda11

# Build and push a specific container and version to registry
just push rfdiffusion cuda11

# Build all containers locally
just build-all

# Build and push all containers to registry
just push-all
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