
	CREATE TABLE IF NOT EXISTS CTS_DataCenter.zzzIssueLoginName_CTSCustomer (
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
		, INDEX			IX_CTSCustomer_CustID_CustSubID(CustID, CustSubID)
		, FULLTEXT 		IX_FullText_CTSCustomer_UserName_UserName2 (UserName,UserName2)
	) ENGINE=INNODB AUTO_INCREMENT=1;

CREATE TABLE IF NOT EXISTS CTS_DataCenter.zzzIssueLoginName_AssociationByDevice(
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
    
CREATE TABLE IF NOT EXISTS CTS_DataCenter.zzzIssueLoginName_AssociationByIP(
		CTSAssIPID			BIGINT	UNSIGNED	AUTO_INCREMENT
		, CTSCustID			BIGINT	UNSIGNED
		, IP				VARCHAR(50)
		, IPID				DECIMAL(50,0)
		, SubscriberID		INT
		, CreatedTime		TIMESTAMP(4)
		, LastLoginTime		TIMESTAMP(4)
		, InsertTime		TIMESTAMP(4)
		, PRIMARY KEY	PK_AssociationByIP_CTSAssID(CTSAssIPID)
		, UNIQUE KEY	UK_AssociationByIP_CTSCustID_IPID(CTSCustID,IPID)
		, INDEX			IX_AssociationByIP_LastLoginTime_CustID_IPID(LastLoginTime, CTSCustID, IPID)
	)ENGINE=INNODB  AUTO_INCREMENT=1;

CREATE TABLE IF NOT EXISTS CTS_DataCenter.zzzIssueLoginName_CustDCSAccount(
		CTSCustID			BIGINT	UNSIGNED
		, AccountID			BIGINT	UNSIGNED
		, SubscriberID		INT
		, InsertTime		TIMESTAMP(4)
		, PRIMARY KEY		PK_CustDCSAccount_AccountID(AccountID)  
        
		, INDEX	IX_CustDCSAccount_SubscriberID_CTSCustID(SubscriberID,CTSCustID)
	) ENGINE=INNODB  AUTO_INCREMENT=1;
    
CREATE TABLE IF NOT EXISTS CTS_DataCenter.zzzIssueLoginName_CustEvidence(
		CustEvidID			BIGINT		UNSIGNED	AUTO_INCREMENT	NOT NULL
		, CTSCustID			BIGINT		UNSIGNED					NOT NULL
        , SubscriberID		INT										NOT NULL
		, EvidenceID		SMALLINT								NOT NULL
		, Remark			VARCHAR(500)	CHARACTER SET 'UTF8MB4' COLLATE 'UTF8MB4_UNICODE_CI' NULL
		, Level				TINYINT									NOT NULL	COMMENT 'Level 1 - 2'
		, FromCustID		BIGINT		UNSIGNED					NOT NULL
		, CreatedDate		DATETIME								NOT NULL
		, CreatedBy			INT										NOT NULL
		, IsCreatedByMaster	TINYINT									NOT NULL
        
        , PRIMARY KEY	PK_CustEvidence(SubscriberID, CTSCustID, FromCustID, EvidenceID, IsCreatedByMaster)
        , UNIQUE INDEX	UX_CustEvidence_CustEvidID(CustEvidID)
	) ENGINE=INNODB  AUTO_INCREMENT=1;

CREATE TABLE IF NOT EXISTS CTS_DataCenter.zzzIssueLoginName_CustRetractEvidence (
		CTSCustID 			BIGINT		UNSIGNED	NOT NULL
		, EvidenceID 		SMALLINT				 NOT NULL
		, Remark 			VARCHAR(500) CHARACTER SET 'UTF8MB4' COLLATE 'UTF8MB4_UNICODE_CI' DEFAULT NULL
		, CreatedDate 		DATETIME DEFAULT NULL
		, CreatedBy 		INT		 NOT NULL
		, PRIMARY KEY PK_CustRetractEvidence_CTSCustID_EvidenceID(CTSCustID, EvidenceID)
	) ENGINE=INNODB;
    
    	CREATE TABLE IF NOT EXISTS CTS_DataCenter.zzzIssueLoginName_CTSCustomer_DuplicateNew (
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
		, INDEX			IX_CTSCustomer_CustID_CustSubID(CustID, CustSubID)
		, FULLTEXT 		IX_FullText_CTSCustomer_UserName_UserName2 (UserName,UserName2)
	) ENGINE=INNODB AUTO_INCREMENT=1;