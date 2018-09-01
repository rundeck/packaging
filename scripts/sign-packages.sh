#!/usr/bin/env bash
#/ Sign the RPMs in the dist dir ...
#/ usage: [dist dir]

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null && pwd )"

set -euo pipefail
IFS=$'\n\t'
readonly ARGS=("$@")

DIST_DIR=${ARGS[0]:-build/distributions}
KEYID=${SIGNING_KEYID:-}
PASSWORD=${SIGNING_PASSWORD:-}
GPG_PATH=${GPG_PATH:-./ci-resources}


usage() {
      grep '^#/' <"$0" | cut -c4- # prints the #/ lines above as usage info
}
die(){
    echo >&2 "$@" ; exit 2
}

check_env(){
    if test -z "$KEYID"; then
        die "ENV var SIGNING_KEYID was not set"
    fi
    if test -z "$PASSWORD"; then
        die "ENV var SIGNING_PASSWORD was not set"
    fi
    if test -z "$GPG_PATH"; then
        die "ENV var GPG_PATH was not set"
    fi
    
    which gpg || die "gpg not found"
    which rpm || die "rpm not found"
    which expect || die "expect not found"

}
list_rpms(){
    local FARGS=("$@")
    local DIR=${FARGS[0]}
    local PATTERN="${DIR}/*.rpm"
    echo $PATTERN
}

list_debs(){
    local FARGS=("$@")
    local DIR=${FARGS[0]}
    local PATTERN="${DIR}/*.deb"
    echo $PATTERN
}

sign_rpms(){
    local RPMS=$(list_rpms $DIST_DIR)
    echo "=======RPMS======="
    echo $RPMS
    export GNUPGHOME=$GPG_PATH
    expect - -- $GPG_PATH $SIGNING_KEYID $SIGNING_PASSWORD  <<END
spawn rpm --define "_gpg_name [lindex \$argv 1]" --define "_gpg_path [lindex \$argv 0]" --define "__gpg_sign_cmd %{__gpg} gpg --force-v3-sigs --digest-algo=sha1 --batch --no-verbose --passphrase-fd 3 --no-secmem-warning -u \"%{_gpg_name}\" -sbo %{__signature_filename} %{__plaintext_filename}" --addsign $RPMS
expect {
    -re "Enter pass *phrase: *" { log_user 0; send -- "[lindex \$argv 2]\r"; log_user 1; }
    eof { catch wait rc; exit [lindex \$rc 3]; }
    timeout { close; exit; }
}
expect {
eof { catch wait rc; exit [lindex \$rc 3]; }
timeout close
}
END
}

sign_debs(){
    local DEBS=$(list_debs $DIST_DIR)
    expect - -- $GPG_PATH $SIGNING_KEYID $SIGNING_PASSWORD  <<END
spawn dpkg-sig --gpg-options "-u [lindex \$argv 1] --secret-keyring ci-resources/secring.gpg" --sign builder $DEBS
set timeout 60
expect {
    "Enter passphrase:" { log_user 0; send -- "[lindex \$argv 2]\r"; log_user 1; exp_continue }
    eof { catch wait rc; exit [lindex \$rc 3]; }
    timeout { puts "Timed out!"; exit 1 }
}
END
}

main() {
    check_env
    sign_rpms
    sign_debs
}

(
    cd $DIR/..
    main
)