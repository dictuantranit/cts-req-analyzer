/*<info serverAlias="CTSMain-CTS_DataCenter" databaseType="2" executers="ctsServiceAdmin" isFunction="0" isNested="0"></info>*/
DROP PROCEDURE IF EXISTS `CTS_DataCenter`.`CTS_DC_CustClassificationAgency_DailyScanPA_Insert`;

DELIMITER $$
CREATE DEFINER=`ctsOwner`@`%` PROCEDURE `CTS_DC_CustClassificationAgency_DailyScanPA_Insert`(
		IN ip_ProblemAccount 	JSON
)
    SQL SECURITY INVOKER
BEGIN
	/*
		Created: 20250228@Casey.Huynh
		Task: Agency Daily PA Insert
		DB: CTS_DataCenter
        
		Original:
		Revisions:
			- 20250228@Casey.Huynh: Created [Redmine ID: #218588]

		Param's Explanation (filtered by):      
			CALL CTS_DC_CustClassificationAgency_DailyScanPA_Insert ('[
				{"CustID": 1267,"WinlossStatus": 2,"TurnoverRM":100,"WinlossRM":10,"BetCount":15,"PerformanceTime":"2025-03-03 07:59:23"}]');
	*/ 
	DECLARE CONST_AGENCY_CATEID_VVIP 					INT;
	DECLARE CONST_AGENCY_PARENTID_PA               		INT;
    DECLARE	CONST_AGENCY_ACTIONTYPE_UPDATE 				INT DEFAULT 1;
    DECLARE CONST_AGENCY_REMARKID_PAMARKEDDIRECTLY		INT DEFAULT 31;
    DECLARE CONST_AGENCY_REMARKID_PAAFFECTEDBYUPLINE	INT DEFAULT 32;

	DECLARE lv_CreatedBy 						INT DEFAULT 10278938;
    DECLARE lv_CurrentDateTime 					DATETIME DEFAULT CURRENT_TIMESTAMP(); 

	SET CONST_AGENCY_CATEID_VVIP 					= CTS_DC_CategoryTypeParent_Get ('CONST_AGENCY_CATEID_VVIP');
	SET CONST_AGENCY_PARENTID_PA 					= CTS_DC_CategoryTypeParent_Get ('CONST_AGENCY_PARENTID_PA');
    
    DROP TEMPORARY TABLE IF EXISTS Temp_InputCust;    
	CREATE TEMPORARY TABLE Temp_InputCust(    
			CustID 			BIGINT UNSIGNED PRIMARY KEY
		,	WinlossStatus	SMALLINT
		,	TurnoverRM		DECIMAL(20,4)
		,	WinlossRM		DECIMAL(20,4)	
		,	BetCount		BIGINT
		,   PerformanceTime DATETIME(3)
	);     
    
	DROP TEMPORARY TABLE IF EXISTS Temp_PA;    
	CREATE TEMPORARY TABLE Temp_PA(	  
			CustID					BIGINT UNSIGNED  
		, 	CTSCustID				BIGINT UNSIGNED 
        ,	ParentID				INT UNSIGNED DEFAULT 0 
        , 	CategoryID				INT UNSIGNED
        , 	RelevantCategoryID 	    INT UNSIGNED
        , 	TargetCC 				INT UNSIGNED
        , 	TargetDangerLevel1 		SMALLINT 
        , 	WinlossStatus			SMALLINT /*LOSING  = 0, WINNING = 2;*/
        , 	IsLicensee				BIT(1)
        ,	TurnoverRM				DECIMAL(20,4)
        ,	WinlossRM				DECIMAL(20,4)
        , 	BetCount				BIGINT
        ,	IsMarkedDirectly		BIT(1)
        , 	IsDataChanged			BIT(1)
        ,	PerformanceTime		    DATETIME(3)
        ,	RoleID					TINYINT
        , 	PRIMARY KEY(CustID,CategoryID)  
    );  
    
    /* START */
    INSERT INTO Temp_InputCust(CustID, WinlossStatus, TurnoverRM, WinlossRM, BetCount, PerformanceTime)
    SELECT	js.CustID
		,	js.WinlossStatus
		,	js.TurnoverRM
		,	js.WinlossRM
		,	js.BetCount
		,	js.PerformanceTime
    FROM JSON_TABLE(ip_ProblemAccount,
		"$[*]" COLUMNS(
				CustID 			BIGINT UNSIGNED			PATH "$.CustID"
			,	WinlossStatus	SMALLINT 				PATH "$.WinlossStatus"	
			,	TurnoverRM		DECIMAL(20,4) 			PATH "$.TurnoverRM"	
            ,	WinlossRM		DECIMAL(20,4) 			PATH "$.WinlossRM"	
			,	BetCount		BIGINT 					PATH "$.BetCount"
            ,   PerformanceTime DATETIME(3)            	PATH "$.PerformanceTime"	
		 )) AS js;

    INSERT IGNORE INTO Temp_PA(
			CustID, CTSCustID, CategoryID, RelevantCategoryID, ParentID,TargetCC,TargetDangerLevel1
		, 	WinlossStatus, TurnoverRM, WinlossRM, BetCount, IsMarkedDirectly
        , 	IsDataChanged, PerformanceTime, RoleID)
	SELECT 	tmpCus.CustID
		,	cust.CTSCustID
        ,	clss.CategoryID
        ,	cate.RelevantCategoryID
        ,	clss.ParentID
        ,	desCate.TargetCC
        ,	desCate.TargetDangerLevel1
		, 	tmpCus.WinlossStatus 
        , 	tmpCus.TurnoverRM
        , 	tmpCus.WinlossRM
        , 	tmpCus.BetCount
        ,	clss.IsMarkedDirectly
        ,	CASE WHEN tmpCus.WinlossStatus = 0 AND cate.IsPAProbation = 0 THEN 1  /*Lose + PA => Update */
				 WHEN tmpCus.WinlossStatus = 0 AND cate.IsPAProbation = 1 THEN 0  /*Lose + Probation =>  No Change*/
                 WHEN tmpCus.WinlossStatus = 2 AND cate.IsPAProbation = 0 THEN 0  /*Win + PA => No Change  */
                 WHEN tmpCus.WinlossStatus = 2 AND cate.IsPAProbation = 1 THEN 1  /*Win + Probation => Update */
			END AS IsDataChanged
        ,   tmpCus.PerformanceTime
        ,	cust.RoleID
	FROM Temp_InputCust AS tmpCus
		INNER JOIN CTS_DataCenter.CTSCustomer AS cust ON tmpCus.CustID = cust.CustID AND cust.CustSubID = 0 AND cust.IsInternal = 0
		INNER JOIN CTS_DataCenter.CTSCustomerClassificationAgency AS clss ON clss.CustID = tmpCus.CustID
        INNER JOIN CTS_DataCenter.CustomerCategoryAgency AS cate ON clss.CategoryID = cate.CategoryID AND cate.IsActive = 1 AND cate.RelevantCategoryID IS NOT NULL
        ,	LATERAL (SELECT CASE WHEN cust.IsLicensee = 0 THEN tbl.Ext_ABIDangerLevel_Credit END AS TargetDangerLevel1
						,	tbl.CustomerClass AS TargetCC
					 FROM CTS_DataCenter.CustomerCategoryAgency AS tbl 
					 WHERE cate.RelevantCategoryID = tbl.CategoryID AND tbl.IsActive = 1
					 LIMIT 1) AS desCate; 
	
    DELETE pa
    FROM Temp_PA AS pa
    WHERE EXISTS (	SELECT 1 
					FROM CTS_DataCenter.CTSCustomerClassificationAgency AS clss 
					WHERE clss.CTSCustID = pa.CTSCustID
						AND clss.CategoryID = CONST_AGENCY_CATEID_VVIP); 
        
    UPDATE CTS_DataCenter.CTSCustomerClassificationAgency AS clss
    INNER JOIN Temp_PA AS tmp ON tmp.CustID = clss.CustID AND tmp.ParentID = clss.ParentID AND tmp.CategoryID = clss.CategoryID 
    SET 	clss.CategoryID 	= tmp.RelevantCategoryID
        ,	clss.LastModifiedBy = lv_CreatedBy
        ,	tmp.CategoryID 		= tmp.RelevantCategoryID 
    WHERE tmp.IsDataChanged = 1;

    INSERT IGNORE INTO CTS_DataCenter.CTSCustomerClassificationAgency_History(
			CustID, CTSCustID, CategoryID, ParentID, LastModifiedDate, LastModifiedBy, ActionType, IsAuto, InsertDate
		, 	TargetCC, SourceTypeID, IsDataChanged,TargetDangerLevel1,TurnoverRM, WinlossRM, BetCount, PerformanceTime, RoleID)
	SELECT  tmp.CustID
		, 	tmp.CTSCustID
		, 	tmp.RelevantCategoryID
		, 	tmp.ParentID
		, 	lv_CurrentDateTime AS LastModifiedDate
		, 	lv_CreatedBy AS LastModifiedBy
		, 	CONST_AGENCY_ACTIONTYPE_UPDATE AS ActionType
		, 	1 AS IsAuto
		, 	DATE(lv_CurrentDateTime) AS InsertDate
		, 	tmp.TargetCC
		, 	CASE WHEN tmp.IsMarkedDirectly = 1 THEN CONST_AGENCY_REMARKID_PAMARKEDDIRECTLY
				 ELSE CONST_AGENCY_REMARKID_PAAFFECTEDBYUPLINE END AS SourceTypeID
		,   tmp.IsDataChanged
        ,	tmp.TargetDangerLevel1
        ,	tmp.TurnoverRM
        ,	tmp.WinlossRM
        , 	tmp.BetCount
        ,   tmp.PerformanceTime
        ,	tmp.RoleID
	FROM Temp_PA AS tmp
    WHERE tmp.IsDataChanged = 1;

    INSERT IGNORE INTO CTS_DataCenter.CTSCustomerClassificationAgency_Log(CustID, CTSCustID, CategoryID, ParentID, LastModifiedDate, LastModifiedBy
    , ActionType, IsAuto, InsertDate, TargetCC, SourceTypeID, IsDataChanged,TargetDangerLevel1,TurnoverRM, WinlossRM, BetCount, PerformanceTime, RoleID)
	SELECT  tmp.CustID
		, 	tmp.CTSCustID
		, 	CASE WHEN tmp.IsDataChanged = 1 THEN tmp.RelevantCategoryID ELSE tmp.CategoryID END AS CategoryID
		, 	tmp.ParentID
		, 	lv_CurrentDateTime AS LastModifiedDate
		, 	lv_CreatedBy AS LastModifiedBy
		, 	CONST_AGENCY_ACTIONTYPE_UPDATE AS ActionType
		, 	1 AS IsAuto
		, 	DATE(lv_CurrentDateTime) AS InsertDate
		, 	tmp.TargetCC
		, 	CASE WHEN tmp.IsMarkedDirectly = 1 THEN CONST_AGENCY_REMARKID_PAMARKEDDIRECTLY
				 ELSE CONST_AGENCY_REMARKID_PAAFFECTEDBYUPLINE END AS SourceTypeID
		,   tmp.IsDataChanged
        ,	tmp.TargetDangerLevel1
        ,	tmp.TurnoverRM
        ,	tmp.WinlossRM
        , 	tmp.BetCount
        ,   tmp.PerformanceTime
        ,	tmp.RoleID
	FROM Temp_PA AS tmp;
        
	SELECT 	DISTINCT
			tmp.CustID
		,	tmp.CTSCustID
    FROM Temp_PA AS tmp
		INNER JOIN CTS_DataCenter.CustomerCategoryAgency AS cat ON tmp.CategoryID = cat.CategoryID AND cat.IsActive = 1
    WHERE tmp.IsDataChanged = 1; 
    
END$$
DELIMITER ;