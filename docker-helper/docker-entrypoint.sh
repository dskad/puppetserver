#!/usr/bin/env bash

shopt -s nocasematch
set -eo pipefail
if [[ -v DEBUG ]]; then set -x; fi

if [[ "$2" = "foreground" ]]; then
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
  puppet config set --section main dns_alt_names $(facter fqdn),$(facter hostname),$DNS_ALT_NAMES


  # *** Puppet Server Config ***
  #*******************
  # Update puppetserver configs to use JAVA_ARGS variable to configure java runtime
  [[ -n "${JAVA_ARGS}" ]] && sed -i "s/JAVA_ARGS=.*$/JAVA_ARGS=\"\$JAVA_ARGS\"/" /etc/sysconfig/puppetserver

  # Should  be either 0 or unlimited. 0 is default, unlimited requires calling environment refresh API
  if [[ -n "${ENVIRONMENT_TIMEOUT}" ]]; then
    puppet config set environment_timeout ${ENVIRONMENT_TIMEOUT}
  fi


  # *** Puppet CA Config ***
  #*******************
  # Enable basic signing. More advanced auto signing should mount via volume
  if [[ -n "${AUTOSIGN}" ]] ; then
    echo "*" > /etc/puppetlabs/puppet/autosign.conf
    chown puppet.puppet /etc/puppetlabs/puppet/autosign.conf
  fi

  # To allow infrastructure scaling like compile masters and puppetdb clusters
  # TODO: investigate server code to see if this can be done in autosign.config or other code change instead of globally
  if [[ -n "${ALLOW_SUBJECT_ALT_NAMES}" ]]; then
    sed -i "s/#\?\s\+allow-subject-alt-names.*/allow-subject-alt-names: true/" /etc/puppetlabs/puppetserver/conf.d/ca.conf
  fi

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
    while ! (echo > /dev/tcp/${CA_SERVER}/${CA_PORT}) >/dev/null 2>&1; do
      echo 'Waiting for puppet server to become available...'
      sleep 10
    done

    # Get the CA server to sign our cert, force prod environment in case this server is set to use some other
    #   env that doesn't exist pre R10k run
    puppet agent \
      --verbose \
      --no-daemonize \
      --onetime \
      --noop \
      --server ${CA_SERVER} \
      --masterport ${CA_PORT} \
      --environment production \
      --waitforcert 30s

    # Update puppetserver webserver.conf to point to new certificates from puppet run.
    # When CA is disabled, puppetserver won't run without ssl-crl-path set, if that is set, the others have to be set
    sed -i '/}/d' /etc/puppetlabs/puppetserver/conf.d/webserver.conf
    echo "    ssl-cert: $(puppet config print hostcert)" >> /etc/puppetlabs/puppetserver/conf.d/webserver.conf
    echo "    ssl-key: $(puppet config print hostprivkey)" >> /etc/puppetlabs/puppetserver/conf.d/webserver.conf
    echo "    ssl-ca-cert: $(puppet config print localcacert)" >> /etc/puppetlabs/puppetserver/conf.d/webserver.conf
    echo "    ssl-crl-path: $(puppet config print hostcrl)" >> /etc/puppetlabs/puppetserver/conf.d/webserver.conf
    echo "}" >> /etc/puppetlabs/puppetserver/conf.d/webserver.conf
  fi


  # *** Configure PuppetDB connections ***
  # **************************************

  # Configure for puppetdb if PUPPETDB_SERVER_URLS is set
  if [[ -n "${PUPPETDB_SERVER_URLS}" ]]; then
    echo "[main]" > /etc/puppetlabs/puppet/puppetdb.conf
    echo "server_urls = ${PUPPETDB_SERVER_URLS}" >> /etc/puppetlabs/puppet/puppetdb.conf
    echo "soft_write_failure = ${SOFT_WRITE_FAILURE}" >> /etc/puppetlabs/puppet/puppetdb.conf

    puppet config set --section master storeconfigs true
    puppet config set --section master storeconfigs_backend puppetdb
    puppet config set --section master reports logs,puppetdb

    echo "---" > /etc/puppetlabs/puppet/routes.yaml
    echo "master:" >> /etc/puppetlabs/puppet/routes.yaml
    echo "  facts:" >> /etc/puppetlabs/puppet/routes.yaml
    echo "    terminus: puppetdb" >> /etc/puppetlabs/puppet/routes.yaml
    echo "    cache: yaml" >> /etc/puppetlabs/puppet/routes.yaml
  fi


  # *** Configure SSH ***
  # ******************************
  # Add SSH private key if supplied
  if [[ -n "${SSH_PRIV_KEY}" ]]; then
    echo "${SSH_PRIV_KEY}" > /etc/puppetlabs/ssh/id_key
    chmod 600 /etc/puppetlabs/ssh/id_key
  fi

  # Generate SSH key pair for R10k if it doesn't exist
  if [[ ! -f  /etc/puppetlabs/ssh/id_key ]]; then
    ssh-keygen  -f /etc/puppetlabs/ssh/id_key -t ed25519 -N "" -C "$(facter fqdn)"
    if [[ ${SHOW_SSH_KEY} = "true" ]]; then
      echo "SSH public key:"
      cat /etc/puppetlabs/ssh/id_key.pub
    fi
  fi

  # Disable strict host checking in SSH if STRICT_HOST_KEY_CHECKING is false
  if [[ "${STRICT_HOST_KEY_CHECKING}" = "false" ]]; then
    echo "StrictHostKeyChecking no" >> /etc/ssh/ssh_config
  fi


  # *** Add custom CA certs from environment variables CA_CERT1, CA_CERT2, etc
  # ***************************************************************************
  if (env | grep -q '^CA_CERT\n*'); then
    env -0 | while IFS='=' read -r -d '' NAME VALUE; do
      if [[ ${NAME} =~ ^CA_CERT\n* && -n "${VALUE}" ]] ; then
        echo "${VALUE}" > /etc/puppetlabs/git/ca/${NAME}.pem
      fi
    done
  fi


  # *** Configure R10k ***
  # ******************************
  # If r10k.yaml doesn't exist, and source url(s) are supplied, build the basic r10k config file
  if (env | grep -q '^R10K_SOURCE\n*'); then
    echo -e "---\n:cachedir: /opt/puppetlabs/server/data/puppetserver/r10k\n\n:sources:" > /etc/puppetlabs/r10k/r10k.yaml

    # TODO: allow custom basedir
    # If R10k sources are supplied via R10K_SOURCE* environment variables, add them to the r10k config file
    env -0 | while IFS='=' read -r -d '' NAME VALUE; do
      # looping through each R10K_SOURCE variables (R10K_SOURCE1, R10K_SOURCE2, etc)
      if [[ ${NAME} =~ R10K_SOURCE\n* && -n "${VALUE}" ]]; then
        IFS=',' read -ra SOURCE <<< "$VALUE"

        # Add source config to r10k.yaml
        echo -e "  ${SOURCE[0]}:\n    remote: ${SOURCE[1]}" >>/etc/puppetlabs/r10k/r10k.yaml
        echo -e "    basedir: /etc/puppetlabs/code/environments" >>/etc/puppetlabs/r10k/r10k.yaml
        if [[ ${#SOURCE[@]} > 2 ]]; then
          echo -e "    prefix: ${SOURCE[2]}\n" >>/etc/puppetlabs/r10k/r10k.yaml
        else
          echo -e "    prefix: false\n" >>/etc/puppetlabs/r10k/r10k.yaml
        fi

        # Parse the R10K_SOURCE url
        pattern='^(([[:alnum:]]+)://)?((([[:alnum:]]+)(:?([[:alnum:]]+)?))@)?([^:^@^/]+)(:([[:digit:]]+))?(/.*)'
        if [[ ${SOURCE[1]} =~ ${pattern} ]]; then
          protocol=${BASH_REMATCH[2]}
          #user=${BASH_REMATCH[5]}
          #password=${BASH_REMATCH[7]}
          host=${BASH_REMATCH[8]}
          port=${BASH_REMATCH[10]}
          #path=${BASH_REMATCH[11]}
        fi

        # Verify that the source URL is SSH
        if [[ "${protocol}" = 'ssh' ]]; then
          # If SSH host key checking and auto trust is turned on, connect to source and add host key
          if [[ ! "${STRICT_HOST_KEY_CHECKING}" = "false" && "${TRUST_SSH_FIRST_CONNECT}" = "true" ]]; then

            # set default ssh port of 22 if not indicated in the url
            port=${port:-22}

            # Check to see if the host already exists in known_hosts, if not, scan the host and add it
            # * Caution, known_hosts formats differently if alternate port specified
            if [[ "${port}" = "22" && ! "$(ssh-keygen -F ${host} -f /etc/puppetlabs/ssh/known_hosts -t rsa > /dev/null 2>&1)" ]]; then
              ssh-keyscan -p ${port} ${host} >> /etc/puppetlabs/ssh/known_hosts
            elif [[ ! "$(ssh-keygen -F [$host]:${port} -f /etc/puppetlabs/ssh/known_hosts -t rsa > /dev/null 2>&1)" ]]; then
              ssh-keyscan -p ${port} $host >> /etc/puppetlabs/ssh/known_hosts
            fi
          fi
        fi
      fi
    done
  fi


  # Run R10k to update local environments
  if [[ "${R10K_ON_STARTUP}" = "true" ]]; then
    r10k deploy environment -p -v
  fi

  # Apply current config for this instance. Use volumes retain config across container restarts
  if [[ "${RUN_PUPPET_AGENT_ON_START}" = "true" ]]; then
    puppet apply /etc/puppetlabs/code/environments/${AGENT_ENVIRONMENT}/manifests/site.pp -v
  fi
  echo 'Starting puppet server...'
fi

## Pass control on to the command supplied on the CMD line of the Dockerfile
## This makes puppetserver PID 1
exec "$@"
