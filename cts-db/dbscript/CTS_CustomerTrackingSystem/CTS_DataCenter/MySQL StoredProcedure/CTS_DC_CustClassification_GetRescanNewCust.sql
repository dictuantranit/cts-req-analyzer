/*<info serverAlias="CTSMain-CTS_DataCenter" databaseType="2" executers="ctsService,ctsWeb" isFunction="0" isNested="0"></info>*/
DROP PROCEDURE IF EXISTS `CTS_DC_CustClassification_GetRescanNewCust`;

DELIMITER $$
CREATE DEFINER=`ctsOwner`@`%` PROCEDURE `CTS_DC_CustClassification_GetRescanNewCust`(
	OUT op_LastCTSCustID 	BIGINT UNSIGNED
)
    SQL SECURITY INVOKER
sp: BEGIN
	/*
		Created:	20220520@Aries.Nguyen
		Task :		Renovate PA Process
		DB:			CTS_DataCenter
		Original: 
		Revisions: 
			- 20220520@Aries.Nguyen: Created [Redmine ID: #172561]
            - 20220614@Aries.Nguyen: CTS - Classify Category for new Customer (all roles) is not Latest [Redmine ID: #174084]
            - 20220616@Aries.Nguyen: Cannot mark PA (affected by uplines) correctly with First Mark [Redmine ID: #174136]
            - 20220628@Aries.Nguyen: Update robot classification rule [Redmine ID: #174430]
			- 202208018@Long.Luu: Use IsDangerProbation in stead of IsPAProbation [Redmine ID: #174219]
            - 20230515@Casey.Huynh:	New Category for Robot OCRD [Redmine ID: #186991]
            - 20240626@Thomas.Nguyen: Renovate CC phase 2 - Remove hardcode CategoryGroup, ParentID [Redmine ID: #205317]
            - 20240923@Jonas.Huynh:	Change CC Priority of Robot- Potential Risk  [RedmineID: #209792]
            - 20241014@Casey.Huynh: Get rescan new cust [Redmine ID: #185799]
			      - 20241216@Tony.Nguyen: Remove UNSIGNED of SMA Recommend & Modify DirectUpLineCustID, DirectUpLineRoleId (Redmine ID: #214585)

        Param's Explanation:

		Example:
			- CALL CTS_DataCenter.CTS_DC_CustClassification_GetRescanNewCust(@op_LastCTSCustID);SELECT @op_LastCTSCustID;
	*/
  DECLARE CONST_CATEID_VVIP				          INT;
  DECLARE CONST_AGENCY_PARENTID_VVIP			  INT;
  DECLARE CONST_AGENCY_PARENTID_PA				  INT;
  DECLARE CONST_AGENCY_CATEGROUPID_ROBOT    INT;

  DECLARE lv_LastCTSCustID 	                    BIGINT UNSIGNED;
  DECLARE lv_BatchSize 		                      INT UNSIGNED;
  DECLARE lv_MaxCTSCustID 	                    BIGINT UNSIGNED;

  DECLARE CONST_ROLEID_MEMBER				        TINYINT DEFAULT 1;
  DECLARE CONST_ROLEID_AGENT            		TINYINT DEFAULT 2;
  DECLARE CONST_ROLEID_MASTER            		TINYINT DEFAULT 3;
  DECLARE CONST_ROLEID_SUPER            		TINYINT DEFAULT 4;

  DECLARE CONST_DIRECT_MEMBER_MASTER           INT  DEFAULT -3;
  DECLARE CONST_DIRECT_MEMBER_SUPER            INT  DEFAULT -4;
    
  SET CONST_CATEID_VVIP				                  = CTS_DC_CategoryTypeParent_Get ('CONST_CATEID_VVIP');  
  SET CONST_AGENCY_PARENTID_VVIP				        = CTS_DC_CategoryTypeParent_Get ('CONST_AGENCY_PARENTID_VVIP');
  SET CONST_AGENCY_PARENTID_PA				          = CTS_DC_CategoryTypeParent_Get ('CONST_AGENCY_PARENTID_PA');
  SET CONST_AGENCY_CATEGROUPID_ROBOT			      = CTS_DC_CategoryTypeParent_Get ('CONST_AGENCY_CATEGROUPID_ROBOT');

DROP TEMPORARY TABLE IF EXISTS Temp_CustInfo;
CREATE TEMPORARY TABLE Temp_CustInfo(
    CTSCustID			      BIGINT UNSIGNED PRIMARY KEY
  ,	CustID				      BIGINT UNSIGNED
  ,	CustSubID			      INT	UNSIGNED
  ,	UserName			      VARCHAR(50) 
  ,	RegisterName		    VARCHAR(50) 
  ,	SubscriberID		    INT UNSIGNED
  ,	RoleID				      INT        
  ,	SRecommend			    BIGINT UNSIGNED
  ,	MRecommend			    BIGINT
  ,	Recommend			      BIGINT
  ,	DirectUpLineCustID	BIGINT UNSIGNED
  ,	DirectUpLineRoleID	BIGINT UNSIGNED
  ,	IsLicensee			    BIT       
  ,	CreatedBy			      INT
  ,	INDEX PK_Temp_CustInfo_CustID(CustID)
  ,	INDEX IX_Temp_CustInfo_DirectUpLineCustID(DirectUpLineCustID)
);

  DROP TEMPORARY TABLE IF EXISTS Temp_VVIPCust;
  CREATE TEMPORARY TABLE Temp_VVIPCust(
    CTSCustID		BIGINT UNSIGNED PRIMARY KEY 
  ,	CustID			BIGINT UNSIGNED
  ,	RoleID			TINYINT
  ,	CreatedBy		INT   
  ,	INDEX PK_Temp_VVIPCust_CustID(CustID)
  ); 
  
  DROP TEMPORARY TABLE IF EXISTS Temp_VVIPCust_Depth;
  CREATE TEMPORARY TABLE Temp_VVIPCust_Depth(
    CTSCustID 	BIGINT UNSIGNED PRIMARY KEY 
  ,	CustID		  BIGINT UNSIGNED
  ,	RoleID		  TINYINT
  ,	CreatedBy	  INT
  ); 
  
  DROP TEMPORARY TABLE IF EXISTS Temp_CustCategory;    
  CREATE TEMPORARY TABLE Temp_CustCategory(	  
    CTSCustID				      BIGINT UNSIGNED 
  ,	CustID					      BIGINT UNSIGNED 
  ,	RoleID					      TINYINT
  ,	CategoryID				    INT
  ,	CategoryGroupID			  INT
  ,	UplineRoleID			    INT
  ,	UplineCategoryID		  INT
  ,	UplineCategoryGroupID	INT
  ,	Remark			    	    VARCHAR(500)
  ,	IsFromTVS		    	    BIT
  ,	IsFromTW		    	    BIT
  ,	IsFromCTS		    	    BIT
  ,	CreatedBy		    	    INT
  ,	LastModifiedDate		  DATETIME
  ,	FromRoleID				    TINYINT
  ,	FromCategoryID			  INT   
  ,	PRIMARY KEY(CustID, FromCategoryID)
  );
  
  SELECT ParameterValue 
  INTO lv_LastCTSCustID 
  FROM CTS_DataCenter.SystemParameter 
  WHERE ParameterID = 92;
  
  SELECT ParameterValue 
  INTO lv_BatchSize 
  FROM CTS_DataCenter.SystemParameter 
  WHERE ParameterID = 93; 

  INSERT INTO Temp_CustInfo(CTSCustID, CustID, CustSubID, UserName, RegisterName, SubscriberID, RoleID, SRecommend, MRecommend, Recommend, DirectUpLineCustID,DirectUpLineRoleID,IsLicensee)
  SELECT  cus.CTSCustID
      ,   cus.CustID
      ,   cus.CustSubID
      ,   cus.UserName
      ,   cus.RegisterName
      ,   cus.SubscriberID
      ,   cus.RoleID
      ,   cus.SRecommend
      ,   cus.MRecommend
      ,   cus.Recommend
      ,   ( CASE	WHEN cus.RoleID = CONST_ROLEID_MEMBER
                  THEN (
                        CASE
                          WHEN cus.Recommend = CONST_DIRECT_MEMBER_MASTER  THEN cus.MRecommend
                          WHEN cus.Recommend = CONST_DIRECT_MEMBER_SUPER   THEN cus.SRecommend
                          ELSE cus.Recommend
                        END)
                  WHEN cus.RoleID = CONST_ROLEID_AGENT
                    THEN cus.MRecommend
                  WHEN cus.RoleID = CONST_ROLEID_MASTER
                    THEN cus.SRecommend
            END) AS DirectUpLineCustID  
      ,   ( CASE	WHEN cus.RoleID = CONST_ROLEID_MEMBER
                  THEN (
                        CASE
                          WHEN cus.Recommend = CONST_DIRECT_MEMBER_MASTER  THEN CONST_ROLEID_MASTER
                          WHEN cus.Recommend = CONST_DIRECT_MEMBER_SUPER   THEN CONST_ROLEID_SUPER
                          ELSE CONST_ROLEID_AGENT
                        END)
                  WHEN cus.RoleID = CONST_ROLEID_AGENT
                    THEN CONST_ROLEID_MASTER
                  WHEN cus.RoleID = CONST_ROLEID_MASTER
                    THEN CONST_ROLEID_SUPER
            END) AS DirectUpLineCustIDRoleID  
      ,   cus.IsLicensee
  FROM CTS_DataCenter.CTSCustomer AS cus 
  WHERE cus.CustSubID = 0
        AND cus.IsInternal = 0
        AND cus.CTSCustID > lv_LastCTSCustID
  LIMIT lv_BatchSize;

  SELECT MAX(CTSCustID)
  INTO op_LastCTSCustID
  FROM Temp_CustInfo;
  
  IF op_LastCTSCustID IS NULL THEN
  SET op_LastCTSCustID = lv_LastCTSCustID;
  END IF;
  
  INSERT IGNORE INTO Temp_VVIPCust(CTSCustID,CustID,CreatedBy)
  SELECT  tmp.CTSCustID
      ,   tmp.CustID
      ,   vip.CreatedBy
  FROM Temp_CustInfo AS tmp		
  INNER JOIN CTS_DataCenter.CTSCustomerClassificationAgency AS vip ON vip.CustID = tmp.DirectUpLineCustID 
                    AND vip.IsAffectToDownline = 1 AND vip.ParentID = CONST_AGENCY_PARENTID_VVIP;
  
  INSERT IGNORE INTO Temp_VVIPCust(CTSCustID,CustID,RoleID,CreatedBy)
  SELECT 	tmp.CTSCustID
        , tmp.CustID
        ,	tmp.RoleID
        , que.CreatedBy
  FROM Temp_CustInfo AS tmp		
  INNER JOIN CTS_DataCenter.CTSCustomerClassificationQueue AS que ON que.CustID IN (tmp.SRecommend, tmp.MRecommend, tmp.Recommend) 
              AND que.ActionType = 1;  # ActiontType 1:Mark VVIP, 2:Unmark VVIP, 3: mark PA, 4:unmark PA
  
  INSERT IGNORE INTO Temp_VVIPCust_Depth(CTSCustID, CustID, RoleID, CreatedBy)
  SELECT 	tmp.CTSCustID
        ,	tmp.CustID
        ,	tmp.RoleID 
        , vv.CreatedBy
  FROM Temp_CustInfo AS tmp		
  INNER JOIN Temp_VVIPCust AS vv ON vv.CustID IN (tmp.SRecommend, tmp.MRecommend, tmp.Recommend);

  INSERT IGNORE INTO Temp_VVIPCust(CTSCustID,CustID,RoleID,CreatedBy)
  SELECT 	tmp.CTSCustID
        , tmp.CustID
        ,	tmp.RoleID
        , tmp.CreatedBy
  FROM Temp_VVIPCust_Depth AS tmp;

  INSERT IGNORE INTO Temp_CustCategory(CTSCustID, CustID, RoleID, Remark, CreatedBy,IsFromTW,IsFromCTS,LastModifiedDate, FromRoleID, FromCategoryID)
  SELECT 	tmp.CTSCustID
        , tmp.CustID
        ,	tmp.RoleID
        ,	class.Remark 
        ,	class.CreatedBy
        ,	class.IsFromTW
        ,	class.IsFromCTS
        ,	class.LastModifiedDate
        ,	( CASE  WHEN class.CustID = tmp.Recommend   THEN CONST_ROLEID_AGENT
                  WHEN class.CustID = tmp.MRecommend  THEN CONST_ROLEID_MASTER
                  WHEN class.CustID = tmp.SRecommend  THEN CONST_ROLEID_SUPER
            END) AS FromRoleID
        ,	class.CategoryID AS FromCategoryID        
  FROM Temp_CustInfo AS tmp    
      STRAIGHT_JOIN CTS_DataCenter.CTSCustomerClassificationAgency AS class USE INDEX (PRIMARY) ON class.CustID IN (tmp.SRecommend,tmp.MRecommend,tmp.Recommend) 
          AND class.CustID <> tmp.CustID 
          AND class.ParentID = CONST_AGENCY_PARENTID_PA 
      STRAIGHT_JOIN CTS_DataCenter.CustomerCategoryAgency AS cate ON cate.CategoryID = class.CategoryID AND cate.CategoryGroupID NOT IN (CONST_AGENCY_CATEGROUPID_ROBOT)
  WHERE NOT EXISTS (SELECT 1 FROM CTS_DataCenter.CTSCustomerClassificationAgency AS cls WHERE cls.CustID = class.CustID AND cls.ParentID = CONST_AGENCY_PARENTID_VVIP);

UPDATE Temp_CustCategory AS tmp
  INNER JOIN CTS_DataCenter.CustomerCategoryDownlineMapping AS ccd ON ccd.FromRoleID <= tmp.FromRoleID AND ccd.FromCategoryID = tmp.FromCategoryID AND ccd.ToRoleID = tmp.RoleID
  LEFT JOIN CTS_DataCenter.CustomerCategory AS cate1 ON cate1.CategoryID = ccd.ToCategoryID AND tmp.RoleID = CONST_ROLEID_MEMBER
  LEFT JOIN CTS_DataCenter.CustomerCategoryAgency AS cate2 ON cate2.CategoryID = ccd.ToCategoryID AND tmp.RoleID IN (CONST_ROLEID_AGENT,CONST_ROLEID_MASTER,CONST_ROLEID_SUPER)
SET tmp.CategoryID = IFNULL(cate1.CategoryID,cate2.CategoryID)
  , tmp.CategoryGroupID = IFNULL(cate1.CategoryGroupID,cate2.CategoryGroupID);

UPDATE Temp_CustCategory AS tmp
  INNER JOIN CTS_DataCenter.CustomerCategoryAgency AS cate ON cate.CategoryID = tmp.FromCategoryID
SET tmp.CategoryID = cate.CategoryID
  , tmp.CategoryGroupID = cate.CategoryGroupID
WHERE tmp.CategoryID IS NULL;
      
SELECT	tmp.CTSCustID
    ,	tmp.CustID          
    ,	tmp.CustSubID  
    ,	tmp.UserName  
    ,	tmp.RegisterName  
    ,	tmp.RoleID  
    ,	tmp.SubscriberID
    , 	CASE WHEN tmp.RoleID = CONST_ROLEID_MEMBER THEN CONST_CATEID_VVIP ELSE catA.CategoryID END AS CategoryID  
    ,	vip.CreatedBy          
FROM Temp_CustInfo AS tmp
  INNER JOIN Temp_VVIPCust AS vip ON tmp.CTSCustID = vip.CTSCustID
  LEFT JOIN CTS_DataCenter.CustomerCategoryAgency AS catA ON catA.ParentID = CONST_AGENCY_PARENTID_VVIP AND catA.RoleID = tmp.RoleID;
  
SELECT 	cate.CTSCustID		
    , cate.CustID	
    , tmp.RoleID
    , tmp.SubscriberID
    , tmp.IsLicensee 
    , cate.CategoryID		
    ,	cate.CategoryGroupID
    , cate.Remark		
    ,	cate.CreatedBy
    ,	cate.IsFromTVS
    ,	cate.IsFromTW
    ,	cate.IsFromCTS
    , cate.LastModifiedDate
    , 0 AS IsMarkedDirectly
FROM Temp_CustCategory AS cate
    LEFT JOIN Temp_CustInfo AS tmp ON tmp.CustID = cate.CustID
WHERE NOT EXISTS (SELECT 1 FROM Temp_VVIPCust AS vv WHERE cate.CTSCustID = vv.CTSCustID); 

SELECT 	tmp.CTSCustID		
      , tmp.CustID
      ,	tmp.RoleID
FROM Temp_CustInfo AS tmp
WHERE NOT EXISTS (SELECT 1 FROM Temp_VVIPCust AS vv WHERE tmp.CTSCustID = vv.CTSCustID)
AND NOT EXISTS (SELECT 1 FROM Temp_CustCategory AS cate WHERE cate.CustID = tmp.CustID);

END$$
DELIMITER ;
