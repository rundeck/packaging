#!/usr/bin/expect

import_gpg(){
  spawn gpg --import "$GPG_PATH"/secring.gpg
  expect "Please enter the passphrase to import the OpenPGP secret key:"
  send "$PASSWORD"
}

export -f import_gpg
