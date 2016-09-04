$server_packages = [
    'bash-completion',
    'ca-certificates',
    'git',
    'less',
    'logrotate',
    'which',
    'puppetserver',
    'puppetdb-termini',
    'puppet-client-tools'
    ]

package {$server_packages: ensure => 'installed' }

package {'r10k':
  ensure          => 'installed',
  provider        => 'gem',
  install_options => '--no-document',
}

exec { 'puppet_module_puppetdb':
  command => 'puppet module install puppetlabs-puppetdb',
  unless  => 'puppet module list | grep puppetlabs-puppetdb',
  path    => ['/bin', '/opt/puppetlabs/bin']
}

file {'/etc/puppetlabs/r10k':
  ensure => directory,
}

file {['/etc/puppetlabs/r10k/ssh', '/root/.ssh']:
  ensure => directory,
  mode   => '0700',
}

file { '/root/.ssh/config':
  ensure  => present,
  mode    => '0600',
  content => 'Host *\n' \
              '  IdentityFile /etc/puppetlabs/r10k/ssh/id_rsa\n' \
              '  StrictHostKeyChecking no\n' \
              '  UserKnownHostsFile /etc/puppetlabs/r10k/ssh/known_hosts' \
              '  User git',
}

exec {'clean_yum':
  command => 'yum clean all',
  path    => ['/bin', '/usr/bin']
}

Package <| |> -> Exec['clean_yum']
