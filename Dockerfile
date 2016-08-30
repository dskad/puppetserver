FROM puppetagent
MAINTAINER Dan Skadra <dskadra@gmail.com>

ENV PATH="/opt/puppetlabs/server/bin:$PATH" \
PUPPETENV=production \
RUNINTERVAL=30m \
PUPPETSERVER_JAVA_ARGS="-Xms2g -Xmx2g" \
DNSALTNAMES="puppet,puppet.example.com" \
PUPPETDB_SERVER="localhost" \
PUPPETDB_PORT="8081"
## DEFAULT_R10K_REPO_URL
##  Set to the location of your default (bootstrap)
##  control repository for a fully functional puppet server setup. It is left blank here
##  so that this image can start up a self contained instance of puppetserver, with out the
##  need to set up a git repository and control repo
##    Example:
##      DEFAULT_R10K_REPO_URL="http://127.0.0.1/gituser/control-repo.git"
##
## R10K_FILE_URL
##  URL of a r10k.yaml file to use at container start up. This overides
##  DEFAULT_R10K_REPO_URL. This allows for the initial configuration of multiple
##  repositories.

## Set locale to en_US.UTF-8 prevent odd puppet errors in containers

## Latest by default, uncomment to pin specific versions or supply with --build-arg PUPPETSERVER_VERSION
## Requires docker-engine >= 1.9
## Examples:
##  --build-arg PUPPETSERVER_VERSION="2.3.*"
##  --build-arg PUPPETSERVER_VERSION="2.3.1"
# ARG PUPPETSERVER_VERSION

## Add puppet PC1 repo, install puppet server and support tool
## Note: Puppetserver creates the user and group puppet and drops the running server to these permissions
##       The following are owned by this user/group, the rest of the install is owned by root
##          /run/puppetlabs
##          /opt/puppetlabs/puppet/cache
##          /opt/puppetlabs/server/data
##          /var/log/puppetlabs/puppetserver (if it exists)
##          /etc/puppetlabs/puppet/ssl
# RUN yum -y install \
#       https://yum.puppetlabs.com/puppetlabs-release-pc1-el-7.noarch.rpm \
#       epel-release \
#   && yum -y update \
#   && yum -y install \
#       bash-completion \
#       ca-certificates \
#       git \
#       less \
#       logrotate \
#       which \
#   ## Puppetserver depends on the which command, so we need to install it with a separate yum install
#   ## Preinstalling puppetdb support files here as well
#   && yum -y install puppetserver${PUPPETSERVER_VERSION:+-}${PUPPETSERVER_VERSION} \
#       puppetdb-termini \
#       puppet-client-tools \
#   && yum clean all

# Install r10k and tools to manage puppet environments and modules
# RUN gem install r10k --no-document
COPY build_puppetserver.pp /build/build_puppetserver.pp
RUN puppet apply /build/build_puppetserver.pp -v

## r10k config template. Repo url gets updated in docker-entrypoint on start up from ENV
## If additional repos are needed, configure and refresh with puppet (eg. zack/r10k)
COPY r10k.yaml /etc/puppetlabs/r10k/r10k.yaml

## Setup ssh to us identification files in the r10k config directory
# COPY ssh-config /root/.ssh/config
# RUN chmod 700 /root/.ssh \
#   && chmod 600 /root/.ssh/config \

## Add custom fact to detect when puppetdb is on line.
## This will be used in the control repo to connect the server to puppetdb when it is available
COPY puppetdb_up.sh /opt/puppetlabs/facter/facts.d/puppetdb_up.sh

## This configures the pre-startup environment in the container
COPY docker-entrypoint.sh /docker-entrypoint.sh

RUN chmod +x /docker-entrypoint.sh \
  && chmod +x /opt/puppetlabs/facter/facts.d/puppetdb_up.sh \

  # Set JAVA_ARGS from the envir variable PUPPETSERVER_JAVA_ARGS
  && sed -i "s/\"-Xms2g -Xmx2g -XX:MaxPermSize=256m\"/\$PUPPETSERVER_JAVA_ARGS/" \
    /etc/sysconfig/puppetserver \

  # Fix forground command so it can listen for signals from docker
  && sed -i "s/runuser \"/exec runuser \"/" \
    /opt/puppetlabs/server/apps/puppetserver/cli/apps/foreground

# Add default site.pp for puppet environment
# COPY site.pp /etc/puppetlabs/code/environments/puppet/manifests/site.pp

# TODO This should go in puppetfile
# RUN puppet module install puppetlabs-puppetdb

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
