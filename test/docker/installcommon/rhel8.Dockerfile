FROM registry.access.redhat.com/ubi8/ubi

ADD scripts/rd-util.sh /rd-util.sh
ADD scripts/rpm-tests.sh /init-tests.sh