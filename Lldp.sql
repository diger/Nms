CREATE TABLE `nms_obj_lldp` (
  `id` mediumint(8) unsigned NOT NULL AUTO_INCREMENT,
  `obj_id` smallint(5) unsigned NOT NULL,
  `neighbor_id` smallint(5) unsigned NOT NULL,
  `loc_port` smallint(5) unsigned DEFAULT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `obj_port` (`obj_id`,`loc_port`),
  KEY `obj_id` (`obj_id`),
  FOREIGN KEY (`obj_id`) REFERENCES `nms_obj` (`id`) ON DELETE CASCADE
) COMMENT='Nms lldp neighbors table'
