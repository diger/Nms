#!perl

=head1 NAME

  Cable tester for NMS

=cut

use strict;
use warnings FATAL => 'all';
use Abills::Base qw(ip2int mk_unique_value);
use Dv;
#use Cid_auth;
use Dhcphosts;
use Nms::HTMLelem qw(label_w_txt table_header2);

our(
  %lang,
  $Nms,
  $html,
  %conf,
  $admin,
  $db
);

#**********************************************************
=head2 cable_test()

=cut
#**********************************************************
sub cable_test {
  my ($attr) = @_;
  my $nms_index = get_function_index('nms_obj');

  my $test_param = $Nms->oids_list({
    OBJECTID  => $attr->{OBJECTID},
    LABEL     => '_SHOW',
    SECTION   => '_SHOW',
    TYPE      => 'cable',
    LIST2HASH => 'label,section'
  });
  my $mib;
  my @vars;
  my %pair;

  foreach my $key (keys %$test_param) {
    $mib =  $key if $test_param->{$key} eq 'action';
    push @vars, [$key,$attr->{PORT}] if $test_param->{$key} ne 'action';
    push @{$pair{$test_param->{$key}}}, $key;
  }

  load_mibs({ OBJECTID => $attr->{OBJECTID} });
  my %snmpparms;
  $snmpparms{Version} = 2;
  $snmpparms{Retries} = 1;
  $snmpparms{Timeout} = 2000000;
  $snmpparms{Community} = $attr->{COMMUNITY} || $conf{NMS_COMMUNITY_RW};
  my $sess = SNMP::Session->new(DestHost => $attr->{IP}, %snmpparms);
  my $value = $SNMP::MIB{$mib}{enums}{action} || 1;
  my $vb = SNMP::Varbind->new([$mib,$attr->{PORT},$value]);
  $sess->set($vb);
  if ( $sess->{ErrorNum} ) {
    return $html->message('err', $lang{ERROR}, $sess->{ErrorStr});
  }
  sleep(2);
  my $vl = SNMP::VarList->new(@vars);
  $sess->get($vl);
  if ( $sess->{ErrorNum} ) {
    return $html->message('err', $lang{ERROR}, $sess->{ErrorStr});
  }
  my %result;
  foreach my $res (@vars) {
    $result{$res->[0]} = $res->[2]
  }
  
  my $li = '';
  if ($pair{status}){
    $li .= $html->element('li', 'Link Status', { class => 'nav-header' });
    my %en = oid_enums($pair{status}[0]);
    my $span = $pair{status}[0] . $html->element('span', $en{$result{$pair{status}[0]}}, { class => 'badge' });
    $li .= $html->element('li', $span, { class => 'list-group-item' });
  }
  if ($pair{length}){
    $li .= $html->element('li', 'Pair Length', { class => 'nav-header' });
    if (@{$pair{length}} == 1){
      my $res = $result{$pair{length}[0]};
      $res =~ s/\n/<br>/g;
      $li .= $html->element('li', $res, { class => 'list-group-item' });
    }
    else {
      foreach my $res ( sort @{$pair{length}} ) {
        my $color = ($result{$res} >= 92)? 'list-group-item-warning' : '';
        my $span = $res . $html->element('span', $result{$res}, { class => 'badge' });
        $li .= $html->element('li', $span, { class => "list-group-item $color" });
      }
    }
  }
  if ($pair{pair_status}){
    $li .= $html->element('li', 'Pair Status', { class => 'nav-header' });
    foreach my $res ( sort @{$pair{pair_status}} ) {
      my %en = oid_enums($res);
      my $span = $res . $html->element('span', $en{$result{$res}} || $result{$res}, { class => 'badge' });
      $li .= $html->element('li', $span, { class => 'list-group-item' });
    }
  }
  print $html->element('ul', $li, { class => 'list-group' });
  return 1;
}

#**********************************************************

=head2 cable_test_setup()

=cut

#**********************************************************
sub cable_test_setup {

  my ($attr) = @_;

  if ( $FORM{del} ) {
    $Nms->oid_del($FORM{del});
  }
  if ( $FORM{OBJECTID} ) {
    cable_test_edit({ OBJECTID => $FORM{OBJECTID} })
  }
  elsif ( $FORM{add} ) {
    $Nms->obj_oids_add({
      LABEL   => $FORM{add},
      SECTION => $FORM{SECT},
      TYPE    => $FORM{TYPE},
    });
    $html->redirect('index.cgi?&index='. $index);
  }
  elsif ( $FORM{ID} ) {
    oid_table_row_edit({ OID_ID => $FORM{ID} });
  } 
  else {
    result_former({
      INPUT_DATA      => $Nms,
      FUNCTION        => 'sysobjectid_list',
      DEFAULT_FIELDS  => 'LABEL, OBJECTID',
      FUNCTION_FIELDS => 'cable_test_setup:change:objectid',
      SKIP_USER_TITLE => 1,
      TABLE => {
        qs      => ($FORM{OBJECTID})? "$pages_qs&OBJECTID=$FORM{OBJECTID}" : $pages_qs,
        ID      => 'CABLE_TEST',
      },
      MAKE_ROWS => 1,
      TOTAL     => 1
    });
  }
  
  return 1;
}

#**********************************************************

=head2 cable_test_edit()

=cut

#**********************************************************
sub cable_test_edit {

  my ($attr) = @_;

  if ( $FORM{del} ) {
    $Nms->oid_del($FORM{del});
  }
  if ( $FORM{SAVE} ) {
    $Nms->obj_oids_add({
      LABEL    => $FORM{LABEL},
      TYPE     => 'cable',
      OBJECTID => $FORM{OBJECTID},
      SECTION  => $FORM{TYPE},
    });
  }
  
  if ( $FORM{add} ) {
    load_mibs({ OBJECTID => $FORM{OBJECTID} });
    my @labels;
    foreach my $oid (keys(%SNMP::MIB)) {
      if  ( $SNMP::MIB{$oid}{label} =~ /Cable/ || $SNMP::MIB{$oid}{label} =~ /cable/
      || $SNMP::MIB{$oid}{label} =~ /vct/ && !$SNMP::MIB{$oid}{children}[0]{label} ) {
        push @labels, $SNMP::MIB{$oid}{label}
      }
    }
    my $LABEL_SEL = $html->form_select(
      'LABEL',
      {
        SELECTED  => $FORM{LABEL},
        SEL_ARRAY => \@labels,
        NO_ID     => 1
      }
    );
    my @types = (
      'length',
      'pair_status',
      'status',
      'action',
    );
    my $TYPE_SEL = $html->form_select(
      'TYPE',
      {
        SELECTED  => $FORM{OID},
        SEL_ARRAY => \@types,
        NO_ID     => 1
      }
    );
    print $html->form_main({
          	CONTENT =>  label_w_txt($lang{NAME}, $LABEL_SEL).
                        label_w_txt($lang{TYPE}, $TYPE_SEL).
                        label_w_txt(undef, $html->form_input( 'SAVE', ( $FORM{chg} )? $lang{CHANGE} : $lang{CREATE}, {
                            TYPE => 'SUBMIT'
                          }) . "	" .
      											$html->button($lang{CANCEL}, "index=$index$pages_qs", {class =>"btn btn-default"}),
      								  {RCOL => 3}),
      	    METHOD  => 'GET',
          	HIDDEN  => {
            				'index'    => $index,
            				'ID'       => $FORM{chg} || '',
                    'OBJECTID' => $FORM{OBJECTID},
          				},
        	});

    return 1;
  }
  else {
    $LIST_PARAMS{OBJECTID} = $FORM{OBJECTID};
    $LIST_PARAMS{TYPE} = 'cable';
    result_former({
      INPUT_DATA      => $Nms,
      FUNCTION        => 'oids_list',
      DEFAULT_FIELDS  => 'LABEL,SECTION',
      FUNCTION_FIELDS => 'cable_test_edit:change:id;section;label;objectid,del',
      HIDDEN_FIELDS   => 'ID,OBJECTID',
      EXT_TITLES      => {
        label => "$lang{NAME}",
        type  => "$lang{TYPE}",
       },
      SKIP_USER_TITLE => 1,
      TABLE           => {
       qs   => "$pages_qs&OBJECTID=$FORM{OBJECTID}",
       ID   => 'OID_LIST',
       MENU => "$lang{ADD}:index=$index$pages_qs&OBJECTID=$FORM{OBJECTID}&add=1:add",
      },
      MAKE_ROWS => 1,
      TOTAL     => 1
    });
  }
  
  return 1;
}

1;