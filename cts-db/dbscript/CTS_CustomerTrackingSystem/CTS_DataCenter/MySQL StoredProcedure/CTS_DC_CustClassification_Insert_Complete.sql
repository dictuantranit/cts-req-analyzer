/*<info serverAlias="CTSMain-CTS_DataCenter" databaseType="2" executers="ctsServiceAdmin" isFunction="0" isNested="1"></info>*/
DROP PROCEDURE IF EXISTS `CTS_DC_CustClassification_Insert_Complete`;

DELIMITER $$
CREATE DEFINER=`ctsOwner`@`%` PROCEDURE `CTS_DC_CustClassification_Insert_Complete`(
		IN	ip_InputFlowID			INT
	,	IN	ip_IsAffectDownline		TINYINT(1)
)
SQL SECURITY INVOKER
BEGIN
/*
		Created:	20240618@Victoria.Le
		Task:		Insert main customer categories for Customer Classification
		DB:			CTS_DataCenter

		Param's Expanation:
			- ip_InputFlowID
			- ip_IsAffectDownline
		
		Example:
			- CALL CTS_DataCenter.CTS_DC_CustClassification_Insert_Complete(9);
			
		Revisions: 
			- 20240618@Victoria.Le:			Initial Writing [Redmine ID: #205317]
			- 20240618@Victoria.Le:			Remove columns: SportGroupID_arc,CategoryID_arc [Redmine ID: #212240]
			- 20250327@Thomas.Nguyen:		Add to source table for the first time classify TW GroupBetting or HighRejected [Redmine ID: #221508]
			- 20250519@Thomas.Nguyen:		Set IsDisabled = 1 for Special Lic Sub source table when having CustomerClassPriority greater than [Redmine ID: #226847]
            - 20250725@Casey.Huynh:			Agent CC, Insert Considerable Agency Queue [Redmine ID: #219679]
			- 20250915@Thomas.Nguyen:		CC 2900/2901 - Use TargetCCHistory to store TargetCC in CC History/Log table [Redmine ID: #237405]						
*/

	DECLARE CONST_CATEID_VVIP 								INT;
	DECLARE CONST_CATEID_SPECIALCC 							INT;
	DECLARE CONST_CATEID_LICVIPSUSPICIOUS 					INT;
	DECLARE CONST_CATEID_LICVIPDANGEROUS 					INT;
	DECLARE CONST_CATEID_LICBA			 					INT;
	DECLARE CONST_CATEID_INITIALGB							INT;
	DECLARE CONST_CATEID_INITIALGBLOSING					INT;
	DECLARE CONST_CATEID_NEWLICSUB							INT DEFAULT 40106;
	DECLARE CONST_CC_LICBA									INT;
	DECLARE CONST_CC_LICVIPSUSPICIOUS						INT;
	DECLARE CONST_CC_LICVIPDANGEROUS						INT;	
	DECLARE CONST_PARENTID_WRAPPER 							INT;
	DECLARE CONST_PARENTID_NORMAL							INT;
    DECLARE CONST_PARENTID_PA								INT;
	DECLARE CONST_REMARKID_PAMARKEDDIRECTLY					INT;
	DECLARE CONST_REMARKID_ROBOTMARKEDDIRECTLY				INT;
	DECLARE CONST_REMARKID_RESCANROBOT						INT;
	DECLARE CONST_REMARKID_PAAFFECTEDBYUPLINE				INT;
	DECLARE CONST_REMARKID_PABYASSOCIATEDGROUP				INT;
	DECLARE CONST_REMARKID_AUTOMARKGB						INT;
	DECLARE CONST_INPUTFLOWID_GENERAL_INSERT_VVIP			INT;
	DECLARE CONST_INPUTFLOWID_GENERAL_INSERT_SPECIALCC		INT;
	DECLARE CONST_INPUTFLOWID_GENERAL_INSERT_LICVIP			INT;
	DECLARE CONST_INPUTFLOWID_GENERAL_INSERT_LICBA			INT;
	DECLARE CONST_INPUTFLOWID_GENERAL_INSERT_PAREASON		INT;
	DECLARE CONST_INPUTFLOWID_GENERAL_INSERT_PACATEGORY		INT;
	DECLARE CONST_INPUTFLOWID_GENERAL_INSERT_POTENTIAL		INT;
	DECLARE CONST_INPUTFLOWID_GENERAL_INSERT_NORMAL			INT;
	DECLARE CONST_INPUTFLOWID_GENERAL_RESCAN_PACATEGORY		INT;
	DECLARE CONST_ACTIONTYPE_INSERT 						INT DEFAULT 0;
	DECLARE	CONST_ACTIONTYPE_UPDATE 						INT DEFAULT 1;
	DECLARE CONST_SOURCETYPE_CUSTOMERCLASS_ADD_MANUAL		INT DEFAULT 10;
	DECLARE CONST_SOURCETYPE_NOREASON_DETAILS				INT DEFAULT 38;
	DECLARE CONST_TVSREQUESTTYPEID_PA						TINYINT DEFAULT 1;
	DECLARE CONST_TVSREQUESTTYPEID_ROBOT					TINYINT DEFAULT 2;
	DECLARE	CONST_SCANTAGGINGTYPE_EXISTONLY 				TINYINT DEFAULT 2;
	DECLARE CONST_TWTAGGINGID_GROUPBETTING					INT DEFAULT 7;
	DECLARE CONST_TWTAGGINGID_HIGHREJECTED					INT DEFAULT 8;
    DECLARE CONST_CONSIDERABLEDANGERQUEUE_SCANTYPE			TINYINT	DEFAULT 1;
	
    DECLARE lv_CreatedBy 									INT DEFAULT 10278938;
	DECLARE	lv_CurrentDateTime								DATETIME DEFAULT CURRENT_TIMESTAMP();
	DECLARE	lv_InsertedCount								INT DEFAULT 0;
	DECLARE	lv_UpdatedCount									INT DEFAULT 0;
	DECLARE lv_IsParallelParentID							TINYINT(1);  
	DECLARE lv_ParentID										INT UNSIGNED;  
	DECLARE lv_CustomerClassPriority						SMALLINT;  
	DECLARE lv_IsAuto										TINYINT(1);  
	DECLARE lv_SourceTypeID									INT;  
	DECLARE lv_ActionType									INT;
	DECLARE lv_IsMarkedDirectly								TINYINT(1);  
	DECLARE lv_IsRescan										TINYINT(1) DEFAULT 0;     
    DECLARE lv_ConsiderableDangerAgentList					TEXT;

	SET CONST_CATEID_VVIP 									= CTS_DataCenter.CTS_DC_CategoryTypeParent_Get ('CONST_CATEID_VVIP');
	SET CONST_CATEID_SPECIALCC								= CTS_DataCenter.CTS_DC_CategoryTypeParent_Get ('CONST_CATEID_SPECIALCC');
	SET CONST_CATEID_LICVIPSUSPICIOUS 						= CTS_DataCenter.CTS_DC_CategoryTypeParent_Get ('CONST_CATEID_LICVIPSUSPICIOUS');
	SET CONST_CATEID_LICVIPDANGEROUS 						= CTS_DataCenter.CTS_DC_CategoryTypeParent_Get ('CONST_CATEID_LICVIPDANGEROUS');
	SET CONST_CATEID_LICBA			 						= CTS_DataCenter.CTS_DC_CategoryTypeParent_Get ('CONST_CATEID_LICBA');
	SET CONST_CATEID_INITIALGB								= CTS_DataCenter.CTS_DC_CategoryTypeParent_Get ('CONST_CATEID_INITIALGB');
	SET CONST_CATEID_INITIALGBLOSING						= CTS_DataCenter.CTS_DC_CategoryTypeParent_Get ('CONST_CATEID_INITIALGBLOSING');
	SET CONST_CC_LICBA										= CTS_DataCenter.CTS_DC_CategoryTypeParent_Get ('CONST_CC_LICBA');
	SET CONST_CC_LICVIPSUSPICIOUS							= CTS_DataCenter.CTS_DC_CategoryTypeParent_Get ('CONST_CC_LICVIPSUSPICIOUS');
	SET CONST_CC_LICVIPDANGEROUS							= CTS_DataCenter.CTS_DC_CategoryTypeParent_Get ('CONST_CC_LICVIPDANGEROUS');
	SET CONST_PARENTID_WRAPPER 								= CTS_DataCenter.CTS_DC_CategoryTypeParent_Get ('CONST_PARENTID_WRAPPER');
	SET CONST_PARENTID_NORMAL 								= CTS_DataCenter.CTS_DC_CategoryTypeParent_Get ('CONST_PARENTID_NORMAL');
    SET CONST_PARENTID_PA 									= CTS_DataCenter.CTS_DC_CategoryTypeParent_Get ('CONST_PARENTID_PA');
	SET CONST_REMARKID_PAMARKEDDIRECTLY 					= CTS_DataCenter.CTS_DC_CategoryTypeParent_Get ('CONST_REMARKID_PAMARKEDDIRECTLY');
	SET CONST_REMARKID_ROBOTMARKEDDIRECTLY 					= CTS_DataCenter.CTS_DC_CategoryTypeParent_Get ('CONST_REMARKID_ROBOTMARKEDDIRECTLY');
	SET CONST_REMARKID_RESCANROBOT 							= CTS_DataCenter.CTS_DC_CategoryTypeParent_Get ('CONST_REMARKID_RESCANROBOT');
	SET CONST_REMARKID_PAAFFECTEDBYUPLINE 					= CTS_DataCenter.CTS_DC_CategoryTypeParent_Get ('CONST_REMARKID_PAAFFECTEDBYUPLINE');
	SET CONST_REMARKID_PABYASSOCIATEDGROUP 					= CTS_DataCenter.CTS_DC_CategoryTypeParent_Get ('CONST_REMARKID_PABYASSOCIATEDGROUP');
	SET CONST_REMARKID_AUTOMARKGB 							= CTS_DataCenter.CTS_DC_CategoryTypeParent_Get ('CONST_REMARKID_AUTOMARKGB');
	SET CONST_INPUTFLOWID_GENERAL_INSERT_VVIP				= CTS_DataCenter.CTS_DC_CategoryTypeParent_Get ('CONST_INPUTFLOWID_GENERAL_INSERT_VVIP');
	SET CONST_INPUTFLOWID_GENERAL_INSERT_SPECIALCC			= CTS_DataCenter.CTS_DC_CategoryTypeParent_Get ('CONST_INPUTFLOWID_GENERAL_INSERT_SPECIALCC');
	SET CONST_INPUTFLOWID_GENERAL_INSERT_LICVIP				= CTS_DataCenter.CTS_DC_CategoryTypeParent_Get ('CONST_INPUTFLOWID_GENERAL_INSERT_LICVIP');
	SET CONST_INPUTFLOWID_GENERAL_INSERT_LICBA				= CTS_DataCenter.CTS_DC_CategoryTypeParent_Get ('CONST_INPUTFLOWID_GENERAL_INSERT_LICBA');
	SET CONST_INPUTFLOWID_GENERAL_INSERT_PAREASON			= CTS_DataCenter.CTS_DC_CategoryTypeParent_Get ('CONST_INPUTFLOWID_GENERAL_INSERT_PAREASON');
	SET CONST_INPUTFLOWID_GENERAL_INSERT_PACATEGORY			= CTS_DataCenter.CTS_DC_CategoryTypeParent_Get ('CONST_INPUTFLOWID_GENERAL_INSERT_PACATEGORY');
	SET CONST_INPUTFLOWID_GENERAL_INSERT_POTENTIAL			= CTS_DataCenter.CTS_DC_CategoryTypeParent_Get ('CONST_INPUTFLOWID_GENERAL_INSERT_POTENTIAL');
	SET CONST_INPUTFLOWID_GENERAL_INSERT_NORMAL				= CTS_DataCenter.CTS_DC_CategoryTypeParent_Get ('CONST_INPUTFLOWID_GENERAL_INSERT_NORMAL');
	SET CONST_INPUTFLOWID_GENERAL_RESCAN_PACATEGORY			= CTS_DataCenter.CTS_DC_CategoryTypeParent_Get ('CONST_INPUTFLOWID_GENERAL_RESCAN_PACATEGORY');
	
	#=================CONSIDERABLE_BEGIN: GET PA BEFORE==================   
    DROP TEMPORARY TABLE IF EXISTS Temp_PACustStart;    
	CREATE TEMPORARY TABLE Temp_PACustStart(	  	
			CustID		BIGINT PRIMARY KEY		
        , 	Recommend	BIGINT
	);  
    
    DROP TEMPORARY TABLE IF EXISTS Temp_PACustEnd;    
	CREATE TEMPORARY TABLE Temp_PACustEnd(	  	
			CustID		BIGINT PRIMARY KEY		
        , 	Recommend	BIGINT
	);  
    
    DROP TEMPORARY TABLE IF EXISTS Temp_PAAgent;    
	CREATE TEMPORARY TABLE Temp_PAAgent(		
		 CustID	BIGINT PRIMARY KEY
	);  


	INSERT IGNORE INTO Temp_PACustStart(CustID, Recommend)
    SELECT	cls.CustID
		,	cus.Recommend
	FROM Temp_NewClassification AS temp 
		INNER JOIN CTS_DataCenter.CTSCustomer AS cus ON cus.CustID = temp.CustID AND cus.IsLicensee = 0
		INNER JOIN CTS_DataCenter.CTSCustomerClassification AS cls ON cls.CustID = cus.CustID
        INNER JOIN CTS_DataCenter.CustomerCategorySettings AS cs ON cs.CategoryID = cls.CategoryID AND cs.FlowConsiderableDangerScan = 1
        INNER JOIN CTS_DataCenter.CustomerCategory AS cc ON cc.CategoryID = cs.CategoryID AND cc.IsActive = 1        
	WHERE cls.ParentID = CONST_PARENTID_PA
		AND NOT EXISTS (SELECT 1			
						FROM CTS_DataCenter.CTSCustomerClassification AS cls2	
							INNER JOIN CTS_DataCenter.CustomerCategory AS cc2 ON cc2.CategoryID = cls2.CategoryID AND cc2.IsActive = 1				
						WHERE cls.CustID = cls2.CustID
							AND cls2.ParentID <> CONST_PARENTID_WRAPPER
							AND cc.CustomerClassPriority > cc2.CustomerClassPriority
							AND cc2.ParentID <> cc.ParentID );
                            
    #=================CONSIDERABLE_END: GET PA BEFORE==================
   
    /*1 - VVIP*/
	IF ip_InputFlowID = CONST_INPUTFLOWID_GENERAL_INSERT_VVIP THEN
		
		SET lv_IsAuto = 0;
	
		SELECT  ccs.IsParallelParentID, cc.ParentID, cc.CustomerClassPriority
		INTO lv_IsParallelParentID, lv_ParentID, lv_CustomerClassPriority
		FROM CTS_DataCenter.CustomerCategorySettings AS ccs
			INNER JOIN CTS_DataCenter.CustomerCategory AS cc ON cc.CategoryID = ccs.CategoryID
		WHERE ccs.CategoryID = CONST_CATEID_VVIP;
		
		IF lv_IsParallelParentID = 0 THEN
			/*Remove all categories which IsKeepOldCateID = 0*/							
			DELETE cls							
			FROM CTS_DataCenter.CTSCustomerClassification AS cls							
				INNER JOIN Temp_NewClassification AS temp ON cls.CustID = temp.CustID						
			WHERE temp.IsExistVVIP = 0							
				AND NOT EXISTS (SELECT 1 
								FROM CTS_DataCenter.CustomerCategorySettings AS cs	
									INNER JOIN CTS_DataCenter.CustomerCategory AS cc ON cc.CategoryID = cs.CategoryID
								WHERE cc.CategoryID = cls.CategoryID AND cc.IsActive = 1	
									AND cc.CustomerClassPriority > lv_CustomerClassPriority 
									AND (cc.ParentID <> lv_ParentID OR (cc.ParentID = lv_ParentID AND cs.IsMultiCateIDSameParentID = 1))
									AND cs.IsKeepOldCateID = 1);
		
			DELETE cls							
			FROM CTS_DataCenter.SpecialCustomerClass AS cls							
				INNER JOIN Temp_NewClassification AS temp ON cls.CustID = temp.CustID						
			WHERE temp.IsExistVVIP = 0							
				AND cls.CreatedFromFunction = 1;
		END IF;
		
		/*Insert VVIP*/
		INSERT IGNORE INTO CTS_DataCenter.CTSCustomerClassification (
				CustID, CTSCustID, SubscriberID, RoleID, ParentID, CategoryID
			, 	Remark, CreatedBy, LastModifiedBy, CreatedDate, LastModifiedDate
			, 	LastScannedDate, IsAffectToDownline, IsMarkedDirectly)
		SELECT 	temp.CustID
			, 	temp.CTSCustID
			, 	temp.SubscriberID
			,	temp.RoleID
			,	temp.ParentID
			,	temp.NewCategoryID
			,	temp.Remark
			,   temp.CreatedBy AS CreatedBy
			,   temp.CreatedBy AS LastModifiedBy
			, 	lv_CurrentDateTime AS CreatedDate
			,   lv_CurrentDateTime AS LastModifiedDate 
			,   DATE(lv_CurrentDateTime) AS LastScannedDate 
			,	ip_IsAffectDownline AS IsAffectToDownline
			,	temp.IsMarkedDirectly
		FROM Temp_NewClassification AS temp
		WHERE temp.IsExistVVIP = 0;
		
		/*Insert VVIP history*/
		INSERT INTO CTS_DataCenter.CTSCustomerClassification_History(
				CustID, CTSCustID, ParentID, CategoryID, LastModifiedDate
			, 	InsertDate, LastModifiedBy, Remark, IsAuto, TargetCC, SourceTypeID
			, 	IsDataChanged, IsMarkedDirectly)
		SELECT 	temp.CustID
			, 	temp.CTSCustID
			,	temp.ParentID
			,	temp.NewCategoryID
			, 	lv_CurrentDateTime AS LastModifiedDate
			,   DATE(lv_CurrentDateTime) AS InsertDate  
			, 	temp.CreatedBy AS LastModifiedBy
			,	temp.Remark
			,	lv_IsAuto AS IsAuto
			,   cat.CustomerClass AS TargetCC
			,   temp.SourceTypeID
			,	temp.IsDataChanged
			,	temp.IsMarkedDirectly
		FROM Temp_NewClassification AS temp
			INNER JOIN CTS_DataCenter.CustomerCategory AS cat ON cat.CategoryID = temp.NewCategoryID
		WHERE temp.IsExistVVIP = 0;
		
		/*Insert VVIP log*/
		INSERT INTO CTS_DataCenter.CTSCustomerClassification_Log(
				CustID, CTSCustID, ParentID, CategoryID ,LastModifiedDate, InsertDate, LastModifiedBy
			, 	IsAuto, TargetCC, SourceTypeID, IsDataChanged, IsMarkedDirectly)
		SELECT 	temp.CustID
			, 	temp.CTSCustID
			,	temp.ParentID
			,	temp.NewCategoryID
			, 	lv_CurrentDateTime AS LastModifiedDate
			,   DATE(lv_CurrentDateTime) AS InsertDate
			, 	temp.CreatedBy AS LastModifiedBy
			,	lv_IsAuto AS IsAuto
			,   cat.CustomerClass AS TargetCC
			,   temp.SourceTypeID
			,	temp.IsDataChanged
			,	temp.IsMarkedDirectly
		FROM Temp_NewClassification AS temp
			INNER JOIN CTS_DataCenter.CustomerCategory AS cat ON cat.CategoryID = temp.NewCategoryID
		WHERE temp.IsExistVVIP = 0;
	
	/*2 - SpecialCC*/
	ELSEIF ip_InputFlowID = CONST_INPUTFLOWID_GENERAL_INSERT_SPECIALCC THEN 
		SET lv_SourceTypeID = CONST_SOURCETYPE_CUSTOMERCLASS_ADD_MANUAL;
		SET lv_ActionType 	= 0;
		SET lv_IsAuto 		= 0;
		
		SELECT  ccs.IsParallelParentID, cc.ParentID, cc.CustomerClassPriority
		INTO lv_IsParallelParentID, lv_ParentID, lv_CustomerClassPriority
		FROM CTS_DataCenter.CustomerCategorySettings AS ccs
			INNER JOIN CTS_DataCenter.CustomerCategory AS cc ON cc.CategoryID = ccs.CategoryID
		WHERE ccs.CategoryID = CONST_CATEID_SPECIALCC;
		
		IF lv_IsParallelParentID = 0 THEN
			/*Remove all categories which IsKeepOldCateID = 0*/							
			DELETE cls							
			FROM CTS_DataCenter.CTSCustomerClassification AS cls							
				INNER JOIN Temp_NewClassification AS temp ON cls.CustID = temp.CustID						
			WHERE NOT EXISTS (SELECT 1 
								FROM CTS_DataCenter.CustomerCategorySettings AS cs	
									INNER JOIN CTS_DataCenter.CustomerCategory AS cc ON cc.CategoryID = cs.CategoryID
								WHERE cc.CategoryID = cls.CategoryID AND cc.IsActive = 1	
									AND cc.CustomerClassPriority > lv_CustomerClassPriority
									AND (cc.ParentID <> lv_ParentID OR (cc.ParentID = lv_ParentID AND cs.IsMultiCateIDSameParentID = 1))
									AND cs.IsKeepOldCateID = 1);
									
		ELSE
			UPDATE CTS_DataCenter.CTSCustomerClassification AS cls
				INNER JOIN Temp_NewClassification AS temp ON temp.CustID = cls.CustID AND cls.ParentID = CONST_PARENTID_WRAPPER AND cls.CategoryID = CONST_CATEID_LICVIPSUSPICIOUS
			SET 	cls.CategoryID 		= CONST_CATEID_LICVIPDANGEROUS
				,	cls.LastModifiedBy	= temp.CreatedBy
			WHERE 	temp.IsDataChanged 	= 1;
			
		END IF;
		
		/*	INSERT VALID SPECIAL CUSTOMER CLASS	*/
		INSERT INTO CTS_DataCenter.SpecialCustomerClass(
				CTSCustID, CustID, RootCTSCustID, SubscriberID, CustomerClass, CreatedBy, CreatedDate, LastModifiedBy, LastModifiedDate, CreatedFromFunction)
		SELECT 	temp.CTSCustID
			,	temp.CustID
			,	temp.CTSCustID AS RootCTSCustID
			,	temp.SubscriberID
			,	temp.TargetCC AS CustomerClass
			,	temp.CreatedBy
			,	lv_CurrentDateTime AS CreatedDate
			,	temp.CreatedBy AS LastModifiedBy
			,	lv_CurrentDateTime AS LastModifiedDate
			,   1 AS CreatedFromFunction -- for Special Customer
		FROM Temp_NewClassification AS temp
		WHERE temp.IsDataChanged = 1;
		
		/*	INSERT LOG FOR SPECIAL CUSTOMER CLASS	*/
		INSERT INTO CTS_DataCenter.SpecialCustomerClass_History(
				CTSCustID, CustID, RootCTSCustID, SubscriberID, CustomerClass, CreatedBy
			, 	CreatedDate, LastModifiedBy, LastModifiedDate, CreatedFromFunction, Remark, ActionType)
		SELECT 	temp.CTSCustID
			,	temp.CustID
			,	temp.CTSCustID
			,	temp.SubscriberID
			,	temp.TargetCC AS CustomerClass
			,	temp.CreatedBy
			,	lv_CurrentDateTime AS CreatedDate
			,	temp.CreatedBy AS LastModifiedBy
			,	lv_CurrentDateTime AS LastModifiedDate
			,   1 AS CreatedFromFunction -- for Special Customer
			,	temp.Remark
			,	lv_ActionType AS ActionType -- insert
		FROM Temp_NewClassification AS temp
		WHERE temp.IsDataChanged = 1;
		
		/*	INSERT */
		INSERT INTO CTS_DataCenter.CTSCustomerClassification (
				CustID, CTSCustID, SubscriberID, RoleID, ParentID, CategoryID, CreatedDate, CreatedBy
			, 	LastModifiedDate, LastModifiedBy, LastScannedDate, Remark)
		SELECT  temp.CustID
			, 	temp.CTSCustID
			,	temp.SubscriberID
			,	temp.RoleID
			,	temp.ParentID
			,	temp.NewCategoryID
			, 	lv_CurrentDateTime AS CreatedDate
			, 	temp.CreatedBy AS CreatedBy
			, 	lv_CurrentDateTime AS LastModifiedDate
			, 	temp.CreatedBy AS LastModifiedBy
			, 	DATE(lv_CurrentDateTime) AS LastScannedDate
			, 	temp.Remark
		FROM Temp_NewClassification AS temp
		WHERE temp.IsDataChanged = 1;
		
		/*	INSERT HISTORY	*/
		INSERT INTO CTS_DataCenter.CTSCustomerClassification_History (
				CustID, CTSCustID, ParentID, CategoryID, LastModifiedDate, LastModifiedBy, ActionType
			, 	IsAuto, InsertDate, TargetCC, SourceTypeID, IsDataChanged, Remark)
		SELECT  temp.CustID
			, 	temp.CTSCustID
			,	temp.ParentID
			,	temp.NewCategoryID
			, 	lv_CurrentDateTime AS LastModifiedDate
			, 	temp.CreatedBy AS LastModifiedBy
			, 	lv_ActionType  AS ActionType 
			, 	lv_IsAuto AS IsAuto
			, 	DATE(lv_CurrentDateTime) AS InsertDate
			,	temp.TargetCC AS TargetCC
			, 	lv_SourceTypeID AS SourceTypeID
			, 	temp.IsDataChanged
			, 	temp.Remark
		FROM Temp_NewClassification AS temp
		WHERE temp.IsDataChanged = 1;
		
		/*	INSERT LOG*/
		INSERT INTO CTS_DataCenter.CTSCustomerClassification_Log (
				CustID, CTSCustID, ParentID, CategoryID, LastModifiedDate, LastModifiedBy, ActionType
			, 	IsAuto, InsertDate, TargetCC, SourceTypeID, IsDataChanged, Remark)
		SELECT  temp.CustID
			, 	temp.CTSCustID
			,	temp.ParentID
			,	temp.NewCategoryID
			, 	lv_CurrentDateTime AS LastModifiedDate
			, 	temp.CreatedBy AS LastModifiedBy
			, 	lv_ActionType AS ActionType 
			, 	lv_IsAuto AS IsAuto
			, 	DATE(lv_CurrentDateTime) AS InsertDate
			,	temp.TargetCC AS TargetCC
			, 	lv_SourceTypeID AS SourceTypeID
			, 	temp.IsDataChanged
			, 	temp.Remark
		FROM Temp_NewClassification AS temp;
	
	/*3 - LicVIP*/
	ELSEIF ip_InputFlowID = CONST_INPUTFLOWID_GENERAL_INSERT_LICVIP THEN 
		SET lv_SourceTypeID 			= CONST_SOURCETYPE_NOREASON_DETAILS;
		SET lv_ActionType 				= 0;
		SET lv_IsAuto 					= 0;
		SET lv_IsMarkedDirectly 		= 1;
		
		SELECT  ccs.IsParallelParentID, cc.ParentID, cc.CustomerClassPriority
		INTO lv_IsParallelParentID, lv_ParentID, lv_CustomerClassPriority
		FROM CTS_DataCenter.CustomerCategorySettings AS ccs
			INNER JOIN CTS_DataCenter.CustomerCategory AS cc ON cc.CategoryID = ccs.CategoryID
		WHERE ccs.CategoryID = CONST_CATEID_LICVIPDANGEROUS;
		
		INSERT INTO Temp_NewClassification(
				CustID, CTSCustID, SubscriberID, RoleID, CreatedBy, IsLicenseeVIP, ParentID, DWCategoryID, NewCategoryID
			, 	NewIsDangerProbation, CategoryPriority, CustomerClassPriority, TargetCC, IsDataChanged ) 
		WITH CTE_LastCategory AS
		(SELECT	temp.CustID
			,	temp.CTSCustID
			,	temp.SubscriberID
			,	temp.RoleID
			,	temp.CreatedBy
			,	temp.IsLicenseeVIP
			,	tmpLastCat.ParentID
			,	tmpLastCat.CategoryID
			,	tmpLastCat.IsDangerProbation
			,	tmpLastCat.CategoryPriority
			,	tmpLastCat.CustomerClassPriority
			,	tmpLastCat.CustomerClass AS TargetCC
		FROM Temp_Customer AS temp,
		LATERAL (
					SELECT cat.ParentID, cls.CategoryID, cat.CategoryPriority, cat.CustomerClassPriority, cat.IsDangerProbation, cat.CustomerClass 
					FROM CTS_DataCenter.CTSCustomerClassification AS cls
						LEFT JOIN CTS_DataCenter.CustomerCategory AS cat ON cat.CategoryID = cls.CategoryID
																				AND cat.CategoryID <> CONST_CATEID_SPECIALCC
					WHERE cls.CustID = temp.CustID
					ORDER BY cls.CustID, cls.LastModifiedDate DESC
					LIMIT 1) AS tmpLastCat) 
		SELECT 	cte.CustID
			,	cte.CTSCustID
			,	cte.SubscriberID
			,	cte.RoleID
			,	cte.CreatedBy
			,	cte.IsLicenseeVIP
			,	cte.ParentID
			,	cte.CategoryID AS DWCategoryID
			,	cte.CategoryID AS NewCategoryID
			,	cte.IsDangerProbation
			,	cte.CategoryPriority
			,	cte.CustomerClassPriority
			,	cte.TargetCC
			,	0 AS IsDataChanged
		FROM  CTE_LastCategory AS cte; 
	
		INSERT INTO Temp_NewClassification(
				CustID, CTSCustID, SubscriberID, RoleID, CreatedBy, IsLicenseeVIP, ParentID, DWCategoryID, NewCategoryID
			, 	NewIsDangerProbation, CategoryPriority, CustomerClassPriority, TargetCC, IsDataChanged ) 
		SELECT 	temp.CustID
			,	temp.CTSCustID
			,	temp.SubscriberID
			,	temp.RoleID
			,	temp.CreatedBy
			,	temp.IsLicenseeVIP
			,	cc.ParentID
			,	cc.CategoryID AS DWCategoryID
			,	cc.CategoryID AS NewCategoryID
			,	cc.IsDangerProbation
			,	cc.CategoryPriority
			,	cc.CustomerClassPriority
			,	cc.CustomerClass
			,	0 AS IsDataChanged
		FROM Temp_Customer AS temp
			INNER JOIN CTS_DataCenter.SpecialCustomerClass AS sc ON sc.CustID = temp.CustID
			INNER JOIN CTS_DataCenter.CustomerCategory AS cc ON sc.CustomerClass = cc.CustomerClass;
	
		UPDATE Temp_NewClassification AS temp
			INNER JOIN CTS_DataCenter.SpecialCustomerClass AS sc ON sc.CustID = temp.CustID
		SET temp.CustomerClassPriority = -1
		WHERE temp.CustomerClassPriority IS NULL;
	
		UPDATE Temp_NewClassification AS temp
		SET 	temp.IsDataChanged 	= 1
			, 	temp.ParentID 		= CONST_PARENTID_WRAPPER
			, 	temp.NewCategoryID 	= (CASE WHEN temp.NewIsDangerProbation = 1 THEN CONST_CATEID_LICVIPSUSPICIOUS 
											ELSE CONST_CATEID_LICVIPDANGEROUS END) 
			, 	temp.TargetCC 		= (CASE WHEN temp.NewIsDangerProbation = 1 THEN CONST_CC_LICVIPSUSPICIOUS 
											ELSE CONST_CC_LICVIPDANGEROUS END)
		WHERE temp.IsLicenseeVIP = 0 
			AND ( temp.CustomerClassPriority IS NULL 
					OR temp.CustomerClassPriority > lv_CustomerClassPriority);
					
		UPDATE Temp_NewClassification AS temp
		SET 	temp.IsReturnData = 0
		WHERE 	temp.IsDataChanged <> 1;

		IF lv_IsParallelParentID = 0 THEN
			/*Remove all categories which IsKeepOldCateID = 0*/							
			DELETE cls							
			FROM CTS_DataCenter.CTSCustomerClassification AS cls							
				INNER JOIN Temp_NewClassification AS temp ON cls.CustID = temp.CustID						
			WHERE NOT EXISTS (SELECT 1 
								FROM CTS_DataCenter.CustomerCategorySettings AS cs	
									INNER JOIN CTS_DataCenter.CustomerCategory AS cc ON cc.CategoryID = cs.CategoryID
								WHERE cc.CategoryID = cls.CategoryID AND cc.IsActive = 1	
									AND cc.CustomerClassPriority > lv_CustomerClassPriority
									AND (cc.ParentID <> lv_ParentID OR (cc.ParentID = lv_ParentID AND cs.IsMultiCateIDSameParentID = 1))
									AND cs.IsKeepOldCateID = 1);
		END IF;

		UPDATE CTS_DataCenter.CTSCustomer AS cus
			INNER JOIN Temp_Customer AS temp ON cus.CTSCustID = temp.CTSCustID
		SET 	cus.IsLicenseeVIP = 1
			, 	cus.ModifiedTime = lv_CurrentDateTime
		WHERE cus.IsLicenseeVIP = 0;   
		
		IF EXISTS (SELECT 1 FROM Temp_NewClassification AS temp) THEN
			INSERT IGNORE INTO CTS_DataCenter.CTSCustomerClassification(
				CTSCustID, CustID, SubscriberID, RoleID, ParentID, CategoryID, CreatedDate, CreatedBy, LastModifiedDate, LastModifiedBy, LastScannedDate, IsMarkedDirectly) 
			SELECT	temp.CTSCustID
				,	temp.CustID
				,	temp.SubscriberID
				,	temp.RoleID
				,	CONST_PARENTID_WRAPPER AS ParentID
				,	(CASE WHEN temp.NewIsDangerProbation = 1 THEN CONST_CATEID_LICVIPSUSPICIOUS ELSE CONST_CATEID_LICVIPDANGEROUS END) AS CategoryID
				,	lv_CurrentDateTime AS CreatedDate
				,	temp.CreatedBy
				,	lv_CurrentDateTime AS LastModifiedDate
				,	temp.CreatedBy AS LastModifiedBy
				,	DATE(lv_CurrentDateTime) LastScannedDate
				,	lv_IsMarkedDirectly AS IsMarkedDirectly
			FROM Temp_NewClassification AS temp;
		
			/*Insert history*/
			INSERT INTO CTS_DataCenter.CTSCustomerClassification_History(
					CustID, CTSCustID, ParentID, CategoryID ,LastModifiedDate, LastModifiedBy, ActionType, IsAuto, InsertDate, TargetCC, SourceTypeID, IsDataChanged, IsMarkedDirectly)
			SELECT 	temp.CustID
				, 	temp.CTSCustID
				,	CONST_PARENTID_WRAPPER AS ParentID
				,	(CASE WHEN temp.NewIsDangerProbation = 1 THEN CONST_CATEID_LICVIPSUSPICIOUS ELSE CONST_CATEID_LICVIPDANGEROUS END) AS CategoryID
				, 	lv_CurrentDateTime AS LastModifiedDate
				, 	temp.CreatedBy AS LastModifiedBy
				,	lv_ActionType AS ActionType
				,	lv_IsAuto AS IsAuto
				,   DATE(lv_CurrentDateTime) AS InsertDate
				,   temp.TargetCC
				,   lv_SourceTypeID AS SourceTypeID
				,	temp.IsDataChanged
				,	lv_IsMarkedDirectly AS IsMarkedDirectly
			FROM Temp_NewClassification AS temp
			WHERE temp.IsDataChanged = 1;
			
			/*Insert log*/
			INSERT INTO CTS_DataCenter.CTSCustomerClassification_Log(
					CustID, CTSCustID, ParentID, CategoryID ,LastModifiedDate, LastModifiedBy, ActionType, IsAuto, InsertDate, TargetCC, SourceTypeID, IsDataChanged, IsMarkedDirectly)
			SELECT 	temp.CustID
				, 	temp.CTSCustID
				,	CONST_PARENTID_WRAPPER AS ParentID
				,	(CASE WHEN temp.NewIsDangerProbation = 1 THEN CONST_CATEID_LICVIPSUSPICIOUS ELSE CONST_CATEID_LICVIPDANGEROUS END) AS CategoryID
				, 	lv_CurrentDateTime AS LastModifiedDate
				, 	temp.CreatedBy AS LastModifiedBy
				,	lv_ActionType AS ActionType
				,	lv_IsAuto AS IsAuto
				,   DATE(lv_CurrentDateTime) AS InsertDate
				,   temp.TargetCC
				,   lv_SourceTypeID AS SourceTypeID
				,	temp.IsDataChanged
				,	lv_IsMarkedDirectly AS IsMarkedDirectly
			FROM Temp_NewClassification AS temp;
			
		ELSE
			INSERT IGNORE INTO CTS_DataCenter.CTSCustomerClassification(
					CTSCustID, CustID, SubscriberID, RoleID, ParentID, CategoryID, CreatedDate, CreatedBy, LastModifiedDate, LastModifiedBy, LastScannedDate, IsMarkedDirectly) 
			SELECT	temp.CTSCustID
				,	temp.CustID
				,	temp.SubscriberID
				,	temp.RoleID
				,	CONST_PARENTID_WRAPPER AS ParentID
				,	CONST_CATEID_LICVIPDANGEROUS AS CategoryID 
				,	lv_CurrentDateTime AS CreatedDate
				,	temp.CreatedBy
				,	lv_CurrentDateTime AS LastModifiedDate
				,	temp.CreatedBy AS LastModifiedBy
				,	DATE(lv_CurrentDateTime) LastScannedDate
				,	lv_IsMarkedDirectly AS IsMarkedDirectly
			FROM Temp_Customer AS temp
				LEFT JOIN Temp_NewClassification AS tmpCat ON tmpCat.CustID = temp.CustID
			WHERE tmpCat.CustID IS NULL;

		END IF;
	
	/*4 - LicBA*/
	ELSEIF ip_InputFlowID = CONST_INPUTFLOWID_GENERAL_INSERT_LICBA THEN 
		SET lv_SourceTypeID 		= CONST_SOURCETYPE_NOREASON_DETAILS;
		SET lv_ActionType 			= 0;
		SET lv_IsAuto 				= 0; 
		SET lv_IsMarkedDirectly 	= 1;
	
		SELECT  ccs.IsParallelParentID, cc.ParentID, cc.CustomerClassPriority
		INTO lv_IsParallelParentID, lv_ParentID, lv_CustomerClassPriority
		FROM CTS_DataCenter.CustomerCategorySettings AS ccs
			INNER JOIN CTS_DataCenter.CustomerCategory AS cc ON cc.CategoryID = ccs.CategoryID
		WHERE ccs.CategoryID = CONST_CATEID_LICBA;
	
		INSERT INTO Temp_NewClassification(
				CustID, CTSCustID, SubscriberID, RoleID, CreatedBy, IsLicenseeBA, ParentID, DWCategoryID, NewCategoryID
			, 	CategoryPriority, CustomerClassPriority, TargetCC, IsDataChanged ) 
		WITH CTE_LastCategory AS
		(
		 SELECT	temp.CustID
			,	temp.CTSCustID
			,	temp.SubscriberID
			,	temp.RoleID
			,	temp.CreatedBy
			,	temp.IsLicenseeBA
			,	tmpLastCat.ParentID
			,	tmpLastCat.CategoryID
			,	tmpLastCat.CategoryPriority
			,	tmpLastCat.CustomerClassPriority
			,	tmpLastCat.CustomerClass AS TargetCC
		 FROM Temp_Customer AS temp,
		 LATERAL (
					SELECT cls.ParentID, cls.CategoryID, cat.CategoryPriority, cat.CustomerClassPriority, cat.CustomerClass 
					FROM CTS_DataCenter.CTSCustomerClassification AS cls
						LEFT JOIN CTS_DataCenter.CustomerCategory AS cat ON cat.CategoryID = cls.CategoryID 
																			AND cat.CategoryID <> CONST_CATEID_SPECIALCC
																			AND cat.CustomerClassPriority < lv_CustomerClassPriority
					WHERE cls.CustID = temp.CustID
					ORDER BY cls.CustID, cls.LastModifiedDate DESC
					LIMIT 1
				  ) AS tmpLastCat
		) 
		SELECT cte.CustID
		,	cte.CTSCustID
		,	cte.SubscriberID
		,	cte.RoleID
		,	cte.CreatedBy
		,	cte.IsLicenseeBA
		,	cte.ParentID
		,	cte.CategoryID AS DWCategoryID
		,	cte.CategoryID AS NewCategoryID
		,	cte.CategoryPriority
		,	cte.CustomerClassPriority
		,	cte.TargetCC
		,	0 AS IsDataChanged
		FROM  CTE_LastCategory AS cte;  
		
		INSERT INTO Temp_NewClassification(
				CustID, CTSCustID, SubscriberID, RoleID, CreatedBy, IsLicenseeBA, ParentID, DWCategoryID, NewCategoryID
			, 	CategoryPriority, CustomerClassPriority, TargetCC, IsDataChanged ) 
		SELECT 	temp.CustID
			,	temp.CTSCustID
			,	temp.SubscriberID
			,	temp.RoleID
			,	temp.CreatedBy
			,	temp.IsLicenseeBA
			,	cc.ParentID
			,	cc.CategoryID AS DWCategoryID
			,	cc.CategoryID AS NewCategoryID
			,	cc.CategoryPriority
			,	cc.CustomerClassPriority
			,	cc.CustomerClass
			,	0 AS IsDataChanged
		FROM Temp_Customer AS temp
			INNER JOIN CTS_DataCenter.SpecialCustomerClass AS sc ON sc.CustID = temp.CustID
			INNER JOIN CTS_DataCenter.CustomerCategory AS cc ON sc.CustomerClass = cc.CustomerClass;

		UPDATE Temp_NewClassification AS temp
			INNER JOIN CTS_DataCenter.SpecialCustomerClass AS sc ON sc.CustID = temp.CustID
		SET temp.CustomerClassPriority = -1
		WHERE temp.CustomerClassPriority IS NULL;
		
		UPDATE Temp_NewClassification AS temp
		SET 	temp.IsDataChanged 		= 1
			, 	temp.ParentID 			= CONST_PARENTID_WRAPPER
			, 	temp.NewCategoryID		= CONST_CATEID_LICBA
			, 	temp.TargetCC 			= CONST_CC_LICBA
		WHERE temp.IsLicenseeBA = 0
			AND ( temp.CustomerClassPriority IS NULL OR temp.CustomerClassPriority > lv_CustomerClassPriority); 
			
		UPDATE Temp_NewClassification AS temp
		SET 	temp.IsReturnData = 0
		WHERE 	temp.IsDataChanged <> 1;
		
		IF lv_IsParallelParentID = 0 THEN
			/*Remove all categories which IsKeepOldCateID = 0*/							
			DELETE cls							
			FROM CTS_DataCenter.CTSCustomerClassification AS cls							
				INNER JOIN Temp_NewClassification AS temp ON cls.CustID = temp.CustID						
			WHERE NOT EXISTS (SELECT 1 
								FROM CTS_DataCenter.CustomerCategorySettings AS cs	
									INNER JOIN CTS_DataCenter.CustomerCategory AS cc ON cc.CategoryID = cs.CategoryID
								WHERE cc.CategoryID = cls.CategoryID AND cc.IsActive = 1	
									AND cc.CustomerClassPriority > lv_CustomerClassPriority
									AND (cc.ParentID <> lv_ParentID OR (cc.ParentID = lv_ParentID AND cs.IsMultiCateIDSameParentID = 1))
									AND cs.IsKeepOldCateID = 1);
		END IF;
		
		UPDATE CTS_DataCenter.CTSCustomer AS cus
			INNER JOIN Temp_Customer AS temp ON cus.CTSCustID = temp.CTSCustID
		SET 	cus.IsLicenseeBA = 1
			, 	cus.ModifiedTime = lv_CurrentDateTime
		WHERE cus.IsLicenseeBA = 0; 

		IF EXISTS (SELECT 1 FROM Temp_NewClassification AS temp) THEN		
			INSERT IGNORE INTO CTS_DataCenter.CTSCustomerClassification(
				CTSCustID, CustID, SubscriberID, RoleID, ParentID, CategoryID, CreatedDate, CreatedBy, LastModifiedDate, LastModifiedBy, LastScannedDate, IsMarkedDirectly) 
			SELECT	temp.CTSCustID
				,	temp.CustID
				,	temp.SubscriberID
				,	temp.RoleID
				,	CONST_PARENTID_WRAPPER AS ParentID
				,	CONST_CATEID_LICBA AS CategoryID 
				,	lv_CurrentDateTime AS CreatedDate
				,	temp.CreatedBy
				,	lv_CurrentDateTime AS LastModifiedDate
				,	temp.CreatedBy AS LastModifiedBy
				,	DATE(lv_CurrentDateTime) LastScannedDate
				,	lv_IsMarkedDirectly AS IsMarkedDirectly
			FROM Temp_NewClassification AS temp;
		
			/*Insert history*/
			INSERT INTO CTS_DataCenter.CTSCustomerClassification_History(
					CustID, CTSCustID, ParentID, CategoryID ,LastModifiedDate, LastModifiedBy, ActionType, IsAuto, InsertDate, TargetCC, SourceTypeID, IsDataChanged, IsMarkedDirectly)
			SELECT 	temp.CustID
				, 	temp.CTSCustID
				,	CONST_PARENTID_WRAPPER AS ParentID
				,	CONST_CATEID_LICBA AS CategoryID 
				, 	lv_CurrentDateTime AS LastModifiedDate
				, 	temp.CreatedBy AS LastModifiedBy
				,	lv_ActionType  AS ActionType
				,	lv_IsAuto  AS IsAuto
				,   DATE(lv_CurrentDateTime) AS InsertDate
				,   temp.TargetCC
				,   lv_SourceTypeID AS SourceTypeID
				,	temp.IsDataChanged
				,	lv_IsMarkedDirectly AS IsMarkedDirectly
			FROM Temp_NewClassification AS temp
			WHERE temp.IsDataChanged = 1;
			
			/*Insert log*/
			INSERT INTO CTS_DataCenter.CTSCustomerClassification_Log(
					CustID, CTSCustID, ParentID, CategoryID ,LastModifiedDate, LastModifiedBy, ActionType, IsAuto, InsertDate, TargetCC, SourceTypeID, IsDataChanged, IsMarkedDirectly)
			SELECT 	temp.CustID
				, 	temp.CTSCustID
				,	CONST_PARENTID_WRAPPER AS ParentID
				,	CONST_CATEID_LICBA AS CategoryID 
				, 	lv_CurrentDateTime AS LastModifiedDate
				, 	temp.CreatedBy AS LastModifiedBy
				,	lv_ActionType  AS ActionType
				,	lv_IsAuto  AS IsAuto
				,   DATE(lv_CurrentDateTime) AS InsertDate
				,   temp.TargetCC
				,   lv_SourceTypeID AS SourceTypeID
				,	temp.IsDataChanged
				,	lv_IsMarkedDirectly AS IsMarkedDirectly
			FROM Temp_NewClassification AS temp;
			
		ELSE
			INSERT IGNORE INTO CTS_DataCenter.CTSCustomerClassification(
					CTSCustID, CustID, SubscriberID, RoleID, ParentID, CategoryID, CreatedDate, CreatedBy, LastModifiedDate, LastModifiedBy, LastScannedDate, IsMarkedDirectly) 
			SELECT	temp.CTSCustID
				,	temp.CustID
				,	temp.SubscriberID
				,	temp.RoleID
				,	CONST_PARENTID_WRAPPER AS ParentID
				,	CONST_CATEID_LICBA AS CategoryID 
				,	lv_CurrentDateTime AS CreatedDate
				,	temp.CreatedBy
				,	lv_CurrentDateTime AS LastModifiedDate
				,	temp.CreatedBy AS LastModifiedBy
				,	DATE(lv_CurrentDateTime) LastScannedDate
				,	lv_IsMarkedDirectly AS IsMarkedDirectly
			FROM Temp_Customer AS temp
				LEFT JOIN Temp_NewClassification AS tmpCat ON tmpCat.CustID = temp.CustID
			WHERE tmpCat.CustID IS NULL;
		
		END IF;

	/*5 - Normal*/
	ELSEIF ip_InputFlowID = CONST_INPUTFLOWID_GENERAL_INSERT_NORMAL THEN 
		SET lv_IsAuto = 1;
		
		UPDATE CTS_DataCenter.CTSCustomerClassification AS cate
			INNER JOIN Temp_NewClassification AS temp ON temp.CustID = cate.CustID AND cate.ParentID = CONST_PARENTID_NORMAL
		SET   	cate.CTSCustID 			= temp.CTSCustID
			, 	cate.SubscriberID 		= temp.SubscriberID
			, 	cate.CategoryID 		= temp.NewCategoryID
			, 	cate.LastModifiedDate 	= lv_CurrentDateTime
			, 	cate.LastScannedDate 	= CASE  WHEN temp.ScanTaggingType = CONST_SCANTAGGINGTYPE_EXISTONLY  THEN cate.LastScannedDate
												ELSE DATE(lv_CurrentDateTime) END
		WHERE temp.ActionType = CONST_ACTIONTYPE_UPDATE;
	
		UPDATE CTS_DataCenter.CTSCustomerClassification AS cate
			INNER JOIN Temp_NewClassification AS temp ON temp.CustID = cate.CustID 
															AND cate.ParentID = CONST_PARENTID_WRAPPER
		SET   	cate.CategoryID = 	CASE WHEN temp.NewIsDangerProbation = 1 
											THEN CONST_CATEID_LICVIPSUSPICIOUS
										ELSE CONST_CATEID_LICVIPDANGEROUS END
		WHERE cate.CategoryID IN (CONST_CATEID_LICVIPSUSPICIOUS,CONST_CATEID_LICVIPDANGEROUS)
			AND temp.IsDataChanged = 1;
		
		DELETE del
		FROM CTS_DataCenter.CTSCustomerClassification AS del
			INNER JOIN Temp_NewClassification AS temp ON del.CustID = temp.CustID 
															AND del.ParentID = CONST_PARENTID_NORMAL
		WHERE temp.ActionType = CONST_ACTIONTYPE_INSERT;
		
		INSERT IGNORE INTO CTS_DataCenter.CTSCustomerClassification(
				CustID,CTSCustID,SubscriberID,RoleID,ParentID,CategoryID,CreatedDate,CreatedBy,LastModifiedDate
			,	LastModifiedBy,LastScannedDate)
		SELECT DISTINCT 
				temp.CustID
			, 	temp.CTSCustID
			, 	temp.SubscriberID
			, 	temp.RoleID
			, 	CONST_PARENTID_NORMAL AS ParentID
			, 	temp.NewCategoryID AS CategoryID
			, 	lv_CurrentDateTime AS CreatedDate
			, 	lv_CreatedBy AS CreatedBy
			, 	lv_CurrentDateTime AS LastModifiedDate
			, 	lv_CreatedBy AS LastModifiedBy
			, 	DATE(lv_CurrentDateTime) AS LastScannedDate
		FROM Temp_NewClassification AS temp
		WHERE temp.ActionType = CONST_ACTIONTYPE_INSERT;
		
		INSERT IGNORE INTO CTS_DataCenter.CTSCustomerClassification_History (
				CustID, CTSCustID, CategoryID, ParentID, LastModifiedDate, LastModifiedBy, TurnoverRM
			, 	WinlossRM, BetCount, ActiveDays, TWBetCount, TWGroupBettingRate, TWTicketRejectRate, TWDesktopUsageRate
			, 	IsAuto, InsertDate, TargetCC, SourceTypeID, OldCategoryID, DWCategoryID, IsDataChanged
			, 	TaggingType, TargetDangerLevel1, PerformanceTime, ActionType)
		SELECT DISTINCT	
				temp.CustID
			, 	temp.CTSCustID
			, 	temp.NewCategoryID AS CategoryID
			, 	CONST_PARENTID_NORMAL AS ParentID
			, 	lv_CurrentDateTime AS LastModifiedDate
			, 	lv_CreatedBy AS LastModifiedBy
			, 	temp.TurnoverRM
			, 	temp.WinlossRM
			, 	temp.BetCount
			, 	temp.ActiveDays
			,	temp.TWBetCount
			, 	temp.TWGroupBettingRate
			, 	temp.TWTicketRejectRate
			, 	temp.TWDesktopUsageRate
			, 	lv_IsAuto
			, 	DATE(lv_CurrentDateTime) AS InsertDate
			,	temp.TargetCC 
			,   temp.SourceTypeID
			, 	temp.OldCategoryID 
			, 	temp.DWCategoryID
			,   temp.IsDataChanged
			,	temp.TaggingType
			,	temp.TargetDangerLevel AS TargetDangerLevel1
			,	temp.PerformanceTime
			,	temp.ActionType
		FROM 	Temp_NewClassification AS temp
		WHERE temp.IsDataChanged  = 1;	
        
        INSERT IGNORE INTO CTS_DataCenter.CTSCustomerClassification_Log (
				CustID, CTSCustID, CategoryID, ParentID, LastModifiedDate, LastModifiedBy, TurnoverRM, WinlossRM
			, 	BetCount, ActiveDays, TWBetCount, TWGroupBettingRate, TWTicketRejectRate, TWDesktopUsageRate
			, 	IsAuto, InsertDate, TargetCC, SourceTypeID, OldCategoryID, DWCategoryID, IsDataChanged
			, 	TaggingType, TargetDangerLevel1, PerformanceTime, ActionType)
		SELECT DISTINCT	
				temp.CustID
			, 	temp.CTSCustID
			, 	temp.NewCategoryID AS CategoryID
			, 	CONST_PARENTID_NORMAL AS ParentID
			, 	lv_CurrentDateTime AS LastModifiedDate
			, 	lv_CreatedBy AS LastModifiedBy
			, 	temp.TurnoverRM
			, 	temp.WinlossRM
			, 	temp.BetCount
			, 	temp.ActiveDays
			,	temp.TWBetCount
			, 	temp.TWGroupBettingRate
			, 	temp.TWTicketRejectRate
			, 	temp.TWDesktopUsageRate
			, 	lv_IsAuto
			, 	DATE(lv_CurrentDateTime) AS InsertDate
			,	temp.TargetCC 
			,   temp.SourceTypeID
			, 	temp.OldCategoryID 
			, 	temp.DWCategoryID
			,   temp.IsDataChanged
			,	temp.TaggingType
			,	temp.TargetDangerLevel AS TargetDangerLevel1
			,	temp.PerformanceTime
			,	temp.ActionType
		FROM 	Temp_NewClassification AS temp;

		/*Add to source table for first time classify TW GB or HighRejected*/	
		IF EXISTS (	SELECT 1 
					FROM Temp_NewClassification AS temp
						INNER JOIN CTS_DataCenter.CustomerCategorySettings AS ccs ON ccs.CategoryID = temp.NewCategoryID
					WHERE ccs.IsFirstTWTagging = 1 AND temp.TaggingID IN (CONST_TWTAGGINGID_GROUPBETTING, CONST_TWTAGGINGID_HIGHREJECTED)) THEN
			INSERT IGNORE INTO CTS_DataCenter.Customer_FirstTWTaggingCC (CustID, TWTaggingID, CreatedTime)
			SELECT temp.CustID, temp.TaggingID, lv_CurrentDateTime
			FROM Temp_NewClassification AS temp
				INNER JOIN CTS_DataCenter.CustomerCategorySettings AS ccs ON ccs.CategoryID = temp.NewCategoryID
				LEFT JOIN CTS_DataCenter.Customer_FirstTWTaggingCC AS cus ON cus.CustID = temp.CustID AND cus.TWTaggingID = temp.TaggingID
			WHERE ccs.IsFirstTWTagging = 1 AND cus.CustID IS NULL AND temp.TaggingID IN (CONST_TWTAGGINGID_GROUPBETTING, CONST_TWTAGGINGID_HIGHREJECTED);
		END IF;

	ELSE
		SET lv_InsertedCount = 0;
		SET lv_UpdatedCount = 0;
		SET lv_IsAuto = 1;

		IF ip_InputFlowID = CONST_INPUTFLOWID_GENERAL_RESCAN_PACATEGORY THEN
			SET lv_IsRescan = 1;
		END IF;
		
		/*delete Normal/PotentialPA - IsKeepOldCateID = 0*/
		DELETE cls
		FROM CTS_DataCenter.CTSCustomerClassification AS cls
			INNER JOIN Temp_CTSCustomerClassification_Old AS temp_old ON temp_old.CustID = cls.CustID
																			AND temp_old.ExistCategoryID = cls.CategoryID
		WHERE temp_old.IsNew = 0 AND temp_old.IsRemove = 1;
		
		/*update PA/PotentialPA when change probation status*/
		UPDATE IGNORE CTS_DataCenter.CTSCustomerClassification AS cls
			INNER JOIN Temp_NewClassification AS temp ON cls.CustID = temp.CustID AND cls.CategoryID = temp.OldCategoryID 
																						AND temp.DataChangeType = 1
		SET 	cls.CTSCustID 			=  temp.CTSCustID
			,	cls.CategoryID 			=  temp.NewCategoryID
			, 	cls.LastModifiedDate 	=  lv_CurrentDateTime
			, 	cls.LastScannedDate 	=  DATE(lv_CurrentDateTime)
			,	cls.IsFromTW 			=   CASE WHEN temp.IsFromTW 		= 1 THEN temp.IsFromTW 			ELSE cls.IsFromTW 			END
			,	cls.IsFromCTS 			=   CASE WHEN temp.IsFromCTS 		= 1 THEN temp.IsFromCTS 		ELSE cls.IsFromCTS 			END
			,	cls.IsFromAI 			=   CASE WHEN temp.IsFromAI 		= 1 THEN temp.IsFromAI 			ELSE cls.IsFromAI 			END
			,	cls.IsFromTVS 			=   CASE WHEN temp.IsFromTVS 		= 1 THEN temp.IsFromTVS 		ELSE cls.IsFromTVS 			END
			,	cls.TVSRequestID		=   CASE WHEN IFNULL(cls.TVSRequestID,0) = 0 AND (temp.TVSRequestID > 0 OR (IFNULL(temp.TVSRequestID,0) = 0 AND temp.TVSIssueTypeID = 11)) 
														THEN temp.TVSRequestID	
												 ELSE cls.TVSRequestID END
			,	cls.SportType 			=   CASE WHEN IFNULL(cls.TVSRequestID,0) = 0 AND (temp.TVSRequestID > 0 OR (IFNULL(temp.TVSRequestID,0) = 0 AND temp.TVSIssueTypeID = 11))
														THEN temp.SportType	
												 ELSE cls.SportType	END
			,	cls.IsParlay 			=   CASE WHEN IFNULL(cls.TVSRequestID,0) = 0 AND (temp.TVSRequestID > 0 OR (IFNULL(temp.TVSRequestID,0) = 0 AND temp.TVSIssueTypeID = 11)) 
														THEN temp.IsTVSParlay
												 ELSE cls.IsParlay END
			,	cls.IssueTypeID			=   CASE WHEN IFNULL(cls.TVSRequestID,0) = 0 AND (temp.TVSRequestID > 0 OR (IFNULL(temp.TVSRequestID,0) = 0 AND temp.TVSIssueTypeID = 11)) 
														THEN temp.TVSIssueTypeID
												 ELSE cls.IssueTypeID END
			,	cls.IsFromImperva		=   CASE WHEN temp.IsFromImperva	= 1 THEN temp.IsFromImperva 	ELSE cls.IsFromImperva 		END
			,	cls.IsMarkedDirectly	=   CASE WHEN temp.IsMarkedDirectly	= 1 THEN temp.IsMarkedDirectly 	ELSE cls.IsMarkedDirectly 	END
			; 
			
		SET lv_UpdatedCount = FOUND_ROWS();
		
		/*update LicVIP*/
		UPDATE IGNORE CTS_DataCenter.CTSCustomerClassification AS cls
			INNER JOIN Temp_LicVIPCust AS tmpVip ON cls.CustID = tmpVip.CustID
		SET 	cls.CategoryID 	=  tmpVip.CategoryID
		WHERE cls.CategoryID IN (CONST_CATEID_LICVIPSUSPICIOUS,CONST_CATEID_LICVIPDANGEROUS);
		
		INSERT IGNORE INTO CTS_DataCenter.CTSCustomerClassification(
				CustID, CTSCustID, SubscriberID, RoleID, CategoryID, ParentID, CreatedDate, CreatedBy, LastModifiedDate
			, 	LastModifiedBy, LastScannedDate, IsMarkedDirectly, Remark, IsFromCTS, IsFromAI, IsFromImperva, IsFromTVS, IsFromTW
			, 	TVSRequestID, IsParlay, SportType, IssueTypeID)
		SELECT 	temp.CustID
			,	temp.CTSCustID
			, 	temp.SubscriberID
			, 	temp.RoleID
			, 	temp.NewCategoryGroupID AS CategoryID
			, 	temp.ParentID
			, 	CASE WHEN lv_IsRescan = 1 THEN temp.CreatedDate ELSE lv_CurrentDateTime END AS CreatedDate
			, 	temp.CreatedBy
			, 	lv_CurrentDateTime AS LastModifiedDate
			, 	temp.CreatedBy AS LastModifiedBy
			, 	DATE(lv_CurrentDateTime) AS LastScannedDate
			,	temp.IsMarkedDirectly
			,	temp.Remark
			,	temp.IsFromCTS
			,	temp.IsFromAI
			,	temp.IsFromImperva
			,	temp.IsFromTVS
			,	temp.IsFromTW
			,	temp.TVSRequestID
			,	temp.IsTVSParlay AS IsParlay
			,	temp.SportType
			,	temp.TVSIssueTypeID AS IssueTypeID
		FROM Temp_NewClassification AS temp 
		WHERE 	(temp.DataChangeType = 0 AND temp.IsDataChanged = 1) 
			OR 	(temp.IsFromOldPA 	= 1 AND lv_IsRescan = 0); /*temp.IsDataChanged = 0*/
		
		SET lv_InsertedCount = FOUND_ROWS();

		UPDATE Temp_NewClassification AS temp
			INNER JOIN CTS_DataCenter.CustomerCategory AS cat ON cat.CategoryID = temp.NewCategoryID
		SET temp.TargetCCForHistory =	CASE	WHEN temp.SpecialCC IS NOT NULL THEN temp.SpecialCC
												WHEN temp.IsLicenseeVIP = 1 AND cat.IsDangerProbation = 1 THEN CONST_CC_LICVIPSUSPICIOUS 
												WHEN temp.IsLicenseeVIP = 1 AND cat.IsDangerProbation = 0 THEN CONST_CC_LICVIPDANGEROUS 
												ELSE temp.TargetCC
										END;

		INSERT IGNORE INTO CTS_DataCenter.CTSCustomerClassification_History(
				CustID, CTSCustID, CategoryID, ParentID, LastModifiedDate, LastModifiedBy, ActionType
			, 	InsertDate, TargetCC, SourceTypeID, IsDataChanged, TargetDangerLevel1,TurnoverRM, WinlossRM, BetCount, ActiveDays
			, 	IsMarkedDirectly, Remark, TVSRequestID, IsFromTVS, IsFromTW, IsFromCTS, IsFromAI, IsFromImperva, IsParlay, SportType
			, 	IssueTypeID, RobotCounter, OldCategoryID, DWCategoryID, PerformanceTime)
		SELECT 	temp.CustID
			, 	temp.CTSCustID
			, 	temp.NewCategoryID AS CategoryID
			,	temp.ParentID
			, 	lv_CurrentDateTime AS LastModifiedDate
			, 	temp.CreatedBy AS LastModifiedBy
			, 	temp.ActionType
			, 	DATE(lv_CurrentDateTime) AS InsertDate
			, 	temp.TargetCCForHistory
			, 	(CASE	WHEN ccs.RemarkTemplateID IS NOT NULL THEN ccs.RemarkTemplateID
						WHEN temp.MatchID IS NOT NULL THEN CONST_REMARKID_AUTOMARKGB
						WHEN temp.GroupName IS NOT NULL THEN CONST_REMARKID_PABYASSOCIATEDGROUP
						WHEN lv_IsRescan = 1 AND temp.IsRobot = 1 THEN CONST_REMARKID_RESCANROBOT
						WHEN temp.IsMarkedDirectly = 1 AND temp.IsRobot = 1 THEN CONST_REMARKID_ROBOTMARKEDDIRECTLY						
						WHEN temp.IsMarkedDirectly = 1 THEN CONST_REMARKID_PAMARKEDDIRECTLY 
						WHEN temp.IsMarkedDirectly = 0 THEN CONST_REMARKID_PAAFFECTEDBYUPLINE END) AS SourceTypeID
			,  	temp.IsDataChanged
			,	temp.TargetDangerLevel AS TargetDangerLevel1
			,	temp.TurnoverRM
			,	temp.WinlossRM
			, 	temp.BetCount
			, 	temp.ActiveDays
			,	temp.IsMarkedDirectly
			,	temp.Remark
			,	temp.TVSRequestID
			,	temp.IsFromTVS
			,	temp.IsFromTW
			,	temp.IsFromCTS
			,	temp.IsFromAI
			,	temp.IsFromImperva
			,	temp.IsTVSParlay AS IsParlay
			,	temp.SportType
			,	temp.TVSIssueTypeID AS IssueTypeID
			,	temp.TWRobotCounter AS RobotCounter
			,	temp.OldCategoryID
			,	temp.DWCategoryID
			,	temp.PerformanceTime
		FROM Temp_NewClassification AS temp
			LEFT JOIN CTS_DataCenter.CustomerCategorySettings AS ccs ON ccs.CategoryID = temp.NewCategoryID 
		WHERE temp.IsDataChanged = 1 
		ORDER BY temp.LastModifiedDate ASC, temp.NewCategoryID ASC;
		
		INSERT INTO CTS_DataCenter.CTSCustomerClassification_Log(
				CustID, CTSCustID, CategoryID, ParentID, LastModifiedDate, LastModifiedBy, ActionType, IsAuto, InsertDate
			, 	TargetCC, SourceTypeID, IsDataChanged,TargetDangerLevel1,TurnoverRM, WinlossRM, BetCount, ActiveDays, IsMarkedDirectly, Remark
			, 	TVSRequestID, IsFromTVS, IsFromTW, IsFromCTS, IsFromAI, IsFromImperva, IsParlay, SportType, IssueTypeID, RobotCounter
			, 	OldCategoryID, DWCategoryID, PerformanceTime)
		SELECT 	temp.CustID
			,	temp.CTSCustID
			,	temp.NewCategoryID
			,	temp.ParentID
			,	lv_CurrentDateTime AS LastModifiedDate
			,	temp.CreatedBy AS LastModifiedBy
			,	temp.ActionType
			,	lv_IsAuto
			,	DATE(lv_CurrentDateTime) AS InsertDate
			,	temp.TargetCCForHistory
			, 	(CASE	WHEN ccs.RemarkTemplateID IS NOT NULL THEN ccs.RemarkTemplateID
						WHEN temp.MatchID IS NOT NULL THEN CONST_REMARKID_AUTOMARKGB
						WHEN temp.GroupName IS NOT NULL THEN CONST_REMARKID_PABYASSOCIATEDGROUP
						WHEN lv_IsRescan = 1 AND temp.IsRobot = 1 THEN CONST_REMARKID_RESCANROBOT
						WHEN temp.IsMarkedDirectly = 1 AND temp.IsRobot = 1 THEN CONST_REMARKID_ROBOTMARKEDDIRECTLY						
						WHEN temp.IsMarkedDirectly = 1 THEN CONST_REMARKID_PAMARKEDDIRECTLY 
						WHEN temp.IsMarkedDirectly = 0 THEN CONST_REMARKID_PAAFFECTEDBYUPLINE END) AS SourceTypeID
			,	temp.IsDataChanged
			,	temp.TargetDangerLevel AS TargetDangerLevel1
			,	temp.TurnoverRM
			,	temp.WinlossRM
			,	temp.BetCount
			,	temp.ActiveDays
			,	temp.IsMarkedDirectly
			,	temp.Remark
			,	temp.TVSRequestID
			,	temp.IsFromTVS
			,	temp.IsFromTW
			,	temp.IsFromCTS
			,	temp.IsFromAI
			,	temp.IsFromImperva
			,	temp.IsTVSParlay AS IsParlay
			,	temp.SportType
			,	temp.TVSIssueTypeID AS IssueTypeID
			,	temp.TWRobotCounter AS RobotCounter
			,	temp.OldCategoryID
			,	temp.DWCategoryID
			,	temp.PerformanceTime
		FROM Temp_NewClassification AS temp
			LEFT JOIN CTS_DataCenter.CustomerCategorySettings AS ccs ON ccs.CategoryID = temp.NewCategoryID ;
		
	/*Insert into source tables*/
	IF (IFNULL(lv_InsertedCount,0) > 0 OR IFNULL(lv_UpdatedCount,0) > 0) THEN

		IF ip_InputFlowID = CONST_INPUTFLOWID_GENERAL_INSERT_PAREASON 
			AND (EXISTS (SELECT 1 
						FROM Temp_NewClassification 
						WHERE IsFromTVS = 1 AND (lv_InsertedCount > 0 OR lv_UpdatedCount > 0)))THEN
			
			INSERT INTO CTS_DataCenter.TVSVoidRequest (
					TVSRequestID,CustID,CategoryID,TVSReasonID,IssueTypeID,CreatedBy,IsParlay,SportType
				,	RequestTypeID,CreatedDate,InsertedTime)
			SELECT 	temp.TVSRequestID,temp.CustID,temp.NewCategoryID,temp.TVSReasonID,temp.TVSIssueTypeID,temp.CreatedBy,temp.IsTVSParlay,temp.SportType
				,	CASE WHEN temp.IsRobot = 1 THEN CONST_TVSREQUESTTYPEID_ROBOT ELSE CONST_TVSREQUESTTYPEID_PA END AS RequestTypeID
				,	lv_CurrentDateTime AS CreatedDate
				,	CURRENT_TIMESTAMP(3) AS InsertedTime
			FROM Temp_NewClassification AS temp
				LEFT JOIN CTS_DataCenter.TVSVoidRequest AS h ON h.CustID = temp.CustID AND h.CategoryID = temp.NewCategoryID AND h.IsDisabled = 0
			WHERE temp.IsFromTVS = 1 
				AND h.CustID IS NULL
				AND 1 = (CASE WHEN lv_InsertedCount > 0 THEN (CASE WHEN (temp.IsFromOldPA = 1 AND lv_IsRescan = 0) OR temp.IsDataChanged = 1 THEN 1 ELSE 0 END)
							  WHEN lv_UpdatedCount > 0 AND temp.IsDataChanged = 1 THEN (CASE WHEN lv_IsRescan = 1 OR DataChangeType = 1 THEN 1 ELSE 0 END)
							  ELSE 0 END);
		END IF;
		
		IF ip_InputFlowID = CONST_INPUTFLOWID_GENERAL_INSERT_PACATEGORY THEN
			IF EXISTS (SELECT 1 
						FROM Temp_NewClassification 
						WHERE IsFromTW = 1 AND IsRobot = 1
							AND ( lv_InsertedCount > 0 OR lv_UpdatedCount > 0)) THEN
				
				INSERT INTO CTS_DataCenter.TWRobotUser (CustID,CategoryID,RobotCounter,CreatedDate,InsertedTime)
				SELECT 	temp.CustID
					,	temp.NewCategoryID
					,	temp.TWRobotCounter
					,	lv_CurrentDateTime AS CreatedDate
					,	CURRENT_TIMESTAMP(3) AS InsertedTime
				FROM Temp_NewClassification AS temp
					LEFT JOIN CTS_DataCenter.TWRobotUser AS h ON h.CustID = temp.CustID AND h.CategoryID = temp.NewCategoryID AND h.IsDisabled = 0
				WHERE temp.IsFromTW = 1 AND temp.IsRobot = 1
					AND h.CustID IS NULL
					AND 1 = (CASE WHEN lv_InsertedCount > 0 THEN (CASE WHEN (temp.IsFromOldPA = 1 AND lv_IsRescan = 0) OR temp.IsDataChanged = 1 THEN 1 ELSE 0 END)
								  WHEN lv_UpdatedCount > 0 AND temp.IsDataChanged = 1 THEN (CASE WHEN lv_IsRescan = 1 OR DataChangeType = 1 THEN 1 ELSE 0 END)
								  ELSE 0 END);
			END IF;
			
			IF EXISTS (SELECT 1 
						FROM Temp_NewClassification 
						WHERE IsFromCTS = 1 AND IsRobot = 1
							AND ( lv_InsertedCount > 0 OR lv_UpdatedCount > 0)) THEN
					
				INSERT INTO CTS_DataCenter.CTSRobotUser (CustID,CategoryID,Remark,CreatedDate,InsertedTime)
				SELECT 	temp.CustID
					,	temp.NewCategoryID
					,	temp.Remark
					,	lv_CurrentDateTime AS CreatedDate
					,	CURRENT_TIMESTAMP(3) AS InsertedTime
				FROM Temp_NewClassification AS temp
					LEFT JOIN CTS_DataCenter.CTSRobotUser AS h ON h.CustID = temp.CustID AND h.CategoryID = temp.NewCategoryID AND h.IsDisabled = 0
				WHERE temp.IsFromCTS = 1 AND temp.IsRobot = 1
					AND h.CustID IS NULL
					AND 1 = (CASE WHEN lv_InsertedCount > 0 THEN (CASE WHEN (temp.IsFromOldPA = 1 AND lv_IsRescan = 0) OR temp.IsDataChanged = 1 THEN 1 ELSE 0 END)
								  WHEN lv_UpdatedCount > 0 AND temp.IsDataChanged = 1 THEN (CASE WHEN lv_IsRescan = 1 OR DataChangeType = 1 THEN 1 ELSE 0 END)
								  ELSE 0 END);
					
			END IF;	

		END IF;	
		
	END IF;
		
	END IF;

	/*Set IsDisabled = 1 for Special Lic Sub source table */
	SELECT cat.CustomerClassPriority
	INTO lv_CustomerClassPriority
	FROM CTS_DataCenter.CustomerCategory AS cat
	WHERE cat.CategoryID = CONST_CATEID_NEWLICSUB;

	IF EXISTS (SELECT 1
				FROM Temp_NewClassification AS temp
					INNER JOIN CTS_DataCenter.CustomerCategory AS cat ON cat.CategoryID = temp.NewCategoryID
					INNER JOIN CTS_DataCenter.Customer_SpecialLicSubCC AS sls ON sls.CustID = temp.CustID
				WHERE sls.IsDisabled = 0 AND cat.CustomerClassPriority < lv_CustomerClassPriority
					AND NOT EXISTS (SELECT 1 FROM CTS_DataCenter.CTSCustomerClassification AS cls 
									WHERE cls.CustID = temp.CustID AND cls.ParentID = CONST_PARENTID_WRAPPER)) THEN
		
		UPDATE CTS_DataCenter.Customer_SpecialLicSubCC AS sls
			INNER JOIN Temp_NewClassification AS temp ON sls.CustID = temp.CustID
			INNER JOIN CTS_DataCenter.CustomerCategory AS cat ON cat.CategoryID = temp.NewCategoryID
		SET sls.IsDisabled = 1
		WHERE sls.IsDisabled = 0 AND cat.CustomerClassPriority < lv_CustomerClassPriority
			AND NOT EXISTS (SELECT 1 FROM CTS_DataCenter.CTSCustomerClassification AS cls 
							WHERE cls.CustID = temp.CustID AND cls.ParentID = CONST_PARENTID_WRAPPER);

	END IF;
    
	#=================CONSIDERABLE_BEGIN: GET PA AFTER==================   
	INSERT IGNORE INTO Temp_PACustEnd(CustID, Recommend)
    SELECT	cls.CustID
		,	cus.Recommend
	FROM Temp_NewClassification AS temp 
		INNER JOIN CTS_DataCenter.CTSCustomer AS cus ON cus.CustID = temp.CustID AND cus.IsLicensee = 0
		INNER JOIN CTS_DataCenter.CTSCustomerClassification AS cls ON cls.CustID = cus.CustID
		INNER JOIN CTS_DataCenter.CustomerCategorySettings AS cs ON cs.CategoryID = cls.CategoryID AND cs.FlowConsiderableDangerScan = 1
        INNER JOIN CTS_DataCenter.CustomerCategory AS cc ON cc.CategoryID = cs.CategoryID AND cc.IsActive = 1 	
	WHERE cls.ParentID = CONST_PARENTID_PA
		AND NOT EXISTS (SELECT 1			
						FROM CTS_DataCenter.CTSCustomerClassification AS cls2	
							INNER JOIN CTS_DataCenter.CustomerCategory AS cc2 ON cc2.CategoryID = cls2.CategoryID AND cc2.IsActive = 1				
						WHERE cls.CustID = cls2.CustID
							AND cls2.ParentID <> CONST_PARENTID_WRAPPER
							AND cc.CustomerClassPriority > cc2.CustomerClassPriority
							AND cc2.ParentID <> cc.ParentID);       

    INSERT INTO Temp_PAAgent(CustID)
    SELECT DISTINCT en.Recommend
	FROM Temp_PACustEnd AS en
		LEFT JOIN Temp_PACustStart AS st ON st.CustID = en.CustID 
	WHERE st.CustID IS NULL;
    
    INSERT IGNORE INTO Temp_PAAgent(CustID)
    SELECT DISTINCT st.Recommend
	FROM Temp_PACustStart AS st
		LEFT JOIN Temp_PACustEnd AS en ON en.CustID = st.CustID 
	WHERE en.CustID IS NULL;
    
    SELECT GROUP_CONCAT(tmp.CustID)
    INTO lv_ConsiderableDangerAgentList 
	FROM Temp_PAAgent AS tmp;
    
    IF (lv_ConsiderableDangerAgentList IS NOT NULL) THEN		
		CALL CTS_DataCenter.CTS_DC_CustClassificationAgency_CDQueue_Insert(CONST_CONSIDERABLEDANGERQUEUE_SCANTYPE, lv_ConsiderableDangerAgentList);
    END IF;
    
   #=================CONSIDERABLE_END: GET PA AFTER==================      

END$$
DELIMITER ;