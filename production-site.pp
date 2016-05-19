node default {}

node 'MYLOCALHOST' {
  # Connect to puppetdb server
  if str2bool($facts['puppetdb_up']) == true {
    class { 'puppetdb::master::config':
      puppetdb_server         => $facts['puppetdb_server'],
      puppetdb_port           => $facts['puppetdb_port'],
      manage_report_processor => true,
      enable_reports          => true,
      manage_routes           => true,
      manage_storeconfigs     => true,
      strict_validation       => true,
      restart_puppet          => true,
      # puppetdb_soft_write_failure => true,
    }
  }
  else {
    class { 'puppetdb::master::config':
      puppetdb_server         => $facts['puppetdb_server'],
      puppetdb_port           => $facts['puppetdb_port'],
      manage_report_processor => false,
      enable_reports          => false,
      manage_routes           => false,
      manage_storeconfigs     => false,
      strict_validation       => false,
      restart_puppet          => false,

    }
  }
}

#########
node 'puppetdb.example.com' {
  class {'puppetdb::server':
    listen_address          => '0.0.0.0',
    manage_firewall         => false,
    puppetdb_service_status => running,
    ssl_deploy_certs        => true,
    node_ttl                => '15m',
    node_purge_ttl          => '30m',
  }
}

#########
node 'puppetexplorer.example.com' {
  puppetdb_servers => [['puppetdb','/api']],
  vhost_options    => {
    rewrites => [
      {
        rewrite_rule => ['^/api/metrics/v1/mbeans/puppetlabs.puppetdb.query.population:type=default,name=(.*)$  https://%{HTTP_HOST}/api/metrics/v1/mbeans/puppetlabs.puppetdb.population:name=$1 [R=301,L]']
      }
    ]
  }
}

##########
node 'puppetboard.example.com' {
  # Configure Apache on this server
  class { 'apache': }
  class { 'apache::mod::wsgi':
  wsgi_socket_prefix => '/var/run/wsgi',
  }
  # Configure Puppetboard
  class { 'puppetboard':
    manage_git        => 'latest',
    manage_virtualenv => 'latest',
    puppetdb_host     => 'puppetdb',
    # listen            => 'public',
  }
  class { 'puppetboard::apache::vhost':
    vhost_name => 'puppetboard.example.com',
    port       => 80,
  }
}
