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

$module_puppetdb = 'puppetlabs-puppetdb'
  exec { 'puppet_module_puppetdb':
    command => "puppet module install ${module_puppetdb}",
    unless  => "puppet module list | grep ${module_puppetdb}",
    path    => ['/bin', '/opt/puppetlabs/bin']
  }

file {'etc/puppetlabs/r10k/ssh':
  ensure  => directory,
  mode    => '0700',
  require => Package['r10k'],
}

file { '/root/.ssh':
  ensure => directory,
  mode   => '0700',
}

file { '/root/.ssh/config':
  ensure  => present,
  mode    => '0600',
  content => "Host *\n\tIdentityFile /etc/puppetlabs/r10k/ssh/id_rsa\n\tStrictHostKeyChecking no",
}

exec {'clean_yum':
  command => 'yum clean all',
  path    => ['/bin', '/usr/bin']
}

Package <| |> -> Exec['clean_yum']
