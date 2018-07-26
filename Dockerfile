FROM centos:7

LABEL maintainer="dskadra@gmail.com"

ENV PATH="$PATH:/opt/puppetlabs/bin:/opt/puppetlabs/puppet/bin:/opt/puppetlabs/server/bin" \
  FACTER_CONTAINER_ROLE="puppetserver" \
  DNS_ALT_NAMES="puppet,puppet.example.com" \
  JAVA_ARGS="-Xms2g -Xmx2g" \
  PUPPET_ADMIN_ENVIRONMENT="puppet-admin"

## Latest by default, un-comment to pin specific versions or supply with --build-arg PUPPETSERVER_VERSION
## Example:
## ARG PUPPETSERVER_VERSION="1.10.*"
## ARG PUPPETSERVER_VERSION="1.10.1"
## Requires docker-engine >= 1.9
ARG PUPPETSERVER_VERSION
ARG R10k_VERSION

## Current available releases: puppet5, puppet5-nightly, puppet6-nightly
ARG PUPPET_RELEASE="puppet5"

COPY docker-entrypoint.sh /docker-entrypoint.sh

RUN \
  # Import repository keys and add puppet repository
  rpm --import http://mirror.centos.org/centos/RPM-GPG-KEY-CentOS-7 \
  --import https://yum.puppetlabs.com/RPM-GPG-KEY-puppet && \
  rpm -Uvh https://yum.puppetlabs.com/${PUPPET_RELEASE}/${PUPPET_RELEASE}-release-el-7.noarch.rpm && \
  \
  # Update and install stuff
  yum -y update && \
  yum -y install \
  git \
  puppetserver${PUPPETSERVER_VERSION:+-}${PUPPETSERVER_VERSION} && \
  \
  # Install R10k via Ruby gem
  /opt/puppetlabs/puppet/bin/gem install r10k -N ${R10k_VERSION:+--version }${R10k_VERSION} && \
  \
  # Configure agent to use special environment
  puppet config set --section agent environment ${PUPPET_ADMIN_ENVIRONMENT} && \
  \
  # Setup paths for CA certificates (used when pulling from internal repo that is self or internal CA signed)
  mkdir -p /etc/puppetlabs/git/certs/ca && \
  git config --system http.sslCAPath /etc/puppetlabs/git/certs/ca && \
  \
  # Configure SSH to store keys in a location saved by volumes for R10k
  mkdir -p /etc/puppetlabs/ssh && \
  chmod 700 /etc/puppetlabs/ssh && \
  echo "IdentityFile /etc/puppetlabs/ssh/id_rsa" >> /etc/ssh/ssh_config && \
  echo "GlobalKnownHostsFile /etc/puppetlabs/ssh/known_hosts" >> /etc/ssh/ssh_config && \
  \
  # Update puppetserver configs to use JAVA_ARGS variable to configure java runtime
  sed "s/JAVA_ARGS=.*$/JAVA_ARGS=\"\$JAVA_ARGS\"/" /etc/sysconfig/puppetserver > /etc/default/puppetserver && \
  \
  # Fix 'puppetserver foreground' command so it can listen for signals from docker and exit gracefully
  sed -i "s/runuser \"/exec runuser \"/" /opt/puppetlabs/server/apps/puppetserver/cli/apps/foreground && \
  \
  # Cleanup
  chmod +x /docker-entrypoint.sh && \
  yum clean all && \
  rm -rf /var/cache/yum

COPY logback.xml /etc/puppetlabs/puppetserver/
COPY request-logging.xml /etc/puppetlabs/puppetserver/

## Save the important stuff!
VOLUME ["/etc/puppetlabs", \
  "/opt/puppetlabs/server/data/puppetserver" ]

EXPOSE 8140

ENTRYPOINT ["/docker-entrypoint.sh"]
CMD ["puppetserver", "foreground"]
