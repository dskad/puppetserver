#!/bin/bash
## unoficial "strict mode" http://redsymbol.net/articles/unofficial-bash-strict-mode/
## with modification, we want unbound variables to allow extra runtime configs
set -eo pipefail
IFS=$'\n\t'

# This section runs before supervisor and is good for initalization or pre-startup tasks
if [ $1 = "/usr/sbin/init" ]; then
  ## Create /var/run/puppetlabs directory as this will go missing since we are mounting tmpfs here
  ## Puppetserver startup doesn't recreate this directory
  ## https://tickets.puppetlabs.com/browse/SERVER-441
  mkdir -p /run/puppetlabs

  ## Set puppet.conf settings
  sed -i "s/SETSERVER/${PUPPETSERVER}/" /etc/puppetlabs/puppet/puppet.conf
  sed -i "s/SETENV/${PUPPETENV}/" /etc/puppetlabs/puppet/puppet.conf
  sed -i "s/SETRUNINTERVAL/${RUNINTERVAL}/" /etc/puppetlabs/puppet/puppet.conf
  sed -i "s/SETWAITFORCERT/${WAITFORCERT}/" /etc/puppetlabs/puppet/puppet.conf

  sed -i "/JAVA_ARGS/ c\\JAVA_ARGS=\"${JAVA_ARGS}\"" /etc/sysconfig/puppetserver

  ## Set extra options for puppet agent if variable is set
  if [ -v PUPPET_EXTRA_OPTS ]; then
    echo PUPPET_EXTRA_OPTS=${PUPPET_EXTRA_OPTS} >> /etc/sysconfig/puppet
  fi

  ## Set extra options for mcollective if variable is set
  if [ -v MCO_DAEMON_OPTS ]; then
    echo MCO_DAEMON_OPTS=${MCO_DAEMON_OPTS} >> /etc/sysconfig/mcollective
  fi

  ## Set extra options for pxp-agent if variable is set
  if [ -v PXP_AGENT_OPTIONS ]; then
    echo PXP_AGENT_OPTIONS=${PXP_AGENT_OPTIONS} >> /etc/sysconfig/pxp-agent
  fi

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
    puppet cert generate $(facter fqdn) --dns_alt_names=${DNSALTNAMES},$(facter hostname) -v

    # Run r10k to sync environments with modules
    # This is only run during container setup to prevent unintentional code deployment
    r10k deploy environment --puppetfile -v

    # Apply inital config on startup.
    # puppet apply --environment=${BOOTSTRAPENV} \
    # /etc/puppetlabs/code/environments/${BOOTSTRAPENV}/manifests/site.pp
  # else
    # TODO fix the supervisor provider to allow confdir location paramaters

    # The container is already initialized. Make sure container configuration is
    # to date. This covers the issue with not being able to store single /etc flies
    # in a volume without storing the entire directory. Supervisord behaves difficultly
    # when the conf file is moved

    # Note: contaner hostname needs to stay the same across container startups or else
    # the signed host certificate and hostname will not match, causing random errors
    # currrent_env=$(puppet config print environment)
    # puppet apply --environment=${currrent_env} \
    # /etc/puppetlabs/code/environments/${currrent_env}/manifests/site.pp
  fi
fi

## Pass control on to the command suppled on the CMD line of the Dockerfile
## This makes supervisor PID 1
exec "$@"
