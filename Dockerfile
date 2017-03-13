FROM puppetagent

ENV PATH="/opt/puppetlabs/server/bin:$PATH" \
    FACTER_CONTAINER_ROLE="puppetserver"

# Build time options
ARG FACTER_PUPPET_ENVIRONMENT="puppet"
ARG FACTER_BUILD_REPO="http://gitlab.example.com/dan/control-puppet.git"
#ARG FACTER_HOST_KEY="MyHostKey"
#ARG FACTER_GSM_TOKEN="MyAccessToken"
#ARG FACTER_GSM_PROJECT_NAME="MyUserName/MyProject"
#ARG FACTER_GSM_URL="https://gitlab.example.com"
#ARG FACTER_GSM_PROVIDER="gitlab"

## DEFAULT_R10K_REPO_URL
##  Set to the location of your default (bootstrap)
##  control repository for a fully functional puppet server setup. It is left blank here
##  so that this image can start up a self contained instance of puppetserver, with out the
##  need to set up a git repository and control repo
##    Example:
##      DEFAULT_R10K_REPO_URL="http://127.0.0.1/gituser/control-repo.git"

COPY docker-entrypoint.sh /docker-entrypoint.sh

COPY dskad-builder-0.1.0.tar.gz /build/dskad-builder-0.1.0.tar.gz

## Run puppet build bootstrap
RUN chmod +x /docker-entrypoint.sh && \
  puppet module install /build/dskad-builder-0.1.0.tar.gz && \
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
#  rm -rf /etc/puppetlabs/r10k/ssh/* && \

# Fix forground command so it can listen for signals from docker
# TODO Can I do this in puppet?
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
        "/var/log/puppetlabs", \
        "/var/cache/r10k" ]

EXPOSE 8140

ENTRYPOINT ["/docker-entrypoint.sh"]
CMD ["puppetserver", "foreground"]
