package Cable;

=head1 NAME

  Equipment managment system

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
=head2 cable_test_list($attr)

=cut
#**********************************************************
sub cable_test_list {
  my $self = shift;
  my ($attr) = @_;

  $SORT      = ($attr->{SORT})      ? $attr->{SORT}      : 1;
  $DESC      = ($attr->{DESC})      ? $attr->{DESC}      : '';
  $PG        = ($attr->{PG})        ? $attr->{PG}        : 0;
  $PAGE_ROWS = ($attr->{PAGE_ROWS}) ? $attr->{PAGE_ROWS} : 50;

  my $WHERE =  $self->search_former($attr, [
    ['ID',       'INT', 'id',       1 ],
    ['LABEL',    'STR', 'label',    1 ],
	  ['OBJECTID', 'STR', 'objectid', 1 ],
	  ['TYPE',     'STR', 'type',     1 ],
    ],
    { WHERE => 1,
    }
  );

  $self->query2("SELECT $self->{SEARCH_FIELDS} id
    FROM nms_cable_test
    $WHERE
    ORDER BY $SORT $DESC
    LIMIT $PG, $PAGE_ROWS;",
    undef,
    $attr
  );

  my $list = $self->{list};
  
  return $self->{list_hash} if ($attr->{LIST2HASH});

  return $list;
}

#**********************************************************
# cable_test_add()
#**********************************************************
sub cable_test_add {
  my $self = shift;
  my ($attr) = @_;

  $self->query_add( 'nms_cable_test', $attr,
    {
      REPLACE => 1
    } );
        
  return $self;
}

#**********************************************************
=head2 cable_test_del($id)

=cut
#**********************************************************
sub cable_test_del {
  my $self = shift;
  my ($id) = @_;

  $self->query_del('nms_cable_test', { ID => $id });

  return $self;
}


1
