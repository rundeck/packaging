#!/bin/bash

REPO="${1:?Must supply repo as arg0}"

unknown_os ()
{
  echo "Unfortunately, your operating system distribution and version are not supported by this script."
  exit 1
}

curl_check ()
{
  echo "Checking for curl..."
  if command -v curl > /dev/null; then
    echo "Detected curl..."
  else
    echo "Installing curl..."
    yum install -d0 -e0 -y curl
  fi
}


detect_os ()
{
  if [[ ( -z "${os}" ) && ( -z "${dist}" ) ]]; then
    if [ -e /etc/os-release ]; then
      . /etc/os-release
      os=${ID}
      if [ "${os}" = "poky" ]; then
        dist="${VERSION_ID}"
      elif [ "${os}" = "sles" ]; then
        dist="${VERSION_ID}"
      elif [ "${os}" = "opensuse" ]; then
        dist="${VERSION_ID}"
      elif [ "${os}" = "opensuse-leap" ]; then
        os=opensuse
        dist="${VERSION_ID}"
      else
        dist=$(echo ${VERSION_ID} | awk -F '.' '{ print $1 }')
      fi

    elif [ "$(which lsb_release 2>/dev/null)" ]; then
      # get major version (e.g. '5' or '6')
      dist=$(lsb_release -r | cut -f2 | awk -F '.' '{ print $1 }')

      # get os (e.g. 'centos', 'redhatenterpriseserver', etc)
      os=$(lsb_release -i | cut -f2 | awk '{ print tolower($1) }')

    elif [ -e /etc/oracle-release ]; then
      dist=$(cut -f5 --delimiter=' ' /etc/oracle-release | awk -F '.' '{ print $1 }')
      os='ol'

    elif [ -e /etc/fedora-release ]; then
      dist=$(cut -f3 --delimiter=' ' /etc/fedora-release)
      os='fedora'

    elif [ -e /etc/redhat-release ]; then
      os_hint=$(cat /etc/redhat-release  | awk '{ print tolower($1) }')
      if [ "${os_hint}" = "centos" ]; then
        dist=$(cat /etc/redhat-release | awk '{ print $3 }' | awk -F '.' '{ print $1 }')
        os='centos'
      elif [ "${os_hint}" = "scientific" ]; then
        dist=$(cat /etc/redhat-release | awk '{ print $4 }' | awk -F '.' '{ print $1 }')
        os='scientific'
      else
        dist=$(cat /etc/redhat-release  | awk '{ print tolower($7) }' | cut -f1 --delimiter='.')
        os='redhatenterpriseserver'
      fi

    else
      grep -q Amazon /etc/issue
      if [ "$?" = "0" ]; then
        dist='6'
        os='aws'
      else
        unknown_os
      fi
    fi
  fi

  if [[ ( -z "${os}" ) || ( -z "${dist}" ) ]]; then
    unknown_os
  fi

  # remove whitespace from OS and dist name
  os="${os// /}"
  dist="${dist// /}"

  echo "Detected operating system as ${os}/${dist}."

  if [ "${dist}" = "8" ]; then
    _skip_pygpgme=1
  else
    _skip_pygpgme=0
  fi
}

finalize_yum_repo ()
{
  if [ "$_skip_pygpgme" = 0 ]; then
    echo "Installing pygpgme to verify GPG signatures..."
    yum install -y pygpgme --disablerepo="${REPO}"

    rpm -qa | grep -qw pygpgme
    if [ "$?" != "0" ]; then
      echo
      echo "WARNING: "
      echo "The pygpgme package could not be installed. This means GPG verification is not possible for any RPM installed on your system. "
      echo "To fix this, add a repository with pygpgme. Usualy, the EPEL repository for your system will have this. "
      echo "More information: https://fedoraproject.org/wiki/EPEL#How_can_I_use_these_extra_packages.3F"
      echo

      # set the repo_gpgcheck option to 0
      sed -i'' 's/repo_gpgcheck=1/repo_gpgcheck=0/' /etc/yum.repos.d/pagerduty_rundeck.repo
    fi
  fi

  echo "Installing yum-utils..."
  yum install -y yum-utils --disablerepo="${REPO}"
  
  rpm -qa | grep -qw yum-utils
  if [ "$?" != "0" ]; then
    echo
    echo "WARNING: "
    echo "The yum-utils package could not be installed. This means you may not be able to install source RPMs or use other yum features."
    echo
  fi

  echo "Generating yum cache for ${REPO}..."
  yum -q makecache -y --disablerepo='*' --enablerepo="${REPO}"
}

finalize_zypper_repo ()
{
  zypper --gpg-auto-import-keys refresh pagerduty_rundeck
  zypper --gpg-auto-import-keys refresh pagerduty_rundeck-source
}

main ()
{
  detect_os
  curl_check

  if [ "${os}" = "sles" ] || [ "${os}" = "opensuse" ]; then
    yum_repo_base_path=/etc/zypp/repos.d
  else
    yum_repo_base_path=/etc/yum.repos.d
  fi
  yum_repo_path="${yum_repo_base_path}/rundeck.repo"

  legacy_yum_repo="${yum_repo_base_path}/bintray-rundeckpro-rpm.repo"
  if [ -f "${legacy_yum_repo}" ]; then
    echo "Cleaning up legacy yum repo [${legacy_yum_repo}]..."
    rm "${legacy_yum_repo}"
  fi

    yum_repo_source=$(cat << EOF
[${REPO}]
name=${REPO}
baseurl=https://packages.rundeck.com/pagerduty/${REPO}/rpm_any/rpm_any/\$basearch
repo_gpgcheck=1
gpgcheck=0
enabled=1
gpgkey=https://packages.rundeck.com/pagerduty/${REPO}/gpgkey
sslverify=1
sslcacert=/etc/pki/tls/certs/ca-bundle.crt
metadata_expire=300
EOF
)

  echo "${yum_repo_source}" > "${yum_repo_path}"

  if [ "${os}" = "sles" ] || [ "${os}" = "opensuse" ]; then
    finalize_zypper_repo
  else
    finalize_yum_repo
  fi

  echo
  echo "The repository is setup! You can now install packages."
}

main
