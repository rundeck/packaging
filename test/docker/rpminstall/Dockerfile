# original https://hub.docker.com/r/bwits/rundeck-build/
FROM rdpro-centos7-util:latest
RUN rpm -Uvh  https://dl.fedoraproject.org/pub/epel/epel-release-latest-7.noarch.rpm
RUN yum -y update
RUN yum -y install java-11-openjdk java-11-openjdk-devel initscripts openssh openssl
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
