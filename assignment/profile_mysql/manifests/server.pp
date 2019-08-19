class profile_mysql::server (

$mysql_repository        =   'enterprise',
$mysql_version           =   '56',
$dba_managed             =   true,
$allowed_hosts           =   undef,
$mysql_support_pkg       = ['mytop',
                            'jemalloc',
                            'mysql-utilities'],
$percona_support_pkg     = ['percona-xtrabackup',
                            'qpress',
                            'percona-toolkit'],
$config_file             =  '/etc/my.cnf',
$custom_config_file      =  false,
$manage_config_file      =  false,
$purge_conf_dir          =  false,
$root_password           =  undef,
$create_root_user        =  undef,
$root_my_cnf             =  undef,
$users                   =  {},
$grants                  =  {},
$databases               =  {},
$mysqluser               =  'mysql',
$mysqlgroup              =  'mysql',
$datadir                 = '/data/mysql',
$dba_sudo_access         = 'apache'

) {

accounts::account { 'mysql': } ->

exec {'make_datadir':
  unless  => "test -d $datadir",
  command => "mkdir -p $datadir",
  path    => $path,
  before  => Class['::mysql::server'],
}

file { $datadir:
  ensure  => directory,
  owner   => 'mysql',
  group   => 'mysql',
  before  => Class['::mysql::server'],
} 

file { "${datadir}/error.log":
  ensure   => file,
  owner   => 'mysql',
  group   => 'mysql',
  require => Class['::mysql::server'],
} 

file { ["${datadir}/mysql-5","${datadir}/mysql-5.index"]:
  ensure  => file,
  owner   => mysql,
  group   => mysql,
  require => Class['::mysql::server'],
} 

package { $mysql_support_pkg:
  ensure  => 'installed',
  before  => Class['::mysql::server'],
} 

case $mysql_repository {
  'enterprise': {


    if $mysql_version == '56' {
      $package_name = 'MySQL-server-advanced'
      $service_name = 'mysql'

      $mysql_enterprise_pkg    = ['MySQL-client-advanced',
                                  'MySQL-devel-advanced',
                                  'MySQL-embedded-advanced',
                                  'MySQL-shared-advanced',
                                  'MySQL-shared-compat-advanced',
                                  'MySQL-test-advanced']

      profile_satellite::repo{"org-rhel${::lsbmajdistrelease}-${::architecture}-mysql56":
        ensure => absent,
        before => Class['::mysql::server'],
      } 

      profile_satellite::repo{"org-rhel${operatingsystemmajrelease}-${architecture}-percona":
        ensure => present,
        before => Class['::mysql::server'],
      } 

      profile_satellite::repo{"org-rhel${::lsbmajdistrelease}-${::architecture}-mysql-enterprise":
        ensure => present,
        before => Class['::mysql::server'],
      } 

      # Package conlicts with MySQL-shared-advanced package
      file_line { 'yum_conf_mysql':
        ensure => present,
        path   => '/etc/yum.conf',
        line   => 'exclude=Percona-Server-shared*,mariadb*',
        before => [ Class['::mysql::server'],
                    Package[$mysql_support_pkg]
                  ]
      }

      package { $mysql_enterprise_pkg:
        ensure  => 'installed',
        before  => Class['::mysql::server'],
      }

      package { $percona_support_pkg:
        ensure  => 'installed',
        before  => Class['::mysql::server'],
      }

    } else {

      $package_name = 'mysql-commercial-server'
      $service_name = 'mysqld'


      # Package conlicts with MySQL package
      file_line { 'yum_conf_mysql':
        ensure => present,
        path   => '/etc/yum.conf',
        line   => 'exclude=mariadb*',
        before => [ Class['::mysql::server'],
                    Package[$mysql_support_pkg]
                  ]
      }

      profile_satellite::repo{"org-rhel${::lsbmajdistrelease}-${::architecture}-mysql56":
        ensure => absent,
        before => Class['::mysql::server'],
      } 

      profile_satellite::repo{"org-rhel${operatingsystemmajrelease}-${architecture}-percona":
        ensure => absent,
        before => Class['::mysql::server'],
      } 

      profile_satellite::repo{"org-rhel${::lsbmajdistrelease}-${::architecture}-mysql-enterprise":
        ensure => absent,
        before => Class['::mysql::server'],
      }
      profile_satellite::repo{"org-rhel${::lsbmajdistrelease}-${::architecture}-mysql-enterprise-${mysql_version}":
        ensure => present,
        before => Class['::mysql::server'],
      }
    }
  }
  'community': {
    $package_name = 'mysql-community-server'
    $service_name = 'mysqld'

    # Package conlicts with MySQL package
    file_line { 'yum_conf_mysql':
      ensure => present,
      path   => '/etc/yum.conf',
      line   => 'exclude=mariadb*',
      before => [ Class['::mysql::server'],
                  Package[$mysql_support_pkg]
                ]
    }

    profile_satellite::repo{"org-rhel${operatingsystemmajrelease}-${architecture}-percona":
      ensure => absent,
      before => Class['::mysql::server'],
    } 

    profile_satellite::repo{"org-rhel${::lsbmajdistrelease}-${::architecture}-mysql${mysql_version}":
      ensure => present,
      before => Class['::mysql::server'],
    } 

    profile_satellite::repo{"org-rhel${::lsbmajdistrelease}-${::architecture}-mysql-enterprise":
      ensure => absent,
      before => Class['::mysql::server'],
    }
  }
}

# Override the defaults for rhel7
$override_options = {
  'mysqld' => {
    log_error               => '/var/log/mysqld.log',
    datadir                 => $datadir,
  }
}

class { '::mysql::server':
  config_file             => $config_file,
  install_options         => undef,
  manage_config_file      => $manage_config_file,
  override_options        => $override_options,
  package_name            => $package_name,
  purge_conf_dir          => $purge_conf_dir,
  mysql_group             => $mysqlgroup,
  root_password           => $root_password,
  service_name            => $service_name,
  create_root_user        => $create_root_user,
  create_root_my_cnf      => $root_my_cnf,
  users                   => $users,
  grants                  => $grants,
  databases               => $databases,
} 

$piddir                  =  dirname($::mysql::server::options['mysqld']['pid-file'])
$socketdir               =  dirname($::mysql::server::options['mysqld']['socket'])
$logdir                  =  dirname($::mysql::server::options['mysqld']['log_error'])

if $custom_config_file {
  file { $config_file :
      replace => true,
      owner   => mysql,
      group   => mysql,
      source  => "puppet:///installer_files/DBA/${::environment}/${::fqdn}.cnf",
      mode    => '0644',
      before  => Class['mysql::server'],
  }
} else {
  file { $config_file :
      replace => false,
      owner   => mysql,
      group   => mysql,
      content => template('profile_mysql/my.cnf.erb'),
      mode    => '0644',
      before  => Class['mysql::server'],
}
}
  
# The mysql module does not manage these directories
# so we have to manage them here.
file { $piddir:
  ensure  => directory,
  owner   => mysql,
  group   => mysql,
  mode    => '0755',
}
file { "${logdir}/mysqld.log":
  ensure  => file,
  owner   => mysql,
  group   => mysql,
}

if ! ($socketdir == $datadir){
  file { $socketdir:
    ensure  => directory,
    owner   => mysql,
    group   => mysql,
    mode    => '0775',
  }
}


case $dba_managed {
  true: {

    if $dba_sudo_access == 'apache'{
      accounts::account { 'apache': }
      $sudo_access = 'apache'
    } else {
      accounts::account { 'apache':
        ensure => absent
      }
      $sudo_access = "%${dba_sudo_access}"
    }

    case $::operatingsystemrelease {
      /^6\.(.*)$/: {
        firewall_multi { '010 OEM Client TCP':
          dport  => 3872,
          proto  => tcp,
          source => 'oraem-a01.ad.org.com',
          action => accept,
        }

        firewall_multi { '010 OEM Client UDP':
          dport  => 3872,
          proto  => udp,
          source => 'oraem-a01.ad.org.com',
          action => accept,
        }

      }
      /^7\.(.*)$/: {
        firewalld_ipset { 'oemserver_whitelist':
            ensure => present,
            entries => gethostbyname2array('oraem-a01.ad.org.com')
          }

        firewalld_rich_rule { '010 OEM Client TCP':
          ensure => present,
          zone   => 'public',
          source => { 'ipset' => 'oemserver_whitelist', 'invert' => false },
          port => {
            'port' => 3872,
            'protocol' => tcp,
          },
          action  => 'accept',
        }
        firewalld_rich_rule { '010 OEM Client UDP':
          ensure => present,
          zone   => 'public',
          source => { 'ipset' => 'oemserver_whitelist', 'invert' => false },
          port => {
            'port' => 3872,
            'protocol' => udp,
          },
          action  => 'accept',
        }
      }
    }

    # set  acls

    posix_acl{ [ '/var/log/mysqld.log','/etc/my.cnf'] :
      action     => set,
      permission => $dba_sudo_access ? {
        'ccspsql' => ["user:apache:r--"],
        default   => ["group:${dba_sudo_access}:r--"],
      },
      provider   => posixacl,
      require    => $dba_sudo_access ? {
        'ccspsql' => User["apache"],
        default   => undef
      },
      recursive  => false,
    }

    posix_acl{'/var/run/mysqld' :
      action     => set,
      permission => $dba_sudo_access ? {
        'ccspsql' => ["user:apache:r-x",
                      "default:user:apache:rw-",
                      "default:mask::rw-",],
        default   => ["group:${dba_sudo_access}:r-x",
                      "default:group:${dba_sudo_access}:rw-",
                      "default:mask::rw-",],
      },
      provider   => posixacl,
      require    => $dba_sudo_access ? {
        'ccspsql' => User["apache"],
        default   => undef
      },
      recursive  => false,
    }

    posix_acl{[ "${datadir}",'/var/lib/mysql' ] :
      action     => set,
      permission => $dba_sudo_access ? {
        'ccspsql' => ["user:apache:rwx",
	              "group:apache:rwx",
                      "mask::rwx",
                      "default:user:apache:rwx",
		      "default:group:apache:rwx",
                      "default:mask::rwx"],
        default   => ["group:${dba_sudo_access}:rwx",
                      "mask::rwx",
                      "default:group:${dba_sudo_access}:rwx",
                      "default:mask::rwx"],
      },
      provider   => posixacl,
      require    => $dba_sudo_access ? {
        'ccspsql' => User["apache"],
        default   => undef
      },
      recursive  => true,
    }

    # sudo for dbas
    sudo::conf { 'mysql':
      content  => @("MYSQLSUDO"/L),
Cmnd_Alias DU = /usr/bin/du
Cmnd_Alias MYSQL_RESTART = /etc/rc.d/init.d/mysqld, /sbin/service mysqld *, /sbin/service mysql *, /etc/rc.d/init.d/mysql, /bin/systemctl * mysqld
Cmnd_Alias MYSQL_EDITMYCNF = /usr/bin/vim /etc/my.cnf, /bin/vi /etc/my.cnf
Cmnd_Alias TSM_LOG = /usr/bin/less /var/log/tsm-error_mysql.log, /bin/more /var/log/tsm-error_mysql.log, /bin/cat /var/log/tsm-error_mysql.log, /bin/grep * /var/log/tsm-error_mysql.log, /usr/bin/less /tmp/dsmsched_mysql.log, /bin/more /tmp/dsmsched_mysql.log, /bin/cat /tmp/dsmsched_mysql.log, /bin/grep * /tmp/dsmsched_mysql.log
Cmnd_Alias MESSAGES_LOG = /usr/bin/less /var/log/messages, /bin/more /var/log/messages, /bin/cat /var/log/messages, /bin/grep * /var/log/messages
Cmnd_Alias MYSQL_INSTALL = /usr/bin/mysql_install_db, /usr/bin/mysql_secure, /bin/chown mysql\:mysql -R /data/mysql/, /usr/bin/mysql_secure_installation, /usr/bin/mysqld_safe
Cmnd_Alias MYSQL_BACKUP = /bin/sh /opt/repostor/rdp4MySQL/bin/mysched.scr, /opt/repostor/rdp4MySQL/bin/mysched.scr, /opt/repostor/rdp4MySQL/bin/mysqlbackup, /opt/repostor/rdp4MySQL/bin/mysqlrestore, /opt/repostor/rdp4MySQL/bin/mysqlquery
Cmnd_Alias AGENT_INSTALL = /home/ccspsql/mysqlmonitoragent-*-linux-x86-64bit-installer.bin, /home/ccspsql/mysqlmonitoragent-*-linux-x86-64bit-update-installer.bin
Cmnd_Alias DSMCAD_MYSQL = /etc/init.d/dsmcad-mysql, /bin/systemctl * dsmcad-mysql

## Users allowed to use sudo
${sudo_access} ALL=MYSQL_RESTART, MYSQL_EDITMYCNF, MESSAGES_LOG, TSM_LOG, MYSQL_LOG, MYSQL_INSTALL, DU, AGENT_INSTALL, MYSQL_BACKUP, DSMCAD_MYSQL
| MYSQLSUDO
    }
  }
}

case $::operatingsystemrelease {
  /^6\.(.*)$/: {
    firewall_multi { '10 allow mysql access':
      dport  => 3306,
      proto  => tcp,
      source => $allowed_hosts,
      action => accept,
    }
    firewall_multi { '10 allow mysql access to naemon':
      dport  => 3306,
      proto  => tcp,
      source => $nrpe_allowed_hosts,
      action => accept,
    }
  }
  /^7\.(.*)$/: {
    if $allowed_hosts != undef {
      firewalld_ipset { 'mysql_whitelist':
        ensure => present,
        entries => $allowed_hosts
      }
    }
    firewalld_rich_rule { '10 allow mysql access':
      ensure => present,
      zone   => 'public',
      source => $allowed_hosts ? { 
		undef   => undef,
                default => { 'ipset' => 'mysql_whitelist', 'invert' => false },
 		},
      port => {
               'port' => 3306,
               'protocol' => 'tcp',
      },
      action  => 'accept',
    } ->
    firewalld_rich_rule { '10 allow mysql access to naemon':
      ensure => present,
      zone   => 'public',
      source => { 'ipset' => 'nrpe_whitelist', 'invert' => false },
      port => {
               'port' => 3306,
               'protocol' => 'tcp',
      },
      action  => 'accept',
    }
  }
}

cron { 'MySQL Weekly Maintenance':
ensure  => present,
  command  => '/usr/bin/mysqlcheck -aA',
  user     => root,
  hour     => 11,
  weekday  => 6,
}

sysctl { 'vm.nr_hugepages': value => '0' }
sysctl { 'kernel.sched_autogroup_enabled': value => '0' }
case $::operatingsystemrelease {
  /^6\.(.*)$/: {
    sysctl { 'kernel.sched_migration_cost': value => '5000000' }
  }
  /^7\.(.*)$/: {
    sysctl { 'kernel.sched_migration_cost_ns': value => '5000000' }
  }
}

limits::limits{'mysql/nofile':
  both => 65536,
}
limits::limits{'mysql/nproc':
  both => 65536,
}

logrotate::rule { 'mysql':
  path          => "${datadir}/*.log",
  rotate        => 10,
  rotate_every  => day,
  copytruncate  => true,
  compress      => true,
  ifempty       => false,
  missingok     => true,
  create        => true,
  create_mode   => '0640',
  create_owner  => 'mysql',
  create_group  => 'mysql',
}

# monitoring
nrpe::command{'procs-mysqld':
    ensure  => 'present',
    command => 'check_procs -C mysqld -w 1:1 -c 1:1',
}

}
