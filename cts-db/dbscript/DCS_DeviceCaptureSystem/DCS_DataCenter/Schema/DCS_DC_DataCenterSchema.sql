/*
Creator: 20190521@Casey.Huynh
Task:    Create Schema FPS4.0 - Data Center
Server:  
DBName:	DCS_DataCenter

Revisions:
		[202002130@Casey.Huynh][130109]: 
			+ DCS: Create Schema table `Transaction07`, ArchiveHistory, ArchiveStatus, ArchiveTrans07_DateTemp, ArchiveTrans07_TransTemp
        [20200723@Casey.Huynh]: 
			+ Add Transaction90
            + Update ArchiveHistory
            + Remove ArchiveTransLog
Reviewer: 
*/

CREATE DATABASE IF NOT EXISTS DCS_DataCenter;
CREATE TABLE IF NOT EXISTS DCS_DataCenter.Device(		
        DeviceID				BIGINT	UNSIGNED	AUTO_INCREMENT NOT NULL  
		, FirstDeviceCode		VARCHAR(32)			NOT NULL
        , UserAgentKey			VARCHAR(32)			NULL
        , FirstTransID			BIGINT				NULL
		, CreatedTime			TIMESTAMP(4)		NOT NULL			COMMENT 'CreatedTime of First Transaction'
        , CreatedDate			DATETIME			NOT NULL        	COMMENT 'Date Only, Date of First Transaction'
        , InsertTime			TIMESTAMP(4)		NOT NULL			COMMENT 'DateTime, the time that data Insert to Table'
        
        , PRIMARY KEY	PK_Device_DeviceKey(DeviceID)
        , UNIQUE KEY	UK_Device_FirstDeviceCode(FirstDeviceCode)
        , INDEX			IX_Device_CreatedDate(CreatedDate)        
     ) ENGINE=InnoDB AUTO_INCREMENT = 1;
# ======Device=============================================
	CREATE TABLE IF NOT EXISTS DCS_DataCenter.DeviceCode(
		DeviceCodeID			BIGINT	UNSIGNED	AUTO_INCREMENT NOT NULL  
		, DeviceCode			VARCHAR(32) 		NOT NULL		COMMENT ' DeviceCode Captured From DI'
        , DeviceID				BIGINT	UNSIGNED	NULL        			
		, FirstTransID			BIGINT				NULL
		, CreatedTime			TIMESTAMP(4)		NOT NULL
        , CreatedDate			DATETIME			NOT NULL
        , InsertTime			TIMESTAMP(4)		NOT NULL
        
        , PRIMARY KEY	PK_DeviceCode_DeviceCodeID(DeviceCodeID)
        , UNIQUE KEY	UK_DeviceCode_DeviceCode(DeviceCode)
        , INDEX			IX_DeviceCode_CreatedDate(CreatedDate)
        , INDEX			IX_DeviceCode_DeviceID(DeviceID)     
        
     ) ENGINE=InnoDB AUTO_INCREMENT = 1;
     
# ======DeviceDetail=============================================
	CREATE TABLE IF NOT EXISTS DCS_DataCenter.DeviceFingerprint(
		DeviceFingerprintID		BIGINT	UNSIGNED	AUTO_INCREMENT NOT NULL  
        , DeviceID				BIGINT	UNSIGNED	NOT NULL
        , FingerprintCode		VARCHAR(620)		NOT NULL
		, FingerprintMoreInfo	TEXT	CHARACTER SET 'UTF8MB4' COLLATE 'UTF8MB4_UNICODE_CI'	NULL
        , CreatedTime			TIMESTAMP(4)	NOT NULL
        , CreatedDate			DATETIME		NOT NULL
        , InsertTime			TIMESTAMP(4)	NOT NULL
        
        , PRIMARY KEY	PK_DeviceFingerprint_DeviceFingerprintID(DeviceFingerprintID)
        , UNIQUE KEY	UK_DeviceFingerprint(DeviceID,FingerprintCode)
     ) ENGINE=InnoDB AUTO_INCREMENT = 1;
    
# =======Association============================================
	CREATE TABLE IF NOT EXISTS DCS_DataCenter.Association(
		AssociationID		BIGINT	UNSIGNED	AUTO_INCREMENT			
		, DeviceID			BIGINT	UNSIGNED	NOT NULL
		, AccountID			BIGINT	UNSIGNED	NOT NULL
		, SubscriberID		INT				NOT NULL
        , CreatedTime		TIMESTAMP(4) 	NOT NULL
        , CreatedDate		TIMESTAMP(4) 	NOT NULL
        , InsertTime		TIMESTAMP(4)	NOT NULL
        , IsCTSTransformed	TINYINT			NOT NULL	DEFAULT 0
        , PRIMARY KEY	PK_Association_AssociationID(AssociationID)        
        , UNIQUE KEY	UK_Association_AccountID_Device(AccountID, DeviceID)
        , INDEX			IX_Association_SubscriberID_AccountID_DeviceID(SubscriberID, AccountID, DeviceID)
        , INDEX			IX_Association_IsCTSTransformed(IsCTSTransformed)
     ) ENGINE=InnoDB AUTO_INCREMENT = 1;

# =======Account============================================
	CREATE TABLE IF NOT EXISTS DCS_DataCenter.Account(
		AccountID			BIGINT		UNSIGNED	AUTO_INCREMENT	NOT NULL        
        , LoginName			VARCHAR(100)			CHARACTER SET 'UTF8MB4' COLLATE 'UTF8MB4_UNICODE_CI'	NOT NULL
        , SubscriberID		INT										NOT NULL
        , SubscriberType	TINYINT									NOT NULL
        , CreatedTime		TIMESTAMP(4)							NOT NULL
        , LastLoginTime		TIMESTAMP(4)							NOT NULL
		, CreatedDate		DATETIME								NOT NULL
        , InsertTime		TIMESTAMP(4)							NOT NULL
        , IsCTSTransformed	TINYINT									NOT NULL DEFAULT 0
        
        , PRIMARY KEY	PK_Account_AccountID(AccountID)
        , UNIQUE KEY	UK_Account_SubscriberIDLoginName(SubscriberID, LoginName)
        , INDEX			IX_Account_IsCTSTransformed(IsCTSTransformed)
     ) ENGINE=InnoDB AUTO_INCREMENT = 1;

# =======Transactions============================================
	CREATE TABLE IF NOT EXISTS DCS_DataCenter.Transaction(
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
        , CreatedDate		DATETIME							NOT NULL		COMMENT 'Date Only'	NOT	NULL
        , InsertTime		TIMESTAMP(4)						NOT NULL
        
        , DeviceCode			VARCHAR(32)						NULL
        , FingerprintCode		VARCHAR(2000)					NULL
        , FingerprintMoreInfo	TEXT	CHARACTER SET 'UTF8MB4' COLLATE 'UTF8MB4_UNICODE_CI'	NULL
        
        , PRIMARY KEY	PK_Transaction_TransID(TransID)
        , INDEX			IX_Transaction_SubscriberIDAccountID(SubscriberID, LoginName, AccountID)
        , INDEX			IX_Transaction_IPID_IP(IPID, IP)
        , INDEX			IX_Transaction_CreatedDate(CreatedDate)
        , INDEX			IX_Transaction_DeviceIDDeviceCode(DeviceID)
	 ) ENGINE=InnoDB;

# ===========================================================================
	CREATE TABLE IF NOT EXISTS DCS_DataCenter.OS(
		OSID			SMALLINT		AUTO_INCREMENT	NOT NULL
		, OSName		VARCHAR(100)					NOT NULL
        , CreatedDate	DATETIME						NOT NULL
        
        , PRIMARY KEY 	PK_OS_ISID(OSID)
        , UNIQUE KEY	UK_OSName(OSName)
     ) ENGINE=InnoDB AUTO_INCREMENT = 1;
     
# ===========================================================================
	CREATE TABLE IF NOT EXISTS DCS_DataCenter.Browser(
		BrowserID			SMALLINT		AUTO_INCREMENT	NOT NULL
		, BrowserName		VARCHAR(100)					NOT NULL
        , CreatedDate		DATETIME						NOT NULL
        
        , PRIMARY KEY 	PK_Browser_BrowserID(BrowserID)
        , UNIQUE KEY	UK_BrowserName(BrowserName)
     ) ENGINE=InnoDB AUTO_INCREMENT = 1;

# ===========================================================================
	CREATE TABLE IF NOT EXISTS DCS_DataCenter.ActionResult(
		ActionResultID			INT				AUTO_INCREMENT
        , Action				VARCHAR(100)	NOT NULL
		, ActionResult			VARCHAR(100)	NOT NULL
        , ActionResultStatus	TINYINT			NOT NULL	COMMENT '0: Inactive; 1: Active; -1: Unhandled(Action has not defined in Intergrated Action List)'
        , CreatedDate			DATETIME		NOT NULL	COMMENT 'Date Only'
        
        , PRIMARY KEY 	PK_ActionResult_ActionResultID(ActionResultID)
        , UNIQUE KEY	UK_ActionResult_ActionResultDetails(Action, ActionResult)
     ) ENGINE=InnoDB AUTO_INCREMENT = 1;

# ===========================================================================	
    CREATE TABLE IF NOT EXISTS DCS_DataCenter.URL(
		URLID				INT			AUTO_INCREMENT
        , SubscriberID		INT				NULL
		, URLDetails		VARCHAR(250)	NULL        
        , CreatedDate		DATETIME		NULL
        
        , PRIMARY KEY 	PK_URL_URLID(URLID)
        , UNIQUE KEY	UK_URL_URLDetails(URLDetails)
     ) ENGINE=InnoDB AUTO_INCREMENT = 1;
     
# =======UserAgent============================================
	CREATE TABLE IF NOT EXISTS DCS_DataCenter.UserAgent(
		UserAgentKey	VARCHAR(32)		NOT NULL
		, UserAgent		TEXT			NOT NULL	
        , BrowserID		SMALLINT		NULL
        , OSID			SMALLINT		NULL
        , OS			VARCHAR(100)	NULL
        , Browser		VARCHAR(100)	NULL
        , CreatedDate	DATETIME		NULL
        
        , PRIMARY KEY 	PK_UserAgent_UserAgentKey(UserAgentKey)
     ) ENGINE=InnoDB;
# ==========TransStatus============================================
CREATE TABLE IF NOT EXISTS DCS_DataCenter.TransStatus(
	 TransStatusName		VARCHAR(100)
     , StatusValue			BIT(16)
     , Notes				VARCHAR(200)
     , IsTransformed		BIT(1)
     , CreatedDate			DATETIME
     , PRIMARY KEY PK_TransStatus(StatusValue)
) ENGINE=InnoDB;

# ==========TransStatus============================================
CREATE TABLE IF NOT EXISTS DCS_DataCenter.TransactionIP(
	 TransID				BIGINT			UNSIGNED	NOT NULL
     , AccountID			INT				UNSIGNED	NOT NULL     
     , LoginName			VARCHAR(100)	CHARACTER SET 'UTF8MB4' COLLATE 'UTF8MB4_UNICODE_CI'	NOT NULL
     , SubscriberID			INT				NOT NULL
     , IP					VARCHAR(50)			NULL
	 , IPID					DECIMAL(50,0)		NULL
     , TransTime			TIMESTAMP(4)	NOT NULL
     , CreatedDate			DATETIME		NOT NULL
     , IsCTSTransformed		TINYINT			NOT NULL	DEFAULT 0
     , PRIMARY KEY	PK_TransactionIP_TransID(TransID)
     , INDEX 		IX_TransactionIP_IsTransformed(IsCTSTransformed)
) ENGINE=InnoDB;
# ===================================================
CREATE TABLE IF NOT EXISTS DCS_DataCenter.zzTracePerformance (
	ID				BIGINT			AUTO_INCREMENT
    , ExecKey		BIGINT			NOT NULL
    , StepID		INT				NOT NULL
    , SPName		VARCHAR(200)	NOT NULL    
    , Notes			VARCHAR(200)	NULL
    , StartTime		TIMESTAMP(4)	NULL
    , EndTime		TIMESTAMP(4)	NULL
    , TotalRecord	INT				NULL
    , FromID		BIGINT			NULL
    , ToID			BIGINT			NULL
    , Duration		BIGINT			NULL
    
	, PRIMARY KEY PK_zzTracePerformance_ID(ID)
	, INDEX 		IX_zzTracePerformance_ExecKey_StepID(ExecKey,StepID)
) ENGINE=InnoDB ;


CREATE TABLE IF NOT EXISTS DCS_DataCenter.TransformTemp_LastLoginTime(
		ID					BIGINT			AUTO_INCREMENT
        , SubscriberID		INT
        , AccountID			BIGINT		UNSIGNED	NOT NULL   
        , LastLoginTime		TIMESTAMP(4)			NOT NULL 
        
        , PRIMARY KEY	PK_TrasformLastLoginTime_ID(ID)
        , INDEX 		IX_TrasformLastLoginTime_AccountID(AccountID)
        
     ) ENGINE=InnoDB, AUTO_INCREMENT = 1;
     
     
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
        
        , PRIMARY KEY	PK_Transaction_TransID(TransID)
        , INDEX			IX_Transaction_SubscriberIDAccountID(SubscriberID, AccountID, CreatedDate)
        , INDEX			IX_Transaction_IPID_IP(IPID, IP)
        , INDEX			IX_Transaction_CreatedDate(CreatedDate)
        , INDEX			IX_Transaction_DeviceID(DeviceID)
	 ) ENGINE=InnoDB;
     
     CREATE TABLE IF NOT EXISTS DCS_DataCenter.Transaction90(
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
        
        , PRIMARY KEY	PK_Transaction_TransID(TransID)
        , INDEX			IX_Transaction_SubscriberIDAccountID(SubscriberID, AccountID, CreatedDate)
        , INDEX			IX_Transaction_IPID_IP(IPID, IP)
        , INDEX			IX_Transaction_CreatedDate(CreatedDate)
        , INDEX			IX_Transaction_DeviceID(DeviceID)
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
        , MovedEndTime			TIMESTAMP(4)
        , EndTime				TIMESTAMP(4)
        , FromTransID			BIGINT UNSIGNED
        , ToTransID				BIGINT UNSIGNED
        , TotalRecord        	INT
		, PRIMARY KEY	PK_ArchiveHistory_ID(ID)
        , UNIQUE KEY 	UX_ArchiveHistory_ArchivedDate(ArchivedDate)
    ) ENGINE=InnoDB;
    
     CREATE TABLE IF NOT EXISTS DCS_DataCenter.ArchiveTransLog(
		ID						INT UNSIGNED AUTO_INCREMENT
        , FromTransId			BIGINT UNSIGNED
        , ToTransId				BIGINT UNSIGNED
        , Moved					BOOLEAN
        , Deleted				BOOLEAN
        , ArchivedDate			DATETIME			
		, PRIMARY KEY	PK_ArchiveTransLog_ID(ID)
        , INDEX 		IX_ArchiveTransLog_ArchivedDate(ArchivedDate)
    ) ENGINE=InnoDB;
    

CREATE TABLE IF NOT EXISTS DCS_RawTransaction.RawTransaction(	
	LoginName					VARCHAR(100) CHARACTER SET 'UTF8MB4' COLLATE 'UTF8MB4_UNICODE_CI' 	NOT NULL	
	, SubscriberName			VARCHAR(50) 						NOT NULL
	, TransTime					TIMESTAMP(4)	 					NOT NULL
	, CreatedDate				DATETIME	 						NOT NULL	COMMENT 'Date Only'
	, DeviceCode				VARCHAR(32) 						NULL		COMMENT 'DI DeviceCode: 32 characters is auto generated'
    , FingerprintCode			VARCHAR(640)						NULL		COMMENT 'Device Fingerprint Codes, the hashcode bases on the set attributes'    
    , FingerprintMoreInfo		VARCHAR(250)						NULL
    , UserAgent					VARCHAR(1000)		 				NULL
	, IP						VARCHAR(50) 						NULL
    , IPID						DECIMAL(50,0)						NULL
    , Flagged					SMALLINT							NULL
	, PluginID					BIGINT 								NULL	
	, URL						VARCHAR(500) 						NULL
    , Action					VARCHAR(100) 						NULL
	, ActionResult				VARCHAR(100) 						NULL
	, InvalidDevice				VARCHAR(1000)	CHARACTER SET 'UTF8MB4' COLLATE 'UTF8MB4_UNICODE_CI'		NULL
    , TransStatus				BIT(16)								NULL	  COMMENT 	'Refer Table TransStatus'
    , FPSTransID				BIGINT  UNSIGNED					NULL
    
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
	, DeviceCode				VARCHAR(32) 						NULL		COMMENT 'DI DeviceCode: 32 characters is auto generated'
    , FingerprintCode			VARCHAR(640)						NULL		COMMENT 'Device Fingerprint Codes, the hashcode bases on the set attributes'    
    , FingerprintMoreInfo		VARCHAR(250)						NULL
    , UserAgent					VARCHAR(1000)						NULL
	, IP						VARCHAR(50) 						NULL
    , IPID						DECIMAL(50,0)						NULL    
	, PluginID					BIGINT(20) 							NULL	
	, URL						VARCHAR(500) 						NULL
    , Action					VARCHAR(100) 						NULL
	, ActionResult				VARCHAR(100) 						NULL
	, InvalidDevice				VARCHAR(1000)	CHARACTER SET 'UTF8MB4' COLLATE 'UTF8MB4_UNICODE_CI'		NULL
    , TransStatus				BIT(16)								NULL	  COMMENT 	'Refer Table TransStatus'
    , FPSTransID				BIGINT  UNSIGNED					NULL
    , Flagged					SMALLINT(6)							NULL
    , IsProcessed				TINYINT								NOT	NULL	DEFAULT '0'
    , TransID					BIGINT	UNSIGNED AUTO_INCREMENT  	NOT NULL    

	, PRIMARY KEY PK_RawTransaction_StaingTransID(TransID)
	, INDEX IX_RawTransaction_IsProcessed(IsProcessed)
    , INDEX IX_RawTransaction_TransTime(CreatedDate)
	, INDEX IX_RawTransaction_SubscriberName_CreatedDate(SubscriberName, CreatedDate)
    
) ENGINE=InnoDB;