#!perl

=head1 NAME

  Cable tester for NMS

=cut

use strict;
use warnings FATAL => 'all';
use Abills::Base qw(ip2int mk_unique_value);
use Nms::db::Traps;
use Nms::HTMLelem qw(oid_enums oid_conv);

our ( %lang, $Nms, $html, %conf, $admin, $db, %utils_menu, %actions );

my $Traps = Traps->new( $db, $admin, \%conf );
SNMP::addMibDirs('../../var/snmp/mibs');
SNMP::addMibDirs('../../var/snmp/mibs/private');
SNMP::initMib();

$utils_menu{NmsTraps} = ({ 
  obj_menu  => 'TRAPS',
 });
$actions{'TRAPS'} = ({
  obj_act  =>  \&nms_traps
});

$FUNCTIONS_LIST{"21:1:Traps:nms_trap_types:"} = 5;
$FUNCTIONS_LIST{"22:0:Traps:nms_traps:"} =  8;

#**********************************************************

=head2 nms_traps()

=cut

#**********************************************************
sub nms_traps {
    my ($attr) = @_;
    SNMP::addMibFiles( glob( '../../var/snmp/mibs/private' . '/*' ) );
    SNMP::loadModules('LLDP-MIB');

    if ( $attr->{MONIT} ) {
        my $oids = $Nms->oids_list(
            { TYPE => 'alert', SECTION => '_SHOW', COLS_NAME => 1 } );
        my @alerts_arr;
        foreach my $oid (@$oids) {
            push @alerts_arr,
              substr( $SNMP::MIB{ $oid->{section} }{objectID}, 1 );
        }
        $LIST_PARAMS{OID} = join( ",", @alerts_arr );
        $LIST_PARAMS{MONIT} = 1;
    }
    if ( $attr->{PAGE_ROWS} || $FORM{PAGE_ROWS} ) {
        $LIST_PARAMS{PAGE_ROWS} = $attr->{PAGE_ROWS} || $FORM{PAGE_ROWS};
    }
    $LIST_PARAMS{IP} = $attr->{IP};
    if ( !$attr->{IP} && $FORM{ID} ) {
        my $values = $Traps->trap_values( $FORM{ID} );
        foreach my $val (@$values) {
            if (   $SNMP::MIB{ $val->[1] }{syntax} eq 'OCTETSTR'
                || $SNMP::MIB{ $val->[1] }{syntax} eq 'PhysAddress' )
            {
                $val->[2] = bin2hex( $val->[2] );
            }
            if ( keys %{ $SNMP::MIB{ $val->[1] }{enums} } ) {
                my %en = oid_enums( $val->[1] );
                $val->[2] = $en{ $val->[2] };
            }
            my $rows = $html->element(
                'div',
                $html->element( 'label', $SNMP::MIB{ $val->[1] }{label} ),
                { class => 'col-sm-6', title => $val->[1] }
            );
            $rows .= $html->element(
                'div',
                $SNMP::MIB{ $val->[2] }{label} || $val->[2],
                { class => 'col-sm-6', title => $val->[2] }
            );
            print $html->element( 'div', $rows, { class => 'row' } );
        }
        return 1;
    }

    my ( $table, $list ) = result_former(
        {
            INPUT_DATA     => $Traps,
            FUNCTION       => 'traps_list',
            DEFAULT_FIELDS => 'TRAPTIME, IP, SYS_NAME, LABEL, TIMETICKS',

            #    FUNCTION_FIELDS => 'nms_traps:stats:id;&pg='.($FORM{pg}||''),
            HIDDEN_FIELDS => 'ID,OID',
            EXT_TITLES    => {
                traptime => $lang{TIME},
                label    => $lang{EVENTS},
                ip       => "IP " . $lang{ADDRESS},
            },
            SKIP_USER_TITLE => 1,
            FILTER_COLS     => {
                ip    => "search_link:nms_obj:,IP",
                label => 'oid_conv::,ID',
            },
            TABLE => {
                width   => '100%',
                caption => ( !$attr->{MONIT} ) ? 'Traps' : undef,
                header  => $html->button(
                    "$lang{CONFIG} 'Traps",
                    "index=" . get_function_index('nms_trap_types'),
                    { class => 'change' }
                ),
                qs => ( $FORM{NAS_ID} ) ? "$pages_qs&NAS_ID=$FORM{NAS_ID}"
                : $pages_qs,
                ID         => 'NMS_TRAPS_LIST',
                DATA_TABLE => ( $attr->{MONIT} )
                ? {
                    searching => undef,
                    paging    => undef,
                    order     => [ [ 0, 'desc' ] ]
                  }
                : undef
            },
            MAKE_ROWS     => 1,
            TOTAL         => ( $attr->{MONIT} ) ? 0 : 1,
            OUTPUT2RETURN => 1
        }
    );

    my $scr = qq(
    <script>
    jQuery('a#trap').on('click', function(){
       loadToModal('?get_index=nms_traps&header=2&ID=' + this.getAttribute('value'))
    })
    </script>
  );

    return $table->show() if $attr->{MONIT};
    print $table. $scr;
    return 1;
}

#********************************************************

=head2 nms_traps_clean()

=cut

#********************************************************
sub nms_traps_clean {
    $Traps->nms_traps_del( { PERIOD => $conf{TRAPS_CLEAN_PERIOD} || 30 } );
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
        $Nms->oid_del( $FORM{del} );
    }

    load_mibs( { ALL => 1 } );

    if ( $FORM{add} ) {
        $Nms->obj_oids_add(
            {
                SECTION  => $FORM{TRAP},
                LABEL    => $FORM{LABEL},
                TYPE     => $FORM{TYPE},
                OBJECTID => $OBJECTID,
            }
        );
    }
    if ( $FORM{new} ) {
        my @types = ( '<option>alert</option>', '<option>mac_notif</option>' );
        my $ind = $html->form_input( 'index', $index, { TYPE => 'hidden' } );
        my $in_box = $html->element(
            'div',
            $html->element( 'span', 'TRAP', { class => 'input-group-addon' } )
              . $html->form_input( 'TRAP', '', { class => 'form-control' } ),
            { class => 'input-group' }
        ) . $html->br;
        $in_box .= $html->element(
            'div',
            $html->element( 'span', 'LABEL', { class => 'input-group-addon' } )
              . $html->form_input( 'LABEL', '', { class => 'form-control' } ),
            { class => 'input-group' }
        ) . $html->br;
        $in_box .= $html->element(
            'div',
            $html->element( 'span', $lang{TYPE},
                { class => 'input-group-addon' } )
              . $html->element(
                'select', "@types",
                { class => 'form-control', id => 'TYPE', name => 'TYPE' }
              ),
            { class => 'input-group' }
        );
        my $sbm = $html->form_input( 'add', $lang{ADD}, { TYPE => 'submit' } );
        print $html->element( 'form', $ind . $in_box . $html->br . $sbm );
        return 1;
    }
    else {
        $LIST_PARAMS{OBJECTID} = $OBJECTID;
        my $modal_btn = $html->button(
            $lang{ADD},
            undef,
            {
                class          => 'btn btn-sm btn-default',
                JAVASCRIPT     => '',
                SKIP_HREF      => 1,
                NO_LINK_FORMER => 1,
                ex_params => qq/onclick=loadToModal('?get_index=nms_trap_types&header=2&new=1')/,
            }
        );
        result_former(
            {
                INPUT_DATA     => $Nms,
                FUNCTION       => 'oids_list',
                DEFAULT_FIELDS => 'SECTION,LABEL,IID,TYPE,ACCESS',
                FUNCTION_FIELDS =>
                  'oid_table_edit:change:id;type;label;objectid,del',
                HIDDEN_FIELDS => 'ID,OBJECTID',
                FILTER_COLS   => {
                    label   => 'oid_conv',
                    section => 'oid_conv',
                },
                SKIP_USER_TITLE => 1,
                TABLE           => {
                    caption => 'SNMP Traps',
                    qs      => "$pages_qs&OBJECTID=$OBJECTID",
                    ID      => 'OID_LIST',
                    header  => $modal_btn,
                },
                MAKE_ROWS => 1,
                TOTAL     => 1,
            }
        );
    }

    return 1;
}

1;
