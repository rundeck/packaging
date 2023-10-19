#!/usr/bin/env bash
#/ helpers

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null && pwd )"

set -euo pipefail
IFS=$'\n\t'
readonly ARGS=("$@")

DIST_DIR=${ARGS[0]:-build/distributions}
ARTIFACTS_DIR=${ARTIFACTS_DIR:-./artifacts}
KEYID=${RUNDECK_SIGNING_KEYID:-}
PASSWORD=${RUNDECK_SIGNING_PASSWORD:-}
GPG_PATH=${GPG_PATH:-~/.gnupg}
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
        die "ENV var RUNDECK_SIGNING_PASSWORD was not set"
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

    for RPM in $RPMS; do
        PRERPMSHA=$(sha256sum $RPM)
        echo -------Pre sig rpm sha---------
        echo "$PRERPMSHA for artifact: $RPM"

    echo "=======Post import RPM======="

    expect - -- $GPG_PATH $KEYID $PASSWORD  <<END
spawn rpm --define "_gpg_name [lindex \$argv 1]" --define "_gpg_path [lindex \$argv 0]" --define "__gpg_sign_cmd %{__gpg} gpg --force-v3-sigs --digest-algo sha256 --batch --no-verbose --passphrase-fd 3 --no-secmem-warning -u \"%{_gpg_name}\" -sbo %{__signature_filename} %{__plaintext_filename}" --addsign $RPM
expect {
    -re "Enter pass *phrase: *" { log_user 0; send -- "[lindex \$argv 2]\r"; log_user 1; }
    eof { catch wait rc; exit [lindex \$rc 3]; }
    timeout { close; exit 1; }
}
expect {
    eof { catch wait rc; exit [lindex \$rc 3]; }
    timeout {close; exit 1;}
}
END

        POSTRPMSHA=$(sha256sum $RPM)
        echo -------post sig rpm sha---------
        echo "$POSTRPMSHA for artifact: $RPM"
        if [ "$PRERPMSHA" = "$POSTRPMSHA" ] ; then
              echo "FAILURE: Signature was not performed: the pre and post SHA are the same"
              exit 2
        fi
    done
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

    for RPM in $RPMS; do
        PRERPMSHA=$(sha256sum $RPM)
        echo -------Pre sig rpm sha---------
        echo "$PRERPMSHA for artifact: $RPM"

    #export GNUPGHOME=$GPG_PATH
    expect - -- $GPG_PATH $KEYID $PASSWORD  <<END
spawn rpm --define "_gpg_name [lindex \$argv 1]" --define "_gpg_path [lindex \$argv 0]" --define "__gpg_sign_cmd %{__gpg} gpg --force-v3-sigs --digest-algo sha256 --no-verbose --pinentry-mode loopback --no-secmem-warning -u \"%{_gpg_name}\" -sbo %{__signature_filename} %{__plaintext_filename}" --addsign $RPM
expect {
    -re "Enter pass *phrase: *" { log_user 0; send -- "[lindex \$argv 2]\r"; log_user 1; }
    eof { catch wait rc; exit [lindex \$rc 3]; }
    timeout {close; exit 1;}
}
expect {
    eof { catch wait rc; exit [lindex \$rc 3]; }
    timeout {close; exit 1;}
}
END

        POSTRPMSHA=$(sha256sum $RPM)
        echo -------post sig rpm sha---------
        echo "$POSTRPMSHA for artifact: $RPM"
        if [ "$PRERPMSHA" = "$POSTRPMSHA" ] ; then
              echo "FAILURE: Signature was not performed: the pre and post SHA are the same"
              exit 2
        fi
    done

}

sign_debs(){
    local DEBS=$(list_debs $DIST_DIR)
    echo "=======DEBS======="
    echo "$DEBS"

    for DEB in $DEBS; do
        PREDEBSHA=$(sha256sum $DEB)
        echo -------Pre sig sha---------
        echo "$PREDEBSHA for artifact: $DEB"


    if tty ; then
        GPG_TTY=$(tty)
        export GPG_TTY
    fi

    expect - -- $GPG_PATH $KEYID $PASSWORD  <<END
spawn dpkg-sig --gpg-options "-u [lindex \$argv 1] --secret-keyring [lindex \$argv 0]/secring.gpg" --sign builder $DEB
set timeout 60
expect {
    # Passphrase prompt arrives for each deb signed; exp_continue allows this block to execute multiple times
    "Enter passphrase:" { log_user 0; send -- "[lindex \$argv 2]\r"; log_user 1; exp_continue }
    eof { catch wait rc; exit [lindex \$rc 3]; }
    timeout { puts "Timed out!"; exit 1 }
}
END

        POSTDEBSHA=$(sha256sum $DEB)
        echo -------Post sig sha---------
        echo "$POSTDEBSHA for artifact: $DEB"
        if [ "$PREDEBSHA" = "$POSTDEBSHA" ] ; then
              echo "FAILURE: Signature was not performed: the pre and post SHA are the same"
              exit 2
        fi
    done
}

sign_debs_gpg2(){
    local DEBS=$(list_debs $DIST_DIR)
    echo "=======DEBS======="
    echo "$DEBS"

    for DEB in $DEBS; do
        PREDEBSHA=$(sha256sum $DEB)
        echo -------Pre sig sha---------
        echo "$PREDEBSHA for artifact: $DEB"

    if tty ; then
        GPG_TTY=$(tty)
        export GPG_TTY
    fi

    expect - -- $KEYID $PASSWORD  <<END
spawn dpkg-sig --gpg-options "-u [lindex \$argv 0] --pinentry-mode loopback" --sign builder $DEB
expect {
    # Passphrase prompt arrives for each deb signed; exp_continue allows this block to execute multiple times
    "Enter passphrase:" { log_user 0; send -- "[lindex \$argv 1]\r"; log_user 1; exp_continue }
    eof { catch wait rc; exit [lindex \$rc 3]; }
    timeout { puts "Timed out!"; exit 1 }
}
END

        POSTDEBSHA=$(sha256sum $DEB)
        echo -------Post sig sha---------
        echo "$POSTDEBSHA for artifact: $DEB"
        if [ "$PREDEBSHA" = "$POSTDEBSHA" ] ; then
              echo "FAILURE: Signature was not performed: the pre and post SHA are the same"
              exit 2
        fi
    done
}

sign_wars() {
    local WARS=$(list_wars $ARTIFACTS_DIR)
    echo "=======WARS======="



    IFS=' '
    for WAR in $WARS; do
        gpg -u "${KEYID}" \
            --secret-keyring "${GPG_PATH}/secring.gpg" \
            --armor \
            --passphrase-fd 0 \
            --detach-sign "${WAR}" <<< "${PASSWORD}"
    done

    for WAR in $WARS; do
        if [ ! -f "${WAR}.asc" ] ; then
              echo "FAILURE: Signature was not performed: the detached signature for $WAR was not found: ${WAR}.asc"
              exit 2
        fi
    done
    IFS=$'\n\t'
}

sign_wars_gpg2() {
    local WARS=$(list_wars $ARTIFACTS_DIR)
    echo "=======WARS======="

    IFS=' '
    for WAR in $WARS; do
        gpg -u "${KEYID}" \
            --armor \
            --batch \
            --pinentry-mode loopback \
            --detach-sign "${WAR}" <<< "${PASSWORD}"
    done

    for WAR in $WARS; do
        if [ ! -f "${WAR}.asc" ] ; then
              echo "FAILURE: Signature was not performed: the detached signature for $WAR was not found: ${WAR}.asc"
              exit 2
        fi
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
export -f sign_wars_gpg2
export -f sign_debs_gpg2
