#!/bin/bash
set -eo pipefail
if [[ -v DEBUG ]]; then set -x; fi

if [[ "$1" = "puppetserver" ]]; then
  # Point the server's puppet agent to SERVER or this host's hostname
  if [[ -n "${SERVER}" ]]; then
    puppet config set --section agent server ${SERVER}
  else
    puppet config set --section agent server $(facter hostname)
  fi

  # Set this for the agent to talk to a puppet master on a different port
  if [[ -n "${MASTERPORT}" ]]; then
    puppet config set --section agent masterport ${MASTERPORT}
  fi

  # Manually set a cert name, default is the container's fqdn/hash. (it's different every run!)
  if [[ -n "${CERTNAME}" ]]; then
    puppet config set --section main certname ${CERTNAME}
  fi

  # environment to configure this container
  puppet config set --section agent environment ${AGENT_ENVIRONMENT}

  # Configure puppet to use a certificate autosign script (if it exists)
  # AUTOSIGN=true|false|path_to_autosign.conf
  if [[ -n "${AUTOSIGN}" ]] ; then
    puppet config set autosign "$AUTOSIGN" --section master
  fi

  puppet config set --section main dns_alt_names $(facter fqdn),$(facter hostname),$DNS_ALT_NAMES

  # If the local CA server is disabled, configure the CA server host and port (optionally)
  if [[ "${DISABLE_CA_SERVER}" = "true" && -n "${CA_SERVER}" ]]; then
    sed -i "s/^\([^#].*certificate-authority-service\)/#\1/" /etc/puppetlabs/puppetserver/services.d/ca.cfg
    sed -i "s/^#\(.*certificate-authority-disabled-service\)/\1/" /etc/puppetlabs/puppetserver/services.d/ca.cfg
    puppet config set --section main ca_server "${CA_SERVER}"
    if [[ -n "${CA_PORT}" ]]; then
      puppet config set --section main ca_port "${CA_PORT}"
    else
      $CA_PORT=8140
    fi

    # Not using puppet agent here because we don't want to do a full puppet run yet.
    #   Environments might not be set up yet

    # Import the CA certs from the master
    puppet certificate find --ca-location remote ca -v

    # Get the local cert signed and import ca certs from master
    # TODO verify the alt-dns-names error doesn't stop the script  use "|| true"
    puppet certificate generate --ca-location remote $(puppet config print certname) -v

    # puppet agent -t -v --waitforcert 30s --environment production --server ${CA_SERVER} --masterport ${MASTERPORT}

    # Update puppetserver webserver.conf to point to certificates from puppet run. This is was not well documented
    # When no CA is setup, puppetserver won't run without ssl-crl-path set, if that is set, the others have to be set
    sed -i '/}/d' /etc/puppetlabs/puppetserver/conf.d/webserver.conf
    echo "    ssl-cert: $(puppet config print hostcert --section master)" >> /etc/puppetlabs/puppetserver/conf.d/webserver.conf
    echo "    ssl-key: $(puppet config print hostprivkey --section master)" >> /etc/puppetlabs/puppetserver/conf.d/webserver.conf
    echo "    ssl-ca-cert: $(puppet config print localcacert --section master)" >> /etc/puppetlabs/puppetserver/conf.d/webserver.conf
    echo "    ssl-crl-path: $(puppet config print hostcrl --section master)" >> /etc/puppetlabs/puppetserver/conf.d/webserver.conf
    echo "}" >> /etc/puppetlabs/puppetserver/conf.d/webserver.conf
  fi

  # Initialize CA if it doesn't exist. Usually on first startup
  # TODO handle disabled CA
  if [[ ! -d  /etc/puppetlabs/puppet/ssl/ca && ! "${DISABLE_CA_SERVER}" = "true" ]]; then
    # Generate new CA certificate
    puppet cert list -a -v

    # Generate a self signed cert named from the container hostname or CERTNAME
    if [[ -n "${CERTNAME}" ]]; then
      puppet cert generate $(puppet config print certname) -v
    else
      puppet cert generate $(facter fqdn) -v
    fi
  fi

  # Generate SSH key pair for R10k if it doesn't exist
  if [[ ! -f  /etc/puppetlabs/ssh/id_rsa ]]; then
    gen-ssh-keys -n -c "r10k-$(facter fqdn)"
    if [[ $SHOW_SSH_KEY = "true" ]]; then
      echo "SSH public key:"
      gen-ssh-keys -p
    fi
  fi

  # Disable strict host checking in SSH if SSH_HOST_KEY_CHECK is false
  if [[ "$SSH_HOST_KEY_CHECK" = "false" ]]; then
    echo "StrictHostKeyChecking no" >> /etc/ssh/ssh_config
  fi

  # If r10k.yaml doesn't exist, build the basic r10k config file
  if [[ ! -f /etc/puppetlabs/r10k/r10k.yaml ]]; then
    echo -e "---\n:cachedir: /opt/puppetlabs/server/data/puppetserver/r10k\n\n:sources:" > /etc/puppetlabs/r10k/r10k.yaml

    # If R10k sources are supplied via R10K_SOURCE* environment variables, add them to the r10k config file
    env -0 | while IFS='=' read -r -d '' NAME VALUE; do
      # looping through each R10K_SOURCE variables (R10K_SOURCE1, R10K_SOURCE2, etc)
      if [[ $NAME =~ R10K_SOURCE\n* && -n "${VALUE}" ]]; then
        IFS=',' read -ra SOURCE <<< "$VALUE"

        echo -e "  ${SOURCE[0]}:\n    remote: ${SOURCE[1]}" >>/etc/puppetlabs/r10k/r10k.yaml
        echo -e "    basedir: /etc/puppetlabs/code/environments" >>/etc/puppetlabs/r10k/r10k.yaml
        if [[ ${#SOURCE[@]} > 2 ]]; then
          echo -e "    prefix: ${SOURCE[2]}\n" >>/etc/puppetlabs/r10k/r10k.yaml
        else
          echo -e "    prefix: false\n" >>/etc/puppetlabs/r10k/r10k.yaml
        fi

        # If SSH host key checking and auto trust is turned on, connect to source and add host key
        if [[ "$SSH_HOST_KEY_CHECK" = "true" && "$TRUST_SSH_FIRST_CONNECT" = "true" ]]; then
          # Parse the R10K_SOURCE# url for the remote
          shopt -s nocasematch
          pattern='^(([[:alnum:]]+)://)?((([[:alnum:]]+)(:?([[:alnum:]]+)?))@)?([^:^@^/]+)(:([[:digit:]]+))?(/.*)'
          if [[ ${SOURCE[1]} =~ $pattern ]]; then
            protocol=${BASH_REMATCH[2]}
            user=${BASH_REMATCH[5]}
            password=${BASH_REMATCH[7]}
            host=${BASH_REMATCH[8]}
            port=${BASH_REMATCH[10]}
            path=${BASH_REMATCH[11]}
          fi

          # Verify that the source URL is SSH
          if [[ "$protocol" = 'ssh' ]]; then
            # set default ssh port of 22 if not indicated in the url
            port=${port:-22}

            # Check to see if the host already exists in known_hosts
            #   * known_hosts formats differently if alternate port specified
            if [[ "$port" = "22" && ! "$(ssh-keygen -F $host -f /etc/puppetlabs/ssh/known_hosts -t rsa > /dev/null 2>&1)" ]]; then
              ssh-keyscan -p $port $host >> /etc/puppetlabs/ssh/known_hosts
            elif [[ ! "$(ssh-keygen -F [$host]:$port -f /etc/puppetlabs/ssh/known_hosts -t rsa > /dev/null 2>&1)" ]]; then
              ssh-keyscan -p $port $host >> /etc/puppetlabs/ssh/known_hosts
            fi
          fi

          shopt -u nocasematch
        fi
      fi
    done
  fi

  # Run R10k to update local environments if environment var set
  # r10k deploy environment -p -v
  if [[ "$R10K_ON_STARTUP" = "true" ]]; then
    r10k deploy environment -p -v
  fi

  # Apply current config for this instance. Volumes retain config across container restarts
  # puppet apply /etc/puppetlabs/code/environments/puppet/manifests/site.pp -v
fi

## Pass control on to the command supplied on the CMD line of the Dockerfile
## This makes puppetserver PID 1
exec "$@"
