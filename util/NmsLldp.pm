#!perl

=head1 NAME

  Lldp for NMS

=cut

use strict;
use warnings FATAL => 'all';
use Nms::db::Lldp;
use Nms::HTMLelem qw(label_w_txt table_header2 make_tree oid_enums flowchart);

our(
  %lang,
  $Nms,
  $html,
  %conf,
  $admin,
  $db
);

my $Lldp = Lldp->new( $db, $admin, \%conf );

my %snmpparms;
$snmpparms{Version} = 2;
$snmpparms{Retries} = 1;
$snmpparms{Timeout} = 2000000;
$snmpparms{Community} = $conf{NMS_COMMUNITY_RO};

#**********************************************************
=head2 neighbors_view()

=cut
#**********************************************************
sub neighbors_view {
  my ($attr) = @_;

  if ($FORM{ID}){
    my $nms_index = get_function_index( 'nms_obj' );
    my $nms = $Nms->obj_list({
      IP           => '_SHOW',
      SYS_NAME     => '_SHOW',
      SYS_LOCATION => '_SHOW',
      SYS_OBJECTID => '_SHOW',
      STATUS       => '_SHOW',
      ID           => $FORM{ID},
      COLS_NAME    => 1,
    });
    my $stbl = nms_snmp_table({ ID => $FORM{ID}, OID => 'lldpRemTable', HASH => 1 });
    my %remp;
    foreach my $key ( keys %$stbl ) {
 #     $stbl->{$key}->{lldpRemPortId} =~ s|1/||;
      $remp{$stbl->{$key}->{lldpRemLocalPortNum}} = [$stbl->{$key}->{lldpRemSysName},$stbl->{$key}->{lldpRemPortId}];
    }
    my $matbl = nms_snmp_table({ ID => $FORM{ID}, OID => 'lldpRemManAddrTable', HASH => 1 });
    my %bd;
    my %outputs;
    my %inputs;
    my %links;
    my $top = 0;
    my $left = 300;
    my $in = 0;
    foreach my $key ( keys %$matbl ) {
      $inputs{$matbl->{$key}->{lldpRemLocalPortNum}} = ({ label => "$lang{PORT} $matbl->{$key}->{lldpRemLocalPortNum}" });
    }
    foreach my $key ( sort { $a <=> $b } keys %inputs ) {
      $in++;
      $bd{$remp{$key}[0]} = ({
        top => $top,
        left => $left,
        properties => {
          title => $remp{$key}[0],
          inputs => {
            $remp{$key}[1] => {
              label => "$lang{PORT} $remp{$key}[1]"
            }
          }
        }
      });
      $links{$key} = ({
        fromOperator  => $nms->[0]->{id},
        fromConnector => $key,
        toOperator    => $remp{$key}[0],
        toConnector   => $remp{$key}[1],
      });
      $left = 500 if ( $in > 7 );
      $top = 0 if ( $in == 8 );
      $top = $top + 80;
    }
    $bd{$nms->[0]->{id}} = ({
      top => 20,
      left => 10,
      properties => {
        title => "$nms->[0]->{ip} $nms->[0]->{sysname}",
        outputs => \%inputs
      }
    });
    print flowchart(\%bd, \%links, {
      canUserEditLinks     => 'false',
      canUserMoveOperators => 'false',
      distanceFromArrow => 20,
      onOperatorSelect => "*function (operatorId) {window.location.href = '?index=$nms_index&ID=' + operatorId;return true;}*"
    });

    return 1
  }
  
  my $res = $html->element('div', '',
                { 
                id => 'RESULT',
                class => 'col-md-8',
                style => 'height:75vh;outline: 1px solid silver;'
              });
  my $search = $html->form_input('SEARCH', undef, {
      class => 'search-input form-control input-sm',
      EX_PARAMS => " placeholder='press Enter for search'"
    });
  my $tree = $html->element('div', $search . neighbors_tree(),
                  { 
                  class => 'col-md-4',
                  style => 'overflow-y: scroll;height:75vh;outline: 1px solid silver'
                });
  my $scr = qq(
   <script>
    jQuery(".search-input").keypress(function(e) {
      if (e.which == 13) {
        var searchString = jQuery(this).val();
        console.log(searchString);
        jQuery('#MY_TREE').jstree('search', searchString);
      }
    });
    jQuery("#MY_TREE").bind("loaded.jstree", function(event, data) {
      data.instance.open_node(1);
    });
    function renewLeftBox(id){
      var url = 'index.cgi?qindex=$index&header=2&ID=' + id;
      jQuery('#RESULT').load(url);
    };
    jQuery('#MY_TREE').on("changed.jstree", function (e, data) {
        renewLeftBox(data.instance.get_node(data.selected[0]).id)
    });
  </script>);

  print $html->element('div', $tree.$res, {class=>'row'}) . $scr;
  
  return 1
}
#**********************************************************
=head2 neighbors_tree()

=cut
#**********************************************************
sub neighbors_tree {
  my ($attr) = @_;
  my $nms = $Nms->obj_list({
    IP           => '_SHOW',
    SYS_NAME     => '_SHOW',
    SYS_LOCATION => '_SHOW',
    SYS_OBJECTID => '_SHOW',
    STATUS       => '_SHOW',
    COLS_NAME    => 1,
  });
  
  my %nms_t;
  foreach my $vl (@$nms) {
    $nms_t{$vl->{ip}} = [$vl->{id},$vl->{sysname}];
  }

  my @lldp_tree = ({
    id   => $nms_t{$conf{NMS_LLDP_ROOT}}[0],
    text => $nms_t{$conf{NMS_LLDP_ROOT}}[1],
    parent => '#',
    icon => 'fa fa-sitemap',
  #  a_attr => { style => 'color:red' }
  });
  if ($conf{NMS_LLDP_USEDB}){
    my %nms_t;
    foreach my $vl (@$nms) {
      $nms_t{$vl->{id}} = [$vl->{ip},$vl->{sysname}];
    }
    my $lldp = $Lldp->neighbors_list({
        COLS_NAME  => 1,
        OBJ_ID     => '_SHOW',
        NGR_ID     => '_SHOW',
        LOC_PORT   => '_SHOW',
    });
    foreach my $var ( @$lldp ){
      push @lldp_tree, ({
        id   => $var->{obj_id},
        text => $nms_t{$var->{obj_id}}[1],
        parent => $var->{neighbor_id},
        icon => 'fa fa-share-alt',
      });

    }
  }
  else {
    my %nms_t;
    foreach my $vl (@$nms) {
      $nms_t{$vl->{ip}} = [$vl->{id},$vl->{sysname}];
    }
    my %tree;
    my @arr =  ($conf{NMS_LLDP_ROOT});

    SNMP::loadModules('LLDP-MIB','MSTP-MIB');
    my @vbs = (SNMP::Varbind->new(['lldpRemManAddrOID']),SNMP::Varbind->new(['swMSTPMstPortRole']));
    my $vl = SNMP::VarList->new(@vbs);
    $snmpparms{UseSprintValue} = 0;

    while ( @arr > 0 ){
      my $ip = shift(@arr);
      $tree{$ip} = 1;
      my $sess = SNMP::Session->new(DestHost => $ip, %snmpparms );
      my ($res,$stp) = $sess->bulkwalk(0, 1, $vl);

      foreach my $port ( @$stp ){
        if ($port->[2] == 1){
          $stp = 0;
          last
        }
      }
    
      if ($stp != 0){
        foreach my $var ( @$res ){
          if ( $var->[2] ne '.0.0' ){
            $var->[1] =~ /\d+\.(\d+)\.\d+\.\d+\.\d+\.(\d+\.\d+\.\d+\.\d+)/gi;
            if ( !exists($tree{$2}) ){
              unshift @arr, $2;
              push @lldp_tree, ({
                id   => $nms_t{$2}[0],
                text => $nms_t{$2}[1],
                parent => $nms_t{$ip}[0],
                icon => 'fa fa-share-alt',
              });
            }
          }
        }
      }
    }
  }

  return make_tree({ data => \@lldp_tree, plugins => ['search','sort'] })
}



1;