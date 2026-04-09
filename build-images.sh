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

# Build the shared base image once (common packages, phpMyAdmin, Apache config...)
BASE_IMAGE="${repobase}/lamp-base"
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
pids=()
failed=()

for PHP_VERSION in "${PHP_VERSIONS[@]}"; do
    echo "  Starting build for PHP ${PHP_VERSION}..."
    podman build \
        --force-rm \
        --layers \
        --tag "${repobase}/lamp-server-php${PHP_VERSION}" \
        --build-arg "BASE_IMAGE=${BASE_IMAGE}" \
        --build-arg "PHP_VERSION=${PHP_VERSION}" \
        --file container/Containerfile \
        container &
    pids+=("$!:${PHP_VERSION}")
done

# Wait for all builds and collect failures
for pid_ver in "${pids[@]}"; do
    pid="${pid_ver%%:*}"
    ver="${pid_ver##*:}"
    if wait "${pid}"; then
        echo "  PHP ${ver}: build OK"
        images+=("${repobase}/lamp-server-php${ver}")
    else
        echo "  PHP ${ver}: build FAILED" >&2
        failed+=("${ver}")
    fi
done

if [[ ${#failed[@]} -gt 0 ]]; then
    echo "ERROR: The following PHP version builds failed: ${failed[*]}" >&2
    exit 1
fi

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
# Setup CI when pushing to Github.
# Warning! docker::// protocol expects lowercase letters (,,)
if [[ -n "${CI}" ]]; then
    # Set output value for Github Actions
    printf "images=%s\n" "${images[*],,}" >> "${GITHUB_OUTPUT}"
else
    # Just print info for manual push
    printf "Publish the images with:\n\n"
    for image in "${images[@],,}"; do printf "  buildah push %s docker://%s:%s\n" "${image}" "${image}" "${IMAGETAG:-latest}" ; done
    printf "\n"
fi
