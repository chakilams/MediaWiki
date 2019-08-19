class profile_apache::server(

$logrotate_period       = 'weekly',
$logrotate_keep         = 4,
$logrotate_compress     = false,

$sudo_users             = undef,
$manage_user            = true,
$manage_group           = true,

$docroot                = '/data/apache/htdocs', 
$cgiroot                = '/data/apache/cgi-bin',
$options                = 'FollowSymLinks',
$directoryindex         = 'index.html index.html.var',

$apache_name            = 'httpd',
$apache_version         = undef,

$ssl_cert               = '/etc/pki/tls/certs/localhost.crt',
$ssl_key                = '/etc/pki/tls/private/localhost.key',
$ssl_chain              = undef,
$managed_ssl            = true,
$sslciphersuite         = 'ECDHE-RSA-AES128-SHA256:AES128-GCM-SHA256:RC4:HIGH:!MD5:!aNULL:!EDH',
$status_allow           = [],
$access_log_file        = 'access_log',
$server_admin           = 'devops_admin@servicedesk.com',
$server_name            = $::fqdn,

$user                   = 'apache',
$group                  = 'apache',

$mpm                    = 'prefork',

$timeout                = '60',
$keepalive              = 'Off',
$keepalive_timeout      = '15',
$keepalive_requests     = '100',

$worker_serverlimit     = '16', 
$worker_maxclients      = '300',

$prefork_startservers   = '8',
$prefork_maxclients     = '256',
$prefork_maxreqsperchild = '4000',
$prefork_minspareservers = '5',
$prefork_maxspareservers = '20',

$servertokens           = 'OS',
$trace_enable           = 'off',

$mod_userdir            = false,
$mod_fastcgi            = false,
$mod_jk                 = false,
$mod_auth_cas           = false,
$mod_wsgi               = false,
$mod_fcgid              = false,
$ldap_oracle_fix        = false,
$mod_perl               = false,

$robots                 = false,

# CAS Defaults

$cas_loginurl           = 'https://cas.example.com/cas/login',
$cas_validateurl        = 'https://cas.example.com/cas/serviceValidate',
$cas_certificatepath    = '/etc/ssl/certs',
$cas_cookiepath         = '/var/cache/mod_auth_cas/',
$cas_version            = undef,
$cas_validatesaml       = 'on',
$cas_debug              = undef,
$cas_timeout            = 7200,
$cas_idle_timeout       = 3600,

$purge_configs          = true,

$apache_stats           = false,

) {

# Create the docroot & cgiroot directories 
exec {'make_docroot':
  unless  => "test -d $docroot",
  command => "mkdir -p $docroot",
  path    => $path
}->
exec {'make_cgiroot':
  unless  => "test -d $cgiroot",
  command => "mkdir -p $cgiroot",
  path    => $path
}

case $::operatingsystemrelease {
  /^7\.(.*)$/: {
    package { 'policycoreutils-python':
      ensure => installed,
    }

    exec { 'set_apache_docroot':
      command => "semanage fcontext -a -t httpd_sys_content_t ${docroot} && touch ${docroot}/.docrootperm",
      path    => '/bin:/usr/bin/:/sbin:/usr/sbin',
      creates => "${docroot}/.docrootperm",
      require => Package['policycoreutils-python'],
    }
    exec { 'set_apache_cgiroot':
      command => "semanage fcontext -a -t httpd_sys_content_t ${cgiroot} && touch ${cgiroot}/.cgirootperm",
      path    => '/bin:/usr/bin/:/sbin:/usr/sbin',
      creates => "${cgiroot}/.cgirootperm",
      require => Package['policycoreutils-python'],
    }
  }
  /^6\.(.*)$/: {
    if $apache_name == 'httpd24-httpd' {

      if ! defined(Class['profile_php::server']) {
        profile_satellite::repo{"rhel-${architecture}-server-${operatingsystemmajrelease}-rhscl-1": ensure => present}
      }

      file {'/etc/httpd':
        ensure  => link,
        target  => '/opt/rh/httpd24/root/etc/httpd',
        force   => true,
      }

      file {'/usr/sbin/apachectl':
        ensure => link,
        target => "/opt/rh/httpd24/root/usr/sbin/apachectl",
      }

      file {'/usr/sbin/httpd':
        ensure => link,
        target => "/opt/rh/httpd24/root/usr/sbin/httpd",
      }

      file {'/etc/init.d/httpd':
        ensure => link,
        target => '/etc/init.d/httpd24-httpd'
      }

      file {'/etc/sysconfig/httpd':
        ensure => link,
        target => '/opt/rh/httpd24/root/etc/sysconfig/httpd'
      }
    }  
  }
}

class {'apache':
  docroot                => $docroot,
  apache_name            => $apache_name,
  apache_version         => $apache_version,
  default_vhost          => false,
  default_ssl_vhost      => false,
  scriptalias            => $cgiroot,
  default_ssl_cert       => $ssl_cert,
  default_ssl_key        => $ssl_key,
  default_ssl_chain      => $ssl_chain,
  serveradmin            => $server_admin,
  manage_user            => $manage_user,
  manage_group           => $manage_group,
  user                   => $user,
  group                  => $group,
  mpm_module             => false,
  timeout                => $timeout,
  use_canonical_name     => 'off',
  keepalive              => $keepalive,
  keepalive_timeout      => $keepalive_timeout,
  max_keepalive_requests => $keepalive_requests,
  server_tokens          => $servertokens,
  trace_enable           => $trace_enable,
  purge_configs          => $purge_configs,
}

apache::custom_config {'docroot':
  priority => '00',
  content  => template('profile_apache/docroot.conf.erb'),
}

# Apache Modules 

class { 'apache::mod::ssl':
  ssl_cipher             => $sslciphersuite,
  package_name           => $apache_name ? {
    'httpd24-httpd'      => 'httpd24-mod_ssl',
    default              => undef,
  },
  ssl_cert               => $ssl_cert,
  ssl_key                => $ssl_key,
  ssl_ca                 => $ssl_chain,
}
if $mod_userdir{
  class {'apache::mod::userdir':}
}
class { 'apache::mod::status':
  allow_from => $status_allow,
}
class {'apache::mod::ldap':
  package_name           => $apache_name ? {
    'httpd24-httpd'      => 'httpd24-mod_ldap',
    default              => undef,
  },
}
if ! ($ldap_oracle_fix) {
  if ($apache_name != 'httpd24-httpd') {
    class {'apache::mod::authnz_ldap':}
  }
}
if $mod_fastcgi {
  class {'apache::mod::fastcgi':}
}
if $mod_jk {
  class {'apache::mod::jk':}
}
# Added conditional implementation of mod_perl
if $mod_perl {
  package {'mod_perl':
    ensure              => installed,
  }
  file { '/etc/httpd/conf.d/perl.conf':
    ensure              => file,
    owner               => 'root',
    group               => 'root',
    mode                => '0644',
    source              => "puppet:///environments/${::environment}/site/profile_apache/files/perl.conf",
    }
}
if $mod_auth_cas {
  class {'apache::mod::auth_cas':
    cas_login_url        => $cas_loginurl,
    cas_validate_url     => $cas_validateurl,
    cas_certificate_path => $cas_certificatepath,
    cas_cookie_path      => $cas_cookiepath,
    cas_version          => $cas_version,
    cas_validate_saml    => $cas_validatesaml,
    cas_debug            => $cas_debug,
    cas_timeout          => $cas_timeout,
    cas_idle_timeout     => $cas_idle_timeout,
  }
}
if $mod_wsgi {
  class { 'apache::mod::wsgi':
    wsgi_socket_prefix => "/var/run/wsgi",
  }
}
if $mod_fcgid {
  class { 'apache::mod::fcgid':
    options => {
      'AddHandler'            => 'fcgid-script fcg fcgi fpl',
      'FcgidIPCDir'           => '/var/run/mod_fcgid',
      'FcgidProcessTableFile' => '/var/run/mod_fcgid/fcgid_shm',
      'MaxRequestLen'         => '5242880',
    }
  }
}
if defined( Class['profile_shibboleth::client'] ) {

  class {'apache::mod::shib':
    mod_full_path => $::apache_version ? {
      /^2\.2\.(.*)$/ => '/usr/lib64/shibboleth/mod_shib_22.so',
      /^2\.4\.(.*)$/ => '/usr/lib64/shibboleth/mod_shib_24.so',
    },
  }

  apache::custom_config {'shib.conf':
    priority => '00',
    source  => "puppet:///environments/${::environment}/site/profile_apache/files/shib.conf",
  }
}
class {'apache::mod::headers':}
class {'apache::mod::info':}
class {'apache::mod::proxy':}
class {'apache::mod::proxy_balancer':}
class {'apache::mod::proxy_ajp':}
class {'apache::mod::proxy_connect':}
class {'apache::mod::disk_cache':}
class {'apache::mod::cgi':}
apache::mod {'proxy_ftp':}

if $mpm == 'prefork' {
  class {'apache::mod::prefork':
    startservers           => $prefork_startservers,
    minspareservers        => $prefork_minspareservers,
    maxspareservers        => $prefork_maxspareservers,
    maxclients             => $prefork_maxclients,
    maxrequestsperchild    => $prefork_maxreqsperchild,
  }
}
if $mpm == 'worker' {
  class {'apache::mod::worker':
    serverlimit            => $worker_serverlimit, 
    maxclients             => $worker_maxclients,
  }
}

apache::vhost { 'org-default':
  port                => 80,
  docroot             => $docroot,
  priority            => '99',
  scriptalias         => $cgiroot,
  serveradmin         => $server_admin,
  servername          => $server_name,
  add_default_charset => 'UTF-8',
  block               => scm,
  options             => $options,
  override            => 'All',
  directoryindex      => $directoryindex,
}


if $managed_ssl {
  
  include profile_naemon::profiles::https

  apache::vhost { 'org-default_ssl':
    port                => 443,
    ssl                 => true,
    docroot             => $docroot,
    priority            => '99',
    scriptalias         => $cgiroot,
    serveradmin         => $server_admin,
    servername          => $server_name,
    access_log_file     => "ssl_${access_log_file}",
    add_default_charset => 'UTF-8',
    block               => scm,
    options             => $options,
    override            => 'All',
    directoryindex      => $directoryindex,
  }
}

# robots.txt to keep robots away from htdocs
if $robots {
  file {"${docroot}/robots.txt":
    ensure  => file,
    content => "User-agent: *\nDisallow: /\n",
  }
} else {
  file {"${docroot}/robots.txt":
    ensure  => absent,
  }
}

logrotate::rule { 'apache':
  rotate_every  => $logrotate_period,
  rotate        => $logrotate_keep,
  path          => '/var/log/httpd/*log',
  compress      => $logrotate_compress,
  copytruncate  => true,
  missingok     => true,
  ifempty       => false,
  sharedscripts => true,
}

$sudo_isarry    = empty($sudo_users)
if ! $sudo_isarry {
  $sudo_users_lists  = join($sudo_users,",")
}

if $sudo_users != undef {
  sudo::conf { 'apache':
    priority => 10,
    content  => "${sudo_users_lists} ALL=APACHE_RESTART",
  }
}

if $apache_stats{
  file {'/usr/local/bin/apachestats.pl':
    ensure  => file,
    owner   => root,
    group   => root,
    mode    => 0755,
    source  => "puppet:///environments/${::environment}/site/profile_apache/files/apachestats.pl",
  }
  cron { apachestats:
    command => "/usr/local/bin/apachestats.pl",
    user    => root,
    hour    => 5,
    minute  => 0,
    ensure  => present
  }
  package { 'perl-DateTime': ensure => installed}
}

case $::operatingsystemrelease {
 /^6\.(.*)$/: {
  firewall { '100 allow http access':
    dport  => 80,
    proto  => tcp,
    action => accept,
  }
  firewall { '100 allow https access':
    dport  => 443,
    proto  => tcp,
    action => accept,
  }
 }
 /^7\.(.*)$/: {
  firewalld_rich_rule { '100 allow http access':
    ensure => present,
    zone   => 'public',
    port => {
     'port' => 80,
     'protocol' => 'tcp',
   },
    action  => 'accept',
  }
  firewalld_rich_rule { '100 allow https access':
    ensure => present,
    zone   => 'public',
    port => {
     'port' => 443,
     'protocol' => 'tcp',
   },
    action  => 'accept',
  }
 }
}

}
