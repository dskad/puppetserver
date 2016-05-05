#!/bin/bash
## unoficial "strict mode" http://redsymbol.net/articles/unofficial-bash-strict-mode/
## with modification, we want unbound variables to allow extra runtime configs
set -eo pipefail
IFS=$'\n\t'

if [ $1 = "/usr/sbin/init" ]; then
  ## Create /var/run/puppetlabs directory as this will go missing since we are mounting tmpfs here
  ## Puppetserver startup doesn't recreate this directory
  ## https://tickets.puppetlabs.com/browse/SERVER-441
  mkdir -p /run/puppetlabs

  # Set JAVA_ARGS for the server
  sed -i "/JAVA_ARGS/ c\\JAVA_ARGS=\"${JAVA_ARGS}\"" /etc/sysconfig/puppetserver

  # Set default r10k repo url.
  sed -i "s@REPOURL@${DEFAULT_R10K_REPO_URL}@" /etc/puppetlabs/r10k/r10k.yaml

  ## This script runs before ssytemd init and is good for initalization or pre-startup tasks
  ## Only initalize and setup the environments (via r10k) if server is launching
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
    puppet cert generate $(facter fqdn) --dns_alt_names=$(facter hostname)${DNSALTNAMES:+,}${DNSALTNAMES} -v

    # Run r10k to sync environments with modules
    # This is only run during container setup to prevent unintentional code deployment
    r10k deploy environment --puppetfile -v
  fi
  ## Set puppet.conf settings
  ## Note: The environment must exist (via r10k above) before the agent can be set to it
  puppet config set runinterval ${RUNINTERVAL} --section agent
  puppet config set waitforcert ${WAITFORCERT} --section agent
  puppet config set server ${PUPPETSERVER} --section main
  puppet config set environment ${PUPPETENV} --section main
  puppet config set trusted_server_facts true --section main
  if [ -v DNSALTNAMES ]; then
    puppet config set dns_alt_names ${DNSALTNAMES} --section main
  fi

  # TODO Add config for puppetserver tuning options

fi

## Pass control on to the command suppled on the CMD line of the Dockerfile
## This makes supervisor PID 1
exec "$@"
