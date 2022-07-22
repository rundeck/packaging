#!/bin/bash

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null && pwd )"

DRY_RUN="${DRY_RUN:-true}"
S3_DRY_RUN="--dryrun"
if [[ "$DRY_RUN" != true ]] ; then
    S3_DRY_RUN=""
fi

set -euo pipefail

shopt -s globstar

UPSTREAM_TAG=${UPSTREAM_TAG:-}
UPSTREAM_ARTIFACT_BASE=${UPSTREAM_ARTIFACT_BASE:-s3://rundeck-ci-artifacts/oss}
UPSTREAM_PROJECT=${UPSTREAM_PROJECT:-rundeck}

main() {

    echo "---------Entering main method----------"
    S3_ARTIFACT_BASE=${UPSTREAM_ARTIFACT_BASE}/${UPSTREAM_PROJECT:-rundeck}

    # Location of CI resources such as private keys
    S3_CI_RESOURCES="s3://rundeck-ci-resources/shared/resources"

    # Determine build context
    # snapshot | release
    if [[ ! -z "${UPSTREAM_TAG}" ]] ; then
        BUILD_TYPE="release"
    else
        BUILD_TYPE="snapshot"
    fi

    echo "---------main method LINE 35----------"
    # Possible artifact locations
    S3_LATEST_ARTIFACT_PATH="${UPSTREAM_ARTIFACT_BASE}/latest/artifacts"
    S3_BUILD_ARTIFACT_PATH="${S3_ARTIFACT_BASE}/branch/${UPSTREAM_BRANCH:-master}/build/${UPSTREAM_BUILD_NUMBER:-}/artifacts"
    S3_TAG_ARTIFACT_PATH="${S3_ARTIFACT_BASE}/tag/${UPSTREAM_TAG}/artifacts"

    local COMMAND="${1}"
    shift
    echo "---------main method LINE 43----------"
    case "${COMMAND}" in
        fetch_artifacts) fetch_artifacts "${@}" ;;
        test) test_packages "${@}" ;;
        docker_login) docker_login "${@}" ;;
    esac
}

fetch_artifacts() {
    echo "------THE TOP OF FETCH ARTIFACTS-------"
    test -d artifacts || mkdir artifacts
    echo "---------FETCH LINE 54----------"
    echo $BUILD_TYPE
    echo  "---------S3 Tag path----------"
    echo "$S3_TAG_ARTIFACT_PATH"
    if [[ "${BUILD_TYPE}" == "release" ]] ; then
        aws s3 sync --delete "${S3_TAG_ARTIFACT_PATH}" upstream-artifacts
    else
        aws s3 sync --delete "${S3_LATEST_ARTIFACT_PATH}" upstream-artifacts
    fi

    aws s3 sync --delete "${S3_CI_RESOURCES}" ~/.gnupg

    PATTERN="upstream-artifacts/**/*.war"
    WARS=( $PATTERN )
    cp "${WARS[@]}" artifacts/
}

test_packages() {
    docker_login
    bash test/test-docker-install-deb.sh
    bash test/test-docker-install-rpm.sh
}

docker_login() {
    docker login -u $DOCKER_USERNAME -p $DOCKER_PASSWORD
}

(
    cd $DIR/..
    main "${@}"
)