#!/usr/bin/env just --justfile

set dotenv-load

# Default registry and organization
REGISTRY := "ghcr.io"
ORGANIZATION := "australian-protein-design-initiative/containers"

# Optional environment variables (set in .env file):
# ROSETTA_PASSWORD: Password for downloading Rosetta binaries
# GITHUB_TOKEN: GitHub token for pushing to container registry

# List all available containers
list:
    @find dockerfiles -mindepth 2 -maxdepth 2 -type f -name Dockerfile | cut -d'/' -f2-3 | sed 's|/| |'

# Build a specific container and version
build container version *args='':
    #!/usr/bin/env bash
    if [ ! -d "dockerfiles/{{container}}/{{version}}" ]; then
        echo "Error: Container {{container}} version {{version}} not found"
        exit 1
    fi

    # Get platforms from Dockerfile label or default to linux/amd64
    platforms="linux/amd64"
    if grep -q "^LABEL.*org.australian-protein-design-initiative.image.platforms=" "dockerfiles/{{container}}/{{version}}/Dockerfile"; then
        platforms=$(grep "^LABEL.*org.australian-protein-design-initiative.image.platforms=" "dockerfiles/{{container}}/{{version}}/Dockerfile" | sed 's/.*platforms="\(.*\)".*/\1/')
    fi

    # Generate datestamp for tag
    datestamp=$(date '+%F.%H%M%S')

    # Build secrets argument if ROSETTA_PASSWORD is set
    secrets_arg=""
    if [ -n "${ROSETTA_PASSWORD:-}" ]; then
        secrets_arg="--secret id=rosetta_password,env=ROSETTA_PASSWORD"
    fi

    # Determine output mode and remove --push from args if present
    other_args="{{args}}"
    output_args="--load" # Default action is to build and load locally.
    
    if [[ " {{args}} " == *" --push "* ]]; then
        other_args=$(echo " {{args}} " | sed 's/ --push / /g' | xargs)
        # If pushing a multi-platform image, only push.
        if [[ "$platforms" == *,* ]]; then
            output_args="--push"
        # If pushing a single-platform image, push AND load.
        else
            output_args="--output type=docker --output type=registry"
        fi
    fi

    # Build and push the image
    if ! docker buildx build \
        --platform "${platforms}" \
        --tag "{{REGISTRY}}/{{ORGANIZATION}}/{{container}}:{{version}}" \
        --tag "{{REGISTRY}}/{{ORGANIZATION}}/{{container}}:{{version}}-${datestamp}" \
        ${secrets_arg} \
        ${output_args} \
        ${other_args} \
        dockerfiles/{{container}}/{{version}}; then
        echo "Docker build failed, skipping Apptainer build"
        exit 1
    fi
    
    # Skip Apptainer build for multi-platform builds
    if [[ "$platforms" == *,* ]]; then
        echo "Skipping Apptainer build for multi-platform build"
        exit 0
    fi
    # Skip Apptainer build for push builds
    # if [[ "{{args}}" == *"--push"* ]]; then
    #     echo "Skipping Apptainer build for push build"
    #     exit 0
    # fi
    
    # Create apptainer_containers directory if it doesn't exist
    mkdir -p apptainer_containers
    
    # Format image name and tag for Apptainer (replace colons with underscores)
    image_name="{{REGISTRY}}/{{ORGANIZATION}}/{{container}}"
    image_tag="{{version}}"
    apptainer_name="${image_name//\//_}_${image_tag//:/_}"
    
    echo "Building Apptainer container: ${apptainer_name}.sif"
    apptainer build --force "apptainer_containers/${apptainer_name}.sif" "docker-daemon://${image_name}:${image_tag}"

# Build and push a specific container and version
push container version *args='': (build container version "--push" args)

# Build all containers
build-all:
    #!/usr/bin/env bash
    set -uo pipefail
    
    failed_builds=()
    
    # Ensure apptainer_containers directory exists
    mkdir -p apptainer_containers
    
    # Find all Dockerfiles and build them
    while IFS= read -r dockerfile; do
        if [[ -f "$dockerfile" ]]; then
            container=$(echo "$dockerfile" | cut -d'/' -f3)
            version=$(echo "$dockerfile" | cut -d'/' -f4)
            echo "Building $container:$version..."
            if ! just build "$container" "$version"; then
                echo "Failed to build $container:$version"
                failed_builds+=("$container:$version")
            fi
        fi
    done < <(find . -type f -name "Dockerfile" -path "*/dockerfiles/*/*/Dockerfile")

    if [ ${#failed_builds[@]} -ne 0 ]; then
        echo "The following builds failed:"
        printf '%s\n' "${failed_builds[@]}"
        exit 1
    fi

# Build and push all containers
push-all:
    #!/usr/bin/env bash
    set -uo pipefail
    
    failed_pushes=()

    if [ -z "${GITHUB_TOKEN:-}" ]; then
        echo "Error: GITHUB_TOKEN not set in .env file"
        exit 1
    fi

    echo "Logging into registry..."
    echo "${GITHUB_TOKEN}" | docker login {{REGISTRY}} -u USERNAME --password-stdin

    # Find all Dockerfiles and build+push them
    while IFS= read -r dockerfile; do
        if [[ -f "$dockerfile" ]]; then
            container=$(echo "$dockerfile" | cut -d'/' -f3)
            version=$(echo "$dockerfile" | cut -d'/' -f4)
            echo "Building and pushing $container:$version..."
            if ! just push "$container" "$version"; then
                echo "Failed to build and push $container:$version"
                failed_pushes+=("$container:$version")
            fi
        fi
    done < <(find . -type f -name "Dockerfile" -path "*/dockerfiles/*/*/Dockerfile")

    if [ ${#failed_pushes[@]} -ne 0 ]; then
        echo "The following builds/pushes failed:"
        printf '%s\n' "${failed_pushes[@]}"
        exit 1
    fi

# Login to the container registry using GITHUB_TOKEN
login:
    #!/usr/bin/env bash
    if [ -z "${GITHUB_TOKEN:-}" ]; then
        echo "Error: GITHUB_TOKEN not set in .env file"
        exit 1
    fi
    echo "${GITHUB_TOKEN}" | docker login {{REGISTRY}} -u USERNAME --password-stdin 