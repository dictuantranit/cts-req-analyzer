/*<info serverAlias="CTSMain-CTS_DataCenter" databaseType="2" executers="ctsServiceAdmin" isFunction="0" isNested="0"></info>*/
DROP PROCEDURE IF EXISTS `CTS_DC_CustClassification_Insert`;

DELIMITER $$
CREATE DEFINER=`ctsOwner`@`%` PROCEDURE `CTS_DC_CustClassification_Insert`(
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
		Created:	20240618@Victoria.Le
		Task:		Insert main customer categories for Customer Classification
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
			- Param's Input:
				+ InputFlow = VVIP: 2 + 3 + 4 + 5 + 7
				+ InputFlow = SpecialCC: 7
				+ InputFlow = LicVIP: 7
				+ InputFlow = LicBA: 7
				+ InputFlow = PA: 6 + 7
				+ InputFlow = Robot: 7
				+ InputFlow = PotentialPA: 7
				+ InputFlow = Normal: 7
				
		Example:
			- CALL CTS_DataCenter.CTS_DC_CustClassification_Insert(9, 3, NULL, NULL, NULL, false, '[{"CustID":1275,"CategoryID":40700,"CategoryGroupID":0,"CreatedTime":"2024-07-02T02:32:57.063","TurnoverRM":0.0,"WinlossRM":0.0,"BetCount":0,"ActiveDays":0,"PerformanceTime":"2024-07-02T02:32:57.063","LastXDaysMargin":0.0,"ProbationPeriodWinloss":0.0,"TaggingID":0,"TaggingType":0,"TWBetCount":0,"TWGroupBettingRate":0.0,"TWTicketRejectRate":0.0,"TWDesktopUsageRate":0.0,"ScanTaggingType":0},{"CustID":1280,"CategoryID":0,"CategoryGroupID":40100,"CreatedTime":"2024-07-02T02:32:57.063","TurnoverRM":0.0,"WinlossRM":0.0,"BetCount":0,"ActiveDays":0,"PerformanceTime":"2024-07-02T02:32:57.063","LastXDaysMargin":0.0,"ProbationPeriodWinloss":0.0,"TaggingID":0,"TaggingType":0,"TWBetCount":0,"TWGroupBettingRate":0.0,"TWTicketRejectRate":0.0,"TWDesktopUsageRate":0.0,"ScanTaggingType":0},{"CustID":5002646,"CategoryID":40700,"CategoryGroupID":0,"CreatedTime":"2024-07-02T02:32:57.063","TurnoverRM":0.0,"WinlossRM":0.0,"BetCount":0,"ActiveDays":0,"PerformanceTime":"2024-07-02T02:32:57.063","LastXDaysMargin":0.0,"ProbationPeriodWinloss":0.0,"TaggingID":0,"TaggingType":0,"TWBetCount":0,"TWGroupBettingRate":0.0,"TWTicketRejectRate":0.0,"TWDesktopUsageRate":0.0,"ScanTaggingType":0},{"CustID":5022391,"CategoryID":0,"CategoryGroupID":40100,"CreatedTime":"2024-07-02T02:32:57.063","TurnoverRM":0.0,"WinlossRM":0.0,"BetCount":0,"ActiveDays":0,"PerformanceTime":"2024-07-02T02:32:57.063","LastXDaysMargin":0.0,"ProbationPeriodWinloss":0.0,"TaggingID":0,"TaggingType":0,"TWBetCount":0,"TWGroupBettingRate":0.0,"TWTicketRejectRate":0.0,"TWDesktopUsageRate":0.0,"ScanTaggingType":0}]', @outParam7);
			
		Revisions: 
			- 20240618@Victoria.Le:		Initial Writing [Redmine ID: #205317]
            - 20240923@Jonas.Huynh:		Change CC Priority of Robot- Potential Risk  [RedmineID: #209792]
			- 20240927@Thomas.Nguyen:	Moved AffectedDownline to Agent's CC flow [Redmine ID: #185799]
            - 20241203@Jonas.Huynh: 	CC 210x - Device Association [Redmine ID: #214353]
            - 20250725@Casey.Huynh:		Agent CC, Insert Considerable Agency Queue [Redmine ID: #219679]
            
*/
	DECLARE CONST_CATEID_VVIP 								INT;
	DECLARE CONST_PARENTID_PA               				INT;
	DECLARE CONST_CC_VVIP	 								INT;
	DECLARE CONST_INPUTFLOWID_GENERAL_INSERT_VVIP			INT;
	DECLARE CONST_INPUTFLOWID_GENERAL_INSERT_SPECIALCC		INT;
	DECLARE CONST_INPUTFLOWID_GENERAL_INSERT_LICVIP			INT;
	DECLARE CONST_INPUTFLOWID_GENERAL_INSERT_LICBA			INT;
	DECLARE CONST_INPUTFLOWID_GENERAL_INSERT_PACATEGORY		INT;
	DECLARE CONST_INPUTFLOWID_GENERAL_INSERT_PAREASON		INT;
	DECLARE CONST_INPUTFLOWID_GENERAL_INSERT_NORMAL			INT;
	
	DECLARE CONST_INPUTFLOWID_GENERAL_RESCAN_PACATEGORY		INT;
	DECLARE CONST_INPUTFLOWID_GENERAL_RESCAN_PAREASON		INT;
    
	DECLARE CONST_BIZCATEGROUPID_NORMAL						INT;
	
	DECLARE lv_MaxCTSCustID									BIGINT;
	DECLARE lv_LogTypeID									INT;
	DECLARE lv_SPName 										VARCHAR(200) DEFAULT 'CTS_DC_CustClassification_Insert';
	DECLARE lv_LogInfo 										VARCHAR(500);
	DECLARE lv_CreatedBy									INT;
	DECLARE	lv_CurrentDateTime								DATETIME DEFAULT CURRENT_TIMESTAMP();
	DECLARE lv_Ext_CateGroupID_VVIP							INT;

	SET CONST_CATEID_VVIP									= CTS_DataCenter.CTS_DC_CategoryTypeParent_Get ('CONST_CATEID_VVIP');
	SET CONST_PARENTID_PA									= CTS_DataCenter.CTS_DC_CategoryTypeParent_Get ('CONST_PARENTID_PA');
	SET CONST_CC_VVIP										= CTS_DataCenter.CTS_DC_CategoryTypeParent_Get ('CONST_CC_VVIP');
	SET CONST_INPUTFLOWID_GENERAL_INSERT_VVIP				= CTS_DataCenter.CTS_DC_CategoryTypeParent_Get ('CONST_INPUTFLOWID_GENERAL_INSERT_VVIP');
	SET CONST_INPUTFLOWID_GENERAL_INSERT_SPECIALCC			= CTS_DataCenter.CTS_DC_CategoryTypeParent_Get ('CONST_INPUTFLOWID_GENERAL_INSERT_SPECIALCC');
	SET CONST_INPUTFLOWID_GENERAL_INSERT_LICVIP				= CTS_DataCenter.CTS_DC_CategoryTypeParent_Get ('CONST_INPUTFLOWID_GENERAL_INSERT_LICVIP');
	SET CONST_INPUTFLOWID_GENERAL_INSERT_LICBA				= CTS_DataCenter.CTS_DC_CategoryTypeParent_Get ('CONST_INPUTFLOWID_GENERAL_INSERT_LICBA');
	SET CONST_INPUTFLOWID_GENERAL_INSERT_PACATEGORY			= CTS_DataCenter.CTS_DC_CategoryTypeParent_Get ('CONST_INPUTFLOWID_GENERAL_INSERT_PACATEGORY');
	SET CONST_INPUTFLOWID_GENERAL_INSERT_PAREASON			= CTS_DataCenter.CTS_DC_CategoryTypeParent_Get ('CONST_INPUTFLOWID_GENERAL_INSERT_PAREASON');
	SET CONST_INPUTFLOWID_GENERAL_INSERT_NORMAL				= CTS_DataCenter.CTS_DC_CategoryTypeParent_Get ('CONST_INPUTFLOWID_GENERAL_INSERT_NORMAL');
	
	SET CONST_INPUTFLOWID_GENERAL_RESCAN_PACATEGORY			= CTS_DataCenter.CTS_DC_CategoryTypeParent_Get ('CONST_INPUTFLOWID_GENERAL_RESCAN_PACATEGORY');
	SET CONST_INPUTFLOWID_GENERAL_RESCAN_PAREASON			= CTS_DataCenter.CTS_DC_CategoryTypeParent_Get ('CONST_INPUTFLOWID_GENERAL_RESCAN_PAREASON');
	
    SET CONST_BIZCATEGROUPID_NORMAL 						= CTS_DataCenter.CTS_DC_CategoryTypeParent_Get ('CONST_BIZCATEGROUPID_NORMAL');
	
	/*STEP 1: Parse raw data and get custinfo*/
	CALL CTS_DataCenter.CTS_DC_CustClassification_Insert_GetInfo (ip_InputFlowID,ip_FromAction,ip_UplineRoleID,ip_CustInfo);
	
	/*STEP 2: Preprocess*/
	IF ip_InputFlowID IN (CONST_INPUTFLOWID_GENERAL_INSERT_NORMAL,CONST_INPUTFLOWID_GENERAL_INSERT_PAREASON) THEN
		
		CALL CTS_DataCenter.CTS_DC_CustClassification_Insert_PreProcess (ip_InputFlowID);
		
	END IF;
	
	/*STEP 3: Process*/
	IF ip_InputFlowID NOT IN (CONST_INPUTFLOWID_GENERAL_INSERT_VVIP,CONST_INPUTFLOWID_GENERAL_INSERT_SPECIALCC,
								CONST_INPUTFLOWID_GENERAL_INSERT_LICVIP,CONST_INPUTFLOWID_GENERAL_INSERT_LICBA) THEN
		
		CALL CTS_DataCenter.CTS_DC_CustClassification_Insert_Process (ip_InputFlowID);
		
	END IF;
	
	/*STEP 4: Complete*/
	CALL CTS_DataCenter.CTS_DC_CustClassification_Insert_Complete (ip_InputFlowID,ip_IsAffectDownline);
	
	/*STEP 5: User Log and More*/
	IF ip_InputFlowID = CONST_INPUTFLOWID_GENERAL_INSERT_VVIP THEN
		
		SELECT 	cc.Ext_CategoryGroupID
		INTO 	lv_Ext_CateGroupID_VVIP
		FROM 	CTS_DataCenter.CustomerCategory AS cc 
		WHERE 	cc.CategoryID = CONST_CATEID_VVIP;
		
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
	
	ELSEIF ip_InputFlowID = CONST_INPUTFLOWID_GENERAL_INSERT_SPECIALCC THEN 
		SET lv_LogTypeID = 19;
		
		SELECT CreatedBy
		INTO lv_CreatedBy
		FROM Temp_NewClassification
		LIMIT 1;
	
		INSERT INTO CTS_Admin.UserLog(LogTypeID, SPName, LogInfo, CreatedDate, CreatedBy)
		SELECT	lv_LogTypeID
			,	lv_SPName
			,	CONCAT('Insert SpecialCustomerClass: CTSCustList: ', GROUP_CONCAT(CTSCustID),';CustIDList: ', GROUP_CONCAT(CustID), ';CustomerClass: ', GROUP_CONCAT(DISTINCT TargetCC)) AS LogInfo
			,	lv_CurrentDateTime AS CreatedDate
			,	lv_CreatedBy
		FROM Temp_NewClassification;
	
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
	
	/*STEP 6: AffectedDownline
	IF (ip_IsToQueue = 1 OR (ip_FromAction = 3 AND ip_IsAffectDownline = 1)) THEN
		CALL CTS_DataCenter.CTS_DC_CustClassification_AffectedDownline_Insert ('Temp_NewClassification',ip_InputFlowID);
	END IF;*/
	
	/*STEP 7: Insert Evidence*/
	IF ip_InputFlowID IN (CONST_INPUTFLOWID_GENERAL_INSERT_PACATEGORY,CONST_INPUTFLOWID_GENERAL_INSERT_PAREASON,
							CONST_INPUTFLOWID_GENERAL_RESCAN_PACATEGORY,CONST_INPUTFLOWID_GENERAL_RESCAN_PAREASON) THEN /*PA*/
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
		,	CASE WHEN temp.NewCategoryID = CONST_CATEID_VVIP THEN CONST_CC_VVIP ELSE temp.TargetCC END AS CustomerClass
		,  	CASE WHEN temp.NewCategoryID = CONST_CATEID_VVIP THEN lv_Ext_CateGroupID_VVIP ELSE temp.NewCategoryID END AS CategoryID
		,	CASE WHEN temp.ParentID = CONST_PARENTID_PA 
						AND temp.IsRobot = 0 
						AND cate.BusinessCategoryGroupID <> CONST_BIZCATEGROUPID_NORMAL 
				THEN 1 ELSE 0 END AS IsPA
		,	CASE WHEN s.FlowNormalDgrAssociation = 1 AND temp.NewCategoryID = s.CategoryID AND temp.OldCategoryID IS NULL THEN 1
				 WHEN s.FlowNormalDgrAssociation = 1 AND temp.NewCategoryID = s.CategoryID AND temp.OldCategoryID <> s.CategoryID THEN 1
                 WHEN s.FlowNormalDgrAssociation = 1 AND temp.NewCategoryID = s.CategoryID AND temp.OldCategoryID = temp.NewCategoryID AND temp.IsDataChanged = 1 THEN 1
				 ELSE 0 END AS IsScanDgrAssociation
		,	lv_CurrentDateTime AS ScannedTime 
	FROM Temp_NewClassification AS temp
		LEFT JOIN CTS_DataCenter.CustomerCategory AS cate ON cate.CategoryID = temp.NewCategoryID
        LEFT JOIN CTS_DataCenter.CustomerCategorySettings AS s ON s.CategoryID = cate.CategoryID
	WHERE temp.IsReturnData = 1;
	
END$$
DELIMITER ;