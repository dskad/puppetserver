FROM cent-sysd-puppet

MAINTAINER Dan Skadra <dskadra@gmail.com>

## Set locale to en_US.UTF-8 prevent odd puppet errors in containers
RUN localedef -i en_US -c -f UTF-8 -A /usr/share/locale/locale.alias en_US.UTF-8
ENV LANG en_US.utf8

## Latest by default, uncomment to pin specific versions or supply with --build-arg PUPPETSERVER_VERSION
## Requires docker-engine >= 1.9
ARG PUPPETSERVER_VERSION
# ARG PUPPETSERVER_VERSION="2.3.*"
# ARG PUPPETSERVER_VERSION="2.3.1"

ENV TERM=linux \
    PATH="/opt/puppetlabs/puppet/bin:/opt/puppetlabs/server/bin:$PATH" \
    BOOTSTRAPENV="bootstrap" \
    DNSALTNAMES="puppet,puppet.example.com"

## Add Facter environment variables to be used in puppet manifests
## e.x. "ENV FACTER_PUPPETSERVER=${PUPPETSERVER}"

## Add puppet PC1 repo, install puppet agent and clear ssl folder (to be regenerated in container)
## Note: Puppetserver creates the user and group puppet and drops the running server to these permissions
##       The following are owned by this user/group, the rest of the install is owned by root
##          /run/puppetlabs/puppetserver
##          /opt/puppetlabs/server/data/puppetserver/*
##          /var/log/puppetlabs/puppetserver/*
##          /etc/puppetlabs/puppet/ssl/*
RUN rpm --import http://mirror.centos.org/centos/RPM-GPG-KEY-CentOS-7 \
        --import https://dl.fedoraproject.org/pub/epel/RPM-GPG-KEY-EPEL-7 \
        --import https://yum.puppetlabs.com/RPM-GPG-KEY-puppetlabs \
    && yum -y install \
        https://yum.puppetlabs.com/puppetlabs-release-pc1-el-7.noarch.rpm \
        epel-release \
    && yum -y install \
        bash-completion \
        ca-certificates \
        git \
        less \
        which \
    && yum clean all

## Need to run this separatly. puppet user doesn't get created otherwise
RUN yum -y install puppetserver${PUPPETSERVER_VERSION:+-}${PUPPETSERVER_VERSION} \
    && yum clean all
RUN gem install r10k generate-puppetfile --no-document
COPY journal-console.service /usr/lib/systemd/system/journal-console.service
COPY logback.xml /etc/puppetlabs/puppetserver/logback.xml
COPY ezbake-functions.sh /opt/puppetlabs/server/apps/puppetserver/ezbake-functions.sh
RUN systemctl enable puppetserver.service
RUN systemctl enable puppet.service
RUN systemctl enable journal-console.service

EXPOSE 8140

## This ONBUILD section creates a derived image that will configure r10k for the
## users environment.

# TODO point this to github url when done.
## Use --build-arg R10KCONFIG when building a derived image to change the r10k config
## file location. URL are ok
ONBUILD ARG R10KCONFIG="r10k.yaml"
ONBUILD ADD ${R10KCONFIG} /etc/puppetlabs/r10k/r10k.yaml

## Save the important stuff!
## For the Agent
ONBUILD VOLUME /etc/puppetlabs
ONBUILD VOLUME /opt/puppetlabs/puppet/cache

# And puppetserver
ONBUILD VOLUME /opt/puppetlabs/server/data/puppetserver
ONBUILD VOLUME /var/log/puppetlabs

# Note: This needs to match the cachdir value in your r10k.conf file
#       Add an additional volume in derived docker files if the cachdir
#       is in a different location
ONBUILD VOLUME /var/cache/r10k
CMD ["/usr/sbin/init"]
