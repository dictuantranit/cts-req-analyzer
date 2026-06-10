/*<info serverAlias="CTSMain-CTS_DataCenter" databaseType="2" executers="ctsServiceAdmin" isFunction="0" isNested="1"></info>*/
DROP PROCEDURE IF EXISTS `CTS_DC_CustClassification_Remove_Complete`;

DELIMITER $$
CREATE DEFINER=`ctsOwner`@`%` PROCEDURE `CTS_DC_CustClassification_Remove_Complete`(
		IN	ip_InputFlowID			INT 
	,	IN	ip_FromAction			TINYINT
	,	IN	ip_UplineRoleID			INT
	,	IN	ip_IsFromQueue			TINYINT(1)
	,	IN	ip_CustInfo				JSON
)
SQL SECURITY INVOKER
BEGIN
/*
		Created:	20240618@Victoria.Le
		Task:		Remove main customer categories for Customer Classification
		DB:			CTS_DataCenter
		
		Revisions: 
			-	20240618@Victoria.Le: 		Initial Writing [Redmine ID: #205317]
            - 	20241210@Casey.Huynh:		New Robot AI-Bot Login Pattern, Update Disable for Member Only [Redmine ID: #214655]
			- 	20250725@Casey.Huynh:		Agent CC, Insert Considerable Agency Queue [Redmine ID: #219679]
            
		Param's Expanation:
			- CTS_DC_CustClassification_Remove_Complete (225,'');
*/

	DECLARE CONST_PARENTID_VVIP 							INT;
	DECLARE CONST_PARENTID_WRAPPER 							INT;
	DECLARE CONST_PARENTID_PA	 							INT;
	DECLARE CONST_CATEID_SPECIALCC 							INT;
	DECLARE CONST_CATEID_LICVIPDANGEROUS 					INT;
	DECLARE CONST_CATEID_LICVIPSUSPICIOUS 					INT;
	DECLARE CONST_CATEID_LICBA			 					INT;
	DECLARE CONST_INPUTFLOWID_GENERAL_REMOVE_VVIP 			INT;
	DECLARE CONST_INPUTFLOWID_GENERAL_REMOVE_SPECIALCC		INT;
	DECLARE CONST_INPUTFLOWID_GENERAL_REMOVE_LICVIP			INT;
	DECLARE CONST_INPUTFLOWID_GENERAL_REMOVE_LICBA 			INT;
	DECLARE CONST_INPUTFLOWID_GENERAL_REMOVE_PA 			INT;
    
	DECLARE	CONST_ROLEID_MEMBER							INT DEFAULT 1;

	DECLARE CONST_ACTIONTYPE_REMOVE 						INT DEFAULT 2;
	DECLARE CONST_ACTIONTYPE_UNMARKPA 						INT DEFAULT 4;
    
	DECLARE CONST_SOURCETYPE_CUSTOMERCLASS_REMOVE_MANUAL	INT DEFAULT 12;
	DECLARE CONST_SOURCETYPE_VVIP_UNMARK_MANUAL				INT DEFAULT 14;
	DECLARE CONST_SOURCETYPE_VVIP_UNMARK_AFFECTED_SUPER		INT DEFAULT 27;
	DECLARE CONST_SOURCETYPE_VVIP_UNMARK_AFFECTED_MASTER	INT DEFAULT 28;
	DECLARE CONST_SOURCETYPE_VVIP_UNMARK_AFFECTED_AGENT		INT DEFAULT 29;
	DECLARE CONST_SOURCETYPE_PA_UNMARK_DIRECTLY				INT DEFAULT 33;
	DECLARE CONST_SOURCETYPE_PA_UNMARK_AFFECTED_UPLINE		INT DEFAULT 34;
	DECLARE CONST_SOURCETYPE_NOREASON_DETAILS				INT DEFAULT 38;
    
    DECLARE CONST_CONSIDERABLEDANGERQUEUE_SCANTYPE			TINYINT	DEFAULT 1;
	
	DECLARE lv_SourceTypeID									INT;
	DECLARE lv_CurrentDateTime 								DATETIME DEFAULT CURRENT_TIMESTAMP();
	DECLARE lv_IsAuto										TINYINT(1);
	DECLARE lv_IsDataChanged								TINYINT(1);
	DECLARE lv_TargetCC										INT;
	DECLARE lv_CCPriority									SMALLINT UNSIGNED;  
    DECLARE lv_ConsiderableDangerAgentList					TEXT;

	SET CONST_PARENTID_VVIP 								= CTS_DC_CategoryTypeParent_Get ('CONST_PARENTID_VVIP');
	SET CONST_PARENTID_WRAPPER 								= CTS_DC_CategoryTypeParent_Get ('CONST_PARENTID_WRAPPER');
	SET CONST_PARENTID_PA	 								= CTS_DC_CategoryTypeParent_Get ('CONST_PARENTID_PA');
	SET CONST_CATEID_SPECIALCC								= CTS_DC_CategoryTypeParent_Get ('CONST_CATEID_SPECIALCC');
	SET CONST_CATEID_LICVIPDANGEROUS						= CTS_DC_CategoryTypeParent_Get ('CONST_CATEID_LICVIPDANGEROUS');
	SET CONST_CATEID_LICVIPSUSPICIOUS						= CTS_DC_CategoryTypeParent_Get ('CONST_CATEID_LICVIPSUSPICIOUS');
	SET CONST_CATEID_LICBA									= CTS_DC_CategoryTypeParent_Get ('CONST_CATEID_LICBA');
	SET CONST_INPUTFLOWID_GENERAL_REMOVE_VVIP				= CTS_DC_CategoryTypeParent_Get ('CONST_INPUTFLOWID_GENERAL_REMOVE_VVIP');
	SET CONST_INPUTFLOWID_GENERAL_REMOVE_SPECIALCC			= CTS_DC_CategoryTypeParent_Get ('CONST_INPUTFLOWID_GENERAL_REMOVE_SPECIALCC');
	SET CONST_INPUTFLOWID_GENERAL_REMOVE_LICVIP				= CTS_DC_CategoryTypeParent_Get ('CONST_INPUTFLOWID_GENERAL_REMOVE_LICVIP');
	SET CONST_INPUTFLOWID_GENERAL_REMOVE_LICBA				= CTS_DC_CategoryTypeParent_Get ('CONST_INPUTFLOWID_GENERAL_REMOVE_LICBA');
	SET CONST_INPUTFLOWID_GENERAL_REMOVE_PA					= CTS_DC_CategoryTypeParent_Get ('CONST_INPUTFLOWID_GENERAL_REMOVE_PA');
	
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
	FROM Temp_Customer AS temp 
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
							AND cc2.ParentID <> cc.ParentID)
    ;
    
    INSERT IGNORE INTO Temp_PACustStart(CustID, Recommend)
    SELECT	cls.CustID
		,	cus.Recommend
	FROM Temp_CustomerClassification AS temp 
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
							AND cc2.ParentID <> cc.ParentID)
    ;

    #=================CONSIDERABLE_END: GET PA BEFORE==================    
    
	IF ip_InputFlowID = CONST_INPUTFLOWID_GENERAL_REMOVE_VVIP THEN
		SET lv_IsAuto 				= 0;
		SET lv_TargetCC				= -1;
		SET lv_IsDataChanged		= 1;
		
		SET lv_SourceTypeID = 	CASE 	WHEN ip_FromAction = 1 THEN CONST_SOURCETYPE_VVIP_UNMARK_MANUAL
										WHEN ip_FromAction = 3 AND ip_UplineRoleID = 4 THEN CONST_SOURCETYPE_VVIP_UNMARK_AFFECTED_SUPER
										WHEN ip_FromAction = 3 AND ip_UplineRoleID = 3 THEN CONST_SOURCETYPE_VVIP_UNMARK_AFFECTED_MASTER
										WHEN ip_FromAction = 3 AND ip_UplineRoleID = 2 THEN CONST_SOURCETYPE_VVIP_UNMARK_AFFECTED_AGENT
								END;
								
		DELETE cls
		FROM CTS_DataCenter.CTSCustomerClassification AS cls
			INNER JOIN Temp_CustomerClassification AS temp ON temp.CustID = cls.CustID
																	AND temp.CategoryID = cls.CategoryID
																	AND temp.IsExistVVIP = 1;
		
		INSERT INTO CTS_DataCenter.CTSCustomerClassification_History(
				CustID, CTSCustID, CategoryID, ParentID, LastModifiedDate, LastModifiedBy, ActionType, IsAuto
			, 	InsertDate, TargetCC, SourceTypeID, IsDataChanged)
		SELECT 	temp.CustID
			, 	temp.CTSCustID
			,   temp.CategoryID
			,   CONST_PARENTID_VVIP AS ParentID
			, 	lv_CurrentDateTime AS LastModifiedDate
			, 	temp.CreatedBy AS LastModifiedBy
			,   CONST_ACTIONTYPE_REMOVE AS ActionType
			,   lv_IsAuto AS IsAuto
			,   DATE(lv_CurrentDateTime) AS InsertDate
			,   lv_TargetCC AS TargetCC
			,   lv_SourceTypeID AS SourceTypeID
			,	lv_IsDataChanged AS IsDataChanged
		FROM Temp_CustomerClassification AS temp
		WHERE temp.IsExistVVIP = 1;
		
		INSERT INTO CTS_DataCenter.CTSCustomerClassification_Log(
				CustID, CTSCustID, CategoryID, ParentID, LastModifiedDate, LastModifiedBy, ActionType, IsAuto
			, 	InsertDate, TargetCC, SourceTypeID, IsDataChanged)
		SELECT 	temp.CustID
			, 	temp.CTSCustID
			,   temp.CategoryID
			,   CONST_PARENTID_VVIP AS ParentID
			, 	lv_CurrentDateTime AS LastModifiedDate
			, 	temp.CreatedBy AS LastModifiedBy
			,   CONST_ACTIONTYPE_REMOVE AS ActionType
			,   lv_IsAuto AS IsAuto
			,   DATE(lv_CurrentDateTime) AS InsertDate
			,   lv_TargetCC AS TargetCC
			,   lv_SourceTypeID AS SourceTypeID
			,	lv_IsDataChanged AS IsDataChanged
		FROM Temp_CustomerClassification AS temp
		WHERE temp.IsExistVVIP = 1;	

	ELSEIF ip_InputFlowID = CONST_INPUTFLOWID_GENERAL_REMOVE_SPECIALCC THEN 
		SET lv_IsAuto 				= 0;
		SET lv_TargetCC				= -1;
		SET lv_IsDataChanged		= 1;
		SET lv_SourceTypeID			= CONST_SOURCETYPE_CUSTOMERCLASS_REMOVE_MANUAL;
	
		DELETE s
		FROM CTS_DataCenter.SpecialCustomerClass AS s
			INNER JOIN Temp_CustomerClassification AS temp ON temp.CTSCustID = s.CTSCustID
		WHERE s.CreatedFromFunction = 1;
		
		INSERT INTO CTS_DataCenter.SpecialCustomerClass_History(
				CTSCustID, CustID, RootCTSCustID, SubscriberID, CustomerClass, CreatedBy
			, 	CreatedDate, LastModifiedBy, LastModifiedDate, CreatedFromFunction, Remark
			, 	ActionType)
		SELECT 	temp.CTSCustID
			,	temp.CustID
			,	temp.CTSCustID AS RootCTSCustID
			,	temp.SubscriberID
			,	lv_TargetCC AS CustomerClass
			,	temp.CreatedBy
			,	lv_CurrentDateTime AS CreatedDate
			,	temp.CreatedBy AS LastModifiedBy
			,	lv_CurrentDateTime AS LastModifiedDate
			,   1 AS CreatedFromFunction
			,	temp.Remark
			,	CONST_ACTIONTYPE_REMOVE AS ActionType
		FROM Temp_CustomerClassification AS temp;
		
		DELETE cls
		FROM CTS_DataCenter.CTSCustomerClassification AS cls
			INNER JOIN Temp_CustomerClassification AS temp ON temp.CustID = cls.CustID
																AND cls.CategoryID = CONST_CATEID_SPECIALCC;
		
		INSERT INTO CTS_DataCenter.CTSCustomerClassification_History(
				CustID, CTSCustID, ParentID, CategoryID, LastModifiedDate, LastModifiedBy, ActionType, IsAuto
			, 	InsertDate, TargetCC, SourceTypeID, IsDataChanged, Remark)
		SELECT  temp.CustID
			,   temp.CTSCustID
			,   CONST_PARENTID_WRAPPER AS ParentID
			,   CONST_CATEID_SPECIALCC AS CategoryID
			,   lv_CurrentDateTime AS LastModifiedDate
			,   temp.CreatedBy
			,   CONST_ACTIONTYPE_REMOVE AS ActionType
			,   lv_IsAuto AS IsAuto
			,   DATE(lv_CurrentDateTime) AS InsertDate
			,   lv_TargetCC AS TargetCC
			,   lv_SourceTypeID AS SourceTypeID
			,   lv_IsDataChanged AS IsDataChanged
			,	temp.Remark
		FROM Temp_CustomerClassification AS temp;
		
		INSERT INTO CTS_DataCenter.CTSCustomerClassification_Log(
				CustID, CTSCustID, ParentID, CategoryID, LastModifiedDate, LastModifiedBy, ActionType, IsAuto
			, 	InsertDate, TargetCC, SourceTypeID, IsDataChanged, Remark)
		SELECT  temp.CustID
			,   temp.CTSCustID
			,   CONST_PARENTID_WRAPPER AS ParentID
			,   CONST_CATEID_SPECIALCC AS CategoryID
			,   lv_CurrentDateTime AS LastModifiedDate
			,   temp.CreatedBy AS LastModifiedBy
			,   CONST_ACTIONTYPE_REMOVE AS ActionType
			,   lv_IsAuto AS IsAuto
			,   DATE(lv_CurrentDateTime) AS InsertDate
			,   lv_TargetCC AS TargetCC
			,   lv_SourceTypeID AS SourceTypeID
			,   lv_IsDataChanged AS IsDataChanged
			,	temp.Remark
		FROM Temp_CustomerClassification AS temp;	
		
	ELSEIF ip_InputFlowID = CONST_INPUTFLOWID_GENERAL_REMOVE_LICVIP THEN 
		SET lv_IsAuto 				= 0;
		SET lv_IsDataChanged		= 0;
		SET lv_SourceTypeID			= CONST_SOURCETYPE_NOREASON_DETAILS;
		
		SELECT  cc.CustomerClassPriority
		INTO lv_CCPriority
		FROM CTS_DataCenter.CustomerCategory AS cc
		WHERE cc.CategoryID = CONST_CATEID_LICVIPDANGEROUS;
		
		INSERT INTO Temp_CustomerClassification (
				CustID, CTSCustID, SubscriberID, CreatedBy, IsLicenseeVIP
			, 	CategoryID, IsDangerProbation, CustomerClassPriority, CustomerClass)
		WITH CTE_LastCategory AS (
		SELECT 	temp.CustID
			,	temp.CTSCustID
			,	temp.SubscriberID
			,	temp.CreatedBy
			,	temp.IsLicenseeVIP
			,	tmpLastCat.CategoryID
			,	tmpLastCat.CustomerClassPriority
			,	tmpLastCat.IsDangerProbation
			,	tmpLastCat.CustomerClass
		FROM Temp_Customer AS temp,
			LATERAL (
						SELECT cls.CategoryID, cc.CustomerClassPriority, cc.IsDangerProbation, cc.CustomerClass 
						FROM CTS_DataCenter.CTSCustomerClassification AS cls
							LEFT JOIN CTS_DataCenter.CustomerCategory AS cc ON cc.CategoryID = cls.CategoryID
																				AND cc.CategoryID <> CONST_CATEID_SPECIALCC
																				AND cc.CustomerClassPriority < lv_CCPriority
						WHERE cls.CustID = temp.CustID
						ORDER BY cls.CustID, cls.LastModifiedDate DESC
						LIMIT 1) AS tmpLastCat)
		SELECT 	cte.CustID
			,	cte.CTSCustID
			,	cte.SubscriberID
			,	cte.CreatedBy
			,	cte.IsLicenseeVIP
			,	cte.CategoryID
			,	cte.IsDangerProbation
			,	cte.CustomerClassPriority
			,	cte.CustomerClass
		FROM CTE_LastCategory AS cte;  

		INSERT IGNORE INTO Temp_CustomerClassification (
				CustID, CTSCustID, SubscriberID, CreatedBy, IsLicenseeVIP
			, 	CategoryID, IsDangerProbation, CustomerClassPriority, CustomerClass)
		SELECT 	temp.CustID
			,	temp.CTSCustID
			,	temp.SubscriberID
			,	temp.CreatedBy
			,	temp.IsLicenseeVIP
			,	cc.CategoryID
			,	cc.IsDangerProbation
			,	cc.CustomerClassPriority
			,	cc.CustomerClass
		FROM Temp_Customer AS temp
			INNER JOIN CTS_DataCenter.SpecialCustomerClass AS sc ON sc.CustID = temp.CustID
			INNER JOIN CTS_DataCenter.CustomerCategory AS cc ON sc.CustomerClass = cc.CustomerClass;
		
		UPDATE Temp_CustomerClassification AS temp
			INNER JOIN CTS_DataCenter.SpecialCustomerClass AS sc ON sc.CustID = temp.CustID
		SET temp.CustomerClassPriority = -1
		WHERE temp.CustomerClassPriority IS NULL;
		
		UPDATE Temp_CustomerClassification AS temp
		SET temp.IsReturnData = 1
		WHERE temp.CustomerClassPriority > lv_CCPriority 
			OR temp.CustomerClassPriority IS NULL;
		
		UPDATE CTS_DataCenter.CTSCustomer AS cus
			INNER JOIN Temp_Customer AS temp ON cus.CTSCustID = temp.CTSCustID
		SET 	cus.IsLicenseeVIP = 0
			, 	cus.ModifiedTime = lv_CurrentDateTime
		WHERE cus.IsLicenseeVIP <> 0;
		
		DELETE del
		FROM CTS_DataCenter.CTSCustomerClassification AS del
			INNER JOIN Temp_CustomerClassification AS temp ON del.CustID = temp.CustID
		WHERE del.CategoryID IN (CONST_CATEID_LICVIPDANGEROUS,CONST_CATEID_LICVIPSUSPICIOUS);
		
		INSERT INTO CTS_DataCenter.CTSCustomerClassification_Log(
				CustID, CTSCustID, CategoryID, ParentID ,LastModifiedDate, LastModifiedBy, ActionType
			, 	IsAuto, InsertDate, TargetCC, SourceTypeID, IsDataChanged, IsMarkedDirectly)
		SELECT 	temp.CustID
			, 	temp.CTSCustID
			, 	(CASE WHEN temp.IsDangerProbation = 1 THEN CONST_CATEID_LICVIPSUSPICIOUS 
					  ELSE CONST_CATEID_LICVIPDANGEROUS END) AS CategoryID
			, 	CONST_PARENTID_WRAPPER AS ParentID
			, 	lv_CurrentDateTime AS LastModifiedDate
			, 	temp.CreatedBy AS LastModifiedBy
			,	CONST_ACTIONTYPE_REMOVE AS ActionType
			,	lv_IsAuto AS IsAuto
			,   DATE(lv_CurrentDateTime) AS InsertDate
			,   temp.CustomerClass AS TargetCC
			,   lv_SourceTypeID AS SourceTypeID
			,	lv_IsDataChanged AS IsDataChanged
			,	1 AS IsMarkedDirectly
		FROM Temp_CustomerClassification AS temp;
		
	ELSEIF ip_InputFlowID = CONST_INPUTFLOWID_GENERAL_REMOVE_LICBA THEN
		SET lv_IsAuto 				= 0;
		SET lv_IsDataChanged		= 0;
		SET lv_SourceTypeID			= CONST_SOURCETYPE_NOREASON_DETAILS;
		
		SELECT cc.CustomerClassPriority
		INTO lv_CCPriority
		FROM CTS_DataCenter.CustomerCategory AS cc
		WHERE cc.CategoryID = CONST_CATEID_LICBA;

		INSERT INTO Temp_CustomerClassification (
				CustID, CTSCustID, SubscriberID, CreatedBy, IsLicenseeVIP
			, 	CategoryID, IsDangerProbation, CustomerClassPriority, CustomerClass)
		WITH CTE_LastCategory AS (
		SELECT 	temp.CustID
			,	temp.CTSCustID
			,	temp.SubscriberID
			,	temp.CreatedBy
			,	temp.IsLicenseeVIP
			,	tmpLastCat.CategoryID
			,	tmpLastCat.CustomerClassPriority
			,	tmpLastCat.IsDangerProbation
			,	tmpLastCat.CustomerClass
		FROM Temp_Customer AS temp,
			LATERAL (
						SELECT cls.CategoryID, cc.CustomerClassPriority, cc.IsDangerProbation, cc.CustomerClass 
						FROM CTS_DataCenter.CTSCustomerClassification AS cls
							LEFT JOIN CTS_DataCenter.CustomerCategory AS cc ON cc.CategoryID = cls.CategoryID
																				AND cc.CategoryID <> CONST_CATEID_SPECIALCC
																				AND cc.CustomerClassPriority < lv_CCPriority
						WHERE cls.CustID = temp.CustID
						ORDER BY cls.CustID, cls.LastModifiedDate DESC
						LIMIT 1) AS tmpLastCat)
		SELECT 	cte.CustID
			,	cte.CTSCustID
			,	cte.SubscriberID
			,	cte.CreatedBy
			,	cte.IsLicenseeVIP
			,	cte.CategoryID
			,	cte.IsDangerProbation
			,	cte.CustomerClassPriority
			,	cte.CustomerClass
		FROM CTE_LastCategory AS cte;  
		
		INSERT IGNORE INTO Temp_CustomerClassification (
				CustID, CTSCustID, SubscriberID, CreatedBy, IsLicenseeVIP
			, 	CategoryID, IsDangerProbation, CustomerClassPriority, CustomerClass)
		SELECT 	temp.CustID
			,	temp.CTSCustID
			,	temp.SubscriberID
			,	temp.CreatedBy
			,	temp.IsLicenseeVIP
			,	cc.CategoryID
			,	cc.IsDangerProbation
			,	cc.CustomerClassPriority
			,	cc.CustomerClass
		FROM Temp_Customer AS temp
			INNER JOIN CTS_DataCenter.SpecialCustomerClass AS sc ON sc.CustID = temp.CustID
			INNER JOIN CTS_DataCenter.CustomerCategory AS cc ON sc.CustomerClass = cc.CustomerClass;
		
		UPDATE Temp_CustomerClassification AS temp
			INNER JOIN CTS_DataCenter.SpecialCustomerClass AS sc ON sc.CustID = temp.CustID
		SET temp.CustomerClassPriority = -1
		WHERE temp.CustomerClassPriority IS NULL;
		
		UPDATE Temp_CustomerClassification AS temp
		SET temp.IsReturnData = 1
		WHERE temp.CustomerClassPriority > lv_CCPriority 
			OR temp.CustomerClassPriority IS NULL;
		
		UPDATE CTS_DataCenter.CTSCustomer AS cus
			INNER JOIN Temp_Customer AS temp ON cus.CTSCustID = temp.CTSCustID
		SET 	cus.IsLicenseeBA = 0
			, 	cus.ModifiedTime = lv_CurrentDateTime
		WHERE cus.IsLicenseeBA <> 0;
		
		DELETE del
		FROM CTS_DataCenter.CTSCustomerClassification AS del
			INNER JOIN Temp_CustomerClassification AS temp ON del.CustID = temp.CustID
		WHERE del.CategoryID = CONST_CATEID_LICBA;
		
		INSERT INTO CTS_DataCenter.CTSCustomerClassification_Log(
				CustID, CTSCustID, CategoryID, ParentID ,LastModifiedDate, LastModifiedBy, ActionType
			, 	IsAuto, InsertDate, TargetCC, SourceTypeID, IsDataChanged, IsMarkedDirectly)
		SELECT 	temp.CustID
			, 	temp.CTSCustID
			, 	CONST_CATEID_LICBA AS CategoryID
			, 	CONST_PARENTID_WRAPPER AS ParentID
			, 	lv_CurrentDateTime AS LastModifiedDate
			, 	temp.CreatedBy AS LastModifiedBy
			,	CONST_ACTIONTYPE_REMOVE AS ActionType
			,	lv_IsAuto AS IsAuto
			,   DATE(lv_CurrentDateTime) AS InsertDate
			,   temp.CustomerClass AS TargetCC
			,   lv_SourceTypeID AS SourceTypeID
			,	lv_IsDataChanged AS IsDataChanged
			,	1 AS IsMarkedDirectly
		FROM Temp_CustomerClassification AS temp;
	
	ELSEIF ip_InputFlowID = CONST_INPUTFLOWID_GENERAL_REMOVE_PA THEN
		SET lv_IsDataChanged		= 1;
		SET lv_SourceTypeID			= CONST_SOURCETYPE_NOREASON_DETAILS;
	
		INSERT IGNORE INTO Temp_CustomerClassification (
				CustID, CTSCustID, SubscriberID, RoleID, CreatedBy, Remark, IsMarkedDirectly
			, 	CategoryID, Ext_EvidenceID_Licensee, Ext_EvidenceID_Credit, IsRemovedPA, IsReturnData)
		SELECT 	temp.CustID
			,	temp.CTSCustID
			,	temp.SubscriberID
			,	temp.RoleID
			,	temp.CreatedBy
			,	temp.Remark
			,	temp.IsMarkedDirectly
			,	cls.CategoryID
			,	cc.Ext_EvidenceID_Licensee
			,	cc.Ext_EvidenceID_Credit
			,	(CASE WHEN (temp.IsExceptDirectDownline = 1 AND cls.IsMarkedDirectly = 1 AND ip_IsFromQueue = 1) THEN 0 
					  ELSE 1 END) AS IsRemovedPA
			,	1 AS IsReturnData
		FROM Temp_Customer AS temp
			INNER JOIN CTS_DataCenter.CTSCustomerClassification AS cls ON temp.CustID = cls.CustID 
																			AND cls.ParentID = CONST_PARENTID_PA
			INNER JOIN CTS_DataCenter.CustomerCategory AS cc ON cls.CategoryID = cc.CategoryID AND cc.IsActive = 1
			; 
			
		UPDATE Temp_CustomerClassification AS temp
		SET temp.IsExistRobot = 1
		WHERE EXISTS (	SELECT 1
						FROM CTS_DataCenter.CTSCustomerClassification AS clsR 
							INNER JOIN CTS_DataCenter.CustomerCategory AS ccR ON clsR.CategoryID = ccR.CategoryID 
																					AND ccR.CustomerClassName = 'Robot'
																					AND ccR.IsActive = 1
						WHERE clsR.CustID = temp.CustID);
		
		UPDATE Temp_CustomerClassification AS temp
		SET temp.IsFromTW = 1
		WHERE EXISTS (	SELECT 1
						FROM CTS_DataCenter.CTSCustomerClassification AS clsR 
							INNER JOIN CTS_DataCenter.CustomerCategory AS ccR ON clsR.CategoryID = ccR.CategoryID
																					AND ccR.IsActive = 1
						WHERE clsR.CustID = temp.CustID AND clsR.IsFromTW = 1);	

		UPDATE Temp_CustomerClassification AS temp
		SET temp.IsFromImperva = 1
		WHERE EXISTS (	SELECT 1
						FROM CTS_DataCenter.CTSCustomerClassification AS clsR 
							INNER JOIN CTS_DataCenter.CustomerCategory AS ccR ON clsR.CategoryID = ccR.CategoryID
																					AND ccR.IsActive = 1
						WHERE clsR.CustID = temp.CustID AND clsR.IsFromImperva = 1);	


		UPDATE Temp_CustomerClassification AS temp
		SET temp.IsFromTVS = 1
		WHERE EXISTS (	SELECT 1
						FROM CTS_DataCenter.CTSCustomerClassification AS clsR 
							INNER JOIN CTS_DataCenter.CustomerCategory AS ccR ON clsR.CategoryID = ccR.CategoryID
																					AND ccR.IsActive = 1
						WHERE clsR.CustID = temp.CustID AND clsR.IsFromTVS = 1);	
						
						
		UPDATE Temp_CustomerClassification AS temp
		SET temp.IsFromAI = 1
		WHERE EXISTS (	SELECT 1
						FROM CTS_DataCenter.CTSCustomerClassification AS clsR 
							INNER JOIN CTS_DataCenter.CustomerCategory AS ccR ON clsR.CategoryID = ccR.CategoryID
																					AND ccR.IsActive = 1
						WHERE clsR.CustID = temp.CustID AND clsR.IsFromAI = 1);	
						
		UPDATE Temp_CustomerClassification AS temp
		SET temp.IsFromCTS = 1
		WHERE EXISTS (	SELECT 1
						FROM CTS_DataCenter.CTSCustomerClassification AS clsR 
							INNER JOIN CTS_DataCenter.CustomerCategory AS ccR ON clsR.CategoryID = ccR.CategoryID
																					AND ccR.IsActive = 1
						WHERE clsR.CustID = temp.CustID AND clsR.IsFromCTS = 1);	
		
		INSERT INTO Temp_KeepDirect
		SELECT DISTINCT temp.CustID
		FROM Temp_CustomerClassification AS temp 
		WHERE temp.IsRemovedPA = 0;
		
		UPDATE Temp_CustomerClassification AS temp
			INNER JOIN Temp_KeepDirect AS tmpKd ON temp.CustID = tmpKd.CustID
		SET temp.IsCleanPA = 0;
		
		INSERT INTO CTS_DataCenter.CustEvidenceAffectedQueueRemove(CTSCustID, EvidenceID, Created)
		SELECT	temp.CTSCustID
			,	ce.EvidenceID
			,	lv_CurrentDateTime AS Created
		FROM CTS_DataCenter.CustEvidence AS ce
			INNER JOIN Temp_CustomerClassification AS temp ON ce.CTSCustID = temp.CTSCustID AND ce.Level = 0 
																AND ce.EvidenceID IN (temp.Ext_EvidenceID_Licensee, temp.Ext_EvidenceID_Credit)
		WHERE temp.IsRemovedPA = 1; 
		
		DELETE ce
		FROM CTS_DataCenter.CustEvidence AS ce
			INNER JOIN Temp_CustomerClassification AS temp ON ce.CTSCustID = temp.CTSCustID 
																AND ce.Level = 0
																AND ce.EvidenceID IN (temp.Ext_EvidenceID_Licensee, temp.Ext_EvidenceID_Credit)					
		WHERE temp.IsRemovedPA = 1;
		
		IF(ip_IsFromQueue = 0) THEN
			INSERT IGNORE INTO CTS_DataCenter.CTSCustomerClassificationQueue(
					CTSCustID, CustID, RoleID, SubscriberID, CreatedBy, Remark, LastDownlineCTSCustID, ActionType
				, 	InsertTime, IsExceptDirectDownline)
			SELECT 	temp.CTSCustID
				,	temp.CustID
				,	temp.RoleID
				,	temp.SubscriberID
				,	temp.CreatedBy
				,	temp.Remark    
				,	0 AS LastDownlineCTSCustID
				,	CONST_ACTIONTYPE_UNMARKPA AS ActionType
				,	lv_CurrentDateTime AS InsertTime
				, 	temp.IsExceptDirectDownline
			FROM Temp_Customer AS temp
			WHERE temp.RoleID > 1;    

		END IF;
		
		UPDATE CTS_DataCenter.RobotDetection AS rd
			INNER JOIN Temp_CustomerClassification AS temp ON rd.CustID = temp.CustID 
            INNER JOIN CTS_DataCenter.CTSCustomer AS cus ON cus.CustID = temp.CustID AND cus.CustSubID = 0
		SET rd.IsDisabled = 1
		WHERE NOT EXISTS (SELECT 1 FROM Temp_KeepDirect AS tmpKD WHERE temp.CustID = tmpKD.CustID)
			AND temp.IsExistRobot = 1 AND temp.IsFromAI = 1 AND rd.IsDisabled = 0
            AND cus.RoleID = CONST_ROLEID_MEMBER;
		
		-- ROBOT IMPERVA
		UPDATE CTS_DataCenter.RobotImperva AS rd
			INNER JOIN Temp_CustomerClassification AS temp ON rd.CustID = temp.CustID
																AND temp.IsExistRobot = 1 AND temp.IsFromImperva = 1 AND rd.IsDisabled = 0
		SET rd.IsDisabled = 1
		WHERE NOT EXISTS (SELECT 1 FROM Temp_KeepDirect AS tmpKD WHERE temp.CustID = tmpKD.CustID);

		-- ROBOT TW
		UPDATE CTS_DataCenter.TWRobotUser AS rd
			INNER JOIN Temp_CustomerClassification AS temp ON rd.CustID = temp.CustID 
																AND temp.IsExistRobot = 1 AND temp.IsFromTW = 1 AND rd.IsDisabled = 0
		SET rd.IsDisabled = 1
		WHERE NOT EXISTS (SELECT 1 FROM Temp_KeepDirect AS tmpKD WHERE temp.CustID = tmpKD.CustID);
		
		-- ROBOT CTS
		UPDATE CTS_DataCenter.CTSRobotUser AS rd
			INNER JOIN Temp_CustomerClassification AS temp ON rd.CustID = temp.CustID 
																AND temp.IsExistRobot = 1 AND temp.IsFromCTS = 1 AND rd.IsDisabled = 0
		SET rd.IsDisabled = 1
		WHERE NOT EXISTS (SELECT 1 FROM Temp_KeepDirect AS tmpKD WHERE temp.CustID = tmpKD.CustID);
		
		-- PA/ROBOT TVS <ADD INSERT PA - SOURCETYPEID>
		UPDATE CTS_DataCenter.TVSVoidRequest AS rd
			INNER JOIN Temp_CustomerClassification AS temp ON rd.CustID = temp.CustID 
																AND temp.IsFromTVS = 1 AND rd.IsDisabled = 0
		SET rd.IsDisabled = 1
		WHERE NOT EXISTS (SELECT 1 FROM Temp_KeepDirect AS tmpKD WHERE temp.CustID = tmpKD.CustID);
		
		-- PA 305/3005
		UPDATE CTS_DataCenter.CustomerLoginInfoDetection AS cld
		INNER JOIN Temp_CustomerClassification AS temp ON cld.CustID = temp.CustID
																AND temp.IsFromCTS = 1 AND cld.IsDisabled = 0
		SET cld.IsDisabled = 1
		WHERE NOT EXISTS (SELECT 1 FROM Temp_KeepDirect AS tmpKD WHERE temp.CustID = tmpKD.CustID);
		
		DELETE cls
		FROM CTS_DataCenter.CTSCustomerClassification AS cls
			INNER JOIN Temp_CustomerClassification AS temp ON cls.CustID = temp.CustID
																AND cls.CategoryID = temp.CategoryID
		WHERE temp.IsRemovedPA = 1;
		
		INSERT IGNORE INTO CTS_DataCenter.CTSCustomerClassification_History(
				CustID, CTSCustID, CategoryID, ParentID, LastModifiedDate, LastModifiedBy, ActionType
			, 	InsertDate, TargetCC, SourceTypeID, IsDataChanged, TargetDangerLevel1,TurnoverRM, WinlossRM
			, 	BetCount, ActiveDays, IsMarkedDirectly, Remark)
		SELECT DISTINCT 
				temp.CustID
			, 	temp.CTSCustID
			, 	NULL AS CategoryID
			, 	CONST_PARENTID_PA AS ParentID
			, 	lv_CurrentDateTime AS LastModifiedDate
			, 	temp.CreatedBy AS LastModifiedBy
			, 	CONST_ACTIONTYPE_REMOVE AS ActionType
			, 	DATE(lv_CurrentDateTime) AS InsertDate
			, 	NULL AS TargetCC
			, 	(CASE WHEN temp.IsMarkedDirectly = 1 THEN CONST_SOURCETYPE_PA_UNMARK_DIRECTLY 
					  WHEN temp.IsMarkedDirectly = 0 THEN CONST_SOURCETYPE_PA_UNMARK_AFFECTED_UPLINE 
				 END) AS SourceTypeID
			,  	lv_IsDataChanged AS IsDataChanged
			,	NULL AS TargetDangerLevel1
			,	NULL AS TurnoverRM
			,	NULL AS WinlossRM
			, 	NULL AS BetCount
			, 	NULL AS ActiveDays
			,	NULL AS IsMarkedDirectly
			,	temp.Remark
		FROM Temp_CustomerClassification AS temp
		WHERE temp.IsRemovedPA = 1;
		
		INSERT IGNORE INTO CTS_DataCenter.CTSCustomerClassification_Log(
				CustID, CTSCustID, CategoryID, ParentID, LastModifiedDate, LastModifiedBy, ActionType
			, 	InsertDate, TargetCC, SourceTypeID, IsDataChanged, TargetDangerLevel1,TurnoverRM, WinlossRM
			, 	BetCount, ActiveDays, IsMarkedDirectly)
		SELECT DISTINCT 
				temp.CustID
			, 	temp.CTSCustID
			, 	NULL AS CategoryID
			, 	CONST_PARENTID_PA AS ParentID
			, 	lv_CurrentDateTime AS LastModifiedDate
			, 	temp.CreatedBy AS LastModifiedBy
			, 	CONST_ACTIONTYPE_REMOVE AS ActionType
			, 	DATE(lv_CurrentDateTime) AS InsertDate
			, 	NULL AS TargetCC
			, 	(CASE WHEN temp.IsMarkedDirectly = 1 THEN CONST_SOURCETYPE_PA_UNMARK_DIRECTLY 
					  WHEN temp.IsMarkedDirectly = 0 THEN CONST_SOURCETYPE_PA_UNMARK_AFFECTED_UPLINE 
				 END) AS SourceTypeID
			,  	lv_IsDataChanged AS IsDataChanged
			,	NULL AS TargetDangerLevel1
			,	NULL AS TurnoverRM
			,	NULL AS WinlossRM
			, 	NULL AS BetCount
			, 	NULL AS ActiveDays
			,	NULL AS IsMarkedDirectly
		FROM Temp_Customer AS temp;

	END IF;

    #=================CONSIDERABLE_BEGIN: GET PA AFTER==================    
	INSERT IGNORE INTO Temp_PACustEnd(CustID, Recommend)
    SELECT	cls.CustID
		,	cus.Recommend
	FROM Temp_Customer AS temp 
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
	
    INSERT IGNORE INTO Temp_PACustEnd(CustID, Recommend)
    SELECT	cls.CustID
		,	cus.Recommend
	FROM Temp_CustomerClassification AS temp 
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