#!/bin/bash
# This script does a basic check to see if the puppetdb server is up by checking
#  to see if the port is open. If the port is open, puppetdb should be ready
#  (or soon will be) to accept traffic.
#
# If puppetdb.conf is present (with the server_urls setting), server and port is
#  used from there, otherwise the environment var are used (PUPPETDB_SERVER, PUPPETDB_PORT)

# Hard coding this because it's always going to be the same in the container.
#  Using "puppet config print confdir" slows down facter by 1s+
confdir="/etc/puppetlabs/puppet"

# safety net in case these variables aren't set and puppetdb isn't configured
if [ -v PUPPETDB_SERVER ]; then
  server_name=$PUPPETDB_SERVER
else
  server_name=localhost
fi

if [ -v PUPPETDB_PORT ]; then
  port_num=$PUPPETDB_PORT
else
  port_num=8081
fi

# if puppetdb is configured, use that as the server and port
if [ -f $confdir/puppetdb.conf ]; then
  read server_name port_num <<< \
    $(sed -r -n -e \
      's#^server_urls\s*=\s*https?:\/\/(.+):([[:alnum:].-]+)?.*#\1 \2#ip' \
      ${confdir}/puppetdb.conf \
    )
fi

# check to see if the $server has $port open using bash net redirection
(echo > /dev/tcp/${server_name}/${port_num}) >/dev/null 2>&1
if [ "$?" = 0 ]; then
  echo "puppetdb_up=true"
else
  echo "puppetdb_up=false"
fi

echo "puppetdb_server=${server_name}"
echo "puppetdb_port=${port_num}"
