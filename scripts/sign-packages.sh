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
    sign_rpms
    #sign_debs
    sign_wars
}

(
    cd "$DIR/.." || exit 1
    main
)
