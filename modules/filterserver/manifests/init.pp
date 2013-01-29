class filterserver {
  
  class {'nginx':
    worker_processes => 4,
    worker_connections => 4000
  }

  class {'sitescripts':
    sitescriptsini_source => 'puppet:///modules/filterserver/sitescripts.ini'
  }
  
  package {'python-geoip':}

  user {'rsync':
    ensure => present,
    comment => 'Filter list mirror user',
    home => '/home/rsync',
    managehome => true
  }

  File {
    owner => root,
    group => root,
    mode => 0644,
  }

  file {'/var/www':
    ensure => directory
  }

  file {'/var/www/easylist':
    ensure => directory,
    require => [
                 File['/var/www'],
                 User['rsync']
               ],
    owner => rsync
  }
  
  file {'/etc/nginx/sites-available/inc.easylist-downloads':
    ensure => file,
    require => Anchor['nginx::begin'],
    before => Nginx::Hostconfig['easylist-downloads.adblockplus.org'],
    source => 'puppet:///modules/filterserver/inc.easylist-downloads'
  }

  file {'/etc/nginx/sites-available/inc.easylist-downloads-txt':
    ensure => file,
    require => Anchor['nginx::begin'],
    before => Nginx::Hostconfig['easylist-downloads.adblockplus.org'],
    source => 'puppet:///modules/filterserver/inc.easylist-downloads-txt'
  }

  file {'/etc/nginx/sites-available/inc.easylist-downloads-tpl':
    ensure => file,
    require => Anchor['nginx::begin'],
    before => Nginx::Hostconfig['easylist-downloads.adblockplus.org'],
    source => 'puppet:///modules/filterserver/inc.easylist-downloads-tpl'
  }

  file {'/etc/nginx/sites-available/easylist-downloads.adblockplus.org_sslcert.key':
    ensure => file,
    require => Anchor['nginx::begin'],
    before => Nginx::Hostconfig['easylist-downloads.adblockplus.org'],
    source => 'puppet:///modules/private/easylist-downloads.adblockplus.org_sslcert.key'
  }  
  
  file {'/etc/nginx/sites-available/easylist-downloads.adblockplus.org_sslcert.pem':
    ensure => file,
    require => Anchor['nginx::begin'],
    before => Nginx::Hostconfig['easylist-downloads.adblockplus.org'],
    mode => 0400,
    source => 'puppet:///modules/private/easylist-downloads.adblockplus.org_sslcert.pem'
  }  

  nginx::hostconfig{'easylist-downloads.adblockplus.org':
    source => 'puppet:///modules/filterserver/easylist-downloads.adblockplus.org',
    enabled => true
  }

  file {'/etc/logrotate.d/nginx_easylist-downloads.adblockplus.org':
    ensure => file,
    require => Nginx::Hostconfig['easylist-downloads.adblockplus.org'],
    source => 'puppet:///modules/filterserver/logrotate'
  }  

  file {'/home/rsync/.ssh':
    ensure => directory,
    require => User['rsync'],
    owner => rsync,
    mode => 0600;
  }

  file {'/home/rsync/.ssh/known_hosts':
    ensure => file,
    require => [
                 File['/home/rsync/.ssh'],
                 User['rsync']
               ],
    owner => rsync,
    mode => 0444,
    source => 'puppet:///modules/filterserver/known_hosts'
  }

  file {'/home/rsync/.ssh/id_rsa':
    ensure => file,
    require => [
                 File['/home/rsync/.ssh'],
                 User['rsync']
               ],
    owner => rsync,
    mode => 0400,
    source => 'puppet:///modules/private/rsync@easylist-downloads.adblockplus.org'
  }

  file {'/home/rsync/.ssh/id_rsa.pub':
    ensure => file,
    require => [
                 File['/home/rsync/.ssh'],
                 User['rsync']
               ],
    owner => rsync,
    mode => 0400,
    source => 'puppet:///modules/private/rsync@easylist-downloads.adblockplus.org.pub'
  }

  file {'/opt/cron_geoipdb_update.sh':
    ensure => file,
    mode => 0750,
    source => 'puppet:///modules/filterserver/cron_geoipdb_update.sh'
  }

  cron {'mirror':
    ensure => present,
    require => [
                 File['/home/rsync/.ssh/known_hosts'],
                 File['/home/rsync/.ssh/id_rsa'],
                 User['rsync']
               ],
    command => 'rsync -e ssh -ltprz rsync@adblockplus.org:. /var/www/easylist/',
    user => rsync,
    hour => '*',
    minute => '2-52/10'
  }

  cron {'mirrorstats':
    ensure => present,
    require => [
                User['rsync'],
		Package['python-geoip']
               ],
    command => 'xz -cd /var/log/nginx/access_log_easylist_downloads.1.xz | python -m sitescripts.logs.bin.extractSubscriptionStats',
    environment => 'PYTHONPATH=/opt/sitescripts',
    user => rsync,
    hour => 1,
    minute => 25
  }
  
  cron {'geoipdb_update':
    ensure => present,
    require => File['/opt/cron_geoipdb_update.sh'],
    command => '/opt/cron_geoipdb_update.sh',
    user => root,
    hour => 3,
    minute => 15,
    monthday => 3
  }

}