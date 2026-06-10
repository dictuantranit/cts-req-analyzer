/*<info serverAlias="CTSMain-CTS_DataCenter" databaseType="2" executers="ctsWebAdmin,ctsServiceAdmin,ctsAPIAdmin" isFunction="0" isNested="0"></info>*/
DROP procedure IF EXISTS `CTS_DC_CustClassificationAgency_Rescan_Get`;

DELIMITER $$
CREATE DEFINER=`ctsOwner`@`%` PROCEDURE `CTS_DC_CustClassificationAgency_Rescan_Get`(
		IN ip_CustIDs	LONGTEXT
)
    SQL SECURITY INVOKER
sp: BEGIN
	/*
		Created:	20241010@Jonas.Huynh
		Task :		Agency Classification
		DB:			CTS_DataCenter 
		Original: 
		Revisions:  
			- 20241010@Jonas.Huynh: 	Created [Redmine ID: #185799]
			- 20250725@Winfred.Pham:  rescan Queue Considerable for Agent (Redmine ID: #219679)
            
        Param's Explanation:

		Example:
			- CALL CTS_DataCenter.CTS_DC_CustClassificationAgency_Rescan_Get("1,2,3,4");
	*/ 
    DECLARE	CONST_AGENCY_CATEID_ROBOT				    INT;
    DECLARE	CONST_AGENCY_CATEID_ROBOTLOSING			    INT;
    DECLARE	CONST_AGENCY_PARENTID_PA				    INT;
    DECLARE CONST_AGENCY_PARENTID_VVIP				    INT;
	DECLARE	CONST_AGENCY_PARENTID_CONSIDERABLEDANGER 	INT;


    DECLARE CONST_INPUTFLOWID_INSERT_NORMAL			INT DEFAULT 1009;
	DECLARE	CONST_INPUTFLOWID_RESCAN_PA				INT DEFAULT 1115;
	DECLARE	CONST_INPUTFLOWID_RESCAN_CD   	        INT DEFAULT 1120;
    DECLARE CONST_AGENCY_CATEID_CD_LOW				INT DEFAULT 130100;
	DECLARE lv_AgentCDList 				            LONGTEXT DEFAULT NULL;
      
	DECLARE CONST_CREATEDBY_STARIXITID				INT DEFAULT 10278938;
    
    SET CONST_AGENCY_CATEID_ROBOT	 				= CTS_DC_CategoryTypeParent_Get ('CONST_AGENCY_CATEID_ROBOT');
    SET CONST_AGENCY_CATEID_ROBOTLOSING	 			= CTS_DC_CategoryTypeParent_Get ('CONST_AGENCY_CATEID_ROBOTLOSING');
    SET CONST_AGENCY_PARENTID_PA 					= CTS_DC_CategoryTypeParent_Get ('CONST_AGENCY_PARENTID_PA');
    SET CONST_AGENCY_PARENTID_VVIP				    = CTS_DC_CategoryTypeParent_Get ('CONST_AGENCY_PARENTID_VVIP');
    SET CONST_AGENCY_PARENTID_CONSIDERABLEDANGER    = CTS_DC_CategoryTypeParent_Get ('CONST_AGENCY_PARENTID_CONSIDERABLEDANGER');
    SET CONST_INPUTFLOWID_RESCAN_CD                 = CTS_DC_CategoryTypeParent_Get ('CONST_AGENCY_INPUTFLOWID_GENERAL_RESCAN_CONSIDERABLEDANGER');
 
    DROP TEMPORARY TABLE IF EXISTS Temp_AgentCD;    
	CREATE TEMPORARY TABLE Temp_AgentCD (	  
			CustID          BIGINT UNSIGNED PRIMARY KEY 	  
		,   IsPassRuleRatio  BIT DEFAULT 0 
     );
     
    DROP TEMPORARY TABLE IF EXISTS Temp_CustID;    
	CREATE TEMPORARY TABLE Temp_CustID (	  
			CustID          BIGINT UNSIGNED PRIMARY KEY 	
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
     ); 
     
    DROP TEMPORARY TABLE IF EXISTS Temp_CustCategory;    
	CREATE TEMPORARY TABLE Temp_CustCategory (	  
			CTSCustID				BIGINT UNSIGNED
        ,   CustID					BIGINT UNSIGNED 
		,	RoleID 					TINYINT 
        , 	SubscriberID			INT UNSIGNED
        ,	CategoryID              INT  
        ,	IsLicensee				BIT
		,   CreatedBy               INT UNSIGNED
		,	Remark				    VARCHAR(500)
        ,	IsMarkedDirectly	    BIT        
		,	IsFromCTS 				BIT DEFAULT 0
        ,	IsFromTW 				BIT DEFAULT 0
        ,	IsFromAI 				BIT DEFAULT 0
        ,   CreatedDate        		DATETIME(3)
        ,   LastModifiedDate        DATETIME(3)
        ,   RobotCounter          	INT
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
			AND cus.IsInternal = 0
            AND cus.IsLicensee = 0;

     /***********************Check CTS RobotUser****************************/
    INSERT IGNORE INTO Temp_CustCategory(CTSCustID, CustID, CategoryID, RoleID, SubscriberID, IsLicensee, Remark, CreatedBy, IsMarkedDirectly, IsFromTW, IsFromCTS, IsFromAI, CreatedDate, LastModifiedDate, InputFlowID)
    SELECT tmp.CTSCustID					AS CTSCustID
		,	tmp.CustID						AS CustID
        ,	CASE WHEN cate.IsPAProbation THEN cate.RelevantCategoryID ELSE s.CategoryID END AS CategoryID
        ,	tmp.RoleID 						AS RoleID
        ,	tmp.SubscriberID				AS SubscriberID
		,	tmp.IsLicensee					AS IsLicensee
        ,	s.Remark						AS Remark
        ,	NULL		 					AS CreatedBy
        ,	1 								AS IsMarkedDirectly
        ,	0 								AS IsFromTW
        ,   1 								AS IsFromCTS
        ,	0 								AS IsFromAI
        ,	s.CreatedDate 					AS CreatedDate
        ,	s.CreatedDate 					AS LastModifiedDate
        ,   CONST_INPUTFLOWID_RESCAN_PA	    AS InputFlowID
    FROM  Temp_CustInfo AS tmp
		INNER JOIN CTS_DataCenter.CTSRobotUser AS s ON s.CustID = tmp.CustID
        INNER JOIN CTS_DataCenter.CustomerCategoryAgency AS cate ON cate.CategoryID = s.CategoryID
	WHERE s.IsDisabled = 0
	ON DUPLICATE KEY UPDATE IsFromCTS = 1
						,	LastModifiedDate = CASE WHEN s.CreatedDate < Temp_CustCategory.LastModifiedDate THEN s.CreatedDate ELSE Temp_CustCategory.LastModifiedDate END
                        ,	CreatedDate = CASE WHEN s.CreatedDate < Temp_CustCategory.CreatedDate THEN s.CreatedDate ELSE Temp_CustCategory.CreatedDate END
                        ,	Remark = CASE WHEN s.CreatedDate < Temp_CustCategory.LastModifiedDate THEN s.Remark ELSE Temp_CustCategory.Remark END;
        
	/***********************Check TWRobotUser****************************/
    INSERT IGNORE INTO Temp_CustCategory(CTSCustID, CustID, CategoryID, RoleID, SubscriberID, IsLicensee, Remark, CreatedBy, IsMarkedDirectly, IsFromTW, IsFromCTS, IsFromAI, CreatedDate, LastModifiedDate, RobotCounter, InputFlowID)
    SELECT tmp.CTSCustID					AS CTSCustID
		,	tmp.CustID						AS CustID
        ,	CASE WHEN cate.IsPAProbation THEN cate.RelevantCategoryID ELSE s.CategoryID END AS CategoryID
        ,	tmp.RoleID 						AS RoleID
        ,	tmp.SubscriberID				AS SubscriberID
		,	tmp.IsLicensee					AS IsLicensee
        ,	NULL 							AS Remark
        ,	NULL		 					AS CreatedBy
        ,	1 								AS IsMarkedDirectly
        ,	1 								AS IsFromTW
        ,   0 								AS IsFromCTS
        ,	0 								AS IsFromAI
		,	s.CreatedDate 					AS CreatedDate
        ,	s.CreatedDate 					AS LastModifiedDate
        ,   s.RobotCounter              	AS RobotCounter
        ,   CONST_INPUTFLOWID_RESCAN_PA	    AS InputFlowID
    FROM  Temp_CustInfo AS tmp
		INNER JOIN CTS_DataCenter.TWRobotUser AS s ON s.CustID = tmp.CustID
        INNER JOIN CTS_DataCenter.CustomerCategoryAgency AS cate ON cate.CategoryID = s.CategoryID
	WHERE s.IsDisabled = 0
   	ON DUPLICATE KEY UPDATE IsFromTW = 1
						,	LastModifiedDate = CASE WHEN s.CreatedDate < Temp_CustCategory.LastModifiedDate THEN s.CreatedDate ELSE Temp_CustCategory.LastModifiedDate END
                        ,	CreatedDate = CASE WHEN s.CreatedDate < Temp_CustCategory.CreatedDate THEN s.CreatedDate ELSE Temp_CustCategory.CreatedDate END;                                               

    /***********************Check affected PA from Upline****************************/   
    INSERT IGNORE INTO Temp_CustCategory(CTSCustID, CustID, CategoryID, RoleID, SubscriberID, IsLicensee, Remark, CreatedBy, IsMarkedDirectly, IsFromTW, IsFromCTS, IsFromAI, CreatedDate, LastModifiedDate, InputFlowID)
    SELECT tmp.CTSCustID					AS CTSCustID
		,	tmp.CustID						AS CustID
        ,	CASE WHEN cate.IsPAProbation = 1 THEN cate.RelevantCategoryID ELSE s.CategoryID END AS CategoryID
        ,	tmp.RoleID 						AS RoleID
        ,	tmp.SubscriberID				AS SubscriberID
		,	tmp.IsLicensee					AS IsLicensee
        ,	s.Remark						AS Remark
        ,	NULL		 					AS CreatedBy
        ,	0 								AS IsMarkedDirectly
        ,	s.IsFromTW 						AS IsFromTW
        ,   s.IsFromCTS 					AS IsFromCTS
        ,	s.IsFromAI 						AS IsFromAI
        ,	s.CreatedDate 					AS CreatedDate
        ,	s.LastModifiedDate				AS LastModifiedDate
        ,   CONST_INPUTFLOWID_RESCAN_PA		AS InputFlowID
    FROM Temp_CustInfo AS tmp    
		STRAIGHT_JOIN CTS_DataCenter.CTSCustomerClassificationAgency AS s USE INDEX (PRIMARY) ON s.CustID IN (tmp.SRecommend,tmp.MRecommend) 
					AND s.CustID <> tmp.CustID
					AND s.ParentID = CONST_AGENCY_PARENTID_PA 
                    AND s.IsMarkedDirectly = 1
                    AND s.CategoryID NOT IN (CONST_AGENCY_CATEID_ROBOT, CONST_AGENCY_CATEID_ROBOTLOSING)
		INNER JOIN CTS_DataCenter.CustomerCategoryAgency AS cate ON cate.CategoryID = s.CategoryID 
    WHERE NOT EXISTS (SELECT 1 FROM CTS_DataCenter.CTSCustomerClassificationAgency AS cls WHERE cls.CustID = s.CustID AND cls.ParentID = CONST_AGENCY_PARENTID_VVIP);
    
    /***********************Check PA from main table ****************************/   
    INSERT IGNORE INTO Temp_CustCategory(CTSCustID, CustID, CategoryID, RoleID, SubscriberID, IsLicensee, Remark, CreatedBy, IsMarkedDirectly, IsFromTW, IsFromCTS, IsFromAI, CreatedDate, LastModifiedDate, InputFlowID)
    SELECT tmp.CTSCustID					AS CTSCustID
		,	tmp.CustID						AS CustID
        ,	CASE WHEN cate.IsPAProbation THEN cate.RelevantCategoryID ELSE s.CategoryID END AS CategoryID
        ,	tmp.RoleID 						AS RoleID
        ,	tmp.SubscriberID				AS SubscriberID
		,	tmp.IsLicensee					AS IsLicensee
        ,	s.Remark						AS Remark
        ,	NULL		 					AS CreatedBy
        ,	s.IsMarkedDirectly				AS IsMarkedDirectly
        ,	s.IsFromTW 						AS IsFromTW
        ,   s.IsFromCTS 					AS IsFromCTS
        ,	s.IsFromAI 						AS IsFromAI
        ,	s.CreatedDate 					AS CreatedDate
        ,	s.LastModifiedDate				AS LastModifiedDate
        ,   CONST_INPUTFLOWID_RESCAN_PA		AS InputFlowID
    FROM Temp_CustInfo AS tmp    
		STRAIGHT_JOIN CTS_DataCenter.CTSCustomerClassificationAgency AS s USE INDEX (PRIMARY) ON s.CustID = tmp.CustID AND s.ParentID = CONST_AGENCY_PARENTID_PA 
		INNER JOIN CTS_DataCenter.CustomerCategoryAgency AS cate ON cate.CategoryID = s.CategoryID
	ON DUPLICATE KEY UPDATE  Remark = CASE WHEN  s.LastModifiedDate < Temp_CustCategory.LastModifiedDate THEN s.Remark ELSE Temp_CustCategory.Remark END
                        ,	CreatedDate = CASE WHEN s.CreatedDate < Temp_CustCategory.CreatedDate THEN s.CreatedDate ELSE Temp_CustCategory.CreatedDate END
                        ,	IsMarkedDirectly = CASE WHEN s.IsMarkedDirectly = 1 THEN s.IsMarkedDirectly ELSE Temp_CustCategory.IsMarkedDirectly END
                        ,	IsFromCTS = CASE WHEN s.IsFromCTS = 1 THEN s.IsFromCTS ELSE Temp_CustCategory.IsFromCTS END
                        ,	IsFromTW = CASE WHEN s.IsFromTW = 1 THEN s.IsFromTW ELSE Temp_CustCategory.IsFromTW END
                        ,	IsFromAI = CASE WHEN s.IsFromAI = 1 THEN s.IsFromAI ELSE Temp_CustCategory.IsFromAI END;
	
    /***********************Check Considerable Danger ****************************/   
    
    SELECT  GROUP_CONCAT(DISTINCT CustID) AS CustJson 
	INTO lv_AgentCDList	
	FROM Temp_CustInfo AS tmpCus
    WHERE tmpCus.RoleID = 2; 

	IF lv_AgentCDList IS NOT NULL THEN        
		CALL CTS_DataCenter.CTS_DC_CustClassificationAgency_DetectCD(lv_AgentCDList,1);
        
        INSERT INTO Temp_AgentCD(CustID, IsPassRuleRatio)
        SELECT tmp.CustID, tmp.IsPassRuleRatio
        FROM Temp_AgentConsiderableDanger AS tmp
			LEFT JOIN Temp_CustCategory AS tcc ON tcc.CustID = tmp.CustID 
        WHERE tcc.CustID IS NULL AND tmp.IsPassRuleRatio = 1;

        INSERT IGNORE INTO Temp_CustCategory(CTSCustID, CustID, CategoryID, RoleID, SubscriberID, IsLicensee, Remark, CreatedBy, IsMarkedDirectly, IsFromTW, IsFromCTS, IsFromAI, InputFlowID)
        SELECT tmp.CTSCustID				AS CTSCustID
            ,	tmp.CustID					AS CustID
            ,	CONST_AGENCY_CATEID_CD_LOW  AS CategoryID
            ,	tmp.RoleID 					AS RoleID
            ,	tmp.SubscriberID			AS SubscriberID
            ,	tmp.IsLicensee				AS IsLicensee
            ,	NULL    					AS Remarks
            ,	NULL		 				AS CreatedBy
            ,	1               			AS IsMarkedDirectly
            ,	0        					AS IsFromTW
            ,   1            				AS IsFromCTS
            ,	0        					AS IsFromAI
            ,   CONST_INPUTFLOWID_RESCAN_CD	AS InputFlowID
        FROM Temp_CustInfo AS tmp   
            INNER JOIN Temp_AgentCD AS tcc ON tcc.CustID = tmp.CustID;
    END IF; 

	/***********************Return****************************/ 
	SELECT cust.CTSCustID
		,	cust.CustID
		, 	cc.CategoryID
		, 	cc.RoleID
		, 	cc.SubscriberID
		, 	cc.IsLicensee
		, 	cc.Remark
		, 	CASE WHEN cc.CreatedBy IS NULL THEN CONST_CREATEDBY_STARIXITID ELSE cc.CreatedBy END AS CreatedBy
		, 	cc.IsMarkedDirectly
		, 	cc.IsFromTW
		, 	cc.IsFromCTS
		, 	cc.IsFromAI
        ,	cc.CreatedDate
        ,   cc.RobotCounter
		, 	CASE WHEN cc.CategoryID IS NULL THEN CONST_INPUTFLOWID_INSERT_NORMAL ELSE cc.InputFlowID END AS InputFlowID
	FROM Temp_CustInfo AS cust
		LEFT JOIN Temp_CustCategory AS cc ON cc.CustID = cust.CustID
	WHERE cc.CustID IS NOT NULL
		OR (cc.CategoryID IS NULL AND cust.RoleID = 2);
    
END$$

DELIMITER ;


