CREATE TABLE `nms_obj` (
  `id` smallint(6) unsigned NOT NULL AUTO_INCREMENT,
  `ip` int(11) unsigned NOT NULL DEFAULT '0',
  `sys_oid` varchar(50) DEFAULT NULL,
  `ro_community` blob,
  `rw_community` blob,
  PRIMARY KEY (`id`),
  UNIQUE KEY `ip_sys` (`ip`,`sys_oid`)
) COMMENT='Equipment objects';

CREATE TABLE `nms_obj_values` (
  `obj_id` smallint(6) DEFAULT NULL,
  `obj_ind` smallint(5) unsigned NOT NULL DEFAULT '0',
  `oid_id` smallint(5) unsigned NOT NULL,
  `value` varchar(255) DEFAULT NULL,
  UNIQUE KEY `obj_o_in` (`obj_id`,`oid_id`,`obj_ind`)
) COMMENT='Equipment objects values';

CREATE TABLE `nms_oids` (
  `id` smallint(4) unsigned NOT NULL AUTO_INCREMENT,
  `section` varchar(20) NOT NULL DEFAULT '',
  `label` varchar(50) NOT NULL DEFAULT '',
  `objectID` varchar(50) NOT NULL DEFAULT '',
  `iid` smallint(5) unsigned DEFAULT NULL,
  `type` varchar(10) NOT NULL DEFAULT '',
  `access` tinyint(1) unsigned DEFAULT NULL,
  PRIMARY KEY (`id`)
) COMMENT='Equipment OIDS table';

CREATE TABLE `nms_oids_rows` (
  `oid_id` smallint(4) unsigned NOT NULL,
  `label` varchar(50) NOT NULL DEFAULT '',
  `objectID` varchar(50) NOT NULL DEFAULT '',
  `iid` smallint(5) unsigned DEFAULT NULL,
  `type` varchar(10) NOT NULL DEFAULT '',
  `access` tinyint(1) unsigned DEFAULT NULL,
  KEY `oid_id` (`oid_id`)
) COMMENT='Equipment OIDS table rows';

CREATE TABLE `nms_vendors` (
  `id` smallint(6) unsigned NOT NULL,
  `name` varchar(200) NOT NULL DEFAULT '',
  PRIMARY KEY (`id`)
) COMMENT='NMS vendors list';

