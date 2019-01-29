FROM centos:7

LABEL maintainer="dskadra@gmail.com"

ENV PATH="$PATH:/opt/puppetlabs/bin:/opt/puppetlabs/puppet/bin:/opt/puppetlabs/server/bin" \
  FACTER_CONTAINER_ROLE="puppetserver"

# Current available releases: puppet5, puppet5-nightly, puppet6, puppet6-nightly
ARG PUPPET_RELEASE="puppet6"

# Latest by default, un-comment to pin specific versions or supply with -e PUPPETSERVER_VERSION
# Example:
# ENV PUPPETSERVER_VERSION="5.3.*"
# ENV PUPPETSERVER_VERSION="5.3.4"
ARG PUPPETSERVER_VERSION
ARG R10K_VERSION
ARG HIERA_EYAML_VERSION
ARG DUMB_INIT_VERSION="1.2.2"

RUN set -eo pipefail && if [[ -v DEBUG ]]; then set -x; fi && \
  # Import repository keys and add puppet repository
  rpm --import http://mirror.centos.org/centos/RPM-GPG-KEY-CentOS-7 \
  --import https://yum.puppet.com/RPM-GPG-KEY-puppet && \
  rpm -Uvh https://yum.puppet.com/${PUPPET_RELEASE}/${PUPPET_RELEASE}-release-el-7.noarch.rpm && \
  \
  # Update and install stuff
  yum -y update && \
  yum -y install \
  git \
  puppetserver${PUPPETSERVER_VERSION:+-}${PUPPETSERVER_VERSION} \
  puppetdb-termini && \
  \
  # Install dumb-init
  curl -Lo /usr/local/bin/dumb-init https://github.com/Yelp/dumb-init/releases/download/v${DUMB_INIT_VERSION}/dumb-init_${DUMB_INIT_VERSION}_amd64 && \
  chmod +x /usr/local/bin/dumb-init && \
  \
  # Install Ruby gems for R10k and hiera-eyaml
  /opt/puppetlabs/puppet/bin/gem install r10k -N ${R10K_VERSION:+--version }${R10K_VERSION} && \
  /opt/puppetlabs/puppet/bin/gem install hiera-eyaml -N ${HIERA_EYAML_VERSION:+--version }${HIERA_EYAML_VERSION} && \
  mkdir /etc/puppetlabs/r10k && \
  \
  # Set logs to display in container logs by default
  puppet config set --section master reports log && \
  \
  # Setup paths for CA certificates (used when pulling from internal repo that is self or internal CA signed)
  mkdir -p /etc/puppetlabs/git/ca && \
  git config --system http.sslCAPath /etc/puppetlabs/git/ca && \
  \
  # Configure SSH to store keys in a location saved by volumes for R10k
  mkdir -p /etc/puppetlabs/ssh && \
  chmod 700 /etc/puppetlabs/ssh && \
  echo "IdentityFile /etc/puppetlabs/ssh/id_key" >> /etc/ssh/ssh_config && \
  echo "IdentityFile /etc/puppetlabs/ssh/identity" >> /etc/ssh/ssh_config && \
  echo "IdentityFile /etc/puppetlabs/ssh/id_rsa" >> /etc/ssh/ssh_config && \
  echo "IdentityFile /etc/puppetlabs/ssh/id_dsa" >> /etc/ssh/ssh_config && \
  echo "IdentityFile /etc/puppetlabs/ssh/id_ecdsa" >> /etc/ssh/ssh_config && \
  echo "IdentityFile /etc/puppetlabs/ssh/id_ed25519" >> /etc/ssh/ssh_config && \
  echo "GlobalKnownHostsFile /etc/puppetlabs/ssh/known_hosts" >> /etc/ssh/ssh_config && \
  \
  # Disable TLSv1 and TLSv1.1 to be more secure
  sed -ri 's/#?(ssl-protocols:.*)TLSv1, TLSv1.1, (.*)/\1\2/' /etc/puppetlabs/puppetserver/conf.d/puppetserver.conf && \
  \
  # Cleanup
  chown -R puppet:puppet $(puppet config print confdir) && \
  yum clean all && \
  rm -rf /var/cache/yum

COPY config /etc/puppetlabs/puppetserver/
COPY docker-helper /
COPY bin /usr/local/bin/

RUN chmod +x \
  /docker-entrypoint.sh \
  /healthcheck.sh \
  /usr/local/bin/refresh-env-cache

# Save the important stuff!
# VOLUME ["/etc/puppetlabs/code", \
#   "/etc/puppetlabs/puppet/ssl", \
#   "/etc/puppetlabs/ssh", \
#   "/opt/puppetlabs/server/data/puppetserver" ]

# Configuration defaults
ENV JAVA_ARGS="-Xms2g -Xmx2g -Djruby.logger.class=com.puppetlabs.jruby_utils.jruby.Slf4jLogger" \
  DNS_ALT_NAMES="puppet,puppet.localhost" \
  AGENT_ENVIRONMENT="production" \
  HEALTHCHECK_ENVIRONMENT="production" \
  SOFT_WRITE_FAILURE="true" \
  ALLOW_SUBJECT_ALT_NAMES="true" \
  AUTOSIGN="true" \
  GENERATED_SSH_KEY_TYPE="ed25519"

EXPOSE 8140

ENTRYPOINT ["dumb-init", "/docker-entrypoint.sh"]
CMD ["puppetserver", "foreground"]
