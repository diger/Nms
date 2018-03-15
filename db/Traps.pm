package Traps;

=head1 NAME

  SNMP Traps for Nms

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

    return $self;
}

#**********************************************************

=head2 traps_list($attr)

=cut

#**********************************************************
sub traps_list {
    my $self = shift;
    my ($attr) = @_;

    $SORT      = ( $attr->{SORT} )      ? $attr->{SORT}      : 1;
    $DESC      = ( $attr->{DESC} )      ? $attr->{DESC}      : 'DESC';
    $PG        = ( $attr->{PG} )        ? $attr->{PG}        : 0;
    $PAGE_ROWS = ( $attr->{PAGE_ROWS} ) ? $attr->{PAGE_ROWS} : '';

    my $WHERE = $self->search_former(
        $attr,
        [
            [ 'ID',        'INT',  't.id',      1 ],
            [ 'TRAPTIME',  'DATE', 'traptime',  1 ],
            [ 'IP',        'IP',   't.ip',      'INET_NTOA(t.ip) AS ip' ],
            [ 'SYS_NAME',  'STR',  'sysname',   1 ],
            [ 'LABEL',     'STR',  'label',     1 ],
            [ 'OID',       'STR',  'oid',       1 ],
            [ 'TIMETICKS', 'STR',  'timeticks', 1 ],
        ],
        { WHERE => 1, }
    );

    $self->query2(
        "SELECT $self->{SEARCH_FIELDS} t.id as id
    FROM nms_traps t
    LEFT JOIN nms_obj n ON (n.ip=t.ip)
    $WHERE
    ORDER BY $SORT $DESC
    LIMIT $PG, $PAGE_ROWS;",
        undef,
        $attr
    );

    my $list = $self->{list};

    if ( $self->{TOTAL} > 0 && !$attr->{MONIT} ) {
        $self->query2(
            "SELECT COUNT(*) AS total
    FROM nms_traps
    $WHERE;", undef, { INFO => 1 }
        );
    }

    return $self->{list_hash} if ( $attr->{LIST2HASH} );

    return $list;
}

#**********************************************************
# trap_add()
#**********************************************************
sub trap_add {
    my $self = shift;
    my ($attr) = @_;

    $self->query_add(
        'nms_traps',
        {
            %$attr, TRAPTIME => 'NOW()',
        }
    );

    return $self;
}

#**********************************************************

=head2 trap_del($id)

=cut

#**********************************************************
sub trap_del {
    my $self = shift;
    my ($id) = @_;

    $self->query_del( 'nms_traps', { ID => $id } );

    return $self;
}

#**********************************************************

=head2 trap_values($attr)

=cut

#**********************************************************
sub trap_values {
    my $self = shift;
    my ($id) = @_;

    $self->query2(
        "SELECT *
    FROM nms_trap_values
    WHERE id= $id ;",
        undef,
    );

    my $list = $self->{list};

    return $list;
}

#**********************************************************
# trap_values_add()
#**********************************************************
sub trap_values_add {
    my $self = shift;
    my ($attr) = @_;

    $self->query_add( 'nms_trap_values', $attr );

    return $self;
}

#**********************************************************

=head2 nms_traps_del($attr)

=cut

#**********************************************************
sub nms_traps_del {
    my $self = shift;
    my ($attr) = @_;

    $self->query2(
"DELETE FROM nms_traps WHERE traptime < CURDATE() - INTERVAL $attr->{PERIOD} day;",
        'do'
    );

    return $self;
}

1;
