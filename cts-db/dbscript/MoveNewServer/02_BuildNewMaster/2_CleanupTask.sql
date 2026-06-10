use DCS_DataCenter;
-- reset Transaction07
drop table Transaction07;
CREATE TABLE `Transaction07` (
  `TransID` bigint(20) unsigned NOT NULL AUTO_INCREMENT,
  `LoginName` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `TransTime` timestamp(4) NOT NULL,
  `SubscriberID` int(11) DEFAULT NULL,
  `AccountID` bigint(20) unsigned DEFAULT NULL,
  `URLID` bigint(20) unsigned DEFAULT NULL,
  `DeviceCodeID` bigint(20) unsigned DEFAULT NULL,
  `DeviceID` bigint(20) unsigned DEFAULT NULL,
  `FirstDeviceCode` varchar(64) CHARACTER SET utf8 COLLATE utf8_unicode_ci DEFAULT NULL,
  `DeviceStatus` tinyint(4) DEFAULT NULL,
  `DeviceFingerprintID` bigint(20) unsigned DEFAULT NULL,
  `UserAgentKey` varchar(32) CHARACTER SET utf8 COLLATE utf8_unicode_ci DEFAULT NULL,
  `IP` varchar(50) CHARACTER SET utf8 COLLATE utf8_unicode_ci DEFAULT NULL,
  `IPID` decimal(50,0) DEFAULT NULL,
  `ActionResultID` bigint(20) DEFAULT NULL,
  `Flagged` smallint(6) DEFAULT NULL COMMENT 'captcha & browserless',
  `PluginID` bigint(20) DEFAULT NULL,
  `TransStatus` bit(16) DEFAULT NULL,
  `CreatedDate` datetime NOT NULL COMMENT 'Date Only',
  `InsertTime` timestamp(4) NOT NULL,
  `RawTransID` bigint(20) unsigned DEFAULT NULL,
  PRIMARY KEY (`TransID`,`CreatedDate`),
  UNIQUE KEY `UN_RawTransID` (`CreatedDate`,`RawTransID`),
  KEY `IX_Transaction_SubscriberIDAccountID` (`SubscriberID`,`AccountID`,`CreatedDate`),
  KEY `IX_Transaction_IPID_IP` (`IPID`,`IP`),
  KEY `IX_Transaction_CreatedDate` (`CreatedDate`),
  KEY `IX_Transaction_DeviceID` (`DeviceID`)
) ENGINE=InnoDB AUTO_INCREMENT=1399747709 DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci
PARTITION BY RANGE (yearweek(`CreatedDate`,0))
(PARTITION pw202000 VALUES LESS THAN (202042) ENGINE = InnoDB,
 PARTITION pw202042 VALUES LESS THAN (202043) ENGINE = InnoDB,
 PARTITION pw202043 VALUES LESS THAN (202044) ENGINE = InnoDB,
 PARTITION pw202044 VALUES LESS THAN (202045) ENGINE = InnoDB,
 PARTITION pw202045 VALUES LESS THAN (202046) ENGINE = InnoDB,
 PARTITION pw202046 VALUES LESS THAN (202047) ENGINE = InnoDB,
 PARTITION pw999999 VALUES LESS THAN MAXVALUE ENGINE = InnoDB);

 -- reset Transaction
drop table `Transaction`;
CREATE TABLE `Transaction` (
  `TransID` bigint(20) unsigned NOT NULL AUTO_INCREMENT,
  `LoginName` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `TransTime` timestamp(4) NOT NULL,
  `SubscriberID` int(11) DEFAULT NULL,
  `AccountID` bigint(20) unsigned DEFAULT NULL,
  `URLID` bigint(20) unsigned DEFAULT NULL,
  `DeviceCodeID` bigint(20) unsigned DEFAULT NULL,
  `DeviceID` bigint(20) unsigned DEFAULT NULL,
  `FirstDeviceCode` varchar(64) CHARACTER SET utf8 COLLATE utf8_unicode_ci DEFAULT NULL,
  `DeviceStatus` tinyint(4) DEFAULT NULL,
  `DeviceFingerprintID` bigint(20) unsigned DEFAULT NULL,
  `UserAgentKey` varchar(32) CHARACTER SET utf8 COLLATE utf8_unicode_ci DEFAULT NULL,
  `IP` varchar(50) CHARACTER SET utf8 COLLATE utf8_unicode_ci DEFAULT NULL,
  `IPID` decimal(50,0) DEFAULT NULL,
  `ActionResultID` bigint(20) DEFAULT NULL,
  `Flagged` smallint(6) DEFAULT NULL COMMENT 'captcha & browserless',
  `PluginID` bigint(20) DEFAULT NULL,
  `TransStatus` bit(16) DEFAULT NULL,
  `CreatedDate` datetime NOT NULL COMMENT 'Date Only',
  `InsertTime` timestamp(4) NOT NULL,
  `DeviceCode` varchar(32) CHARACTER SET utf8 COLLATE utf8_unicode_ci DEFAULT NULL,
  `FingerprintCode` varchar(620) CHARACTER SET utf8 COLLATE utf8_unicode_ci DEFAULT NULL,
  `FingerprintMoreInfo` varchar(250) CHARACTER SET utf8 COLLATE utf8_unicode_ci DEFAULT NULL,
  `RawTransID` bigint(20) unsigned NOT NULL,
  PRIMARY KEY (`TransID`),
  UNIQUE KEY `UN_RawTransID` (`RawTransID`),
  KEY `IX_Transaction_SubscriberIDAccountID` (`SubscriberID`,`LoginName`,`AccountID`),
  KEY `IX_Transaction_IPID_IP` (`IPID`,`IP`),
  KEY `IX_Transaction_CreatedDate` (`CreatedDate`),
  KEY `IX_Transaction_DeviceIDDeviceCode` (`DeviceID`)
) ENGINE=InnoDB AUTO_INCREMENT=1409370813 DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci;

-- reset DCS_RawTransaction
use DCS_RawTransaction;

create table ProcessedTransaction_New like ProcessedTransaction;
create table ProcessedTransaction_New like RawTransaction;

drop table ProcessedTransaction;
drop table RawTransaction;
drop table TEMP_MaxTrans; 
drop table ArchiveTransactionLog;

rename table ProcessedTransaction_New to ProcessedTransaction;
rename table RawTransaction_New to RawTransaction;

-- reset DCS_DataArchive
drop schema DCS_DataArchive;

-- reset MonDB
use MonDB;
drop table CS01_Temp_Association;
drop table CS01_Temp_AssociationCS01_JSON;
drop table CS01_Temp_AssociationCS01_Temp_Association;
drop table CS01_Temp_AssociationCS01_Temp_AssociationV1;
drop table CS01_Temp_AssociationCS_DataMonitor;
drop table CS01_Temp_AssociationCS_DataMonitorSubscriberTrans;