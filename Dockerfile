FROM puppetagent

ENV PATH="/opt/puppetlabs/server/bin:$PATH" \
    FACTER_CONTAINER_ROLE="puppetserver"

## Build time options
# Required
ARG FACTER_PUPPET_ENVIRONMENT="puppet"
ARG FACTER_BUILD_REPO="http://192.168.10.50/dan/control-puppet.git"

# Optional
#ARG FACTER_HOST_KEY="MyHostKey"
#ARG FACTER_GMS_TOKEN="MyAccessToken"
#ARG FACTER_GMS_PROJECT_NAME="MyUserName/MyProject"
#ARG FACTER_GMS_URL="https://gitlab.example.com"
#ARG FACTER_GMS_PROVIDER="gitlab"

COPY docker-entrypoint.sh /docker-entrypoint.sh

# TODO Remove this once hosted online
COPY dskad-builder-0.1.0.tar.gz /build/dskad-builder-0.1.0.tar.gz

## Run puppet build bootstrap
RUN chmod +x /docker-entrypoint.sh && \
  puppet module install /build/dskad-builder-0.1.0.tar.gz && \ #TODO remove this when hosted online
  # puppet module install dskad-builder -v && \

  # setup r10k to retrieve current environments from supplied control repo
  puppet apply -v -e 'include builder::bootstrap' && \

  # Run R10k to pull latest config
  r10k deploy environment -p -v debug && \

  # Build the image according to the newly appled environment
  puppet apply /etc/puppetlabs/code/environments/puppet/manifests/site.pp -v && \

  # Clean up
  puppet apply -v -e 'include builder::cleanup' && \

  # Clean up puppet cache from build process
  rm -rf /opt/puppetlabs/puppet/cache/* && \

  # Clean build SSH keys. New keys will be generated on 1st run
  rm -rf /etc/puppetlabs/r10k/ssh/* && \

  # Clean tmp
  find /tmp -mindepth 1 -delete && \

# Fix forground command so it can listen for signals from docker
  sed -i "s/runuser \"/exec runuser \"/" \
    /opt/puppetlabs/server/apps/puppetserver/cli/apps/foreground

## Save the important stuff!
## Note1: /var/cache/r10k needs to match the cachdir value in r10k.conf file
## Note2: /opt/puppetlabs/puppet/modules is not saved.
##        Use /etc/puppetlabs/code/modules for global modules
## Note3: /opt/puppetlabs/facter/facts.d is not saved.
##        Use /etc/puppetlabs/facter/facts.d for custom global facts
## TODO Add mcollective and pxp-agent volumes
VOLUME ["/etc/puppetlabs", \
        "/opt/puppetlabs/puppet/cache", \
        "/opt/puppetlabs/server/data", \
        "/var/log/puppetlabs" ]

EXPOSE 8140

ENTRYPOINT ["/docker-entrypoint.sh"]
CMD ["puppetserver", "foreground"]
