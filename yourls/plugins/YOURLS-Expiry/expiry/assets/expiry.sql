CREATE TABLE IF NOT EXISTS `expiry` (
  `keyword` varchar(200) NOT NULL,
  `type` varchar(5) NOT NULL,
  `click` varchar(5),
  `timestamp` varchar(20),
  `shelflife` varchar(20),
  `postexpire` varchar(200),
  PRIMARY KEY  (`keyword`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;
