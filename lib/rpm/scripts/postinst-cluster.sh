#!/bin/sh

DIR=/etc/rundeck
RDECK_CONFIG="$DIR/rundeck-config.properties"

if [ -f "$DIR/rundeck-config.properties.rpmnew" ]; then
    RDECK_CONFIG="$DIR/rundeck-config.properties.rpmnew"
fi

# enabling cluster mode
cat >> "$RDECK_CONFIG" <<END

rundeck.clusterMode.enabled=true
END