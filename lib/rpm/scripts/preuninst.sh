#!/bin/sh

if [ "$1" = 0 ]; then
    /sbin/service rundeckd stop
    /sbin/chkconfig --del rundeckd
fi
