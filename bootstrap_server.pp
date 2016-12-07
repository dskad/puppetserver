# Configure SSH to store keys in a directory that is saved in a docker volume
file {'/etc/puppetlabs/r10k':
  ensure => directory,
}

file {['/etc/puppetlabs/r10k/ssh', '/root/.ssh']:
  ensure => directory,
  mode   => '0700',
}

# TODO This might need to be changed when droping root privlidges
#   Investigate using global config during build
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

class { 'r10k':
  remote     => 'http://192.168.10.50/dan/control.git',
  configfile => '/etc/puppetlabs/r10k/r10k.yaml',
  provider   => 'gem',
}

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
