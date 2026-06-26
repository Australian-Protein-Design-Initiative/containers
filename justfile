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
        --tag "{{REGISTRY}}/{{ORGANIZATION}}/${container}:${version}" \
        --tag "{{REGISTRY}}/{{ORGANIZATION}}/${container}:${version}-${datestamp}" \
        ${secrets_arg} \
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
    image_tag="${version}"
    apptainer_name="${image_name//\//-}-${image_tag//:/-}"
    
    apptainer_img="apptainer_containers/${apptainer_name}.img"
    apptainer_build_source="docker-daemon://${image_name}:${image_tag}"
    if [[ " {{args}} " == *" --push "* ]]; then
        # Image is already in the registry; build from there instead of the local daemon.
        apptainer_build_source="docker://${image_name}:${image_tag}"
    fi

    apptainer_build() {
        apptainer build --force "${apptainer_img}" "${apptainer_build_source}"
    }

    echo "Building Apptainer container: ${apptainer_img}"
    if ! apptainer_build; then
        if [[ " {{args}} " == *" --push "* ]]; then
            echo ""
            echo "Warning: Apptainer build failed (Docker image was pushed successfully)."
            echo "ORAS Apptainer images cannot be published without a local SIF build."
            echo "Or push the Dockerfile to trigger GitHub Actions, which builds and publishes the ORAS image."
            exit 0
        fi
        exit 1
    fi

    if [[ " {{args}} " == *" --push "* ]]; then
        oras_ref="oras://${image_name}:${image_tag}"
        oras_ref_datestamp="oras://${image_name}:${image_tag}-${datestamp}"

        if [ -n "${GITHUB_TOKEN:-}" ]; then
            echo "${GITHUB_TOKEN}" | apptainer registry login -u USERNAME --password-stdin oras://ghcr.io
        fi

        push_apptainer_oras() {
            local ref="$1"
            local output
            local rc
            echo "Pushing Apptainer container to ${ref}"
            output=$(apptainer push "${apptainer_img}" "${ref}" 2>&1) && return 0
            rc=$?
            echo "${output}"
            if echo "${output}" | grep -qiE 'unauthorized|authentication|not logged|401|403|denied|login required|please log'; then
                echo ""
                echo "Warning: Apptainer ORAS push failed due to missing or invalid authentication."
                echo "Log in with:"
                echo "  apptainer registry login -u <github_username> -p <pat_token> oras://ghcr.io"
                echo ""
                echo "Or set GITHUB_TOKEN in .env and run 'just login' first."
            fi
            return "${rc}"
        }

        push_apptainer_oras "${oras_ref}"
        push_apptainer_oras "${oras_ref_datestamp}"
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
    echo "${GITHUB_TOKEN}" | apptainer registry login -u USERNAME --password-stdin oras://ghcr.io

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
    echo "${GITHUB_TOKEN}" | apptainer registry login -u USERNAME --password-stdin oras://ghcr.io