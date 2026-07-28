# original https://hub.docker.com/r/bwits/rundeck-build/
FROM rdpro-rhel8-util:latest
RUN dnf -y update
# Grails 7: Java 17 required (Rundeck 6.0 supports Java 17-25; UBI8 already
# provides chkconfig/initscripts/openssh/openssl via BaseOS/AppStream, no EPEL needed)
RUN dnf -y install java-17-openjdk java-17-openjdk-devel initscripts openssh openssl
RUN useradd rundeck
#USER rundeck

ENV USERNAME=rundeck \
    USER=rundeck \
    HOME=/home/rundeck \
    LOGNAME=$USERNAME \
    TERM=xterm-256color

ENV EDITION=$EDITION
ENV JAVA_HOME=/etc/alternatives/java_sdk

ADD entry.sh /entry.sh
RUN chmod +x /entry.sh

VOLUME $HOME/rundeck
WORKDIR $HOME/rundeck


EXPOSE 4440
ENTRYPOINT ["/entry.sh"]
