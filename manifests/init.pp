# Installs, configures, and manages nomad
#
# @example To set up a single nomad server, with several agents attached, on the server.
#   class { '::nomad':
#     version     => '1.0.1', # check latest version at https://github.com/hashicorp/nomad/blob/master/CHANGELOG.md
#     config_hash => {
#       'region'     => 'us-west',
#       'datacenter' => 'ptk',
#       'log_level'  => 'INFO',
#       'bind_addr'  => '0.0.0.0',
#       'data_dir'   => '/opt/nomad',
#       'server'     => {
#         'enabled'          => true,
#         'bootstrap_expect' => 3,
#       }
#     }
#   }
#
# @example On the agent(s)
#   class { 'nomad':
#     config_hash => {
#         'region'     => 'us-west',
#         'datacenter' => 'ptk',
#         'log_level'  => 'INFO',
#         'bind_addr'  => '0.0.0.0',
#         'data_dir'   => '/opt/nomad',
#         'client'     => {
#         'enabled'    => true,
#         'servers'    => [
#           "nomad01.your-org.pvt:4647",
#           "nomad02.your-org.pvt:4647",
#           "nomad03.your-org.pvt:4647"
#         ]
#       }
#     },
#   }
#
# @example Disable install and service components
#   class { '::nomad':
#     install_method => 'none',
#     init_style     => false,
#     manage_service => false,
#     config_hash   => {
#       'region'     => 'us-west',
#       'datacenter' => 'ptk',
#       'log_level'  => 'INFO',
#       'bind_addr'  => '0.0.0.0',
#       'data_dir'   => '/opt/nomad',
#       'client'     => {
#       'enabled'    => true,
#       'servers'    => [
#           "nomad01.your-org.pvt:4647",
#           "nomad02.your-org.pvt:4647",
#           "nomad03.your-org.pvt:4647"
#         ]
#       }
#     },
#   }
#
# @param arch
#     cpu architecture
# @param manage_user
#     manage the user that will run nomad
# @param user
#     username
# @param manage_group
#     manage the group that will run nomad
# @param extra_groups
#     additional groups to add the nomad user
# @param purge_config_dir
#     Purge config files no longer generated by Puppet
# @param group
#     groupname
# @param join_wan
#     join nomad cluster over the WAN
# @param bin_dir
#     location of the nomad binary
# @param version
#     Specify version of nomad binary to download.
# @param install_method
#     install via system package, download and extract from a url.
# @param os
#     operation system to install for
# @param download_url
#     download url to download from
# @param download_url_base
#     download hostname to down from
# @param download_extension
#     archive type to download
# @param package_name
#     Only valid when the install_method == package.
# @param package_ensure
#     Only valid when the install_method == package.
# @param config_dir
#     location of the nomad configuration
# @param extra_options
#     Extra arguments to be passed to the nomad agent
# @param config_hash
#     Use this to populate the JSON config file for nomad.
# @param config_defaults
#     default set of config settings
# @param config_mode
#     Use this to set the JSON config file mode for nomad.
# @param manage_service
#     manage the nomad service
# @param pretty_config
#     Generates a human readable JSON config file.
# @param pretty_config_indent
#     Toggle indentation for human readable JSON file.
# @param service_enable
#     enable the nomad service
# @param service_ensure
#     ensure the state of the nomad service
# @param restart_on_change
#     Determines whether to restart nomad agent on $config_hash changes. This will not affect reloads when service, check or watch configs change.
# @param init_style
#     What style of init system your system uses.
class nomad (
  String[1] $arch,
  Boolean $manage_user                           = true,
  String[1] $user                                = 'nomad',
  Boolean $manage_group                          = true,
  Array[String[1]] $extra_groups                 = [],
  Boolean $purge_config_dir                      = true,
  String[1] $group                               = 'nomad',
  Optional[String[1]] $join_wan                  = undef,
  Stdlib::Absolutepath $bin_dir                  = '/usr/local/bin',
  String[1] $version                             = '1.0.1',
  Enum['url', 'package', 'none'] $install_method = 'url',
  String[1] $os                                  = downcase($facts['kernel']),
  Optional[String[1]] $download_url              = undef,
  String[1] $download_url_base                   = 'https://releases.hashicorp.com/nomad/',
  String[1] $download_extension                  = 'zip',
  String[1] $package_name                        = 'nomad',
  String[1] $package_ensure                      = 'installed',
  Stdlib::Absolutepath $config_dir               = '/etc/nomad',
  String $extra_options                          = '',
  Hash $config_hash                              = {},
  Hash $config_defaults                          = {},
  Stdlib::Filemode $config_mode                  = '0660',
  Boolean $pretty_config                         = false,
  Integer $pretty_config_indent                  = 4,
  Boolean $service_enable                        = true,
  Stdlib::Ensure::Service $service_ensure        = 'running',
  Boolean $manage_service                        = true,
  Boolean $restart_on_change                     = true,
  Variant[String[1], Boolean] $init_style        = $facts['service_provider'],
) {
  $real_download_url = pick($download_url, "${download_url_base}${version}/${package_name}_${version}_${os}_${arch}.${download_extension}")
  $config_hash_real = deep_merge($config_defaults, $config_hash)

  if $config_hash_real['data_dir'] {
    $data_dir = $config_hash_real['data_dir']
  } else {
    $data_dir = undef
  }

  if ($config_hash_real['ports'] and $config_hash_real['ports']['rpc']) {
    $rpc_port = $config_hash_real['ports']['rpc']
  } else {
    $rpc_port = 8400
  }

  if ($config_hash_real['addresses'] and $config_hash_real['addresses']['rpc']) {
    $rpc_addr = $config_hash_real['addresses']['rpc']
  } elsif ($config_hash_real['client_addr']) {
    $rpc_addr = $config_hash_real['client_addr']
  } else {
    $rpc_addr = $facts['networking']['interfaces']['lo']['ip']
  }

  $notify_service = $restart_on_change ? {
    true    => Class['nomad::run_service'],
    default => undef,
  }

  class { 'nomad::install': }
  -> class { 'nomad::config':
    config_hash => $config_hash_real,
    purge       => $purge_config_dir,
    notify      => $notify_service,
  }
  -> class { 'nomad::run_service': }
  -> class { 'nomad::reload_service': }

  contain nomad::install
  contain nomad::config
  contain nomad::run_service
  contain nomad::reload_service
}
