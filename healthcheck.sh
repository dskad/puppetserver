#!/usr/bin/env bash
set -e

hostname=$(puppet config print certname) && \
curl -sS --fail -H 'Accept: pson' \
  --resolve "${hostname}:8140:127.0.0.1" \
  --cert   /etc/puppetlabs/puppet/ssl/certs/${hostname}.pem \
  --key    /etc/puppetlabs/puppet/ssl/private_keys/${hostname}.pem \
  --cacert /etc/puppetlabs/puppet/ssl/certs/ca.pem \
  https://${HOSTNAME}:8140/${HEALTHCHECK_ENVIRONMENT}/status/test \
  | grep -q '"is_alive":true' \
  ||exit 1
