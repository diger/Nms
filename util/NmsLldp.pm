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
$snmpparms{UseEnums} = 1;
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
      $stbl->{$key}->{lldpRemPortId} =~ s|1/||;
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
      $inputs{$matbl->{$key}->{lldpRemLocalPortNum}} = ({ label => "Port $matbl->{$key}->{lldpRemLocalPortNum}" });
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
              label => "Port $remp{$key}[1]"
            }
          }
        }
      });
      $links{$key} = ({
        fromOperator  => $nms->[0]->{sysname},
        fromConnector => $key,
        toOperator    => $remp{$key}[0],
        toConnector   => $remp{$key}[1],
      });
      $left = 500 if ( $in > 7 );
      $top = 0 if ( $in == 8 );
      $top = $top + 80;
    }
    $bd{$nms->[0]->{sysname}} = ({
      top => 20,
      left => 10,
      properties => {
        title => "$nms->[0]->{ip} $nms->[0]->{sysname}",
        outputs => \%inputs
      }
    });
    print flowchart(\%bd, \%links, {
      canUserEditLinks     => 'false',
      canUserMoveOperators => 'false'
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
      EX_PARAMS => "placeholder='press Enter for search'"
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

  print $tree.$res. $scr;
  
  return 1
}
#**********************************************************
=head2 neighbors_tree()

=cut
#**********************************************************
sub neighbors_tree {
  my ($attr) = @_;
  my $lldp = $Lldp->neighbors_list({
    COLS_NAME  => 1,
    OBJ_ID     => '_SHOW',
    NGR_ID     => '_SHOW',
    LOC_PORT   => '_SHOW',
    SYS_NAME   => '_SHOW',
    TYPE       => '_SHOW',
    TIMEMARK   => '_SHOW'
  });
  
  my %tree;
  foreach my $vl (@$lldp) {
    $tree{$vl->{neighbor_id}}{$vl->{obj_id}} = $vl->{sysname};
  }

  my $root = 1;
  my $ind = 0;
  my @lldp_tree = ({
    id   => $root,
    text => 'Root',
    parent => '#',
    icon => 'fa fa-sitemap',
  #  a_attr => { style => 'color:red' }
  });

  while ( $ind < 500){
    $ind++;
    foreach my $vl ( keys %tree ) {
      my @key = keys %{$tree{$vl}};
      my @value = values %{$tree{$vl}};
      if ( @key == 1) {
        my %type;
        if ( $tree{$key[0]}{$vl}  &&  $vl != 1) {
          push @lldp_tree, ({
            id   => $vl,
            text => $tree{$key[0]}{$vl},
            parent => $key[0],
            icon => 'fa fa-share-alt',
            %type
          });
        }
        delete $tree{$vl} if $vl != 1;
        delete $tree{$key[0]}{$vl} if !$tree{$vl};
      }
      elsif ( @key < 1) {
        delete $tree{$vl};
      }
    }
    next if ( keys %tree > 1);
    last if ( keys %tree <= 1);
  }
    
#  print $ind . "\n";
#  print $html->element('div', Dumper \@lldp_tree );
#  print $html->element('div', Dumper \%tree );

  return make_tree({ data => \@lldp_tree, plugins => ['search'] })
}



1;