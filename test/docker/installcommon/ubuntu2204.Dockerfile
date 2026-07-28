FROM ubuntu:22.04

# Grails 7: Install Java 17 for Rundeck runtime (Rundeck 6.0 supports Java 17-25).
# Switched from the external rundeck/ubuntu-base:latest image (stuck on Ubuntu
# 20.04.3, with an unresolved TODO to rebuild it for 22.04) to the stock public
# ubuntu:22.04 image, matching the documented minimum supported version.
RUN apt-get update && \
    apt-get install -y openjdk-17-jre-headless && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# rundeck/ubuntu-base:latest used to provide this user; now created explicitly.
RUN useradd -m -d /home/rundeck rundeck

USER rundeck
COPY --chown=rundeck:root scripts/rd-util.sh /rd-util.sh
ADD --chown=rundeck:root scripts/deb-tests.sh /init-tests.sh
