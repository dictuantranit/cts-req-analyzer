CREATE TABLE IF NOT EXISTS CTS_DataCenter.zzzIssueDI_AssociationByDevice_UM(
		CTSAssDevID		BIGINT	UNSIGNED AUTO_INCREMENT
		, CTSCustID		BIGINT	UNSIGNED
		, DCSDeviceID	BIGINT
		, SubscriberID	INT
		, CreatedTime	TIMESTAMP(4)
		, InsertTime	TIMESTAMP(4)
		, PRIMARY KEY	PK_AssociationByDevice_CTSAssDevID(CTSAssDevID)
        , UNIQUE KEY	IX_AssociationByDevice_CTSCustID_DCSDeviceID(CTSCustID, DCSDeviceID)
        , INDEX			IX_AssociationByDevice_SubscriberID_DeviceID(SubscriberID, DCSDeviceID)
) ENGINE=INNODB AUTO_INCREMENT=1;
    
CREATE TABLE IF NOT EXISTS DCS_DataCenter.zzzIssueDI_Association_UM(
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

CREATE TABLE IF NOT EXISTS DCS_DataCenter.zzzIssueDI_Device_UM(		
        DeviceID				BIGINT	UNSIGNED	AUTO_INCREMENT NOT NULL  
		, FirstDeviceCode		VARCHAR(32)		NOT NULL
        , UserAgentKey			VARCHAR(32)		NULL
        , FirstTransID			BIGINT			NULL
		, CreatedTime			TIMESTAMP(4)	NOT NULL			COMMENT 'CreatedTime of First Transaction'
        , CreatedDate			DATETIME		NOT NULL        	COMMENT 'Date Only, Date of First Transaction'
        , InsertTime			TIMESTAMP(4)	NOT NULL			COMMENT 'DateTime, the time that data Insert to Table'
        
        , PRIMARY KEY	PK_Device_DeviceKey(DeviceID)
        , UNIQUE KEY	UK_Device_FirstDeviceCode(FirstDeviceCode)
        , INDEX			IX_Device_CreatedDate(CreatedDate)        
     ) ENGINE=InnoDB AUTO_INCREMENT = 1;     
	
   	CREATE TABLE IF NOT EXISTS DCS_DataCenter.zzzIssueDI_DeviceCode_UM(
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
 
	CREATE TABLE IF NOT EXISTS DCS_DataCenter.zzzIssueDI_DeviceFingerprint_UM(
		DeviceFingerprintID		BIGINT	UNSIGNED	AUTO_INCREMENT NOT NULL  
        , DeviceID				BIGINT	UNSIGNED	NOT NULL
        , FingerprintCode		VARCHAR(620)		NOT NULL
		, FingerprintMoreInfo	TEXT	CHARACTER SET 'UTF8MB4' COLLATE 'UTF8MB4_UNICODE_CI'	NULL
        , CreatedTime			TIMESTAMP(4)	NOT NULL
        , CreatedDate			DATETIME		NOT NULL
        , InsertTime			TIMESTAMP(4)	NOT NULL
        
        , PRIMARY KEY	PK_DeviceFingerprint_DeviceFingerprintID(DeviceFingerprintID)
        , UNIQUE KEY	UK_DeviceFingerprint(DeviceID,FingerprintCode)
        , INDEX			IX_DeviceFingerprint_CreatedDate(CreatedDate)
     ) ENGINE=InnoDB AUTO_INCREMENT = 1;
     

