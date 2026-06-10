	CREATE  TABLE IF NOT EXISTS DCS_DataCenter.zzzFixIssueDeviceCodeNULL(
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
        , FixedStatus			TINYINT							DEFAULT 0
        , PRIMARY KEY	PK_Transaction_TransID(TransID)
        , INDEX			IX_Transaction_TransID(FixedStatus)
	 ) ENGINE=InnoDB;
     
     