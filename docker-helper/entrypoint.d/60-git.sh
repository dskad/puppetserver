#!/usr/bin/bash

# *** Add custom CA certs for git over https from environment variables CA_CERT1, CA_CERT2, etc
# ***************************************************************************

compgen -A variable | grep '^CA_CERT\n*' | while read cacert
do
  echo "${!cacert}" > /etc/puppetlabs/git/ca/${cacert}.pem
done