FROM centos:7

LABEL maintainer="dskadra@gmail.com"

ENV PATH="$PATH:/opt/puppetlabs/bin:/opt/puppetlabs/puppet/bin:/opt/puppetlabs/server/bin" \
  FACTER_CONTAINER_ROLE="puppetserver" \
  container=docker \
  LANG=en_US.utf8 \
  TERM=linux

## Latest by default, un-comment to pin specific versions or supply with --build-arg PUPPETAGENT_VERSION
## Requires docker-engine >= 1.9
ARG PUPPETAGENT_VERSION
# ARG PUPPETAGENT_VERSION="1.10.*"
# ARG PUPPETAGENT_VERSION="1.10.1"

ARG CONFIG_ENV="puppet"

  ## Import repository keys
RUN rpm --import http://mirror.centos.org/centos/RPM-GPG-KEY-CentOS-7 \
  --import https://dl.fedoraproject.org/pub/epel/RPM-GPG-KEY-EPEL-7 \
  --import https://yum.puppetlabs.com/RPM-GPG-KEY-puppet && \
  \
  ## Add the proper puppet platform repo, install puppet agent and support tool
  ## The following are owned by the puppet user/group, the rest of the install is owned by root
  ##    /run/puppetlabs
  ##    /opt/puppetlabs/puppet/cache
  ##    /etc/puppetlabs/puppet/ssl
  rpm -Uvh https://yum.puppetlabs.com/puppet5/puppet5-release-el-7.noarch.rpm && \
  yum -y update && \
  yum -y install \
  # bash-completion \
  ca-certificates \
  less \
  # logrotate \
  which && \
  \
  ## puppet depends on which, so we need to install it with a separate yum command
  yum -y install puppet-agent${PUPPETAGENT_VERSION:+-}${PUPPETAGENT_VERSION} && \
  \
  # Make environment use hiera v5 layout
  #rm -f /etc/puppetlabs/puppet/hiera.yaml && \
  \
  yum clean all

COPY docker-entrypoint.sh /docker-entrypoint.sh

# TODO look into using vault or multi-stage build to conceal secrets
# TODO Here be secrets (in common.yaml) This is cached in the build layers...
COPY build /build

# TODO Remove this once hosted online
COPY dskad-builder-0.1.0.tar.gz /build/dskad-builder-0.1.0.tar.gz

## Run puppet build bootstrap
RUN chmod +x /docker-entrypoint.sh && \
  # Install module to bootstrap environment
  puppet module install -v --modulepath=/build/modules /build/dskad-builder-0.1.0.tar.gz && \
  # puppet module install -v --modulepath=/build/modules dskad-builder && \
  \
  # setup r10k to retrieve current environments from supplied control repo
  puppet apply -v -e 'include builder::bootstrap' --modulepath=/build/modules --hiera_config=/build/hiera.yaml && \
  \
  # Run R10k to pull latest config
  sleep 5 && \
  r10k deploy environment -p -v debug && \
  \
  # Build the image according to the newly applied environment
  puppet apply -v --environment=${CONFIG_ENV} /etc/puppetlabs/code/environments/${CONFIG_ENV}/manifests/site.pp && \
  \
  # Clean up
  puppet apply -v -e 'include builder::cleanup' --modulepath=/build/modules --hiera_config=/build/hiera.yaml && \
  \
  # Clean up puppet cache from build process
  rm -rf /opt/puppetlabs/puppet/cache/* && \
  rm -f /etc/puppetlabs/r10k/ssh/* && \
  \
  # Clean tmp
  # find /tmp -mindepth 1 -delete && \
  \
  # Remove build dir (secrets!)
  rm -rf /build && \
  \
# Fix foreground command so it can listen for signals from docker
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
