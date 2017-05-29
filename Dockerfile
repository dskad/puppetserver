FROM puppetagent

ENV PATH="/opt/puppetlabs/server/bin:$PATH" \
    FACTER_CONTAINER_ROLE="puppetserver"

COPY docker-entrypoint.sh /docker-entrypoint.sh
COPY hiera.yaml /build/hiera.yaml
# TODO Here be secrets (in common.yaml) This is cached in the build layers...
COPY common.yaml /build/data/common.yaml

# TODO Remove this once hosted online
COPY dskad-builder-0.1.0.tar.gz /build/dskad-builder-0.1.0.tar.gz

# TODO look into using vault or multi-stage build to conseal secrets
## Run puppet build bootstrap
RUN chmod +x /docker-entrypoint.sh && \
  # Make environment use hiera v5 layout
  rm -f /etc/puppetlabs/puppet/hiera.yaml && \
  rm -rf /etc/puppetlabs/code/environments/production/hieradata && \

  # Install module to bootstrap environment
  puppet module install -v --modulepath /build/modules /build/dskad-builder-0.1.0.tar.gz && \
  # puppet module install -v --modulepath /build/modules dskad-builder && \

  # setup r10k to retrieve current environments from supplied control repo
  puppet apply -v -e 'include builder::bootstrap' --modulepath /build/modules --hiera_config /build/hiera.yaml && \

  # Run R10k to pull latest config
  r10k deploy environment -p -v debug && \

  # Build the image according to the newly appled environment
  puppet apply -v --environment=puppet /etc/puppetlabs/code/environments/puppet/manifests/site.pp && \

  # Clean up
  puppet apply -v -e 'include builder::cleanup' --modulepath /build/modules --hiera_config /build/hiera.yaml && \

  # Clean up puppet cache from build process
  rm -rf /opt/puppetlabs/puppet/cache/* && \

  # Clean tmp
  find /tmp -mindepth 1 -delete && \

  # Remove build dir (secrets!)
  rm -rf /build && \

# Fix forground command so it can listen for signals from docker
  sed -i "s/runuser \"/exec runuser \"/" \
    /opt/puppetlabs/server/apps/puppetserver/cli/apps/foreground

## Save the important stuff!
VOLUME ["/etc/puppetlabs", \
        "/opt/puppetlabs/puppet/cache", \
        "/opt/puppetlabs/server/data", \
        "/var/log/puppetlabs" ]

EXPOSE 8140

ENTRYPOINT ["/docker-entrypoint.sh"]
CMD ["puppetserver", "foreground"]
