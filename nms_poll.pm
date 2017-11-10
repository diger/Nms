=head1
  Name: nms_poll

=cut

use strict;
use warnings;

use Abills::Filters;
use Abills::Base qw(in_array load_pmodule2 ip2int);
use POSIX qw(strftime);
use Nms::db::Nms;
use Data::Dumper;
use Net::IP;
use SNMP;

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
$Admin->info( $conf{SYSTEM_ADMIN_ID}, { IP => '127.0.0.1' } );

my $Nms = Nms->new( $db, $Admin, \%conf );
my $sess;
my $ctime = time;
my $Log = Log->new($db, $Admin);
if($debug > 2) {
  $Log->{PRINT}=1;
}
else {
  $Log->{LOG_FILE} = $var_dir.'/log/nms_poll.log';
}

if ($argv->{INIT}) {
  my %mod;
  foreach my $oid (keys(%SNMP::MIB)) {
    my $parent = '';
    if ( split(/\./,$SNMP::MIB{$oid}{objectID}) > 8 ){
      my @prt = split(/\./,$SNMP::MIB{$oid}{objectID});
      $parent = "@prt[0,1,2,3,4,5,6,7]";
      $parent =~ s/ /./g;
      $parent = $SNMP::MIB{$parent}{label};
    }
    $mod{$SNMP::MIB{$oid}{moduleID}} = $parent if $SNMP::MIB{$oid}{moduleID}
  }
  foreach my $key ( sort keys %mod ) {
    $Nms->module_add({ NODE => $mod{$key}, MODULE => $key })
  }

  return 255
}
if ($argv->{PING}) {
  nms_ping();
}
nms_poll();

#**********************************************************
=head2 nms_poll($attr)

  Arguments:
    
    
  Returns:
  
=cut
#**********************************************************
sub nms_poll {
	
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

  my %values;
  my $vl = new SNMP::VarList(['sysObjectID', 0],
                             ['sysDescr', 0],
                             ['sysName', 0],
                             ['sysLocation', 0],
                             ['sysUpTime', 0]);

  if ($argv->{DISC}) {
	  my $ip = new Net::IP( $argv->{IPS} || $conf{NMS_NET});
	  do {
		  $snmpparms{UseSprintValue} = 0;
      $snmpparms{DestHost} = $ip->ip();
		  $sess = new SNMP::Session(%snmpparms);
		  print $ip->ip() . "\n" if $debug > 0;
		  my @result = $sess->get($vl);
      print Dumper \@result if $debug > 0;
      $Nms->obj_add({ 
        IP => ip2int($ip->ip()),
        SYSOBJECTID => $result[0],
        SYSNAME     => $result[2],
        SYSLOCATION => $result[3],
      }) if (@result && $debug < 2);
	  } while (++$ip);
  }
  if ($argv->{MOD}) {
	  foreach my $obj (@$obj_list) {
		  $snmpparms{UseSprintValue} = 0;
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
      my $modules = $sess->gettable( 'sysORTable', columns => ['sysORID','sysORDescr'], noindexes => 1 );
      if ($modules) {
        print Dumper %$modules if $debug > 0;
        foreach my $key ( keys %$modules ){
          my $module;
          if ($SNMP::MIB{$modules->{$key}->{sysORID}}){
            $module = $SNMP::MIB{$modules->{$key}->{sysORID}}{moduleID};
          }
          my @sysordescr =  split(': ',$modules->{$key}->{sysORDescr});
           $Nms->module_add({ 
            OBJECTID => $result[0],
            MODULE   => $module,
            DESCR    => $sysordescr[1] || "@sysordescr",
            STATUS   => ($module)? 1 : 0,
          }) if $debug < 1;
        }
      }
	  } 
  }
  foreach my $obj (@$obj_list) {

    my $stats = $Nms->triggers_list({
      COLS_NAME => 1,
      OBJ_ID    => $obj->{id},
      LABEL     => '_SHOW',
      IID       => '_SHOW'
    });

=comm
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
=cut	
	if ($argv->{STATS} && $stats) {
      stats($obj->{ip}, $stats);
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
  my ($ip,$attr) = @_;
  my $redis = Redis->new(
          server   => $conf{REDIS_SERV},
          encoding => undef,
  );
  $sess = SNMP::Session->new( DestHost => $ip, %snmpparms );

  foreach my $var (@$attr) {
    my $val = $sess->get("$var->{label}.$var->{iid}");
    $redis->zadd( "$var->{id}", $ctime, $val );
  }

  return 1;
}

#**********************************************************
=head2 nms_ping($attr)

=cut
#********************************************************** 
sub nms_ping {
  my $obj_list = $Nms->obj_list( {
    COLS_NAME    => 1,
    PAGE_ROWS    => 100000,
    IP           => '_SHOW',
  } );

  my %list;
  my $var;
  my $id;

  foreach my $obj (@$obj_list) {
    $sess = SNMP::Session->new(
      DestHost => $obj->{ip},
      Version  => 2,
      Retries  => 1,
      Timeout  => -1,
      Community=> $conf{NMS_COMMUNITY_RO}
    );

    my $vb = new SNMP::Varbind(['sysUpTime']);

    # The responses to our queries are stored in %list.
    $var = $sess->getnext($vb, [ \&gotit, $obj->{id}, \%list ]);

    # Update the rate limiting counter.
    $id++;

    # After every 100 IP's, wait for the timeout period (default is two seconds) to keep from overwhelming routers with ARP queries.
#    if ( $id > 100 ) {
      &SNMP::MainLoop(2);
#      $id = 0;
#    }
  }
}

sub gotit{
  my $id = shift;
  my $listref = shift;
  my $vl = shift;
  if ( defined $$vl[0] ) {
    &SNMP::finish();
    $Nms->change_obj_status({ ID => $id, STATUS => 0 });
    print "$id Ok \n" if $debug > 1;
#    $$listref{$id}{desc} = $$vl[0]->val;
  } else {
    $Nms->change_obj_status({ ID => $id, STATUS => 1 });
    print "$id fall \n" if $debug > 1;
  }
  return();
}

1;
