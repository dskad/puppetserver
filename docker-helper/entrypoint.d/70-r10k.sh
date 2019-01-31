#!/usr/bin/bash

# *** Configure R10k ***
# ******************************
# If r10k.yaml doesn't exist, and source url(s) are supplied, build the basic r10k config file
if (compgen -A variable | grep -q '^R10K_SOURCE\n*'); then
  echo -e "---\n:cachedir: /opt/puppetlabs/server/data/puppetserver/r10k\n\n:sources:" > /etc/puppetlabs/r10k/r10k.yaml

  # TODO: allow custom basedir
  # If R10k sources are supplied via R10K_SOURCE* environment variables, add them to the r10k config file
  compgen -A variable | grep '^R10K_SOURCE\n*'| while read SOURCEVAR; do

    # looping through each R10K_SOURCE variables (R10K_SOURCE1, R10K_SOURCE2, etc)
    IFS=',' read -ra SOURCE <<< "${!SOURCEVAR}"

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
        if [[ "${port}" = "22" ]] && ! ssh-keygen -F ${host} -f /etc/puppetlabs/ssh/known_hosts > /dev/null 2>&1; then
          ssh-keyscan -p ${port} ${host} >> /etc/puppetlabs/ssh/known_hosts
        elif ! ssh-keygen -F [$host]:${port} -f /etc/puppetlabs/ssh/known_hosts > /dev/null 2>&1; then
          ssh-keyscan -p ${port} $host >> /etc/puppetlabs/ssh/known_hosts
        fi
      fi
    fi
  done
fi
