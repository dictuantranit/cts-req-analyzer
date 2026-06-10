/*
Creator: 20191106@CaseyHuynh + Harvey.Nguyen
Task:	 	CTS_Schema
Server:  	Slave
DBName:		CTS_DataCenter

Revisions: 
		- 20191217@CaseyHuynh: Add Column LastLoginDate column to table CTSCustomer.  	(#125530)
        - 20200117@HarveyNguyen: Add table CustRetractEvidence							(#127352)
        - [202002130@Casey.Huynh][130109]: Add INDEX (SubscriberID, CTSCustID) on TABLE CustDCSAcount.
Reviewer:
*/

CREATE DATABASE IF NOT EXISTS CTS_DataCenter;

	CREATE TABLE IF NOT EXISTS CTS_DataCenter.CTSCustomer (
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

	CREATE TABLE IF NOT EXISTS CTS_DataCenter.AssociationByDevice(
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

	CREATE TABLE IF NOT EXISTS CTS_DataCenter.AssociationByIP(
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

	CREATE TABLE IF NOT EXISTS CTS_DataCenter.CustDCSAccount(
		CTSCustID			BIGINT	UNSIGNED
		, AccountID			BIGINT	UNSIGNED
		, SubscriberID		INT
		, InsertTime		TIMESTAMP(4)
		, PRIMARY KEY		PK_CustDCSAccount_AccountID(AccountID)  
        
		, INDEX	IX_CustDCSAccount_SubscriberID_CTSCustID(SubscriberID,CTSCustID)
	) ENGINE=INNODB  AUTO_INCREMENT=1;
	
   CREATE TABLE IF NOT EXISTS CTS_DataCenter.MappingSubscriberSite(
		
		SubscriberID		INT
		, SubscriberName	VARCHAR(50)
        , RoleMapping		TINYINT
		, SubscriberType	TINYINT
        , SubscriberStatus	TINYINT
        , SiteID			INT
        , SiteName			VARCHAR(50)
        , Comments			VARCHAR(200)
		, PRIMARY KEY	PK_MappingSubscriberSite_SubscriberID(SiteID, SubscriberID)    
	) ENGINE=INNODB;

# ======EvidenceGroup=============================================
	CREATE TABLE IF NOT EXISTS CTS_DataCenter.EvidenceGroup(
		EvidenceGroupID			TINYINT			AUTO_INCREMENT		NOT NULL
		, EvidenceGroupName		VARCHAR(50)							NOT NULL
		, EvidenceGroupDesc		VARCHAR(200)	CHARACTER SET 'UTF8MB4' COLLATE 'UTF8MB4_UNICODE_CI'	NULL
		, OrderNo				SMALLINT							NULL
		, CreatedDate			DATETIME							NOT NULL
		, CreatedBy				INT									NOT NULL
		, IsActive				TINYINT								NOT NULL
        
        , PRIMARY KEY	PK_EvidenceGroup_EvidenceGroupID(EvidenceGroupID)
	) ENGINE=INNODB AUTO_INCREMENT=1;

	# ========EvidenceType===========================================
	CREATE TABLE IF NOT EXISTS CTS_DataCenter.Evidence(
		EvidenceID			SMALLINT		AUTO_INCREMENT			NOT NULL
		, EvidenceGroupID	TINYINT									NOT NULL
		, EvidenceCode		VARCHAR(10)								NOT NULL
		, EvidenceName		VARCHAR(50)								NOT NULL
		, EvidenceDesc		VARCHAR(200)	CHARACTER SET 'UTF8MB4' COLLATE 'UTF8MB4_UNICODE_CI'	NULL
		, OrderNo			SMALLINT								NOT NULL
		, CreatedDate		DATETIME								NOT NULL
		, CreatedBy			INT										NOT NULL
		, IsActive			TINYINT									NOT NULL
        
        , PRIMARY KEY	PK_Evidence_EvidenceID(EvidenceID)
        , UNIQUE INDEX	UX_Evidence_EvidenceGroupID_EvidenceCode(EvidenceGroupID, EvidenceCode)
	) ENGINE=INNODB  AUTO_INCREMENT=1;

	# =======CustEvidence============================================
	CREATE TABLE IF NOT EXISTS CTS_DataCenter.CustEvidence(
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
	
    # =======CustRetractEvidence============================================
	CREATE TABLE IF NOT EXISTS CTS_DataCenter.CustRetractEvidence (
		CTSCustID 			BIGINT		UNSIGNED	NOT NULL
		, EvidenceID 		SMALLINT				 NOT NULL
		, Remark 			VARCHAR(500) CHARACTER SET 'UTF8MB4' COLLATE 'UTF8MB4_UNICODE_CI' DEFAULT NULL
		, CreatedDate 		DATETIME DEFAULT NULL
		, CreatedBy 		INT		 NOT NULL
		, PRIMARY KEY PK_CustRetractEvidence_CTSCustID_EvidenceID(CTSCustID, EvidenceID)
	) ENGINE=INNODB;
    
	# ========LogType===========================================
	CREATE TABLE  IF NOT EXISTS CTS_DataCenter.LogType(
		LogTypeID				SMALLINT		AUTO_INCREMENT		NOT NULL
		, LogTypeName			VARCHAR(50)							NULL
		, LogTypeDescription	VARCHAR(200)	CHARACTER SET 'UTF8MB4' COLLATE 'UTF8MB4_UNICODE_CI'	NULL
        
        , PRIMARY KEY	PK_LogType_LogTypeID(LogTypeID)
     ) ENGINE=INNODB  AUTO_INCREMENT=1;
     
	# ========IPLocation===========================================
	CREATE TABLE IF NOT EXISTS IPRangeLocation (
		IPRangeLocationID			INT 			NOT NULL 		AUTO_INCREMENT
		, IPRangeLocationCode		VARCHAR(64) 	DEFAULT NULL
		, FromIP					DECIMAL(50,0) 	NOT NULL
		, ToIP						DECIMAL(50,0) 	NOT NULL
		, CountryCode				VARCHAR(10) 	DEFAULT NULL
		, CountryName				VARCHAR(80) 	DEFAULT NULL
		, Region					VARCHAR(128) 	DEFAULT NULL
		, City						VARCHAR(100) 	DEFAULT NULL
		, ISPName					VARCHAR(256) 	DEFAULT NULL
		, Status					TINYINT		 	DEFAULT NULL 	COMMENT '0: Inactive; 1: Active'
		, CreatedDate				DATETIME 		DEFAULT NULL
		, PRIMARY KEY PK_IPRangeLocation_IPRangeLocationID(IPRangeLocationID)
		, UNIQUE KEY	UK_IPRangeLocation_FromIP_ToIP(FromIP,ToIP)
		, INDEX		IX_IPRangeLocation_IPRangeLocationCode(IPRangeLocationCode)
	) ENGINE=INNODB  AUTO_INCREMENT=1;

	CREATE TABLE IF NOT EXISTS IPRangeLocation_Initial (
		IPRangeLocationID 		INT				NOT NULL 		AUTO_INCREMENT
		, IPRangeLocationCode	VARCHAR(64) 	DEFAULT NULL
		, FromIP 				DECIMAL(50,0)	NOT NULL
		, ToIP 					DECIMAL(50,0)	NOT NULL
		, CountryCode			VARCHAR(10)		DEFAULT NULL
		, CountryName			VARCHAR(80)		DEFAULT NULL
		, Region				VARCHAR(128)	DEFAULT NULL
		, City					VARCHAR(100)	DEFAULT NULL
		, ISPName				VARCHAR(256)	DEFAULT NULL
		, Status				TINYINT			DEFAULT NULL COMMENT '0: Inactive; 1: Active'
		, CreatedDate 			DATETIME		DEFAULT NULL
		, PRIMARY KEY	PK_IPRangeLocation_Initial_IPRangeLocationID(IPRangeLocationID)
		, INDEX			IX_IPRangeLocation_Initial_FromIP_ToIP (FromIP,ToIP)
		, INDEX			IX_IPRangeLocation_Initial_IPRangeLocationCode (IPRangeLocationCode)
	) ENGINE=INNODB AUTO_INCREMENT=1;

	CREATE TABLE IF NOT EXISTS IPTableLog (
		IPTableLogID 			INT			NOT NULL 		AUTO_INCREMENT
		, UpdatedDate			DATETIME	DEFAULT NULL
		, IsNewUpdate			TINYINT		DEFAULT NULL	COMMENT '0: old, 1: New'
		, PRIMARY KEY	PK_IPTableLog_IPTableLogID(IPTableLogID)
		, INDEX 		IX_IPTableLog_IPType_Flag (IsNewUpdate)
	) ENGINE=INNODB AUTO_INCREMENT=1;

# ===================================================
CREATE TABLE IF NOT EXISTS CTS_DataCenter.StaticList
(
	ListID				INT
    , ItemID			SMALLINT
    , ListName			VARCHAR(100)
    , ListNameDisplay	VARCHAR(200)
    , ItemName			VARCHAR(100)
    , ItemNameDisplay	VARCHAR(200)
    , PriorityOrder		SMALLINT
    , Status			BOOL
    , Description		VARCHAR(200)    
    , CreatedDate		DATETIME
    
    , PRIMARY KEY PK_StaticList_ListID_ItemID(ListID, ItemID)
) ;

CREATE TABLE IF NOT EXISTS CTS_DataCenter.CustRetractEvidence
(
	  CTSCustID			BIGINT		UNSIGNED	NOT NULL
    , EvidenceID		SMALLINT    NOT NULL
    , Remark			VARCHAR(500)
    , CreatedDate		DATETIME
    , CreatedBy			INT
    
    , PRIMARY KEY PK_CustRetractEvidence_CTSCustID_EvidenceID(CTSCustID,EvidenceID)
) ENGINE=INNODB;

CREATE TABLE IF NOT EXISTS CTS_DataCenter.CustException
(	
	FromCTSCustID					BIGINT 	UNSIGNED	NOT NULL
    , ToCTSCustID					BIGINT	UNSIGNED	NOT NULL
	, LeastCTSCustID_Order			BIGINT	UNSIGNED	AS (LEAST(FromCTSCustID, ToCTSCustID)) 		STORED
    , GreatestCTSCustID_Order		BIGINT	UNSIGNED	AS (GREATEST(FromCTSCustID, ToCTSCustID))	STORED
    , CreatedDate		DATETIME	NULL
    , CreatedBy			BIGINT		NULL	
    , Comment			VARCHAR(500)	CHARACTER SET 'UTF8MB4' COLLATE 'UTF8MB4_UNICODE_CI'	NULL
	
    , PRIMARY KEY	PK_CustException_FromCTSCustID_ToCTSCustID(LeastCTSCustID_Order,GreatestCTSCustID_Order)
) ENGINE=INNODB;

CREATE TABLE IF NOT EXISTS CTS_DataCenter.ProcessAffectedEvidence
(	
	LastCTSAssDevID		BIGINT	UNSIGNED
)  ENGINE=INNODB;
