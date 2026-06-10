/*<info serverAlias="CTSMain-CTS_DataCenter" databaseType="2" executers="ctsWeb,ctsAPI,ctsService" isFunction="0" isNested="0"></info>*/
DROP PROCEDURE IF EXISTS `CTS_DC_CustClassification_TaggingScan_Get`;

DELIMITER $$
CREATE PROCEDURE `CTS_DC_CustClassification_TaggingScan_Get`(
		OUT op_LastCategoryID 	INT 
	,	OUT op_LastCustID 		BIGINT UNSIGNED 
)

    SQL SECURITY INVOKER
BEGIN
	/*
		Created:	20230804@Jonas.Huynh
        Task :		Get normal customer to scan tagging
		DB:			CTS_DataCenter  
		Original: 
		Revisions:
			- 20230804@Jonas.Huynh: Created [RedmineID: #191400]
			- 20240620@Jonas.Huynh: Renovate CC [RedmineID: #205317]
			- 20241218@Thomas.Nguyen: New CC 230x-240x [Redmine ID: #206327]
            
        Param's Explanation:     
        Example:
			- CALL CTS_DataCenter.CTS_DC_CustClassification_TaggingScan_Get();
	*/ 
    DECLARE	CONST_PARENTID_NORMAL		INT ;
    DECLARE CONST_PARENTID_WRAPPER		INT	;
	DECLARE CONST_CATEGROUPID_NEW		INT	;            
	DECLARE CONST_CATEGROUPID_GOOD 		INT ;
    DECLARE CONST_CATEGROUPID_NORMAL 	INT ;
	DECLARE CONST_CATEGROUPID_PROBATION	INT	;            
	DECLARE CONST_CATEGROUPID_SMART 	INT ;
    DECLARE CONST_CATEGROUPID_RISKY 	INT ;

    DECLARE lv_BatchSize 				INT;
    DECLARE lv_LastCategoryID 			BIGINT UNSIGNED;
    DECLARE lv_NextCategoryID 			BIGINT UNSIGNED;
    DECLARE lv_LastCustID 				BIGINT UNSIGNED;
    DECLARE lv_NextCustID 				BIGINT UNSIGNED;
    
    SET CONST_PARENTID_NORMAL 			= CTS_DC_CategoryTypeParent_Get ('CONST_PARENTID_NORMAL');
    SET CONST_PARENTID_WRAPPER 			= CTS_DC_CategoryTypeParent_Get ('CONST_PARENTID_WRAPPER');
	SET CONST_CATEGROUPID_NEW 			= CTS_DC_CategoryTypeParent_Get ('CONST_CATEGROUPID_NEW');
	SET CONST_CATEGROUPID_GOOD 			= CTS_DC_CategoryTypeParent_Get ('CONST_CATEGROUPID_GOOD');
    SET CONST_CATEGROUPID_NORMAL 		= CTS_DC_CategoryTypeParent_Get ('CONST_CATEGROUPID_NORMAL');
	SET CONST_CATEGROUPID_PROBATION 	= CTS_DC_CategoryTypeParent_Get ('CONST_CATEGROUPID_PROBATION');
	SET CONST_CATEGROUPID_SMART 		= CTS_DC_CategoryTypeParent_Get ('CONST_CATEGROUPID_SMART');
    SET CONST_CATEGROUPID_RISKY 		= CTS_DC_CategoryTypeParent_Get ('CONST_CATEGROUPID_RISKY');
        
    DROP TEMPORARY TABLE IF EXISTS Temp_Category;
	CREATE TEMPORARY TABLE Temp_Category(
			CategoryID			INT UNSIGNED PRIMARY KEY,
            CategoryGroupID		INT UNSIGNED
	);
    
    DROP TEMPORARY TABLE IF EXISTS Temp_Cust;
    CREATE TEMPORARY TABLE Temp_Cust(
			CustID 			BIGINT UNSIGNED PRIMARY KEY,
            CategoryID		INT UNSIGNED NOT NULL
    );
          
    SELECT ParameterValue 
    INTO lv_BatchSize 
    FROM CTS_DataCenter.SystemParameter 
    WHERE ParameterID = 143; 
    
    SELECT ParameterValue 
    INTO lv_LastCategoryID 
    FROM CTS_DataCenter.SystemParameter 
    WHERE ParameterID = 144;
    
    SELECT ParameterValue 
    INTO lv_LastCustID 
    FROM CTS_DataCenter.SystemParameter 
    WHERE ParameterID = 145;
   
	INSERT INTO Temp_Category(CategoryID, CategoryGroupID)
	SELECT CategoryID, CategoryGroupID
	FROM CTS_DataCenter.CustomerCategory
	WHERE ParentID = CONST_PARENTID_NORMAL 
		AND IsActive = 1
		AND ScanTaggingIntervalInSecond > 0;
        
    IF lv_LastCategoryID IS NULL OR lv_LastCategoryID = 0 THEN
		SELECT CategoryID 
		INTO lv_LastCategoryID
		FROM Temp_Category
		ORDER BY CategoryID ASC
        LIMIT 1;
	END IF;
    
    INSERT IGNORE INTO Temp_Cust (CustID, CategoryID)
    SELECT tmplc.CustID, tmplc.CategoryID
	FROM CTS_DataCenter.CTSCustomerClassification AS clss
		,	LATERAL	
				(	SELECT cc.CustID, cc.CategoryID
					FROM CTS_DataCenter.CTSCustomerClassification AS cc 
						INNER JOIN CTS_DataCenter.CustomerCategory AS ca ON ca.CategoryID = cc.CategoryID
					WHERE cc.CustID = clss.CustID
						AND ca.IsActive = 1
                        AND cc.ParentID <> CONST_PARENTID_WRAPPER 
					ORDER BY ca.CategoryPriority ASC, cc.LastModifiedDate DESC
					LIMIT 1
			   ) AS tmplc 
	WHERE clss.CustID > lv_LastCustID
		AND clss.CategoryID = lv_LastCategoryID
		AND clss.ParentID = CONST_PARENTID_NORMAL
		AND tmplc.CategoryID = lv_LastCategoryID
	ORDER BY clss.CategoryID ASC
		,	 clss.CustID ASC
	LIMIT lv_BatchSize;
    
    IF NOT EXISTS (SELECT 1 FROM Temp_Cust) THEN
		SELECT tmplc.CategoryID
        INTO   lv_NextCategoryID
		FROM Temp_Category AS cate
			INNER JOIN CTS_DataCenter.CTSCustomerClassification AS clss ON clss.CategoryID = cate.CategoryID
			, LATERAL	
				(	SELECT cc.CustID, cc.CategoryID
					FROM CTS_DataCenter.CTSCustomerClassification AS cc 
						INNER JOIN CTS_DataCenter.CustomerCategory AS ca ON ca.CategoryID = cc.CategoryID
					WHERE cc.CustID = clss.CustID
						AND ca.IsActive = 1
                        AND cc.ParentID <> CONST_PARENTID_WRAPPER
					ORDER BY ca.CategoryPriority ASC, cc.LastModifiedDate DESC
					LIMIT 1
			    ) AS tmplc
		WHERE cate.CategoryID > lv_LastCategoryID
			AND tmplc.CategoryID = cate.CategoryID
		ORDER BY cate.CategoryID ASC
		LIMIT 1; 
    END IF;
    
    IF lv_NextCategoryID IS NOT NULL THEN
		INSERT IGNORE INTO Temp_Cust (CustID, CategoryID)
		SELECT tmplc.CustID, tmplc.CategoryID
		FROM CTS_DataCenter.CTSCustomerClassification AS clss
			,	LATERAL	
				(	SELECT cc.CustID, cc.CategoryID
					FROM CTS_DataCenter.CTSCustomerClassification AS cc 
						INNER JOIN CTS_DataCenter.CustomerCategory AS ca ON ca.CategoryID = cc.CategoryID
					WHERE cc.CustID = clss.CustID
						AND ca.IsActive = 1
                        AND cc.ParentID <> CONST_PARENTID_WRAPPER
					ORDER BY ca.CategoryPriority ASC, cc.LastModifiedDate DESC
					LIMIT 1
			   ) AS tmplc 
		WHERE clss.CustID > 0
			AND clss.CategoryID = lv_NextCategoryID
			AND clss.ParentID = CONST_PARENTID_NORMAL
           	AND tmplc.CategoryID = lv_NextCategoryID
		ORDER BY clss.CategoryID ASC
			,	 clss.CustID ASC
		LIMIT lv_BatchSize;
	ELSE
		SET lv_NextCategoryID = lv_LastCategoryID;
	END IF;
    
    SELECT MAX(CustID)
    INTO lv_NextCustID
    FROM Temp_Cust;
    
    IF lv_NextCustID IS NOT NULL THEN
        SET op_LastCategoryID = lv_NextCategoryID;
		SET op_LastCustID = lv_NextCustID;
	ELSE 
		SELECT CategoryID
        INTO lv_NextCategoryID
		FROM Temp_Category
		ORDER BY CategoryID ASC 
		LIMIT 1;
	
        SET op_LastCategoryID = lv_NextCategoryID;
        SET op_LastCustID = 0;
    END IF;
    
    SELECT DISTINCT	tmp.CustID, 
		CASE 
			WHEN tmpc.CategoryGroupID IS NOT NULL AND tmpc.CategoryGroupID IN (CONST_CATEGROUPID_NEW, CONST_CATEGROUPID_GOOD, CONST_CATEGROUPID_NORMAL, CONST_CATEGROUPID_PROBATION, CONST_CATEGROUPID_SMART, CONST_CATEGROUPID_RISKY) THEN 1 
            ELSE 0 
		END AS IsCheckTaggingTW
    FROM Temp_Cust AS tmp
		LEFT JOIN Temp_Category AS tmpc ON tmpc.CategoryID = tmp.CategoryID;
    
END$$

DELIMITER ;