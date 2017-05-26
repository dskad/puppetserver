FROM puppetagent

ENV PATH="/opt/puppetlabs/server/bin:$PATH" \
    FACTER_CONTAINER_ROLE="puppetserver"

COPY docker-entrypoint.sh /docker-entrypoint.sh
COPY hiera.yaml /etc/puppetlabs/code/environments/production/hiera.yaml
COPY common.yaml /etc/puppetlabs/code/environments/production/data/common.yaml

# TODO Remove this once hosted online
COPY dskad-builder-0.1.0.tar.gz /build/dskad-builder-0.1.0.tar.gz

## Run puppet build bootstrap
RUN chmod +x /docker-entrypoint.sh && \
  rm -f /etc/puppetlabs/puppet.hiera.yaml && \
  rm -rf /etc/puppetlabs/code/environments/production/hieradata && \

  # Install module to bootstrap environment
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
  # rm -rf /etc/puppetlabs/r10k/ssh/* && \

  # Clean tmp
  find /tmp -mindepth 1 -delete && \

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
