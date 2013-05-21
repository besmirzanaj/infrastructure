class base {
  stage {'pre': before => Stage['main']}
  stage {'post': require => Stage['main']}

  class {'users':
    stage => 'pre',
  }

  class {'apt':
    always_apt_update => true
  }

  Exec['apt_update'] -> Package <| |>

  include private::users, postfix

  package {['mercurial', 'vim', 'emacs']: ensure => present}

  file {'/etc/timezone':
    ensure => file,
    owner => root,
    group => root,
    mode => 0644,
    content => 'UTC'
  }

  file {'/etc/localtime':
    ensure => link,
    target => '/usr/share/zoneinfo/UTC'
  }

  class {'logrotate':
    stage => 'post'
  }
}
