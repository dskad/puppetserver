#!/usr/bin/bash
set -e

certname=$(puppet config print certname) && \
curl -sS --fail -H 'Accept: pson' \
  --resolve "${certname}:8140:127.0.0.1" \
  --cert   "/etc/puppetlabs/puppet/ssl/certs/${certname}.pem" \
  --key    "/etc/puppetlabs/puppet/ssl/private_keys/${certname}.pem" \
  --cacert /etc/puppetlabs/puppet/ssl/certs/ca.pem \
  "https://${certname}:8140/${HEALTHCHECK_ENVIRONMENT}/status/test" | \
  grep -q '"is_alive":true' || \
  exit 1
