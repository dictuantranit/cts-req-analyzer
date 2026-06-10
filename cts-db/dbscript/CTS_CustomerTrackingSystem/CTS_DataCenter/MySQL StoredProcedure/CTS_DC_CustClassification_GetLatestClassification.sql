/*<info serverAlias="CTSMain-CTS_DataCenter" databaseType="2" executers="ctsWeb,ctsAPI,ctsService" isFunction="0" isNested="0"></info>*/
DROP PROCEDURE IF EXISTS `CTS_DataCenter`.`CTS_DC_CustClassification_GetLatestClassification`;

DELIMITER $$
CREATE DEFINER=`ctsOwner`@`%` PROCEDURE `CTS_DC_CustClassification_GetLatestClassification`(
	IN ip_CustIDs TEXT
)
    SQL SECURITY INVOKER
BEGIN
	/*
		Created:	20201214@Irena.Vo	
		Task :		Get Customers' latest Customer Class 
		DB:			CTS_DataCenter
		Original: 
		Revisions:
			- 20201214@Irena.Vo: Created [RedmineID: #145951]
            - 20210413@Irena.Vo: Get Reason. Ignore sub account for case CC = -1 [RedmineID: #141931]
			- 20210419@Irena.Vo: Get Category more [RedmineID: #153617]
			- 20210625@Long.Luu: Refactor  [Redmine ID: #157203]
			- 20210811@Irena.Vo: Fix issue get PA Category incorrectly [Redmine ID: 160071]
            - 20210910@Irena.Vo: Additional IGNORE for insert table Temp_CustomerClass [Redmine ID: 161232]
			- 20211115@Irena.Vo: Re-priortize Robot and other PA categories  [Redmine ID: #164344]
			- 20220214@Long.Luu: Support new category for Good & Bad Robot User [Redmine ID: #167726]
            - 20220428@Casey.Huynh: Rename Category Add CC Label  [Redmine ID: #172032]
        Param's Explanation:     
        Example:
			- CALL CTS_DataCenter.CTS_DC_CustClassification_GetLatestClassification('1,2,1277,555555');
	*/ 
	DECLARE	CONST_GROUP_NORMAL 					INT DEFAULT 200;
    DECLARE	CONST_GROUP_PROBLEM 				INT DEFAULT 0;
    DECLARE	CONST_GROUP_ROBOTUSER 				INT DEFAULT 61;
    DECLARE	CONST_CATEGORY_BADROBOTUSER 		INT DEFAULT 163;
    DECLARE	CONST_CATEGORY_GOODROBOTUSER 		INT DEFAULT 164;
    
    DECLARE lv_CurrentDateTime		DATETIME DEFAULT CURRENT_TIMESTAMP();
    
	DROP TEMPORARY TABLE IF EXISTS Temp_InputCustomers;
    CREATE TEMPORARY TABLE 		Temp_InputCustomers (
			CustID              BIGINT UNSIGNED PRIMARY KEY 
    );  
    
    DROP TEMPORARY TABLE IF EXISTS Temp_ExistedSpecialCC;
    CREATE TEMPORARY TABLE 		Temp_ExistedSpecialCC (
			CustID              BIGINT UNSIGNED PRIMARY KEY 
		,	ScannedTime			DATETIME
        ,   CustomerClass       SMALLINT
    );  
    
    DROP TEMPORARY TABLE IF EXISTS Temp_ProblemAccounts;
    CREATE TEMPORARY TABLE 		Temp_ProblemAccounts (
        	CustID			    BIGINT UNSIGNED
        ,	CategoryGroup		SMALLINT
        ,	PRIMARY KEY 		PK(CustID,CategoryGroup)
    ); 
    
    DROP TEMPORARY TABLE IF EXISTS Temp_CategoryList;
    CREATE TEMPORARY TABLE 		Temp_CategoryList (
        	CustID			    BIGINT UNSIGNED
		,	ScannedTime			DATETIME
        ,	SportGroupID		SMALLINT
        ,	CategoryID			SMALLINT
        ,	CategoryGroup		SMALLINT
		,	PRIMARY KEY 		PK(CustID,CategoryID)
    ); 
    
    DROP TEMPORARY TABLE IF EXISTS Temp_ExistedLatestCategory;
    CREATE TEMPORARY TABLE 		Temp_ExistedLatestCategory (
        	CustID			    BIGINT UNSIGNED PRIMARY KEY 
		,	ScannedTime			DATETIME
		,	SportGroupID		SMALLINT
		,	CategoryID			SMALLINT
    );    
    
	DROP TEMPORARY TABLE IF EXISTS Temp_LatestClassification;
    CREATE TEMPORARY TABLE 		Temp_LatestClassification (
        	CustID				BIGINT UNSIGNED PRIMARY KEY             
		,	ScannedTime			DATETIME
		,   CustomerClass       SMALLINT DEFAULT -1 /* -1: No data, <> -1: Has data */
        ,	CustomerClassName	VARCHAR(50)
		,	CategoryGroup		SMALLINT DEFAULT -1 /* -1: No data, <> -1: Has data */
		,	CategoryID			SMALLINT DEFAULT -1 /* -1: No data, <> -1: Has data */
    );    
    
    /* 1. Insert CustIDs */
	SET @sql = 	CONCAT("INSERT IGNORE INTO Temp_InputCustomers (CustID) VALUES ('", REPLACE(ip_CustIDs, ",", "'),('"),"');");
	PREPARE stmt1 FROM @sql;
	EXECUTE stmt1;    
    
	/* 2. Insert Existed Special CC */
	INSERT IGNORE INTO Temp_ExistedSpecialCC (CustID, ScannedTime, CustomerClass)
    SELECT c.CustID, sp.LastModifiedDate, sp.CustomerClass
    FROM Temp_InputCustomers AS c
		INNER JOIN CTS_DataCenter.SpecialCustomerClass AS sp ON sp.CustID = c.CustID;
    
    /* 3 Get Problem Account */
	INSERT IGNORE INTO Temp_ProblemAccounts(CustID, CategoryGroup)
    SELECT cate.CustID, cc.CategoryGroup
    FROM CTS_DataCenter.CTSCustomerClassification AS cate
		INNER JOIN Temp_InputCustomers AS c ON c.CustID = cate.CustID AND cate.SportGroupID = CONST_GROUP_PROBLEM
        INNER JOIN  CTS_DataCenter.CustomerCategory AS cc ON cc.CategoryID = cate.CategoryID;
	
    /* 4. Insert Category List */
    INSERT IGNORE INTO Temp_CategoryList (CustID, ScannedTime, SportGroupID, CategoryID, CategoryGroup)
    SELECT cate.CustID, cate.LastModifiedDate, cate.SportGroupID, cate.CategoryID, cc.CategoryGroup
    FROM CTS_DataCenter.CTSCustomerClassification AS cate
		INNER JOIN Temp_InputCustomers AS c ON c.CustID = cate.CustID
        INNER JOIN  CTS_DataCenter.CustomerCategory AS cc ON cc.CategoryID = cate.CategoryID;
    
    /* 5. Validate Data */
    /* 5.1 Validate Normal Category */
    DELETE c 
    FROM Temp_CategoryList AS c 
		INNER JOIN Temp_ProblemAccounts AS p ON p.CustID = c.CustID AND c.SportGroupID = CONST_GROUP_NORMAL;
    
    /* 5.2 Validate Robot User */
	DELETE p
    FROM Temp_ProblemAccounts AS p
    WHERE p.CategoryGroup = CONST_GROUP_ROBOTUSER; /** Clean Robot User. Only get PA */
    
    DELETE c 
    FROM Temp_CategoryList AS c 
		INNER JOIN Temp_ProblemAccounts AS p ON p.CustID = c.CustID AND c.CategoryGroup = CONST_GROUP_ROBOTUSER;

    /* 6. Insert Existed Lastest Category */
	INSERT IGNORE INTO Temp_ExistedLatestCategory(CustID, ScannedTime)
    SELECT c.CustID, MAX(c.ScannedTime) AS ScannedTime
    FROM Temp_CategoryList AS c
    GROUP BY c.CustID;
    
    UPDATE Temp_ExistedLatestCategory AS ec,
		LATERAL (SELECT CustID, ScannedTime, SportGroupID, MAX(CategoryID) AS CategoryID 
				FROM Temp_CategoryList 
                GROUP BY CustID, ScannedTime, SportGroupID) AS c
	SET 	ec.SportGroupID = c.SportGroupID
		, 	ec.CategoryID = c.CategoryID
	WHERE ec.CustID = c.CustID AND ec.ScannedTime = c.ScannedTime;
    
    /* 7. Update ScannedTime to back Special CC */
    UPDATE Temp_ExistedSpecialCC AS es
		INNER JOIN Temp_ExistedLatestCategory AS ec ON ec.CustID = es.CustID
    SET es.ScannedTime = GREATEST(es.ScannedTime, ec.ScannedTime);
    
    DELETE ec
    FROM Temp_ExistedLatestCategory AS ec  
		INNER JOIN Temp_ExistedSpecialCC AS es ON es.CustID = ec.CustID;
    
    /* 8. Mapping case: Not existed category */
	INSERT IGNORE INTO Temp_LatestClassification (CustID, ScannedTime)
    SELECT temp.CustID, lv_CurrentDateTime AS ScannedTime
    FROM Temp_InputCustomers AS temp
		INNER JOIN CTS_DataCenter.CTSCustomer AS cust ON cust.CustID = temp.CustID AND cust.CustSubID = 0
	WHERE NOT EXISTS (SELECT 1 FROM Temp_ExistedSpecialCC AS es WHERE es.CustID = temp.CustID) /* Not existed Special CC */
		 AND NOT EXISTS (SELECT 1 FROM Temp_ExistedLatestCategory AS ec WHERE ec.CustID = temp.CustID); /* Not existed Category */
    
    /* 9. Mapping case: Existed Special CC */
    INSERT IGNORE INTO Temp_LatestClassification (CustID, ScannedTime, CustomerClass)
    SELECT es.CustID, es.ScannedTime,  es.CustomerClass 
    FROM Temp_ExistedSpecialCC AS es;
    
    /* 10. Mapping case: Existed Category */
	INSERT IGNORE INTO Temp_LatestClassification (CustID, ScannedTime, CustomerClass, CustomerClassName, CategoryGroup, CategoryID)
	SELECT 	ec.CustID, ec.ScannedTime,  cc.CustomerClass, cc.CustomerClassName
		,	CASE WHEN ec.SportGroupID = CONST_GROUP_NORMAL THEN -1 ELSE cc.CategoryGroup END AS CategoryGroup
        ,	CASE WHEN ec.SportGroupID = CONST_GROUP_NORMAL THEN -1 ELSE ec.CategoryID END AS CategoryID
	FROM Temp_ExistedLatestCategory AS ec
        INNER JOIN CTS_DataCenter.CustomerCategory AS cc ON cc.CategoryID = ec.CategoryID;

    /* 12. Get Latest Classification to push */
     SELECT DISTINCT c.CustID
		, 	c.CustomerClass
        ,	c.CustomerClassName
        , 	CASE WHEN c.CategoryID IN (CONST_CATEGORY_BADROBOTUSER, CONST_CATEGORY_GOODROBOTUSER) THEN c.CategoryID ELSE c.CategoryGroup END AS Category # PACategory
        , 	c.ScannedTime 
    FROM Temp_LatestClassification AS c;

END$$
DELIMITER ;