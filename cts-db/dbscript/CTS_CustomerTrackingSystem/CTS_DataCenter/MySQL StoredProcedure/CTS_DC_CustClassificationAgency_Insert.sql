/*<info serverAlias="CTSMain-CTS_DataCenter" databaseType="2" executers="ctsServiceAdmin" isFunction="0" isNested="0"></info>*/
DROP PROCEDURE IF EXISTS `CTS_DC_CustClassificationAgency_Insert`;

DELIMITER $$
CREATE DEFINER=`ctsOwner`@`%` PROCEDURE `CTS_DC_CustClassificationAgency_Insert`(
		IN	ip_InputFlowID			INT 
	,	IN	ip_FromAction			TINYINT
	,	IN	ip_UplineRoleID			INT
	,	IN	ip_QueueID				BIGINT
	,	IN	ip_IsAffectDownline		TINYINT(1)
	,	IN	ip_IsToQueue			TINYINT(1)
	,	IN	ip_CustInfo				JSON
	,	OUT op_ErrorMessage 		VARCHAR(2000)
)
SQL SECURITY INVOKER
BEGIN
/*
		Created:	20240927@Thomas.Nguyen
		Task:		Insert main Agency categories for Agency Classification
		DB:			CTS_DataCenter
		
		Param's Expanation:
			1. ip_InputFlowID: Used to identify flows: Insert/Rescan/Remove. Details of this can be found from StaticList (ListID = 24)
			2. From CTSWeb (1), From CTS API (2), From CTS Service (3), From Manual Trigger (4)
			3. ip_UplineRoleID: From Web (NULL), From Service (<UplineRoleID>)
			4. ip_QueueID: From Web (NULL), From Service (<QueueID>)
			5. ip_IsAffectDownline: From Web (0,1), From Service (NULL)
			6. ip_IsToQueue: Insert SMA PA to queue PA
			7. ip_CustInfo: 
			8. op_ErrorMessage:
				
		Example:
			- CALL CTS_DC_CustClassificationAgency_Insert(1001, 1, null, null, false, false, '[{"CustID":24180504,"CTSCustID":11194,"SubscriberID":168,"RoleID":2,"CreatedBy":8,"Remark":"Thomas test"}]', @outParam7);
			
		Revisions: 
			- 20240927@Thomas.Nguyen: Created [Redmine ID: #185799]
            - 20250725@Casey.Huynh: Agent CC, Insert Considerable Agency [Redmine ID: #219679]
*/
	DECLARE CONST_AGENCY_PARENTID_VVIP 									INT;
	DECLARE CONST_AGENCY_PARENTID_PA									INT;
	DECLARE CONST_AGENCY_CC_VVIP										INT;
	DECLARE CONST_AGENCY_INPUTFLOWID_GENERAL_INSERT_VVIP				INT;
	DECLARE CONST_AGENCY_INPUTFLOWID_GENERAL_INSERT_PACATEGORY			INT;
	DECLARE CONST_AGENCY_INPUTFLOWID_GENERAL_INSERT_NORMAL				INT;   
	DECLARE CONST_AGENCY_INPUTFLOWID_GENERAL_RESCAN_PACATEGORY			INT;
	
	DECLARE lv_MaxCTSCustID												BIGINT;
	DECLARE lv_LogTypeID												INT;
	DECLARE lv_SPName 													VARCHAR(200) DEFAULT 'CTS_DC_CustClassificationAgency_Insert';
	DECLARE lv_LogInfo 													VARCHAR(500);
	DECLARE lv_CreatedBy												INT;
	DECLARE	lv_CurrentDateTime											DATETIME DEFAULT CURRENT_TIMESTAMP();

	SET CONST_AGENCY_PARENTID_VVIP 										= CTS_DataCenter.CTS_DC_CategoryTypeParent_Get ('CONST_AGENCY_PARENTID_VVIP');
	SET CONST_AGENCY_PARENTID_PA										= CTS_DataCenter.CTS_DC_CategoryTypeParent_Get ('CONST_AGENCY_PARENTID_PA');
	SET CONST_AGENCY_CC_VVIP											= CTS_DataCenter.CTS_DC_CategoryTypeParent_Get ('CONST_AGENCY_CC_VVIP');
	SET CONST_AGENCY_INPUTFLOWID_GENERAL_INSERT_VVIP				    = CTS_DataCenter.CTS_DC_CategoryTypeParent_Get ('CONST_AGENCY_INPUTFLOWID_GENERAL_INSERT_VVIP');
	SET CONST_AGENCY_INPUTFLOWID_GENERAL_INSERT_PACATEGORY			    = CTS_DataCenter.CTS_DC_CategoryTypeParent_Get ('CONST_AGENCY_INPUTFLOWID_GENERAL_INSERT_PACATEGORY');
	SET CONST_AGENCY_INPUTFLOWID_GENERAL_INSERT_NORMAL				    = CTS_DataCenter.CTS_DC_CategoryTypeParent_Get ('CONST_AGENCY_INPUTFLOWID_GENERAL_INSERT_NORMAL');	
	SET CONST_AGENCY_INPUTFLOWID_GENERAL_RESCAN_PACATEGORY			    = CTS_DataCenter.CTS_DC_CategoryTypeParent_Get ('CONST_AGENCY_INPUTFLOWID_GENERAL_RESCAN_PACATEGORY');

	/*STEP 1: Parse raw data and get custinfo*/
	CALL CTS_DataCenter.CTS_DC_CustClassificationAgency_Insert_GetInfo (ip_InputFlowID,ip_FromAction,ip_UplineRoleID,ip_CustInfo);
	
	/*STEP 2: Preprocess*/
	IF ip_InputFlowID IN (CONST_AGENCY_INPUTFLOWID_GENERAL_INSERT_NORMAL) THEN
		
		CALL CTS_DataCenter.CTS_DC_CustClassificationAgency_Insert_PreProcess (ip_InputFlowID);
		
	END IF;
	
	/*STEP 3: Process*/
	IF ip_InputFlowID NOT IN (CONST_AGENCY_INPUTFLOWID_GENERAL_INSERT_VVIP) THEN
		
		CALL CTS_DataCenter.CTS_DC_CustClassificationAgency_Insert_Process (ip_InputFlowID);
		
	END IF;
	
	/*STEP 4: Complete*/
	CALL CTS_DataCenter.CTS_DC_CustClassificationAgency_Insert_Complete (ip_InputFlowID,ip_IsAffectDownline);
	
	/*STEP 5: User Log and More*/
	IF ip_InputFlowID = CONST_AGENCY_INPUTFLOWID_GENERAL_INSERT_VVIP THEN
		
		IF ip_FromAction = 1 THEN
			SET lv_LogTypeID = 10;
		
			INSERT INTO CTS_Admin.UserLog(LogTypeID, SPName, LogInfo, CreatedDate, CreatedBy)
			SELECT  lv_LogTypeID
				, 	lv_SPName
				, 	CONCAT('Insert VVIP: CTSCustID_', temp.CTSCustID,'; CustID_', temp.CustID,'; RoleID_', temp.RoleID, '; AffectDownline_', ip_IsAffectDownline,'; SubscriberID_', temp.SubscriberID, '; CategoryID_', temp.NewCategoryID, '; Remark_', temp.Remark)
				,	lv_CurrentDateTime AS CreatedDate
				, 	temp.CreatedBy
			FROM Temp_NewClassification AS temp;
		
		ELSEIF ip_FromAction = 3 AND ip_QueueID IS NOT NULL THEN
			SELECT MAX(tmpCus.CTSCustID)
			INTO lv_MaxCTSCustID
			FROM Temp_NewClassification AS tmpCus;
		
			UPDATE CTS_DataCenter.CTSCustomerClassificationQueue AS que
			SET que.LastDownlineCTSCustID = lv_MaxCTSCustID
			WHERE que.ID = ip_QueueID;
		END IF;
	
	ELSEIF ip_IsToQueue = 1 THEN /*PA*/
		SET lv_LogTypeID = 32;
	
		/*From PAM*/
		SELECT CreatedBy
		INTO lv_CreatedBy
		FROM Temp_NewClassification
		WHERE IsFromCTS = 1
		LIMIT 1;
		
		IF lv_CreatedBy IS NOT NULL THEN
			SELECT LEFT(CONCAT('CustNo.:',COUNT(1),'_',GROUP_CONCAT(DISTINCT CTSCustID)),500)
			INTO lv_LogInfo
			FROM Temp_NewClassification;
			
			INSERT INTO CTS_Admin.UserLog(LogTypeID, SPName, LogInfo, CreatedDate, CreatedBy)
			SELECT	lv_LogTypeID
				,	lv_SPName
				,	lv_LogInfo AS LogInfo
				,	lv_CurrentDateTime AS CreatedDate
				,	lv_CreatedBy
			FROM Temp_NewClassification;
			
		END IF;
		
	END IF;
	
	/*STEP 6: AffectedDownline*/
	IF (ip_IsToQueue = 1 OR (ip_FromAction = 3 AND ip_IsAffectDownline = 1)) THEN
		CALL CTS_DataCenter.CTS_DC_CustClassification_AffectedDownline_Insert ('Temp_NewClassification',ip_InputFlowID);
	END IF;
	
	/*STEP 7: Insert Evidence*/
	IF ip_InputFlowID IN (CONST_AGENCY_INPUTFLOWID_GENERAL_INSERT_PACATEGORY,
							CONST_AGENCY_INPUTFLOWID_GENERAL_RESCAN_PACATEGORY) THEN /*PA*/
		/*For Root*/
		INSERT IGNORE INTO CTS_DataCenter.CustEvidence(CTSCustID, EvidenceID, Remark, `Level`, FromCustID,  CreatedDate, CreatedBy)
		SELECT 	temp.CTSCustID
			,	temp.ToEvidenceID
			,	temp.Remark
			,	0 AS `Level`
			,	temp.CTSCustID
			,	lv_CurrentDateTime AS CreatedDate
			,	temp.CreatedBy
		FROM Temp_NewClassification AS temp    
		WHERE (temp.ToEvidenceID <> 0) AND (temp.ToEvidenceID IS NOT NULL);
		
		/*Queue*/
		INSERT IGNORE INTO CTS_DataCenter.CustEvidenceAffectedQueueInsert(CTSCustID, EvidenceID, Remark, CreatedBy, Created)
		SELECT 	temp.CTSCustID
			,	temp.ToEvidenceID
			,	temp.Remark
			,	temp.CreatedBy
			,	lv_CurrentDateTime AS CreatedDate
		FROM Temp_NewClassification AS temp
		WHERE (temp.ToEvidenceID) IS NOT NULL AND (temp.DataChangeType = 0 OR temp.IsFromOldPA = 1); 
		
	END IF;
	
	/*STEP N: Return data*/
	SELECT DISTINCT 
			temp.CTSCustID
		,  	temp.CustID
		,	CASE WHEN ParentID = CONST_AGENCY_PARENTID_VVIP THEN CONST_AGENCY_CC_VVIP ELSE temp.TargetCC END AS CustomerClass
		,  	CASE WHEN ParentID = CONST_AGENCY_PARENTID_VVIP THEN 0 ELSE temp.NewCategoryID END AS CategoryID
		,	CASE WHEN ParentID = CONST_AGENCY_PARENTID_PA AND temp.IsRobot = 0 THEN 1 ELSE 0 END AS IsPA
		,	lv_CurrentDateTime AS ScannedTime 
	FROM Temp_NewClassification AS temp
	WHERE temp.IsReturnData = 1;
	
END$$
DELIMITER ;