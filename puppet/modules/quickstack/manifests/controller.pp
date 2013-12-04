# Quickstack controller node
class quickstack::controller (
  $admin_email                  = $quickstack::params::admin_email,
  $admin_password               = $quickstack::params::admin_password,
  $bridge_interface             = $quickstack::params::bridge_interface,
  $ceilometer_metering_secret   = $quickstack::params::ceilometer_metering_secret,
  $ceilometer_user_password     = $quickstack::params::ceilometer_user_password,
  $cinder_backend_gluster       = $quickstack::params::cinder_backend_gluster,
  $cinder_backend_iscsi         = $quickstack::params::cinder_backend_iscsi,
  $cinder_db_password           = $quickstack::params::cinder_db_password,
  $cinder_gluster_peers         = $quickstack::params::cinder_gluster_peers,
  $cinder_gluster_volume        = $quickstack::params::cinder_gluster_volume,
  $cinder_user_password         = $quickstack::params::cinder_user_password,
  $cisco_nexus_plugin           = $quickstack::params::cisco_nexus_plugin,
  $cisco_vswitch_plugin         = $quickstack::params::cisco_vswitch_plugin,
  $controller_priv_floating_ip  = $quickstack::params::controller_priv_floating_ip,
  $controller_pub_floating_ip   = $quickstack::params::controller_pub_floating_ip,
  $glance_db_password           = $quickstack::params::glance_db_password,
  $glance_user_password         = $quickstack::params::glance_user_password,
  $heat_cfn                     = $quickstack::params::heat_cfn,
  $heat_cloudwatch              = $quickstack::params::heat_cloudwatch,
  $heat_db_password             = $quickstack::params::heat_db_password,
  $heat_user_password           = $quickstack::params::heat_user_password,
  $horizon_secret_key           = $quickstack::params::horizon_secret_key,
  $keystone_admin_token         = $quickstack::params::keystone_admin_token,
  $keystone_db_password         = $quickstack::params::keystone_db_password,
  $metadata_proxy_shared_secret = $quickstack::params::metadata_proxy_shared_secret,
  $mysql_host                   = $quickstack::params::mysql_host,
  $mysql_root_password          = $quickstack::params::mysql_root_password,
  $neutron                      = $quickstack::params::neutron,
  $neutron_db_password          = $quickstack::params::neutron_db_password,
  $neutron_user_password        = $quickstack::params::neutron_user_password,
  $nexus_config                 = $quickstack::params::nexus_config,
  $nexus_credentials            = $quickstack::params::nexus_credentials,
  $nova_db_password             = $quickstack::params::nova_db_password,
  $nova_user_password           = $quickstack::params::nova_user_password,
  $ovs_vlan_ranges              = $quickstack::params::ovs_vlan_ranges,
  $provider_vlan_auto_create    = $quickstack::params::provider_vlan_auto_create,
  $provider_vlan_auto_trunk     = $quickstack::params::provider_vlan_auto_trunk,
  $qpid_host                    = $quickstack::params::qpid_host,
  $tenant_network_type          = $quickstack::params::tenant_network_type,
  $auto_assign_floating_ip      = $quickstack::params::auto_assign_floating_ip,
  $verbose                      = $quickstack::params::verbose,
) inherits quickstack::params {

  class {'openstack::db::mysql':
    mysql_root_password  => $mysql_root_password,
    keystone_db_password => $keystone_db_password,
    glance_db_password   => $glance_db_password,
    nova_db_password     => $nova_db_password,
    cinder_db_password   => $cinder_db_password,
    neutron_db_password  => $neutron_db_password,

    # MySQL
    mysql_bind_address     => '0.0.0.0',
    mysql_account_security => true,

    allowed_hosts          => ['%',$controller_priv_floating_ip],
    enabled                => true,

    # Networking
    neutron                => str2bool("$neutron"),
  }

  class {'qpid::server':
    auth => "no"
  }

  class {'openstack::keystone':
    db_host                 => $mysql_host,
    db_password             => $keystone_db_password,
    admin_token             => $keystone_admin_token,
    admin_email             => $admin_email,
    admin_password          => $admin_password,
    glance_user_password    => $glance_user_password,
    nova_user_password      => $nova_user_password,
    cinder_user_password    => $cinder_user_password,
    neutron_user_password   => $neutron_user_password,

    public_address          => $controller_pub_floating_ip,
    admin_address           => $controller_priv_floating_ip,
    internal_address        => $controller_priv_floating_ip,

    glance_public_address   => $controller_pub_floating_ip,
    glance_admin_address    => $controller_priv_floating_ip,
    glance_internal_address => $controller_priv_floating_ip,

    nova_public_address     => $controller_pub_floating_ip,
    nova_admin_address      => $controller_priv_floating_ip,
    nova_internal_address   => $controller_priv_floating_ip,

    cinder_public_address   => $controller_pub_floating_ip,
    cinder_admin_address    => $controller_priv_floating_ip,
    cinder_internal_address => $controller_priv_floating_ip,

    neutron_public_address   => $controller_pub_floating_ip,
    neutron_admin_address    => $controller_priv_floating_ip,
    neutron_internal_address => $controller_priv_floating_ip,

    neutron                 => str2bool("$neutron"),
    enabled                 => true,
    require                 => Class['openstack::db::mysql'],
  }

  class { 'swift::keystone::auth':
    password         => $swift_admin_password,
    public_address   => $controller_pub_floating_ip,
    internal_address => $controller_priv_floating_ip,
    admin_address    => $controller_priv_floating_ip,
  }

  class {'openstack::glance':
    db_host        => $mysql_host,
    user_password  => $glance_user_password,
    db_password    => $glance_db_password,
    require        => Class['openstack::db::mysql'],
  }

  # Configure Nova
  class { 'nova':
    sql_connection     => "mysql://nova:${nova_db_password}@${mysql_host}/nova",
    image_service      => 'nova.image.glance.GlanceImageService',
    glance_api_servers => "http://${controller_priv_floating_ip}:9292/v1",
    rpc_backend        => 'nova.openstack.common.rpc.impl_qpid',
    verbose            => $verbose,
    require            => Class['openstack::db::mysql', 'qpid::server'],
  }

  class { 'nova::api':
    enabled           => true,
    admin_password    => $nova_user_password,
    auth_host         => $controller_priv_floating_ip,
    neutron_metadata_proxy_shared_secret => $metadata_proxy_shared_secret,
  }

  class { [ 'nova::scheduler', 'nova::cert', 'nova::consoleauth', 'nova::conductor' ]:
    enabled => true,
  }

  class { 'nova::vncproxy':
    host    => '0.0.0.0',
    enabled => true,
  }

  class { 'quickstack::ceilometer_controller':
    ceilometer_metering_secret  => $ceilometer_metering_secret,
    ceilometer_user_password    => $ceilometer_user_password,
    controller_priv_floating_ip => $controller_priv_floating_ip,
    controller_pub_floating_ip  => $controller_pub_floating_ip,
    qpid_host                   => $qpid_host,
    verbose                     => $verbose,
  }

  class { 'quickstack::cinder_controller':
    cinder_backend_gluster      => $cinder_backend_gluster,
    cinder_backend_iscsi        => $cinder_backend_iscsi,
    cinder_db_password          => $cinder_db_password,
    cinder_gluster_volume       => $cinder_gluster_volume,
    cinder_gluster_peers        => $cinder_gluster_peers,
    cinder_user_password        => $cinder_user_password,
    controller_priv_floating_ip => $controller_priv_floating_ip,
    mysql_host                  => $mysql_host,
    qpid_host                   => $qpid_host,
    verbose                     => $verbose,
  }

  class { 'quickstack::heat_controller':
    heat_cfn                    => $heat_cfn,
    heat_cloudwatch             => $heat_cloudwatch,
    heat_user_password          => $heat_user_password,
    heat_db_password            => $heat_db_password,
    controller_priv_floating_ip => $controller_priv_floating_ip,
    controller_pub_floating_ip  => $controller_pub_floating_ip,
    mysql_host                  => $mysql_host,
    qpid_host                   => $qpid_host,
    verbose                     => $verbose,
  }

  package {'horizon-packages':
    name   => ['python-memcached', 'python-netaddr'],
    notify => Class['horizon'],
  }

  file {'/etc/httpd/conf.d/rootredirect.conf':
    ensure  => present,
    content => 'RedirectMatch ^/$ /dashboard/',
    notify  => File['/etc/httpd/conf.d/openstack-dashboard.conf'],
  }

  class {'horizon':
    secret_key    => $horizon_secret_key,
    keystone_host => $controller_priv_floating_ip,
  }

  class {'memcached':}

  if str2bool("$neutron") {
    class { '::quickstack::neutron::controller':
      admin_email                  => $admin_email,
      admin_password               => $admin_password,
      bridge_interface             => $bridge_interface,
      cisco_nexus_plugin           => $cisco_nexus_plugin,
      cisco_vswitch_plugin         => $cisco_vswitch_plugin,
      controller_priv_floating_ip  => $controller_priv_floating_ip,
      controller_pub_floating_ip   => $controller_pub_floating_ip,
      mysql_host                   => $mysql_host,
      neutron_core_plugin          => $neutron_core_plugin,
      neutron_db_password          => $neutron_db_password,
      neutron_user_password        => $neutron_user_password,
      nexus_config                 => $nexus_config,
      nexus_credentials            => $nexus_credentials,
      ovs_vlan_ranges              => $ovs_vlan_ranges,
      provider_vlan_auto_create    => $provider_vlan_auto_create,
      provider_vlan_auto_trunk     => $provider_vlan_auto_trunk,
      qpid_host                    => $qpid_host,
      tenant_network_type          => $tenant_network_type,
      verbose                      => $verbose
    }
  }
  else {
    class { '::quickstack::nova_network::controller':
      auto_assign_floating_ip => $auto_assign_floating_ip,
    }
  }

  firewall { '001 controller incoming':
    proto    => 'tcp',
    dport    => ['80', '443', '3260', '3306', '5000', '35357', '5672', '8773', '8774', '8775', '8776', '9292', '6080'],
    action   => 'accept',
  }

  if ($::selinux != "false"){
    selboolean { 'httpd_can_network_connect':
      value => on,
      persistent => true,
    }
  }
}
