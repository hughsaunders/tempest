# encoding: UTF-8
default['openstack']['tempest'] = {
    'branch' => nil,
    'disable_ssl_validation' => false,
    'tenant_isolation' => true,
    'tenant_reuse' => true,
    'alt_ssh_user' => 'cirros',
    'ssh_user' => 'cirros',
    'user1' => {
        'user_name' => 'tempest_user1',
        'password' => 'tempest_user1_pass',
        'tenant_name' => 'tempest_tenant1'
    },
    'user2' => {
        'user_name' => 'tempest_user2',
        'password' => 'tempest_user2_pass',
        'tenant_name' => 'tempest_tenant1'
    },
    'test_img1' => {
        'id' => nil,
        'url' => 'http://launchpadlibrarian.net/83305348/cirros-0.3.0-x86_64-disk.img',
        'flavor' => 1
    },
    'admin' => 'admin',
    'admin_pass' => 'admin',
    'admin_tenant' => 'admin'
}
