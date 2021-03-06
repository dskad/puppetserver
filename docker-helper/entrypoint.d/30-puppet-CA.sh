#!/usr/bin/bash

# *** Puppet CA Config ***
#*******************
# Enable autosigning. true, false or path to executable addeded via volume or build
if [[ -n "${AUTOSIGN}" ]] ; then
  puppet config set autosign "$AUTOSIGN" --section master
fi

# allow CA to sign certificate requests that have subject alternative names
#   to allow infrastructure scaling like compile masters and puppetdb clusters
# TODO: investigate server code to see if this can be done in autosign.config or other code change instead of globally
if [[ -n "${ALLOW_SUBJECT_ALT_NAMES}" ]]; then
  sed -i "s/#\?\s\+allow-subject-alt-names.*/allow-subject-alt-names: true/" /etc/puppetlabs/puppetserver/conf.d/ca.conf
fi

# allow CA to sign certificate requests that have authorization extensions
if [[ -n "${ALLOW_AUTHORIZATION_EXTENSIONS}" ]]; then
  sed -i "s/#\?\s\+allow-authorization-extensions.*/allow-authorization-extensions: true/" /etc/puppetlabs/puppetserver/conf.d/ca.conf
fi

# TODO: Allow Infrastructure certificate revocation list
# Add support to add infra list at $cadir/infra_inventory.txt
# https://puppet.com/docs/puppetserver/6.0/infrastructure_crl.html
# if [[ -n "${ENABLE_INFRA_CRL}" ]]; then
#   sed -i "s/#\?\s\+enable-infra-crl.*/enable-infra-crl: true/" /etc/puppetlabs/puppetserver/conf.d/ca.conf
# fi

# If CA server is supplied, disable the local CA and configure the CA server host and port (optionally)
if [[ -n "${CA_SERVER}" ]]; then
  # Disable CA
  sed -i "s/^\([^#].*certificate-authority-service\)/#\1/" /etc/puppetlabs/puppetserver/services.d/ca.cfg
  sed -i "s/^#\(.*certificate-authority-disabled-service\)/\1/" /etc/puppetlabs/puppetserver/services.d/ca.cfg

  # Set CA server and port, if port isn't provided, roll with the default
  puppet config set --section main ca_server "${CA_SERVER}"
  if [[ -n "${CA_PORT}" ]]; then
    puppet config set --section main ca_port "${CA_PORT}"
  else
    CA_PORT=$(puppet config print ca_port)
  fi

  # Wait for the CA server to spin up, in case the infra was started all at the same time
  while ! (echo > /dev/tcp/"${CA_SERVER}"/"${CA_PORT}") >/dev/null 2>&1; do
    echo 'Waiting for puppet CA server to become available...'
    sleep 10
  done

  # Get the CA server to sign our cert, force prod environment in case this server is set to use some other
  #   env that doesn't exist pre R10k run
  puppet agent \
    --verbose \
    --no-daemonize \
    --onetime \
    --noop \
    --server "${CA_SERVER}" \
    --masterport "${CA_PORT}" \
    --environment production \
    --waitforcert 30s

  # Update puppetserver webserver.conf to point to new certificates from puppet run.
  # When CA is disabled, puppetserver won't run without ssl-crl-path set, if that is set, the others have to be set
  sed -i '/}/d' /etc/puppetlabs/puppetserver/conf.d/webserver.conf
  cat <<EOF >> /etc/puppetlabs/puppetserver/conf.d/webserver.conf
    ssl-cert: $(puppet config print hostcert)
    ssl-key: $(puppet config print hostprivkey)
    ssl-ca-cert: $(puppet config print localcacert)
    ssl-crl-path: $(puppet config print hostcrl)
  }
EOF
fi
