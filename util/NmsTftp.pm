#!perl

=head1 NAME

  TFTP upload/download for NMS

=cut

use strict;
use warnings FATAL => 'all';
use Abills::Base qw(ip2int mk_unique_value);

use Nms::HTMLelem qw(label_w_txt table_header2 oid_enums);

our ( %lang, $Nms, $html, %conf, $admin, $db, %utils_menu, %actions );

my %snmpparms;
$snmpparms{Version}   = 2;
$snmpparms{Retries}   = 1;
$snmpparms{Timeout}   = 2000000;
$snmpparms{Community} = $conf{NMS_COMMUNITY_RW};

$utils_menu{NmsTftp} = (
    {
        cfg_menu => 'TFTP',
        obj_menu => 'TFTP'
    }
);
$actions{'TFTP'} = (
    {
        cfg_act => \&tftp_setup,
        obj_act =>  \&tftp_action
    }
);

#**********************************************************

=head2 tftp_action()

=cut

#**********************************************************
sub tftp_action {
    my ($attr) = @_;
    my $prm = load_mibs( { ID => $attr->{ID} } );

    my $tftp_param = $Nms->oids_list(
        {
            OBJECTID  => $prm->{sysobjectid},
            VALUE     => '_SHOW',
            LABEL     => '_SHOW',
            SECTION   => '_SHOW',
            TYPE      => 'tftp',
            COLS_NAME => 1,
        }
    );
    
    my %param;
    foreach my $row (@$tftp_param) {
      push @{$param{$row->{section}}},( $row->{label}, $row->{value}) 
    }
    if ( $FORM{SAVE} ) {
      my @mibs;
      my $ind = ( $param{index} )? $param{index}[1] : 0;
      push @mibs, SNMP::Varbind->new( [ $param{ip_adress}[0], $ind, $param{ip_adress}[1] ] );
      push @mibs, SNMP::Varbind->new( [ $param{src_name}[0], $ind, $param{src_name}[1] ] ) if $param{src_name};
      push @mibs, SNMP::Varbind->new( [ $param{dst_name}[0], $ind, $param{dst_name}[1] || $attr->{ID}.'.cfg' ] ) if $param{dst_name};
      push @mibs, SNMP::Varbind->new( [ $param{transfer_type}[0], $ind, $param{transfer_type}[1] ] );
      push @mibs, SNMP::Varbind->new( [ $param{upload}[0], $ind, $param{upload}[1] ] ) if $param{upload};
      push @mibs, SNMP::Varbind->new( [ $param{start}[0], $ind, $param{start}[1] ] );
      my $vb = SNMP::VarList->new(@mibs);

      my $sess = SNMP::Session->new( DestHost => $attr->{IP}, %snmpparms );
      $sess->set($vb);
      print Dumper $vb;

      if ( $sess->{ErrorNum} ) {
          return $html->message( 'err', $lang{ERROR}, $sess->{ErrorStr} );
      }
    }
    
    print $html->form_main(
        {
            CONTENT => $html->form_input(
                        'SAVE',
                        $lang{SAVE},
                        {
                            TYPE => 'SUBMIT'
                        }
                      ),
            METHOD => 'GET',
            HIDDEN => {
                'index'    => $index,
                'visual'   => 'TFTP',
                'ID'       => $attr->{ID}
            },
            class => 'form-horizontal'
        }
    );
#    sleep(2);
#    my $vl = SNMP::VarList->new(@vars);
#    $sess->get($vl);
 #   if ( $sess->{ErrorNum} ) {
#        return $html->message( 'err', $lang{ERROR}, $sess->{ErrorStr} );
#    }
#    my %result;
 #   foreach my $res (@vars) {
 #       $result{ $res->[0] } = $res->[2];
#    }
 
    return 1;
}

#**********************************************************

=head2 tftp_setup()

=cut

#**********************************************************
sub tftp_setup {

    my ($attr) = @_;

    if ( $FORM{del} ) {
        $Nms->oid_del( $FORM{del} );
    }
    if ( $FORM{OBJECTID} ) {
        tftp_setup_edit( { OBJECTID => $FORM{OBJECTID} } );
    }
    elsif ( $FORM{add} ) {
        $Nms->obj_oids_add(
            {
                LABEL   => $FORM{add},
                SECTION => $FORM{SECT},
                TYPE    => $FORM{TYPE},
            }
        );
        $html->redirect( 'index.cgi?&index=' . $index );
    }
    elsif ( $FORM{ID} ) {
        oid_table_row_edit( { OID_ID => $FORM{ID} } );
    }
    else {
        result_former(
            {
                INPUT_DATA      => $Nms,
                FUNCTION        => 'sysobjectid_list',
                DEFAULT_FIELDS  => 'LABEL, OBJECTID',
                FUNCTION_FIELDS => 'tftp_setup:change:objectid',
                SKIP_USER_TITLE => 1,
                TABLE           => {
                    qs => ( $FORM{OBJECTID} )
                    ? "$pages_qs&OBJECTID=$FORM{OBJECTID}"
                    : $pages_qs,
                    ID => 'TFTP_SETUP',
                },
                MAKE_ROWS => 1,
                TOTAL     => 1
            }
        );
    }

    return 1;
}

#**********************************************************

=head2 tftp_setup_edit()

=cut

#**********************************************************
sub tftp_setup_edit {

    my ($attr) = @_;

    if ( $FORM{del} ) {
        $Nms->oid_del( $FORM{del} );
    }

    $LIST_PARAMS{OBJECTID} = $FORM{OBJECTID};
    $LIST_PARAMS{TYPE}     = 'tftp';
    my ( $table, $list ) = result_former(
        {
            INPUT_DATA     => $Nms,
            FUNCTION       => 'oids_list',
            DEFAULT_FIELDS => 'LABEL,SECTION,VALUE',
            FUNCTION_FIELDS =>
              'change,del',
            HIDDEN_FIELDS => 'ID,OBJECTID',
            EXT_TITLES    => {
                label => "$lang{NAME}",
                type  => "$lang{TYPE}",
            },
            SKIP_USER_TITLE => 1,
            TABLE           => {
                qs => "$pages_qs&OBJECTID=$FORM{OBJECTID}&oid_type=TFTP",
                ID => 'OID_LIST',
                MENU =>
"$lang{ADD}:index=$index$pages_qs&OBJECTID=$FORM{OBJECTID}&oid_type=TFTP&add=1:add",
            },
            MAKE_ROWS => 1,
            TOTAL     => 1,
            OUTPUT2RETURN => 1
        }
    );
    if ( $FORM{add} || $FORM{chg} ) {
        load_mibs( { ID => $FORM{OBJECTID} } );
        my %labels;
        foreach my $oid ( keys(%SNMP::MIB) ) {
            if ( $SNMP::MIB{$oid}{label} =~ /agentBscSwFile|^file|File/ )
            {
                {
                    my %enums = oid_enums( $SNMP::MIB{$oid}{label} );
                    $labels{ $SNMP::MIB{$oid}{label} } =
                      (%enums) ? \%enums : undef;
                }
            }
        }
        my $vals  = JSON->new->indent->encode( \%labels );
        my @keys  = sort keys %labels;
        my @types = (
        'index',     'ip_adress', 'upload', 'download', 'src_name',
        'dst_name', 'file_type', 'transfer_type', 'start',  'status'
        );

        print $html->form_main(
            {
                CONTENT => label_w_txt(
                    'TYPE',
                    $list->[0]->{section} || 'write',
                    { INP => 'select', SELECT => \@types }
                  )
                  . label_w_txt(
                    'OID',
                    $list->[0]->{label} || 0,
                    { INP => 'select', SELECT => \@keys }
                  )
                  . label_w_txt(
                    'VALUE',
                    $list->[0]->{value} || 0,
                    {
                        INP => (
                                 $list->[0]->{label}
                              && $labels{ $list->[0]->{label} }
                          ) ? 'select' : 'input',
                        SELECT => (
                                 $list->[0]->{label}
                              && $labels{ $list->[0]->{label} }
                        ) ? $labels{ $list->[0]->{label} } : ''
                    }
                  )
                  . label_w_txt(
                    undef,
                    $html->form_input(
                        'SAVE',
                        ( $FORM{chg} ) ? $lang{CHANGE} : $lang{CREATE},
                        {
                            TYPE => 'SUBMIT'
                        }
                      )
                      . "	"
                      . $html->button(
                        $lang{CANCEL},
                        "index=$index$pages_qs",
                        { class => "btn btn-default" }
                      ),
                    { RCOL => 3 }
                  ),
                METHOD => 'GET',
                HIDDEN => {
                    'index'    => $index,
                    'oid_type' => 'TFTP',
                    'OBJECTID' => $attr->{OBJECTID},
                    'ID'       => $FORM{chg}
                },
                class => 'form-horizontal'
            }
        );
        print qq(
    <script>
    var selectValues = $vals;
    jQuery('select#OID').on('change', function() {
      if (selectValues[this.value] === null ) {
        jQuery('select#VALUE').chosen("destroy");
        jQuery('select#VALUE').replaceWith("<input class='form-control' name='VALUE' id='VALUE'></input>");
      }
      else {
        jQuery('input#VALUE').replaceWith("<select class='form-control' name='VALUE' id='VALUE'></select>");
        jQuery('select#VALUE').chosen();
        jQuery('select#VALUE').empty();
        jQuery.each(selectValues[this.value], function(key, value) {
          jQuery('select#VALUE').append('<option value=' + key + '>' + value + '<option>');
        });
        jQuery('select#VALUE').trigger("chosen:updated");
      }
    });
    </script>
  );

        return 1;
    }
    else {
      print $table;
    }

    return 1;
}

1;
