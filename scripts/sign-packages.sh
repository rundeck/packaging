#!/usr/bin/env bash
#/ Sign the RPMs in the dist dir ...
#/ usage: [dist dir]

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null && pwd )"

# shellcheck source=signing-helpers.sh
source "$DIR/signing-helpers.sh"

if [[ -z "$PASSWORD" ]] ; then
    echo -n 'Enter signing key password passphrase:'
    read -r -s PASSWORD
fi


main() {

   check_env
   if isgpg2; then
      echo "gpg v2 detected"
      sign_rpms_gpg2
      sign_debs_gpg2
      sign_wars_gpg2
    else
      echo "gpg v2 not detected"
      sign_rpms
      sign_debs
      sign_wars
    fi
}
}

(
    cd "$DIR/.." || exit 1
    main
)
