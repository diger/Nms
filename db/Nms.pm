package Nms;

=head1 NAME

  Equipment managment system

=cut

=head2 VERSION

   VERSION = 1.0

=cut

use strict;
use parent 'main';
our $VERSION = 1.0;
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
  
  $CONF->{NMS_NET} = '10.0.0.0/24';
  $CONF->{NMS_COMMUNITY_RO} = 'public';
  $CONF->{NMS_COMMUNITY_RW} = 'private';
  $CONF->{NMS_MAC_NOTIF} = 0;
  $CONF->{NMS_STATS_CLEAN_PERIOD} = 60;
  $CONF->{NMS_REDIS_SERV} = '10.0.0.1:6379';

  my $new_cfg = $self->query2("SELECT param, value
    FROM nms_config;",
    undef
  );
  foreach my $util (@{$new_cfg->{list}}) {
    $CONF->{$util->[0]} = $util->[1]
  }

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
# obj__add()
#**********************************************************
sub obj_add {
  my $self = shift;
  my ($attr) = @_;
  my $SECRETKEY = $CONF->{secretkey} || '';
  if($attr->{RO_COMMUNITY}) {
    $attr->{RO_COMMUNITY} = "ENCODE('$attr->{RO_COMMUNITY}', $SECRETKEY)"
  }
  if($attr->{RW_COMMUNITY}) {
    $attr->{RW_COMMUNITY} = "ENCODE('$attr->{RW_COMMUNITY}', $SECRETKEY)"
  }

  my $UPD =  $self->search_former($attr,
    [
    ['IP',           'STR', 'ip',                      1 ],
    ['SYS_NAME',     'STR', 'sysname',                 1 ],
    ['SYS_LOCATION', 'STR', 'syslocation',             1 ],
    ['SYS_OBJECTID', 'STR', 'sysobjectid',             1 ],
    ['STATUS',       'INT', 'status',                  1 ],
    ['ID',           'INT', 'id',                      1 ],
    ['RO_COMMUNITY', 'STR', 'ro_community',            1 ],
    ['RW_COMMUNITY', 'STR', 'rw_community',            1 ],
    ]
  );
  $UPD =~ s/AND/,/g;
  $UPD =~ s/\(|\)//g;
  $self->{SEARCH_FIELDS} =~ s/,\s$//;
  my $VALUES = join(',', @{$self->{SEARCH_VALUES}});
  $self->query2("INSERT INTO nms_obj ( $self->{SEARCH_FIELDS} ) VALUES
    ( $VALUES )
    ON DUPLICATE KEY UPDATE $UPD;", 'do'
  );
     
  return $self;
}

#**********************************************************
=head2 oid_del($id)

=cut
#**********************************************************
sub obj_del {
  my $self = shift;
  my ($id) = @_;

  $self->query_del('nms_obj', { ID => $id });

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
    ['VALUE',    'INT', 'value',    1 ],
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
sub sysobjectid_add {
  my $self = shift;
  my ($attr) = @_;

  $self->query2("INSERT INTO nms_sysobjectid (objectid, label) VALUES
				('$attr->{OBJECTID}', '$attr->{LABEL}')
				ON DUPLICATE KEY UPDATE label='$attr->{LABEL}'", 'do'
				);

  return $self;
}
#**********************************************************
=head2 sysobjectid_list($attr)

=cut
#**********************************************************
sub modules_list
 {
  my $self = shift;
  my ($attr) = @_;

  $SORT      = ($attr->{SORT})      ? $attr->{SORT}      : 1;
  $DESC      = ($attr->{DESC})      ? $attr->{DESC}      : 'DESC';
  $PG        = ($attr->{PG})        ? $attr->{PG}        : 0;
  $PAGE_ROWS = ($attr->{PAGE_ROWS}) ? $attr->{PAGE_ROWS} : 10000;

  my $WHERE =  $self->search_former($attr, [
    ['MODULE',   'STR', 'module',   1 ],
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

#**********************************************************
=head2 triggers_list($attr)

=cut
#**********************************************************
sub triggers_list {
  my $self = shift;
  my ($attr) = @_;

  $SORT      = ($attr->{SORT})      ? $attr->{SORT}      : 1;
  $DESC      = ($attr->{DESC})      ? $attr->{DESC}      : 'DESC';
  $PG        = ($attr->{PG})        ? $attr->{PG}        : 0;
  $PAGE_ROWS = ($attr->{PAGE_ROWS}) ? $attr->{PAGE_ROWS} : 10000;

  my $WHERE =  $self->search_former($attr, [
    ['OBJ_ID',   'INT', 'obj_id',   1 ],
    ['LABEL',    'STR', 'label',    1 ],
    ['IID',      'INT', 'iid',      1 ],
    ['TYPE',     'STR', 'objectid', 1 ],
    ['MONIT',    'INT', 'monit',    1 ],
    ['SYS_NAME', 'STR', 'sysname',  1 ],
    ],
    { WHERE => 1,
    }
  );

  $self->query2("SELECT $self->{SEARCH_FIELDS} tr.id AS id
    FROM nms_obj_triggers tr
    LEFT JOIN nms_obj n ON (n.id=obj_id)
    $WHERE
    ORDER BY $SORT $DESC
    LIMIT $PG, $PAGE_ROWS;",
    undef,
    $attr
  );

  my $list = $self->{list};
  $self->query2("SELECT COUNT(*) AS total
    FROM nms_obj_triggers
    $WHERE;",
    undef,
    { INFO => 1 }
  );  
  return $self->{list_hash} if ($attr->{LIST2HASH});

  return $list;
}

#**********************************************************
# triggers_add()
#**********************************************************
sub trigger_add {
  my $self = shift;
  my ($attr) = @_;

  $self->query_add('nms_obj_triggers', $attr, { REPLACE => 1 });

  return $self;
}

#**********************************************************
=head2 triggers($id)

=cut
#**********************************************************
sub trigger_del {
  my $self = shift;
  my ($id) = @_;

  $self->query_del('nms_obj_triggers', { ID => $id });
 
  return $self;
}

#**********************************************************
=head2 config_list($attr)

=cut
#**********************************************************
sub config_list {
  my $self = shift;
  my ($attr) = @_;

  $SORT      = ($attr->{SORT})      ? $attr->{SORT}      : 1;
  $DESC      = ($attr->{DESC})      ? $attr->{DESC}      : '';
  $PG        = ($attr->{PG})        ? $attr->{PG}        : 0;
  $PAGE_ROWS = ($attr->{PAGE_ROWS}) ? $attr->{PAGE_ROWS} : 25;

  my $WHERE =  $self->search_former($attr, [
      ['ID',    'INT', 'id',    1 ],
			['PARAM', 'STR', 'param', 1 ],
      ['VALUE', 'STR', 'value', 1 ],
    ],
    { WHERE => 1,
    }
  );

  $self->query2("SELECT $self->{SEARCH_FIELDS} id
    FROM nms_config
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
# config_add()
#**********************************************************
sub config_add {
  my $self = shift;
  my ($attr) = @_;

  $self->query_add('nms_config', $attr, { REPLACE => 1 });

  return $self;
}

#**********************************************************
=head2 config_del($id)

=cut
#**********************************************************
sub config_del {
  my $self = shift;
  my ($id) = @_;

  $self->query_del('nms_config', { ID => $id });
 
  return $self;
}

1;
