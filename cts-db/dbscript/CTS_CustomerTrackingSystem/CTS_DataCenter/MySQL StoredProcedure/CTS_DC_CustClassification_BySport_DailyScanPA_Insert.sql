/*<info serverAlias="CTSMain-CTS_DataCenter" databaseType="2" executers="ctsServiceAdmin" isFunction="0" isNested="0"></info>*/
DROP PROCEDURE IF EXISTS `CTS_DataCenter`.`CTS_DC_CustClassification_BySport_DailyScanPA_Insert`;

DELIMITER $$
CREATE DEFINER=`ctsOwner`@`%` PROCEDURE `CTS_DC_CustClassification_BySport_DailyScanPA_Insert`(
		IN ip_ProblemAccount 	JSON
)
    SQL SECURITY INVOKER
BEGIN
	/*
		Created: 20251114@Logan.Nguyen
		Task: Add new category/class for daily scan PA By Sport [Redmine ID: #239955]
		DB: CTS_DataCenter
        
		Original:
		Revisions:
			- 20251114@Logan.Nguyen: Add new category/class for daily scan PA By Sport [Redmine ID: #239955]

		Param's Explanation (filtered by):      
			- CALL CTS_DC_CustClassification_BySport_DailyScanPA_Insert ('[{"CustID": 224340007,"SportGroup": 0,"WinlossStatus": 2,"TurnoverRM":100,"WinlossRM":10,"BetCount":15,"ActiveDays":10},{"CustID": 224340007,"SportGroup": 2,"WinlossStatus": 0,"TurnoverRM":150,"WinlossRM":-15000,"BetCount":15,"ActiveDays":10}]');
	*/ 
	DECLARE CONST_CATEID_VVIP 					INT;
	DECLARE CONST_PARENTID_WRAPPER 				INT;
    DECLARE	CONST_ACTIONTYPE_UPDATE 			INT DEFAULT 1;
	DECLARE lv_CreatedBy 						INT DEFAULT 10278938;
    DECLARE lv_CurrentDateTime 					DATETIME DEFAULT CURRENT_TIMESTAMP(); 

	SET CONST_CATEID_VVIP 						= CTS_DC_CategoryTypeParent_Get ('CONST_CATEID_VVIP');
	SET CONST_PARENTID_WRAPPER 					= CTS_DC_CategoryTypeParent_Get ('CONST_PARENTID_WRAPPER');

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
        ,	IsLicenseeVIP			BIT(1)
        ,	IsLicenseeBA			BIT(1)
        , 	IsDataChanged			BIT(1)
        ,	PerformanceTime		    DATETIME(3)
		,	SportGroup				SMALLINT
        , 	PRIMARY KEY(CustID, SportGroup, CategoryID)  
    );  
        
    /* START */
    INSERT IGNORE INTO Temp_PA(
			CustID, CTSCustID, CategoryID, RelevantCategoryID, ParentID,TargetCC,TargetDangerLevel1, IsDangerProbation
		, 	WinlossStatus, TurnoverRM, WinlossRM, BetCount, ActiveDays,IsLicenseeVIP,IsLicenseeBA, IsDataChanged, PerformanceTime, SportGroup)
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
        ,	cust.IsLicenseeVIP
        ,	cust.IsLicenseeBA
        ,	CASE WHEN js.WinlossStatus = 1 THEN 0 /*No Change*/
				 WHEN js.WinlossStatus = 0 AND cate.IsDangerProbation = 0 THEN 1  /*Lose + PA => Update */
				 WHEN js.WinlossStatus = 0 AND cate.IsDangerProbation = 1 THEN 0  /*Lose + Probation =>  No Change*/
                 WHEN js.WinlossStatus = 2 AND cate.IsDangerProbation = 0 THEN 0  /*Win + PA => No Change  */
                 WHEN js.WinlossStatus = 2 AND cate.IsDangerProbation = 1 THEN 1  /*Win + Probation => Update */
			END AS IsDataChanged
        ,   js.PerformanceTime
		,	js.SportGroup
	FROM JSON_TABLE(ip_ProblemAccount,
		"$[*]" COLUMNS(
				CustID 			BIGINT UNSIGNED			PATH "$.CustID"
			,	WinlossStatus	SMALLINT 				PATH "$.WinlossStatus"	
			,	TurnoverRM		DECIMAL(20,4) 			PATH "$.TurnoverRM"	
            ,	WinlossRM		DECIMAL(20,4) 			PATH "$.WinlossRM"	
			,	BetCount		BIGINT 					PATH "$.BetCount"	
            ,	ActiveDays		INT 					PATH "$.ActiveDays"
            ,   PerformanceTime DATETIME(3)            	PATH "$.PerformanceTime"	
			,   SportGroup		SMALLINT 				PATH "$.SportGroup"
		 )) AS js
		INNER JOIN CTS_DataCenter.CTSCustomer AS cust ON js.CustID = cust.CustID AND cust.CustSubID = 0 AND cust.IsInternal = 0
		INNER JOIN CTS_DataCenter.CTSCustomerClassification_BySport AS clss ON clss.CustID = js.CustID AND clss.SportID = js.SportGroup
        INNER JOIN CTS_DataCenter.CustomerCategory AS cate ON clss.CategoryID = cate.CategoryID AND cate.IsActive = 1 AND cate.RelevantCategoryID IS NOT NULL
	,	LATERAL (SELECT CASE WHEN cust.IsLicensee = 1 THEN tbl.Ext_ABIDangerLevel_Licensee  ELSE tbl.Ext_ABIDangerLevel_Credit END AS TargetDangerLevel1
				,	tbl.CustomerClass AS TargetCC
				FROM CTS_DataCenter.CustomerCategory AS tbl 
				WHERE cate.RelevantCategoryID = tbl.CategoryID AND tbl.IsActive = 1
				LIMIT 1) AS desCate; 
    
    DELETE pa
    FROM Temp_PA AS pa
    WHERE EXISTS (	SELECT 1 
					FROM CTS_DataCenter.CTSCustomerClassification_BySport AS clss 
					WHERE clss.CTSCustID = pa.CTSCustID
						AND clss.CategoryID = CONST_CATEID_VVIP); 
        
    UPDATE CTS_DataCenter.CTSCustomerClassification_BySport AS clss
		INNER JOIN Temp_PA AS tmp ON tmp.CustID = clss.CustID AND tmp.ParentID = clss.ParentID AND tmp.CategoryID = clss.CategoryID AND tmp.SportGroup = clss.SportID
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
                                ELSE t.TargetCC
							END;

    INSERT IGNORE INTO CTS_DataCenter.CTSCustomerClassification_BySport_History(
			CustID, CTSCustID, SportID, CategoryID, ParentID, LastModifiedDate, LastModifiedBy, ActionType, InsertDate
		, 	TargetCC, SourceTypeID, TurnoverRM, WinlossRM, BetCount, ActiveDays, PerformanceTime)
	SELECT  tmp.CustID
		, 	tmp.CTSCustID
		,	tmp.SportGroup AS SportID
		, 	tmp.RelevantCategoryID
		, 	tmp.ParentID
		, 	lv_CurrentDateTime AS LastModifiedDate
		, 	lv_CreatedBy AS LastModifiedBy
		, 	CONST_ACTIONTYPE_UPDATE AS ActionType
		, 	DATE(lv_CurrentDateTime) AS InsertDate
		, 	TargetCC
		, 	ccs.RemarkTemplateID
        ,	tmp.TurnoverRM
        ,	tmp.WinlossRM
        , 	tmp.BetCount
        , 	tmp.ActiveDays
        ,   tmp.PerformanceTime
	FROM Temp_PA AS tmp
		LEFT JOIN CTS_DataCenter.CustomerCategorySettings AS ccs ON ccs.CategoryID = tmp.RelevantCategoryID
    WHERE tmp.IsDataChanged = 1
		AND tmp.ParentID <> CONST_PARENTID_WRAPPER;

    INSERT IGNORE INTO CTS_DataCenter.CTSCustomerClassification_BySport_Log(CustID, CTSCustID, SportID, CategoryID, ParentID, LastModifiedDate, LastModifiedBy, ActionType, InsertDate, TargetCC, SourceTypeID, TurnoverRM, WinlossRM, BetCount, ActiveDays, PerformanceTime)
	SELECT  tmp.CustID
		, 	tmp.CTSCustID
		,	tmp.SportGroup AS SportID
		, 	CASE WHEN tmp.IsDataChanged = 1 THEN tmp.RelevantCategoryID ELSE tmp.CategoryID END AS CategoryID
		, 	tmp.ParentID
		, 	lv_CurrentDateTime AS LastModifiedDate
		, 	lv_CreatedBy AS LastModifiedBy
		, 	CONST_ACTIONTYPE_UPDATE AS ActionType
		, 	DATE(lv_CurrentDateTime) AS InsertDate
		, 	TargetCC
		, 	ccs.RemarkTemplateID
        ,	tmp.TurnoverRM
        ,	tmp.WinlossRM
        , 	tmp.BetCount
        , 	tmp.ActiveDays
        ,   tmp.PerformanceTime
	FROM Temp_PA AS tmp
		LEFT JOIN CTS_DataCenter.CustomerCategorySettings AS ccs ON ccs.CategoryID = tmp.RelevantCategoryID;

	SELECT DISTINCT
       tmp.CustID,
       tmp.SportGroup AS SportGroup
	FROM Temp_PA AS tmp
	WHERE tmp.IsDataChanged = 1;
	
END$$
DELIMITER ;