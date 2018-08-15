#!/bin/sh

getent group rundeck >/dev/null || groupadd rundeck
getent passwd rundeck >/dev/null || useradd -d /var/lib/rundeck -m -g rundeck rundeck
