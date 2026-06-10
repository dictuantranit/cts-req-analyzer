	CREATE TABLE IF NOT EXISTS CTS_Adhoc.csCTMax_Account_bk(
		AccountID			BIGINT		UNSIGNED	AUTO_INCREMENT	NOT NULL        
        , LoginName			VARCHAR(100)			CHARACTER SET 'UTF8MB4' COLLATE 'UTF8MB4_UNICODE_CI'	NOT NULL
        , SubscriberID		INT										NOT NULL
        , SubscriberType	TINYINT									NOT NULL
        , CreatedTime		TIMESTAMP(4)							NOT NULL
        , LastLoginTime		TIMESTAMP(4)							NOT NULL
		, CreatedDate		DATETIME								NOT NULL
        , InsertTime		TIMESTAMP(4)							NOT NULL
        , IsCTSTransformed	TINYINT									NOT NULL DEFAULT 0
        , IssueType			TINYINT
        , PRIMARY KEY	PK_Account_AccountID(AccountID)
        , UNIQUE KEY	UK_Account_SubscriberIDLoginName(SubscriberID, LoginName)
        , INDEX			IX_Account_IsCTSTransformed(IsCTSTransformed)
        , INDEX			IX_Account_IssueType(IssueType)
     ) ENGINE=InnoDB AUTO_INCREMENT = 1;

CREATE TABLE IF NOT EXISTS CTS_Adhoc.csCTMax_Association_bk(
		AssociationID		BIGINT	UNSIGNED	AUTO_INCREMENT			
		, DeviceID			BIGINT	UNSIGNED	NOT NULL
		, AccountID			BIGINT	UNSIGNED	NOT NULL
		, SubscriberID		INT				NOT NULL
        , CreatedTime		TIMESTAMP(4) 	NOT NULL
        , CreatedDate		TIMESTAMP(4) 	NOT NULL
        , InsertTime		TIMESTAMP(4)	NOT NULL
        , IsCTSTransformed	TINYINT			NOT NULL	DEFAULT 0
        , IssueType			TINYINT
        , PRIMARY KEY	PK_Association_AssociationID(AssociationID)        
        , UNIQUE KEY	UK_Association_AccountID_Device(AccountID, DeviceID)
        , INDEX			IX_Association_SubscriberID_AccountID_DeviceID(SubscriberID, AccountID, DeviceID)
        , INDEX			IX_Association_IsCTSTransformed(IsCTSTransformed)
        , INDEX			IX_Association_IssueType(IssueType)
     ) ENGINE=InnoDB AUTO_INCREMENT = 1;


CREATE TABLE IF NOT EXISTS CTS_Adhoc.csCTMax_CustDCSAccount_bk(
		CTSCustID			BIGINT	UNSIGNED
		, AccountID			BIGINT	UNSIGNED
		, SubscriberID		INT
		, InsertTime		TIMESTAMP(4)
		, cusSubscriberID	INT
        , IssueType			TINYINT
		, PRIMARY KEY	PK_CustDCSAccount_AccountID(AccountID)          
		, INDEX			IX_CustDCSAccount_SubscriberID_CTSCustID(SubscriberID,CTSCustID)
        , INDEX			IX_Association_IssueType(IssueType)
	) ENGINE=INNODB  AUTO_INCREMENT=1;
    
CREATE TABLE IF NOT EXISTS CTS_Adhoc.csCTMax_AssociationByDevice_bk(
	CTSAssDevID		BIGINT	UNSIGNED AUTO_INCREMENT
	, CTSCustID		BIGINT	UNSIGNED
	, DCSDeviceID	BIGINT
	, SubscriberID	INT
	, CreatedTime	TIMESTAMP(4)
	, InsertTime	TIMESTAMP(4)
    , IssueType			TINYINT
	, PRIMARY KEY	PK_AssociationByDevice_CTSAssDevID(CTSAssDevID)
	, UNIQUE KEY	IX_AssociationByDevice_CTSCustID_DCSDeviceID(CTSCustID, DCSDeviceID)
	, INDEX			IX_AssociationByDevice_SubscriberID_DeviceID(SubscriberID, DCSDeviceID)
    , INDEX			IX_Association_IssueType(IssueType)
) ENGINE=INNODB AUTO_INCREMENT=1;

	CREATE TABLE IF NOT EXISTS CTS_Adhoc.csCTMax_CTSCustomer_bk(
		CTSCustID			BIGINT	UNSIGNED	AUTO_INCREMENT
		, SubscriberID		INT		UNSIGNED
		, CustID			INT		UNSIGNED
		, CustSubID			INT		UNSIGNED
		, UserName			VARCHAR(50) CHARACTER SET 'UTF8MB4' COLLATE 'UTF8MB4_UNICODE_CI'
		, UserName2			VARCHAR(50) CHARACTER SET 'UTF8MB4' COLLATE 'UTF8MB4_UNICODE_CI'
        , SiteID			INT
		, Site				VARCHAR(50) CHARACTER SET 'UTF8MB4' COLLATE 'UTF8MB4_UNICODE_CI'
		, RoleID			TINYINT
		, Currency			VARCHAR(10)
		, CurrencyID		INT		
		, SRecommend		INT		UNSIGNED
		, MRecommend		INT		UNSIGNED	
		, Recommend			INT		UNSIGNED
        , LastLoginTime		TIMESTAMP(4)
        , CreatedDate		DATETIME
		, PRIMARY KEY	PK_CTSCustomer_CTSCustID(CTSCustID)    
		, UNIQUE KEY	UK_CTSCustomer_SubscriberID_UserName_UserName2(SubscriberID, UserName, UserName2)
		, INDEX			IX_CTSCustomer_UserName_UserName2(UserName, UserName2)
		, INDEX			IX_CTSCustomer_UserName2(UserName2)
	) ENGINE=INNODB AUTO_INCREMENT=1;    
    
    CREATE TABLE IF NOT EXISTS CTS_Adhoc.csCTMax_DeviceFingerprint_bk(
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