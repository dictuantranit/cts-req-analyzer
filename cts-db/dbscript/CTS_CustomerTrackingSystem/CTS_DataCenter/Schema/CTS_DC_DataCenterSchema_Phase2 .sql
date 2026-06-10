/*
Creator: 20191217@CaseyHuynh
Task:	 	CTS_Schema
Server:  	Slave
DBName:		CTS_DataCenter

Revisions: 
	#1. [20191217@CaseyHuynh][#125530]: Add LastLoginDate column to table CTSCustomer.
    #2. [20191217@CaseyHuynh][#125534]: Create StaticList table
    #3. [20191217@Harvey.Nguyen][#125530]: Add CreatedDate column to table CTSCustomer
    #4. [20191220@CaseyHuynh][#125844]: Inplement Mapping Subscriber and Site
    
Reviewer:
	#1. Harvey: 
*/
/* ==========================PHASE 2===================================*/

ALTER TABLE		CTS_DataCenter.CTSCustomer
ADD COLUMN		LastLoginTime	TIMESTAMP(4);

ALTER TABLE		CTS_DataCenter.CTSCustomer
ADD COLUMN		CreatedDate		DATETIME;

ALTER TABLE		CTS_DataCenter.CTSCustomer
ADD COLUMN		SiteID		INT;

ALTER TABLE		CTS_DataCenter.CTSCustomer
ADD	FULLTEXT 	IX_FullText_UserName_UserName2 (UserName,UserName2);

ALTER TABLE		CTS_DataCenter.AssociationByDevice
ADD	INDEX		IX_AssociationByDevice_SubscriberID_DeviceID(SubscriberID, DCSDeviceID);

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

#--=========================
CREATE TABLE IF NOT EXISTS CTS_DataCenter.MappingSubscriberSite(
	SiteID				BIGINT	UNSIGNED
	, SiteName			VARCHAR(50)	CHARACTER SET 'UTF8MB4' COLLATE 'UTF8MB4_UNICODE_CI'
	, Type				VARCHAR(30)
	, IsLicensee		BOOL
	, IsDeposit			BOOL
	, SubscriberID		INT
	, SubscriberName	VARCHAR(50)
	, SiteType			TINYINT							COMMENT '1: Deposit, 0:Credit'
	, MappingType		TINYINT							COMMENT '-2:NOT Existing Main but DCS, -1:Existing Main but NOT DCS, 0: mapping SiteName, 1: Mapping SiteName ADN RoleID =1, 2: Mapping SiteName ADN RoleID > 1'
	, Comments			VARCHAR(200)
	, UNIQUE KEY	PK_MappingSubscriberSite_SubscriberID(SiteID, SubscriberID)    
) ENGINE=INNODB;

