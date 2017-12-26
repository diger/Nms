=head1
  Name: nms_poll

=cut

use strict;
use warnings;

use Abills::Filters;
use Abills::Base qw(in_array ip2int);
use POSIX qw(strftime);
use Nms::db::Nms;
use Data::Dumper;
use Net::IP;
use SNMP;
use Redis;

our (
  $Admin,
  $db,
  %conf,
  $argv,
  $debug,
  $var_dir
);

SNMP::addMibDirs( "$var_dir/snmp/mibs" );
SNMP::addMibDirs( "$var_dir/snmp/mibs/private" );
SNMP::addMibFiles(glob("$var_dir/snmp/mibs/private" . '/*'));
SNMP::initMib();

my $SNMP_COMMUNITY = $argv->{SNMP_COMMUNITY} || $conf{NMS_COMMUNITY_RO};
my %snmpparms;
$snmpparms{Community} = $SNMP_COMMUNITY;
$snmpparms{Version} = 2;
$snmpparms{Retries} = 1;
$snmpparms{UseSprintValue} = 0;
$Admin->info( $conf{SYSTEM_ADMIN_ID}, { IP => '127.0.0.1' } );

my $Redis = Redis->new( server   => $conf{REDIS_SERV}, encoding => undef );
my $Nms = Nms->new( $db, $Admin, \%conf );
my $sess;
my $ctime = time;
#my $Log = Log->new($db, $Admin);
#if($debug > 2) {
#  $Log->{PRINT}=1;
#}
#else {
#  $Log->{LOG_FILE} = $var_dir.'/log/nms_poll.log';
#}

if ($argv->{INIT}) {
  nms_init();
}

nms_poll();

#**********************************************************
=head2 nms_poll($attr)

  Arguments:
    
    
  Returns:
  
=cut
#**********************************************************
sub nms_init {
	
	if($debug > 7) {
		$Nms->{debug}=1;
	}

	if ($argv->{NAS_IPS}) {
		$LIST_PARAMS{NAS_IP} = $argv->{NAS_IPS};
	}

  my $obj_list = $Nms->obj_list( {
    COLS_NAME    => 1,
    PAGE_ROWS    => 100000,
    SYS_OBJECTID => '_SHOW',
		NAS_ID       => '_SHOW',
    IP           => $argv->{NAS_IPS} || '_SHOW',
  } );

  my $vl = new SNMP::VarList(['sysObjectID', 0],
                             ['sysDescr', 0],
                             ['sysName', 0],
                             ['sysLocation', 0],
                             ['sysUpTime', 0]);

  if ($argv->{DISC}) {
    $Nms->{debug}=1;
    $snmpparms{Timeout} = 400000;
	  my $ip = new Net::IP( $argv->{IPS} || $conf{NMS_NET});
	  do {
      $snmpparms{DestHost} = $ip->ip();
		  $sess = new SNMP::Session(%snmpparms);
		  print $ip->ip() . "\n" if $debug > 0;
		  my @result = $sess->get($vl);
      print Dumper \@result if $debug > 0;
      $Nms->obj_add({ 
        IP => ip2int($ip->ip()),
        SYS_OBJECTID => $result[0],
        SYS_NAME     => $result[2],
        SYS_LOCATION => $result[3],
      }) if (@result && $debug < 2);
	  } while (++$ip);
  }

  foreach my $obj (@$obj_list) {

    my $stats = $Nms->triggers_list({
      COLS_NAME => 1,
      OBJ_ID    => $obj->{id},
      LABEL     => '_SHOW',
      IID       => '_SHOW'
    });
    
    if ($argv->{STATS} && $stats) {
      stats($obj->{ip}, $stats);
    }
    
    if ($argv->{INIT}) {
      $snmpparms{DestHost} = $obj->{ip};
		  $sess = new SNMP::Session(%snmpparms);
		  print $obj->{ip} . "\n" if $debug > 0;
      my @result = $sess->get($vl);
      if (@result) {
        print Dumper \@result if $debug > 0;
          $Nms->sysobjectid_add({ 
            OBJECTID => $result[0],
            LABEL    => $SNMP::MIB{$result[0]}{label},
          }) if $debug < 1;
      }
    }
  }

  return 1;
}

#**********************************************************
=head2 nms_ping($attr)

=cut
#********************************************************** 
sub nms_poll {
  my $obj_list = $Nms->obj_list( {
    COLS_NAME    => 1,
    PAGE_ROWS    => 100000,
    IP           => '_SHOW',
    SYS_OBJECTID => '_SHOW',
    STATUS       => '_SHOW',
  } );

  my %list;
  my $var;

  foreach my $obj (@$obj_list) {
    my $triggers = $Nms->triggers_list({
      COLS_NAME => 1,
      OBJ_ID    => $obj->{id},
      LABEL     => '_SHOW',
      IID       => '_SHOW',
    }) if $argv->{STATS};
    my @mibs;
    push @mibs, ['sysObjectID', 0];
 #   push @mibs, ['sysName', 0];
#    push @mibs, ['sysLocation', 0];
    if ($triggers){
      foreach my $vr (@$triggers){
        push @mibs, [$vr->{label},$vr->{iid}];
      }
    }
    
    my $vb = new SNMP::VarList(@mibs);

    $sess = SNMP::Session->new(
      DestHost => $obj->{ip},
      Version  => 2,
      Retries  => 1,
  #    Timeout  => -1,
      Community=> $conf{NMS_COMMUNITY_RO}
    );

    $var = $sess->get($vb, [ \&nms_clb, $obj, $triggers ]);

    &SNMP::MainLoop(2);
  }
}

#**********************************************************
=head2 nms_clb$obj,$tr,$vl)

=cut
#**********************************************************
sub nms_clb{
  my ($obj,$tr,$vl) = @_;
  if ( defined $vl->[0] ) {
    &SNMP::finish();
    if ($vl->[0]->[2] ne $obj->{sysobjectid}){
      $Nms->obj_add({ 
        ID           => $obj->{id},
        SYS_OBJECTID => $vl->[0]->[2],
      })
    }
    if ( $obj->{status} != 0 ){
      $Nms->obj_add({ 
        ID     => $obj->{id},
        STATUS => 0
      })
    }
    if ( $tr ){
      print Dumper $vl if $debug > 2;
      foreach my $ind (0..@$tr-1){
        $Redis->zadd( "$tr->[$ind]->{id}", $ctime, $vl->[$ind+1]->[2] );
      }
    }
    print "$obj->{id} Ok \n" if $debug > 1;
  }
  else {
    if ( $obj->{status} != 1 ){
      $Nms->obj_add({ 
        ID     => $obj->{id},
        STATUS => 1
      })
    }
    print "$obj->{id} fall \n" if $debug > 1;
  }
  return();
}

1;
