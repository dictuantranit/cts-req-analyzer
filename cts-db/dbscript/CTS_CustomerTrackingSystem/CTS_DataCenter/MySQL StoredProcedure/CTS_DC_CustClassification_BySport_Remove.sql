/*<info serverAlias="CTSMain-CTS_DataCenter" databaseType="2" executers="ctsServiceAdmin" isFunction="0" isNested="0"></info>*/
DROP PROCEDURE IF EXISTS `CTS_DC_CustClassification_BySport_Remove`;

DELIMITER $$
CREATE DEFINER=`ctsOwner`@`%` PROCEDURE `CTS_DC_CustClassification_BySport_Remove`(
		IN	ip_InputFlowID			INT
	,	IN	ip_CustInfo				JSON
	,	OUT op_ErrorMessage 		VARCHAR(200)
)
SQL SECURITY INVOKER
BEGIN
/*
		Created:	20240618@Victoria.Le
		Task:		Remove main customer categories for Customer Classification
		DB:			CTS_DataCenter
		
		Param's Expanation:
			- ip_InputFlowID: Used to identify flows: Insert/Rescan/Remove. Details of this can be found from StaticList (ListID = 24)
			- ip_CustInfo:
		
		Example:
			- CALL CTS_DC_CustClassification_BySport_Remove(442, '[{"CustID":1275,"CategoryID":40700,"CategoryGroupID":0,"CreatedTime":"2024-07-02T02:32:57.063","TurnoverRM":0.0,"WinlossRM":0.0,"BetCount":0,"ActiveDays":0,"PerformanceTime":"2024-07-02T02:32:57.063","LastXDaysMargin":0.0,"ProbationPeriodWinloss":0.0,"TaggingID":0,"TaggingType":0,"TWBetCount":0,"TWGroupBettingRate":0.0,"TWTicketRejectRate":0.0,"TWDesktopUsageRate":0.0,"ScanTaggingType":0},{"CustID":1280,"CategoryID":0,"CategoryGroupID":40100,"CreatedTime":"2024-07-02T02:32:57.063","TurnoverRM":0.0,"WinlossRM":0.0,"BetCount":0,"ActiveDays":0,"PerformanceTime":"2024-07-02T02:32:57.063","LastXDaysMargin":0.0,"ProbationPeriodWinloss":0.0,"TaggingID":0,"TaggingType":0,"TWBetCount":0,"TWGroupBettingRate":0.0,"TWTicketRejectRate":0.0,"TWDesktopUsageRate":0.0,"ScanTaggingType":0},{"CustID":5002646,"CategoryID":40700,"CategoryGroupID":0,"CreatedTime":"2024-07-02T02:32:57.063","TurnoverRM":0.0,"WinlossRM":0.0,"BetCount":0,"ActiveDays":0,"PerformanceTime":"2024-07-02T02:32:57.063","LastXDaysMargin":0.0,"ProbationPeriodWinloss":0.0,"TaggingID":0,"TaggingType":0,"TWBetCount":0,"TWGroupBettingRate":0.0,"TWTicketRejectRate":0.0,"TWDesktopUsageRate":0.0,"ScanTaggingType":0},{"CustID":5022391,"CategoryID":0,"CategoryGroupID":40100,"CreatedTime":"2024-07-02T02:32:57.063","TurnoverRM":0.0,"WinlossRM":0.0,"BetCount":0,"ActiveDays":0,"PerformanceTime":"2024-07-02T02:32:57.063","LastXDaysMargin":0.0,"ProbationPeriodWinloss":0.0,"TaggingID":0,"TaggingType":0,"TWBetCount":0,"TWGroupBettingRate":0.0,"TWTicketRejectRate":0.0,"TWDesktopUsageRate":0.0,"ScanTaggingType":0}]', @outParam7);

		Revisions: 
			- 20240618@Victoria.Le: 		Initial Writing [Redmine ID: #205317]
			
*/
	DECLARE CONST_PARENTID_WRAPPER 							INT;
	DECLARE CONST_CATEID_SPECIALCC 							INT;
	DECLARE CONST_ACTIONTYPE_REMOVE 						INT DEFAULT 2;
	DECLARE CONST_SOURCETYPE_CUSTOMERCLASS_REMOVE_MANUAL	INT DEFAULT 12;
	DECLARE CONST_INPUTFLOWID_BYSPORT_REMOVE_SPECIALCC		INT;
	
	DECLARE lv_ActionType									INT;
	DECLARE lv_IsAuto										TINYINT(1);
	DECLARE lv_TargetCC										INT;
	DECLARE lv_IsDataChanged								TINYINT(1);
	DECLARE lv_SourceTypeID									INT;
	DECLARE lv_LogTypeID									INT;
	DECLARE lv_CreatedBy									INT;
	DECLARE lv_SPName 										VARCHAR(200) DEFAULT 'CTS_DC_CustClassification_BySport_Remove';
	DECLARE lv_CurrentDateTime 								DATETIME DEFAULT CURRENT_TIMESTAMP();
	DECLARE lv_ListCustInfo									LONGTEXT;
	
	SET CONST_PARENTID_WRAPPER								= CTS_DC_CategoryTypeParent_Get ('CONST_PARENTID_WRAPPER');
	SET CONST_CATEID_SPECIALCC								= CTS_DC_CategoryTypeParent_Get ('CONST_CATEID_SPECIALCC');
	SET CONST_INPUTFLOWID_BYSPORT_REMOVE_SPECIALCC			= CTS_DC_CategoryTypeParent_Get ('CONST_INPUTFLOWID_BYSPORT_REMOVE_SPECIALCC');

	DROP TEMPORARY TABLE IF EXISTS Temp_CustomerClassification;
	CREATE TEMPORARY TABLE Temp_CustomerClassification (
			CustID								BIGINT UNSIGNED 
		, 	CTSCustID							BIGINT UNSIGNED
		, 	SubscriberID						INT UNSIGNED
		,	SportID								SMALLINT UNSIGNED
		,	Remark 								VARCHAR(500) 
		,	CreatedBy 							INT UNSIGNED
		,	IsReturnData						TINYINT(1) DEFAULT 0
		,	INDEX IX_Temp_CC_CustID_SportID (CustID, SportID)
	);

	IF ip_InputFlowID = CONST_INPUTFLOWID_BYSPORT_REMOVE_SPECIALCC THEN
		SET lv_ActionType 			= CONST_ACTIONTYPE_REMOVE;
		SET lv_IsAuto 				= 0;
		SET lv_TargetCC				= -1;
		SET lv_IsDataChanged		= 1;
		SET lv_SourceTypeID			= CONST_SOURCETYPE_CUSTOMERCLASS_REMOVE_MANUAL;
		SET lv_LogTypeID 			= 20;
	
		INSERT INTO Temp_CustomerClassification(CustID, CTSCustID, SubscriberID, SportID, CreatedBy, Remark, IsReturnData)
		SELECT temp.CustID, temp.CTSCustID, temp.SubscriberID, temp.SportID, temp.CreatedBy, temp.Remark, 1 AS IsReturnData
		FROM JSON_TABLE(ip_CustInfo,
						"$[*]" COLUMNS(
											CTSCustID				BIGINT UNSIGNED			PATH '$.CTSCustID'
										,	CustID					BIGINT UNSIGNED			PATH '$.CustID'
										,	SubscriberID			INT	UNSIGNED			PATH '$.SubscriberID'
										,	SportID					SMALLINT UNSIGNED		PATH '$.SportID'
										,	Remark					VARCHAR(500)			PATH '$.Remark'
										,	CreatedBy 				INT UNSIGNED			PATH "$.CreatedBy"
										)) AS temp;    
		
		DELETE s
		FROM CTS_DataCenter.SpecialCustomerClass_BySport AS s
			INNER JOIN Temp_CustomerClassification AS temp ON temp.CTSCustID = s.CTSCustID AND temp.SportID = s.SportID;
			
		INSERT INTO CTS_DataCenter.SpecialCustomerClass_BySport_History(
				CTSCustID, CustID, SportID, SubscriberID, CustomerClass, CreatedBy, CreatedDate
			, 	LastModifiedBy, LastModifiedDate, Remark, ActionType)
		SELECT 	temp.CTSCustID
			,	temp.CustID
			,	temp.SportID
			,	temp.SubscriberID
			,	lv_TargetCC AS CustomerClass
			,	temp.CreatedBy
			,	lv_CurrentDateTime AS CreatedDate
			,	temp.CreatedBy AS LastModifiedBy
			,	lv_CurrentDateTime AS LastModifiedDate
			,	temp.Remark
			,	lv_ActionType AS ActionType
		FROM Temp_CustomerClassification AS temp;
		
		DELETE cls
		FROM CTS_DataCenter.CTSCustomerClassification_BySport AS cls
			INNER JOIN Temp_CustomerClassification AS temp ON temp.CustID = cls.CustID 
																AND temp.SportID = cls.SportID
																AND cls.ParentID = CONST_PARENTID_WRAPPER
																AND cls.CategoryID = CONST_CATEID_SPECIALCC;
		
		INSERT INTO CTS_DataCenter.CTSCustomerClassification_BySport_History(
				CustID, CTSCustID, ParentID, CategoryID, SportID, LastModifiedDate, LastModifiedBy, ActionType, InsertDate
			, 	TargetCC, Remark, SourceTypeID)
		SELECT  temp.CustID
			,   temp.CTSCustID
			,   CONST_PARENTID_WRAPPER AS ParentID
			,   CONST_CATEID_SPECIALCC AS CategoryID
			,	temp.SportID
			,   lv_CurrentDateTime AS LastModifiedDate
			,   temp.CreatedBy AS LastModifiedBy
			,   lv_ActionType AS ActionType
			,   DATE(lv_CurrentDateTime) AS InsertDate
			,   lv_TargetCC AS TargetCC
			,   temp.Remark
			,	lv_SourceTypeID
		FROM Temp_CustomerClassification AS temp;
		
		INSERT INTO CTS_DataCenter.CTSCustomerClassification_BySport_Log(
				CustID, CTSCustID, ParentID, CategoryID, SportID, LastModifiedDate, LastModifiedBy, ActionType, InsertDate
			, 	TargetCC, Remark, SourceTypeID)
		SELECT  temp.CustID
			,   temp.CTSCustID
			,   CONST_PARENTID_WRAPPER AS ParentID
			,   CONST_CATEID_SPECIALCC AS CategoryID
			,	temp.SportID
			,   lv_CurrentDateTime AS LastModifiedDate
			,   temp.CreatedBy AS LastModifiedBy
			,   lv_ActionType AS ActionType
			,   DATE(lv_CurrentDateTime) AS InsertDate
			,   lv_TargetCC AS TargetCC
			,   temp.Remark
			,	lv_SourceTypeID
		FROM Temp_CustomerClassification AS temp;	

		SELECT CreatedBy
		INTO lv_CreatedBy
		FROM Temp_CustomerClassification AS temp
		LIMIT 1;
		
		SELECT JSON_ARRAYAGG(JSON_OBJECT('CTSCustID',CTSCustID,'CustID',CustID,'SportID',SportID))
		INTO lv_ListCustInfo
		FROM Temp_CustomerClassification AS temp;
		
		INSERT INTO CTS_Admin.UserLog(LogTypeID, SPName, LogInfo, CreatedDate, CreatedBy)
		SELECT	lv_LogTypeID AS LogTypeID
			,	lv_SPName
			,	CONCAT('Remove special customer class by sport: CTSCustList-CustID-SportID: ', lv_ListCustInfo)
			,	lv_CurrentDateTime
			,	lv_CreatedBy
		FROM Temp_CustomerClassification AS temp;
		
	END IF;

	SELECT CTSCustID, CustID, SportID
	FROM Temp_CustomerClassification AS temp;

END$$
DELIMITER ;