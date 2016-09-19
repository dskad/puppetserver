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

# Configure SSH to store keys in a directory we're saving. Setup for git
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
  content => @(EOT)
                Host *
                  IdentityFile /etc/puppetlabs/r10k/ssh/id_rsa
                  StrictHostKeyChecking no
                  UserKnownHostsFile /etc/puppetlabs/r10k/ssh/known_hosts
                  User git
                | EOT
}

# Save space
exec {'clean_yum':
  command => 'yum clean all',
  path    => ['/bin', '/usr/bin']
}

# Don't clean before we've installed everything
Package <| |> -> Exec['clean_yum']

# git_deploy_key { 'add_deploy_key_to_puppet_control':
#   ensure       => present,
#   name         => $::fqdn,
#   path         => '/etc/puppetlabs/r10k/ssh/id_rsa.pub',
##   token        => hiera('gitlab_api_token'),
#   token        => 'NuVxbpU6vubf5SoaXCof',
#   project_name => 'dan/control-repo',
#   server_url   => 'https://gitlab.example.com',
#   provider     => 'gitlab',
# }
