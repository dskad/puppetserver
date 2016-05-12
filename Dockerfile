FROM centos:7
MAINTAINER Dan Skadra <dskadra@gmail.com>

## Latest by default, uncomment to pin specific versions or supply with --build-arg PUPPETSERVER_VERSION
## Requires docker-engine >= 1.9
## Examples:
##  --build-arg PUPPETSERVER_VERSION="2.3.*"
##  --build-arg PUPPETSERVER_VERSION="2.3.1"
ARG PUPPETSERVER_VERSION


ENV PATH="/opt/puppetlabs/bin:/opt/puppetlabs/puppet/bin:/opt/puppetlabs/server/bin:$PATH" \
    container=docker \
    LANG=en_US.utf8 \
    TERM=linux \
    PUPPETSERVER=puppet \
    PUPPETENV=bootstrap \
    RUNINTERVAL=5m \
    JAVA_ARGS="-Xms2g -Xmx2g"
    ## DEFAULT_R10K_REPO_URL should be set to the location of your default (bootstrap)
    ##  control repository for a fully functional puppet server setup. It is left blank here
    ##  so that this image can start up a self contained instance of puppetserver, with out the
    ##  need to set up a git repository and control repo
    ##    Example:
    ##      DEFAULT_R10K_REPO_URL="http://127.0.0.1/gituser/control-repo.git"
    ##
    ## DNSALTNAMES can't be empty here, so no default can be provided.
    ##  use '-e DNSALTNAMES="host,host2,etc"' on the command line to specify dns_alt_names
    ##  settings on initial container start up

## Set locale to en_US.UTF-8 prevent odd puppet errors in containers
RUN localedef -i en_US -c -f UTF-8 -A /usr/share/locale/locale.alias en_US.UTF-8

## Import repository keys
RUN rpm --import http://mirror.centos.org/centos/RPM-GPG-KEY-CentOS-7 \
        --import https://dl.fedoraproject.org/pub/epel/RPM-GPG-KEY-EPEL-7 \
        --import https://yum.puppetlabs.com/RPM-GPG-KEY-puppetlabs

## Add puppet PC1 repo, install puppet server and support tool
## Note: Puppetserver creates the user and group puppet and drops the running server to these permissions
##       The following are owned by this user/group, the rest of the install is owned by root
##          /run/puppetlabs
##          /opt/puppetlabs/puppet/cache
##          /opt/puppetlabs/server/data
##          /var/log/puppetlabs/puppetserver (if it exists)
##          /etc/puppetlabs/puppet/ssl
RUN yum -y install \
      https://yum.puppetlabs.com/puppetlabs-release-pc1-el-7.noarch.rpm \
      epel-release \
  && yum -y update \
  && yum -y install \
      bash-completion \
      ca-certificates \
      git \
      less \
      logrotate \
      which \
  ## Puppetserver depends on the which command, so we need to install it with a separate yum install
  ## Preinstalling puppetdb support files here as well
  && yum -y install puppetserver${PUPPETSERVER_VERSION:+-}${PUPPETSERVER_VERSION} \
      puppetdb-termini \
      puppet-client-tools \
  && yum clean all

## Clean up systemd folders to allow it to run in a container
## https://hub.docker.com/_/centos/
## Note: this needs to run after "yum update". If there is an upgrade to systemd/dbus
##      these files will get restored
RUN (cd /lib/systemd/system/sysinit.target.wants/; for i in *; \
  do [ $i == systemd-tmpfiles-setup.service ] || rm -f $i; \
  done); \
  rm -f /lib/systemd/system/multi-user.target.wants/*;\
  rm -f /etc/systemd/system/*.wants/*;\
  rm -f /lib/systemd/system/local-fs.target.wants/*; \
  rm -f /lib/systemd/system/sockets.target.wants/*udev*; \
  rm -f /lib/systemd/system/sockets.target.wants/*initctl*; \
  rm -f /lib/systemd/system/basic.target.wants/*;\
  rm -f /lib/systemd/system/anaconda.target.wants/*;

# Install r10k and tools to manage puppet environments and modules
RUN gem install r10k generate-puppetfile --no-document

## Files to send journal logs to stdout for docker logs
COPY journal-console.service /usr/lib/systemd/system/journal-console.service
COPY quiet-console.conf /etc/systemd/system.conf.d/quiet-console.conf
COPY logback.xml /etc/puppetlabs/puppetserver/logback.xml

## r10k config template. Repo url gets updated in docker-entrypoint on start up from ENV
## If additional repos are needed, configure and refresh with puppet (eg. zack/r10k)
COPY r10k.yaml /etc/puppetlabs/r10k/r10k.yaml

## This configures the pre-startup environment in the container
COPY docker-entrypoint.sh /docker-entrypoint.sh
RUN chmod +x /docker-entrypoint.sh

## Update puppet server to use /dev/tcp/localhost/8140 instead of netstat to determine when the
##    server is up. Netstat needs container privlidge escalations to run in a container.
RUN sed -i '/netstat -tulpn 2/c\(echo > /dev/tcp/localhost/8140) >/dev/null 2>&1' \
      /opt/puppetlabs/server/apps/puppetserver/ezbake-functions.sh

## Update puppet service to start after puppetserver is fully up. Preventing strange
##    errors in the logs.
RUN sed -i -e '/^After=/ s/$/ puppetserver.service/' \
      /usr/lib/systemd/system/puppet.service

## Enable config reload via systemctl command for puppetserver service
RUN grep -q ExecReload /usr/lib/systemd/system/puppetserver.service || \
    sed -i '/^KillMode=/ i\ExecReload=/bin/kill -HUP ${MAINPID}\n' \
      /usr/lib/systemd/system/puppetserver.service

## Enable services
RUN systemctl enable \
    puppetserver.service \
    puppet.service \
    journal-console.service

## Save the important stuff!
## Note1: /var/cache/r10k needs to match the cachdir value in r10k.conf file
## Note2: /opt/puppetlabs/puppet/modules is not saved.
##        Use /etc/puppetlabs/code/modules for global modules
## Note3: /opt/puppetlabs/facter/facts.d is not saved.
##        Use /etc/puppetlabs/facter/facts.d for custom global facts
## TODO Add mcollective and pxp-agent volumes
VOLUME ["/sys/fs/cgroup", \
        "/etc/puppetlabs", \
        "/opt/puppetlabs/puppet/cache", \
        "/opt/puppetlabs/server/data", \
        "/var/log/puppetlabs", \
        "/var/cache/r10k" ]

EXPOSE 8140

ENTRYPOINT ["/docker-entrypoint.sh"]
CMD ["/usr/sbin/init"]
