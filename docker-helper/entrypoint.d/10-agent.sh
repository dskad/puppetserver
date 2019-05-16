#!/usr/bin/bash

# *** Puppet Agent Config ***
#*********************
# Point the server's puppet agent to SERVER or this host's hostname
if [[ -n "${SERVER}" ]]; then
  puppet config set --section agent server ${SERVER}
else
  puppet config set --section agent server $(facter hostname)
fi

# Set this for the agent to talk to a puppet master on a different port
[[ -n "${MASTERPORT}" ]] && puppet config set --section agent masterport ${MASTERPORT}

# Manually set a cert name, default is the container's fqdn/hash. (it's different every run!)
[[ -n "${CERTNAME}" ]] && puppet config set --section main certname ${CERTNAME}

# environment to configure this container
puppet config set --section agent environment ${AGENT_ENVIRONMENT}

# Have to be careful not to change the server's cert when acting as a CA server
if [[ ! -n "${CA_SERVER}" ]]; then
  currentCertName=$(puppet config print certname)
  if [[ ! -f "/etc/puppetlabs/puppet/ssl/certs/${currentCertName}.pem" ]]; then
    puppet config set --section main dns_alt_names $(facter fqdn),$(facter hostname)${DNS_ALT_NAMES:+,}$DNS_ALT_NAMES
  else
    echo "Notice: CERTNAME/DNS_ALT_NAMES not updated. A certificate for ${currentCertName} already exists."
    echo "        Revoke or remove this certificate to change CERTNAME/DNS_ALT_NAMES."
    echo "        You may need to reissue client certificates."
  fi
else
  # We're not the CA server, we call ourselves anything we want!
  puppet config set --section main dns_alt_names $(facter fqdn),$(facter hostname)${$DNS_ALT_NAMES:+,}$DNS_ALT_NAMES
fi

