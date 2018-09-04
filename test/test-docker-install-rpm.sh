#!/bin/bash

LDIR=$( cd $(dirname $0) ; echo $PWD )
export DIR=test/docker/rpminstall
export COMMON="centos6"
export PACKAGE_TYPE="rpm"

. "$LDIR/test-docker-install-common.sh"

build
run