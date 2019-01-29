#!/usr/bin/bash

# Run R10k to update local environments
if [[ "${R10K_ON_STARTUP}" = "true" ]]; then
  r10k deploy environment -p -v
fi

# Apply current config for this instance. Use volumes retain config across container restarts
if [[ "${RUN_PUPPET_AGENT_ON_START}" = "true" ]]; then
  puppet apply /etc/puppetlabs/code/environments/${AGENT_ENVIRONMENT}/manifests/site.pp -v
fi
