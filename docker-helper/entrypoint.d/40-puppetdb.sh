#!/usr/bin/bash

  # *** Configure PuppetDB connections ***
  # **************************************

# Configure for puppetdb if PUPPETDB_SERVER_URLS is set
if [[ -n "${PUPPETDB_SERVER_URLS}" ]]; then
  puppet config set --section main storeconfigs true
  puppet config set --section main storeconfigs_backend puppetdb
  puppet config set --section main reports logs,puppetdb

  if [[ ! -f /etc/puppetlabs/puppet/puppetdb.conf ]]; then
    echo "[main]" > /etc/puppetlabs/puppet/puppetdb.conf
    echo "server_urls = ${PUPPETDB_SERVER_URLS}" >> /etc/puppetlabs/puppet/puppetdb.conf
    echo "soft_write_failure = ${SOFT_WRITE_FAILURE}" >> /etc/puppetlabs/puppet/puppetdb.conf
  fi

  if [[ ! -f /etc/puppetlabs/puppet/routes.yaml ]]; then
    echo "---" > /etc/puppetlabs/puppet/routes.yaml
    echo "master:" >> /etc/puppetlabs/puppet/routes.yaml
    echo "  facts:" >> /etc/puppetlabs/puppet/routes.yaml
    echo "    terminus: puppetdb" >> /etc/puppetlabs/puppet/routes.yaml
    echo "    cache: yaml" >> /etc/puppetlabs/puppet/routes.yaml
  fi
fi
