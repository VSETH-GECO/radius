#!/usr/bin/env bash

echo "Loading static clients"

cat >/etc/freeradius/clients.conf <<EOF

# testing
client dockernet {
	ipaddr = 127.0.0.1/8
	secret = testing123
}

EOF

exit 0
