/*
Creator: 20191106@CaseyHuynh + Harvey.Nguyen
Task:	 	CTS_Schema
Server:  	Slave
DBName:		CTS_DataCenter

Revisions: 
		- [20191217@CaseyHuynh][125530]: Add Column LastLoginDate column to table CTSCustomer.  	(#125530)
        - [20200117@HarveyNguyen][127352]: Add table CustRetractEvidence							(#127352)
        - [202002130@Casey.Huynh][130109]: Add INDEX (SubscriberID, CTSCustID) on TABLE CustDCSAcount.
        - [20200416@Long.Luu][131506]: Manage Association_Create tables(AssociationByManual, AssociationRemove)
        - [20200416@Long.Luu][132623]: Customer Category_Create tables(SportGroup, CustomerCategory, CTSCustomerClassification)
        - [20200612@Casey.Huynh][135324]: 
			+ Alter Table CTSCustomerClassification, add column LastScannedDate
            + Alter table CTS_DataCenter.CustomerCategory: Add ScanIntervalInSecond
            + Re-Design Table CTS_DataCenter.CustomerCategory_History
            + Add table CTS_DataCenter.CTSCustomerClassification_ScanStatus
            
		- [20200706@Long.Luu][134652]: Associated Account Monitor	[Redmine ID: #134652]
        - [20200806@Casey.Huynh]: Add Index for table AssociationByDevice
        - [20200807@Casey.Huynh][138925]: Chagne CustEvidence Structure for Cross Subscriber
        - [20200820@Casey.Huynh][139061]: Update Index CTSCustomer Classification
        - [20200903@Harvey.Nguyen][140869]: Add more column to table CTSCustomerClassification_ScanStatus
        - [20200905@Long.Luu][140996]: New table for storing Hardcoded CustomerClass's customers
        - [20200909@Irena.Vo][141020]: Enhance Schema for params CustomerClass's customers
        - [20200917@Long.Luu][141755]: Probation Category Monitoring
        - [20201006@Long.Luu][142414]: Notification Settings
        - [20201012@Long.Luu][141756]: Sync Evidence to CTS Category
        - [20201016@Irena.Vo][145028]: Add LastScannedDate column
		- [20201113@Aries.Nguyen][145271]: Add Column InsertedTime, ModifiedTime columns to table CTSCustomer
        
Reviewer:
*/

CREATE DATABASE IF NOT EXISTS CTS_DataCenter;

	CREATE TABLE IF NOT EXISTS   `CTS_DataCenter`.`CTSCustomer` (
		  `CTSCustID` bigint unsigned NOT NULL AUTO_INCREMENT
		  , `SubscriberID` int unsigned DEFAULT NULL
		  , `CustID` int unsigned DEFAULT NULL
		  , `CustSubID` int unsigned DEFAULT NULL
		  , `UserName` varchar(50) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL
		  , `UserName2` varchar(50) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL
		  , `RegisterName` varchar(50) COLLATE utf8_unicode_ci DEFAULT NULL
		  , `SiteID` int DEFAULT NULL
		  , `Site` varchar(50) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL
		  , `RoleID` tinyint DEFAULT NULL
		  , `Currency` varchar(10) COLLATE utf8_unicode_ci DEFAULT NULL
		  , `CurrencyID` int DEFAULT NULL
		  , `SRecommend` int unsigned DEFAULT NULL
		  , `MRecommend` int unsigned DEFAULT NULL
		  , `Recommend` int unsigned DEFAULT NULL
		  , `LastLoginTime` timestamp(4) NULL DEFAULT NULL
		  , `CreatedDate` datetime DEFAULT NULL
		  , `CustStatusID` tinyint DEFAULT '1'
		  , `Danger1` tinyint DEFAULT '0'
		  , `Danger2` tinyint DEFAULT '0'
		  , `Danger3` tinyint DEFAULT '0'
		  , `InsertedTime` datetime(4) DEFAULT NULL
		  , `ModifiedTime` datetime(4) DEFAULT NULL
		  , PRIMARY KEY (`CTSCustID`)
		  , UNIQUE KEY `UK_CTSCustomer_04062020_SubID_UserName_UserName2` (`SubscriberID`,`UserName`,`UserName2`)
		  , KEY `IX_CTSCustomer_RoleID` (`RoleID`)
		  , KEY `IX_CTSCustomer_04062020_UserName` (`UserName`)
		  , KEY `IX_CTSCustomer_04062020_UserName2` (`UserName2`)
		  , KEY `IX_CTSCustomer_04062020_RegisterName` (`RegisterName`)
		  , KEY `IX_CTSCustomer_04062020_CustID_CustSubID` (`CustID`,`CustSubID`)
		  , KEY `IX_CTSCustomer_SRecommend_RoleID` (`SRecommend`,`RoleID`)
		) ENGINE=InnoDB AUTO_INCREMENT=1 DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci

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
        , INDEX			IX_AssociationByDevice_DCSDeviceID_CTSCustID( DCSDeviceID, CTSCustID)
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
		, SubscriberGroupID SMALLINT UNSIGNED
        , SiteID			INT
        , SiteName			VARCHAR(50)
        , Comments			VARCHAR(200)
		, PRIMARY KEY	PK_MappingSubscriberSite_SiteIDSubscriberID(SiteID, SubscriberID)
		, INDEX			IX_MappingSubscriberSite_SubscriberID(SubscriberID)
	) ENGINE=INNODB;

	# ======SubscriberGroup=============================================
    CREATE TABLE IF NOT EXISTS CTS_DataCenter.SubscriberGroup (
		SubscriberGroupID			SMALLINT UNSIGNED AUTO_INCREMENT
	, 	SubscriberGroupName		VARCHAR(50) CHARACTER SET 'UTF8MB4' COLLATE 'UTF8MB4_UNICODE_CI'
    , 	SubscriberGroupDesc		VARCHAR(200) CHARACTER SET 'UTF8MB4' COLLATE 'UTF8MB4_UNICODE_CI'
    ,	ParentID			SMALLINT UNSIGNED
	, 	DisplayOrder		TINYINT UNSIGNED
    ,	IsActive			BIT DEFAULT 1
	, 	CreatedDate			DATETIME
    ,	CreatedBy			INT UNSIGNED
    , 	LastModifiedDate	DATETIME
    ,	LastModifiedBy		INT UNSIGNED
	, 	PRIMARY KEY			PK_SubscriberGroup_SubscriberGroupDisplayOrder(SubscriberGroupID,DisplayOrder)
	, 	INDEX				IX_SubscriberGroup_ParentID(ParentID)
    , 	INDEX				IX_SubscriberGroup_IsActive(IsActive)
) ENGINE=INNODB AUTO_INCREMENT=1;

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

/*	# =======CustEvidence============================================
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
*/	
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


CREATE TABLE IF NOT EXISTS CTS_DataCenter.AssociationByManual (
	FromSubscriberID		INT		UNSIGNED
	, FromCTSCustID			BIGINT	UNSIGNED
	, ToSubscriberID		INT		UNSIGNED
	, ToCTSCustID			BIGINT	UNSIGNED
	, Remark				VARCHAR(500) CHARACTER SET 'UTF8MB4' COLLATE 'UTF8MB4_UNICODE_CI'
	, CreatedDate			DATETIME
    , CreatedBy				BIGINT
	, PRIMARY KEY	PK_AssociationByManual_FromCustIDToCustID(FromCTSCustID, ToCTSCustID)
	, INDEX			IX_AssociationByManual_ToCTSCustID(ToCTSCustID)
    , INDEX			IX_AssociationByManual_FromSubscriberIDToSubscriberID(FromSubscriberID, ToSubscriberID)
	, INDEX			IX_AssociationByManual_CreatedDate(CreatedDate)
) ENGINE=INNODB AUTO_INCREMENT=1;

CREATE TABLE IF NOT EXISTS CTS_DataCenter.AssociationRemove (
	FromSubscriberID		INT		UNSIGNED
	, FromCTSCustID			BIGINT	UNSIGNED
	, ToSubscriberID		INT		UNSIGNED
	, ToCTSCustID			BIGINT	UNSIGNED
	, Remark				VARCHAR(500) CHARACTER SET 'UTF8MB4' COLLATE 'UTF8MB4_UNICODE_CI'
	, CreatedDate			DATETIME
    , CreatedBy				BIGINT
	, PRIMARY KEY	PK_AssociationRemove_FromCustIDToCustID(FromCTSCustID, ToCTSCustID)
	, INDEX			IX_AssociationRemove_ToCTSCustID(ToCTSCustID)
	, INDEX			IX_AssociationRemove_FromSubscriberIDToSubscriberID(FromSubscriberID, ToSubscriberID)
	, INDEX			IX_AssociationRemove_CreatedDate(CreatedDate)
) ENGINE=INNODB AUTO_INCREMENT=1;

CREATE TABLE IF NOT EXISTS CTS_DataCenter.SportGroup (
		SportGroupID		SMALLINT UNSIGNED AUTO_INCREMENT
	, 	SportGroupName		VARCHAR(50) CHARACTER SET 'UTF8MB4' COLLATE 'UTF8MB4_UNICODE_CI'
    ,	MainDBSportID		SMALLINT UNSIGNED
	, 	DisplayOrder		TINYINT UNSIGNED
    ,	IsActive			BIT DEFAULT 1
	, 	CreatedDate			DATETIME
    ,	CreatedBy			INT UNSIGNED
	, 	PRIMARY KEY		PK_SportGroup_SportGroupIDDisplayOrder(SportGroupID,DisplayOrder)
	, 	INDEX			IX_SportGroup_MainDBSportID(MainDBSportID));

CREATE TABLE IF NOT EXISTS CTS_DataCenter.SmartGroup (
		GroupID				INT UNSIGNED NOT NULL
    ,   CustID				INT UNSIGNED NOT NULL
    ,	Username			VARCHAR(64) NOT NULL
    , 	Similarity			FLOAT NOT NULL DEFAULT '0'
    ,	Currency 			VARCHAR(8) NOT NULL
    ,	Site	 			VARCHAR(32) NOT NULL
    , 	AgentID				INT UNSIGNED NOT NULL 
    , 	AgentName			VARCHAR(64) NOT NULL
    , 	MasterID			INT UNSIGNED NOT NULL 
    , 	MasterName			VARCHAR(64) NOT NULL
    , 	SuperID				INT UNSIGNED NOT NULL 
    , 	SuperName			VARCHAR(64) NOT NULL
    , 	CreatedDate			DATETIME DEFAULT NULL
    , 	PRIMARY KEY			PK_SmartGroup_CustIDGroupID(CustID, GroupID)
    , 	INDEX				IX_SmartGroup_Username(Username)
) ENGINE=INNODB DEFAULT CHARSET='UTF8MB4' COLLATE='UTF8MB4_UNICODE_CI';

CREATE TABLE IF NOT EXISTS CTS_DataCenter.SmartGroupHistory (
		GroupID				INT UNSIGNED NOT NULL
    ,   CustID				INT UNSIGNED NOT NULL
    ,	Username			VARCHAR(64) NOT NULL
    , 	Similarity			FLOAT NOT NULL DEFAULT '0'
    ,	Currency 			VARCHAR(8) NOT NULL
    ,	Site	 			VARCHAR(32) NOT NULL
    , 	AgentID				INT UNSIGNED NOT NULL 
    , 	AgentName			VARCHAR(64) NOT NULL
    , 	MasterID			INT UNSIGNED NOT NULL 
    , 	MasterName			VARCHAR(64) NOT NULL
    , 	SuperID				INT UNSIGNED NOT NULL 
    , 	SuperName			VARCHAR(64) NOT NULL
    , 	CreatedDate			DATE NOT NULL
    , 	PRIMARY KEY			PK_SmartGroup_CustIDGroupID(CustID, CreatedDate)
    , 	INDEX				IX_SmartGroup_Username(Username)
) ENGINE=INNODB DEFAULT CHARSET='UTF8MB4' COLLATE='UTF8MB4_UNICODE_CI';
  
) ENGINE=INNODB AUTO_INCREMENT=1;

CREATE TABLE IF NOT EXISTS 	CTS_DataCenter.CustomerCategory (
		CategoryID			SMALLINT UNSIGNED AUTO_INCREMENT
	, 	CategoryName		VARCHAR(50) CHARACTER SET 'UTF8MB4' COLLATE 'UTF8MB4_UNICODE_CI'
    , 	CategorySpec		VARCHAR(200) CHARACTER SET 'UTF8MB4' COLLATE 'UTF8MB4_UNICODE_CI'
    ,	ParentID			SMALLINT UNSIGNED
	, 	DisplayOrder		TINYINT UNSIGNED
    ,	IsActive			BIT DEFAULT 1
	, 	CreatedDate			DATETIME
    ,	CreatedBy			INT UNSIGNED
    , 	LastModifiedDate	DATETIME
    ,	LastModifiedBy		INT UNSIGNED
    ,	IsUsedManually		BIT	
    , 	ScanIntervalInSecond	BIGINT
	, 	PRIMARY KEY			PK_CustomerCategory_CategoryIDDisplayOrder(CategoryID,DisplayOrder)
	, 	INDEX				IX_CustomerCategory_ParentID(ParentID)
    , 	INDEX				IX_CustomerCategory_IsActive(IsActive)
) ENGINE=INNODB AUTO_INCREMENT=1;

CREATE TABLE IF NOT EXISTS CTS_DataCenter.CTSCustomerClassification (
		CustID				BIGINT UNSIGNED
	,	CTSCustID			BIGINT UNSIGNED
	, 	SubscriberID		INT	UNSIGNED
    ,	SportGroupID		SMALLINT UNSIGNED
	, 	CategoryID			SMALLINT UNSIGNED    
	, 	Remark				VARCHAR(500) CHARACTER SET 'UTF8MB4' COLLATE 'UTF8MB4_UNICODE_CI'
	, 	CreatedDate			DATETIME
    ,	CreatedBy			INT
    , 	LastModifiedDate	DATETIME
    ,	LastModifiedBy		INT UNSIGNED
    ,	LastScannedDate		DATETIME
	, 	PRIMARY KEY			PK_CTSCustomerClassification_CustIDSportGroupIDCategoryID(CustID, SportGroupID, CategoryID)
    ,   INDEX				IX_CTSCustomerClassification_CategoryIDLastScannedDate(CategoryID, LastScannedDate, SportGroupID, CustID)
    , 	INDEX 				IX_CTSCustomerClassification_CTSCustID(CTSCustID)
) ENGINE=INNODB;

CREATE TABLE IF NOT EXISTS CTS_DataCenter.CTSCustomerClassification_History (
		ID					BIGINT UNSIGNED AUTO_INCREMENT
	,	CustID				BIGINT UNSIGNED
    ,  	CTSCustID			BIGINT UNSIGNED
	, 	CategoryID			SMALLINT UNSIGNED
    ,	SportGroupID		SMALLINT UNSIGNED
    , 	LastModifiedDate	DATETIME
    ,	LastModifiedBy		INT UNSIGNED
    , 	TurnoverRM			DECIMAL(20,4)
    , 	WinlossRM			DECIMAL(20,4)
    , 	BetCount			BIGINT
	, 	ActiveDays			INT
    ,	ActionType			TINYINT
    ,	IsAuto				BIT
    , 	InsertDate			DATETIME
    , 	PRIMARY KEY			PK_CTSCustomerClassificationHistory_ID(ID)
	, 	INDEX				IX_CTSCustomerClassificationHistory_CustIDSportGroupID(CustID, SportGroupID)
    ,	INDEX				IX_CTSCustomerClassificationHistory_LastModifiedDate(LastModifiedDate)
) ENGINE=INNODB AUTO_INCREMENT=1;

CREATE TABLE IF NOT EXISTS  CTS_DataCenter.CTSCustomerClassification_ScanStatus
(
	ScanTime		DATETIME
    , LastCustID	BIGINT UNSIGNED
    , ScanStatus	TINYINT				# 0-Inprogress, 1-Done
    
    ,PRIMARY KEY	PK_CTSCustomerClassification_ScanStatus_ScannedTime(ScanTime)
);

CREATE TABLE IF NOT EXISTS CTS_DataCenter.SmartGroup (
		GroupID				INT UNSIGNED NOT NULL
    ,   CustID				INT UNSIGNED NOT NULL
	,	Username			VARCHAR(64) NOT NULL
	, 	Similarity			FLOAT NOT NULL DEFAULT '0'
    ,	Currency 			VARCHAR(8) NOT NULL
    ,	Site	 			VARCHAR(32) NOT NULL
	, 	AgentID				INT UNSIGNED NOT NULL 
	, 	AgentName			VARCHAR(64) NOT NULL
    , 	MasterID			INT UNSIGNED NOT NULL 
	, 	MasterName			VARCHAR(64) NOT NULL
    , 	SuperID				INT UNSIGNED NOT NULL 
	, 	SuperName			VARCHAR(64) NOT NULL
	, 	CreatedDate			DATETIME DEFAULT NULL
	, 	PRIMARY KEY			PK_SmartGroup_CustIDGroupID(CustID, GroupID)
	, 	INDEX				IX_SmartGroup_Username(Username)
) ENGINE=INNODB DEFAULT CHARSET='UTF8MB4' COLLATE='UTF8MB4_UNICODE_CI';

CREATE TABLE IF NOT EXISTS CTS_DataCenter.AssociatedAccountMonitor (
		CTSCustID			INT UNSIGNED NOT NULL
	,	Remark				VARCHAR(200) NOT NULL
	, 	CreatedBy			INT UNSIGNED NOT NULL
    , 	CreatedTime			DATETIME NOT NULL
	, 	PRIMARY KEY			PK_AssociatedAccountMonitor_CTSCustID(CTSCustID)
) ENGINE=INNODB DEFAULT CHARSET='UTF8MB4' COLLATE='UTF8MB4_UNICODE_CI';

CREATE TABLE IF NOT EXISTS CTS_DataCenter.AssociatedAccountNewAssociation (
		AccountNewAssID			BIGINT UNSIGNED AUTO_INCREMENT
    ,	CTSCustID				INT UNSIGNED NOT NULL
	,	UserName				VARCHAR(50) NOT NULL
	, 	NewAssCount				SMALLINT UNSIGNED NOT NULL DEFAULT 0
    , 	CreatedDate				DATE NOT NULL
    , 	CreatedTime				DATETIME NOT NULL
	, 	PRIMARY KEY				PK_AssociatedAccountNewAssociation_AccountNewAssID(AccountNewAssID)
    ,	INDEX					IX_AssociatedAccountNewAssociation_CTSCustID(CTSCustID)
    ,	INDEX					IX_AssociatedAccountNewAssociation_CreatedDate(CreatedDate)
) ENGINE=INNODB DEFAULT CHARSET='UTF8MB4' COLLATE='UTF8MB4_UNICODE_CI';

CREATE TABLE IF NOT EXISTS CTS_DataCenter.CTSUserNotificationParameter (
		UserID					INT UNSIGNED PRIMARY KEY
    ,	FromNewAssID			BIGINT UNSIGNED DEFAULT 0
    ,	ToNewAssID				BIGINT UNSIGNED DEFAULT 0
) ENGINE=INNODB DEFAULT CHARSET='UTF8MB4' COLLATE='UTF8MB4_UNICODE_CI';

CREATE TABLE IF NOT EXISTS CTS_DataCenter.SystemParameter (
		ParameterID				SMALLINT UNSIGNED PRIMARY KEY
    ,	ParameterName			VARCHAR(50)
    ,	ParameterDesc			VARCHAR(200)
    ,	ParameterDataType		VARCHAR(50)
    ,	ParameterValue			VARCHAR(200)
) ENGINE=INNODB DEFAULT CHARSET='UTF8MB4' COLLATE='UTF8MB4_UNICODE_CI';

#- 20200807@Casey.Huynh: Chagne CustEvidence Structure

	# =======CustEvidence============================================
    DROP TABLE IF EXISTS CTS_DataCenter.CustEvidence;
	CREATE TABLE IF NOT EXISTS CTS_DataCenter.CustEvidence(
		CustEvidID			BIGINT		UNSIGNED	AUTO_INCREMENT	NOT NULL
		, CTSCustID			BIGINT		UNSIGNED					NOT NULL
		, EvidenceID		SMALLINT								NOT NULL
		, Remark			VARCHAR(500)	CHARACTER SET 'UTF8MB4' COLLATE 'UTF8MB4_UNICODE_CI' NULL
		, Level				TINYINT									NOT NULL	COMMENT 'Level 1 - 2'
		, FromCustID		BIGINT		UNSIGNED					NOT NULL
		, CreatedDate		DATETIME								NOT NULL
		, CreatedBy			INT										NOT NULL
        
        , PRIMARY KEY	PK_CustEvidence(CTSCustID, FromCustID, EvidenceID)
        , INDEX			IX_CustEvidence(FromCustID, CTSCustID, EvidenceID)
        , UNIQUE INDEX	UX_CustEvidence_CustEvidID(CustEvidID)
	) ENGINE=INNODB  AUTO_INCREMENT=1;
	
# - 138575@Roger.Le: Enhance Associated Account Monitor by NAP Permission
DROP TABLE IF EXISTS CTS_DataCenter.CTSUserPermission;
CREATE TABLE IF NOT EXISTS CTS_DataCenter.CTSUserPermission (
		UserID					INT UNSIGNED
	,	FunctionName			VARCHAR(50)
    ,	GrantedFrom				DATETIME DEFAULT NULL
    ,	GrantedTo				DATETIME DEFAULT NULL
	, 	CreatedDate				DATETIME DEFAULT NULL
    , 	LastModifiedDate		DATETIME DEFAULT NULL
	,	INDEX					IX_CTSUserPermission(UserID, FunctionName)
) ENGINE=INNODB DEFAULT CHARSET='UTF8MB4' COLLATE='UTF8MB4_UNICODE_CI';


DROP TABLE IF EXISTS CTS_DataCenter.CustEvidenceLog;
CREATE TABLE IF NOT EXISTS CTS_DataCenter.CustEvidenceLog(
	CustEvidID			BIGINT		UNSIGNED	AUTO_INCREMENT	NOT NULL
	, CTSCustID			BIGINT		UNSIGNED					NOT NULL
	, EvidenceID		SMALLINT								NOT NULL
	, Remark			VARCHAR(500)	CHARACTER SET 'UTF8MB4' COLLATE 'UTF8MB4_UNICODE_CI' NULL
	, Level				TINYINT									NOT NULL	COMMENT 'Level 0 - 2'
	, FromCustID		BIGINT		UNSIGNED					NOT NULL
	, CreatedDate		DATETIME								NOT NULL
	, CreatedBy			INT										NOT NULL
	, SessionId			BIGINT									NOT NULL
	
	, PRIMARY KEY	CustEvidenceLog(CustEvidID)
	, INDEX			IX_CustEvidenceLog(SessionId)
) ENGINE=INNODB  AUTO_INCREMENT=1;
	
ALTER TABLE CTS_DataCenter.CTSCustomerClassification_ScanStatus ADD COLUMN ParentCategoryID SMALLINT;

#[20200905@Long.Luu][140996]: New table for storing Hardcoded CustomerClass customers. 
-- CreatedFromFunction = 1: Normal, CreatedFromFunction = 11: VVIP, CreatedFromFunction = 21: Pin Category
#[20200909@Irena.Vo][141020]: Enhance Schema for params & insert LogTypeID = 21, 22. Add Index for custid
DROP TABLE IF EXISTS CTS_DataCenter.SpecialCustomerClass;
CREATE TABLE IF NOT EXISTS CTS_DataCenter.SpecialCustomerClass(
		CTSCustID			BIGINT UNSIGNED	NOT NULL
	, 	CustID				INT UNSIGNED NOT NULL
	, 	RootCTSCustID		BIGINT UNSIGNED	NOT NULL
	, 	SubscriberID		INT NOT NULL
	, 	CustomerClass		TINYINT DEFAULT NULL
	, 	CreatedBy			INT	NOT NULL
	, 	CreatedDate			DATETIME NOT NULL
    , 	LastModifiedBy		INT DEFAULT NULL	
	, 	LastModifiedDate	DATETIME DEFAULT NULL
    ,   CreatedFromFunction TINYINT NOT NULL
	, 	PRIMARY KEY			PK_SpecialCustomerClass_CTSCustID_CreatedFromFunction(CTSCustID, CreatedFromFunction)
	, 	INDEX				IX_SpecialCustomerClass_SubscriberID(SubscriberID)
    , 	INDEX				IX_SpecialCustomerClass_RootCTSCustID(RootCTSCustID)
    , 	INDEX				IX_SpecialCustomerClass_CustID(CustID)
) ENGINE=INNODB;

USE DCS_DataCenter;
ALTER TABLE DeviceFingerprint 
	DROP PRIMARY KEY
    , DROP INDEX UK_DeviceFingerprint_DeviceID_FingerprintCode
	, ADD KEY KEY_DeviceFingerprintID (DeviceFingerprintID)
	, ADD PRIMARY KEY (`DeviceID`, `FingerprintCode`);
	
USE DCS_DataCenter;
ALTER TABLE Association 
	DROP PRIMARY KEY
        , DROP INDEX UK_Association_AccountID_Device
	, ADD KEY KEY_AssociationID (AssociationID)
	, ADD PRIMARY KEY(`AccountID`, `DeviceID`);
    
#[20200917@Long.Luu][141755]: Probation Category Monitoring
DROP TABLE IF EXISTS CTS_DataCenter.ProbationCategoryMonitor;
CREATE TABLE IF NOT EXISTS CTS_DataCenter.ProbationAccountMonitor(
		CTSCustID			BIGINT UNSIGNED	NOT NULL
	, 	CustID				INT UNSIGNED NOT NULL
	, 	SportGroupID		SMALLINT NOT NULL
	, 	TargetCategoryID	SMALLINT DEFAULT NULL
    ,	FirstMargin			DECIMAL(20,4)
	, 	CreatedBy			INT	NOT NULL
	, 	CreatedDate			DATETIME NOT NULL
    , 	CreatedTime			DATETIME NOT NULL
	, 	PRIMARY KEY			PK_ProbationAccountMonitor_CTSCustID_SportGroupID(CTSCustID, SportGroupID)
    , 	INDEX				IX_ProbationAccountMonitor_CustID(CustID)
	, 	INDEX				IX_ProbationAccountMonitor_CreatedDate(CreatedDate)
    , 	INDEX				IX_ProbationAccountMonitor_TargetCategoryID(TargetCategoryID)
) ENGINE=INNODB;

DROP TABLE IF EXISTS CTS_DataCenter.ProbationAccountNotification;
CREATE TABLE IF NOT EXISTS CTS_DataCenter.ProbationAccountNotification (
		NotificationID			BIGINT UNSIGNED AUTO_INCREMENT
	,	NotificationType		TINYINT NOT NULL # 1: margin < 0; 2: jump level failed after probation duration
	, 	TotalScanned			SMALLINT UNSIGNED NOT NULL DEFAULT 0
    , 	TotalFailed				SMALLINT UNSIGNED NOT NULL DEFAULT 0
    , 	TotalGeneralFailed		SMALLINT UNSIGNED NOT NULL DEFAULT 0
    , 	CreatedDate				DATE NOT NULL
    , 	CreatedTime				DATETIME NOT NULL
	, 	PRIMARY KEY				PK_ProbationAccountNotification_NotificationID(NotificationID)
    ,	INDEX					IX_ProbationAccountNotification_CreatedDate(CreatedDate)
    ,	INDEX					IX_ProbationAccountNotification_NotificationType(NotificationType)
) ENGINE=INNODB DEFAULT CHARSET='UTF8MB4' COLLATE='UTF8MB4_UNICODE_CI';

ALTER TABLE CTS_DataCenter.CTSUserPermission
ADD COLUMN FunctionID SMALLINT UNSIGNED NOT NULL; # 1: Associated Account Monitor, 2: Probation Account
ALTER TABLE CTS_DataCenter.CTSUserPermission
ADD COLUMN IsTurnedOnNotification BOOLEAN DEFAULT 1; 
ALTER TABLE CTS_DataCenter.CTSUserPermission 
ADD INDEX IX_ProbationAccountNotification_FunctionID(FunctionID DESC);
UPDATE CTS_DataCenter.CTSUserPermission
SET FunctionID = 1, IsTurnedOnNotification = 1;

ALTER TABLE CTS_DataCenter.CTSUserNotificationParameter
ADD COLUMN FunctionID SMALLINT UNSIGNED NOT NULL; # 1: Associated Account Monitor, 2: Probation Account
UPDATE CTS_DataCenter.CTSUserNotificationParameter
SET FunctionID = 1;
ALTER TABLE CTS_DataCenter.CTSUserNotificationParameter DROP PRIMARY KEY;
ALTER TABLE CTS_DataCenter.CTSUserNotificationParameter
ADD PRIMARY KEY(UserID,FunctionID);

ALTER TABLE CTS_DataCenter.CTSUserNotificationParameter
ADD COLUMN FromNotificationID BIGINT UNSIGNED;
ALTER TABLE CTS_DataCenter.CTSUserNotificationParameter
ADD COLUMN ToNotificationID BIGINT UNSIGNED;
SET SQL_SAFE_UPDATES = 0;
UPDATE CTS_DataCenter.CTSUserNotificationParameter
SET FromNotificationID = FromID, ToNotificationID = ToID;
ALTER TABLE CTS_DataCenter.CTSUserNotificationParameter
DROP COLUMN FromID;
ALTER TABLE CTS_DataCenter.CTSUserNotificationParameter
DROP COLUMN ToID;

CREATE TABLE IF NOT EXISTS CTS_DataCenter.AssociatedAccountNotification (
		AccountNewAssID			BIGINT UNSIGNED AUTO_INCREMENT
    ,	CTSCustID				INT UNSIGNED NOT NULL
	,	UserName				VARCHAR(50) NOT NULL
	, 	NewAssCount				SMALLINT UNSIGNED NOT NULL DEFAULT 0
    , 	CreatedDate				DATE NOT NULL
    , 	CreatedTime				DATETIME NOT NULL
	, 	PRIMARY KEY				PK_AssociatedAccountNotification_AccountNewAssID(AccountNewAssID)
    ,	INDEX					IX_AssociatedAccountNotification_CTSCustID(CTSCustID)
    ,	INDEX					IX_AssociatedAccountNotification_CreatedDate(CreatedDate)
) ENGINE=INNODB DEFAULT CHARSET='UTF8MB4' COLLATE='UTF8MB4_UNICODE_CI';
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;
INSERT INTO AssociatedAccountNotification(AccountNewAssID, CTSCustID, UserName, NewAssCount, CreatedDate, CreatedTime)
SELECT AccountNewAssID, CTSCustID, UserName, NewAssCount, CreatedDate, CreatedTime
FROM  CTS_DataCenter.AssociatedAccountNewAssociation;
DROP TABLE IF EXISTS CTS_DataCenter.AssociatedAccountNewAssociation;

ALTER TABLE CTS_DataCenter.ProbationAccountMonitor DROP PRIMARY KEY;
ALTER TABLE CTS_DataCenter.ProbationAccountMonitor
ADD PRIMARY KEY(CustID,SportGroupID);

#[20201006@Long.Luu][142414]: Notification Settings
DROP TABLE IF EXISTS CTS_DataCenter.NotificationSettings;
CREATE TABLE IF NOT EXISTS CTS_DataCenter.NotificationSettings (
		UserID					INT UNSIGNED NOT NULL
	,	FunctionID 				SMALLINT UNSIGNED NOT NULL # 1: Associated Account Monitor, 2: Probation Account
	,	FunctionName			VARCHAR(50)
    ,	GrantedFrom				DATETIME DEFAULT NULL
    ,	GrantedTo				DATETIME DEFAULT NULL
	, 	CreatedDate				DATETIME DEFAULT NULL
    , 	LastModifiedDate		DATETIME DEFAULT NULL
	,	INDEX					IX_NotificationSettings(UserID, FunctionID)
) ENGINE=INNODB;

#init data
INSERT INTO NotificationSettings(UserID, FunctionID, FunctionName, GrantedFrom, CreatedDate)
SELECT p.UserID, p.FunctionID, p.FunctionName, p.GrantedFrom, p.CreatedDate
FROM CTS_DataCenter.CTSUserPermission AS p
WHERE p.GrantedTo IS NULL;

# [20201012@Long.Luu][141756]: Sync Evidence to CTS Category
DROP TABLE IF EXISTS CTS_DataCenter.EvidenceToCategory;
CREATE TABLE IF NOT EXISTS CTS_DataCenter.EvidenceToCategory (
		EvidenceID			SMALLINT UNSIGNED AUTO_INCREMENT
	,	CategoryID			SMALLINT UNSIGNED
	, 	PRIMARY KEY			PK_EvidenceToCategory_EvidenceIDCategoryID(EvidenceID,CategoryID)
    ,	INDEX				IX_EvidenceToCategory_CategoryID(CategoryID)
) ENGINE=INNODB;

INSERT INTO CTS_DataCenter.EvidenceToCategory(EvidenceID,CategoryID)
SELECT EvidenceID, 72 FROM CTS_DataCenter.Evidence WHERE EvidenceCode IN ('6.1','6.11','6.21');

INSERT INTO CTS_DataCenter.EvidenceToCategory(EvidenceID,CategoryID)
SELECT EvidenceID, 73 FROM CTS_DataCenter.Evidence WHERE EvidenceCode IN ('6.4','6.14','6.24');

INSERT INTO CTS_DataCenter.EvidenceToCategory(EvidenceID,CategoryID)
SELECT EvidenceID, 74 FROM CTS_DataCenter.Evidence WHERE EvidenceCode IN ('6.3','6.13','6.23');

INSERT INTO CTS_DataCenter.EvidenceToCategory(EvidenceID,CategoryID)
SELECT EvidenceID, 75 FROM CTS_DataCenter.Evidence WHERE EvidenceCode IN ('6.2','6.12','6.22');

INSERT INTO CTS_DataCenter.EvidenceToCategory(EvidenceID,CategoryID)
SELECT EvidenceID, 76 FROM CTS_DataCenter.Evidence WHERE EvidenceCode IN ('6.17','6.27');

INSERT INTO CTS_DataCenter.EvidenceToCategory(EvidenceID,CategoryID)
SELECT EvidenceID, 78 FROM CTS_DataCenter.Evidence WHERE EvidenceCode IN ('6.5','6.15','6.25');

INSERT INTO CTS_DataCenter.EvidenceToCategory(EvidenceID,CategoryID)
SELECT EvidenceID, 79 FROM CTS_DataCenter.Evidence WHERE EvidenceCode IN ('6.6','6.16','6.26');

INSERT INTO CTS_DataCenter.EvidenceToCategory(EvidenceID,CategoryID)
SELECT EvidenceID, 80 FROM CTS_DataCenter.Evidence WHERE EvidenceCode IN ('6.18','6.28');

INSERT INTO CTS_DataCenter.CustomerCategory(CategoryID, CategoryName, CategorySpec, ParentID, DisplayOrder, IsActive, CreatedDate, IsUsedManually)
VALUES (60, 'Bonus Hunter', 'Bonus Hunter', 50, 255, 1, CURRENT_TIME(),0);

INSERT INTO CTS_DataCenter.CustomerCategory(CategoryID, CategoryName, CategorySpec, ParentID, DisplayOrder, IsActive, CreatedDate, IsUsedManually)
SELECT 	CategoryID + 20
	,	CONCAT(CategoryName, ' (Evidence)')
    ,	CONCAT(CategorySpec, ' (Evidence)')
    ,	ParentID
    ,	DisplayOrder
    ,	1
    ,	CURRENT_TIMESTAMP()
    ,	0
FROM CTS_DataCenter.CustomerCategory
WHERE CategoryID IN (52,53,54,55,56,58,59,60);

INSERT INTO CTS_DataCenter.SystemParameter(ParameterID,ParameterName,ParameterDesc,ParameterDataType,ParameterValue)
VALUES(6,'IsTurnedOnEvidenceSyncToCategory', 'Is Turned On Evidence Sync To Category', 'BOOLEAN', '1');

# [20201016@Irena.Vo][145028]: Add LastScannedDate column
ALTER TABLE CTS_DataCenter.ProbationAccountMonitor
ADD COLUMN LastScannedDate DATE,
ADD INDEX IX_ProbationAccountMonitor_LastScannedDate(LastScannedDate);

# [20201106@Adam.Tran][141563]: Import Customer Evidences
DROP TABLE IF EXISTS CTS_DataCenter.CustEvidenceFromFile;
CREATE TABLE IF NOT EXISTS CTS_DataCenter.CustEvidenceFromFile(
		ID					BIGINT UNSIGNED NOT NULL AUTO_INCREMENT
	,	CTSCustID			INT UNSIGNED NOT NULL
	,	CustID				INT UNSIGNED NOT NULL
	,	SubscriberID		INT UNSIGNED NOT NULL
	,	EvidenceID			SMALLINT UNSIGNED NOT NULL
	,	Remark 				VARCHAR(500) 
	,	IsOverwrite			BIT
	,	FileKey				VARCHAR(50) NOT NULL
	,	FileName			VARCHAR (200)
	,	IsProcessed			BIT	DEFAULT 0	
	,	CreatedBy			INT	NOT NULL
	, 	CreatedTime			TIMESTAMP(4) NOT NULL
	,	LastModifiedBy		INT	UNSIGNED
	, 	LastModifiedTime	DATETIME	
    ,	PRIMARY KEY			PK_CustEvidenceFromFile_ID(ID)
	,	INDEX 		 		IX_CustEvidenceFromFile_IsProcessed(IsProcessed)
	,	INDEX 		 		IX_CustEvidenceFromFile_CreatedTime(CreatedTime)
) ENGINE=INNODB DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci;
