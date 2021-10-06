#!/usr/bin/env bash
#/ helpers

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null && pwd )"

set -euo pipefail
IFS=$'\n\t'
readonly ARGS=("$@")

DIST_DIR=${ARGS[0]:-build/distributions}
ARTIFACTS_DIR=${ARTIFACTS_DIR:-./artifacts}
KEYID=${SIGNING_KEYID:-}
PASSWORD=${SIGNING_PASSWORD:-}
GPG_PATH=${GPG_PATH:-./ci-resources}
SIGNING_KEY_B64=${SIGNING_KEY_B64:-}

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
check_key(){
  if [ -n "${SIGNING_KEY_B64}" ] ; then
    echo "${SIGNING_KEY_B64}" | base64 -d | GNUPGHOME="$GPG_PATH" gpg --import --batch
  fi
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

list_wars(){
    local FARGS=("$@")
    local DIR=${FARGS[0]}
    local PATTERN="${DIR}/*.war"
    echo $PATTERN
}

sign_rpms(){
    local RPMS=$(list_rpms $DIST_DIR)
    echo "=======RPMS======="
    echo $RPMS
    export GNUPGHOME=$GPG_PATH
    expect - -- $GPG_PATH $KEYID $PASSWORD  <<END
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

#/ isgpg2 detects gpg v 2
isgpg2(){
    gpg --version | grep 'gpg (GnuPG) 2' -q
}

#/ sign_rpms_gpg2 works with gpg v2
sign_rpms_gpg2(){
    local RPMS=$(list_rpms $DIST_DIR)
    echo "=======RPMS======="
    echo $RPMS
    export GNUPGHOME=$GPG_PATH
    expect - -- $GPG_PATH $KEYID $PASSWORD  <<END
spawn rpm --define "_gpg_name [lindex \$argv 1]" --define "_gpg_path [lindex \$argv 0]" --define "__gpg_sign_cmd %{__gpg} gpg --force-v3-sigs --digest-algo=sha1 --no-verbose --pinentry-mode loopback --no-secmem-warning -u \"%{_gpg_name}\" -sbo %{__signature_filename} %{__plaintext_filename}" --addsign $RPMS
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
    echo "=======DEBS======="
    echo $DEBS
    expect - -- $GPG_PATH $KEYID $PASSWORD  <<END
spawn dpkg-sig --gpg-options "-u [lindex \$argv 1] --secret-keyring [lindex \$argv 0]/secring.gpg" --sign builder $DEBS
set timeout 60
expect {
    # Passphrase prompt arrives for each deb signed; exp_continue allows this block to execute multiple times
    "Enter passphrase:" { log_user 0; send -- "[lindex \$argv 2]\r"; log_user 1; exp_continue }
    eof { catch wait rc; exit [lindex \$rc 3]; }
    timeout { puts "Timed out!"; exit 1 }
}
END
}

sign_wars() {
    local WARS=$(list_wars $ARTIFACTS_DIR)

    IFS=' '
    for WAR in $WARS; do
        gpg -u "${KEYID}" \
            --secret-keyring "${GPG_PATH}/secring.gpg" \
            --armor \
            --passphrase-fd 0 \
            --detach-sign "${WAR}" <<< "${PASSWORD}"
    done
    IFS=$'\n\t'
}

export -f check_env
export -f check_key
export -f sign_wars
export -f sign_debs
export -f sign_rpms
export -f isgpg2
export -f sign_rpms_gpg2
