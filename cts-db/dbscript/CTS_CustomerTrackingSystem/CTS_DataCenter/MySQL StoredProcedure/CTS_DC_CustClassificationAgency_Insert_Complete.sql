/*<info serverAlias="CTSMain-CTS_DataCenter" databaseType="2" executers="ctsServiceAdmin" isFunction="0" isNested="1"></info>*/
DROP PROCEDURE IF EXISTS `CTS_DC_CustClassificationAgency_Insert_Complete`;

DELIMITER $$
CREATE DEFINER=`ctsOwner`@`%` PROCEDURE `CTS_DC_CustClassificationAgency_Insert_Complete`(
		IN	ip_InputFlowID			INT
	,	IN	ip_IsAffectDownline		TINYINT(1)
)
SQL SECURITY INVOKER
BEGIN
/*
		Created:	20240927@Thomas.Nguyen
		Task:		
		DB:			CTS_DataCenter

		Param's Expanation:
			- ip_InputFlowID
			- ip_IsAffectDownline
		
		Example:
			- CALL CTS_DataCenter.CTS_DC_CustClassificationAgency_Insert_Complete(1009);
			
		Revisions: 
			- 20240927@Thomas.Nguyen: Created [Redmine ID: #185799]
			- 20250303@Thomas.Nguyen: Set default value for CONST_AGENCY_REMARKID [Redmine ID: #218588]
            - 20250725@Casey.Huynh: Agent CC, Insert Considerable Agency [Redmine ID: #219679]
*/

	DECLARE CONST_AGENCY_CATEID_VVIP 									INT;
	DECLARE CONST_AGENCY_PARENTID_NORMAL								INT;
	DECLARE CONST_AGENCY_REMARKID_PAMARKEDDIRECTLY						INT DEFAULT 31;
	DECLARE CONST_AGENCY_REMARKID_PAAFFECTEDBYUPLINE					INT DEFAULT 32;
	DECLARE CONST_AGENCY_INPUTFLOWID_GENERAL_INSERT_VVIP				INT;
	DECLARE CONST_AGENCY_INPUTFLOWID_GENERAL_INSERT_NORMAL				INT;
	DECLARE CONST_AGENCY_INPUTFLOWID_GENERAL_RESCAN_PACATEGORY			INT;    
    DECLARE CONST_AGENCY_INPUTFLOWID_GENERAL_INSERT_CONSIDERABLEDANGER	INT;
	DECLARE CONST_AGENCY_INPUTFLOWID_GENERAL_RESCAN_CONSIDERABLEDANGER	INT;
    
	DECLARE CONST_ACTIONTYPE_INSERT 						        INT DEFAULT 0;
	DECLARE	CONST_ACTIONTYPE_UPDATE 						        INT DEFAULT 1;

    DECLARE lv_CreatedBy                                            INT DEFAULT 10278938;
	DECLARE	lv_CurrentDateTime								        DATETIME DEFAULT CURRENT_TIMESTAMP();
	DECLARE	lv_InsertedCount										INT DEFAULT 0;
	DECLARE	lv_UpdatedCount											INT DEFAULT 0;
	DECLARE lv_IsParallelParentID							        TINYINT(1);  
	DECLARE lv_ParentID										        INT UNSIGNED;  
	DECLARE lv_CustomerClassPriority						        SMALLINT;  
	DECLARE lv_IsAuto										        TINYINT(1);  
	DECLARE lv_IsRescan										        TINYINT(1) DEFAULT 0;  

	SET CONST_AGENCY_CATEID_VVIP 									= CTS_DataCenter.CTS_DC_CategoryTypeParent_Get ('CONST_AGENCY_CATEID_VVIP');
	SET CONST_AGENCY_PARENTID_NORMAL 								= CTS_DataCenter.CTS_DC_CategoryTypeParent_Get ('CONST_AGENCY_PARENTID_NORMAL');
	SET CONST_AGENCY_INPUTFLOWID_GENERAL_INSERT_VVIP				= CTS_DataCenter.CTS_DC_CategoryTypeParent_Get ('CONST_AGENCY_INPUTFLOWID_GENERAL_INSERT_VVIP');
	SET CONST_AGENCY_INPUTFLOWID_GENERAL_INSERT_NORMAL				= CTS_DataCenter.CTS_DC_CategoryTypeParent_Get ('CONST_AGENCY_INPUTFLOWID_GENERAL_INSERT_NORMAL');
	SET CONST_AGENCY_INPUTFLOWID_GENERAL_RESCAN_PACATEGORY			= CTS_DataCenter.CTS_DC_CategoryTypeParent_Get ('CONST_AGENCY_INPUTFLOWID_GENERAL_RESCAN_PACATEGORY');
	SET CONST_AGENCY_INPUTFLOWID_GENERAL_INSERT_CONSIDERABLEDANGER	= CTS_DataCenter.CTS_DC_CategoryTypeParent_Get ('CONST_AGENCY_INPUTFLOWID_GENERAL_INSERT_CONSIDERABLEDANGER');
	SET CONST_AGENCY_INPUTFLOWID_GENERAL_RESCAN_CONSIDERABLEDANGER	= CTS_DataCenter.CTS_DC_CategoryTypeParent_Get ('CONST_AGENCY_INPUTFLOWID_GENERAL_RESCAN_CONSIDERABLEDANGER');


	/*VVIP*/
	IF ip_InputFlowID = CONST_AGENCY_INPUTFLOWID_GENERAL_INSERT_VVIP THEN
	
		SET lv_IsAuto = 0;
	
		SELECT  ccs.IsParallelParentID, cc.ParentID, cc.CustomerClassPriority
		INTO lv_IsParallelParentID, lv_ParentID, lv_CustomerClassPriority
		FROM CTS_DataCenter.CustomerCategorySettingsAgency AS ccs
			INNER JOIN CTS_DataCenter.CustomerCategoryAgency AS cc ON cc.CategoryID = ccs.CategoryID
		WHERE ccs.CategoryID = CONST_AGENCY_CATEID_VVIP;
	
		IF lv_IsParallelParentID = 0 THEN
			/*Remove all categories which IsKeepOldCateID = 0*/							
			DELETE cls							
			FROM CTS_DataCenter.CTSCustomerClassificationAgency AS cls							
				INNER JOIN Temp_NewClassification AS temp ON cls.CustID = temp.CustID						
			WHERE temp.IsExistVVIP = 0							
				AND NOT EXISTS (SELECT 1 
								FROM CTS_DataCenter.CustomerCategorySettingsAgency AS cs	
									INNER JOIN CTS_DataCenter.CustomerCategoryAgency AS cc ON cc.CategoryID = cs.CategoryID
								WHERE cc.CategoryID = cls.CategoryID AND cc.IsActive = 1	
									AND cc.CustomerClassPriority > lv_CustomerClassPriority 
									AND (cc.ParentID <> lv_ParentID OR (cc.ParentID = lv_ParentID AND cs.IsMultiCateIDSameParentID = 1))
									AND cs.IsKeepOldCateID = 1);
	
		END IF;
		
		/*Insert VVIP*/
		INSERT IGNORE INTO CTS_DataCenter.CTSCustomerClassificationAgency (
				CustID, CTSCustID, SubscriberID, RoleID, ParentID, CategoryID, Remark, CreatedBy, LastModifiedBy, CreatedDate, LastModifiedDate, LastScannedDate, IsAffectToDownline, IsMarkedDirectly)
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
		INSERT INTO CTS_DataCenter.CTSCustomerClassificationAgency_History(
				CustID, CTSCustID, RoleID, ParentID, CategoryID, LastModifiedDate, InsertDate, LastModifiedBy, Remark, IsAuto, TargetCC, SourceTypeID, IsDataChanged, IsMarkedDirectly)
		SELECT 	temp.CustID
			, 	temp.CTSCustID
			,	temp.RoleID
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
			INNER JOIN CTS_DataCenter.CustomerCategoryAgency AS cat ON cat.CategoryID = temp.NewCategoryID
		WHERE temp.IsExistVVIP = 0;
		
		/*Insert VVIP log*/
		INSERT INTO CTS_DataCenter.CTSCustomerClassificationAgency_Log(
				CustID, CTSCustID, RoleID, ParentID, CategoryID ,LastModifiedDate, InsertDate, LastModifiedBy, IsAuto, TargetCC, SourceTypeID, IsDataChanged, IsMarkedDirectly)
		SELECT 	temp.CustID
			, 	temp.CTSCustID
			,	temp.RoleID
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
			INNER JOIN CTS_DataCenter.CustomerCategoryAgency AS cat ON cat.CategoryID = temp.NewCategoryID
		WHERE temp.IsExistVVIP = 0;

	/*Normal*/
	ELSEIF ip_InputFlowID = CONST_AGENCY_INPUTFLOWID_GENERAL_INSERT_NORMAL THEN 
		SET lv_IsAuto = 1;
		
		UPDATE CTS_DataCenter.CTSCustomerClassificationAgency AS cate
			INNER JOIN Temp_NewClassification AS temp ON temp.CustID = cate.CustID AND cate.ParentID = CONST_AGENCY_PARENTID_NORMAL
		SET   	cate.CTSCustID 			= temp.CTSCustID
			, 	cate.SubscriberID 		= temp.SubscriberID
			, 	cate.CategoryID 		= temp.NewCategoryID
			, 	cate.LastModifiedDate 	= lv_CurrentDateTime
			, 	cate.LastScannedDate 	= DATE(lv_CurrentDateTime)
		WHERE temp.ActionType = CONST_ACTIONTYPE_UPDATE;
		
		DELETE del
		FROM CTS_DataCenter.CTSCustomerClassificationAgency AS del
			INNER JOIN Temp_NewClassification AS temp ON del.CustID = temp.CustID 
															AND del.ParentID = CONST_AGENCY_PARENTID_NORMAL
		WHERE temp.ActionType = CONST_ACTIONTYPE_INSERT;
		
		INSERT IGNORE INTO CTS_DataCenter.CTSCustomerClassificationAgency(
				CustID, CTSCustID, SubscriberID, RoleID, ParentID, CategoryID, CreatedDate, CreatedBy, LastModifiedDate, LastModifiedBy, LastScannedDate)
		SELECT DISTINCT 
				temp.CustID
			, 	temp.CTSCustID
			, 	temp.SubscriberID
			, 	temp.RoleID
			, 	CONST_AGENCY_PARENTID_NORMAL AS ParentID
			, 	temp.NewCategoryID AS CategoryID
			, 	lv_CurrentDateTime AS CreatedDate
			, 	lv_CreatedBy AS CreatedBy
			, 	lv_CurrentDateTime AS LastModifiedDate
			, 	lv_CreatedBy AS LastModifiedBy
			, 	DATE(lv_CurrentDateTime) AS LastScannedDate
		FROM Temp_NewClassification AS temp
		WHERE temp.ActionType = CONST_ACTIONTYPE_INSERT;
		
		INSERT IGNORE INTO CTS_DataCenter.CTSCustomerClassificationAgency_History (
				CustID, CTSCustID, RoleID, CategoryID, ParentID, LastModifiedDate, LastModifiedBy, TurnoverRM, WinlossRM, BetCount
			,	LastXDaysTurnoverRM, LastXDaysWinlossRM, LastXDaysBetCount, LastYDaysTurnoverRM, LastYDaysWinlossRM, LastYDaysBetCount
			,	IsAuto, InsertDate, TargetCC, SourceTypeID, OldCategoryID, DWCategoryID, IsDataChanged, TargetDangerLevel1, PerformanceTime, ActionType)
		SELECT DISTINCT	
				temp.CustID
			, 	temp.CTSCustID
			,	temp.RoleID
			, 	temp.NewCategoryID AS CategoryID
			, 	CONST_AGENCY_PARENTID_NORMAL AS ParentID
			, 	lv_CurrentDateTime AS LastModifiedDate
			, 	lv_CreatedBy AS LastModifiedBy
			, 	temp.TurnoverRM
			, 	temp.WinlossRM
			, 	temp.BetCount
            ,	temp.LastXDaysTurnoverRM
            ,	temp.LastXDaysWinlossRM
            , 	temp.LastXDaysBetCount
            ,	temp.LastYDaysTurnoverRM
            ,	temp.LastYDaysWinlossRM
            , 	temp.LastYDaysBetCount
			, 	lv_IsAuto
			, 	DATE(lv_CurrentDateTime) AS InsertDate
			,	temp.TargetCC 
			,   temp.SourceTypeID
			, 	temp.OldCategoryID 
			, 	temp.DWCategoryID
			,   temp.IsDataChanged
			,	temp.TargetDangerLevel AS TargetDangerLevel1
			,	temp.PerformanceTime
			,	temp.ActionType
		FROM 	Temp_NewClassification AS temp
		WHERE temp.IsDataChanged  = 1;	
        
        INSERT IGNORE INTO CTS_DataCenter.CTSCustomerClassificationAgency_Log (
				CustID, CTSCustID, RoleID, CategoryID, ParentID, LastModifiedDate, LastModifiedBy, TurnoverRM, WinlossRM, BetCount
			,	LastXDaysTurnoverRM, LastXDaysWinlossRM, LastXDaysBetCount,	LastYDaysTurnoverRM, LastYDaysWinlossRM, LastYDaysBetCount
			,	IsAuto, InsertDate, TargetCC, SourceTypeID, OldCategoryID, DWCategoryID, IsDataChanged, TargetDangerLevel1, PerformanceTime, ActionType)
		SELECT DISTINCT	
				temp.CustID
			, 	temp.CTSCustID
			,	temp.RoleID
			, 	temp.NewCategoryID AS CategoryID
			, 	CONST_AGENCY_PARENTID_NORMAL AS ParentID
			, 	lv_CurrentDateTime AS LastModifiedDate
			, 	lv_CreatedBy AS LastModifiedBy
			, 	temp.TurnoverRM
			, 	temp.WinlossRM
			, 	temp.BetCount
            ,	temp.LastXDaysTurnoverRM
            ,	temp.LastXDaysWinlossRM
            , 	temp.LastXDaysBetCount
            ,	temp.LastYDaysTurnoverRM
            ,	temp.LastYDaysWinlossRM
            , 	temp.LastYDaysBetCount
			, 	lv_IsAuto
			, 	DATE(lv_CurrentDateTime) AS InsertDate
			,	temp.TargetCC 
			,   temp.SourceTypeID
			, 	temp.OldCategoryID 
			, 	temp.DWCategoryID
			,   temp.IsDataChanged
			,	temp.TargetDangerLevel AS TargetDangerLevel1
			,	temp.PerformanceTime
			,	temp.ActionType
		FROM 	Temp_NewClassification AS temp;
        
	ELSEIF ip_InputFlowID IN (CONST_AGENCY_INPUTFLOWID_GENERAL_INSERT_CONSIDERABLEDANGER,CONST_AGENCY_INPUTFLOWID_GENERAL_RESCAN_CONSIDERABLEDANGER) THEN 

        IF ip_InputFlowID = CONST_AGENCY_INPUTFLOWID_GENERAL_RESCAN_CONSIDERABLEDANGER THEN
			SET lv_IsRescan = 1;
		END IF;

        UPDATE Temp_NewClassification AS temp
			, LATERAL ( SELECT cd.PAMemberRatio
						FROM CTS_DataCenter.Customer_ConsiderableDanger AS cd
						WHERE cd.CustID = temp.CustID AND cd.InsertedTime < CURRENT_TIMESTAMP(3)
						ORDER BY cd.InsertedTime DESC
                        LIMIT 1
						) AS ltr
        SET temp.Remark = CONCAT('PARatio:',ltr.PAMemberRatio);

		UPDATE IGNORE CTS_DataCenter.CTSCustomerClassificationAgency AS cls
			INNER JOIN Temp_NewClassification AS temp ON cls.CustID = temp.CustID AND cls.CategoryID = temp.OldCategoryID 
																						AND temp.DataChangeType = 1
		SET 	cls.CTSCustID 			=  temp.CTSCustID
			,	cls.CategoryID 			=  temp.NewCategoryID
			, 	cls.LastModifiedDate 	=  lv_CurrentDateTime
			, 	cls.LastScannedDate 	=  DATE(lv_CurrentDateTime)
            ,	cls.CreatedBy			=  temp.CreatedBy
            ,	cls.Remark				=  temp.Remark
			;         
        
		/*delete Normal - IsKeepOldCateID = 0*/
		DELETE cls
		FROM CTS_DataCenter.CTSCustomerClassificationAgency AS cls
			INNER JOIN Temp_CTSCustomerClassificationAgency_Old AS temp_old ON temp_old.CustID = cls.CustID
																			AND temp_old.ExistCategoryID = cls.CategoryID
		WHERE temp_old.IsNew = 0 AND temp_old.IsRemove = 1;
        
        INSERT IGNORE INTO CTS_DataCenter.CTSCustomerClassificationAgency(
				CustID, CTSCustID, SubscriberID, RoleID, CategoryID, ParentID, CreatedDate, CreatedBy, LastModifiedDate
			, 	LastModifiedBy, LastScannedDate, IsMarkedDirectly, Remark, IsFromCTS, IsFromAI, IsFromTW)
		SELECT 	temp.CustID
			,	temp.CTSCustID
			, 	temp.SubscriberID
			, 	temp.RoleID
			, 	temp.NewCategoryGroupID AS CategoryID
			, 	temp.ParentID
			, 	lv_CurrentDateTime AS CreatedDate
			, 	temp.CreatedBy
			, 	lv_CurrentDateTime AS LastModifiedDate
			, 	temp.CreatedBy AS LastModifiedBy
			, 	DATE(lv_CurrentDateTime) AS LastScannedDate
			,	temp.IsMarkedDirectly
			,	temp.Remark
			,	temp.IsFromCTS
			,	temp.IsFromAI
			,	temp.IsFromTW
		FROM Temp_NewClassification AS temp 
		WHERE 	(temp.DataChangeType = 0 AND temp.IsDataChanged = 1) 
			OR 	(temp.IsFromOldPA 	= 1 AND lv_IsRescan = 0);
        
        INSERT IGNORE INTO CTS_DataCenter.CTSCustomerClassificationAgency_History(
				CustID, CTSCustID, RoleID, CategoryID, ParentID, LastModifiedDate, LastModifiedBy, ActionType, InsertDate, TargetCC, SourceTypeID, IsDataChanged, TargetDangerLevel1
			,	TurnoverRM, WinlossRM, BetCount, IsMarkedDirectly, Remark, IsFromTW, IsFromCTS, IsFromAI, OldCategoryID, DWCategoryID, RobotCounter, PerformanceTime)
		SELECT 	temp.CustID
			, 	temp.CTSCustID
			,	temp.RoleID
			, 	temp.NewCategoryID AS CategoryID
			,	temp.ParentID
			, 	lv_CurrentDateTime AS LastModifiedDate
			, 	temp.CreatedBy AS LastModifiedBy
			, 	temp.ActionType
			, 	DATE(lv_CurrentDateTime) AS InsertDate
			, 	temp.TargetCC
			, 	(CASE	WHEN ccs.RemarkTemplateID IS NOT NULL THEN ccs.RemarkTemplateID END) AS SourceTypeID
			,  	temp.IsDataChanged
			,	temp.TargetDangerLevel AS TargetDangerLevel1
			,	temp.TurnoverRM
			,	temp.WinlossRM
			, 	temp.BetCount
			,	temp.IsMarkedDirectly
			,	temp.Remark
			,	temp.IsFromTW
			,	temp.IsFromCTS
			,	temp.IsFromAI
			,	temp.OldCategoryID
			,	temp.DWCategoryID
			,	temp.TWRobotCounter AS RobotCounter
			,	temp.PerformanceTime
		FROM Temp_NewClassification AS temp
			LEFT JOIN CTS_DataCenter.CustomerCategorySettingsAgency AS ccs ON ccs.CategoryID = temp.NewCategoryID 
		WHERE temp.IsDataChanged = 1 
		ORDER BY temp.LastModifiedDate ASC, temp.NewCategoryID ASC;
		
		INSERT INTO CTS_DataCenter.CTSCustomerClassificationAgency_Log(
				CustID, CTSCustID, RoleID, CategoryID, ParentID, LastModifiedDate, LastModifiedBy, ActionType, IsAuto, InsertDate, TargetCC, SourceTypeID, IsDataChanged,TargetDangerLevel1
			,	TurnoverRM, WinlossRM, BetCount, IsMarkedDirectly, Remark, IsFromTW, IsFromCTS, IsFromAI, OldCategoryID, DWCategoryID, RobotCounter, PerformanceTime)
		SELECT 	temp.CustID
			,	temp.CTSCustID
			,	temp.RoleID
			,	temp.NewCategoryID
			,	temp.ParentID
			,	lv_CurrentDateTime AS LastModifiedDate
			,	temp.CreatedBy AS LastModifiedBy
			,	temp.ActionType
			,	lv_IsAuto
			,	DATE(lv_CurrentDateTime) AS InsertDate
			,	temp.TargetCC
			, 	(CASE	WHEN ccs.RemarkTemplateID IS NOT NULL THEN ccs.RemarkTemplateID END) AS SourceTypeID
			,	temp.IsDataChanged
			,	temp.TargetDangerLevel AS TargetDangerLevel1
			,	temp.TurnoverRM
			,	temp.WinlossRM
			,	temp.BetCount
			,	temp.IsMarkedDirectly
			,	temp.Remark
			,	temp.IsFromTW
			,	temp.IsFromCTS
			,	temp.IsFromAI
			,	temp.OldCategoryID
			,	temp.DWCategoryID
			,	temp.TWRobotCounter AS RobotCounter
			,	temp.PerformanceTime
		FROM Temp_NewClassification AS temp
			LEFT JOIN CTS_DataCenter.CustomerCategorySettingsAgency AS ccs ON ccs.CategoryID = temp.NewCategoryID ;
	ELSE
		SET lv_InsertedCount = 0;
		SET lv_UpdatedCount = 0;
		SET lv_IsAuto = 1;

		IF ip_InputFlowID = CONST_AGENCY_INPUTFLOWID_GENERAL_RESCAN_PACATEGORY THEN
			SET lv_IsRescan = 1;
		END IF;
		
		/*delete Normal - IsKeepOldCateID = 0*/
		DELETE cls
		FROM CTS_DataCenter.CTSCustomerClassificationAgency AS cls
			INNER JOIN Temp_CTSCustomerClassificationAgency_Old AS temp_old ON temp_old.CustID = cls.CustID
																			AND temp_old.ExistCategoryID = cls.CategoryID
		WHERE temp_old.IsNew = 0 AND temp_old.IsRemove = 1;
		
		/*update PA when change probation status*/
		UPDATE IGNORE CTS_DataCenter.CTSCustomerClassificationAgency AS cls
			INNER JOIN Temp_NewClassification AS temp ON cls.CustID = temp.CustID AND cls.CategoryID = temp.OldCategoryID 
																						AND temp.DataChangeType = 1
		SET 	cls.CTSCustID 			=  temp.CTSCustID
			,	cls.CategoryID 			=  temp.NewCategoryID
			, 	cls.LastModifiedDate 	=  lv_CurrentDateTime
			, 	cls.LastScannedDate 	=  DATE(lv_CurrentDateTime)
			,	cls.IsFromTW 			=   CASE WHEN temp.IsFromTW 		= 1 THEN temp.IsFromTW 			ELSE cls.IsFromTW 			END
			,	cls.IsFromCTS 			=   CASE WHEN temp.IsFromCTS 		= 1 THEN temp.IsFromCTS 		ELSE cls.IsFromCTS 			END
			,	cls.IsFromAI 			=   CASE WHEN temp.IsFromAI 		= 1 THEN temp.IsFromAI 			ELSE cls.IsFromAI 			END
			,	cls.IsMarkedDirectly	=   CASE WHEN temp.IsMarkedDirectly	= 1 THEN temp.IsMarkedDirectly 	ELSE cls.IsMarkedDirectly 	END
			; 

		SET lv_UpdatedCount = FOUND_ROWS();

		INSERT IGNORE INTO CTS_DataCenter.CTSCustomerClassificationAgency(
				CustID, CTSCustID, SubscriberID, RoleID, CategoryID, ParentID, CreatedDate, CreatedBy, LastModifiedDate
			, 	LastModifiedBy, LastScannedDate, IsMarkedDirectly, Remark, IsFromCTS, IsFromAI, IsFromTW)
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
			,	temp.IsFromTW
		FROM Temp_NewClassification AS temp 
		WHERE 	(temp.DataChangeType = 0 AND temp.IsDataChanged = 1) 
			OR 	(temp.IsFromOldPA 	= 1 AND lv_IsRescan = 0);

		SET lv_InsertedCount = FOUND_ROWS();

		INSERT IGNORE INTO CTS_DataCenter.CTSCustomerClassificationAgency_History(
				CustID, CTSCustID, RoleID, CategoryID, ParentID, LastModifiedDate, LastModifiedBy, ActionType, InsertDate, TargetCC, SourceTypeID, IsDataChanged, TargetDangerLevel1
			,	TurnoverRM, WinlossRM, BetCount, IsMarkedDirectly, Remark, IsFromTW, IsFromCTS, IsFromAI, OldCategoryID, DWCategoryID, RobotCounter, PerformanceTime)
		SELECT 	temp.CustID
			, 	temp.CTSCustID
			,	temp.RoleID
			, 	temp.NewCategoryID AS CategoryID
			,	temp.ParentID
			, 	lv_CurrentDateTime AS LastModifiedDate
			, 	temp.CreatedBy AS LastModifiedBy
			, 	temp.ActionType
			, 	DATE(lv_CurrentDateTime) AS InsertDate
			, 	temp.TargetCC
			, 	(CASE	WHEN ccs.RemarkTemplateID IS NOT NULL THEN ccs.RemarkTemplateID
						WHEN temp.IsMarkedDirectly = 1 THEN CONST_AGENCY_REMARKID_PAMARKEDDIRECTLY 
						WHEN temp.IsMarkedDirectly = 0 THEN CONST_AGENCY_REMARKID_PAAFFECTEDBYUPLINE END) AS SourceTypeID
			,  	temp.IsDataChanged
			,	temp.TargetDangerLevel AS TargetDangerLevel1
			,	temp.TurnoverRM
			,	temp.WinlossRM
			, 	temp.BetCount
			,	temp.IsMarkedDirectly
			,	temp.Remark
			,	temp.IsFromTW
			,	temp.IsFromCTS
			,	temp.IsFromAI
			,	temp.OldCategoryID
			,	temp.DWCategoryID
			,	temp.TWRobotCounter AS RobotCounter
			,	temp.PerformanceTime
		FROM Temp_NewClassification AS temp
			LEFT JOIN CTS_DataCenter.CustomerCategorySettingsAgency AS ccs ON ccs.CategoryID = temp.NewCategoryID 
		WHERE temp.IsDataChanged = 1 
		ORDER BY temp.LastModifiedDate ASC, temp.NewCategoryID ASC;
		
		INSERT INTO CTS_DataCenter.CTSCustomerClassificationAgency_Log(
				CustID, CTSCustID, RoleID, CategoryID, ParentID, LastModifiedDate, LastModifiedBy, ActionType, IsAuto, InsertDate, TargetCC, SourceTypeID, IsDataChanged,TargetDangerLevel1
			,	TurnoverRM, WinlossRM, BetCount, IsMarkedDirectly, Remark, IsFromTW, IsFromCTS, IsFromAI, OldCategoryID, DWCategoryID, RobotCounter, PerformanceTime)
		SELECT 	temp.CustID
			,	temp.CTSCustID
			,	temp.RoleID
			,	temp.NewCategoryID
			,	temp.ParentID
			,	lv_CurrentDateTime AS LastModifiedDate
			,	temp.CreatedBy AS LastModifiedBy
			,	temp.ActionType
			,	lv_IsAuto
			,	DATE(lv_CurrentDateTime) AS InsertDate
			,	temp.TargetCC
			, 	(CASE	WHEN ccs.RemarkTemplateID IS NOT NULL THEN ccs.RemarkTemplateID
						WHEN temp.IsMarkedDirectly = 1 THEN CONST_AGENCY_REMARKID_PAMARKEDDIRECTLY 
						WHEN temp.IsMarkedDirectly = 0 THEN CONST_AGENCY_REMARKID_PAAFFECTEDBYUPLINE END) AS SourceTypeID
			,	temp.IsDataChanged
			,	temp.TargetDangerLevel AS TargetDangerLevel1
			,	temp.TurnoverRM
			,	temp.WinlossRM
			,	temp.BetCount
			,	temp.IsMarkedDirectly
			,	temp.Remark
			,	temp.IsFromTW
			,	temp.IsFromCTS
			,	temp.IsFromAI
			,	temp.OldCategoryID
			,	temp.DWCategoryID
			,	temp.TWRobotCounter AS RobotCounter
			,	temp.PerformanceTime
		FROM Temp_NewClassification AS temp
			LEFT JOIN CTS_DataCenter.CustomerCategorySettingsAgency AS ccs ON ccs.CategoryID = temp.NewCategoryID ;

	/* Insert into source tables */
	IF (IFNULL(lv_InsertedCount,0) > 0 OR IFNULL(lv_UpdatedCount,0) > 0) THEN
	
		IF EXISTS (SELECT 1 
						FROM Temp_NewClassification 
						WHERE IsFromTW = 1 AND IsRobot = 1
							AND ( lv_InsertedCount > 0 OR lv_UpdatedCount > 0)) THEN

			/*Add to source table TWRobotUser*/	
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

			/*Add to source table CTSRobotUser*/		
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
	
END$$
DELIMITER ;
