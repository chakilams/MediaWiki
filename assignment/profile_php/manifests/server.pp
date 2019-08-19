class profile_php::server (

    $short_open_tag             = 'Off',
    $error_reporting            = 'E_ALL & ~E_DEPRECATED',
    $memory_limit               = '128M',
    $file_uploads               = 'On',
    $upload_max_filesize        = '160M',
    $allow_url_fopen            = 'On',
    $post_max_size              = '161M',
    $upload_tmp_dir             = '/tmp',
    $enable_dl                  = 'Off',
    $session_entropy_length     = '0',
    $magic_quotes               = 'Off',
    $max_execution_time         = '30',
    $max_input_time             = '60',
    $max_input_vars             = '1000',
    $session_save_path          = '/var/lib/php/session',
    $php_package_name           = 'php',
    $inifile                    = '/etc/php.ini',

    $allow_url_include          = 'Off',
    $html_errors                = 'Off',

    $apache_group               = $profile_apache::server::group,

    $oci8_extension             = false,

    $use_memcache               = false,
    $memcache_conf_file         = '/etc/httpd/conf.d/memcache.php.conf',
    $memcache_hash_strategy     = 'consistent',
    $memcache_use_script        = true,
    $memcache_script_server     = 'localhost',
    $memcache_script_port       = '11211',
    $memcache_script_user       = 'memcache',
    $memcache_script_password   = 'm3mc4ch3',
    $memcache_script_path       = '/var/www/html/memcache.php',
    $memcache_script_allow_ips  = [],

    $apc_shm_size               = '256M',
    $apc_shm_segments           = '1',
    $apc_mmap_file_mask         = '/apc.shm.XXXXXX',

    $opcache_memory_consumption = 128,
    $opcache_revalidate_freq    = 0,


) inherits profile_apache::server {

if !($php_package_name =~ /^(php|php54|php56u|php71u)$/) {
  fail ("$php_package_name is not currently supported, please choose either: php, php54, php56u, php71u")
}

create_resources(php::module, hiera_hash('php::module', {}))

if $php_package_name == 'php' {

  $php_mod_prefix   = undef
  $php_inifile      = $inifile
  $session_php_path = $session_save_path

  profile_satellite::repo{"rhel-${architecture}-server-${operatingsystemmajrelease}-rhscl-1": ensure => absent}
  profile_satellite::repo{"org-rhel${operatingsystemmajrelease}-${architecture}-sc-php54": ensure => absent}
  profile_satellite::repo{"org-rhel${operatingsystemmajrelease}-${architecture}-ius": ensure => absent}

  case $::operatingsystemrelease {
    /^6\.(.*)$/: {
      $php_pecl = 'apc'
    }
  }
} elsif $php_package_name == 'php54' {

  case $::operatingsystemrelease {
    /^6\.(.*)$/: {
      $php_mod_prefix   = 'php54-php-'
      $php_inifile      = '/opt/rh/php54/root/etc/php.ini'
      $session_php_path = '/opt/rh/php54/root/var/lib/php/session'

      profile_satellite::repo{"rhel-${architecture}-server-${operatingsystemmajrelease}-rhscl-1": ensure => present}
      profile_satellite::repo{"org-rhel${operatingsystemmajrelease}-${architecture}-ius": ensure => absent}
      profile_satellite::repo{"org-rhel${operatingsystemmajrelease}-${architecture}-sc-php54": ensure => present}
    }
    /^7\.(.*)$/: {
      $php_mod_prefix = undef
      $session_php_path = $session_save_path
      $php_inifile      = $inifile

      profile_satellite::repo{"rhel-${architecture}-server-${operatingsystemmajrelease}-rhscl-1": ensure => absent}
      profile_satellite::repo{"org-rhel${operatingsystemmajrelease}-${architecture}-sc-php54": ensure => absent}
      profile_satellite::repo{"org-rhel${operatingsystemmajrelease}-${architecture}-ius": ensure => absent}
    }
  }
} else {

  $php_mod_prefix = "${php_package_name}-"
  $session_php_path = $session_save_path
  $php_inifile      = $inifile

  profile_satellite::repo{"rhel-${architecture}-server-${operatingsystemmajrelease}-rhscl-1": ensure => absent}
  profile_satellite::repo{"org-rhel${operatingsystemmajrelease}-${architecture}-sc-php54": ensure => absent}
  profile_satellite::repo{"org-rhel${operatingsystemmajrelease}-${architecture}-ius": ensure => present}

}

class { 'php::mod_php5':
  php_package_name         => $php_package_name ? {
    'php54'                => $::operatingsystemrelease ? {
      /^6\.(.*)$/          => 'php54',
      default              => undef,
    },
    default                => $php_package_name,
  },
  inifile                  => $php_inifile,
} ->

class { 'php::common':
  common_package_name      => $php_package_name ? {
    'php54'                => $::operatingsystemrelease ? { 
      /^7\.(.*)$/          => undef,
      default              => 'php54-php-common',
    },
    default                => "${php_package_name}-common",
  }
} ->

class { 'php::cli':
  cli_package_name         => $php_package_name ? {
    'php54'                => $::operatingsystemrelease ? {
      /^7\.(.*)$/          => undef,
      default              => 'php54-php-cli',
    },
    default                => "${php_package_name}-cli",
  },
  inifile                  => $php_inifile,
}

php::ini { $php_inifile:
  memory_limit             => $memory_limit,
  short_open_tag           => $short_open_tag,
  error_reporting          => $error_reporting,
  post_max_size            => $post_max_size,
  magic_quotes_gpc         => $magic_quotes,
  expose_php               => 'Off',
  max_execution_time       => $max_execution_time,
  max_input_time           => $max_input_time,
  max_input_vars           => $max_input_vars,
  enable_dl                => $enable_dl,
  file_uploads             => $file_uploads,
  upload_tmp_dir           => $upload_tmp_dir,
  upload_max_filesize      => $upload_max_filesize,
  allow_url_fopen          => $allow_url_fopen,
  session_entropy_length   => $session_entropy_length,
  session_save_path        => $session_php_path,
  date_timezone            => 'Europe/London',
  allow_url_include        => $allow_url_include,
  html_errors              => $html_errors,
  soap_wsdl_cache_dir      => php_package_name ? {
    'php'                  => '/tmp',
    'php54'                => '/tmp',
    default                => '/var/lib/php/wsdlcache',
  },
  user_ini_filename        => '',

}

# Default Modules to install

php::module { [ "${php_mod_prefix}mcrypt",
                "${php_mod_prefix}intl",
                "${php_mod_prefix}mbstring",
                "${php_mod_prefix}ldap",
                "${php_mod_prefix}pdo",
                "${php_mod_prefix}xmlrpc",
                "${php_mod_prefix}xml",
                "${php_mod_prefix}gd",
                "${php_mod_prefix}soap",
                "${php_mod_prefix}tidy" ]:
}

case $php_package_name {
  'php': {
    php::module { [ 'mysql',
                    'Smarty' ]:
    }
    case $::operatingsystemrelease {
      /^6\.(.*)$/: {
        php::module { ['domxml-php4-php5',
                       'pecl-apc']:
        }
      }
      /^7\.(.*)$/: {
        php::module { [ 'pecl-zendopcache' ]:}
      }
    }
  }
  'php54': {
    case $::operatingsystemrelease {
      /^6\.(.*)$/: {
        php::module { [ 'php54-php',
                        'php54-php-mysqlnd', 
		        'php54-php-pecl-zendopcache' ]:
        }
        $mysqlnd_enable = true

        file { '/opt/rh/php54/root/etc/php.d/opcache.ini':
          ensure => 'link',
          target => '/etc/php.d/opcache.ini',
          force  => true,
        }

        profiled::script { 'php54.sh':
          content => "source /opt/rh/php54/enable\n"
        }

        File<|title == '/etc/httpd/conf.d/php.conf'|> {
          content => '#NOT IN USE see 10-php54-php.conf#',
        }
      
        apache::custom_config {'php54-php':
          priority => '10',
          source  => "puppet:///environments/${::environment}/site/profile_php/files/php54-php.conf",
        }
      }
      /^7\.(.*)$/: {
        php::module { [ 'pecl-zendopcache' ]:}
      }
    }
  }
  'php56u': {
    php::module { [ 'php56u-mysqlnd',
                    'php56u-opcache',
                    'php56u-pear',
                    'php56u-process', ]:
    }
    $mysqlnd_enable = true
  }
  'php71u': {
    php::module { [ 'php71u-devel',
                    'php71u-json',
                    'php71u-mysqlnd',
                    'php71u-opcache',
                    'php71u-pecl-igbinary',
                    'php71u-pecl-igbinary-devel',
                    'php71u-process' ]:
    }

    $mysqlnd_enable = true

    File<|title == '/etc/httpd/conf.d/php.conf'|> {
      content => '#NOT IN USE see 10-php71-php.conf#',
    }

    apache::custom_config {'php71-php':
      priority => '10',
      source  => "puppet:///environments/${::environment}/site/profile_php/files/php71-php.conf",
    }
  }
}

if $php_pecl == 'apc' {

  php::module::ini { 'pecl-apc':
    settings => {
      'apc.enabled'                => '1',
      'apc.num_files_hint'         => '1024',
      'apc.user_entries_hint'      => '4096',
      'apc.ttl'                    => '7200',
      'apc.use_request_time'       => '1',
      'apc.user_ttl'               => '7200',
      'apc.gc_ttl'                 => '3600',
      'apc.cache_by_default'       => '1',
      'apc.filters'                => '',
      'apc.file_update_protection' => '2',
      'apc.enable_cli'             => '0',
      'apc.max_file_size'          => '1M',
      'apc.stat'                   => '1',
      'apc.stat_ctime'             => '0',
      'apc.canonicalize'           => '0',
      'apc.write_lock'             => '1',
      'apc.report_autofilter'      => '0',
      'apc.rfc1867'                => '0',
      'apc.rfc1867_prefix'         => 'upload_',
      'apc.rfc1867_name'           => 'APC_UPLOAD_PROGRESS',
      'apc.rfc1867_freq'           => '0',
      'apc.rfc1867_ttl'            => '3600',
      'apc.include_once_override'  => '0',
      'apc.lazy_classes'           => '00',
      'apc.lazy_functions'         => '0',
      'apc.coredump_unmap'         => '0',
      'apc.file_md5'               => '0',
      'apc.preload_path'           => '',
      'apc.shm_segments'           => $apc_shm_segments,
      'apc.shm_size'               => $apc_shm_size,
      'apc.nmap_file_mask'         => $apc_mmap_file_mask,
    }
  }
} else {

  php::module::ini { 'pecl-opcache':
    pkgname                        => $php_package_name ? {
      'php71u'                     => 'php71u-opcache',
      'php56u'                     => 'php56u-opcache',
      'php54'                      => $::operatingsystemrelease ? {
        /^6\.(.*)$/                => 'php54-php-pecl-zendopcache',
        default                    => 'pecl-zendopcache',
      },
      default                      => 'pecl-zendopcache',
    },
    zend                           => $php_package_name ? {
      'php54'                      => $::operatingsystemrelease ? {
        /^6\.(.*)$/                => '/opt/rh/php54/root/usr/lib64/php/modules',
        default                    => '/usr/lib64/php/modules',
      },
      default                      => '/usr/lib64/php/modules',
    },
    prefix                         => $php_package_name ? {
      'php56u'                     => '10',
      'php71u'                     => '10',
      default                      => undef,
    },

    settings => {
      'opcache.enabled'                 => '1',
      'opcache.memory_consumption'      => $opcache_memory_consumption,
      'opcache.interned_strings_buffer' => 8,
      'opcache.max_accelerated_files'   => 4000,
      'opcache.revalidate_freq'         => $opcache_revalidate_freq,
      'opcache.fast_shutdown'           => 1,
      'opcache.blacklist_filename'      => $php_package_name ? {
        'php54'                         => $::operatingsystemrelease ? {
          /^6\.(.*)$/                   => '/opt/rh/php54/root/etc/php.d/opcache*.blacklist',
          default                       => '/etc/php.d/opcache*.blacklist',
        },
        default                         => '/etc/php.d/opcache*.blacklist',
      }
    }
  }
}

php::module::ini { 'soap':
  pkgname                        => $php_package_name ? {
    'php71u'                     => 'php71u-soap',
    'php56u'                     => 'php56u-soap',
    'php54'                      => $::operatingsystemrelease ? {
      /^6\.(.*)$/                => 'php54-php-soap',
      default                    => "${php_mod_prefix}soap",
    },
    default                      => "${php_mod_prefix}soap",
  },
  prefix                         => $php_package_name ? {
    'php56u'                     => '20',
    'php71u'                     => '20',
    default                      => undef,
  },

  settings => {
    'soap.wsdl_cache_limit'      => 5,
  }
}

if $mysqlnd_enable {

  php::module::ini { 'mysqlnd':
    pkgname                               => $php_package_name ? {
      'php71u'                            => 'php71u-mysqlnd',
      'php56u'                            => 'php56u-mysqlnd',
      'php54'                             => $::operatingsystemrelease ? {
        /^6\.(.*)$/                       => 'php54-php-mysqlnd',
        default                           => "${php_mod_prefix}mysqlnd",
      },
      default                             => "${php_mod_prefix}mysqlnd",
    },
    prefix                                => $php_package_name ? {
      'php56u'                            => '20',
      'php71u'                            => '20',
      default                             => undef,
    },

    settings => {
      'mysqlnd.collect_statistics'        => 'On',
      'mysqlnd.collect_memory_statistics' => 'Off',
    }
  }

  php::module::ini { 'pdo_mysql':
    pkgname                               => $php_package_name ? {
      'php71u'                            => 'php71u-mysqlnd',
      'php56u'                            => 'php56u-mysqlnd',
      'php54'                             => $::operatingsystemrelease ? {
        /^6\.(.*)$/                       => 'php54-php-mysqlnd',
        default                           => "${php_mod_prefix}mysqlnd",
      },
      default                             => "${php_mod_prefix}mysqlnd",
    },
    prefix                                => $php_package_name ? {
      'php56u'                            => '30',
      'php71u'                            => '30',
      default                             => undef,
    },

    settings => {
      'pdo_mysql.cache_size'              => 2000,
      'pdo_mysql.default_socket'          => '',
    }
  }

  php::module::ini { 'mysqli':
    pkgname                               => $php_package_name ? {
      'php71u'                            => 'php71u-mysqlnd',
      'php56u'                            => 'php56u-mysqlnd',
      'php54'                             => $::operatingsystemrelease ? {
        /^6\.(.*)$/                       => 'php54-php-mysqlnd',
        default                           => "${php_mod_prefix}mysqlnd",
      },
      default                             => "${php_mod_prefix}mysqlnd",
    },
    prefix                                => $php_package_name ? {
      'php56u'                            => '30',
      'php71u'                            => '30',
      default                             => undef,
    },

    settings => {
      'mysqli.max_persistent'             => '-1',
      'mysqli.allow_persistent'           => 'On',
      'mysqli.cache_size'                 => 2000,
    }
  }
}

if $oci8_extension {
  profile_satellite::repo{"org-rhel${operatingsystemmajrelease}-${architecture}-php-oci8": ensure => present}
  php::module { 'oci8':
    name        => php_package_name ? {
    'php54'                => 'php54-php-oci8',
    'php56u'               => 'php56-php-oci8',
    'php71u'                => 'php71-php-oci8',
    default                => "${php_package_name}-oci8",
    }
  }
} else {
    profile_satellite::repo{"org-rhel${operatingsystemmajrelease}-${architecture}-php-oci8": ensure => absent}
}

file {$session_php_path:
  ensure  => directory,
  owner   => root,
  group   => $apache_group,
  require => Class['php::mod_php5'],
  mode    => '0770'
}


#Memcache PHP Settings
if $use_memcache {
  case $php_package_name {
    'php53': {
        php::module { [ 'php-pecl-memcache' ]:}
        $memcache_ini     = '/etc/php.d/memcache.ini'
     }
    'php54': {
        php::module { [ 'php-pecl-memcache' ]:}
        $memcache_ini     = '/opt/rh/php54/root/etc/php.d/memcache.ini'
     }
    'php56u': {
        php::module { [ 'php-pecl-memcache' ]:}
        $memcache_ini     = '/opt/rh/php56/root/etc/php.d/memcache.ini'
     }
    'php71u': {
        php::module { [ 'php-pecl-memcached' ]:}
        $memcache_ini     = '/opt/rh/php71/root/etc/php.d/memcache.ini'
     }
  }
  
  if $php_package_name == 'php54' {
    file { "/opt/rh/php54/root/etc/php.d/":
        ensure  => directory,
        owner   => 'root',
        group   => 'root',
        mode    => '0755',
    }
  }
  if $php_package_name == 'php56u' {
    file { "/opt/rh/php56/root/etc/php.d/":
        ensure  => directory,
        owner   => 'root',
        group   => 'root',
        mode    => '0755',
    }
  }
  if $php_package_name == 'php71u' {
    file { "/opt/rh/php71/root/etc/php.d/":
        ensure  => directory,
        owner   => 'root',
        group   => 'root',
        mode    => '0755',
    }
  }

  file { "$memcache_ini":
      ensure  => file,
      owner   => 'root',
      group   => 'root',
      mode    => '0644',
      content => template('profile_php/memcache.ini.erb'),
  }

  if $memcache_use_script {
      validate_array($memcache_script_allow_ips)

      file { 
        "${memcache_script_path}":
            ensure  => file,
            owner   => 'root',
            group   => 'root',
            content => template('profile_php/memcache.php.erb');
        "${memcache_conf_file}":
            ensure  => file,
            owner   => 'root',
            group   => 'root',
            content => template('profile_php/memcache.php.conf.erb'),
            notify  => Service['httpd'];
      }
  }
}

}
