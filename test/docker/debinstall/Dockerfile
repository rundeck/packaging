FROM rdpro-ubuntu2204-util:latest

USER root

# dpkg -i (used by entry.sh) doesn't auto-resolve dependencies like apt-get
# does, so the package's real deps (openssh-client, uuid-runtime; adduser and
# openssl already ship in the ubuntu:22.04 base) must be pre-installed here -
# mirrors how the rpm side pre-installs initscripts/openssh/openssl before
# `rpm -ivh`.
RUN apt-get update && \
    apt-get install -y openssh-client uuid-runtime && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

ENV USERNAME=rundeck \
    USER=rundeck \
    HOME=/home/rundeck \
    LOGNAME=$USERNAME \
    TERM=xterm-256color

COPY --chown=rundeck:root entry.sh /entry.sh
RUN chmod +x /entry.sh
VOLUME $HOME/rundeck
WORKDIR $HOME/rundeck

EXPOSE 4440
ENTRYPOINT ["/entry.sh"]
