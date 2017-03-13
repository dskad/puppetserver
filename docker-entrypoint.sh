#!/bin/bash
## unoficial "strict mode" http://redsymbol.net/articles/unofficial-bash-strict-mode/
## with modification, we want unbound variables to allow extra runtime configs
set -eo pipefail
if [ -v DEBUG ]; then
  set -x
fi

# IFS=$'\n\t'

if [ $1 = "puppetserver" ]; then
  if [ -v IMPORT_SELFSIGNED_URL ]; then
  :
#  FIXME
#    openssl s_client -connect $IMPORT_SELFSIGNED_URL:443 <<<'' | openssl x509 -out /etc/pki/ca-trust/source/anchors/$IMPORT_SELFSIGNED_URL.pem
#    update-ca-trust
  fi

  # Generate SSH key pair for R10k if it doesn't exist
  if [[ ! -f  /etc/puppetlabs/r10k/.ssh/id_rsa ]]; then
    ssh-keygen -b 4096 -f /etc/puppetlabs/r10k/.ssh/id_rsa -t rsa -N ""
  fi

  ## This script runs before systemd init and is good for initialization or pre-startup tasks
  ## Only initialize and setup the environments (via r10k) if server is launching
  ##    for the first time (i.e. new server container). We don't want to unintentionally
  ##    upgrade an environment or break certs on a container restart or upgrade.
  if [ ! -d  /etc/puppetlabs/puppet/ssl/ca ]; then
    # Generate CA certificate
    puppet cert list -a -v

    # Generate puppetserver host certificates named from the container hostname
    # (docker run --host <hostname for container>)
    # Prevents partial state error when starting puppet and puppetserver at the
    # same time. See https://tickets.puppetlabs.com/browse/SERVER-528 and
    # https://tickets.puppetlabs.com/browse/SERVER-1233
    # Note: hostname must be set at container runtime. facter can't properly resolve
    #   the hostname of the container when letting docker generate a random name
    puppet cert generate $(facter fqdn) -v
  fi
fi

## Pass control on to the command supplied on the CMD line of the Dockerfile
## This makes supervisor PID 1
exec "$@"
