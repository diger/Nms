=head1
  Name: nms_poll

=cut


use strict;
use warnings;

use Abills::Filters;
use Abills::Base qw(in_array load_pmodule2);
use POSIX qw(strftime);
use Nms::db::Nms;
use Equipment;
use Data::Dumper;

our (
  $Admin,
  $db,
  %conf,
  $argv,
  $debug,
  $var_dir
);

load_pmodule2('SNMP');

SNMP::addMibDirs( grep { -d } glob "$var_dir/snmp/mibs/private/*" );
SNMP::addMibDirs("$var_dir/snmp/mibs");
SNMP::addMibFiles(glob("$var_dir/snmp/mibs/private" . '/*/*'));
SNMP::initMib();
$Admin->info( $conf{SYSTEM_ADMIN_ID}, { IP => '127.0.0.1' } );

my $Nms = Nms->new( $db, $Admin, \%conf );
my $Equipment = Equipment->new( $db, $Admin, \%conf );
my $sess;
my $ctime = time;

my $Log = Log->new($db, $Admin);
if($debug > 2) {
  $Log->{PRINT}=1;
}
else {
  $Log->{LOG_FILE} = $var_dir.'/log/equipment_check.log';
}

nms_poll();

#**********************************************************
=head2 equipment_check($attr)

  Arguments:
    
    
  Returns:
  
=cut
#**********************************************************
sub nms_poll {
	
	if($debug > 7) {
		$Equipment->{debug}=1;
	}

	if ($argv->{NAS_IPS}) {
		$LIST_PARAMS{NAS_IP} = $argv->{NAS_IPS};
	}

	my $SNMP_COMMUNITY = $argv->{SNMP_COMMUNITY} || $conf{EQUIPMENT_SNMP_COMMUNITY_RO};

  my $obj_list = $Nms->obj_list( {
    COLS_NAME => 1,
    PAGE_ROWS => 100000,
    SYS_OID   => '_SHOW',
		NAS_ID    => '_SHOW',
    IP        => $argv->{NAS_IPS} || '_SHOW',
  } );

  my %values;
  my %snmpparms;
  $snmpparms{Community} = $SNMP_COMMUNITY;
  $snmpparms{Version} = 2;
  $snmpparms{Retries} = 1;

  my $oids = $Nms->oids_list({
	  PAGE_ROWS => 10000,
	  OBJECTID  => '_SHOW',
	  IID       => '_SHOW',
  });
  my %oids;
  foreach my $id ( @$oids ){
	  $oids{$id->[0]} = $id->[2];
  } 
  my $vars = SNMP::VarList->new( @$oids );
    
  if ($argv->{DISC}) {
	  my $ip = new Net::IP( $argv->{IPS} || $conf{EQUIP_NET});
	  do {
		  $snmpparms{DestHost} = $ip->ip();
		  $sess = new SNMP::Session(%snmpparms);
		  print $ip->ip() . "\n" if $debug > 0;
		  my $sysoid = $sess->get([ 'sysObjectID', 0 ]);
		  $Nms->obj_add({ IP => ip2int($ip->ip()), SYS_OID => $sysoid }) if $sysoid;
	  } while (++$ip);
  }
  foreach my $obj (@$obj_list) {

    $sess = SNMP::Session->new(
      DestHost => $obj->{ip},
      Community=> $SNMP_COMMUNITY,
      Version  => 2,
      UseEnums => 1,
      Retries  => 2,
      %snmpparms
    );

    my $stats = $Equipment->graph_list({ COLS_NAME => 1, OBJ_ID => $obj->{id} });

	if ($argv->{FIX}) {
	  $snmpparms{UseSprintValue} = 1;
	  $snmpparms{UseNumeric} = 1;
	  $snmpparms{UseEnums} = 1;
	  $snmpparms{DestHost} = $obj->{ip};
	  $sess = new SNMP::Session(%snmpparms);
	  my @vals = $sess->get( $vars );
	  
	  print $obj->{ip} . "\n" if $debug > 0;
	  foreach my $val (@$oids) {
		  if (!($val->[2] =~ 'No Such Object' || $val->[2] =~ 'Wrong Type')){
			  $Nms->obj_values_add({
				  OBJ_ID => $obj->{id},
				  OID_ID  => $oids{$val->[0]},
				  OBJ_IND  => $val->[1],
				  VALUE  => $val->[2],
			  });
		  }
	  }
    }
	
	if ($argv->{STATS} && $stats) {
      stats({ NAS_ID => $obj->{nas_id} });
    }
  }

  return 1;
}

#**********************************************************
=head2 stats($attr)

=cut
#********************************************************** 
sub stats {
  
	load_pmodule2('Redis');
  my ($attr) = @_;
  my $redis = Redis->new(
          server   => $conf{REDIS_SERV},
          encoding => undef,
  );

  my $params = $Equipment->graph_list({
    COLS_NAME   => 1,
    NAS_ID      => $attr->{NAS_ID},
		OBJ_ID      => '_SHOW',
    PORT        => '_SHOW',
    PARAM       => '_SHOW',
		NAME        => '_SHOW',
		TYPE        => '_SHOW'
  });

  foreach my $var (@$params) {
    my $val = $sess->get("$var->{name}.$var->{port}");
	$redis->zadd( "$var->{obj_id}:$var->{port}:$var->{param}", $ctime, $val );
  }

  return 1;
}

1
