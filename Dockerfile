FROM centos:7

LABEL maintainer="dskadra@gmail.com"

ENV PATH="$PATH:/opt/puppetlabs/bin:/opt/puppetlabs/puppet/bin:/opt/puppetlabs/server/bin"
ENV FACTER_CONTAINER_ROLE="puppetserver"

## Current available releases: puppet5, puppet5-nightly, puppet6-nightly
ENV PUPPET_RELEASE="puppet5"

## Latest by default, un-comment to pin specific versions or supply with -e PUPPETSERVER_VERSION
## Example:
## ENV PUPPETSERVER_VERSION="5.3.*"
## ENV PUPPETSERVER_VERSION="5.3.4"
ENV PUPPETSERVER_VERSION=
ENV R10k_VERSION=
ENV HIERA_EYAML_VERSION=

RUN set -eo pipefail && if [[ -v DEBUG ]]; then set -x; fi && \
  # Import repository keys and add puppet repository
  rpm --import http://mirror.centos.org/centos/RPM-GPG-KEY-CentOS-7 \
  --import https://yum.puppetlabs.com/RPM-GPG-KEY-puppet && \
  rpm -Uvh https://yum.puppetlabs.com/${PUPPET_RELEASE}/${PUPPET_RELEASE}-release-el-7.noarch.rpm && \
  \
  # Update and install stuff
  yum -y update && \
  yum -y install \
  git \
  puppetserver${PUPPETSERVER_VERSION:+-}${PUPPETSERVER_VERSION} \
  puppetdb-termini && \
  \
  # Install Ruby gems for R10k and hiera-eyaml
  /opt/puppetlabs/puppet/bin/gem install r10k -N ${R10k_VERSION:+--version }${R10k_VERSION} && \
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
  echo "IdentityFile /etc/puppetlabs/ssh/id_rsa" >> /etc/ssh/ssh_config && \
  echo "GlobalKnownHostsFile /etc/puppetlabs/ssh/known_hosts" >> /etc/ssh/ssh_config && \
  \
  # Update puppetserver configs to use JAVA_ARGS variable to configure java runtime
  sed "s/JAVA_ARGS=.*$/JAVA_ARGS=\"\$JAVA_ARGS\"/" /etc/sysconfig/puppetserver > /etc/default/puppetserver && \
  \
  # Fix 'puppetserver foreground' command so it can listen for signals from docker and exit gracefully
  sed -i "s/runuser \"/exec runuser \"/" /opt/puppetlabs/server/apps/puppetserver/cli/apps/foreground && \
  \
  # Disable TLSv1 to be more secure
  sed -ri 's/#?(ssl-protocols:.*)TLSv1, (.*)/\1\2/' /etc/puppetlabs/puppetserver/conf.d/puppetserver.conf && \
  \
  # Cleanup
  chown -R puppet:puppet $(puppet config print confdir) && \
  yum clean all && \
  rm -rf /var/cache/yum

COPY logback.xml /etc/puppetlabs/puppetserver/
COPY request-logging.xml /etc/puppetlabs/puppetserver/
COPY docker-entrypoint.sh /docker-entrypoint.sh
COPY gen-ssh-keys /usr/local/bin/gen-ssh-keys

RUN chmod +x /docker-entrypoint.sh && \
  chmod +x /usr/local/bin/gen-ssh-keys

## Save the important stuff!
# VOLUME ["/etc/puppetlabs/code" ]

# Run time defaults
# To enable jruby9 in puppet5, set JRUBY_JAR to "/opt/puppetlabs/server/apps/puppetserver/jruby-9k.jar"
ENV JRUBY_JAR=
ENV JAVA_ARGS="-Xms2g -Xmx2g"
ENV CERTNAME=puppet.example.com
ENV DNS_ALT_NAMES="puppet,puppet.example.com"
ENV AGENT_ENVIRONMENT=production
ENV HEALTHCHECK_ENVIRONMENT="production"
ENV SERVER=puppet
ENV MASTERPORT=
ENV SSH_HOST_KEY_CHECK=true
ENV SHOW_SSH_KEY=false
ENV TRUST_SSH_FIRST_CONNECT=false
ENV R10K_ON_STARTUP=false
ENV R10K_SOURCE1=
ENV R10K_SOURCE2=
ENV AUTOSIGN=
ENV DISABLE_CA_SERVER=false
ENV CA_SERVER=
ENV CA_PORT=
ENV PUPPETDB_SERVER_URLS=

EXPOSE 8140

ENTRYPOINT ["/docker-entrypoint.sh"]
CMD ["puppetserver", "foreground"]

HEALTHCHECK --interval=30s --timeout=30s --retries=90 CMD \
  curl --fail -H 'Accept: pson' \
  --resolve "${HOSTNAME}:8140:127.0.0.1" \
  --cert   $(puppet config print hostcert) \
  --key    $(puppet config print hostprivkey) \
  --cacert $(puppet config print localcacert) \
  https://${HOSTNAME}:8140/${HEALTHCHECK_ENVIRONMENT}/status/test \
  | grep -q '"is_alive":true' \
  ||exit 1
