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

my %snmpparms;
$snmpparms{Version} = 2;
$snmpparms{Retries} = 1;
$snmpparms{UseSprintValue} = 0;
$Admin->info( $conf{SYSTEM_ADMIN_ID}, { IP => '127.0.0.1' } );

my $Redis = Redis->new( server => $conf{REDIS_SERV}, encoding => undef );
my $Nms = Nms->new( $db, $Admin, \%conf );
my $sess;
my $ctime = time;

if ($argv->{INIT}) {
  nms_init();
  return 1
}

nms_poll();
#**********************************************************
=head2 nms_init($attr)

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

  my $vl = SNMP::VarList->new(['sysObjectID', 0],
                             ['sysDescr', 0],
                             ['sysName', 0],
                             ['sysLocation', 0],
                             ['sysUpTime', 0]);

  if ($argv->{DISC}) {
    $Nms->{debug}=1;
    $snmpparms{Community} = $conf{NMS_COMMUNITY_RO};
    $snmpparms{Timeout} = 400000;
	  my $ip = Net::IP->new( $argv->{IPS} || $conf{NMS_NET});
	  do {
      $snmpparms{DestHost} = $ip->ip();
		  $sess = SNMP::Session->new(%snmpparms);
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

    if ($argv->{INIT}) {
      $snmpparms{Community} = $conf{NMS_COMMUNITY_RO};
      $snmpparms{DestHost} = $obj->{ip};
		  $sess = SNMP::Session->new(%snmpparms);
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
=head2 nms_poll($attr)

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

  foreach my $obj (@$obj_list) {
    my @mibs;
    push @mibs, ['sysObjectID', 0];
 #   push @mibs, ['sysName', 0];
#    push @mibs, ['sysLocation', 0];
    my $triggers;
    if ($argv->{STATS}){
      $triggers = $Nms->triggers_list({
        COLS_NAME => 1,
        OBJ_ID    => $obj->{id},
        LABEL     => '_SHOW',
        IID       => '_SHOW',
      });
      if ($triggers){
        foreach my $vr (@$triggers){
          push @mibs, [$vr->{label},$vr->{iid}];
        }
      }
    }
    
    my $vb = SNMP::VarList->new(@mibs);
    $sess = SNMP::Session->new(
      %snmpparms,
      Community => $conf{NMS_COMMUNITY_RO},
      DestHost  => $obj->{ip},
  #    Timeout  => -1,
    );
    $sess->get($vb, [ \&nms_clb, $obj, $triggers ]);

    &SNMP::MainLoop(2);
  }
  return 1;
}

#**********************************************************
=head2 nms_clb($obj,$tr,$vl)

=cut
#**********************************************************
sub nms_clb {
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
      });
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
