#!/bin/bash

LDIR=$( cd $(dirname $0) ; echo $PWD )
export DIR=test/docker/debinstall
export COMMON="ubuntu2204"
export PACKAGE_TYPE="deb"

. "$LDIR/test-docker-install-common.sh"

build
run