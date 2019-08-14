#!/usr/bin/bash

# *** Puppet Agent Config ***
#*********************
# Point the server's puppet agent to $SERVER or this host's hostname
if [[ -n "${SERVER}" ]]; then
  puppet config set --section agent server "${SERVER}"
else
  puppet config set --section agent server "$(facter hostname)"
fi

# Optionally set puppet server port for agent
[[ -n "${MASTERPORT}" ]] && puppet config set --section agent masterport "${MASTERPORT}"

# Optionally set a cert name, default is the container's fqdn/hash. (it's usually different every run!)
[[ -n "${CERTNAME}" ]] && puppet config set --section main certname "${CERTNAME}"

# Set the puppet environment for the agent in this container. (default is production)
puppet config set --section agent environment "${AGENT_ENVIRONMENT}"

# Optionally configure an external CA server
# Have to be careful not to change the server's cert when acting as a CA server
if [[ -z "${CA_SERVER}" ]]; then
  currentCertName=$(puppet config print certname)
  if [[ ! -f "/etc/puppetlabs/puppet/ssl/certs/${currentCertName}.pem" ]]; then
    puppet config set --section main dns_alt_names "$(facter fqdn),$(facter hostname)${DNS_ALT_NAMES:+,}${DNS_ALT_NAMES}"
  else
    echo "Notice: CERTNAME/DNS_ALT_NAMES not updated. A certificate for ${currentCertName} already exists."
    echo "        Revoke or remove this certificate to change CERTNAME/DNS_ALT_NAMES."
    echo "        You may need to reissue client certificates."
  fi
else
  # We're not the CA server, we call ourselves anything we want!
  puppet config set --section main dns_alt_names "$(facter fqdn),$(facter hostname)${DNS_ALT_NAMES:+,}$DNS_ALT_NAMES"
fi

