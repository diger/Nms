package Nms;

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
=head2 obj_list($attr)

=cut
#**********************************************************
sub obj_list {
  my $self = shift;
  my ($attr) = @_;

  $SORT      = ($attr->{SORT} && $attr->{SORT} == 1) ? 'LPAD( o.ip, 16, 0 )' : $attr->{SORT}|| 1;
  $DESC      = ($attr->{DESC})      ? $attr->{DESC}        : '';
#  $PG        = ($attr->{PG})        ? $attr->{PG}          : 0;
#  $PAGE_ROWS = ($attr->{PAGE_ROWS}) ? $attr->{PAGE_ROWS}   : 25;

  my $SECRETKEY = $CONF->{secretkey} || '';
  my $WHERE =  $self->search_former($attr, [
    ['IP',           'IP',  'o.ip',  'INET_NTOA(o.ip) AS ip' ],
	  ['NAS_NAME',     'STR', 'name',                      1 ],
	  ['SYS_NAME',     'STR', 'sysname',                   1 ],
	  ['SYS_LOCATION', 'STR', 'syslocation',               1 ],
    ['SYS_OBJECTID', 'STR', 'sysobjectid',               1 ],
    ['STATUS',       'INT', 'status',                    1 ],
	  ['ID',           'INT', 'o.id',                      1 ],
	  ['NAS_ID',       'INT', 'n.id',       'n.id AS nas_id' ],
	  ['RO_COMMUNITY', 'STR', '', "DECODE(ro_community, '$SECRETKEY') AS ro_community"],
	  ['RW_COMMUNITY', 'STR', '', "DECODE(rw_community, '$SECRETKEY') AS rw_community"],
    ],
    { WHERE => 1,
    }
  );
  
  $self->query2("SELECT $self->{SEARCH_FIELDS} o.id AS id
    FROM nms_obj o
    LEFT JOIN nas n ON (n.ip=o.ip)
    $WHERE
    ORDER BY $SORT $DESC;",
    undef,
    $attr
  );

  my $list = $self->{list};

  $self->query2("SELECT COUNT(*) AS total
    FROM nms_obj o
    $WHERE;",
    undef,
    { INFO => 1 }
  );
  return $self->{list_hash} if ($attr->{LIST2HASH});
  return $list;
}

#**********************************************************
# obj_add()
#**********************************************************
sub obj_add {
  my $self = shift;
  my ($attr) = @_;

  $self->query2("INSERT INTO nms_obj ( ip, sysobjectid, sysname, syslocation ) VALUES
				('$attr->{IP}',
         '$attr->{SYSOBJECTID}',
         '$attr->{SYSNAME}',
         '$attr->{SYSLOCATION}')
				ON DUPLICATE KEY UPDATE sysobjectid='$attr->{SYSOBJECTID}',
                                sysname='$attr->{SYSNAME}',
                                syslocation='$attr->{SYSLOCATION}'
                                ", 'do'
				);
        
  return $self;
}

#**********************************************************
=head2 obj_values_list($attr)

=cut
#**********************************************************
sub obj_values_list {
  my $self = shift;
  my ($attr) = @_;

  $SORT      = ($attr->{SORT})      ? $attr->{SORT}      : 1;
  $DESC      = ($attr->{DESC})      ? $attr->{DESC}      : '';
  $PG        = ($attr->{PG})        ? $attr->{PG}        : 0;
  $PAGE_ROWS = ($attr->{PAGE_ROWS}) ? $attr->{PAGE_ROWS} : 50;

  my $WHERE =  $self->search_former($attr, [
      ['OBJ_ID', 'INT', 'obj_id',  1 ],
      ['OBJ_IND','INT', 'obj_ind', 1 ],
	  ['OID_ID', 'STR', 'oid_id',  1 ],
	  ['VALUE',  'STR', 'value',   1 ],
    ],
    { WHERE => 1,
    }
  );

  $self->query2("SELECT $self->{SEARCH_FIELDS} obj_id
    FROM nms_obj_values
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
# obj_values_add()
#**********************************************************
sub obj_values_add {
  my $self = shift;
  my ($attr) = @_;

  $self->query2("INSERT INTO nms_obj_values (obj_id, oid_id, obj_ind, value) VALUES
				('$attr->{OBJ_ID}', '$attr->{OID_ID}', '$attr->{OBJ_IND}', '$attr->{VALUE}')
				ON DUPLICATE KEY UPDATE value='$attr->{VALUE}'", 'do'
				);

  return $self;
}

#**********************************************************
=head2 oids_list($attr)

=cut
#**********************************************************
sub oids_list {
  my $self = shift;
  my ($attr) = @_;

  $SORT      = ($attr->{SORT})      ? $attr->{SORT}      : 1;
  $DESC      = ($attr->{DESC})      ? $attr->{DESC}      : '';
  $PG        = ($attr->{PG})        ? $attr->{PG}        : 0;
  $PAGE_ROWS = ($attr->{PAGE_ROWS}) ? $attr->{PAGE_ROWS} : 50;
  my $GROUP  = ($attr->{GROUP})     ? "GROUP BY $attr->{GROUP}" : '';

  my $WHERE =  $self->search_former($attr, [
    ['ID',       'INT', 'id',       1 ],
    ['SECTION',  'STR', 'section',  1 ],
    ['LABEL',    'STR', 'label',    1 ],
	  ['OBJECTID', 'STR', 'objectid', 1 ],
	  ['IID',      'INT', 'iid',      1 ],
	  ['TYPE',     'STR', 'type',     1 ],
	  ['ACCESS',   'STR', 'access',   1 ],
    ],
    { WHERE => 1,
    }
  );

  $self->query2("SELECT $self->{SEARCH_FIELDS} id
    FROM nms_oids
    $WHERE
    $GROUP
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
# obj_oids_add()
#**********************************************************
sub obj_oids_add {
  my $self = shift;
  my ($attr) = @_;
=comm
  my $UPD =  $self->search_former($attr,
    [
      ['ID',       'INT', 'id',       1 ],
      ['SECTION',  'STR', 'section',  1 ],
      ['LABEL',    'STR', 'label',    1 ],
  	  ['OBJECTID', 'STR', 'objectID', 1 ],
  	  ['IID',      'INT', 'iid',      1 ],
  	  ['TYPE',     'STR', 'type',     1 ],
  	  ['ACCESS',   'STR', 'access',   1 ],
    ]
  );
  
  $self->query2("INSERT INTO nms_oids ( $self->{SEARCH_FIELDS} ) VALUES
				( $self->{SEARCH_VALUES} )
				ON DUPLICATE KEY UPDATE $UPD;", 'do'
				);
=cut
  $self->query_add( 'nms_oids', $attr,
    {
      REPLACE => 1
    } );
        
  return $self;
}
#**********************************************************
=head2 oid_del($id)

=cut
#**********************************************************
sub oid_del {
  my $self = shift;
  my ($id) = @_;

  $self->query_del('nms_oids', { ID => $id });

  return $self;
}

#**********************************************************
=head2 oids_rows_list($attr)

=cut
#**********************************************************
sub oids_rows_list {
  my $self = shift;
  my ($attr) = @_;

  $SORT      = ($attr->{SORT})      ? $attr->{SORT}      : 1;
  $DESC      = ($attr->{DESC})      ? $attr->{DESC}      : '';
  $PG        = ($attr->{PG})        ? $attr->{PG}        : 0;
  $PAGE_ROWS = ($attr->{PAGE_ROWS}) ? $attr->{PAGE_ROWS} : 50;

  my $WHERE =  $self->search_former($attr, [
    ['ID',   'INT', 'id',   1 ],
	  ['LABEL',    'STR', 'label',    1 ],
	  ['OBJECTID', 'STR', 'objectID', 1 ],
	  ['IID',      'INT', 'iid',      1 ],
	  ['ACCESS',   'INT', 'access',   1 ],
    ],
    { WHERE => 1,
    }
  );

  $self->query2("SELECT $self->{SEARCH_FIELDS} label
    FROM nms_oids_rows
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
# oid_row_add()
#**********************************************************
sub oid_row_add {
  my $self = shift;
  my ($attr) = @_;

  $self->query_add('nms_oids_rows', $attr);

  return $self;
}

#**********************************************************
=head2 oid_row_del($id)

=cut
#**********************************************************
sub oid_row_del {
  my $self = shift;
  my ($attr) = @_;

  $self->query2("DELETE FROM nms_oids_rows WHERE label='$attr->{LABEL}' AND id=$attr->{OID_ID};", 'do');
 
  return $self;
}

#**********************************************************
# vendor_add()
#**********************************************************
sub vendor_add {
  my $self = shift;
  my ($attr) = @_;

  $self->query2("INSERT INTO nms_vendors (id, name) VALUES
				('$attr->{ID}', '$attr->{NAME}')
				ON DUPLICATE KEY UPDATE name='$attr->{NAME}'", 'do'
				);

  return $self;
}

#**********************************************************
=head2 vendors_list($attr)

=cut
#**********************************************************
sub vendors_list {
  my $self = shift;
  my ($attr) = @_;

  $SORT      = ($attr->{SORT})      ? $attr->{SORT}      : 1;
  $DESC      = ($attr->{DESC})      ? $attr->{DESC}      : '';
  $PG        = ($attr->{PG})        ? $attr->{PG}        : 0;
  $PAGE_ROWS = ($attr->{PAGE_ROWS}) ? $attr->{PAGE_ROWS} : 25;

  my $WHERE =  $self->search_former($attr, [
      ['ID',   'INT', 'id',   1 ],
			['NAME', 'STR', 'name', 1 ],
    ],
    { WHERE => 1,
    }
  );

  $self->query2("SELECT $self->{SEARCH_FIELDS} id
    FROM nms_vendors
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
=head2 sysobjectid_list($attr)

=cut
#**********************************************************
sub sysobjectid_list {
  my $self = shift;
  my ($attr) = @_;

  $SORT      = ($attr->{SORT})      ? $attr->{SORT}      : 1;
  $DESC      = ($attr->{DESC})      ? $attr->{DESC}      : '';
  my $GROUP  = ($attr->{GROUP})     ? "GROUP BY $attr->{GROUP}" : '';

  my $WHERE =  $self->search_former($attr, [
    ['LABEL',    'STR', 'label',    1 ],
    ['OBJECTID', 'STR', 'objectid', 1 ],
    ],
    { WHERE => 1,
    }
  );

  $self->query2("SELECT $self->{SEARCH_FIELDS} objectid
    FROM nms_sysobjectid
    $WHERE
    $GROUP
    ORDER BY $SORT $DESC;",
    undef,
    $attr
  );

  my $list = $self->{list};
  
  return $self->{list_hash} if ($attr->{LIST2HASH});

  return $list;
}

#**********************************************************
# sysobjectid_add()
#**********************************************************
#sub sysobjectid_add {
#  my $self = shift;
#  my ($attr) = @_;

#  $self->query2("INSERT INTO nms_sysobjectid (sysobjectid, sysorid, sysordescr, module) VALUES
#				('$attr->{SYSOBJECTID}', '$attr->{SYSORID}', '$attr->{SYSORDESCR}', '$attr->{MODULE}')
#				ON DUPLICATE KEY UPDATE module='$attr->{MODULE}', sysordescr='$attr->{SYSORDESCR}'", 'do'
#				);

#  return $self;
#}

sub sysobjectid_add {
  my $self = shift;
  my ($attr) = @_;
  
  $self->query_add('nms_sysobjectid', $attr, { REPLACE => 1 });
  return $self;
}

#**********************************************************
=head2 sysobjectid_list($attr)

=cut
#**********************************************************
sub modules_list {
  my $self = shift;
  my ($attr) = @_;

  $SORT      = ($attr->{SORT})      ? $attr->{SORT}      : 1;
  $DESC      = ($attr->{DESC})      ? $attr->{DESC}      : 'DESC';
  $PG        = ($attr->{PG})        ? $attr->{PG}        : 0;
  $PAGE_ROWS = ($attr->{PAGE_ROWS}) ? $attr->{PAGE_ROWS} : 10000;

  my $WHERE =  $self->search_former($attr, [
    ['MODULE',   'STR', 'module',   1 ],
    ['DESCR',    'STR', 'descr',    1 ],
    ['STATUS',   'INT', 'status',   1 ],
    ['OBJECTID', 'STR', 'objectid', 1 ],
    ['ID',       'INT', 'id',       1 ],
    ],
    { WHERE => 1,
    }
  );

  $self->query2("SELECT $self->{SEARCH_FIELDS} id
    FROM nms_modules
    $WHERE
    ORDER BY $SORT $DESC
    LIMIT $PG, $PAGE_ROWS;",
    undef,
    $attr
  );

  my $list = $self->{list};
  $self->query2("SELECT COUNT(*) AS total
    FROM nms_modules
    $WHERE;",
    undef,
    { INFO => 1 }
  );  
  return $self->{list_hash} if ($attr->{LIST2HASH});

  return $list;
}

#**********************************************************
# oid_row_add()
#**********************************************************
sub module_add {
  my $self = shift;
  my ($attr) = @_;

  $self->query_add('nms_modules', $attr, { REPLACE => 1 });

  return $self;
}

#**********************************************************
=head2 oid_row_del($id)

=cut
#**********************************************************
sub module_del {
  my $self = shift;
  my ($id) = @_;

  $self->query_del('nms_modules', { ID => $id });
 
  return $self;
}



1;
