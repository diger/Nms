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
use Nms::HTMLelem qw(label_w_txt table_header2 oid_enums);

our ( %lang, $Nms, $html, %conf, $admin, $db, %utils_menu, %actions );

my %snmpparms;
$snmpparms{Version}   = 2;
$snmpparms{Retries}   = 1;
$snmpparms{Timeout}   = 2000000;
$snmpparms{Community} = $conf{NMS_COMMUNITY_RW};

$utils_menu{CableTest} = (
    {
        cfg_menu  => 'CABLE',
        user_menu => 'CABLE',
    }
);
$actions{'CABLE'} = (
    {
        cfg_act  => \&cable_test_setup,
        user_act => \&cable_test,
    }
);
$FUNCTIONS_LIST{"42:0:Cable:cable_test:PORT5"} = 8;

#**********************************************************

=head2 cable_test()

=cut

#**********************************************************
sub cable_test {
    my ($attr) = @_;

    my $prm = load_mibs( { ID => $attr->{ID} || $FORM{ID} } );
    if ( $FORM{UID} && pon_test( { UID => $FORM{UID}, IP => $prm->{ip} } ) ) {
        return 1;
    }
    my $test_param = $Nms->oids_list(
        {
            OBJECTID  => $prm->{sysobjectid},
            LABEL     => '_SHOW',
            SECTION   => '_SHOW',
            TYPE      => 'cable',
            LIST2HASH => 'label,section'
        }
    );
    my $mib;
    my @vars;
    my %pair;

    foreach my $key ( keys %$test_param ) {
        $mib = $key if $test_param->{$key} eq 'action';
        push @vars, [ $key, $attr->{PORT} || $FORM{PORT} ]
          if $test_param->{$key} ne 'action';
        push @{ $pair{ $test_param->{$key} } }, $key;
    }

    my $sess = SNMP::Session->new( DestHost => $prm->{ip}, %snmpparms );
    my $value = $SNMP::MIB{$mib}{enums}{action} || 1;
    if ( !$FORM{header} ) {
        my $vb = SNMP::Varbind->new( [ $mib, $attr->{PORT}, $value ] );
        $sess->set($vb);

        if ( $sess->{ErrorNum} ) {
            return $html->message( 'err', $lang{ERROR}, $sess->{ErrorStr} );
        }
        print $html->element(
            'ul',
            "<i class='fa fa-spinner fa-spin fa-5x'></i>",
            { ID => 'CBLT', class => 'list-group' }
        );
        print qq(
           <script>
           setTimeout(function() {
             var url = '?get_index=cable_test&header=2&PORT=$attr->{PORT}&ID=$attr->{ID}';
             jQuery('#CBLT').load(url);
           }, 3000);
           </script>
           );
        return 1;
    }

    my $vl = SNMP::VarList->new(@vars);
    $sess->get($vl);
    if ( $sess->{ErrorNum} ) {
        return $html->message( 'err', $lang{ERROR}, $sess->{ErrorStr} );
    }
    my %result;
    foreach my $res (@vars) {
        $result{ $res->[0] } = $res->[2];
    }

    my $li = '';
    if ( $pair{status} ) {
        $li .= $html->element( 'li', 'Link Status', { class => 'nav-header' } );
        my %en   = oid_enums( $pair{status}[0] );
        my $span = $pair{status}[0]
          . $html->element(
            'span',
            $en{ $result{ $pair{status}[0] } },
            { class => 'badge' }
          );
        $li .= $html->element( 'li', $span, { class => 'list-group-item' } );
    }
    if ( $pair{length} ) {
        $li .= $html->element( 'li', 'Pair Length', { class => 'nav-header' } );
        if ( @{ $pair{length} } == 1 ) {
            my $res = $result{ $pair{length}[0] };
            $res =~ s/\n/<br>/g;
            $li .= $html->element( 'li', $res, { class => 'list-group-item' } );
        }
        else {
            foreach my $res ( sort @{ $pair{length} } ) {
                my $color =
                  ( $result{$res} >= 92 ) ? 'list-group-item-warning' : '';
                my $span =
                  $res
                  . $html->element( 'span', $result{$res},
                    { class => 'badge' } );
                $li .= $html->element( 'li', $span,
                    { class => "list-group-item $color" } );
            }
        }
    }
    if ( $pair{pair_status} ) {
        $li .= $html->element( 'li', 'Pair Status', { class => 'nav-header' } );
        foreach my $res ( sort @{ $pair{pair_status} } ) {
            my %en   = oid_enums($res);
            my $span = $res
              . $html->element(
                'span',
                $en{ $result{$res} } || $result{$res},
                { class => 'badge' }
              );
            $li .=
              $html->element( 'li', $span, { class => 'list-group-item' } );
        }
    }
    print $li;

    return 1;
}

#**********************************************************

=head2 cable_test_setup()

=cut

#**********************************************************
sub cable_test_setup {

    my ($attr) = @_;

    if ( $FORM{del} ) {
        $Nms->oid_del( $FORM{del} );
    }
    if ( $FORM{SAVE} ) {
        $Nms->obj_oids_add(
            {
                LABEL    => $FORM{LABEL},
                TYPE     => 'cable',
                OBJECTID => $FORM{OBJECTID},
                SECTION  => $FORM{TYPE},
            }
        );
    }

    if ( $FORM{ID} ) {
        oid_table_row_edit( { OID_ID => $FORM{ID} } );
    }

    if ( $FORM{add} ) {
        load_mibs( { ID => $FORM{OBJECTID} } );
        my @labels;
        foreach my $oid ( keys(%SNMP::MIB) ) {
            if (   $SNMP::MIB{$oid}{label} =~ /Cable/
                || $SNMP::MIB{$oid}{label} =~ /cable/
                || $SNMP::MIB{$oid}{label} =~ /vct/
                && !$SNMP::MIB{$oid}{children}[0]{label} )
            {
                push @labels, $SNMP::MIB{$oid}{label};
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
        my @types = ( 'length', 'pair_status', 'status', 'action', );
        my $TYPE_SEL = $html->form_select(
            'TYPE',
            {
                SELECTED  => $FORM{OID},
                SEL_ARRAY => \@types,
                NO_ID     => 1
            }
        );
        print $html->form_main(
            {
                CONTENT => label_w_txt( $lang{NAME}, $LABEL_SEL )
                  . label_w_txt( $lang{TYPE}, $TYPE_SEL )
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
                    'ID'       => $FORM{chg} || '',
                    'OBJECTID' => $FORM{OBJECTID},
                    'oid_type' => 'CABLE'
                },
            }
        );

        return 1;
    }
    else {
        $LIST_PARAMS{OBJECTID} = $FORM{OBJECTID};
        $LIST_PARAMS{TYPE}     = 'cable';
        result_former(
            {
                INPUT_DATA      => $Nms,
                FUNCTION        => 'oids_list',
                DEFAULT_FIELDS  => 'LABEL,SECTION',
                FUNCTION_FIELDS => ':change:id;objectid;&oid_type=CABLE,del',
                HIDDEN_FIELDS   => 'ID,OBJECTID',
                EXT_TITLES      => {
                    label => "$lang{NAME}",
                    type  => "$lang{TYPE}",
                },
                SKIP_USER_TITLE => 1,
                TABLE           => {
                    qs => "$pages_qs&OBJECTID=$FORM{OBJECTID}",
                    ID => 'OID_LIST',
                    MENU =>
"$lang{ADD}:index=$index$pages_qs&OBJECTID=$FORM{OBJECTID}&oid_type=CABLE&add=1:add",
                },
                MAKE_ROWS => 1,
                TOTAL     => 1
            }
        );
    }

    return 1;
}

#**********************************************************

=head2 pon_test()

=cut

#**********************************************************
sub pon_test {
    my ($attr) = @_;
    $Nms->query2(
        "SELECT _onu_mac AS ONU_MAC FROM users_pi WHERE uid='$attr->{UID}';",
        undef, { INFO => 1 } );
    if ( $Nms->{ONU_MAC} ) {
        $snmpparms{UseSprintValue} = 1;
        my $sess = SNMP::Session->new( DestHost => $attr->{IP}, %snmpparms );
        my @result = $sess->bulkwalk( 0, 1, ['onuID'] );
        if ( $sess->{ErrorNum} ) {
            return $html->message( 'err', $lang{ERROR}, $sess->{ErrorStr} );
        }
        print Dumper @result;
    }
    return $Nms->{ONU_MAC};
}

1;
