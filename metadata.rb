name              "tempest"
maintainer        "Rackspace Hosting, Inc."
license           "Apache 2.0"
description       "tempest module"
long_description  IO.read(File.join(File.dirname(__FILE__), 'README.md'))
version           "0.1.8"

%w{ ubuntu }.each do |os|
  supports os
end

%w{ osops-utils keystone glance }.each do |dep|
  depends dep
end
