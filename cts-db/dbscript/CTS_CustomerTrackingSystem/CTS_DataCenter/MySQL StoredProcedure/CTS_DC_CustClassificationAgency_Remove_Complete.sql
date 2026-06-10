/*<info serverAlias="CTSMain-CTS_DataCenter" databaseType="2" executers="ctsServiceAdmin" isFunction="0" isNested="1"></info>*/
DROP PROCEDURE IF EXISTS `CTS_DC_CustClassificationAgency_Remove_Complete`;

DELIMITER $$
CREATE DEFINER=`ctsOwner`@`%` PROCEDURE `CTS_DC_CustClassificationAgency_Remove_Complete`(
		IN	ip_InputFlowID			INT 
	,	IN	ip_FromAction			TINYINT
	,	IN	ip_UplineRoleID			INT
	,	IN	ip_IsFromQueue			TINYINT(1)
	,	IN	ip_CustInfo				JSON
)
SQL SECURITY INVOKER
BEGIN
/*
		Created:	20240927@Thomas.Nguyen
		Task:		
		DB:			CTS_DataCenter
		
		Revisions: 
			- 20240927@Thomas.Nguyen: Created [Redmine ID: #185799]
            - 20250725@Casey.Huynh: Agent CC, Insert Considerable Agency [Redmine ID: #219679]
			
		Param's Expanation:
			- CALL CTS_DC_CustClassificationAgency_Remove_Complete(1225, 1, 0, false, '[{"CustID":24150964,"RoleID":2,"SubscriberID":168,"CTSCustID":11059,"CreatedBy":8,"Remark":"Thomas unmark PA","IsExceptDirectDownline":false,"IsMarkedDirectly":true}]');
*/
	DECLARE CONST_AGENCY_CATEID_ROBOT									INT;
	DECLARE CONST_AGENCY_CATEID_ROBOTLOSING								INT;
	DECLARE CONST_AGENCY_PARENTID_VVIP 							    	INT;
	DECLARE CONST_AGENCY_PARENTID_PA	 								INT;
    DECLARE CONST_AGENCY_PARENTID_CONSIDERABLEDANGER					INT;
	DECLARE CONST_AGENCY_INPUTFLOWID_GENERAL_REMOVE_VVIP 				INT;
	DECLARE CONST_AGENCY_INPUTFLOWID_GENERAL_REMOVE_PA 			    	INT;
    DECLARE CONST_AGENCY_INPUTFLOWID_GENERAL_REMOVE_CONSIDERABLEDANGER	INT;

	DECLARE CONST_ACTIONTYPE_REMOVE 						        INT DEFAULT 2;
	DECLARE CONST_ACTIONTYPE_UNMARKPA 						        INT DEFAULT 4;
	DECLARE CONST_SOURCETYPE_VVIP_UNMARK_MANUAL				        INT DEFAULT 14;
	DECLARE CONST_SOURCETYPE_VVIP_UNMARK_AFFECTED_SUPER		        INT DEFAULT 27;
	DECLARE CONST_SOURCETYPE_VVIP_UNMARK_AFFECTED_MASTER	        INT DEFAULT 28;
	DECLARE CONST_SOURCETYPE_PA_UNMARK_DIRECTLY				        INT DEFAULT 33;
	DECLARE CONST_SOURCETYPE_PA_UNMARK_AFFECTED_UPLINE		        INT DEFAULT 34;

	DECLARE lv_SourceTypeID									        INT;
	DECLARE lv_CurrentDateTime 								        DATETIME DEFAULT CURRENT_TIMESTAMP();
	DECLARE lv_IsAuto										        TINYINT(1);
	DECLARE lv_IsDataChanged								        TINYINT(1);
	DECLARE lv_TargetCC										        INT;
	DECLARE lv_CCPriority									        SMALLINT UNSIGNED;  

	SET CONST_AGENCY_CATEID_ROBOT 									= CTS_DataCenter.CTS_DC_CategoryTypeParent_Get ('CONST_AGENCY_CATEID_ROBOT');
	SET CONST_AGENCY_CATEID_ROBOTLOSING 							= CTS_DataCenter.CTS_DC_CategoryTypeParent_Get ('CONST_AGENCY_CATEID_ROBOTLOSING');
	SET CONST_AGENCY_PARENTID_VVIP 								    = CTS_DataCenter.CTS_DC_CategoryTypeParent_Get ('CONST_AGENCY_PARENTID_VVIP');
	SET CONST_AGENCY_PARENTID_PA	 								= CTS_DataCenter.CTS_DC_CategoryTypeParent_Get ('CONST_AGENCY_PARENTID_PA');
    SET CONST_AGENCY_PARENTID_CONSIDERABLEDANGER					= CTS_DataCenter.CTS_DC_CategoryTypeParent_Get ('CONST_AGENCY_PARENTID_CONSIDERABLEDANGER');
	SET CONST_AGENCY_INPUTFLOWID_GENERAL_REMOVE_VVIP				= CTS_DataCenter.CTS_DC_CategoryTypeParent_Get ('CONST_AGENCY_INPUTFLOWID_GENERAL_REMOVE_VVIP');
	SET CONST_AGENCY_INPUTFLOWID_GENERAL_REMOVE_PA					= CTS_DataCenter.CTS_DC_CategoryTypeParent_Get ('CONST_AGENCY_INPUTFLOWID_GENERAL_REMOVE_PA');
    SET CONST_AGENCY_INPUTFLOWID_GENERAL_REMOVE_CONSIDERABLEDANGER	= CTS_DataCenter.CTS_DC_CategoryTypeParent_Get ('CONST_AGENCY_INPUTFLOWID_GENERAL_REMOVE_CONSIDERABLEDANGER');

	IF ip_InputFlowID = CONST_AGENCY_INPUTFLOWID_GENERAL_REMOVE_VVIP THEN
    
		SET lv_IsAuto 				= 0;
		SET lv_TargetCC				= -1;
		SET lv_IsDataChanged		= 1;
		
		SET lv_SourceTypeID = 	CASE 	WHEN ip_FromAction = 1 THEN CONST_SOURCETYPE_VVIP_UNMARK_MANUAL
										WHEN ip_FromAction = 3 AND ip_UplineRoleID = 4 THEN CONST_SOURCETYPE_VVIP_UNMARK_AFFECTED_SUPER
										WHEN ip_FromAction = 3 AND ip_UplineRoleID = 3 THEN CONST_SOURCETYPE_VVIP_UNMARK_AFFECTED_MASTER
								END;
								
		DELETE cls
		FROM CTS_DataCenter.CTSCustomerClassificationAgency AS cls
			INNER JOIN Temp_CustomerClassification AS temp ON temp.CustID = cls.CustID
																	AND temp.CategoryID = cls.CategoryID
																	AND temp.IsExistVVIP = 1;
		
		INSERT INTO CTS_DataCenter.CTSCustomerClassificationAgency_History(
				CustID, CTSCustID, CategoryID, ParentID, LastModifiedDate, LastModifiedBy, ActionType, IsAuto
			, 	InsertDate, TargetCC, SourceTypeID, IsDataChanged)
		SELECT 	temp.CustID
			, 	temp.CTSCustID
			,   temp.CategoryID
			,   CONST_AGENCY_PARENTID_VVIP AS ParentID
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
		
		INSERT INTO CTS_DataCenter.CTSCustomerClassificationAgency_Log(
				CustID, CTSCustID, CategoryID, ParentID, LastModifiedDate, LastModifiedBy, ActionType, IsAuto
			, 	InsertDate, TargetCC, SourceTypeID, IsDataChanged)
		SELECT 	temp.CustID
			, 	temp.CTSCustID
			,   temp.CategoryID
			,   CONST_AGENCY_PARENTID_VVIP AS ParentID
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
	
	ELSEIF ip_InputFlowID = CONST_AGENCY_INPUTFLOWID_GENERAL_REMOVE_PA THEN
		SET lv_IsDataChanged	= 1;
	
		INSERT IGNORE INTO Temp_CustomerClassification (
				CustID, CTSCustID, SubscriberID, RoleID, CreatedBy, Remark, IsMarkedDirectly
			, 	CategoryID, Ext_EvidenceID_Credit, IsRemovedPA, IsReturnData)
		SELECT 	temp.CustID
			,	temp.CTSCustID
			,	temp.SubscriberID
			,	temp.RoleID
			,	temp.CreatedBy
			,	temp.Remark
			,	temp.IsMarkedDirectly
			,	cls.CategoryID
			,	cc.Ext_EvidenceID_Credit
			,	(CASE WHEN (temp.IsExceptDirectDownline = 1 AND cls.IsMarkedDirectly = 1 AND ip_IsFromQueue = 1) THEN 0 
					  ELSE 1 END) AS IsRemovedPA
			,	1 AS IsReturnData
		FROM Temp_Customer AS temp
			INNER JOIN CTS_DataCenter.CTSCustomerClassificationAgency AS cls ON temp.CustID = cls.CustID 
																			AND cls.ParentID = CONST_AGENCY_PARENTID_PA
			INNER JOIN CTS_DataCenter.CustomerCategoryAgency AS cc ON cls.CategoryID = cc.CategoryID AND cc.IsActive = 1
			; 
		
		UPDATE Temp_CustomerClassification AS temp
		SET temp.IsExistRobot = 1
		WHERE EXISTS (	SELECT 1
						FROM CTS_DataCenter.CTSCustomerClassificationAgency AS clsR 
							INNER JOIN CTS_DataCenter.CustomerCategoryAgency AS ccR ON clsR.CategoryID = ccR.CategoryID 
																					AND ccR.CategoryID IN (CONST_AGENCY_CATEID_ROBOT, CONST_AGENCY_CATEID_ROBOTLOSING)
																					AND ccR.IsActive = 1
						WHERE clsR.CustID = temp.CustID);

		UPDATE Temp_CustomerClassification AS temp
		SET temp.IsFromTW = 1
		WHERE EXISTS (	SELECT 1
						FROM CTS_DataCenter.CTSCustomerClassificationAgency AS clsR 
							INNER JOIN CTS_DataCenter.CustomerCategoryAgency AS ccR ON clsR.CategoryID = ccR.CategoryID
																					AND ccR.IsActive = 1
						WHERE clsR.CustID = temp.CustID AND clsR.IsFromTW = 1);	

		UPDATE Temp_CustomerClassification AS temp
		SET temp.IsFromCTS = 1
		WHERE EXISTS (	SELECT 1
						FROM CTS_DataCenter.CTSCustomerClassificationAgency AS clsR 
							INNER JOIN CTS_DataCenter.CustomerCategoryAgency AS ccR ON clsR.CategoryID = ccR.CategoryID
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
																AND ce.EvidenceID = temp.Ext_EvidenceID_Credit
		WHERE temp.IsRemovedPA = 1; 
		
		
		DELETE ce
		FROM CTS_DataCenter.CustEvidence AS ce
			INNER JOIN Temp_CustomerClassification AS temp ON ce.CTSCustID = temp.CTSCustID 
																AND ce.Level = 0
																AND ce.EvidenceID = temp.Ext_EvidenceID_Credit				
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

		DELETE cls
		FROM CTS_DataCenter.CTSCustomerClassificationAgency AS cls
			INNER JOIN Temp_CustomerClassification AS temp ON cls.CustID = temp.CustID
																AND cls.CategoryID = temp.CategoryID
		WHERE temp.IsRemovedPA = 1;
		
		INSERT IGNORE INTO CTS_DataCenter.CTSCustomerClassificationAgency_History(
				CustID, CTSCustID, CategoryID, ParentID, LastModifiedDate, LastModifiedBy, ActionType
			, 	InsertDate, TargetCC, SourceTypeID, IsDataChanged, TargetDangerLevel1,TurnoverRM, WinlossRM
			, 	BetCount, IsMarkedDirectly, Remark)
		SELECT DISTINCT 
				temp.CustID
			, 	temp.CTSCustID
			, 	NULL AS CategoryID
			, 	CONST_AGENCY_PARENTID_PA AS ParentID
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
			,	NULL AS IsMarkedDirectly
			,	temp.Remark
		FROM Temp_CustomerClassification AS temp
		WHERE temp.IsRemovedPA = 1;
		
		INSERT IGNORE INTO CTS_DataCenter.CTSCustomerClassificationAgency_Log(
				CustID, CTSCustID, CategoryID, ParentID, LastModifiedDate, LastModifiedBy, ActionType
			, 	InsertDate, TargetCC, SourceTypeID, IsDataChanged, TargetDangerLevel1,TurnoverRM, WinlossRM
			, 	BetCount, IsMarkedDirectly)
		SELECT DISTINCT 
				temp.CustID
			, 	temp.CTSCustID
			, 	NULL AS CategoryID
			, 	CONST_AGENCY_PARENTID_PA AS ParentID
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
			,	NULL AS IsMarkedDirectly
		FROM Temp_Customer AS temp;
        
	ELSEIF ip_InputFlowID = CONST_AGENCY_INPUTFLOWID_GENERAL_REMOVE_CONSIDERABLEDANGER THEN
		SET lv_IsDataChanged	= 0;
        
		DELETE cls
		FROM CTS_DataCenter.CTSCustomerClassificationAgency AS cls
			INNER JOIN Temp_CustomerClassification AS temp ON temp.CustID = cls.CustID
		WHERE cls.ParentID = CONST_AGENCY_PARENTID_CONSIDERABLEDANGER
			AND temp.IsRemovedConsiderableDanger = 1;
        
        INSERT INTO CTS_DataCenter.CTSCustomerClassificationAgency_Log(
				CustID, CTSCustID, CategoryID, ParentID, LastModifiedDate, LastModifiedBy, ActionType, IsAuto
			, 	InsertDate, IsDataChanged)
		SELECT 	temp.CustID
			, 	temp.CTSCustID
			,   temp.CategoryID
			,   CONST_AGENCY_PARENTID_CONSIDERABLEDANGER AS ParentID
			, 	lv_CurrentDateTime AS LastModifiedDate
			, 	temp.CreatedBy AS LastModifiedBy
			,   CONST_ACTIONTYPE_REMOVE AS ActionType
			,   lv_IsAuto AS IsAuto
			,   DATE(lv_CurrentDateTime) AS InsertDate
			,	lv_IsDataChanged AS IsDataChanged
		FROM Temp_CustomerClassification AS temp
		WHERE temp.IsRemovedConsiderableDanger = 1;	
        
	END IF;

END$$
DELIMITER ;