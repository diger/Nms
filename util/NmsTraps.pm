#!perl

=head1 NAME

  Cable tester for NMS

=cut

use strict;
use warnings FATAL => 'all';
use Abills::Base qw(ip2int mk_unique_value);
use Nms::db::Traps;

our(
  %lang,
  $Nms,
  $html,
  %conf,
  $admin,
  $db
);

my $Traps = Traps->new( $db, $admin, \%conf );
SNMP::addMibDirs( '../../var/snmp/mibs' );
SNMP::addMibDirs( '../../var/snmp/mibs/private' );
SNMP::initMib();

#**********************************************************
=head2 nms_traps()

=cut
#**********************************************************
sub nms_traps {
  my ($attr) = @_;
  
  SNMP::addMibFiles(glob('../../var/snmp/mibs/private' . '/*'));
  SNMP::loadModules('LLDP-MIB');

  if ($attr->{PAGE_ROWS}){
	  $LIST_PARAMS{PAGE_ROWS} = $attr->{PAGE_ROWS};
	  $LIST_PARAMS{MONIT} = 1;
  }
  if ($FORM{NAS_ID}){
    $LIST_PARAMS{NAS_ID} = $FORM{NAS_ID};
  }
  if ($FORM{ID}){
    my $values = $Traps->trap_values($FORM{ID});
    foreach my $val (@$values){
      if ( $SNMP::MIB{$val->[1]}{syntax} eq 'OCTETSTR' || $SNMP::MIB{$val->[1]}{syntax} eq 'PhysAddress' ){
        $val->[2] = bin2hex($val->[2]);
      }
      if ( keys %{$SNMP::MIB{$val->[1]}{enums}} ){
        my %en = oid_enums($val->[1]);
        $val->[2] = $en{$val->[2]};
      }
      my $rows = $html->element('div', "<label>$SNMP::MIB{$val->[1]}{label}</label>", {class => 'col-sm-6', title => $val->[1]});
      $rows .= $html->element('div', $SNMP::MIB{$val->[2]}{label} || $val->[2], {class => 'col-sm-6', title => $val->[2]});
      print $html->element('div', $rows,{class => 'row'});
    }

    return 1
  }
  
  result_former({
    INPUT_DATA      => $Traps,
    FUNCTION        => 'traps_list',
    DEFAULT_FIELDS  => 'TRAPTIME, IP, EVENTNAME',
    FUNCTION_FIELDS => 'nms_traps:stats:id;&pg='.($FORM{pg}||''),
    HIDDEN_FIELDS   => 'ID',
    EXT_TITLES      => {
      traptime    => $lang{TIME},
      name        => $lang{NAME},
      eventname   => $lang{EVENTS},
      ip      => "IP ".$lang{ADDRESS},
    },
    SKIP_USER_TITLE => 1,
    FILTER_COLS  => {
      ip => "search_link:nms_obj:,IP",
      eventname => 'oid_conv::,ID',
    },
    TABLE           => {
      width   => '100%',
      caption => "$lang{TRAPS}",
      header  => $html->button( "$lang{CONFIG} $lang{TRAPS}", "index=".get_function_index( 'nms_trap_types' ), { class => 'change' } ),
      qs      => ($FORM{NAS_ID})? "$pages_qs&NAS_ID=$FORM{NAS_ID}" : $pages_qs,
      ID      => 'TRAPS_LIST',
    },
    MAKE_ROWS => 1,
    TOTAL     => 1
  });
  my $scr = qq(
    <script>
    \$('a#trap').on('click', function(){
      //loadDataToModal(this.innerText);
      loadToModal('?get_index=nms_traps&header=2&ID=' + this.getAttribute('value'))
    })
    </script>
  );
  print $scr;
  return 1
}

#********************************************************
=head2 nms_traps_clean()

=cut
#********************************************************
sub nms_traps_clean{
  $Traps->traps_del({ PERIOD => $conf{TRAPS_CLEAN_PERIOD} || 30 });
}

#**********************************************************
=head2 equipment_monitor()

=cut
#**********************************************************
sub nms_monitor {
  my $traps_pg_rows = $FORM{FILTER} || 10;
  return 1;
}

#**********************************************************
=head2 nms_trap_types() -

  Arguments:
    $attr -
  Returns:

  Examples:

=cut
#**********************************************************
sub nms_trap_types {
  
  my $OBJECTID = '.1.3.6.1.2.1.1.3.0';
  if ( $FORM{del} ) {
    $Nms->oid_del($FORM{del});
  }

  load_mibs({ ALL => 1 });

  if ( $FORM{add} ) {
    $Nms->obj_oids_add({
      SECTION  => $FORM{TRAP},
      LABEL    => $FORM{LABEL},
      TYPE     => $FORM{TYPE},
      OBJECTID => $OBJECTID,
    });
  }
  if ( $FORM{new} ) {
    my @types = ('<option>alert</option>','<option>mac_notif</option>');
    my $ind = $html->form_input('index', $index, {TYPE => 'hidden'});
    my $in_box = $html->element('div', 
      $html->element('span', 'TRAP', {class => 'input-group-addon'}).
      $html->form_input('TRAP', '', {class => 'form-control'}),
      {class => 'input-group'}
    ) . $html->br;
    $in_box .= $html->element('div', 
      $html->element('span', 'LABEL', {class => 'input-group-addon'}).
      $html->form_input('LABEL', '', {class => 'form-control'}),
      {class => 'input-group'}
    ) . $html->br;
    $in_box .= $html->element('div', 
      $html->element('span', $lang{TYPE}, {class => 'input-group-addon'}).
      $html->element('select', "@types", {class => 'form-control', id =>'TYPE', name => 'TYPE'}),
       {class => 'input-group'}
    );
    my $sbm = $html->form_input( 'add', $lang{ADD}, { TYPE => 'submit' } );
    print $html->element('form', $ind. $in_box . $html->br . $sbm );
    return 1;
  }
  else {
    $LIST_PARAMS{OBJECTID} = $OBJECTID;
    my $modal_btn = $html->button( $lang{ADD}, undef,
        {
          class          => 'btn btn-sm btn-default',
          JAVASCRIPT     => '',
          SKIP_HREF      => 1,
          NO_LINK_FORMER => 1,
          ex_params      => qq/onclick=loadToModal('?get_index=nms_trap_types&header=2&new=1')/,
        } );
    result_former({
       INPUT_DATA      => $Nms,
       FUNCTION        => 'oids_list',
       DEFAULT_FIELDS  => 'SECTION,LABEL,IID,TYPE,ACCESS',
       FUNCTION_FIELDS => 'oid_table_edit:change:id;type;label;objectid,del',
       HIDDEN_FIELDS   => 'ID,OBJECTID',
       FILTER_COLS  => {
         label => 'oid_conv',
         section => 'oid_conv',
       },
       SKIP_USER_TITLE => 1,
       TABLE           => {
        caption => 'SNMP Traps',
        qs   => "$pages_qs&OBJECTID=$OBJECTID",
        ID   => 'OID_LIST',
        header => $modal_btn,
       },
       MAKE_ROWS => 1,
       TOTAL     => 1
    });
  }

  return 1;
}

#**********************************************************
=head2 oid_conv($attr) - conv numerical oid to human

=cut
#**********************************************************
sub oid_conv{
  my ($text, $attr) = @_;
  if (!$attr->{STR}){
    my $html_str = $html->element('a', $SNMP::MIB{$text}{label}, {
      title => $text,
      id    => 'trap',
      value => $attr->{VALUES}->{ID}
    });
    return $html_str;
  }

  return $SNMP::MIB{$text}{label};
}
1;