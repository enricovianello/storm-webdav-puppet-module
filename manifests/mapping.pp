# @summary Utility class used to install LCMAPS and LCAS and configure mapping software and files. 
#
# @param gridmapdir_owner
#   The owner of /etc/grid-security/gridmapdir
#
# @param gridmapdir_group
#   The group of /etc/grid-security/gridmapdir
#
# @param gridmapdir_mode
#   The permissions on /etc/grid-security/gridmapdir
#
# @param pools
#   The Array of pool accounts.
#
# @param manage_lcmaps_db_file
#   If true (default) use as /etc/lcmaps/lcmaps.db the file specified with lcmaps_db_file.
#   If false, file is not managed by this class.
#
# @param lcmaps_db_file
#   The path of the lcmaps.db to copy into /etc/lcmaps/lcmaps.db. Default: puppet:///modules/storm/etc/lcmaps/lcmaps.db
#
# @param manage_lcas_db_file
#   If true (default) use as /etc/lcas/lcas.db the file specified with lcas_db_file.
#   If false, file is not managed by this class.
#
# @param lcas_db_file
#   The path of the lcas.db to copy into /etc/lcas/lcas.db. Default: puppet:///modules/storm/etc/lcas/lcas.db
#
# @param manage_lcas_ban_users_file
#   If true (default) use as /etc/lcas/ban_users.db the file specified with lcas_ban_users_file.
#   If false, file is not managed by this class.
#
# @param lcas_ban_users_file
#   The path of the ban_users.db to copy into /etc/lcas/ban_users.db. Default: puppet:///modules/storm/etc/lcas/ban_users.db
#
# @param manage_gsi_authz_file
#   If true (default) use as /etc/grid-security/gsi-authz.conf the file specified with gsi_authz_file.
#   If false, file is not managed by this class.
#
# @param gsi_authz_file
#   The path of the gsi-authz.conf to copy into /etc/grid-security/gsi-authz.conf. Default: puppet:///modules/storm/etc/grid-security/gsi-authz.conf
#
# @example Example of usage
#    class { 'storm::mapping':
#      pools => [{
#        'name' => 'dteam',
#        'size' => 20,
#        'base_uid' => 7100,
#        'group' => 'dteam',
#        'gid' => 7100,
#        'vo' => 'dteam',
#      }],
#      manage_lcas_ban_users_file => false,
#    }
#
class storm::mapping (

  String $gridmapdir_owner = 'storm',
  String $gridmapdir_group = 'storm',
  String $gridmapdir_mode = '0770',

  Array[Data] $pools = [{
    'name' => 'tstvo',
    'size' => 20,
    'base_uid' => 7100,
    'group' => 'testvo',
    'gid' => 7100,
    'vo' => 'test.vo',
  },{
    'name' => 'testdue',
    'size' => 20,
    'base_uid' => 8100,
    'group' => 'testvodue',
    'gid' => 8100,
    'vo' => 'test.vo.2',
  }],

  Boolean $manage_lcmaps_db_file = true,
  String $lcmaps_db_file = 'puppet:///modules/storm/etc/lcmaps/lcmaps.db',

  Boolean $manage_lcas_db_file = true,
  String $lcas_db_file = 'puppet:///modules/storm/etc/lcas/lcas.db',

  Boolean $manage_lcas_ban_users_file = true,
  String $lcas_ban_users_file = 'puppet:///modules/storm/etc/lcas/ban_users.db',

  Boolean $manage_gsi_authz_file = true,
  String $gsi_authz_file = 'puppet:///modules/storm/etc/grid-security/gsi-authz.conf',

) {

  $lcamps_rpms = ['lcmaps', 'lcmaps-without-gsi', 'lcmaps-plugins-basic', 'lcmaps-plugins-voms']
  package { $lcamps_rpms:
    ensure => latest,
  }

  $lcas_rpms = ['lcas', 'lcas-lcmaps-gt4-interface', 'lcas-plugins-basic', 'lcas-plugins-voms']
  package { $lcas_rpms:
    ensure => latest,
  }

  $gridmapdir = '/etc/grid-security/gridmapdir'

  if !defined(File[$gridmapdir]) {
    file { $gridmapdir:
      ensure  => directory,
      owner   => $gridmapdir_owner,
      group   => $gridmapdir_group,
      mode    => $gridmapdir_mode,
      recurse => true,
      require => [User[$gridmapdir_owner]],
    }
  }

  $pools.each | $pool | {

    group { $pool['group']:
      ensure => present,
      gid    => $pool['gid'],
    }

    range('1', $pool['size']).each | $id | {

      $id_str = sprintf('%03d', $id)
      $name = "${pool['name']}${id_str}"

      user { $name:
        ensure     => present,
        uid        => $pool['base_uid'] + $id,
        gid        => $pool['gid'],
        groups     => [$pool['group']],
        comment    => "Mapped user for ${pool['vo']}",
        managehome => true,
        require    => [Group[$pool['group']]],
      }

      file { "${gridmapdir}/${name}":
        ensure  => present,
        require => File[$gridmapdir],
        owner   => $gridmapdir_owner,
        group   => $gridmapdir_group,
      }
    }
  }

  $gridmapfile='/etc/grid-security/grid-mapfile'
  $gridmapfile_template='storm/etc/grid-security/grid-mapfile.erb'

  file { $gridmapfile:
    ensure  => present,
    content => template($gridmapfile_template),
    owner   => 'root',
    group   => 'root',
    mode    => '0644',
  }

  $groupmapfile='/etc/grid-security/groupmapfile'
  $groupmapfile_template='storm/etc/grid-security/groupmapfile.erb'

  file { $groupmapfile:
    ensure  => present,
    content => template($groupmapfile_template),
    owner   => 'root',
    group   => 'root',
    mode    => '0644',
  }

  if $manage_gsi_authz_file {
    file { '/etc/grid-security/gsi-authz.conf':
      ensure => present,
      source => $gsi_authz_file,
      mode   => '0644',
      owner  => 'root',
      group  => 'root',
    }
  }

  if $manage_lcmaps_db_file {
    file { '/etc/lcmaps/lcmaps.db':
      ensure  => present,
      source  => $lcmaps_db_file,
      mode    => '0644',
      owner   => 'root',
      group   => 'root',
      require => Package[$lcamps_rpms],
    }
  }

  if $manage_lcas_db_file {
    file { '/etc/lcas/lcas.db':
      ensure  => present,
      source  => $lcas_db_file,
      mode    => '0644',
      owner   => 'root',
      group   => 'root',
      require => Package[$lcas_rpms],
    }
    if $manage_lcas_ban_users_file {
      file { '/etc/lcas/ban_users.db':
        ensure  => present,
        source  => $lcas_ban_users_file,
        mode    => '0644',
        owner   => 'root',
        group   => 'root',
        require => File['/etc/lcas/lcas.db'],
      }
    }
  }
}