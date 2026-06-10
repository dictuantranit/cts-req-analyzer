/*
Creator: 2019/12/09@CaseyHuynh
Task:		DCS_RawTransaction Schema
Server:		Slave
DBName:		DCS_RawTransaction

Revisions: 
Reviewer: 
*/

CREATE DATABASE IF NOT EXISTS DCS_RawTransaction;

CREATE TABLE IF NOT EXISTS DCS_RawTransaction.RawTransaction(	
	LoginName					VARCHAR(100) CHARACTER SET 'UTF8MB4' COLLATE 'UTF8MB4_UNICODE_CI' 	NOT NULL	
	, SubscriberName			VARCHAR(50) 						NOT NULL
	, TransTime					TIMESTAMP(4)	 					NOT NULL
	, CreatedDate				DATETIME	 						NOT NULL	COMMENT 'Date Only'
	, DeviceCode				VARCHAR(62) 						NULL		COMMENT 'DI DeviceCode: 32 characters is auto generated'
    , FingerprintCode			VARCHAR(2000)						NULL		COMMENT 'Device Fingerprint Codes, the hashcode bases on the set attributes'    
    , FingerprintMoreInfo		TEXT	CHARACTER SET 'UTF8MB4' COLLATE 'UTF8MB4_UNICODE_CI'		NULL
    , UserAgent					TEXT		 						NULL
	, IP						VARCHAR(50) 						NULL
    , IPID						DECIMAL(50,0)						NULL
    , Flagged					SMALLINT							NULL
	, PluginID					BIGINT 								NULL	
	, URL						VARCHAR(500) 						NULL
    , Action					VARCHAR(100) 						NULL
	, ActionResult				VARCHAR(100) 						NULL
	, InvalidDevice				TEXT	CHARACTER SET 'UTF8MB4' COLLATE 'UTF8MB4_UNICODE_CI'		NULL
    , TransStatus				BIT(16)								NULL	  COMMENT 	'Refer Table TransStatus'
    , FPSTransID				BIGINT  UNSIGNED
    
    , IsProcessed				TINYINT								NOT	NULL	DEFAULT '0'
    , TransID					BIGINT	UNSIGNED AUTO_INCREMENT  	NOT NULL    

	, PRIMARY KEY PK_RawTransaction_StaingTransID(TransID)
	, INDEX IX_RawTransaction_IsProcessed(IsProcessed)
	, INDEX IX_RawTransaction_SubscriberName(SubscriberName, CreatedDate)
    
) ENGINE=InnoDB;


CREATE TABLE IF NOT EXISTS DCS_RawTransaction.ProcessedTransaction(	
	LoginName					VARCHAR(100) CHARACTER SET 'UTF8MB4' COLLATE 'UTF8MB4_UNICODE_CI' 	NOT NULL	
	, SubscriberName			VARCHAR(50) 						NOT NULL
	, TransTime					TIMESTAMP(4)	 					NOT NULL
	, CreatedDate				DATETIME	 						NOT NULL	COMMENT 'Date Only'
	, DeviceCode				VARCHAR(62) 						NULL		COMMENT 'DI DeviceCode: 32 characters is auto generated'
    , FingerprintCode			VARCHAR(2000)						NULL		COMMENT 'Device Fingerprint Codes, the hashcode bases on the set attributes'    
    , FingerprintMoreInfo		TEXT	CHARACTER SET 'UTF8MB4' COLLATE 'UTF8MB4_UNICODE_CI'		NULL
    , UserAgent					TEXT		 						NULL
	, IP						VARCHAR(50) 						NULL
    , IPID						DECIMAL(50,0)						NULL    
	, PluginID					BIGINT(20) 							NULL	
	, URL						VARCHAR(500) 						NULL
    , Action					VARCHAR(100) 						NULL
	, ActionResult				VARCHAR(100) 						NULL
	, InvalidDevice				TEXT	CHARACTER SET 'UTF8MB4' COLLATE 'UTF8MB4_UNICODE_CI'		NULL
    , TransStatus				BIT(16)								NULL	  COMMENT 	'Refer Table TransStatus'
    , FPSTransID				BIGINT  UNSIGNED
    , Flagged					SMALLINT(6)							NULL
    , IsProcessed				TINYINT								NOT	NULL	DEFAULT '0'
    , TransID					BIGINT	UNSIGNED AUTO_INCREMENT  	NOT NULL    

	, PRIMARY KEY PK_RawTransaction_StaingTransID(TransID)
	, INDEX IX_RawTransaction_IsProcessed(IsProcessed)
    , INDEX IX_RawTransaction_TransTime(CreatedDate)
	, INDEX IX_RawTransaction_SubscriberName_CreatedDate(SubscriberName, CreatedDate)
    
) ENGINE=InnoDB;
