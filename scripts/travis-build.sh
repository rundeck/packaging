#!/bin/bash

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null && pwd )"

set -xeuo pipefail

shopt -s globstar

UPSTREAM_TAG=${UPSTREAM_TAG:-}
UPSTREAM_ARTIFACT_BASE=${UPSTREAM_ARTIFACT_BASE:-s3://rundeck-travis-artifacts/oss}
UPSTREAM_PROJECT=${UPSTREAM_PROJECT:-rundeck}

main() {
    S3_ARTIFACT_BASE=${UPSTREAM_ARTIFACT_BASE}/${UPSTREAM_PROJECT:-rundeck}

    # Location of CI resources such as private keys
    S3_CI_RESOURCES="s3://rundeck-ci/shared/resources"

    # Determine build context
    # snapshot | release
    if [[ ! -z "${UPSTREAM_TAG}" ]] ; then
        BUILD_TYPE="release"
    else
        BUILD_TYPE="snapshot"
    fi

    # Possible artifact locations
    S3_LATEST_ARTIFACT_PATH="${S3_ARTIFACT_BASE}/branch/master/latest/artifacts"
    S3_BUILD_ARTIFACT_PATH="${S3_ARTIFACT_BASE}/branch/${RUNDECK_BRANCH:-master}/build/${UPSTREAM_BUILD_NUMBER:-}/artifacts"
    S3_TAG_ARTIFACT_PATH="${S3_ARTIFACT_BASE}/tag/${UPSTREAM_TAG}/artifacts"

    local COMMAND="${1}"
    shift

    case "${COMMAND}" in
        build) build "${@}" ;;
    esac
}

build() {
    local RELEASE_NUM="${1:-1}"

    test -d artifacts || mkdir artifacts

    if [[ "${BUILD_TYPE}" == "release" ]] ; then
        aws s3 sync --delete "${S3_TAG_ARTIFACT_PATH}" upstream-artifacts
    else
        aws s3 sync --delete "${S3_BUILD_ARTIFACT_PATH}" upstream-artifacts
    fi

    aws s3 sync --delete "${S3_CI_RESOURCES}" ci-resources

    PATTERN="upstream-artifacts/**/*.war"
    WARS=( $PATTERN )
    cp "${WARS[@]}" artifacts/

    ./gradlew -PpackageRelease=$RELEASE_NUM clean packageArtifacts
}

(
    cd $DIR/..
    main "${@}"
)