/*<info serverAlias="CTSMain-CTS_DataCenter" databaseType="2" executers="ctsWebAdmin,ctsServiceAdmin,ctsAPIAdmin" isFunction="0" isNested="0"></info>*/
DROP procedure IF EXISTS `CTS_DC_CustClassification_Queue_Get`;

DELIMITER $$
CREATE DEFINER=`ctsOwner`@`%` PROCEDURE `CTS_DC_CustClassification_Queue_Get`(
		OUT op_QueueID					BIGINT UNSIGNED
	,	OUT op_LastDownlineCTSCustID 	BIGINT
	,	OUT op_ActionType				TINYINT
    ,	OUT op_UplineRoleID				TINYINT
)
    SQL SECURITY INVOKER
BEGIN
	/* 
		Created:	20220601@Casey.Huynh	
		Task :		Renovate PA Process [Redmine ID: #172061]
		DB:			CTS_DataCenter
		Original: 
 
		Revisions:
			- 20220601@Casey.Huynh: Created [Redmine ID: #172061]
            - 20240628@Thomas.Nguyen: Renovate CC phase 2 - Change column CategoryGroupID to CategoryGroupID  [Redmine ID: #205317]
            - 20241009@Casey.Huynh: Return Agent [Redmine ID: #185799]

		Param's Explanation:
        
        Example: 
        CALL CTS_DC_CustClassification_Queue_Get(@op_QueueID,@op_LastDownlineCTSCustID,@op_ActionType,@op_UplineRoleID); 
        select @op_QueueID,@op_LastDownlineCTSCustID,@op_ActionType,@op_UplineRoleID;
        

	
    */ 

    DECLARE CONST_ROLEID_MEMBER				    TINYINT DEFAULT 1;
    DECLARE CONST_ROLEID_AGENT            		TINYINT DEFAULT 2;
    DECLARE CONST_ROLEID_MASTER            		TINYINT DEFAULT 3;
    DECLARE CONST_ROLEID_SUPER            		TINYINT DEFAULT 4;

	DECLARE lv_BatchSize				INT;
    DECLARE lv_QueueID					BIGINT UNSIGNED;
    DECLARE lv_LastDownlineCTSCustID 	BIGINT UNSIGNED;
    DECLARE lv_ActionType				TINYINT; #1: INSERT VVIP, 2:Remove VVIP, 3:INSERT PA, 4: UNMARK PA
    DECLARE lv_MaxCTSCustID				BIGINT UNSIGNED;
    
	DECLARE lv_FromCTSCustID				BIGINT UNSIGNED;
    DECLARE lv_FromCustID					BIGINT UNSIGNED;
    DECLARE lv_FromSubscriberID				INT UNSIGNED;
    DECLARE lv_FromRoleID					TINYINT;
    
    
	DECLARE lv_FromCategoryID				INT;
    DECLARE lv_FromCategoryGroupID			INT;
    
    DECLARE lv_CreatedBy 				INT;
    DECLARE lv_Remark 					VARCHAR(500);
	
    DECLARE lv_IsExceptDirectDownline 	TINYINT(1);
    DECLARE lv_IsFromTVS 				TINYINT(1);
    DECLARE lv_IsFromTW 				TINYINT(1);
    DECLARE lv_IsFromCTS 				TINYINT(1);
    DECLARE lv_TVSRequestID             BIGINT;
	
    
    #===========================================================
    DROP TEMPORARY TABLE IF EXISTS Temp_DownlineCustomer;
    CREATE TEMPORARY TABLE Temp_DownlineCustomer(
			CTSCustID		BIGINT UNSIGNED
		,	CustID			BIGINT UNSIGNED
        ,	RoleID			TINYINT
        ,	SubscriberID	INT
        ,	CategoryID		INT
        ,	CategoryGroupID	INT
        ,	IsLicensee		BIT
        
        ,	PRIMARY KEY PK_Temp_DownlineCustomer(CTSCustID)
    );
    
	#===============================================================================
    SELECT sys.ParameterValue
    INTO lv_BatchSize
    FROM SystemParameter AS sys
    WHERE sys.ParameterID = 91;
 
    #=========GET QUEUE Info========================================================
    SELECT 	que.ID, que.LastDownlineCTSCustID, que.ActionType    
		,   que.CTSCustID, que.CustID, que.SubscriberID, que.RoleID        
		, 	IFNULL(que.CategoryID,-1) AS CategoryID, IFNULL(que.CategoryGroupID,-1) AS CategoryGroupID        
        , 	que.CreatedBy, IFNULL(que.Remark,'') AS Remark        
        , 	IFNULL(que.IsExceptDirectDownline,0) AS IsExceptDirectDownline, que.IsFromTVS, que.IsFromTW, que.IsFromCTS, IFNULL(que.TVSRequestID,0) AS TVSRequestID
    INTO 	lv_QueueID, lv_LastDownlineCTSCustID, lv_ActionType		
        , 	lv_FromCTSCustID, lv_FromCustID , lv_FromSubscriberID, lv_FromRoleID        
        , 	lv_FromCategoryID, lv_FromCategoryGroupID        
        , 	lv_CreatedBy, lv_Remark        
        ,	lv_IsExceptDirectDownline, lv_IsFromTVS, lv_IsFromTW, lv_IsFromCTS, lv_TVSRequestID
    FROM CTS_DataCenter.CTSCustomerClassificationQueue AS que
    ORDER BY ID ASC
    LIMIT 1; 

    #====== Super  Get By SRecommend===============
    IF lv_FromRoleID = CONST_ROLEID_SUPER THEN    
		INSERT INTO Temp_DownlineCustomer(CTSCustID, CustID, RoleID, SubscriberID, IsLicensee)
        SELECT	cus.CTSCustID
			,	cus.CustID
            ,	cus.RoleID
			, 	cus.SubscriberID
            ,	cus.IsLicensee
		FROM CTS_DataCenter.CTSCustomer AS cus USE INDEX(IX_CTSCustomer_SRecommend)
		WHERE cus.CustSubID = 0 
			AND cus.SRecommend = lv_FromCustID 
            AND cus.CTSCustID > lv_LastDownlineCTSCustID
			AND cus.RoleID != lv_FromRoleID
        ORDER BY cus.CTSCustID ASC
        LIMIT lv_BatchSize;
        
        #====Map Category If downline Category <> Up Line Category

        UPDATE Temp_DownlineCustomer AS tmpCCmap
			INNER JOIN CustomerCategoryDownlineMapping AS map ON map.FromRoleID <= lv_FromRoleID AND map.FromCategoryID = lv_FromCategoryID	
																	AND map.ToRoleID = tmpCCmap.RoleID
			LEFT JOIN CustomerCategory AS ccm ON ccm.CategoryID = map.ToCategoryID
            LEFT JOIN CustomerCategoryAgency AS cca ON cca.CategoryID = map.ToCategoryID
        SET tmpCCmap.CategoryID = map.ToCategoryID
			,	tmpCCmap.CategoryGroupID = CASE WHEN ccm.CategoryGroupID IS NOT NULL THEN ccm.CategoryGroupID	 
											  WHEN cca.CategoryGroupID IS NOT NULL THEN cca.CategoryGroupID
											ELSE  tmpCCmap.CategoryGroupID END;

        UPDATE Temp_DownlineCustomer AS tmpCCmap
		SET 	tmpCCmap.CategoryID = lv_FromCategoryID
			,	tmpCCmap.CategoryGroupID = lv_FromCategoryGroupID	
        WHERE tmpCCmap.CategoryID IS NULL;    

    END IF;
    
    IF lv_FromRoleID = CONST_ROLEID_MASTER THEN    
    
		INSERT INTO Temp_DownlineCustomer(CTSCustID, CustID, RoleID, SubscriberID, IsLicensee)
        SELECT	cus.CTSCustID
			,	cus.CustID
            ,	cus.RoleID
			, 	cus.SubscriberID
            ,	cus.IsLicensee
		FROM CTS_DataCenter.CTSCustomer AS cus USE INDEX(IX_CTSCustomer_SRecommend)
		WHERE cus.CustSubID = 0 
			AND cus.MRecommend = lv_FromCustID 
            AND cus.CTSCustID > lv_LastDownlineCTSCustID
			AND cus.RoleID != lv_FromRoleID
        ORDER BY cus.CTSCustID ASC
        LIMIT lv_BatchSize;

        #====Map Category If downline Category <> Up Line Category
        UPDATE Temp_DownlineCustomer AS tmpCCmap
			INNER JOIN CustomerCategoryDownlineMapping AS map ON map.FromRoleID <= lv_FromRoleID AND map.FromCategoryID = lv_FromCategoryID	
																	AND map.ToRoleID = tmpCCmap.RoleID
			LEFT JOIN CustomerCategory AS ccm ON ccm.CategoryID = map.ToCategoryID
            LEFT JOIN CustomerCategoryAgency AS cca ON cca.CategoryID = map.ToCategoryID
        SET tmpCCmap.CategoryID = map.ToCategoryID
			,	tmpCCmap.CategoryGroupID = CASE WHEN ccm.CategoryGroupID IS NOT NULL THEN ccm.CategoryGroupID	 
											  WHEN cca.CategoryGroupID IS NOT NULL THEN cca.CategoryGroupID
											ELSE  tmpCCmap.CategoryGroupID END;

        UPDATE Temp_DownlineCustomer AS tmpCCmap
		SET 	tmpCCmap.CategoryID = lv_FromCategoryID
			,	tmpCCmap.CategoryGroupID = lv_FromCategoryGroupID	
        WHERE tmpCCmap.CategoryID IS NULL;    

    END IF;
    
    IF lv_FromRoleID = CONST_ROLEID_AGENT THEN    

		INSERT INTO Temp_DownlineCustomer(CTSCustID, CustID, RoleID, SubscriberID, IsLicensee)
        SELECT	cus.CTSCustID
			,	cus.CustID
            ,	cus.RoleID
			, 	cus.SubscriberID
            ,	cus.IsLicensee
		FROM CTS_DataCenter.CTSCustomer AS cus USE INDEX(IX_CTSCustomer_SRecommend)
		WHERE cus.CustSubID = 0 
			AND cus.Recommend = lv_FromCustID 
            AND cus.CTSCustID > lv_LastDownlineCTSCustID
			AND cus.RoleID != lv_FromRoleID
        ORDER BY cus.CTSCustID ASC
        LIMIT lv_BatchSize;
        
        #====Map Category If downline Category <> Up Line Category
        UPDATE Temp_DownlineCustomer AS tmpCCmap
			INNER JOIN CustomerCategoryDownlineMapping AS map ON map.FromRoleID <= lv_FromRoleID AND map.FromCategoryID = lv_FromCategoryID	
																	AND map.ToRoleID = tmpCCmap.RoleID
			LEFT JOIN CustomerCategory AS ccm ON ccm.CategoryID = map.ToCategoryID
            LEFT JOIN CustomerCategoryAgency AS cca ON cca.CategoryID = map.ToCategoryID
        SET tmpCCmap.CategoryID = map.ToCategoryID
			,	tmpCCmap.CategoryGroupID = CASE WHEN ccm.CategoryGroupID IS NOT NULL THEN ccm.CategoryGroupID	 
											  WHEN cca.CategoryGroupID IS NOT NULL THEN cca.CategoryGroupID
											ELSE  tmpCCmap.CategoryGroupID END;

        UPDATE Temp_DownlineCustomer AS tmpCCmap
		SET 	tmpCCmap.CategoryID = lv_FromCategoryID
			,	tmpCCmap.CategoryGroupID = lv_FromCategoryGroupID	
        WHERE tmpCCmap.CategoryID IS NULL;    

    END IF;
	
    #===========Return Member=======================
    SELECT tmpDl.CTSCustID AS CTSCustID
		,	tmpDl.CustID AS CustID		
		,	tmpDl.RoleID 
        ,	lv_FromSubscriberID AS SubscriberID
		,	tmpDl.IsLicensee      
        
		,	tmpDl.CategoryID AS CategoryID
		,	tmpDl.CategoryGroupID AS CategoryGroupID	
        
        ,	lv_CreatedBy AS CreatedBy
		,	lv_Remark AS Remark	
        
		,	lv_IsExceptDirectDownline AS IsExceptDirectDownline
		,	lv_IsFromTVS AS IsFromTVS
		,	lv_IsFromTW AS IsFromTW
		,	lv_IsFromCTS AS IsFromCTS
		,	lv_TVSRequestID AS TVSRequestID		
        
		,	lv_LastDownlineCTSCustID AS LastDownlineCTSCustID
        
	FROM Temp_DownlineCustomer AS tmpDl
    WHERE RoleID = CONST_ROLEID_MEMBER ;
    
    #===========Return SMA=======================
    SELECT tmpDl.CTSCustID AS CTSCustID
		,	tmpDl.CustID AS CustID		
		,	tmpDl.RoleID 
        ,	lv_FromSubscriberID AS SubscriberID
		,	tmpDl.IsLicensee      
        
		,	tmpDl.CategoryID AS CategoryID
		,	tmpDl.CategoryGroupID AS CategoryGroupID	
        
        ,	lv_CreatedBy AS CreatedBy
		,	lv_Remark AS Remark	
        
		,	lv_IsExceptDirectDownline AS IsExceptDirectDownline
		,	lv_IsFromTVS AS IsFromTVS
		,	lv_IsFromTW AS IsFromTW
		,	lv_IsFromCTS AS IsFromCTS
		,	lv_TVSRequestID AS TVSRequestID		
        
		,	lv_LastDownlineCTSCustID AS LastDownlineCTSCustID
        
	FROM Temp_DownlineCustomer AS tmpDl
    WHERE RoleID IN (CONST_ROLEID_AGENT,CONST_ROLEID_MASTER,CONST_ROLEID_SUPER) ;
    
    
    SET lv_MaxCTSCustID = (SELECT MAX(CTSCustID) FROM Temp_DownlineCustomer);
     
    IF lv_MaxCTSCustID > lv_LastDownlineCTSCustID THEN    
		SET op_QueueID	= lv_QueueID;
		SET op_LastDownlineCTSCustID = lv_MaxCTSCustID;
		SET op_ActionType = lv_ActionType; 
		SET op_UplineRoleID = lv_FromRoleID;      
    ELSE
		SET op_QueueID	= lv_QueueID;
		SET op_LastDownlineCTSCustID = -1;
		SET op_ActionType = NULL; 
		SET op_UplineRoleID = NULL;   
	END IF;
END$$

DELIMITER ;
