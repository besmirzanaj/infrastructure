class web::server(
    $vhost,
    $repository,
    $certificate = hiera('web::server::certificate', 'undef'),
    $private_key = hiera('web::server::private_key', 'undef'),
    $is_default = false,
    $aliases = undef,
    $custom_config = undef,
    $multiplexer_locations = undef,
) {

  include sitescripts
  include adblockplus::web
  include geoip

  $remote = hiera('web::server::remote', "https://hg.adblockplus.org/${repository}")

  $pythonpath = 'PYTHONPATH=/opt/cms:/opt/sitescripts'

  # Ensure there is at least one character in the respective strings;
  # see https://codereview.adblockplus.org/29329028/#msg3
  validate_re($vhost, '.+')
  validate_re($repository, '.+')

  File {
    owner  => 'root',
    group  => 'root',
    mode   => '0644',
  }

  Cron {
    environment => concat(hiera('cron::environment', []), [
      $pythonpath,
    ]),
  }

  class {'nginx':
    geoip_country => '/usr/share/GeoIP/GeoIPv6.dat',
  }

  # Make sure that apt packages corresponding to the pip-installed modules below
  # won't be installed unintentionally, these will take precedence otherwise.
  package {['python-jinja2', 'python-markdown']:
    ensure => 'held',
  }

  package {'Jinja2':
    ensure => '2.8',
    provider => 'pip',
    require => [Package['python-pip'], Package['python-jinja2']],
  }

  package {'markdown':
    ensure => '2.6.8',
    provider => 'pip',
    require => [Package['python-pip'], Package['python-markdown']],
  }

  nginx::hostconfig {$vhost:
    content => template('web/site.conf.erb'),
    global_config => template('web/global.conf.erb'),
    is_default => $is_default,
    certificate => $certificate ? {'undef' => undef, default => $certificate},
    private_key => $private_key ? {'undef' => undef, default => $private_key},
    log => "access_log_$vhost"
  }

  if $multiplexer_locations != undef {
    include spawn_fcgi

    spawn_fcgi::pool {"multiplexer":
      ensure => present,
      fcgi_app => '/opt/sitescripts/multiplexer.fcgi',
      socket => '/tmp/multiplexer-fastcgi.sock',
      mode => '0666',
      user => 'nginx',
      children => 1,
      require => [
        Class["sitescripts"],
      ],
    }
  }

  user {'www':
    ensure => present,
    comment => 'Web content owner',
    home => '/home/www',
    managehome => true,
  }

  $fetch_cms_cmd = [
    'hg', 'clone',
    'https://hg.adblockplus.org/cms/',
    '/opt/cms',
  ]

  Exec {
    path => ["/usr/bin/", "/bin/"],
  }

  exec {"fetch_cms":
    command => shellquote($fetch_cms_cmd),
    require => Class['adblockplus::mercurial'],
    timeout => 0,
    creates => "/opt/cms/.hg/hgrc",
  }

  $fetch_repo_cmd = [
    'hg', 'clone',
    '--update', 'master',
    $remote,
    "/home/www/${repository}",
  ]

  exec {"fetch_repo":
    command => shellquote($fetch_repo_cmd),
    require => Class['adblockplus::mercurial'],
    user => www,
    timeout => 0,
    creates => "/home/www/${repository}/.hg/hgrc",
  }

  $initialize_content_exec = [
    'python', '-m', 'cms.bin.generate_static_pages',
    "/home/www/${repository}", "/var/www/${vhost}",
  ]

  exec {"initialize_content":
    command => shellquote($initialize_content_exec),
    user => www,
    subscribe => [Exec["fetch_repo"], Exec["fetch_cms"]],
    refreshonly => true,
    environment => $pythonpath,
  }

  file {[
    "/var/cache/$repository",
    "/var/www/$vhost",
    "/var/www/docs",
  ]:
    ensure => directory,
    owner => www,
    mode => '0755',
  }

  $update_cms_cmd = [
    'hg', 'pull',
    '--quiet',
    '--rev', 'master',
    '--update',
    '--repository', '/opt/cms',
  ]

  cron {'update_cms':
    ensure => present,
    command => shellquote($update_cms_cmd),
    minute  => '4-59/20',
  }

  $update_repo_cmd = [
    'hg', 'pull',
    '--quiet',
    '--repository', "/home/www/${repository}",
  ]

  $update_webpage_cmd = join(
    [
      shellquote($update_repo_cmd),
      shellquote($initialize_content_exec)
    ],
    "&&"
  )

  cron {'update_repo':
    ensure => present,
    command => $update_webpage_cmd,
    user => www,
    minute  => '5-59/20',
  }

}
