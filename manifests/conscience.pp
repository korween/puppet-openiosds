# Configure and install an OpenIO conscience service
define openiosds::conscience (
  $action                                = 'create',
  $type                                  = 'conscience',
  $num                                   = '0',

  $ns                                    = undef,
  $ipaddress                             = $::ipaddress,
  $port                                  = $::openiosds::params::conscience_port,
  $chunk_size                            = '10485760',
  $ns_status                             = 'STANDALONE',
  $worm                                  = false,
  $auto_container                        = false,
  $vns                                   = undef,
  $storage_policy                        = 'SINGLE',
  $service_update_policy                 = 'meta2=KEEP|1|1|;sqlx=KEEP|1|1|;rdir=KEEP|1|1|user_is_a_service=1',
  $automatic_open                        = true,
  $meta2_max_versions                    = '1',
  $min_workers                           = '2',
  $min_spare_workers                     = '2',
  $max_spare_workers                     = '10',
  $max_workers                           = '10',
  $score_timeout                         = '86400',
  $lb_rawx                               = 'WRAND',
  $lb_rdir                               = 'WRAND?shorten_ratio=1.0&standard_deviation=no',
  $param_option_events_max_pending       = '1000',
  $param_option_meta2_events_max_pending = '1000',
  $param_option_meta1_events_max_pending = '1000',

  $no_exec               = false,
) {

  if ! defined(Class['openiosds']) {
    include openiosds
  }


  # Validation
  $actions = ['create','remove']
  validate_re($action,$actions,"${action} is invalid.")
  validate_string($type)
  validate_integer($num)

  validate_string($ns)
  if ! has_interface_with('ipaddress',$ipaddress) { fail("${ipaddress} is invalid.") }
  validate_integer($port)
  validate_integer($chunk_size)
  $valid_ns_status = ['STANDALONE','MASTER','SLAVE']
  validate_re($ns_status,$valid_ns_status,"${ns_status} is invalid.")
  validate_bool($worm)
  validate_bool($auto_container)
  if $vns { validate_string($vns) }
  $valid_storage_policy = ['SINGLE','TWOCOPIES','THREECOPIES','FIVECOPIES','RAIN','ERASURECODE']
  validate_re($storage_policy,$valid_storage_policy,"${storage_policy} is invalid.")
  validate_string($service_update_policy)
  validate_bool($automatic_open)
  validate_integer($meta2_max_versions)
  validate_integer($min_workers)
  validate_integer($min_spare_workers)
  validate_integer($max_spare_workers)
  validate_integer($max_workers)
  validate_integer($score_timeout)
  validate_integer($param_option_events_max_pending)
  validate_integer($param_option_meta2_events_max_pending)
  validate_integer($param_option_meta1_events_max_pending)


  # Namespace
  if $action == 'create' {
    if ! defined(Openiosds::Namespace[$ns]) {
      fail('You must include the namespace class before using OpenIO defined types.')
    }
  }

  # Service
  openiosds::service {"${ns}-${type}-${num}":
    action => $action,
    type   => $type,
    num    => $num,
    ns     => $ns,
  } ->
  # Configuration files
  file { "${openiosds::sysconfdir}/${ns}/${type}-${num}/${type}-${num}.conf":
    ensure  => $openiosds::file_ensure,
    content => template("openiosds/${type}.conf.erb"),
    owner   => $openiosds::user,
    group   => $openiosds::group,
    mode    => '0644',
    notify  => Gridinit::Program["${ns}-${type}-${num}"],
    require => Class['openiosds'],
  } ->
  file { "${openiosds::sysconfdir}/${ns}/${type}-${num}/${type}-${num}-events.conf":
    ensure  => $openiosds::file_ensure,
    content => template("openiosds/${type}.events.erb"),
    owner   => $openiosds::user,
    group   => $openiosds::group,
    mode    => '0644',
    notify  => Gridinit::Program["${ns}-${type}-${num}"],
  } ->
  file { "${openiosds::sysconfdir}/${ns}/${type}-${num}/${type}-${num}-policies.conf":
    ensure  => $openiosds::file_ensure,
    content => template("openiosds/${type}.storage.erb"),
    owner   => $openiosds::user,
    group   => $openiosds::group,
    mode    => '0644',
    notify  => Gridinit::Program["${ns}-${type}-${num}"],
  } ->
  # Init
  gridinit::program { "${ns}-${type}-${num}":
    action  => $action,
    command => "${openiosds::bindir}/oio-daemon -s OIO,${ns},${type},${num} ${openiosds::sysconfdir}/${ns}/${type}-${num}/${type}-${num}.conf",
    group   => "${ns},${type},${type}-${num}",
    uid     => $openiosds::user,
    gid     => $openiosds::group,
    no_exec => $no_exec,
  }

}
