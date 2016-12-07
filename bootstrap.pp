$yum_packages = [
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

$gem_packages = [
  'r10k'
]

$puppet_modules = [
  'puppetlabs-puppetdb',
  'puppet-r10k'
]

package {$yum_packages:
  ensure => 'installed',
}

package {$gem_packages:
  ensure          => 'installed',
  provider        => 'gem',
  install_options => '--no-document',
}

# Make installing a module idempotent
$puppet_modules.each |$module| {
  exec { "puppet_module_${module}":
    command => "puppet module install ${module}",
    unless  => "puppet module list | grep ${module}",
    path    => ['/bin', '/opt/puppetlabs/bin'],
  }
}

# Save space
exec {'clean_yum':
  command => 'yum clean all',
  path    => ['/bin', '/usr/bin']
}

# Don't clean before we've installed everything
Package <| |> -> Exec['clean_yum']
