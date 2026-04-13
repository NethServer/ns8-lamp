#!/bin/bash

#
# Copyright (C) 2024 Nethesis S.r.l.
# SPDX-License-Identifier: GPL-3.0-or-later
#

# Terminate on error
set -e

# Prepare variables for later use
images=()
# The image will be pushed to GitHub container registry
repobase="${REPOBASE:-ghcr.io/nethserver}"
# Configure the image name
reponame="lamp"

# Define PHP versions to build
PHP_VERSIONS=("7.4" "8.0" "8.1" "8.2" "8.3" "8.4" "8.5")
PHPMYADMIN_VERSION="5.2.3"

# Secure temp dir for FIFO (avoids TOCTOU race of mktemp -u)
tmpdir=$(mktemp -d)
result_fifo="${tmpdir}/result.fifo"
mkfifo "${result_fifo}"
# Open FIFO read-write to avoid blocking on open (no writer needed yet)
exec 3<> "${result_fifo}"

declare -a pids=()

kill_all_builds() {
    for pid in "${pids[@]}"; do
        pkill -P "${pid}" 2>/dev/null || true  # kill podman and other children first
        kill "${pid}" 2>/dev/null || true       # then kill the bash wrapper
    done
}
trap 'kill_all_builds; exec 3<&-; exec 3>&-; rm -rf "${tmpdir}"' EXIT
trap 'kill_all_builds; exit 130' INT
trap 'kill_all_builds; exit 143' TERM

# Build the shared base image once (common packages, phpMyAdmin, Apache config...).
# Uses the localhost/ prefix so it is treated as a local image and never pulled
# from or pushed to a remote registry.
BASE_IMAGE="localhost/lamp-base-build"
echo "Building shared base image..."
podman build \
    --force-rm \
    --layers \
    --tag "${BASE_IMAGE}" \
    --build-arg "PHPMYADMIN_VERSION=${PHPMYADMIN_VERSION}" \
    --file container/Containerfile.base \
    container

# Build all PHP version images in parallel
echo "Building PHP version images in parallel..."
for PHP_VERSION in "${PHP_VERSIONS[@]}"; do
    echo "  Starting build for PHP ${PHP_VERSION}..."
    (
        result=0
        # Reports result to FIFO on exit; handles normal exit and SIGTERM.
        trap 'printf "%s %d\n" "${PHP_VERSION}" "${result}" >"${result_fifo}" 2>/dev/null || true' EXIT
        set -o pipefail
        podman build \
            --force-rm \
            --layers \
            --pull-never \
            --tag "${repobase}/lamp-server-php${PHP_VERSION}" \
            --build-arg "BASE_IMAGE=${BASE_IMAGE}" \
            --build-arg "PHP_VERSION=${PHP_VERSION}" \
            --file container/Containerfile \
            container 2>&1 | sed -u "s/^/[PHP ${PHP_VERSION}] /" || result=$?
    ) &
    pids+=("$!")
done

# Read results in completion order; stop everything on first failure
total=${#PHP_VERSIONS[@]}
for (( completed=0; completed<total; completed++ )); do
    read -r done_version done_result <&3
    if [[ "${done_result}" -ne 0 ]]; then
        echo "[PHP ${done_version}] BUILD FAILED — killing remaining builds..." >&2
        podman rmi "${BASE_IMAGE}" 2>/dev/null || true
        exit 1
    fi
    echo "[PHP ${done_version}] BUILD OK"
    images+=("${repobase}/lamp-server-php${done_version}")
done

# Reap all background build jobs to avoid zombies
wait "${pids[@]}"

# Remove the base image: it is an intermediate build artifact, not meant to be published
echo "Removing intermediate base image..."
podman rmi "${BASE_IMAGE}" 2>/dev/null || true

# Create a new empty container image
container=$(buildah from scratch)

# Reuse existing nodebuilder-lamp container, to speed up builds
if ! buildah containers --format "{{.ContainerName}}" | grep -q nodebuilder-lamp; then
    echo "Pulling NodeJS runtime..."
    buildah from --name nodebuilder-lamp -v "${PWD}:/usr/src:Z" docker.io/library/node:lts
fi

echo "Build static UI files with node..."
buildah run \
    --workingdir=/usr/src/ui \
    --env="NODE_OPTIONS=--openssl-legacy-provider" \
    nodebuilder-lamp \
    sh -c "yarn install && yarn build"

# Add imageroot directory to the container image
buildah add "${container}" imageroot /imageroot
buildah add "${container}" ui/dist /ui

buildah config --entrypoint=/ \
    --label="org.nethserver.authorizations=traefik@node:routeadm cluster:accountconsumer" \
    --label="org.nethserver.tcp-ports-demand=1" \
    --label="org.nethserver.rootfull=0" \
    --label="org.nethserver.min-core=3.12.4-0" \
    --label="org.nethserver.images=ghcr.io/nethserver/lamp-server-php8.3:${IMAGETAG}" \
    "${container}"
# Commit the image
buildah commit "${container}" "${repobase}/${reponame}"

# Append the image URL to the images array
images+=("${repobase}/${reponame}")

#
# NOTICE:
#
# It is possible to build and publish multiple images.
#
# 1. create another buildah container
# 2. add things to it and commit it
# 3. append the image url to the images array
#

#
# Setup CI when pushing to GitHub.
# Warning! docker::// protocol expects lowercase letters (,,)
if [[ -n "${CI}" ]]; then
    # Set output value for GitHub Actions
    printf "images=%s\n" "${images[*],,}" >> "${GITHUB_OUTPUT}"
else
    # Just print info for manual push
    printf "Publish the images with:\n\n"
    for image in "${images[@],,}"; do printf "  buildah push %s docker://%s:%s\n" "${image}" "${image}" "${IMAGETAG:-latest}" ; done
    printf "\n"
fi
