/*<info serverAlias="CTSMain-CTS_DataCenter" databaseType="2" executers="ctsServiceAdmin" isFunction="0" isNested="0"></info>*/
DROP PROCEDURE IF EXISTS `CTS_DataCenter`.`CTS_DC_CustClassification_ProblemAccountProbation_Insert`;

DELIMITER $$
CREATE DEFINER=`ctsOwner`@`%` PROCEDURE `CTS_DC_CustClassification_ProblemAccountProbation_Insert`(
		IN ip_ProblemAccount 	JSON
)
    SQL SECURITY INVOKER
BEGIN
	/*
		Created: 20220328@Aries.Nguyen
		Task: Add new category/class for PA Probation [Redmine ID: #170468]
		DB: CTS_DataCenter
        
		Original:
		Revisions:
			- 20220328@Aries.Nguyen: Created [Redmine ID: #170468]
			- 20220426@Aries.Nguyen: CTS - Daily PA Scan - Check Losing lead to show Created Date is wrong in PAM [Redmine ID: #171972]
			- 20220607@Aries.Nguyen: Renovate PA process [Redmine ID: #172561]
			- 20220628@Aries.Nguyen: Update robot classification rule [Redmine ID: #174430]
			- 20220628@Aries.Nguyen: Update robot classification rule [Redmine ID: #174430]
			- 202208018@Long.Luu: Exclude wrapper categories from rescan PA flow [Redmine ID: #174219]          
			- 20220817@Long.Luu: Rearrange CC's IDs [Redmine ID: #175698]
			- 20230517@Casey.Huynh:	New Category for Robot OCRD [Redmine ID: #186991]
			- 20240103@Thomas.Nguyen: New Category for System Detect Unauthorized Login [RedmineID: #197710]
			- 20240318@Casey.Huynh: Classify Danger Score [Redmine ID: #201358]
			- 20240415@Casey.Huynh: Fix Missing DangerScrore info in remark [Redmine ID: #203889]
			- 20240423@Thomas.Nguyen: Classify Initial Group Betting - Add Remark [RedmineID: #200854]
			- 20240703@Victoria.Le:   Renovate CC phase 2 - Remove Table PinCustomerCategory  [Redmine ID: #205317]
			- 20241205@Victoria.Le:   Incorect Datatype for ActiveDays [Redmine ID: #214567]
			- 20250909@Thomas.Nguyen: CC 2900/2901 - Update logic to map DW Performance by DWSportType [Redmine ID: #237405]

		Param's Explanation (filtered by):      
			- CALL CTS_DC_CustClassification_ProblemAccountProbation_Insert ('[{"CustID": 224340007,"DWSportType": 0,"WinlossStatus": 2,"TurnoverRM":100,"WinlossRM":10,"BetCount":15,"ActiveDays":10},{"CustID": 224340007,"DWSportType": 2,"WinlossStatus": 0,"TurnoverRM":150,"WinlossRM":-15000,"BetCount":15,"ActiveDays":10}]');
	*/ 
	DECLARE CONST_CATEID_VVIP 					INT;
	DECLARE CONST_CATEID_LICVIPSUSPICIOUS 		INT;
	DECLARE CONST_CATEID_LICVIPDANGEROUS 		INT;
	DECLARE CONST_CATEID_LICBA 					INT;
	DECLARE CONST_PARENTID_PA               	INT;
	DECLARE CONST_PARENTID_WRAPPER 				INT;
    DECLARE	CONST_ACTIONTYPE_UPDATE 			INT DEFAULT 1;
    DECLARE CONST_REMARKID_PAMARKEDDIRECTLY		INT;
    DECLARE CONST_REMARKID_PAAFFECTEDBYUPLINE	INT;
	DECLARE CONST_REMARKID_RESCANROBOT			INT;
	DECLARE lv_CreatedBy 						INT DEFAULT 10278938;
    DECLARE lv_CurrentDateTime 					DATETIME DEFAULT CURRENT_TIMESTAMP(); 
    DECLARE lv_LicBACC							INT UNSIGNED;
    DECLARE lv_LicVIPCC_Danger					INT UNSIGNED;
    DECLARE lv_LicVIPCC_Suspicious				INT UNSIGNED;
    DECLARE lv_LicBAPriority					SMALLINT UNSIGNED;

	SET CONST_CATEID_VVIP 						= CTS_DC_CategoryTypeParent_Get ('CONST_CATEID_VVIP');
	SET CONST_CATEID_LICVIPSUSPICIOUS 			= CTS_DC_CategoryTypeParent_Get ('CONST_CATEID_LICVIPSUSPICIOUS');
	SET CONST_CATEID_LICVIPDANGEROUS			= CTS_DC_CategoryTypeParent_Get ('CONST_CATEID_LICVIPDANGEROUS');
	SET CONST_CATEID_LICBA 						= CTS_DC_CategoryTypeParent_Get ('CONST_CATEID_LICBA');
	SET CONST_PARENTID_PA 				    	= CTS_DC_CategoryTypeParent_Get ('CONST_PARENTID_PA');
	SET CONST_PARENTID_WRAPPER 					= CTS_DC_CategoryTypeParent_Get ('CONST_PARENTID_WRAPPER');
	SET CONST_REMARKID_PAMARKEDDIRECTLY 		= CTS_DC_CategoryTypeParent_Get ('CONST_REMARKID_PAMARKEDDIRECTLY');
	SET CONST_REMARKID_PAAFFECTEDBYUPLINE 		= CTS_DC_CategoryTypeParent_Get ('CONST_REMARKID_PAAFFECTEDBYUPLINE');
	SET CONST_REMARKID_RESCANROBOT 				= CTS_DC_CategoryTypeParent_Get ('CONST_REMARKID_RESCANROBOT');

	DROP TEMPORARY TABLE IF EXISTS Temp_PA;    
	CREATE TEMPORARY TABLE Temp_PA(	  
			CustID					BIGINT UNSIGNED  
		, 	CTSCustID				BIGINT UNSIGNED 
        ,	ParentID				INT UNSIGNED DEFAULT 0 
        , 	CategoryID				INT UNSIGNED
        , 	RelevantCategoryID 	    INT UNSIGNED
        , 	TargetCC 				INT UNSIGNED
        , 	TargetDangerLevel1 		SMALLINT 
        ,	IsDangerProbation 		BIT(1)
        , 	WinlossStatus			SMALLINT /*LOSING  = 0,KEEPSTATE = 1, WINNING = 2;*/
        , 	IsLicensee				BIT(1)
        ,	TurnoverRM				DECIMAL(20,4)
        ,	WinlossRM				DECIMAL(20,4)
        , 	BetCount				BIGINT 
        , 	ActiveDays				INT
        ,	IsMarkedDirectly		BIT(1)
        ,	IsLicenseeVIP			BIT(1)
        ,	IsLicenseeBA			BIT(1)
        , 	IsDataChanged			BIT(1)
        ,	PerformanceTime		    DATETIME(3)
		,	IsRobot					BIT(1)
		,	DWSportType				SMALLINT
        , 	PRIMARY KEY(CustID,CategoryID)  
    );  
    
    /* INIT */    
    SELECT CustomerClass, CustomerClassPriority 
    INTO lv_LicBACC, lv_LicBAPriority
    FROM CustomerCategory WHERE CategoryID = CONST_CATEID_LICBA;
    
    SELECT CustomerClass
    INTO lv_LicVIPCC_Danger
    FROM CustomerCategory WHERE CategoryID = CONST_CATEID_LICVIPDANGEROUS;
    
    SELECT CustomerClass
    INTO lv_LicVIPCC_Suspicious
    FROM CustomerCategory WHERE CategoryID = CONST_CATEID_LICVIPSUSPICIOUS;    
    
    /* START */
    INSERT IGNORE INTO Temp_PA(
			CustID, CTSCustID, CategoryID, RelevantCategoryID, ParentID,TargetCC,TargetDangerLevel1, IsDangerProbation
		, 	WinlossStatus, TurnoverRM, WinlossRM, BetCount, ActiveDays,IsMarkedDirectly,IsLicenseeVIP,IsLicenseeBA, IsDataChanged, PerformanceTime, IsRobot, DWSportType)
	SELECT 	js.CustID
		,	cust.CTSCustID
        ,	clss.CategoryID
        ,	cate.RelevantCategoryID
        ,	clss.ParentID
        ,	desCate.TargetCC
        ,	desCate.TargetDangerLevel1
        ,	cate.IsDangerProbation
		, 	js.WinlossStatus 
        , 	js.TurnoverRM
        , 	js.WinlossRM
        , 	js.BetCount
        , 	js.ActiveDays
        ,	clss.IsMarkedDirectly
        ,	cust.IsLicenseeVIP
        ,	cust.IsLicenseeBA
        ,	CASE WHEN js.WinlossStatus = 1 THEN 0 /*No Change*/
				 WHEN js.WinlossStatus = 0 AND cate.IsDangerProbation = 0 THEN 1  /*Lose + PA => Update */
				 WHEN js.WinlossStatus = 0 AND cate.IsDangerProbation = 1 THEN 0  /*Lose + Probation =>  No Change*/
                 WHEN js.WinlossStatus = 2 AND cate.IsDangerProbation = 0 THEN 0  /*Win + PA => No Change  */
                 WHEN js.WinlossStatus = 2 AND cate.IsDangerProbation = 1 THEN 1  /*Win + Probation => Update */
			END AS IsDataChanged
        ,   js.PerformanceTime
		,	CASE WHEN cate.CustomerClassName = 'Robot' THEN 1 ELSE 0 END AS IsRobot
		,	js.DWSportType
	FROM JSON_TABLE(ip_ProblemAccount,
		"$[*]" COLUMNS(
				CustID 			BIGINT UNSIGNED			PATH "$.CustID"
			,	WinlossStatus	SMALLINT 				PATH "$.WinlossStatus"	
			,	TurnoverRM		DECIMAL(20,4) 			PATH "$.TurnoverRM"	
            ,	WinlossRM		DECIMAL(20,4) 			PATH "$.WinlossRM"	
			,	BetCount		BIGINT 					PATH "$.BetCount"	
            ,	ActiveDays		INT 					PATH "$.ActiveDays"
            ,   PerformanceTime DATETIME(3)            	PATH "$.PerformanceTime"	
			,   DWSportType		SMALLINT 				PATH "$.DWSportType"
		 )) AS js
		INNER JOIN CTS_DataCenter.CTSCustomer AS cust ON js.CustID = cust.CustID AND cust.CustSubID = 0 AND cust.IsInternal = 0
		INNER JOIN CTS_DataCenter.CTSCustomerClassification AS clss ON clss.CustID = js.CustID
        INNER JOIN CTS_DataCenter.CustomerCategory AS cate ON clss.CategoryID = cate.CategoryID AND cate.IsActive = 1 AND cate.RelevantCategoryID IS NOT NULL
		INNER JOIN CTS_DataCenter.CustomerCategorySettings AS ccs ON ccs.CategoryID = cate.CategoryID AND ccs.SportType = js.DWSportType
	,	LATERAL (SELECT CASE WHEN cust.IsLicensee = 1 THEN tbl.Ext_ABIDangerLevel_Licensee  ELSE tbl.Ext_ABIDangerLevel_Credit END AS TargetDangerLevel1
				,	tbl.CustomerClass AS TargetCC
				FROM CTS_DataCenter.CustomerCategory AS tbl 
				WHERE cate.RelevantCategoryID = tbl.CategoryID AND tbl.IsActive = 1
				LIMIT 1) AS desCate; 
    
    DELETE pa
    FROM Temp_PA AS pa
    WHERE EXISTS (	SELECT 1 
					FROM CTS_DataCenter.CTSCustomerClassification AS clss 
					WHERE clss.CTSCustID = pa.CTSCustID
						AND clss.CategoryID = CONST_CATEID_VVIP); 
        
    UPDATE CTS_DataCenter.CTSCustomerClassification AS clss
		INNER JOIN Temp_PA AS tmp ON tmp.CustID = clss.CustID AND tmp.ParentID = clss.ParentID AND tmp.CategoryID = clss.CategoryID
		INNER JOIN CTS_DataCenter.CustomerCategorySettings AS ccs ON ccs.CategoryID = tmp.CategoryID AND ccs.SportType = tmp.DWSportType
    SET 	clss.CategoryID = tmp.RelevantCategoryID
        ,	clss.LastModifiedBy = lv_CreatedBy
        ,	tmp.CategoryID = tmp.RelevantCategoryID 
    WHERE tmp.IsDataChanged = 1;

    UPDATE Temp_PA AS t 
		INNER JOIN CTS_DataCenter.CustomerCategory AS c ON t.CategoryID = c.CategoryID 
																AND c.IsActive = 1
																AND c.RelevantCategoryID IS NOT NULL
        LEFT JOIN CTS_DataCenter.SpecialCustomerClass AS s ON t.CustID = s.CustID       
    SET 	t.TargetCC = 	CASE
								WHEN s.CustomerClass IS NOT NULL THEN s.CustomerClass
                                WHEN t.IsLicenseeVIP = 1 AND c.IsDangerProbation = 1 THEN lv_LicVIPCC_Suspicious
                                WHEN t.IsLicenseeVIP = 1 AND c.IsDangerProbation = 0 THEN lv_LicVIPCC_Danger
                                WHEN t.IsLicenseeBA = 1 AND c.CustomerClassPriority > lv_LicBAPriority THEN lv_LicBACC
                                ELSE t.TargetCC
							END;

    INSERT IGNORE INTO CTS_DataCenter.CTSCustomerClassification_History(
			CustID, CTSCustID, CategoryID, ParentID, LastModifiedDate, LastModifiedBy, ActionType, IsAuto, InsertDate
		, 	TargetCC, SourceTypeID, IsDataChanged,TargetDangerLevel1,TurnoverRM, WinlossRM, BetCount, ActiveDays, PerformanceTime)
	SELECT  tmp.CustID
		, 	tmp.CTSCustID
		, 	tmp.RelevantCategoryID
		, 	tmp.ParentID
		, 	lv_CurrentDateTime AS LastModifiedDate
		, 	lv_CreatedBy AS LastModifiedBy
		, 	CONST_ACTIONTYPE_UPDATE AS ActionType
		, 	1 AS IsAuto
		, 	DATE(lv_CurrentDateTime) AS InsertDate
		, 	TargetCC
		, 	CASE WHEN ccs.RemarkTemplateID IS NOT NULL THEN ccs.RemarkTemplateID
				 WHEN tmp.IsRobot = 1 THEN CONST_REMARKID_RESCANROBOT 
				 WHEN tmp.IsMarkedDirectly = 1 THEN CONST_REMARKID_PAMARKEDDIRECTLY
				 ELSE CONST_REMARKID_PAAFFECTEDBYUPLINE END AS SourceTypeID
		,   tmp.IsDataChanged
        ,	tmp.TargetDangerLevel1
        ,	tmp.TurnoverRM
        ,	tmp.WinlossRM
        , 	tmp.BetCount
        , 	tmp.ActiveDays
        ,   tmp.PerformanceTime
	FROM Temp_PA AS tmp
		LEFT JOIN CTS_DataCenter.CustomerCategorySettings AS ccs ON ccs.CategoryID = tmp.RelevantCategoryID
    WHERE tmp.IsDataChanged = 1
		AND tmp.ParentID <> CONST_PARENTID_WRAPPER;

    INSERT IGNORE INTO CTS_DataCenter.CTSCustomerClassification_Log(CustID, CTSCustID, CategoryID, ParentID, LastModifiedDate, LastModifiedBy, ActionType, IsAuto, InsertDate, TargetCC, SourceTypeID, IsDataChanged,TargetDangerLevel1,TurnoverRM, WinlossRM, BetCount, ActiveDays, PerformanceTime)
	SELECT  tmp.CustID
		, 	tmp.CTSCustID
		, 	CASE WHEN tmp.IsDataChanged = 1 THEN tmp.RelevantCategoryID ELSE tmp.CategoryID END AS CategoryID
		, 	tmp.ParentID
		, 	lv_CurrentDateTime AS LastModifiedDate
		, 	lv_CreatedBy AS LastModifiedBy
		, 	CONST_ACTIONTYPE_UPDATE AS ActionType
		, 	1 AS IsAuto
		, 	DATE(lv_CurrentDateTime) AS InsertDate
		, 	TargetCC
		, 	CASE WHEN ccs.RemarkTemplateID IS NOT NULL THEN ccs.RemarkTemplateID
				 WHEN tmp.IsRobot = 1 THEN CONST_REMARKID_RESCANROBOT 
				 WHEN tmp.IsMarkedDirectly = 1 THEN CONST_REMARKID_PAMARKEDDIRECTLY
				 ELSE CONST_REMARKID_PAAFFECTEDBYUPLINE END AS SourceTypeID
		,   tmp.IsDataChanged
        ,	tmp.TargetDangerLevel1
        ,	tmp.TurnoverRM
        ,	tmp.WinlossRM
        , 	tmp.BetCount
        , 	tmp.ActiveDays
        ,   tmp.PerformanceTime
	FROM Temp_PA AS tmp
		LEFT JOIN CTS_DataCenter.CustomerCategorySettings AS ccs ON ccs.CategoryID = tmp.RelevantCategoryID;
    
	SELECT 	DISTINCT
			tmp.CustID
		,	tmp.CTSCustID
        ,	CASE WHEN cat.CustomerClassName = 'Robot' THEN 1 ELSE 0 END AS IsRobot
		,	CASE WHEN cat.ParentID = CONST_PARENTID_PA THEN 1 ELSE 0 END AS IsPA
    FROM Temp_PA AS tmp
		INNER JOIN CTS_DataCenter.CustomerCategory AS cat ON tmp.CategoryID = cat.CategoryID AND cat.IsActive = 1
    WHERE IsDataChanged = 1; 
    
END$$
DELIMITER ;