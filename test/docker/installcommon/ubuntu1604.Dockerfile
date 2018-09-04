FROM rundeck/ubuntu-base@sha256:7057294fad2e341ea2582acf0a4d26fc66d7e1cf8d875f4207d3377f4b9fbd9f

COPY --chown=rundeck:rundeck scripts/rd-util.sh /rd-util.sh
ADD --chown=rundeck:rundeck scripts/deb-tests.sh /init-tests.sh