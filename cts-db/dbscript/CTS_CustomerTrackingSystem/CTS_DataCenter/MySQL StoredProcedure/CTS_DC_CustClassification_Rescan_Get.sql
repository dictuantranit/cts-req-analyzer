/*<info serverAlias="CTSMain-CTS_DataCenter" databaseType="2" executers="ctsWeb,ctsService,ctsAPI" isFunction="0" isNested="0"></info>*/
DROP procedure IF EXISTS `CTS_DC_CustClassification_Rescan_Get`;

DELIMITER $$
CREATE DEFINER=`ctsOwner`@`%` PROCEDURE `CTS_DC_CustClassification_Rescan_Get`(
		IN ip_CustIDs	LONGTEXT
)
    SQL SECURITY INVOKER
sp: BEGIN
	/*
		Created:	20220520@Aries.Nguyen
		Task :		Renovate PA Process
		DB:			CTS_DataCenter 
		Original: 
		Revisions:  
			- 20220520@Aries.Nguyen: 	Created [Redmine ID: #172561]
            - 20220616@Aries.Nguyen: 	Cannot mark PA (affected by uplines) correctly with First Mark [Redmine ID: #174136]
            - 20220628@Aries.Nguyen: 	Update robot classification rule [Redmine ID: #174430]
			- 20220705@Long.Luu: 		Return IsLicenseeVIP info [Redmine ID: #174219]
            - 20221007@Harvey.Nguyen: 	Change CTSCustomerClassificationOldPA -> CTSCustomerClassificationOldCategory [Redmine ID: #178022]
			- 20230315@Victoria.Le:		Add Robot Imperva [Redmine ID: #184773]
			- 20230404@Victoria.Le		TVS Abnormal Bet and Abnormal Account - Add IsParlay,SportType,IssueTypeId [Redmine ID: #185319] 
			- 20230517@Victoria.Le:		New Category for Robot OCRD [Redmine ID: #186991]
            - 20240103@Thomas.Nguyen:   New Category for System Detect Unauthorized Login [RedmineID: #197710]
			- 20240620@Jonas.Huynh: 	Renovate CC [RedmineID: #205317]
            - 20240923@Jonas.Huynh: 	Change CC Priority of Robot- Potential Risk  [RedmineID: #209792]
            - 20241030@Thomas.Nguyen: 	CC Agent - Change source tables when checking affected PA from Upline [RedmineID: #185799]
			- 20241210@Casey.Huynh:		New Robot AI, Bot Login Pattern [Redmine ID: #214655]
            - 20250909@Thomas.Nguyen:	Rescan for CC 2900/2901 [Redmine ID: #237405]
            - 20250922@Logan.Nguyen:    Adjust Performance Calculation Logic for Initial Smart - CC2700 - Initial Smart (Losing) - CC2701 [Redmine ID: #239118]

        Param's Explanation:

		Example:
			- CALL CTS_DataCenter.CTS_DC_CustClassification_Rescan_Get("1,2,3,4");
	*/ 
    DECLARE	CONST_CATEID_UNAUTHORIZEDLOGIN			INT;
    DECLARE	CONST_CATEID_ROBOTUSER					INT;
    DECLARE	CONST_CATEID_ROBOTOCRD					INT;
    DECLARE	CONST_CATEID_BOTLOGINPATTERN			INT;
    DECLARE	CONST_CATEID_EARLYWARNING				INT;
    DECLARE	CONST_CATEID_INITIALGB					INT;
    DECLARE	CONST_PARENTID_PA						INT;
    DECLARE	CONST_AGENCY_CATEID_ROBOT				INT;
    DECLARE	CONST_AGENCY_CATEID_ROBOTLOSING			INT;
    DECLARE	CONST_AGENCY_PARENTID_PA				INT;
    DECLARE CONST_AGENCY_PARENTID_VVIP				INT;

    DECLARE CONST_INPUTFLOWID_NORMAL				INT DEFAULT 9;
    DECLARE	CONST_INPUTFLOWID_POTENTIALPA			INT DEFAULT 118;
	DECLARE	CONST_INPUTFLOWID_CATEGORY_PA			INT DEFAULT 115;
      
	DECLARE	CONST_TVSREQUESTTYPE_PA					TINYINT DEFAULT 1; 
	DECLARE CONST_CREATEDBY_STARIXITID				INT DEFAULT 10278938;
    DECLARE CONST_ROLEID_MEMBER					    SMALLINT DEFAULT 1;
	DECLARE CONST_ROLEID_AGENT					    SMALLINT DEFAULT 2;
    DECLARE CONST_ROLEID_MASTER					    SMALLINT DEFAULT 3;
    DECLARE CONST_ROLEID_SUPER					    SMALLINT DEFAULT 4;
    
    DECLARE	CONST_PERIODRANGETYPE_OCRD						INT DEFAULT 200;
    DECLARE	CONST_PERIODRANGETYPE_LP_LOGINTIMEPATTERN		INT DEFAULT 400;
    DECLARE	CONST_PERIODRANGETYPE_LP_MASSIVELOGINATTEMPT	INT DEFAULT 420;
    DECLARE	CONST_PERIODRANGETYPE_LP_IPDEVERSITY			INT DEFAULT 430;    
    DECLARE	CONST_PERIODRANGETYPE_LP_DEVICEDEVERSITY		INT DEFAULT 440;

    SET CONST_CATEID_UNAUTHORIZEDLOGIN	 			= CTS_DataCenter.CTS_DC_CategoryTypeParent_Get ('CONST_CATEID_UNAUTHORIZEDLOGIN');
    SET CONST_CATEID_ROBOTUSER	 					= CTS_DataCenter.CTS_DC_CategoryTypeParent_Get ('CONST_CATEID_ROBOTUSER');
    SET CONST_CATEID_ROBOTOCRD	 					= CTS_DataCenter.CTS_DC_CategoryTypeParent_Get ('CONST_CATEID_ROBOTOCRD');
    SET CONST_CATEID_BOTLOGINPATTERN				= CTS_DataCenter.CTS_DC_CategoryTypeParent_Get ('CONST_CATEID_BOTLOGINPATTERN');
    SET CONST_CATEID_EARLYWARNING	 				= CTS_DataCenter.CTS_DC_CategoryTypeParent_Get ('CONST_CATEID_EARLYWARNING');
    SET CONST_CATEID_INITIALGB	 					= CTS_DataCenter.CTS_DC_CategoryTypeParent_Get ('CONST_CATEID_INITIALGB');
    SET CONST_PARENTID_PA 							= CTS_DataCenter.CTS_DC_CategoryTypeParent_Get ('CONST_PARENTID_PA');
    SET CONST_AGENCY_CATEID_ROBOT	 				= CTS_DataCenter.CTS_DC_CategoryTypeParent_Get ('CONST_AGENCY_CATEID_ROBOT');
    SET CONST_AGENCY_CATEID_ROBOTLOSING	 			= CTS_DataCenter.CTS_DC_CategoryTypeParent_Get ('CONST_AGENCY_CATEID_ROBOTLOSING');
    SET CONST_AGENCY_PARENTID_PA 					= CTS_DataCenter.CTS_DC_CategoryTypeParent_Get ('CONST_AGENCY_PARENTID_PA');
    SET CONST_AGENCY_PARENTID_VVIP				    = CTS_DataCenter.CTS_DC_CategoryTypeParent_Get ('CONST_AGENCY_PARENTID_VVIP');
        
    DROP TEMPORARY TABLE IF EXISTS Temp_CustID;    
	CREATE TEMPORARY TABLE Temp_CustID (	  
			CustID          BIGINT UNSIGNED PRIMARY KEY 	
     );
    
    DROP TEMPORARY TABLE IF EXISTS Temp_RobotDetection;
    CREATE TEMPORARY TABLE Temp_RobotDetection(
			CustID 				INT
        ,	CategoryID 			INT
        ,	CreatedDate 		DATETIME(3)
        ,	LastModifiedDate	DATETIME(3)
        ,	ID 					INT
        
		,	PRIMARY KEY (CustID,CategoryID)
	);    
    
	DROP TEMPORARY TABLE IF EXISTS Temp_CustInfo;    
	CREATE TEMPORARY TABLE Temp_CustInfo (	  
			CTSCustID		BIGINT UNSIGNED PRIMARY KEY 
        ,   CustID			BIGINT UNSIGNED 
		,	RoleID 			TINYINT 
		,	SRecommend 		INT  
		,	MRecommend		INT  
		,	Recommend 		INT  
        , 	SubscriberID	INT 
        ,	IsLicensee		BIT 
        ,	IsLicenseeVIP	BIT
     ); 
     
	DROP TEMPORARY TABLE IF EXISTS Temp_PotentialCategory;    
	CREATE TEMPORARY TABLE Temp_PotentialCategory (	  
			CTSCustID				BIGINT UNSIGNED
        ,   CustID					BIGINT UNSIGNED 
        ,	CategoryID              INT  
        ,	TVSReasonID             INT 
        ,	RoleID 					TINYINT 
		, 	SubscriberID			INT UNSIGNED
        ,	IsLicensee				BIT
		,	Remark				    VARCHAR(500)
        ,   CreatedBy               INT UNSIGNED
        ,	IsMarkedDirectly	    BIT        
        ,	IsFromTVS 				BIT DEFAULT 0
        ,	IsFromTW 				BIT DEFAULT 0
        ,	IsFromCTS 				BIT DEFAULT 0
        ,	IsFromAI 				BIT DEFAULT 0
		,	IsFromImperva			BIT DEFAULT 0
        ,   CreatedDate        		DATETIME(3)
        ,   LastModifiedDate        DATETIME(3) 
        ,   SportType               SMALLINT
		,	InputFlowID	 			INT
        ,	CategoryPriority		SMALLINT
		,	PRIMARY KEY(CustID,CategoryID)
	);
    
    DROP TEMPORARY TABLE IF EXISTS Temp_CustCategory;    
	CREATE TEMPORARY TABLE Temp_CustCategory (	  
			CTSCustID				BIGINT UNSIGNED
        ,   CustID					BIGINT UNSIGNED 
        ,	CategoryID              INT  
        ,	TVSReasonID             INT 
        ,	RoleID 					TINYINT 
		, 	SubscriberID			INT UNSIGNED
        ,	IsLicensee				BIT
		,	Remark				    VARCHAR(500)
        ,   CreatedBy               INT UNSIGNED
        ,	IsMarkedDirectly	    BIT        
        ,	IsFromTVS 				BIT DEFAULT 0
        ,	IsFromTW 				BIT DEFAULT 0
        ,	IsFromCTS 				BIT DEFAULT 0
        ,	IsFromAI 				BIT DEFAULT 0
		,	IsFromImperva			BIT DEFAULT 0
        ,   CreatedDate        		DATETIME(3)
        ,   LastModifiedDate        DATETIME(3)
        ,   RobotCounter          	INT
        ,   TVSRequestID            BIGINT UNSIGNED
        ,   IsParlay                TINYINT(1)
        ,   SportType               SMALLINT
        ,   IssueTypeID             TINYINT
		,	InputFlowID	 			INT
		,	PRIMARY KEY(CustID,CategoryID)
	);
        
    SET @sql = 	CONCAT("INSERT IGNORE INTO Temp_CustID (CustID) VALUES ('", REPLACE(ip_CustIDs, ",", "'),('"),"');");
	PREPARE 	stmt1 FROM @sql;
	EXECUTE 	stmt1;    
     
    INSERT  INTO Temp_CustInfo(CTSCustID,CustID,SRecommend,MRecommend,Recommend,RoleID,SubscriberID,IsLicensee)
    SELECT 	cus.CTSCustID
		,	cus.CustID
        ,	CASE WHEN cus.SRecommend = 0 THEN -1 ELSE cus.SRecommend END AS SRecommend
        ,	CASE WHEN cus.MRecommend = 0 THEN -1 ELSE cus.MRecommend END AS MRecommend
        ,	CASE WHEN cus.Recommend = 0 THEN -1 ELSE cus.Recommend END AS Recommend
        ,	cus.RoleID	 
		, 	cus.SubscriberID	 
        ,	cus.IsLicensee	
    FROM Temp_CustID AS tmp
		INNER JOIN CTS_DataCenter.CTSCustomer AS cus ON cus.CustID = tmp.CustID 
			AND cus.CustSubID = 0 
			AND cus.IsInternal = 0;
        
	/***********************Check Robot Imperva****************************/
    INSERT IGNORE INTO Temp_CustCategory(CTSCustID, CustID, CategoryID, TVSReasonID, RoleID, SubscriberID, IsLicensee, Remark, CreatedBy, IsMarkedDirectly, IsFromTVS, IsFromTW, IsFromCTS, IsFromAI, IsFromImperva, CreatedDate, LastModifiedDate, InputFlowID)
    SELECT tmp.CTSCustID					AS CTSCustID	
		,	tmp.CustID						AS CustID
        ,	CONST_CATEID_ROBOTUSER 			AS CategoryID
        , 	NULL 							AS TVSReasonID
        ,	tmp.RoleID 						AS RoleID
        ,	tmp.SubscriberID				AS SubscriberID
		,	tmp.IsLicensee					AS IsLicensee
        ,	NULL 							AS Remark
        ,	NULL 							AS CreatedBy
        ,	1 								AS IsMarkedDirectly
		,	0 								AS IsFromTVS
        ,	0 								AS IsFromTW
        ,   0 								AS IsFromCTS
        ,	0 								AS IsFromAI
        ,	1 								AS IsFromImperva
        ,	s.CreateTime 					AS CreatedDate
        ,	s.LastModifiedDate 				AS LastModifiedDate
        ,   CONST_INPUTFLOWID_CATEGORY_PA	AS InputFlowID
    FROM  Temp_CustInfo AS tmp
		, LATERAL (SELECT CreateTime, LastModifiedDate
					 FROM CTS_DataCenter.RobotImperva
					 WHERE CustID = tmp.CustID 
						AND IsDisabled = 0
					 ORDER BY CreateTime DESC
					 LIMIT 1) AS s;
	
    /***********************Check Robot Betting****************************/

    INSERT IGNORE INTO Temp_RobotDetection(CustID, CategoryID, CreatedDate, LastModifiedDate)
    SELECT	bd.CustID
			, (CASE WHEN bd.PeriodRangeType = CONST_PERIODRANGETYPE_OCRD THEN CONST_CATEID_ROBOTOCRD
					WHEN bd.PeriodRangeType IN (  CONST_PERIODRANGETYPE_LP_LOGINTIMEPATTERN
												, CONST_PERIODRANGETYPE_LP_MASSIVELOGINATTEMPT
                                                , CONST_PERIODRANGETYPE_LP_IPDEVERSITY
                                                , CONST_PERIODRANGETYPE_LP_DEVICEDEVERSITY) THEN CONST_CATEID_BOTLOGINPATTERN
					ELSE CONST_CATEID_ROBOTUSER END) AS CategoryID
			, bd.CreatedDate
            , bd.LastModifiedDate
	FROM Temp_CustInfo AS tmp
		INNER JOIN CTS_DataCenter.RobotDetection AS bd ON bd.CustID = tmp.CustID
	WHERE tmp.RoleID = CONST_ROLEID_MEMBER
		AND bd.IsDisabled = 0
	ORDER BY bd.CustID, bd.CreatedDate DESC;

    INSERT IGNORE INTO Temp_CustCategory(CTSCustID, CustID, CategoryID, TVSReasonID, RoleID, SubscriberID, IsLicensee, Remark, CreatedBy, IsMarkedDirectly, IsFromTVS, IsFromTW, IsFromCTS, IsFromAI, IsFromImperva, CreatedDate, LastModifiedDate, InputFlowID)
    SELECT 	tmp.CTSCustID					AS CTSCustID
		,	tmp.CustID						AS CustID
        ,	s.CategoryID 					AS CategoryID
        , 	NULL 							AS TVSReasonID
        ,	tmp.RoleID 						AS RoleID
        ,	tmp.SubscriberID 				AS SubscriberID
		,	tmp.IsLicensee 					AS IsLicensee
        ,	NULL 							AS Remark
        ,	NULL 							AS CreatedBy
        ,	1								AS IsMarkedDirectly
		,	0 								AS IsFromTVS
        ,	0 								AS IsFromTW
        ,   0 								AS IsFromCTS
        ,	1 								AS IsFromAI
        ,	0 								AS IsFromImperva
        ,	s.CreatedDate 					AS CreatedDate
        ,	s.LastModifiedDate 				AS LastModifiedDate
        ,   CONST_INPUTFLOWID_CATEGORY_PA	AS InputFlowID
    FROM  Temp_CustInfo AS tmp		
		INNER JOIN Temp_RobotDetection AS s ON tmp.CustID = s.CustID;

    /***********************Check CTS RobotUser****************************/
    INSERT IGNORE INTO Temp_CustCategory(CTSCustID, CustID, CategoryID, TVSReasonID, RoleID, SubscriberID, IsLicensee, Remark, CreatedBy, IsMarkedDirectly, IsFromTVS, IsFromTW, IsFromCTS, IsFromAI, IsFromImperva, CreatedDate, LastModifiedDate, InputFlowID)
    SELECT tmp.CTSCustID					AS CTSCustID
		,	tmp.CustID						AS CustID
        ,	CASE WHEN cate.IsPAProbation THEN cate.RelevantCategoryID ELSE s.CategoryID END AS CategoryID
        , 	NULL	 						AS TVSReasonID
        ,	tmp.RoleID 						AS RoleID
        ,	tmp.SubscriberID				AS SubscriberID
		,	tmp.IsLicensee					AS IsLicensee
        ,	s.Remark						AS Remark
        ,	NULL		 					AS CreatedBy
        ,	1 								AS IsMarkedDirectly
		,	0 								AS IsFromTVS
        ,	0 								AS IsFromTW
        ,   1 								AS IsFromCTS
        ,	0 								AS IsFromAI
        ,	0								AS IsFromImperva
        ,	s.CreatedDate 					AS CreatedDate
        ,	s.CreatedDate 					AS LastModifiedDate
        ,   CONST_INPUTFLOWID_CATEGORY_PA	AS InputFlowID
    FROM  Temp_CustInfo AS tmp
		INNER JOIN CTS_DataCenter.CTSRobotUser AS s ON s.CustID = tmp.CustID
        INNER JOIN CTS_DataCenter.CustomerCategory AS cate ON cate.CategoryID = s.CategoryID
	WHERE s.IsDisabled = 0
	ON DUPLICATE KEY UPDATE IsFromCTS = 1
						,	LastModifiedDate = CASE WHEN s.CreatedDate < Temp_CustCategory.LastModifiedDate THEN s.CreatedDate ELSE Temp_CustCategory.LastModifiedDate END
                        ,	CreatedDate = CASE WHEN s.CreatedDate < Temp_CustCategory.CreatedDate THEN s.CreatedDate ELSE Temp_CustCategory.CreatedDate END
                        ,	Remark = CASE WHEN s.CreatedDate < Temp_CustCategory.LastModifiedDate THEN s.Remark ELSE Temp_CustCategory.Remark END;
  
	/***********************Check TWRobotUser****************************/
    INSERT IGNORE INTO Temp_CustCategory(CTSCustID, CustID, CategoryID, TVSReasonID, RoleID, SubscriberID, IsLicensee, Remark, CreatedBy, IsMarkedDirectly, IsFromTVS, IsFromTW, IsFromCTS, IsFromAI, IsFromImperva, CreatedDate, LastModifiedDate, RobotCounter, InputFlowID)
    SELECT tmp.CTSCustID					AS CTSCustID
		,	tmp.CustID						AS CustID
        ,	CASE WHEN cate.IsPAProbation THEN cate.RelevantCategoryID ELSE s.CategoryID END AS CategoryID
        , 	NULL	 						AS TVSReasonID
        ,	tmp.RoleID 						AS RoleID
        ,	tmp.SubscriberID				AS SubscriberID
		,	tmp.IsLicensee					AS IsLicensee
        ,	NULL 							AS Remark
        ,	NULL		 					AS CreatedBy
        ,	1 								AS IsMarkedDirectly
		,	0 								AS IsFromTVS
        ,	1 								AS IsFromTW
        ,   0 								AS IsFromCTS
        ,	0 								AS IsFromAI
        ,	0								AS IsFromImperva
		,	s.CreatedDate 					AS CreatedDate
        ,	s.CreatedDate 					AS LastModifiedDate
        ,   s.RobotCounter              	AS RobotCounter
        ,   CONST_INPUTFLOWID_CATEGORY_PA	AS InputFlowID
    FROM  Temp_CustInfo AS tmp
		INNER JOIN CTS_DataCenter.TWRobotUser AS s ON s.CustID = tmp.CustID
        INNER JOIN CTS_DataCenter.CustomerCategory AS cate ON cate.CategoryID = s.CategoryID
	WHERE s.IsDisabled = 0
   	ON DUPLICATE KEY UPDATE IsFromTW = 1
						,	LastModifiedDate = CASE WHEN s.CreatedDate < Temp_CustCategory.LastModifiedDate THEN s.CreatedDate ELSE Temp_CustCategory.LastModifiedDate END
                        ,	CreatedDate = CASE WHEN s.CreatedDate < Temp_CustCategory.CreatedDate THEN s.CreatedDate ELSE Temp_CustCategory.CreatedDate END;
                                     
	 /***********************Check System Detect Unauthorized Login****************************/
    INSERT IGNORE INTO Temp_CustCategory(CTSCustID, CustID, CategoryID, TVSReasonID, RoleID, SubscriberID, IsLicensee, Remark, CreatedBy, IsMarkedDirectly, IsFromTVS, IsFromTW, IsFromCTS, IsFromAI, IsFromImperva, CreatedDate, LastModifiedDate, InputFlowID)
    SELECT 	tmp.CTSCustID					AS CTSCustID
		,	tmp.CustID						AS CustID
        ,	CONST_CATEID_UNAUTHORIZEDLOGIN  AS CategoryID
        , 	NULL 							AS TVSReasonID
        ,	tmp.RoleID 						AS RoleID
        ,	tmp.SubscriberID				AS SubscriberID
		,	tmp.IsLicensee					AS IsLicensee
        ,	NULL 							AS Remark
        ,	NULL 							AS CreatedBy
        ,	1 								AS IsMarkedDirectly
		,	0 								AS IsFromTVS
        ,	0 								AS IsFromTW
        ,   1 								AS IsFromCTS
        ,	0 								AS IsFromAI
        ,	0 								AS IsFromImperva
		,	s.SourceCreatedDate 			AS CreatedDate
        ,	s.SourceCreatedDate 			AS LastModifiedDate
        ,   CONST_INPUTFLOWID_CATEGORY_PA	AS InputFlowID
    FROM  Temp_CustInfo AS tmp
		INNER JOIN CTS_DataCenter.CustomerLoginInfoDetection AS s ON s.CustID = tmp.CustID 
    WHERE s.IsDisabled = 0;

    /***********************Check TVS Void****************************/
	INSERT IGNORE INTO Temp_CustCategory(CTSCustID, CustID, CategoryID, TVSReasonID, RoleID, SubscriberID, IsLicensee, Remark, CreatedBy, IsMarkedDirectly, IsFromTVS, IsFromTW, IsFromCTS, IsFromAI, IsFromImperva, CreatedDate, LastModifiedDate, TVSRequestID, IsParlay, SportType, IssueTypeID, InputFlowID)
    SELECT tmp.CTSCustID					AS CTSCustID
		,	tmp.CustID						AS CustID
        ,	CASE WHEN cate.IsPAProbation THEN cate.RelevantCategoryID ELSE s.CategoryID END AS CategoryID
        , 	s.TVSReasonID 					AS TVSReasonID
        ,	tmp.RoleID 						AS RoleID
        ,	tmp.SubscriberID				AS SubscriberID
 		,	tmp.IsLicensee					AS IsLicensee
        ,	NULL 							AS Remark
        ,	NULL		 					AS CreatedBy
        ,	1 								AS IsMarkedDirectly
 		,	1 								AS IsFromTVS
        ,	0 								AS IsFromTW
        ,   0 								AS IsFromCTS
        ,	0 								AS IsFromAI
		,	0								AS IsFromImperva
        ,	s.InsertedTime 					AS CreatedDate
        ,	s.InsertedTime 					AS LastModifiedDate
        ,   s.TVSRequestID                  AS TVSRequestID
        ,   s.IsParlay                      AS IsParlay
        ,   s.SportType                     AS SportType
        ,   s.IssueTypeID                   AS IssueTypeID
        ,   CONST_INPUTFLOWID_CATEGORY_PA 	AS InputFlowID
    FROM  Temp_CustInfo AS tmp
 		,	LATERAL (SELECT CategoryID, TVSReasonID, InsertedTime, TVSRequestID, IsParlay, SportType, IssueTypeID
 					 FROM CTS_DataCenter.TVSVoidRequest 
 					 WHERE CustID = tmp.CustID
						AND RequestTypeID = CONST_TVSREQUESTTYPE_PA
                        AND IsDisabled = 0
					 ORDER BY ID DESC
					 LIMIT 1) AS s
		INNER JOIN CTS_DataCenter.CustomerCategory AS cate ON cate.CategoryID = s.CategoryID
	ON DUPLICATE KEY UPDATE  IsFromTVS = 1
					,	LastModifiedDate = CASE WHEN s.InsertedTime < Temp_CustCategory.LastModifiedDate THEN s.InsertedTime ELSE Temp_CustCategory.LastModifiedDate END
					,	CreatedDate = CASE WHEN s.InsertedTime < Temp_CustCategory.CreatedDate THEN s.InsertedTime ELSE Temp_CustCategory.CreatedDate END;

    /***********************Check affected PA from Upline****************************/   
    INSERT IGNORE INTO Temp_CustCategory(CTSCustID, CustID, CategoryID, TVSReasonID, RoleID, SubscriberID, IsLicensee, Remark, CreatedBy, IsMarkedDirectly, IsFromTVS, IsFromTW, IsFromCTS, IsFromAI, IsFromImperva, CreatedDate, LastModifiedDate, InputFlowID)
    SELECT tmp.CTSCustID					AS CTSCustID
		,	tmp.CustID						AS CustID
        ,	CASE WHEN cate.IsPAProbation = 1 THEN cate.RelevantCategoryID ELSE cate.CategoryID END AS CategoryID
        , 	NULL 							AS TVSReasonID
        ,	tmp.RoleID 						AS RoleID
        ,	tmp.SubscriberID				AS SubscriberID
		,	tmp.IsLicensee					AS IsLicensee
        ,	s.Remark						AS Remark
        ,	NULL		 					AS CreatedBy
        ,	0 								AS IsMarkedDirectly
		,	NULL 					        AS IsFromTVS
        ,	s.IsFromTW 						AS IsFromTW
        ,   s.IsFromCTS 					AS IsFromCTS
        ,	s.IsFromAI 						AS IsFromAI
        ,	NULL				            AS IsFromImperva
        ,	s.CreatedDate 					AS CreatedDate
        ,	s.LastModifiedDate 				AS LastModifiedDate
        ,   CONST_INPUTFLOWID_CATEGORY_PA	AS InputFlowID
    FROM Temp_CustInfo AS tmp    
		STRAIGHT_JOIN CTS_DataCenter.CTSCustomerClassificationAgency AS s USE INDEX (PRIMARY) ON s.CustID IN (tmp.SRecommend,tmp.MRecommend,tmp.Recommend) 
					AND s.CustID <> tmp.CustID
					AND s.ParentID = CONST_AGENCY_PARENTID_PA 
                    AND s.IsMarkedDirectly = 1
                    AND s.CategoryID NOT IN (CONST_AGENCY_CATEID_ROBOT, CONST_AGENCY_CATEID_ROBOTLOSING)
        INNER JOIN CTS_DataCenter.CustomerCategoryDownlineMapping AS catmap ON catmap.FromCategoryID = s.CategoryID AND catmap.FromRoleID IN (CONST_ROLEID_AGENT,CONST_ROLEID_MASTER,CONST_ROLEID_SUPER) AND catmap.ToRoleID = CONST_ROLEID_MEMBER
        INNER JOIN CTS_DataCenter.CustomerCategory AS cate ON cate.CategoryID = catmap.ToCategoryID 
    WHERE NOT EXISTS (SELECT 1 FROM CTS_DataCenter.CTSCustomerClassificationAgency AS cls WHERE cls.CustID = s.CustID AND cls.ParentID = CONST_AGENCY_PARENTID_VVIP)  
	ON DUPLICATE KEY UPDATE  Remark = CASE WHEN  s.LastModifiedDate < Temp_CustCategory.LastModifiedDate THEN s.Remark ELSE Temp_CustCategory.Remark END
						,	LastModifiedDate = CASE WHEN s.LastModifiedDate < Temp_CustCategory.LastModifiedDate THEN s.LastModifiedDate ELSE Temp_CustCategory.LastModifiedDate END
						,	CreatedDate = CASE WHEN s.CreatedDate < Temp_CustCategory.CreatedDate THEN s.CreatedDate ELSE Temp_CustCategory.CreatedDate END
                        ,	IsFromCTS = CASE WHEN s.IsFromCTS = 1 THEN s.IsFromCTS ELSE Temp_CustCategory.IsFromCTS END;

    /***********************Check PA from main table ****************************/   
    INSERT IGNORE INTO Temp_CustCategory(CTSCustID, CustID, CategoryID, TVSReasonID, RoleID, SubscriberID, IsLicensee, Remark, CreatedBy, IsMarkedDirectly, IsFromTVS, IsFromTW, IsFromCTS, IsFromAI, IsFromImperva, CreatedDate, LastModifiedDate, InputFlowID)
    SELECT tmp.CTSCustID					AS CTSCustID
		,	tmp.CustID						AS CustID
        ,	CASE WHEN cate.IsPAProbation THEN cate.RelevantCategoryID ELSE s.CategoryID END AS CategoryID
        , 	NULL 							AS TVSReasonID
        ,	tmp.RoleID 						AS RoleID
        ,	tmp.SubscriberID				AS SubscriberID
		,	tmp.IsLicensee					AS IsLicensee
        ,	s.Remark						AS Remark
        ,	NULL		 					AS CreatedBy
        ,	s.IsMarkedDirectly				AS IsMarkedDirectly
		,	s.IsFromTVS 					AS IsFromTVS
        ,	s.IsFromTW 						AS IsFromTW
        ,   s.IsFromCTS 					AS IsFromCTS
        ,	s.IsFromAI 						AS IsFromAI
        ,	s.IsFromImperva					AS IsFromImperva
        ,	s.CreatedDate 					AS CreatedDate
        ,	s.LastModifiedDate 				AS LastModifiedDate
        ,   CONST_INPUTFLOWID_CATEGORY_PA	AS InputFlowID
    FROM Temp_CustInfo AS tmp    
		STRAIGHT_JOIN CTS_DataCenter.CTSCustomerClassification AS s USE INDEX (PRIMARY) ON s.CustID = tmp.CustID AND s.ParentID = CONST_PARENTID_PA 
		INNER JOIN CTS_DataCenter.CustomerCategory AS cate ON cate.CategoryID = s.CategoryID
	ON DUPLICATE KEY UPDATE  Remark = CASE WHEN  s.LastModifiedDate < Temp_CustCategory.LastModifiedDate THEN s.Remark ELSE Temp_CustCategory.Remark END
						,	LastModifiedDate = CASE WHEN s.LastModifiedDate < Temp_CustCategory.LastModifiedDate THEN s.LastModifiedDate ELSE Temp_CustCategory.LastModifiedDate END
                        ,	CreatedDate = CASE WHEN s.CreatedDate < Temp_CustCategory.CreatedDate THEN s.CreatedDate ELSE Temp_CustCategory.CreatedDate END
                        ,	IsMarkedDirectly = CASE WHEN s.IsMarkedDirectly = 1 THEN s.IsMarkedDirectly ELSE Temp_CustCategory.IsMarkedDirectly END
                        ,	IsFromCTS = CASE WHEN s.IsFromCTS = 1 THEN s.IsFromCTS ELSE Temp_CustCategory.IsFromCTS END
                        ,	IsFromTW = CASE WHEN s.IsFromTW = 1 THEN s.IsFromTW ELSE Temp_CustCategory.IsFromTW END
                        ,	IsFromTVS = CASE WHEN s.IsFromTVS = 1 THEN s.IsFromTVS ELSE Temp_CustCategory.IsFromTVS END
                        ,	IsFromAI = CASE WHEN s.IsFromAI = 1 THEN s.IsFromAI ELSE Temp_CustCategory.IsFromAI END
                        ,	IsFromImperva = CASE WHEN s.IsFromImperva = 1 THEN s.IsFromImperva ELSE Temp_CustCategory.IsFromImperva END;
			
	/***********************Check Early Warning****************************/
    INSERT IGNORE INTO Temp_PotentialCategory(CTSCustID, CustID, CategoryID, TVSReasonID, RoleID, SubscriberID, IsLicensee, Remark, CreatedBy, IsMarkedDirectly, IsFromTVS, IsFromTW, IsFromCTS, IsFromAI, IsFromImperva, CreatedDate, LastModifiedDate, InputFlowID)
    SELECT tmp.CTSCustID					AS CTSCustID
		,	tmp.CustID						AS CustID
        ,	CONST_CATEID_EARLYWARNING 		AS CategoryID
        , 	NULL 							AS TVSReasonID
        ,	tmp.RoleID 						AS RoleID
        ,	tmp.SubscriberID				AS SubscriberID
		,	tmp.IsLicensee					AS IsLicensee
        ,	NULL 							AS Remark
        ,	NULL 							AS CreatedBy
        ,	1 								AS IsMarkedDirectly
		,	0 								AS IsFromTVS
        ,	0 								AS IsFromTW
        ,   0 								AS IsFromCTS
        ,	1 								AS IsFromAI
        ,	0 								AS IsFromImperva
		, 	s.CreatedDate 					AS CreatedDate
        ,	s.LastModifiedDate 				AS LastModifiedDate
        ,   CONST_INPUTFLOWID_POTENTIALPA	AS InputFlowID
    FROM  Temp_CustInfo AS tmp
		,	LATERAL (SELECT cd.CreatedDate, cd.LastModifiedDate
					 FROM CTS_DataCenter.Customer_DangerousScore AS cd
					 WHERE cd.CustID = tmp.CustID 
						AND cd.ClassifiedScore IS NOT NULL
					 ORDER BY cd.ID ASC
					 LIMIT 1) AS s
	WHERE NOT EXISTS (SELECT 1 
					  FROM Temp_CustCategory AS cc 
                      WHERE cc.CustID = tmp.CustID 
						AND cc.CategoryID = CONST_CATEID_EARLYWARNING);
    
    /***********************Check Initial GroupBetting****************************/
    INSERT IGNORE INTO Temp_PotentialCategory(CTSCustID, CustID, CategoryID, TVSReasonID, RoleID, SubscriberID, IsLicensee, Remark, CreatedBy, IsMarkedDirectly, IsFromTVS, IsFromTW, IsFromCTS, IsFromAI, IsFromImperva, CreatedDate, LastModifiedDate, SportType, InputFlowID)
	SELECT tmp.CTSCustID					AS CTSCustID
		,	tmp.CustID						AS CustID
        ,	CONST_CATEID_INITIALGB 			AS CategoryID
        , 	NULL 							AS TVSReasonID
        ,	tmp.RoleID 						AS RoleID	 
        ,	tmp.SubscriberID				AS SubscriberID	
		,	tmp.IsLicensee					AS IsLicensee
        ,	NULL 							AS Remark
        ,	NULL 							AS CreatedBy
        ,	1 								AS IsMarkedDirectly
		,	0 								AS IsFromTVS
        ,	1 								AS IsFromTW
        ,   0 								AS IsFromCTS
        ,	0 								AS IsFromAI
        ,	0 								AS IsFromImperva
        , 	s.CreatedDate 					AS CreatedDate
        ,	s.CreatedDate	 				AS LastModifiedDate
        ,   s.SportType                     AS SportType
        ,   CONST_INPUTFLOWID_POTENTIALPA	AS InputFlowID
    FROM  Temp_CustInfo AS tmp
		INNER JOIN CTS_DataCenter.Customer_InitialGroupBetting AS s ON s.CustID = tmp.CustID
	WHERE NOT EXISTS (SELECT 1 
					  FROM Temp_CustCategory AS cc 
					  WHERE cc.CustID = tmp.CustID 
						AND cc.CategoryID = CONST_CATEID_INITIALGB);
    
    /***********************Check Initial Smart (B)****************************/
    INSERT IGNORE INTO Temp_PotentialCategory(CTSCustID, CustID, CategoryID, TVSReasonID, RoleID, SubscriberID, IsLicensee, Remark, CreatedBy, IsMarkedDirectly, IsFromTVS, IsFromTW, IsFromCTS, IsFromAI, IsFromImperva, CreatedDate, LastModifiedDate, InputFlowID, SportType)
    SELECT tmp.CTSCustID					AS CTSCustID
		,	tmp.CustID						AS CustID
        ,	ccs.CategoryID                  AS CategoryID
        , 	NULL 							AS TVSReasonID
        ,	tmp.RoleID 						AS RoleID
        ,	tmp.SubscriberID				AS SubscriberID
		,	tmp.IsLicensee					AS IsLicensee
        ,	NULL 							AS Remark
        ,	NULL 							AS CreatedBy
        ,	1 								AS IsMarkedDirectly
		,	0 								AS IsFromTVS
        ,	1 								AS IsFromTW
        ,   0 								AS IsFromCTS
        ,	0 								AS IsFromAI
        ,	0 								AS IsFromImperva
        , 	s.InsertedTime 					AS CreatedDate
        ,	s.InsertedTime 					AS LastModifiedDate
        ,   CONST_INPUTFLOWID_POTENTIALPA	AS InputFlowID
        ,   NULL                            AS SportType
    FROM  Temp_CustInfo AS tmp
		INNER JOIN CTS_DataCenter.Customer_InitialSmart_BySport AS s ON s.CustID = tmp.CustID
        INNER JOIN CTS_DataCenter.CustomerCategorySettings AS ccs ON ccs.SportType = s.SportType
        INNER JOIN CTS_DataCenter.CustomerCategory AS cate ON ccs.CategoryID = cate.CategoryID
	WHERE NOT EXISTS (SELECT 1 
					  FROM Temp_CustCategory AS cc 
					  WHERE cc.CustID = tmp.CustID 
						AND cc.CategoryID = ccs.CategoryID)
        AND cate.IsPAProbation = 0;

    /***********************Rescan Potential Category****************************/        
    INSERT IGNORE INTO Temp_CustCategory (CTSCustID, CustID, CategoryID, TVSReasonID, RoleID, SubscriberID, IsLicensee, Remark, CreatedBy, IsMarkedDirectly, IsFromTVS, IsFromTW, IsFromCTS, IsFromAI, IsFromImperva, SportType, CreatedDate, LastModifiedDate, InputFlowID)       
    SELECT tmppc.CTSCustID, tmppc.CustID, tmppc.CategoryID, tmppc.TVSReasonID, tmppc.RoleID, tmppc.SubscriberID, tmppc.IsLicensee, tmppc.Remark, tmppc.CreatedBy, tmppc.IsMarkedDirectly, tmppc.IsFromTVS, tmppc.IsFromTW, tmppc.IsFromCTS, tmppc.IsFromAI, tmppc.IsFromImperva, tmppc.SportType, tmppc.CreatedDate, tmppc.LastModifiedDate, tmppc.InputFlowID
    FROM Temp_PotentialCategory AS tmppc;
    
	/***********************Return****************************/ 
	SELECT cust.CTSCustID
		,	cust.CustID
		, 	cc.CategoryID
        ,	cat.CategoryName
		, 	cc.TVSReasonID
		, 	cc.RoleID
		, 	cc.SubscriberID
		, 	cc.IsLicensee
		, 	cc.Remark
		, 	CASE WHEN cc.CreatedBy IS NULL THEN CONST_CREATEDBY_STARIXITID ELSE cc.CreatedBy END AS CreatedBy
		, 	cc.IsMarkedDirectly
		, 	cc.IsFromTVS
		, 	cc.IsFromTW
		, 	cc.IsFromCTS
		, 	cc.IsFromAI
		, 	cc.IsFromImperva
        ,	cc.CreatedDate
		, 	cc.LastModifiedDate
        ,   cc.RobotCounter
        ,   cc.TVSRequestID
        ,   cc.IsParlay
        ,   cc.SportType
        ,   cc.IssueTypeID
		, 	CASE WHEN cc.CategoryID IS NULL THEN CONST_INPUTFLOWID_NORMAL ELSE cc.InputFlowID END AS InputFlowID
        ,   ccs.SportType AS DWSportType
	FROM Temp_CustInfo AS cust
		LEFT JOIN Temp_CustCategory AS cc ON cc.CustID = cust.CustID
        LEFT JOIN CTS_DataCenter.CustomerCategory AS cat ON cc.CategoryID = cat.CategoryID
        LEFT JOIN CTS_DataCenter.CustomerCategorySettings AS ccs ON cc.CategoryID = ccs.CategoryID
	WHERE cc.CustID IS NOT NULL
		OR (cc.CategoryID IS NULL AND cust.RoleID = 1);
    
END$$

DELIMITER ;


