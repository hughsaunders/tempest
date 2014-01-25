name              'tempest'
maintainer        'Rackspace Hosting, Inc.'
license           'Apache 2.0'
description       'tempest module'
long_description  IO.read(File.join(File.dirname(__FILE__), 'README.md'))
version           IO.read(File.join(File.dirname(__FILE__), 'VERSION'))

%w{ ubuntu }.each do |os|
  supports os
end

%w{
    openstack-common
    openstack-identity
    openstack-image
    openstack-compute
    openstack-block-storage
    openstack-object-storage
}.each do |dep|
  depends dep
end
