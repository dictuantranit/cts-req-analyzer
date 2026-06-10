/*
Creator: 20191217@CaseyHuynh
Task:	 	DCS_Schema
Server:  	Slave
DBName:		DCS_DataCenter

Revisions: 
	#1. [20191217@CaseyHuynh][#125530]: Add Column LastLoginTime column to table CTSCustomer.
    
Reviewer:
	#1. Harvey: 
*/
CREATE TABLE IF NOT EXISTS DCS_DataCenter.Transaction07(
		TransID				BIGINT	UNSIGNED					NOT NULL
		, LoginName			VARCHAR(100) 		CHARACTER SET 'UTF8MB4' COLLATE 'UTF8MB4_UNICODE_CI'		NOT NULL
        , TransTime			TIMESTAMP(4)						NOT	NULL                
        , SubscriberID		INT									NULL
        , AccountID			BIGINT			UNSIGNED			NULL
        , URLID				BIGINT			UNSIGNED			NULL
		, DeviceCodeID		BIGINT			UNSIGNED			NULL
		, DeviceID			BIGINT			UNSIGNED			NULL
        , FirstDeviceCode	VARCHAR(64)							NULL
        , DeviceStatus		TINYINT								NULL
        , DeviceFingerprintID	BIGINT			UNSIGNED		NULL
        , UserAgentKey		VARCHAR(32)							NULL
        , IP				VARCHAR(50)							NULL
        , IPID				DECIMAL(50,0)						NULL
        , ActionResultID 	BIGINT								NULL
		, Flagged			SMALLINT							NULL		COMMENT 'captcha & browserless'		
        , PluginID			BIGINT 								NULL
        , TransStatus		BIT(16)								NULL
        , CreatedDate		DATETIME							NOT NULL	COMMENT 'Date Only'	NOT	NULL
        , InsertTime		TIMESTAMP(4)						NOT NULL
        
        , DeviceCode			VARCHAR(32)						NULL
        , FingerprintCode		VARCHAR(2000)					NULL
        , FingerprintMoreInfo	TEXT	CHARACTER SET 'UTF8MB4' COLLATE 'UTF8MB4_UNICODE_CI'	NULL
        
        , PRIMARY KEY	PK_Transaction_TransID(TransID)
        , INDEX			IX_Transaction_SubscriberIDAccountID(SubscriberID, AccountID, CreatedDate)
        , INDEX			IX_Transaction_IPID_IP(IPID, IP)
        , INDEX			IX_Transaction_CreatedDate(CreatedDate)
        , INDEX			IX_Transaction_DeviceIDDeviceCode(DeviceID, DeviceCode)
	 ) ENGINE=InnoDB;
     
	CREATE TABLE IF NOT EXISTS DCS_DataCenter.ArchiveStatus(
		ArchiveID				INT
		, ArchiveName			VARCHAR(100)	
		, LastArchivedDate		DATETIME
        , UpdateTime			DATETIME				
    ) ENGINE=InnoDB;

    CREATE TABLE IF NOT EXISTS DCS_DataCenter.ArchiveHistory(
		ID						INT UNSIGNED AUTO_INCREMENT
        , ArchiveID				INT
        , ArchivedDate			DATETIME				# Date is moved data
        , Status				TINYINT
        , ScheduleTime			DATETIME				# Schedule Time  run
        , StartTime				TIMESTAMP(4)
        , EndTime				TIMESTAMP(4)
        
		, PRIMARY KEY	PK_ArchiveHistory_ID(ID)
    ) ENGINE=InnoDB;
    
    CREATE TABLE IF NOT EXISTS DCS_DataCenter.Temp_ArchiveTrans07Date(
        ArchivedDate			DATETIME				# Date is moved data    
        , ScheduleTime			DATETIME
		, PRIMARY KEY	PK_Temp_ArchiveTrans07Date_(ArchivedDate)
    ) ENGINE=InnoDB;