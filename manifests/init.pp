# == Class: varnish
#
# Configure Varnish proxy cache
#
# === Parameters
#
# [*addrepo*]
#   Whether to add the official Varnish repos
# [*secret*]
#   Varnish secret (used by varnishadm etc).
#   Optional; will be autogenerated if not specified
# [*vcl_conf*]
#   Location of Varnish config file template
# [*listen*]
#   IP address for HTTP to listen on
# [*listen_port*]
#   Port to listen on for HTTP requests
# [*admin_listen*]
#   IP address for admin requests - defaults to 127.0.0.1
# [*admin_port*]
#   Port for Varnish admin to listen on
# [*min_threads*]
#   Varnish minimum thread pool size
# [*max_threads*]
#   Varnish maximum thread pool size
# [*thread_timeout*]
#   Thread timeout
# [*storage_type*]
#   Whether to use malloc (RAM only) or file storage for cache
# [*storage_size*]
#   Size of cache
# [*varnish_version*]
#   Major Varnish version to use
# [*vcl_reload*]
#   Script to use to load new Varnish config
# [*package_ensure*]
#   Ensure specific package version for Varnish, eg 3.0.5-1.el6
# [*runtime_params*]
#   Hash of key:value runtime parameters
#
class varnish (
  $runtime_params  = {},
  $addrepo         = true,
  $admin_listen    = '127.0.0.1',
  $admin_port      = '6082',
  $listen          = '0.0.0.0',
  $listen_port     = '6081',
  $secret          = undef,
  $secret_file     = '/etc/varnish/secret',
  $vcl_conf        = '/etc/varnish/default.vcl',
  $storage_type    = 'file',
  $storage_file    = '/var/lib/varnish/varnish_storage.bin',
  $storage_size    = '1G',
  $min_threads     = '50',
  $max_threads     = '1000',
  $thread_timeout  = '120',
  $varnish_version = '4.1',
  $instance_name   = undef,
  $package_ensure  = 'present',
  $package_name    = 'varnish',
  $service_name    = 'varnish',
  $vcl_reload_cmd  = undef,
  $vcl_reload_path = $::path,
) {

  if $package_ensure == 'present' {
    $version_major = regsubst($varnish_version, '^(\d+)\.(\d+).*$', '\1')
    $version_minor = regsubst($varnish_version, '^(\d+)\.(\d+).*$', '\2')
    $version_full  = $varnish_version
  } else {
    $version_major = regsubst($package_ensure, '^(\d+)\.(\d+).*$', '\1')
    $version_minor = regsubst($package_ensure, '^(\d+)\.(\d+).*$', '\2')
    $version_full = "${version_major}.${version_minor}"
    if $varnish_version != "${version_major}.${version_minor}" {
      fail("Version mismatch, varnish_version is ${varnish_version}, but package_ensure is ${version_full}")
    }
  }

  include ::varnish::params

  if $vcl_reload_cmd == undef {
    $vcl_reload = $::varnish::params::vcl_reload
  } else {
    $vcl_relaod = $vcl_reload_cmd
  }

  validate_bool($addrepo)
  validate_string($secret)
  validate_absolute_path($secret_file)
  unless is_integer($admin_port) { fail('admin_port invalid') }
  unless is_integer($min_threads) { fail('min_threads invalid') }
  unless is_integer($max_threads) { fail('max_threads invalid') }
  validate_absolute_path($storage_file)
  validate_hash($runtime_params)
  validate_re($storage_type, '^(malloc|file)$')
  validate_re("${version_major}.${version_minor}", '^[3-5]\.[0-9]')

  if $addrepo {
    class { '::varnish::repo':
      before => Class['::varnish::install'],
    }
  }

  include ::varnish::install


  class { '::varnish::secret':
    secret  => $secret,
    require => Class['::varnish::install'],
  }

  class { '::varnish::config':
    require => Class['::varnish::secret'],
    notify  => Class['::varnish::service'],
  }

  class { '::varnish::service':
    require => Class['::varnish::config'],
  }

}
