
CREATE TABLE `nms_obj` (
  `id` smallint(6) unsigned NOT NULL AUTO_INCREMENT,
  `ip` int(11) unsigned NOT NULL DEFAULT '0',
  `sysobjectid` varchar(50) DEFAULT NULL,
  `sysname` varchar(50) DEFAULT NULL,
  `syslocation` varchar(100) DEFAULT NULL,
  `status` smallint(3) NOT NULL DEFAULT '0',
  `ro_community` blob,
  `rw_community` blob,
  PRIMARY KEY (`id`),
  UNIQUE KEY `ip_sys` (`ip`,`sysobjectid`)
) COMMENT='Equipment objects';



CREATE TABLE `nms_oids` (
  `id` smallint(4) unsigned NOT NULL AUTO_INCREMENT,
  `section` varchar(50) NOT NULL DEFAULT '',
  `label` varchar(50) NOT NULL DEFAULT '',
  `objectid` varchar(50) NOT NULL DEFAULT '',
  `iid` smallint(5) unsigned DEFAULT NULL,
  `type` varchar(50) DEFAULT NULL,
  `access` tinyint(1) unsigned DEFAULT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `lab_i_obj` (`label`,`iid`,`objectid`),
  KEY `objectid` (`objectid`),
  CONSTRAINT `nms_oids_ibfk_1` FOREIGN KEY (`objectid`) REFERENCES `nms_sysobjectid` (`objectid`) ON DELETE CASCADE
) COMMENT='Equipment OIDS table';



CREATE TABLE `nms_oids_rows` (
  `id` smallint(4) unsigned NOT NULL,
  `label` varchar(50) NOT NULL DEFAULT '',
  `objectID` varchar(50) NOT NULL DEFAULT '',
  `iid` smallint(5) unsigned DEFAULT NULL,
  `type` varchar(10) NOT NULL DEFAULT '',
  `access` tinyint(1) unsigned DEFAULT NULL,
  UNIQUE KEY `id_lab` (`id`,`label`),
  KEY `id` (`id`),
  CONSTRAINT `nms_oids_rows_ibfk_1` FOREIGN KEY (`id`) REFERENCES `nms_oids` (`id`) ON DELETE CASCADE
) COMMENT='Equipment OIDS table rows';



CREATE TABLE `nms_sysobjectid` (
  `objectid` varchar(50) NOT NULL,
  `label` varchar(50) DEFAULT NULL,
  PRIMARY KEY (`objectid`),
  UNIQUE KEY `obj_label` (`objectid`,`label`)
) COMMENT='Nms sysobjects table';



CREATE TABLE `nms_trap_values` (
  `id` int(11) unsigned NOT NULL,
  `label` varchar(50) NOT NULL DEFAULT '',
  `value` varbinary(100) NOT NULL DEFAULT '',
  KEY `id` (`id`),
  CONSTRAINT `nms_trap_values_ibfk_1` FOREIGN KEY (`id`) REFERENCES `nms_traps` (`id`) ON DELETE CASCADE
) COMMENT='Nms trap values';



CREATE TABLE `nms_traps` (
  `id` int(11) unsigned NOT NULL AUTO_INCREMENT,
  `traptime` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `ip` int(11) unsigned NOT NULL DEFAULT '0',
  `oid` varchar(50) NOT NULL DEFAULT '',
  `label` varchar(50) NOT NULL DEFAULT '',
  `timeticks` int(11) NOT NULL DEFAULT '0',
  PRIMARY KEY (`id`)
) COMMENT='Nms traps';



CREATE TABLE `nms_vendors` (
  `id` smallint(6) unsigned NOT NULL,
  `name` varchar(200) NOT NULL DEFAULT '',
  PRIMARY KEY (`id`)
) COMMENT='NMS vendors list';


