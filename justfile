#!/usr/bin/env just --justfile

set dotenv-load

# Default registry and organization
REGISTRY := "ghcr.io"
ORGANIZATION := "australian-protein-design-initiative/containers"

# Optional environment variables (set in .env file):
# ROSETTA_PASSWORD: Password for downloading Rosetta binaries
# GITHUB_TOKEN: GitHub token for pushing to container registry
# APPTAINER_IGNORE_PROOT: Set to 0 to re-enable proot (default 1; avoids ptrace failures on hardened hosts)

# Default for all recipes; bash recipes also apply ${APPTAINER_IGNORE_PROOT:-1} so .env can override.
export APPTAINER_IGNORE_PROOT := "1"

# List all available containers
list:
    @find dockerfiles -mindepth 2 -maxdepth 2 -type f -name Dockerfile | cut -d'/' -f2-3

# Build a specific container and version (e.g. just build germinal/5efad8f)
# Weight variants from one Dockerfile: just build name/tag --variant weights|no-weights
build container_version *args='':
    #!/usr/bin/env bash
    export APPTAINER_IGNORE_PROOT="${APPTAINER_IGNORE_PROOT:-1}"
    container_version="{{container_version}}"
    # Accept dockerfile(s)/ prefix from copy-pasted paths (e.g. dockerfile/proteina-complexa/916eaae)
    case "$container_version" in
        dockerfile/*) container_version="${container_version#dockerfile/}" ;;
        dockerfiles/*) container_version="${container_version#dockerfiles/}" ;;
    esac
    container="${container_version%/*}"
    version="${container_version#*/}"
    if [ ! -d "dockerfiles/${container}/${version}" ]; then
        echo "Error: Container ${container} version ${version} not found"
        exit 1
    fi

    # Get platforms from Dockerfile label or default to linux/amd64
    platforms="linux/amd64"
    if grep -q "^LABEL.*org.australian-protein-design-initiative.image.platforms=" "dockerfiles/${container}/${version}/Dockerfile"; then
        platforms=$(grep "^LABEL.*org.australian-protein-design-initiative.image.platforms=" "dockerfiles/${container}/${version}/Dockerfile" | sed 's/.*platforms="\(.*\)".*/\1/')
    fi

    # Generate datestamp for tag
    datestamp=$(date '+%F.%H%M%S')

    # Build secrets argument if ROSETTA_PASSWORD is set
    secrets_arg=""
    if [ -n "${ROSETTA_PASSWORD:-}" ]; then
        secrets_arg="--secret id=rosetta_password,env=ROSETTA_PASSWORD"
    fi

    # Determine output mode and remove --push / --variant from args if present
    other_args="{{args}}"
    output_args="--load" # Default action is to build and load locally.
    variant=""
    weights_build_arg=""
    image_tag="${version}"

    if [[ " ${other_args} " =~ [[:space:]]--variant(=|[[:space:]]+)([^[:space:]]+) ]]; then
        variant="${BASH_REMATCH[2]}"
        other_args=$(echo " ${other_args} " | sed -E 's/ --variant(=| +)[^ ]+ / /g')
    fi
    case "${variant}" in
        weights)
            weights_build_arg="--build-arg DOWNLOAD_WEIGHTS=true"
            if [[ "${image_tag}" == *_no-weights ]]; then
                image_tag="${image_tag%_no-weights}_weights"
            elif [[ "${image_tag}" != *_weights ]]; then
                image_tag="${image_tag}_weights"
            fi
            ;;
        no-weights)
            weights_build_arg="--build-arg DOWNLOAD_WEIGHTS=false"
            if [[ "${image_tag}" == *_no-weights ]]; then
                :
            elif [[ "${image_tag}" == *_weights ]]; then
                image_tag="${image_tag%_weights}_no-weights"
            else
                image_tag="${image_tag}_no-weights"
            fi
            ;;
        "")
            ;;
        *)
            echo "Error: unknown --variant '${variant}' (expected weights or no-weights)"
            exit 1
            ;;
    esac

    if [[ " ${other_args} " == *" --push "* ]]; then
        other_args=$(echo " ${other_args} " | sed 's/ --push / /g')
        # If pushing a multi-platform image, only push.
        if [[ "$platforms" == *,* ]]; then
            output_args="--push"
        # If pushing a single-platform image, push AND load.
        else
            output_args="--output type=docker --output type=registry"
        fi
    fi
    other_args=$(echo "${other_args}" | xargs)

    # Build and push the image
    if ! docker buildx build \
        --platform "${platforms}" \
        --tag "{{REGISTRY}}/{{ORGANIZATION}}/${container}:${image_tag}" \
        --tag "{{REGISTRY}}/{{ORGANIZATION}}/${container}:${image_tag}-${datestamp}" \
        ${secrets_arg} \
        ${weights_build_arg} \
        ${output_args} \
        ${other_args} \
        "dockerfiles/${container}/${version}"; then
        echo "Docker build failed, skipping Apptainer build"
        exit 1
    fi
    
    # Skip Apptainer build for multi-platform builds
    if [[ "$platforms" == *,* ]]; then
        echo "Skipping Apptainer build for multi-platform build"
        exit 0
    fi
    
    # Create apptainer_containers directory if it doesn't exist
    mkdir -p apptainer_containers
    
    # Format image name and tag for Apptainer (replace slashes and colons with dashes)
    image_name="{{REGISTRY}}/{{ORGANIZATION}}/${container}"
    apptainer_name="${image_name//\//-}-${image_tag//:/-}"
    
    apptainer_img="apptainer_containers/${apptainer_name}.img"
    apptainer_daemon_ref="docker-daemon://${image_name}:${image_tag}"
    apptainer_registry_ref="docker://${image_name}:${image_tag}"

    apptainer_build_from() {
        local source="$1"
        echo "Building Apptainer container: ${apptainer_img} (from ${source})"
        apptainer build --force "${apptainer_img}" "${source}"
    }

    apptainer_build_ok=false
    if docker image inspect "${image_name}:${image_tag}" >/dev/null 2>&1; then
        if apptainer_build_from "${apptainer_daemon_ref}"; then
            apptainer_build_ok=true
        else
            echo "Apptainer build from local Docker daemon failed, trying registry..."
        fi
    else
        echo "Image not in local Docker daemon, building from registry..."
    fi

    if [ "${apptainer_build_ok}" = false ]; then
        if apptainer_build_from "${apptainer_registry_ref}"; then
            apptainer_build_ok=true
        fi
    fi

    # The SIF is built for local use only and is deliberately NOT pushed.
    #
    # We used to also `apptainer push` it to oras://${image_name}:${image_tag} --
    # the same repo and tag the Docker image had just been pushed to. A tag
    # resolves to exactly one manifest, so the ORAS push silently REPLACED the
    # multi-layer Docker manifest with a single-blob SIF artifact. That made the
    # published image one monolithic layer (e.g. rc-foundry:0.2.0-weights was a
    # single 9.68 GB blob), which cannot be fetched in parallel and cannot be
    # resumed if the connection drops mid-transfer.
    #
    # Consumers should now pull docker://${image_name}:${image_tag} and let
    # Apptainer convert it locally.
    if [ "${apptainer_build_ok}" = false ]; then
        if [[ " {{args}} " == *" --push "* ]]; then
            echo ""
            echo "Warning: local Apptainer SIF build failed (the Docker image was pushed successfully)."
            echo "This does not affect the published image -- only oras:// artifacts needed a local SIF,"
            echo "and those are no longer published. Pull docker://${image_name}:${image_tag} instead."
            exit 0
        fi
        exit 1
    fi

# Build and push a specific container and version (e.g. just push germinal/5efad8f)
push container_version *args='': (build container_version "--push" args)

# Build all containers
build-all:
    #!/usr/bin/env bash
    set -uo pipefail
    export APPTAINER_IGNORE_PROOT="${APPTAINER_IGNORE_PROOT:-1}"
    
    failed_builds=()
    
    # Ensure apptainer_containers directory exists
    mkdir -p apptainer_containers
    
    # Find all Dockerfiles and build them
    while IFS= read -r dockerfile; do
        if [[ -f "$dockerfile" ]]; then
            container=$(echo "$dockerfile" | cut -d'/' -f3)
            version=$(echo "$dockerfile" | cut -d'/' -f4)
            echo "Building $container/$version..."
            if ! just build "$container/$version"; then
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
    export APPTAINER_IGNORE_PROOT="${APPTAINER_IGNORE_PROOT:-1}"
    
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
            echo "Building and pushing $container/$version..."
            if ! just push "$container/$version"; then
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
    export APPTAINER_IGNORE_PROOT="${APPTAINER_IGNORE_PROOT:-1}"
    if [ -z "${GITHUB_TOKEN:-}" ]; then
        echo "Error: GITHUB_TOKEN not set in .env file"
        exit 1
    fi
    echo "${GITHUB_TOKEN}" | docker login {{REGISTRY}} -u USERNAME --password-stdin