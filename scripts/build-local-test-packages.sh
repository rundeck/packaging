#!/bin/bash
# Build real .rpm/.deb packages locally from buildSrc/PackagingTask.groovy,
# using a disposable dummy WAR + libsDir fixture - no real Rundeck/RundeckPro
# WAR, no signing keys, no network access to packages.rundeck.com required.
#
# Useful for iterating on package dependency declarations (e.g. the Java
# 17/21/25 `requires()` logic) without needing a full Rundeck build.
#
# Usage: ./scripts/build-local-test-packages.sh [version] [date]
#   version defaults to 6.0.1, date defaults to today (YYYYMMDD)
#
# Output: build/distributions/rundeckpro-enterprise-<version>.<date>-1.noarch.rpm
#         build/distributions/rundeckpro-enterprise_<version>.<date>-1_all.deb

set -euo pipefail

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )/.." >/dev/null && pwd )"
cd "$DIR"

VERSION="${1:-6.0.1}"
DATE="${2:-$(date +%Y%m%d)}"
FIXTURE_DIR="$DIR/.local-test-fixture"
WAR_NAME="rundeckpro-enterprise-${VERSION}-${DATE}.war"

echo "==> Setting up disposable fixture ($FIXTURE_DIR)"
rm -rf "$FIXTURE_DIR"
mkdir -p \
  "$FIXTURE_DIR/libsDir/common/etc/rundeck" \
  "$FIXTURE_DIR/libsDir/rpm/etc/rundeck" \
  "$FIXTURE_DIR/libsDir/rpm/etc/rc.d/init.d" \
  "$FIXTURE_DIR/libsDir/rpm/scripts" \
  "$FIXTURE_DIR/libsDir/deb/etc/rundeck" \
  "$FIXTURE_DIR/libsDir/deb/scripts" \
  "$FIXTURE_DIR/warstage" \
  "$DIR/artifacts"

echo "placeholder=true" > "$FIXTURE_DIR/libsDir/common/etc/rundeck/dummy.properties"
echo "placeholder=true" > "$FIXTURE_DIR/libsDir/rpm/etc/rundeck/dummy-rpm.properties"
printf '#!/bin/sh\nexit 0\n' > "$FIXTURE_DIR/libsDir/rpm/etc/rc.d/init.d/rundeckd"
for f in preinst postinst postinst-cluster preuninst postuninst; do
  printf '#!/bin/sh\nexit 0\n' > "$FIXTURE_DIR/libsDir/rpm/scripts/${f}.sh"
done
echo "placeholder=true" > "$FIXTURE_DIR/libsDir/deb/etc/rundeck/dummy-deb.conf"
for f in postinst postinst-cluster postrm; do
  printf '#!/bin/sh\nexit 0\n' > "$FIXTURE_DIR/libsDir/deb/scripts/${f}"
done

# Any valid zip works - PackageTask only unzips it, never reads real content.
touch "$FIXTURE_DIR/warstage/placeholder.txt"
(cd "$FIXTURE_DIR/warstage" && zip -q "$DIR/artifacts/${WAR_NAME}" placeholder.txt)

echo "==> Building rundeckpro-enterprise-${VERSION}.${DATE} rpm + deb"
./gradlew build-rundeckpro-enterprise-rpm build-rundeckpro-enterprise-deb \
  -PlibsDir="$FIXTURE_DIR/libsDir"

echo ""
echo "==> Built packages:"
ls -la build/distributions/*.rpm build/distributions/*.deb 2>/dev/null

echo ""
echo "Next: ./scripts/test-local-package-install.sh rockylinux/rockylinux:10 java-25-openjdk-headless"
