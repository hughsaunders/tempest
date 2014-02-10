# encoding: UTF-8
#
# Cookbook Name:: tempest
# Recipe:: default
#
# Copyright 2012-2013, Rackspace US, Inc.
#
# Licensed under the Apache License, Version 2.0 (the 'License');
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an 'AS IS' BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

case node['platform_family']
when 'debian'
  %w{python-dev libxml2 libxslt1-dev libpq-dev}.each do |pkg|
    package pkg do
      action :install
    end
  end
when 'rhel'
  %w{libxslt-devel postgresql-devel}.each do |pkg|
    package pkg do
      action :install
    end
  end
end

%w{git python-unittest2 python-nose python-httplib2 python-paramiko python-testtools python-novaclient python-glanceclient testrepository python-testresources}.each do |pkg|
  package pkg do
    action :install
  end
end

identity_admin_endpoint = endpoint 'identity-admin'
identity_api_endpoint = endpoint 'identity-api'
bootstrap_token = secret 'secrets', 'openstack_identity_bootstrap_token'
auth_uri = ::URI.decode identity_admin_endpoint.to_s

openstack_identity_register 'Register tempest tenant 1' do
  auth_uri auth_uri
  bootstrap_token bootstrap_token
  tenant_name node['openstack']['tempest']['user1']['tenant_name']
  tenant_description 'Tempest tenant 1'

  action :create_tenant
end

openstack_identity_register 'Register tempest user 1' do
  auth_uri auth_uri
  bootstrap_token bootstrap_token
  tenant_name node['openstack']['tempest']['user1']['tenant_name']
  user_name node['openstack']['tempest']['user1']['user_name']
  user_pass node['openstack']['tempest']['user1']['password']

  action :create_user
end

openstack_identity_register "Grant 'member' Role to tempest user for tempest tenant #1" do
  auth_uri auth_uri
  bootstrap_token bootstrap_token
  tenant_name node['openstack']['tempest']['user1']['tenant_name']
  user_name node['openstack']['tempest']['user1']['user_name']
  role_name 'Member'

  action :grant_role
end

openstack_identity_register 'Register tempest tenant 2' do
  auth_uri auth_uri
  bootstrap_token bootstrap_token
  tenant_name node['openstack']['tempest']['user2']['tenant_name']
  tenant_description 'Tempest tenant 2'

  action :create_tenant
end

openstack_identity_register 'Register tempest user 2' do
  auth_uri auth_uri
  bootstrap_token bootstrap_token
  tenant_name node['openstack']['tempest']['user2']['tenant_name']
  user_name node['openstack']['tempest']['user2']['user_name']
  user_pass node['openstack']['tempest']['user2']['password']

  action :create_user
end

openstack_identity_register "Grant 'member' Role to tempest user for tempest tenant #2" do
  auth_uri auth_uri
  bootstrap_token bootstrap_token
  tenant_name node['openstack']['tempest']['user2']['tenant_name']
  user_name node['openstack']['tempest']['user2']['user_name']
  role_name 'Member'

  action :grant_role
end

# need to check that this is running on a node where glance is.  presumably
# this would be on a infra node
#
# if you don't want glance to upload images then set your own image id
#
if node['openstack']['tempest']['test_img1']['id'].nil?
  Chef::Log.info 'tempest/default: test_img1::id was nil so we are going to upload an image for you'
  openstack_image_image 'Image setup for cirros-tempest-test' do
    image_url node['openstack']['tempest']['test_img1']['url']
    image_name 'cirros-tempest-test'
    identity_user node['openstack']['tempest']['user1']['user_name']
    identity_pass node['openstack']['tempest']['user1']['password']
    identity_tenant node['openstack']['tempest']['user1']['tenant_name']
    identity_uri identity_admin_endpoint.to_s
    action :upload
  end
else
  Chef::Log.info "tempest/default Using image UUID #{node['openstack']['tempest']['test_img1']['id']} for tempest tests"
  img1_uuid = node['openstack']['tempest']['test_img1']['id']
end

git '/opt/tempest' do
  repository 'https://github.com/openstack/tempest'
  reference 'stable/havana'
  action :sync
end

execute 'clean_tempest_checkout' do
  command 'git clean -df'
  cwd '/opt/tempest'
  user 'root'
  action :nothing
end

# this is placed in a ruby block so we can use a notify when the image is updated and we can get the uuid of the image
if node['openstack']['tempest']['test_img1']['id'].nil?
  ruby_block 'get_image1_uuid' do
    action :create
    block do
      shell_cmd = "nova --no-cache --os-username=#{node['openstack']['tempest']['user1']['user_name']} "\
                  +"--os-password=#{node['openstack']['tempest']['user1']['password']} "
                  +"--os-tenant-name=#{node['openstack']['tempest']['user1']['tenant_name']} "\
                  +"--os-auth-url=#{identity_admin_endpoint.to_s} "\
                  +"image-show cirros-#{node['openstack']['tempest']['user1']['tenant_name']}-image "\
                  +"| awk '{if($2==\'id\') print $4}'"
      img1_uuid_test = Mixlib::ShellOut.new(shell_cmd)
      img1_uuid_test.run_command
      img1_uuid = img1_uuid_test.stdout
      img1_uuid.delete('\n')
      if img1_uuid.length > 0
        # guard against a failure in getting the UUID of the image.
        node.set['openstack']['tempest']['test_img1']['uuid'] = img1_uuid
      else
        node.set['openstack']['tempest']['test_img1']['uuid'] = 'Failed to get uploaded image id'
      end
    end
  end
else
  node.set['openstack']['tempest']['test_img1']['uuid'] = node['openstack']['tempest']['test_img1']['id']
end

#unless node['openstack']['identity']['users'][node['openstack']['identity']['admin_user']]['password'].nil?
#  node.set['openstack']['tempest']['admin_pass'] = node['keystone']['users'][keystone['admin_user']]['password']
#end
node.save

template '/opt/tempest/etc/tempest.conf' do
  source 'tempest.conf.erb'
  owner 'root'
  group 'root'
  mode '0644'
  variables(
            'tempest_disable_ssl_validation' => node['openstack']['tempest']['disable_ssl_validation'],
            'identity_endpoint_host' => identity_api_endpoint.host,
            'identity_endpoint_port' => identity_api_endpoint.port,
            'tempest_tenant_isolation' => node['openstack']['tempest']['tenant_isolation'],
            'tempest_tenant_reuse' => node['openstack']['tempest']['tenant_reuse'],
            'tempest_user1' => node['openstack']['tempest']['user1']['user_name'],
            'tempest_user1_pass' => node['openstack']['tempest']['user1']['password'],
            'tempest_user1_tenant' => node['openstack']['tempest']['user1']['tenant_name'],
            'tempest_img_flavor1' => node['openstack']['tempest']['test_img1']['flavor'],
            'tempest_img_flavor2' => node['openstack']['tempest']['test_img1']['flavor'],
            'tempest_admin' => node['openstack']['tempest']['admin'],
            'tempest_admin_tenant' => node['openstack']['tempest']['admin_tenant'],
            'tempest_admin_pass' => node['openstack']['tempest']['admin_pass'],
            'tempest_alt_ssh_user' => node['openstack']['tempest']['alt_ssh_user'],
            'tempest_ssh_user' => node['openstack']['tempest']['ssh_user'],
            'tempest_user2' => node['openstack']['tempest']['user2']['user_name'],
            'tempest_user2_pass' => node['openstack']['tempest']['user2']['password'],
            'tempest_user2_tenant' => node['openstack']['tempest']['user2']['tenant_name'],
            'tempest_img_ref1' => node['openstack']['tempest']['test_img1']['uuid'],
            'tempest_img_ref2' => node['openstack']['tempest']['test_img1']['uuid']
            )
end
