#!/bin/bash
## unoficial "strict mode" http://redsymbol.net/articles/unofficial-bash-strict-mode/
## with modification, we want unbound variables to allow extra runtime configs
set -eo pipefail
if [ -v DEBUG ]; then
  set -x
fi

# IFS=$'\n\t'

if [ $1 = "puppetserver" ]; then
  ## Create /var/run/puppetlabs directory as this will go missing since we are mounting tmpfs here
  ## Puppetserver startup doesn't recreate this directory
  ## https://tickets.puppetlabs.com/browse/SERVER-441

  # Set default r10k repo url, if set
  # TODO Set DEFAULT_R10K_REPO_URL to a local directory with a default repo in it
  if [ -v DEFAULT_R10K_REPO_URL ]; then
    sed -i "s@REPO_URL@${DEFAULT_R10K_REPO_URL}@" /etc/puppetlabs/r10k/r10k.yaml
    # r10k deploy environment --puppetfile -v
  # else
    # TODO Use tags instead of the hostname
    # sed -i "s/MYLOCALHOST/$(hostname)/" /etc/puppetlabs/code/environments/production/manifests/site.pp
  fi

  if [ -v R10K_FILE_URL ]; then
    curl -Lo /etc/puppetlabs/r10k/r10k.yaml R10K_FILE_URL
  fi

  # Generate SSH key pair for R10k if it doesn't exist
  if [[ ! -f  /etc/puppetlabs/r10k/ssh/id_rsa ]]; then
    ssh-keygen -b 4096 -f /etc/puppetlabs/r10k/ssh/id_rsa -t rsa -N ""
  fi

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
  fi

  ## Set puppet.conf settings
  # puppet config set runinterval ${RUNINTERVAL} --section agent --environment production
  # puppet config set environment ${PUPPETENV} --section main --environment production
  puppet config set trusted_server_facts true --section main --environment production

  # if [ ${PUPPETSERVER} == "localhost" ]; then
  #   puppet config set server $(hostname) --section main --environment production
  # else
  #   puppet config set server ${PUPPETSERVER} --section main --environment production
  # fi

  if [ -v DNSALTNAMES ]; then
    puppet config set dns_alt_names ${DNSALTNAMES} --section main --environment production
  fi

  # TODO Add config for puppetserver tuning options
  # Set JAVA_ARGS for the server
  # sed -i "/JAVA_ARGS/ c\\JAVA_ARGS=\"${JAVA_ARGS}\"" /etc/sysconfig/puppetserver
fi

## Pass control on to the command suppled on the CMD line of the Dockerfile
## This makes supervisor PID 1
exec "$@"
