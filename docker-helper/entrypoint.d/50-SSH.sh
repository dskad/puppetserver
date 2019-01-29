#!/usr/bin/bash

# *** Configure SSH ***
# ******************************
# Add SSH private key if supplied
if [[ -n "${SSH_PRIV_KEY}" ]]; then
  echo "${SSH_PRIV_KEY}" > /etc/puppetlabs/ssh/id_key
  chmod 600 /etc/puppetlabs/ssh/id_key
fi

# Generate SSH key pair for R10k if it doesn't exist
if [[ ! -f  /etc/puppetlabs/ssh/id_key ]]; then
  ssh-keygen  -f /etc/puppetlabs/ssh/id_key -t ${GENERATED_SSH_KEY_TYPE} -N "" -C "$(facter fqdn)"
  if [[ ${SHOW_SSH_KEY} = "true" ]]; then
    echo "SSH public key:"
    cat /etc/puppetlabs/ssh/id_key.pub
  fi
fi

# Disable strict host checking in SSH if STRICT_HOST_KEY_CHECKING is false
if [[ "${STRICT_HOST_KEY_CHECKING}" = "false" ]]; then
  echo "StrictHostKeyChecking no" >> /etc/ssh/ssh_config
fi

