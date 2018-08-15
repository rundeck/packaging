#!/bin/sh

#Set owner on dirs
chown -R rundeck:rundeck /var/lib/rundeck /var/rundeck /etc/rundeck /var/log/rundeck /tmp/rundeck

if [ ! -e ~rundeck/.ssh/id_rsa ]; then
	su -c "ssh-keygen -q -t rsa -C '' -N '' -f ~rundeck/.ssh/id_rsa" rundeck
fi
/sbin/chkconfig --add rundeckd

DIR=/etc/rundeck

RDECK_CONFIG="$DIR/rundeck-config.properties"
FW_CONFIG="$DIR/framework.properties"

if [ -f "$DIR/rundeck-config.properties.rpmnew" ]; then
    RDECK_CONFIG="$DIR/rundeck-config.properties.rpmnew"
fi

if [ -f "$DIR/framework.properties.rpmnew" ]; then
    FW_CONFIG="$DIR/framework.properties.rpmnew"
fi

if  ! grep -E '^\s*rundeck.server.uuid\s*=\s*.{8}-.{4}-.{4}-.{4}-.{12}\s*$' "$FW_CONFIG" ; then
    uuid=$(uuidgen)
    echo -e "\n# ----------------------------------------------------------------" >> "$FW_CONFIG"
    echo "# Auto generated server UUID: $uuid" >> "$FW_CONFIG"
    echo "# ----------------------------------------------------------------" >> "$FW_CONFIG"
    echo "rundeck.server.uuid = $uuid" >> "$FW_CONFIG"
fi

#setting a random password for encryption
STORAGE_PASS=$(openssl rand -hex 8)
sed -i -E 's/^rundeck\.storage\.converter\.([0-9]+)\.config\.password=default\.encryption\.password$/rundeck.storage.converter.\1.config.password='"$STORAGE_PASS"'/' "$RDECK_CONFIG"
sed -i -E 's/^rundeck\.config\.storage\.converter\.([0-9]+)\.config\.password=default\.encryption\.password$/rundeck.config.storage.converter.\1.config.password='"$STORAGE_PASS"'/' "$RDECK_CONFIG"
