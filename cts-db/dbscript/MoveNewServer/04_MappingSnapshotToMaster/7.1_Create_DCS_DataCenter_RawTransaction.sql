-- Step 1: Create DCS_DataCenter.RawTransaction from DCS_RawTransaction.RawTransaction
USE DCS_DataCenter;
CREATE TABLE DCS_DataCenter.RawTransaction LIKE DCS_RawTransaction.RawTransaction;

-- Step 2: Create DCS_DataCenter.ProcessedTransaction from DCS_RawTransaction.ProcessedTransaction
CREATE TABLE DCS_DataCenter.ProcessedTransaction LIKE DCS_RawTransaction.ProcessedTransaction;

-- Step 3: Create partition for DCS_DataCenter.RawTransaction
ALTER  TABLE DCS_DataCenter.RawTransaction  
                PARTITION BY RANGE (yearweek(CreatedDate,0)) (
                PARTITION pw202039 VALUES LESS THAN (202040),
                PARTITION pw202040 VALUES LESS THAN (202041),
                PARTITION pw202041 VALUES LESS THAN (202042),
                PARTITION pw202042 VALUES LESS THAN (202043),
                PARTITION pw202043 VALUES LESS THAN (202044),
                PARTITION pw999999 VALUES LESS THAN MAXVALUE);
                
--Step 4: Set AUTO_INCREMENT for TransID
-- ALTER TABLE DCS_DataCenter.RawTransaction AUTO_INCREMENT={[MaxTransID(RawTransaction)] + 1}, ALGORITHM=INPLACE, LOCK=NONE;  



-- Create RawTransaction, ProcessedTransaction if DCS_RawTransaction isn't exist
/*
 USE DCS_DataCenter; 

CREATE TABLE `RawTransaction` (
  `LoginName` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `SubscriberName` varchar(50) COLLATE utf8_unicode_ci NOT NULL,
  `TransTime` timestamp(4) NOT NULL,
  `CreatedDate` datetime NOT NULL COMMENT 'Date Only',
  `DeviceCode` varchar(62) COLLATE utf8_unicode_ci DEFAULT NULL COMMENT 'DI DeviceCode: 32 characters is auto generated',
  `FingerprintCode` varchar(2000) COLLATE utf8_unicode_ci DEFAULT NULL COMMENT 'Device Fingerprint Codes, the hashcode bases on the set attributes',
  `FingerprintMoreInfo` text CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci,
  `UserAgent` text COLLATE utf8_unicode_ci,
  `IP` varchar(50) COLLATE utf8_unicode_ci DEFAULT NULL,
  `IPID` decimal(50,0) DEFAULT NULL,
  `PluginID` bigint(20) DEFAULT NULL,
  `URL` varchar(500) COLLATE utf8_unicode_ci DEFAULT NULL,
  `Action` varchar(100) COLLATE utf8_unicode_ci DEFAULT NULL,
  `ActionResult` varchar(100) COLLATE utf8_unicode_ci DEFAULT NULL,
  `InvalidDevice` text CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci,
  `TransStatus` bit(16) DEFAULT NULL COMMENT 'Refer Table TransStatus',
  `FPSTransID` bigint(20) unsigned DEFAULT NULL,
  `Flagged` smallint(6) DEFAULT NULL,
  `IsProcessed` tinyint(4) NOT NULL DEFAULT '0',
  `TransID` bigint(20) unsigned NOT NULL AUTO_INCREMENT,
  PRIMARY KEY (`TransID`),
  KEY `IX_RawTransaction_IsProcessed` (`IsProcessed`),
  KEY `IX_RawTransaction_SubscriberName` (`SubscriberName`,`CreatedDate`)
) ENGINE=InnoDB AUTO_INCREMENT=1319676997 DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci       



CREATE TABLE `ProcessedTransaction` (
  `LoginName` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `SubscriberName` varchar(50) CHARACTER SET utf8 COLLATE utf8_unicode_ci NOT NULL,
  `TransTime` timestamp(4) NOT NULL,
  `CreatedDate` datetime NOT NULL COMMENT 'Date Only',
  `DeviceCode` varchar(62) CHARACTER SET utf8 COLLATE utf8_unicode_ci DEFAULT NULL COMMENT 'DI DeviceCode: 32 characters is auto generated',
  `FingerprintCode` varchar(2000) CHARACTER SET utf8 COLLATE utf8_unicode_ci DEFAULT NULL COMMENT 'Device Fingerprint Codes, the hashcode bases on the set attributes',
  `FingerprintMoreInfo` text CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci,
  `UserAgent` text CHARACTER SET utf8 COLLATE utf8_unicode_ci,
  `IP` varchar(50) CHARACTER SET utf8 COLLATE utf8_unicode_ci DEFAULT NULL,
  `IPID` decimal(50,0) DEFAULT NULL,
  `PluginID` bigint(20) DEFAULT NULL,
  `URL` varchar(500) CHARACTER SET utf8 COLLATE utf8_unicode_ci DEFAULT NULL,
  `Action` varchar(100) CHARACTER SET utf8 COLLATE utf8_unicode_ci DEFAULT NULL,
  `ActionResult` varchar(100) CHARACTER SET utf8 COLLATE utf8_unicode_ci DEFAULT NULL,
  `InvalidDevice` text CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci,
  `TransStatus` bit(16) DEFAULT NULL COMMENT 'Refer Table TransStatus',
  `FPSTransID` bigint(20) unsigned DEFAULT NULL,
  `Flagged` smallint(6) DEFAULT NULL,
  `IsProcessed` tinyint(4) NOT NULL DEFAULT '0',
  `TransID` bigint(20) unsigned NOT NULL AUTO_INCREMENT,
  PRIMARY KEY (`TransID`,`CreatedDate`),
  KEY `IX_RawTransaction_IsProcessed` (`IsProcessed`),
  KEY `IX_RawTransaction_TransTime` (`CreatedDate`),
  KEY `IX_RawTransaction_SubscriberName_CreatedDate` (`SubscriberName`,`CreatedDate`)
) ENGINE=InnoDB AUTO_INCREMENT=1319677564 DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci
/*!50100 PARTITION BY RANGE (yearweek(`CreatedDate`,0))
(PARTITION pw202000 VALUES LESS THAN (202038) ENGINE = InnoDB,
 PARTITION pw202038 VALUES LESS THAN (202039) ENGINE = InnoDB,
 PARTITION pw202039 VALUES LESS THAN (202040) ENGINE = InnoDB,
 PARTITION pw202040 VALUES LESS THAN (202041) ENGINE = InnoDB,
 PARTITION pw202041 VALUES LESS THAN (202042) ENGINE = InnoDB,
 PARTITION pw202042 VALUES LESS THAN (202043) ENGINE = InnoDB,
 PARTITION pw999999 VALUES LESS THAN MAXVALUE ENGINE = InnoDB) */

*/
