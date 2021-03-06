name             'primero'
maintainer       'Pavel Nabutovsky, Quoin, Inc.'
maintainer_email 'pnabutov@quoininc.com'
license          'All rights reserved'
description      'Installs/Configures primero'
long_description IO.read(File.join(File.dirname(__FILE__), 'README.md'))
version          '0.1.0'

depends 'apt', '~> 2.3.8'
depends 'couchdb', '~> 2.5.0'
depends 'logrotate', '= 1.7.0'
depends 'nginx', '~> 2.4.2'
depends 'rvm', '~> 0.9.0'
depends 'sudo', '~> 2.7.1'
depends 'supervisor', '~> 0.4.12'
depends 'chef-unattended-upgrades', '= 1.0.1'
