FROM centos:7

LABEL maintainer="dskadra@gmail.com"

ENV PATH="$PATH:/opt/puppetlabs/bin:/opt/puppetlabs/puppet/bin:/opt/puppetlabs/server/bin" \
  FACTER_CONTAINER_ROLE="puppetserver" \
  LANG=en_US.utf8 \
  TERM=linux

# Only used on first run when there is no server certificate yet, ignored otherwise
#ENV DNS_ALT_NAMES


## Latest by default, un-comment to pin specific versions or supply with --build-arg PUPPETSERVER_VERSION
## Example:
## ARG PUPPETSERVER_VERSION="1.10.*"
## ARG PUPPETSERVER_VERSION="1.10.1"
## Requires docker-engine >= 1.9
ARG PUPPETSERVER_VERSION
ARG R10k_VERSION

## Current available releases: puppet5, puppet5-nightly, puppet6-nightly
ARG PUPPET_RELEASE="puppet5"

# TODO look into using vault or multi-stage build to conceal secrets
# TODO Here be secrets (in common.yaml) This is cached in the build layers...
COPY build /build

COPY docker-entrypoint.sh /docker-entrypoint.sh

## Add the proper puppet platform repo, install puppet agent and support tool
## The following are owned by the puppet user/group, the rest of the install is owned by root
##    /run/puppetlabs
##    /opt/puppetlabs/puppet/cache
##    /etc/puppetlabs/puppet/ssl
RUN rpm -Uvh https://yum.puppetlabs.com/${PUPPET_RELEASE}/${PUPPET_RELEASE}-release-el-7.noarch.rpm && \
  yum -y update && \
  yum -y install \
  git \
  puppetserver${PUPPETSERVER_VERSION:+-}${PUPPETSERVER_VERSION} && \
  yum clean all && \
  rm -rf /var/cache/yum && \
  ## Install R10k and configure for running in a container
  sed "s/JAVA_ARGS=.*$/JAVA_ARGS=\"\$JAVA_ARGS -Dlogappender=STDOUT\"/" /etc/sysconfig/puppetserver > /etc/default/puppetserver && \
  /opt/puppetlabs/puppet/bin/gem install r10k -N ${R10k_VERSION:+--version }${R10k_VERSION} && \
  puppet config set --section agent environment docker_puppetserver && \
  mkdir -p /etc/puppetlabs/git/certs/ca && \
  git config --system http.sslCAPath /etc/puppetlabs/git/certs/ca && \
  mkdir -p /etc/puppetlabs/ssh && \
  chmod 700 /etc/puppetlabs/ssh && \
  echo "IdentityFile /etc/puppetlabs/ssh/id_rsa" >> /etc/ssh/ssh_config && \
  echo "GlobalKnownHostsFile /etc/puppetlabs/ssh/known_hosts" >> /etc/ssh/ssh_config && \
  # Install module to bootstrap environment
  # puppet module install -v --modulepath=/build/modules /build/dskad-builder-0.1.0.tar.gz && \
  # puppet module install -v --modulepath=/build/modules dskad-builder && \
  \
  # setup r10k to retrieve current environments from supplied control repo
  # puppet apply -v -e 'include builder::bootstrap' --modulepath=/build/modules --hiera_config=/build/hiera.yaml && \
  \
  # Run R10k to pull latest config
  # r10k deploy environment -p -v debug && \
  \
  # Build the image according to the newly applied environment
  # puppet apply -v --environment=docker_puppetserver /etc/puppetlabs/code/environments/${CONFIG_ENV}/manifests/site.pp && \
  \
  # Clean up
  # puppet apply -v -e 'include builder::cleanup' --modulepath=/build/modules --hiera_config=/build/hiera.yaml && \
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
  chmod +x /docker-entrypoint.sh
# Fix foreground command so it can listen for signals from docker
#sed -i "s/runuser \"/exec runuser \"/" \
#/opt/puppetlabs/server/apps/puppetserver/cli/apps/foreground

## Save the important stuff!
VOLUME ["/etc/puppetlabs", \
  "/opt/puppetlabs/puppet/cache", \
  "/opt/puppetlabs/server/data", \
  "/var/log/puppetlabs" ]

EXPOSE 8140

ENTRYPOINT ["/docker-entrypoint.sh"]
CMD ["puppetserver", "foreground"]
