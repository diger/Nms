package Lldp;

=head1 NAME

  Lldp for NMS

=cut

use strict;
use parent 'main';
use warnings FATAL => 'all';
use Socket;

my $admin;
my $CONF;
my $SORT      = 1;
my $DESC      = '';
my $PG        = 0;
my $PAGE_ROWS = 25;

#**********************************************************
# New
#**********************************************************
sub new {
    my $class = shift;
    my $db    = shift;
    ( $admin, $CONF ) = @_;

    my $self = {};
    bless( $self, $class );

    $self->{db}    = $db;
    $self->{admin} = $admin;
    $self->{conf}  = $CONF;
    
    $CONF->{NMS_LLDP_ROOT} = '10.0.0.1';
    $CONF->{NMS_LLDP_USEDB} = 1;
    $CONF->{NMS_LLDP_STP} = 0;

    return $self;
}

#**********************************************************

=head2 neighbors_list($attr)

=cut

#**********************************************************
sub neighbors_list {
    my $self = shift;
    my ($attr) = @_;

    $SORT      = ( $attr->{SORT} )      ? $attr->{SORT}      : 1;
    $DESC      = ( $attr->{DESC} )      ? $attr->{DESC}      : 'DESC';
    $PG        = ( $attr->{PG} )        ? $attr->{PG}        : 0;
    $PAGE_ROWS = ( $attr->{PAGE_ROWS} ) ? $attr->{PAGE_ROWS} : '';

    my $WHERE = $self->search_former(
        $attr,
        [
            [ 'OBJ_ID',   'INT', 'obj_id',      1 ],
            [ 'NGR_ID',   'INT', 'neighbor_id', 1 ],
            [ 'LOC_PORT', 'INT', 'loc_port',    1 ],
        ],
        { WHERE => 1, }
    );

    $self->query2(
        "SELECT $self->{SEARCH_FIELDS} obj_id
    FROM nms_obj_lldp
    $WHERE
    ORDER BY $SORT $DESC;",
        undef,
        $attr
    );

    my $list = $self->{list};

    if ( $self->{TOTAL} > 0 && !$attr->{MONIT} ) {
        $self->query2(
            "SELECT COUNT(*) AS total
    FROM nms_obj_lldp
    $WHERE;", undef, { INFO => 1 }
        );
    }

    return $self->{list_hash} if ( $attr->{LIST2HASH} );

    return $list;
}

#**********************************************************
# neighbor__add()
#**********************************************************
sub neighbor_add {
    my $self = shift;
    my ($attr) = @_;

    my $UPD = $self->search_former(
        $attr,
        [
            [ 'OBJ_ID',   'INT', 'obj_id',      1 ],
            [ 'NGR_ID',   'INT', 'neighbor_id', 1 ],
            [ 'LOC_PORT', 'INT', 'loc_port',    1 ],
            [ 'TIMEMARK', 'INT', 'timemark',    1 ],
        ]
    );
    $UPD =~ s/AND/,/g;
    $UPD =~ s/\(|\)//g;
    $self->{SEARCH_FIELDS} =~ s/,\s$//;
    my $VALUES = join( ',', @{ $self->{SEARCH_VALUES} } );
    $self->query2(
        "INSERT INTO nms_obj_lldp ( $self->{SEARCH_FIELDS} ) VALUES
    ( $VALUES )
    ON DUPLICATE KEY UPDATE $UPD;", 'do'
    );

    return $self;
}

#**********************************************************

=head2 neighbor_del($id)

=cut

#**********************************************************
sub neighbor_del {
    my $self = shift;
    my ( $attr, $clear ) = @_;

    $self->query_del(
        'nms_obj_lldp',
        undef,
        {
            obj_id      => $attr->{OBJ_ID},
            neighbor_id => $attr->{NEI_ID},
        },
        { CLEAR_TABLE => $clear }
    );

    return $self;
}

1;
