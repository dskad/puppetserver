#!/bin/bash
## unofficial "strict mode" http://redsymbol.net/articles/unofficial-bash-strict-mode/
## with modification, we want unbound variables to allow extra runtime configs
set -eo pipefail
if [ -v DEBUG ]; then
  set -x
fi

if [ $1 = "puppetserver" ]; then
  # Generate SSH key pair for R10k if it doesn't exist
  if [[ ! -f  /etc/puppetlabs/ssh/id_rsa ]]; then
    ssh-keygen -b 4096 -f /etc/puppetlabs/ssh/id_rsa -t rsa -N ""
    echo "SSH public key:"
    cat /etc/puppetlabs/ssh/id_rsa.pub
  fi

  ## This script runs before systemd init and is good for initialization or pre-startup tasks
  ## Only initialize and setup the environments (via r10k) if server is launching
  ##    for the first time (i.e. new server container). We don't want to unintentionally
  ##    upgrade an environment or break certs on a container restart or upgrade.
  if [ ! -d  /etc/puppetlabs/puppet/ssl/ca ]; then
    # Generate CA certificate
    # puppet cert list -a -v

    # Generate puppetserver host certificates named from the container hostname
    # (docker run --host <hostname for container>)
    # Prevents partial state error when starting puppet and puppetserver at the
    # same time. See https://tickets.puppetlabs.com/browse/SERVER-528 and
    # https://tickets.puppetlabs.com/browse/SERVER-1233
    # Note: hostname must be set at container runtime. facter can't properly resolve
    #   the hostname of the container when letting docker generate a random name
    puppet cert generate $(facter fqdn) -v --dns_alt_names $(facter fqdn),$(facter hostname),$DNS_ALT_NAMES

    # Apply current config for this instance. Volumes retain config across container restarts
    # puppet apply /etc/puppetlabs/code/environments/puppet/manifests/site.pp -v
  fi

  # Run R10k to update local environments
  #   Changes to the R10k configuration should be changed in the image and rebuilt
  # r10k deploy environment -p -v

  # Apply current config for this instance. Volumes retain config across container restarts
  # puppet apply /etc/puppetlabs/code/environments/puppet/manifests/site.pp -v
fi

## Pass control on to the command supplied on the CMD line of the Dockerfile
## This makes supervisor PID 1
exec "$@"
