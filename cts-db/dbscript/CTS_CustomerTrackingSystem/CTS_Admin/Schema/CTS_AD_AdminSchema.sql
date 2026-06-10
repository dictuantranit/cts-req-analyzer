/*
Creator: 20190521@John
Task:	 FPS Reform [Redmine ID: 105252]
Server:  
DBName:	CTS_Admin

Revisions: 
			- 20190521@CaseyHuynh: SubscriberPrefix HotFix, Update Subscriber Schema. Not allow SubscriberPrefix NULL [146563]
Reviewer:
*/

CREATE DATABASE IF NOT EXISTS CTS_Admin;

CREATE TABLE CTS_Admin.Subscriber (
		SubscriberID		INT				NOT NULL	AUTO_INCREMENT
	,	SubscriberName		VARCHAR(50) 	NOT NULL
	,	SubscriberPrefix	VARCHAR(30) 	NULL    
    , 	SubscriberType		TINYINT	UNSIGNED	NULL	COMMENT' 0: Credit, 1: Deposit, 2: SUB not have Customer in MainDB (ex: CTMAX, AGENTCTMAX)'
	,	SubscriberStatus	TINYINT	NOT NULL			COMMENT '0: Inactive; 1: Active'
    ,	CreatedDate			DATETIME	 	NULL
	,	CreatedBy			INT 			NULL	
	,	IsTest				TINYINT			NULL
    , 	DCSStatus			BOOLEAN			NULL		COMMENT '0: Inactive; 1: Active; -1: Unhandle (sub that not integrate, is insert new from transaction)'
    ,	DCSIntegrationDate	DATETIME		NULL		
	,	TerminatedDate 		DATETIME		DEFAULT NULL
	,	PRIMARY KEY	PK_Subscriber_SubscriberID (SubscriberID)
	,	UNIQUE KEY	IX_Subscriber_SubscriberName_SubScriberPrefix (SubscriberName,SubScriberPrefix)
	,	INDEX		IX_Subscriber_SubscriberPrefix(SubscriberPrefix)
	
) ENGINE=InnoDB AUTO_INCREMENT=1;

CREATE TABLE CTS_Admin.UserSubscriber (
		UserID				INT 		NOT NULL
	,	SubscriberID		INT			NOT NULL
	,	CreatedDate			DATETIME	NULL
	,	CreatedBy			INT			NULL
	,	PRIMARY KEY	PK_UserSubscriber_UserID_SubscriberID (UserID,SubscriberID)
) ENGINE=InnoDB;

CREATE TABLE CTS_Admin.LogType (
		LogTypeID			SMALLINT 						NOT NULL	AUTO_INCREMENT
	,	LogTypeName			VARCHAR(50) 					NOT NULL
	,	LogTypeDescription	VARCHAR(200) CHARACTER SET 'UTF8MB4' COLLATE 'UTF8MB4_UNICODE_CI' 	NULL 	COMMENT 'NVARCHAR'
	,	PRIMARY KEY	PK_LogType_LogTypeID (LogTypeID)
) ENGINE=InnoDB AUTO_INCREMENT=1;

CREATE TABLE CTS_Admin.UserLog (
		LogTypeID			SMALLINT 						NOT NULL
	,	SPName				VARCHAR(100)					NULL
	,	LogInfo				VARCHAR(500) CHARACTER SET 'UTF8MB4' COLLATE 'UTF8MB4_UNICODE_CI'	NULL COMMENT 'NVARCHAR'
	,	CreatedDate			DATETIME	 NULL
	,	CreatedBy			INT NULL
) ENGINE=InnoDB;

CREATE TABLE CTS_Admin.CTSUser (
		UserID				INT 		NOT NULL
	,	UserName			VARCHAR(50) CHARACTER SET 'UTF8MB4' COLLATE 'UTF8MB4_UNICODE_CI' NOT NULL
	,	CreatedDate			DATETIME	NULL
    ,	IsMaster			BOOL
	,	PRIMARY KEY	PK_CTSUser_UserID (UserID)
) ENGINE=InnoDB;

/*146563-SubscriberPrefix Hot Fix, Update Subscriber Schema. Not allow SubscriberPrefix NULL*/
ALTER TABLE 	CTS_DataCenter.Subscriber
MODIFY COLUMN 	SubscriberPrefix VARCHAR(30) NOT NULL;
