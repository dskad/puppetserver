#!/usr/bin/bash

# *** Puppet Server Config ***
#*******************
# Update puppetserver configs to use JAVA_ARGS variable to configure java runtime
[[ -n "${JAVA_ARGS}" ]] && sed -i "s/JAVA_ARGS=.*$/JAVA_ARGS=\"\$JAVA_ARGS\"/" /etc/sysconfig/puppetserver

# Should  be either 0 or unlimited. 0 is default, unlimited requires calling environment refresh API
if [[ -n "${ENVIRONMENT_TIMEOUT}" ]]; then
  puppet config set environment_timeout "${ENVIRONMENT_TIMEOUT}"
fi
