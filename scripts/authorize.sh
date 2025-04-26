#!/usr/bin/env bash

echo "Loading static users"

cat >/etc/freeradius/mods-config/files/authorize <<EOF

# testing
bob	Cleartext-Password := "test"

EOF

exit 0
