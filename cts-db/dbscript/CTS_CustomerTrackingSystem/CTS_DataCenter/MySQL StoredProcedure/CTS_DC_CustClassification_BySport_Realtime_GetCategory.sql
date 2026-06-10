/*<info serverAlias="CTSMain-CTS_DataCenter" databaseType="2" executers="ctsService" isFunction="0" isNested="0"></info>*/
DROP PROCEDURE IF EXISTS `CTS_DataCenter`.`CTS_DC_CustClassification_BySport_Realtime_GetCategory`;

DELIMITER $$
CREATE DEFINER=`ctsOwner`@`%` PROCEDURE `CTS_DataCenter`.`CTS_DC_CustClassification_BySport_Realtime_GetCategory`(
	  IN ip_CustInfoList      	TEXT
)
    SQL SECURITY INVOKER
BEGIN
	/*
		Created: 20251114@Logan.Nguyen
		Task:  Return the auto tag customer list for daily scan PA By Sport by ip_category [Redmine ID: #239955] 
		DB: CTS_DataCenter
		Original:
		Revisions:
			- 20251114@Logan.Nguyen: Return the auto tag customer list for daily scan PA By Sport by ip_category [Redmine ID: #239955]
            
		CALL CTS_DC_CustClassification_BySport_Realtime_GetCategory(
    		'[{"CustID":761925,"SportGroup":1}]'
		);
	*/  
    DECLARE	CONST_PARENTID_NORMAL 		INT;
	DECLARE	CONST_PARENTID_PA 			INT;
	DECLARE	CONST_PARENTID_POTENTIALPA	INT;
   	DECLARE CONST_PARENTID_WRAPPER		INT;
    
    SET CONST_PARENTID_NORMAL 			= CTS_DC_CategoryTypeParent_Get ('CONST_PARENTID_NORMAL');
    SET CONST_PARENTID_PA 				= CTS_DC_CategoryTypeParent_Get ('CONST_PARENTID_PA');
    SET CONST_PARENTID_POTENTIALPA 		= CTS_DC_CategoryTypeParent_Get ('CONST_PARENTID_POTENTIALPA');
   	SET CONST_PARENTID_WRAPPER 			= CTS_DC_CategoryTypeParent_Get ('CONST_PARENTID_WRAPPER');
    
    DROP TEMPORARY TABLE IF EXISTS Temp_Customers;
	CREATE TEMPORARY TABLE Temp_Customers(
			CustID					BIGINT UNSIGNED
        ,   SportGroup           	INT
		,	PRIMARY KEY (CustID, SportGroup)
	);
    
    DROP TEMPORARY TABLE IF EXISTS Temp_CustomerCategory;
	CREATE TEMPORARY TABLE Temp_CustomerCategory(
			CustID					BIGINT UNSIGNED NOT NULL
		,   CTSCustID				BIGINT UNSIGNED NOT NULL
		,	ParentID				INT
        ,	CategoryID 				INT
        ,	RelevantCategoryID 		INT UNSIGNED
        ,   SportGroup           	INT
        , 	INDEX IX_Temp_CustomerCategory_CustID(CustID)
	);      
	
    INSERT INTO Temp_Customers (CustID, SportGroup)
    SELECT DISTINCT temp.CustID, temp.SportGroup
    FROM JSON_TABLE(ip_CustInfoList,
			'$[*]' COLUMNS(
					CustID 		BIGINT UNSIGNED PATH '$.CustID'
				,	SportGroup	INT            	PATH '$.SportGroup'
			)) AS temp;
	
    -- #1: Get customer category
	INSERT INTO Temp_CustomerCategory(CustID, CTSCustID, ParentID, CategoryID, RelevantCategoryID, SportGroup)
	SELECT 		tmplc.CustID
			,	tmplc.CTSCustID
			, 	tmplc.ParentID
            ,	tmplc.CategoryID
            ,	tmplc.RelevantCategoryID
            ,   temp.SportGroup
	FROM Temp_Customers AS temp
    	, LATERAL	
			(	SELECT cc.CustID, cc.CTSCustID, cc.CategoryID, ca.ParentID, ca.RelevantCategoryID
				FROM CTS_DataCenter.CTSCustomerClassification_BySport AS cc 
					INNER JOIN CTS_DataCenter.CustomerCategory AS ca ON ca.CategoryID = cc.CategoryID
				WHERE temp.CustID = cc.CustID 
					AND ca.IsActive = 1
                    AND ca.ParentID <> CONST_PARENTID_WRAPPER
                    AND temp.SportGroup = cc.SportID
				ORDER BY ca.CategoryPriority ASC, cc.LastModifiedDate DESC
                LIMIT 1
		   ) tmplc;
	
    -- #2: Return customer category for realtime classification
    SELECT DISTINCT temp.CustID AS CustID, temp.SportGroup AS SportGroup
	FROM Temp_Customers AS temp
		LEFT JOIN Temp_CustomerCategory AS cate ON cate.CustID = temp.CustID AND cate.SportGroup = temp.SportGroup
	WHERE cate.CategoryID IS NULL 
		OR (cate.CategoryID IS NOT NULL AND cate.ParentID = CONST_PARENTID_NORMAL);
	
    -- #3: Return customer with problem category for PA daily scan
	SELECT DISTINCT CustID, SportGroup
    FROM Temp_CustomerCategory 
    WHERE ParentID IN (CONST_PARENTID_PA, CONST_PARENTID_POTENTIALPA)
		AND RelevantCategoryID IS NOT NULL;
	
END$$
DELIMITER ;