/*<info serverAlias="CTSMain-CTS_DataCenter" databaseType="2" executers="ctsServiceAdmin" isFunction="0" isNested="1"></info>*/
DROP PROCEDURE IF EXISTS `CTS_DC_CustClassification_BySport_Insert_GetInfo`;

DELIMITER $$
CREATE DEFINER=`ctsOwner`@`%` PROCEDURE `CTS_DC_CustClassification_BySport_Insert_GetInfo`(
		IN	ip_InputFlowID			INT 
	,	IN	ip_CustInfo				JSON
)
SQL SECURITY INVOKER
BEGIN
/*
		Created:	20240618@Victoria.Le
		Task:		Insert main customer categories for Customer Classification
		DB:			CTS_DataCenter
			
		Param's Expanation:
			- ip_InputFlowID:
			- ip_CustInfo:
			
		Example:
			- CALL CTS_DC_CustClassification_BySport_Insert_GetInfo(332, '[{"CustID":1275,"CategoryID":40700,"CategoryGroupID":0,"CreatedTime":"2024-07-02T02:32:57.063","TurnoverRM":0.0,"WinlossRM":0.0,"BetCount":0,"ActiveDays":0,"PerformanceTime":"2024-07-02T02:32:57.063","LastXDaysMargin":0.0,"ProbationPeriodWinloss":0.0,"TaggingID":0,"TaggingType":0,"TWBetCount":0,"TWGroupBettingRate":0.0,"TWTicketRejectRate":0.0,"TWDesktopUsageRate":0.0,"ScanTaggingType":0},{"CustID":1280,"CategoryID":0,"CategoryGroupID":40100,"CreatedTime":"2024-07-02T02:32:57.063","TurnoverRM":0.0,"WinlossRM":0.0,"BetCount":0,"ActiveDays":0,"PerformanceTime":"2024-07-02T02:32:57.063","LastXDaysMargin":0.0,"ProbationPeriodWinloss":0.0,"TaggingID":0,"TaggingType":0,"TWBetCount":0,"TWGroupBettingRate":0.0,"TWTicketRejectRate":0.0,"TWDesktopUsageRate":0.0,"ScanTaggingType":0},{"CustID":5002646,"CategoryID":40700,"CategoryGroupID":0,"CreatedTime":"2024-07-02T02:32:57.063","TurnoverRM":0.0,"WinlossRM":0.0,"BetCount":0,"ActiveDays":0,"PerformanceTime":"2024-07-02T02:32:57.063","LastXDaysMargin":0.0,"ProbationPeriodWinloss":0.0,"TaggingID":0,"TaggingType":0,"TWBetCount":0,"TWGroupBettingRate":0.0,"TWTicketRejectRate":0.0,"TWDesktopUsageRate":0.0,"ScanTaggingType":0},{"CustID":5022391,"CategoryID":0,"CategoryGroupID":40100,"CreatedTime":"2024-07-02T02:32:57.063","TurnoverRM":0.0,"WinlossRM":0.0,"BetCount":0,"ActiveDays":0,"PerformanceTime":"2024-07-02T02:32:57.063","LastXDaysMargin":0.0,"ProbationPeriodWinloss":0.0,"TaggingID":0,"TaggingType":0,"TWBetCount":0,"TWGroupBettingRate":0.0,"TWTicketRejectRate":0.0,"TWDesktopUsageRate":0.0,"ScanTaggingType":0}]');
			- CALL CTS_DC_CustClassification_BySport_Insert_GetInfo_xpre(335, '[{"CustID":1290,"CTSCustID":1003273192,"CategoryID":20900,"SportGroup":145,"TurnoverRM":20000.0,"WinlossRM":-10000.0,"CreatedBy":8,"Remark":null,"WinlossStatus":2,"MatchID":83717954,"BetCount":10,"ActiveDays":5,"PerformanceTime":"2025-11-17T02:32:57.063"}]');
		
		Revisions: 
			- 20240618@Victoria.Le: Initial Writing [Redmine ID: #205317]
			- 20251113@Thomas.Nguyen: Classify Saba Soccer in System Detect GB CC3101/CC3201 - Add new InputFlowID for PA [Redmine ID: #239995]
			
*/
	DECLARE CONST_PARENTID_WRAPPER 							INT;
	DECLARE CONST_CATEID_SPECIALCC 							INT;
	DECLARE CONST_INPUTFLOWID_BYSPORT_INSERT_NORMAL			INT;
	DECLARE CONST_INPUTFLOWID_BYSPORT_INSERT_SPECIALCC		INT;
	DECLARE CONST_INPUTFLOWID_BYSPORT_INSERT_PACATEGORY		INT;
	DECLARE CONST_INPUTFLOWID_BYSPORT_RESCAN_PACATEGORY		INT;

	DECLARE CONST_PARENTID_PA 								INT;
	
	SET CONST_PARENTID_PA 									= CTS_DataCenter.CTS_DC_CategoryTypeParent_Get ('CONST_PARENTID_PA');
	SET CONST_PARENTID_WRAPPER								= CTS_DataCenter.CTS_DC_CategoryTypeParent_Get ('CONST_PARENTID_WRAPPER');
	SET CONST_CATEID_SPECIALCC								= CTS_DataCenter.CTS_DC_CategoryTypeParent_Get ('CONST_CATEID_SPECIALCC');
	SET CONST_INPUTFLOWID_BYSPORT_INSERT_NORMAL				= CTS_DataCenter.CTS_DC_CategoryTypeParent_Get ('CONST_INPUTFLOWID_BYSPORT_INSERT_NORMAL');
	SET CONST_INPUTFLOWID_BYSPORT_INSERT_SPECIALCC			= CTS_DataCenter.CTS_DC_CategoryTypeParent_Get ('CONST_INPUTFLOWID_BYSPORT_INSERT_SPECIALCC');
	SET CONST_INPUTFLOWID_BYSPORT_INSERT_PACATEGORY			= CTS_DataCenter.CTS_DC_CategoryTypeParent_Get ('CONST_INPUTFLOWID_BYSPORT_INSERT_PACATEGORY');
	SET CONST_INPUTFLOWID_BYSPORT_RESCAN_PACATEGORY			= CTS_DataCenter.CTS_DC_CategoryTypeParent_Get ('CONST_INPUTFLOWID_BYSPORT_RESCAN_PACATEGORY');

	DROP TEMPORARY TABLE IF EXISTS Temp_NewClassification;    
	CREATE TEMPORARY TABLE Temp_NewClassification(	  	
			CustID						BIGINT UNSIGNED
		, 	CTSCustID					BIGINT 
		,	SubscriberID 				INT UNSIGNED
		,	RoleID						INT	
		,	IsLicenseeVIP				TINYINT(1) DEFAULT 0
		,	SportID						SMALLINT UNSIGNED
		,	Remark						VARCHAR(500)
		,	CreatedBy					INT UNSIGNED
		,	CreatedDate					DATETIME
		,	LastModifiedDate			DATETIME
		, 	TurnoverRM					DECIMAL(20,4)
		, 	WinlossRM					DECIMAL(20,4)
		, 	BetCount					BIGINT
		, 	ActiveDays					INT	
		,	DWCategoryID				INT UNSIGNED
		,	ParentID					INT UNSIGNED
		,	OldCategoryID 				INT UNSIGNED
		,	OldCategoryGroupID			INT UNSIGNED
		,	NewCategoryID				INT UNSIGNED
		, 	NewCategoryGroupID			INT UNSIGNED
		,	CategoryPriority			SMALLINT UNSIGNED
		,	CustomerClassPriority		SMALLINT UNSIGNED
		,	IsDataChanged				TINYINT(1) DEFAULT 1 /*0: No change category => No Action*/
		,	OldTargetCC					INT
		,	TargetCC					INT
		,	TargetCCForHistory			INT
		, 	ActionType					SMALLINT DEFAULT 0 /* 0: Insert; 1: Update, 3: Ignore Exist PA, 4: Ignore PIN; 5: Not satisfy Pass Probation*/
		,	PerformanceTime				DATETIME
		,	SpecialCC					INT
		,	SourceTypeID      			SMALLINT
		,	IsFromOld					TINYINT(1) DEFAULT 0
		,	IsReturnData				TINYINT(1) DEFAULT 1		
		,	IsExistPA					TINYINT(1) DEFAULT 0	
		,	IsFromOldPA					TINYINT(1) DEFAULT 0
		,	DWCategoryGroupID   		INT UNSIGNED
		,	IsPAProbation	     		TINYINT(1) DEFAULT 0

		, 	RelevantCategoryID			INT UNSIGNED
		,	RelevantCategoryGroupID   	INT UNSIGNED
		,	RelevantIsPAProbation	   	TINYINT(1)
		,	MatchID						INT
		,	DataChangeType				TINYINT DEFAULT 0	/* 0: New OR Change Category, 1: Change Probation Status, 2: NOT CHANGE */
		, 	WinlossStatus				SMALLINT /*LOSING  = 0 (PROBATION), KEEPSTATE = 1 (NOT CHANGE), WINNING = 2 (NOT PROBATION);*/
		,	PRIMARY KEY (CustID, SportID, DWCategoryID)
		, 	INDEX IX_Temp_NewCC_BySport_CustID_NewCategoryID (CustID, NewCategoryID)  
		, 	INDEX IX_Temp_NewCC_BySport_CustID_ActionType (CustID, ActionType)  
	); 

	DROP TEMPORARY TABLE IF EXISTS Temp_CTSCustomerClassification_Old;    
	CREATE TEMPORARY TABLE Temp_CTSCustomerClassification_Old(	  
			CustID										BIGINT UNSIGNED
		,	SportID										SMALLINT UNSIGNED
        ,	OldCategoryID 								INT UNSIGNED
        ,	OldCategoryGroupID							INT UNSIGNED
		,	CTSCustID									BIGINT UNSIGNED
		,	RoleID										INT
		,	ParentID									INT UNSIGNED
		,	ExistCategoryID								INT UNSIGNED
		,	RelevantCategoryID							INT UNSIGNED
		,	Remark										VARCHAR(500)
		,	CreatedDate									DATETIME
		,	CreatedBy									INT UNSIGNED
		,	LastModifiedDate							DATETIME
		,	LastModifiedBy								INT UNSIGNED
		,	LastScannedDate								DATETIME
		,	InsertTime									DATETIME
		,	SpecialCC	       							SMALLINT 
		,	CustomerClass								INT 
		,	CategoryPriority							SMALLINT
		,	CustomerClassPriority						SMALLINT
		,	IsPAProbation								TINYINT(1)
		,	IsMultiCateIDSameParentID					TINYINT(1)
		,	IsKeepOldCateID								TINYINT(1)
		,	IsNew										TINYINT(1) DEFAULT 1
		,	IsRemove									TINYINT(1) DEFAULT NULL
        ,	PRIMARY KEY (CustID, SportID)
	); 

	IF ip_InputFlowID = CONST_INPUTFLOWID_BYSPORT_INSERT_SPECIALCC THEN 
		
		INSERT INTO Temp_NewClassification (
				CustID, CTSCustID, SubscriberID, RoleID, Remark, DWCategoryID, NewCategoryID, SportID, CreatedBy
			, 	IsLicenseeVIP, TargetCC, IsDataChanged, IsReturnData)
		SELECT 	tmpJs.CustID, tmpJs.CTSCustID, tmpJs.SubscriberID, cus.RoleID, tmpJs.Remark
			,	CONST_CATEID_SPECIALCC AS DWCategoryID
			,	CONST_CATEID_SPECIALCC AS NewCategoryID
			, 	tmpJs.SportID, tmpJs.CreatedBy, tmpJs.IsLicenseeVIP, tmpJs.TargetCC
			,	(CASE WHEN cls.CustID IS NULL THEN 1 ELSE 0 END) AS IsDataChanged
			,	(CASE WHEN cls.CustID IS NOT NULL THEN 0 ELSE 1 END) AS IsReturnData
		FROM JSON_TABLE(ip_CustInfo,
						 "$[*]" COLUMNS(
												CustID 			BIGINT UNSIGNED		PATH "$.CustID"
											,	CTSCustID 		BIGINT UNSIGNED		PATH "$.CTSCustID"
											,	SubscriberID 	INT UNSIGNED		PATH "$.SubscriberID"
											,	IsLicenseeVIP	TINYINT(1)			PATH "$.IsLicenseeVIP"            
											,	SportID			SMALLINT UNSIGNED	PATH "$.SportID"            
											,	TargetCC		INT					PATH "$.CustomerClass"            
											,	CreatedBy 		INT UNSIGNED		PATH "$.CreatedBy"          
											,	Remark			VARCHAR(500)		PATH "$.Remark"
										 )) AS tmpJs
			INNER JOIN CTS_DataCenter.CTSCustomer AS cus ON cus.CustID = tmpJs.CustID AND cus.CustSubID = 0
			LEFT JOIN CTS_DataCenter.CTSCustomerClassification_BySport AS cls ON cls.CustID = tmpJs.CustID 
																					AND cls.SportID = tmpJs.SportID
																					AND cls.ParentID = CONST_PARENTID_WRAPPER
																					AND cls.CategoryID = CONST_CATEID_SPECIALCC;

	ELSEIF ip_InputFlowID IN (CONST_INPUTFLOWID_BYSPORT_INSERT_PACATEGORY, CONST_INPUTFLOWID_BYSPORT_RESCAN_PACATEGORY) THEN 

			INSERT INTO Temp_NewClassification(
					CustID, CTSCustID, SportID, DWCategoryID, CreatedBy, Remark, MatchID
				, 	WinlossStatus, TurnoverRM, WinlossRM, BetCount, IsPAProbation, RelevantCategoryID, CategoryPriority, CustomerClassPriority
				,	ParentID, IsDataChanged, PerformanceTime, SpecialCC, CreatedDate)
			SELECT 	tmpJs.CustID
				,	CASE WHEN tmpJs.CTSCustID = 0 THEN cus.CTSCustID ELSE tmpJs.CTSCustID END
				,	tmpJs.SportID
				,	tmpJs.DWCategoryID
				,	tmpJs.CreatedBy 
				,	(CASE WHEN tmpJs.MatchID IS NOT NULL THEN CONCAT('Auto MatchID: ', MatchID) ELSE tmpJs.Remark END) AS Remark
				,	tmpJs.MatchID
				, 	IFNULL(tmpJs.WinlossStatus,2) AS  WinlossStatus
				, 	tmpJs.TurnoverRM
				, 	tmpJs.WinlossRM 
				, 	tmpJs.BetCount 
				,	(CASE WHEN tmpJs.WinlossStatus = 0 THEN 1 ELSE 0 END) AS IsPAProbation	/*1: PROBATION, 0: NOT PROBATION*/
				,	cat.RelevantCategoryID
				,	cat.CategoryPriority
				,	cat.CustomerClassPriority
				,	cat.ParentID
				,	0 AS IsDataChanged
				,	tmpJs.PerformanceTime
				,	sp.CustomerClass AS SpecialCC
				,	tmpJs.CreatedDate
			FROM JSON_TABLE(ip_CustInfo,
							"$[*]" COLUMNS(
												CustID 						BIGINT UNSIGNED		PATH "$.CustID"
											,	CTSCustID 					BIGINT UNSIGNED		PATH "$.CTSCustID"
											, 	SportID						SMALLINT UNSIGNED	PATH "$.SportGroup"
											,	DWCategoryID				INT UNSIGNED		PATH "$.CategoryID"
											, 	CreatedBy					INT UNSIGNED		PATH "$.CreatedBy"
											, 	Remark						VARCHAR(500)		PATH "$.Remark"
											,	WinlossStatus				SMALLINT 			PATH "$.WinlossStatus" 
											,	TurnoverRM					DECIMAL(20,4)		PATH "$.TurnoverRM"
											,	WinlossRM					DECIMAL(20,4) 		PATH "$.WinlossRM"
											, 	BetCount					BIGINT 				PATH "$.BetCount"
											, 	PerformanceTime				DATETIME			PATH "$.PerformanceTime"
											,	CreatedDate					DATETIME			PATH "$.CreatedDate"
											,	MatchID						INT					PATH "$.MatchID"
											)) AS tmpJs
				INNER JOIN CTS_DataCenter.CTSCustomer AS cus ON cus.CustID = tmpJs.CustID AND cus.CustSubID = 0
				LEFT JOIN CTS_DataCenter.CustomerCategory AS cat ON cat.CategoryID = tmpJs.DWCategoryID
				LEFT JOIN CTS_DataCenter.SpecialCustomerClass_BySport AS sp ON tmpJs.CustID = sp.CustID AND tmpJs.SportID = sp.SportID
			ON DUPLICATE KEY UPDATE TurnoverRM = IFNULL(Temp_NewClassification.TurnoverRM, tmpJs.TurnoverRM) 
								,	WinlossRM = IFNULL(Temp_NewClassification.WinlossRM, tmpJs.WinlossRM)
								,	BetCount = IFNULL(Temp_NewClassification.BetCount, tmpJs.BetCount);

	ELSEIF ip_InputFlowID = CONST_INPUTFLOWID_BYSPORT_INSERT_NORMAL THEN 
	
		INSERT IGNORE INTO Temp_NewClassification(
				CTSCustID, CustID, SportID, DWCategoryID, TurnoverRM, WinlossRM, BetCount
			, 	ActiveDays, PerformanceTime, SpecialCC)
		SELECT DISTINCT cus.CTSCustID
					,	tmpJs.CustID
					, 	tmpJs.SportID
					, 	tmpJs.DWCategoryID
					, 	tmpJs.TurnoverRM
					, 	tmpJs.WinlossRM
					, 	tmpJs.BetCount
					, 	tmpJs.ActiveDays
					,	tmpJs.PerformanceTime
					,	sp.CustomerClass AS SpecialCC
		FROM JSON_TABLE(ip_CustInfo,
							"$[*]" COLUMNS(
												CustID 					BIGINT UNSIGNED		PATH "$.CustId"
											, 	SportID					SMALLINT UNSIGNED	PATH "$.SportGroup"
											, 	DWCategoryID			INT UNSIGNED		PATH "$.CategoryId"
											, 	TurnoverRM				DECIMAL(20,4)		PATH "$.TurnoverRM"
											, 	WinlossRM				DECIMAL(20,4)		PATH "$.WinlossRM"
											, 	BetCount				BIGINT				PATH "$.BetCount"
											, 	ActiveDays				INT					PATH "$.ActiveDays"		
											,	PerformanceTime			DATETIME			PATH "$.PerformanceTime"
										   )) AS tmpJs
			INNER JOIN CTS_DataCenter.CTSCustomer AS cus ON tmpJs.CustID = cus.CustID AND cus.CustSubID = 0
			LEFT JOIN CTS_DataCenter.SpecialCustomerClass_BySport AS sp ON tmpJs.CustID = sp.CustID AND tmpJs.SportID = sp.SportID
		WHERE tmpJs.DWCategoryID <> 0;
		
		UPDATE Temp_NewClassification AS temp
		SET temp.IsExistPA = 1
		WHERE EXISTS (	SELECT 1
						FROM CTS_DataCenter.CTSCustomerClassification_BySport AS cls
						WHERE temp.CustID = cls.CustID
							AND temp.SportID = cls.SportID
							AND cls.ParentID = CONST_PARENTID_PA
						);

	END IF;



END$$
DELIMITER ;