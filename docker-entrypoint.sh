#!/bin/bash
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

  # Initialize CA if it doesn't exist. Usually on first startup
  # TODO handle disabled CA
  if [ ! -d  /etc/puppetlabs/puppet/ssl/ca ]; then
    # Generate new CA certificate
    puppet cert list -a -v

    # Generate puppetserver host certificates named from the container hostname
    puppet cert generate $(facter fqdn) -v --dns_alt_names $(facter fqdn),$(facter hostname),$DNS_ALT_NAMES
  fi

  # TODO Check for R10k config, then run R10k and run 'puppet apply' to apply custom container config

  # Run R10k to update local environments
  #   Changes to the R10k configuration should be changed in the image and rebuilt
  # r10k deploy environment -p -v

  # Apply current config for this instance. Volumes retain config across container restarts
  # puppet apply /etc/puppetlabs/code/environments/puppet/manifests/site.pp -v
fi

## Pass control on to the command supplied on the CMD line of the Dockerfile
## This makes puppetserver PID 1
exec "$@"
