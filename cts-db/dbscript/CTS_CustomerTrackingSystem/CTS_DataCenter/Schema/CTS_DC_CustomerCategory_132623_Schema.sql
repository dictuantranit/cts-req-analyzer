/*
Creator: 20200423@Long.Luu
Task:	 	Customer Category
Server:  	Slave
DBName:		CTS_DataCenter

Revisions: 
		- 20200423@Long.Luu: Created [#132623]
Reviewer:
*/

CREATE TABLE IF NOT EXISTS CTS_DataCenter.SportGroup (
		SportGroupID		SMALLINT UNSIGNED AUTO_INCREMENT
	, 	SportGroupName		VARCHAR(50) CHARACTER SET 'UTF8MB4' COLLATE 'UTF8MB4_UNICODE_CI'
    ,	MainDBSportID		SMALLINT UNSIGNED
	, 	DisplayOrder		TINYINT UNSIGNED
    ,	IsActive			BIT DEFAULT 1
	, 	CreatedDate			DATETIME
    ,	CreatedBy			INT UNSIGNED
	, 	PRIMARY KEY		PK_SportGroup_SportGroupIDDisplayOrder(SportGroupID,DisplayOrder)
	, 	INDEX			IX_SportGroup_MainDBSportID(MainDBSportID)
    , 	INDEX			IX_SportGroup_IsActive(IsActive)
) ENGINE=INNODB AUTO_INCREMENT=1;

CREATE TABLE IF NOT EXISTS CTS_DataCenter.CustomerCategory (
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
	, 	PRIMARY KEY			PK_CustomerCategory_CategoryIDDisplayOrder(CategoryID,DisplayOrder)
	, 	INDEX				IX_CustomerCategory_ParentID(ParentID)
    , 	INDEX				IX_CustomerCategory_IsActive(IsActive)
) ENGINE=INNODB AUTO_INCREMENT=1;

CREATE TABLE IF NOT EXISTS CTS_DataCenter.CTSCustomerClassification (
		CTSCustID			BIGINT UNSIGNED
	, 	SubscriberID		INT	UNSIGNED
	, 	CategoryID			SMALLINT UNSIGNED
    ,	SportGroupID		SMALLINT UNSIGNED
	, 	Remark				VARCHAR(500) CHARACTER SET 'UTF8MB4' COLLATE 'UTF8MB4_UNICODE_CI'
	, 	CreatedDate			DATETIME
    ,	CreatedBy			INT -- > 0 for normal user, 0 for auto, and may be negative for other sources in the future
    , 	LastModifiedDate	DATETIME
    ,	LastModifiedBy		INT UNSIGNED
	, 	PRIMARY KEY			PK_CTSCustomerClassification_CTSCustID(CTSCustID,CategoryID,SportGroupID)
	, 	INDEX				IX_CTSCustomerClassification_SubscriberID(SubscriberID)
) ENGINE=INNODB;

