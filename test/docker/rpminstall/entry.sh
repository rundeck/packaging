#!/bin/bash
. /rd-util.sh

set -e

FLAV=${EDITION:-cluster}
DIR=$HOME/rundeck/build/distributions


install_rundeck(){

	if ! find "$DIR"/ -name "rundeckpro-$FLAV*.rpm" ; then
		echo "rpm not found at $DIR/rundeckpro-$FLAV*.rpm"
		exit 2
	fi

	echo "Install Rundeck Pro $FLAV from file: " "$DIR"/rundeckpro-"$FLAV"*.rpm 
	rpm -ivh "$DIR"/rundeckpro-"$FLAV"*.rpm 
}

main(){
	install_rundeck
	cp_license
	echo_config
	entry_start "$@"
}


main "$@"