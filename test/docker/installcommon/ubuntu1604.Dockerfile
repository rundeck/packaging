FROM rundeck/ubuntu-base:latest

# Grails 7: Ubuntu 22.04 base image includes Java 17 by default
# No additional Java installation needed

COPY --chown=rundeck:root scripts/rd-util.sh /rd-util.sh
ADD --chown=rundeck:root scripts/deb-tests.sh /init-tests.sh
