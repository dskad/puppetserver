#!/bin/bash
## unoficial "strict mode" http://redsymbol.net/articles/unofficial-bash-strict-mode/
set -euo pipefail
IFS=$'\n\t'

# This section runs before supervisor and is good for initalization or pre-startup tasks
if [ $1 = "supervisord" ]; then

  ## Only initalize and setup the environments (via r10k) if server is launching
  ##    for the first time (i.e. new server container). We don't want to unintentionally
  ##    upgrade an environment or break certs on a container restart or upgrade.
  if [ ! -d  /etc/puppetlabs/puppet/ssl/ca ]; then
    # Generate CA certificate
    puppet cert list -a -v

    # Generate puppetserver host certificates named from the container hostname
    # (docker run --host <hostname for container>)
    # Prevents partial state error when starting puppet and puppetserver at the
    # same time. See https://tickets.puppetlabs.com/browse/SERVER-528
    puppet cert generate $(facter fqdn) --dns_alt_names=${DNSALTNAMES},$(facter hostname) -v

    # Run r10k to sync environments with modules
    r10k deploy environment --puppetfile -v

    # Apply inital config on startup.
    puppet apply --environment=${BOOTSTRAPENV} \
    /etc/puppetlabs/code/environments/${BOOTSTRAPENV}/manifests/site.pp
  else
    # TODO fix the supervisor provider to allow confdir location paramaters

    # The container is already initialized. Make sure container configuration is
    # to date. This covers the issue with not being able to store single /etc flies
    # in a volume without storing the entire directory. Supervisord behaves difficultly
    # when the conf file is moved

    # Note: contaner hostname needs to stay the same across container startups or else
    # the signed host certificate and hostname will not match, causing random errors
    currrent_env=$(puppet config print environment)
    puppet apply --environment=${currrent_env} \
    /etc/puppetlabs/code/environments/${currrent_env}/manifests/site.pp
  fi
fi

## Pass control on to the command suppled on the CMD line of the Dockerfile
## This makes supervisor PID 1
exec "$@"
