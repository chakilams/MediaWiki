# Apache Profile

#### Table of Contents

1. [Overview](#overview)
2. [Usage](#usage)
3. [Development - Guide for contributing to the module](#development)

## Owner
Santosh Chakkilam

## Overview

This profile configures and installs apache 2.2  on RHEL6 and apache 2.4 on RHEL7 servers with standard setup. This includes default SSL support, apache modules, and allows standard apache ports in server firewall. 

This profiles uses puppetlabs apache forge module. (https://forge.puppet.com/puppetlabs/apache)

### Supported platforms
* RedHat 6,7

## Usage
### How to deploy
Simply include the `profile_apache::server` to the roles.

```role
include profile_apache::server
```
```yaml example
profile_apache::server::docroot: '/path/for/homedir/'
profile_apache::server::directoryindex: 'index.html index.html.var index.php'
profile_apache::server::robots: true
profile_apache::server::logrotate_keep: 30
profile_apache::server::logrotate_period: 'daily'
profile_apache::server::logrotate_compress: true
profile_apache::server::sudo_users:
  - '%AD\\sudo-group'
```

### PARAMETERS

The following lists all the class parameters this module accepts.

    CLASS PARAMETERS                    VALUES                              
    ------------------------------------------------------
    logrotate_period                    STRING

#### `logrotate_period`

Defines the time period for rotating the log files

Valid values: `weekly`, `daily`, `hourly`, `monthly`

Defaults: `weekly`.

`logrotate_period` will update the file `/etc/logrotate.d/apache` with the value specified.

### Custom Facts

N/A

## Development

For future development, email devops_team@servicedesk.com

