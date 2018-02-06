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
  ($admin, $CONF) = @_;

  my $self = {};
  bless($self, $class);

  $self->{db}=$db;
  $self->{admin} = $admin;
  $self->{conf} = $CONF;

  return $self;
}

#**********************************************************
=head2 neighbors_list($attr)

=cut
#**********************************************************
sub neighbors_list {
  my $self = shift;
  my ($attr) = @_;

  $SORT      = ($attr->{SORT})      ? $attr->{SORT}      : 1;
  $DESC      = ($attr->{DESC})      ? $attr->{DESC}      : 'DESC';
  $PG        = ($attr->{PG})        ? $attr->{PG}        : 0;
  $PAGE_ROWS = ($attr->{PAGE_ROWS}) ? $attr->{PAGE_ROWS} : '';

  my $WHERE =  $self->search_former($attr, [
    ['ID',        'INT',  'l.id',      1 ],
    ['OBJ_ID',    'INT',  'obj_id',    1 ],
    ['LOC_PORT',  'INT',  'loc_port',  1 ],
    ['REM_PORT',  'INT',  'rem_port',  1 ],
    ['SYS_NAME',  'STR',  'sysname',   1 ],
    ['TYPE',      'STR',  'type',      1 ],
	  ['TIMEMARK',  'STR',  'timemark',  1 ],
    ],
    { WHERE => 1,
    }
  );

  $self->query2("SELECT $self->{SEARCH_FIELDS} l.id as id
    FROM nms_obj_lldp l
    LEFT JOIN nms_obj n ON (n.id=obj_id)
    $WHERE
    ORDER BY $SORT $DESC
    LIMIT $PG, $PAGE_ROWS;",
    undef,
    $attr
  );

  my $list = $self->{list};
  
  if ($self->{TOTAL} > 0 && !$attr->{MONIT}) {
    $self->query2("SELECT COUNT(*) AS total
    FROM nms_obj_lldp
    $WHERE;", undef, { INFO => 1 }
    );
  }
  
  return $self->{list_hash} if ($attr->{LIST2HASH});

  return $list;
}

#**********************************************************
# neighbor__add()
#**********************************************************
sub neighbor_add {
  my $self = shift;
  my ($attr) = @_;

  my $UPD =  $self->search_former($attr, [
    ['ID',        'INT',  'l.id',      1 ],
    ['OBJ_ID',    'INT',  'obj_id',    1 ],
    ['LOC_PORT',  'INT',  'loc_port',  1 ],
    ['REM_PORT',  'INT',  'rem_port',  1 ],
    ['SYS_NAME',  'STR',  'sysname',   1 ],
    ['TYPE',      'STR',  'type',      1 ],
	  ['TIMEMARK',  'STR',  'timemark',  1 ],
    ],
    { WHERE => 1,
    }
  );
  $UPD =~ s/AND/,/g;
  $UPD =~ s/\(|\)//g;
  $self->{SEARCH_FIELDS} =~ s/,\s$//;
  my $VALUES = join(',', @{$self->{SEARCH_VALUES}});
  $self->query2("INSERT INTO nms_obj_lldp ( $self->{SEARCH_FIELDS} ) VALUES
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
  my ($id) = @_;

  $self->query_del('nms_obj_lldp', { ID => $id });

  return $self;
}

1;
