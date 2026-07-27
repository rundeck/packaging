#!/bin/bash
# Install the locally-built rundeckpro-enterprise .rpm or .deb (from
# build/distributions, see build-local-test-packages.sh) into a disposable
# container to prove it actually resolves/installs, without needing to
# rebuild the full docker-compose test environments under docker/.
#
# Usage:
#   ./scripts/test-local-package-install.sh <base-image> <java-package> [rpm|deb]
#
# Examples:
#   ./scripts/test-local-package-install.sh rockylinux/rockylinux:9  java-17-openjdk               rpm
#   ./scripts/test-local-package-install.sh rockylinux/rockylinux:10 java-21-openjdk-headless      rpm
#   ./scripts/test-local-package-install.sh rockylinux/rockylinux:10 java-25-openjdk-headless      rpm
#   ./scripts/test-local-package-install.sh debian:trixie            openjdk-21-jre-headless       deb
#   ./scripts/test-local-package-install.sh debian:trixie            openjdk-25-jre-headless       deb

set -euo pipefail

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )/.." >/dev/null && pwd )"
cd "$DIR"

IMAGE="${1:?usage: $0 <base-image> <java-package> [rpm|deb]}"
JAVA_PKG="${2:?usage: $0 <base-image> <java-package> [rpm|deb]}"
TYPE="${3:-rpm}"

if [ ! -d "$DIR/build/distributions" ]; then
  echo "No build/distributions found - run ./scripts/build-local-test-packages.sh first." >&2
  exit 1
fi

if [ "$TYPE" = "rpm" ]; then
  docker run --rm -v "$DIR/build/distributions:/repo:ro" "$IMAGE" bash -c "
    set -e
    dnf -y install ${JAVA_PKG}
    echo '=== installing local rpm ==='
    dnf -y install /repo/rundeckpro-enterprise-*.noarch.rpm
    echo '=== installed ==='
    rpm -q rundeckpro-enterprise
  "
elif [ "$TYPE" = "deb" ]; then
  docker run --rm -v "$DIR/build/distributions:/repo:ro" "$IMAGE" bash -c "
    set -e
    apt-get update -qq
    apt-get install -y -qq ${JAVA_PKG}
    echo '=== installing local deb ==='
    apt-get install -y /repo/rundeckpro-enterprise_*.deb
    echo '=== installed ==='
    dpkg -l rundeckpro-enterprise
  "
else
  echo "Unknown type '$TYPE' - expected 'rpm' or 'deb'" >&2
  exit 1
fi
