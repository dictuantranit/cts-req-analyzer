/*<info serverAlias="CTSMain-CTS_DataCenter" databaseType="2" executers="ctsService" isFunction="0" isNested="0"></info>*/
DROP PROCEDURE IF EXISTS `CTS_DataCenter`.`CTS_DC_CustClassification_DailyScan_GetNormal`;

DELIMITER $$
CREATE DEFINER=`ctsOwner`@`%` PROCEDURE `CTS_DC_CustClassification_DailyScan_GetNormal`(
		OUT op_LastCategoryID 	INT 
	,	OUT op_LastCustID 		BIGINT UNSIGNED 

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
            - 20221007@Harvey.Nguyen: Return CurrentCategoryID [Redmine ID: #178022]
            - 20240702@Victoria.le: Renovate CC - Phase2 - Remove hardcode [Redmine ID: #205317]

		Param's Explanation (filtered by):      
			- CALL CTS_DC_CustClassification_DailyScan_GetNormal (@op_LastCategoryID, @op_LastCustID);
	*/
	
	DECLARE CONST_PARENTID_VVIP 						INT;
	DECLARE CONST_PARENTID_NORMAL		    			INT;
	DECLARE CONST_PARENTID_WRAPPER		    			INT;

	DECLARE CONST_CATEGROUPID_PROBATION	    			INT;

	DECLARE lv_LastCategoryID 							INT;
	DECLARE lv_LastCustID 								BIGINT UNSIGNED;
	DECLARE lv_BatchSize 								BIGINT;
	DECLARE lv_ScanDateValid 							DATETIME;

	DECLARE lv_NextCategoryID 							INT;
	DECLARE lv_NextCustID 								BIGINT UNSIGNED;
	DECLARE lv_NextScanDateValid 						DATETIME;

	SET CONST_PARENTID_VVIP 							= CTS_DC_CategoryTypeParent_Get ('CONST_PARENTID_VVIP');
	SET CONST_PARENTID_NORMAL 							= CTS_DC_CategoryTypeParent_Get ('CONST_PARENTID_NORMAL');
	SET CONST_PARENTID_WRAPPER 							= CTS_DC_CategoryTypeParent_Get ('CONST_PARENTID_WRAPPER');

	SET CONST_CATEGROUPID_PROBATION						= CTS_DC_CategoryTypeParent_Get ('CONST_CATEGROUPID_PROBATION');
    
    DROP TEMPORARY TABLE IF EXISTS Temp_Category;
	CREATE TEMPORARY TABLE Temp_Category(
			CategoryID				INT PRIMARY KEY 	
        ,	ScanDate				DATETIME
	);
    
    DROP TEMPORARY TABLE IF EXISTS Temp_Normal;
    CREATE TEMPORARY TABLE 	Temp_Normal (
			CustID 					BIGINT UNSIGNED PRIMARY KEY
		,	CurrentCategoryID		INT
	);
    
    INSERT INTO Temp_Category(CategoryID, ScanDate)
	SELECT 	CategoryID
        , 	DATE_SUB(NOW(), INTERVAL ScanIntervalInSecond - 86400 SECOND)
	FROM CTS_DataCenter.CustomerCategory
	WHERE ParentID = CONST_PARENTID_NORMAL 
		AND IsActive = 1
		AND ScanIntervalInSecond > 0; 
    
    SELECT ParameterValue 
    INTO lv_BatchSize 
    FROM CTS_DataCenter.SystemParameter 
    WHERE ParameterID = 84; 
    
    SELECT ParameterValue 
    INTO lv_LastCategoryID 
    FROM CTS_DataCenter.SystemParameter 
    WHERE ParameterID = 85;
    
    SELECT ParameterValue 
    INTO lv_LastCustID 
    FROM CTS_DataCenter.SystemParameter 
    WHERE ParameterID = 86;
    
    IF lv_LastCategoryID IS NULL OR  lv_LastCategoryID = 0 THEN
		SELECT CategoryID 
		INTO lv_LastCategoryID 
		FROM Temp_Category
		ORDER BY CategoryID ASC
        LIMIT 1;
	END IF;
    
    SELECT ScanDate 
    INTO lv_ScanDateValid 
    FROM Temp_Category
    WHERE CategoryID = lv_LastCategoryID;

    INSERT IGNORE INTO Temp_Normal (CustID, CurrentCategoryID)
	SELECT clss.CustID, clss.CategoryID
	FROM CTS_DataCenter.CTSCustomerClassification AS clss USE INDEX(IX_CTSCC_CategoryID_CustID_LastScannedDate)
	,	LATERAL (
			SELECT cls.CustID, cls.CategoryID, cat.CategoryGroupID, cat.ParentID
			FROM CTS_DataCenter.CTSCustomerClassification AS cls 
				INNER JOIN CTS_DataCenter.CustomerCategory AS cat ON cat.CategoryID = cls.CategoryID AND cat.IsActive = 1
			WHERE cls.CustID = clss.CustID
				AND cls.ParentID <> CONST_PARENTID_WRAPPER
			ORDER BY cat.CategoryPriority ASC, cls.LastModifiedDate DESC
			LIMIT 1
		) AS ltc
	WHERE 	clss.CustID > lv_LastCustID
		AND clss.CategoryID = ltc.CategoryID
		AND ltc.CategoryID = lv_LastCategoryID
		AND clss.LastScannedDate <= lv_ScanDateValid
		AND ltc.ParentID <> CONST_PARENTID_VVIP
		AND ltc.CategoryGroupID <> CONST_CATEGROUPID_PROBATION
	ORDER BY clss.CategoryID ASC
		,	clss.CustID ASC
	LIMIT lv_BatchSize
	;
	
	IF NOT EXISTS (SELECT 1 FROM Temp_Normal) THEN
		SELECT 	cate.CategoryID
			,	cate.ScanDate
        INTO 	lv_NextCategoryID
			,	lv_NextScanDateValid
		FROM Temp_Category  AS cate
			INNER JOIN CTS_DataCenter.CTSCustomerClassification AS clss ON cate.CategoryID = clss.CategoryID 
			,	LATERAL (
					SELECT cls.CategoryID, cat.CategoryGroupID, cat.ParentID
					FROM CTS_DataCenter.CTSCustomerClassification AS cls 
						INNER JOIN CTS_DataCenter.CustomerCategory AS cat ON cat.CategoryID = cls.CategoryID AND cat.IsActive = 1
					WHERE cls.CustID = clss.CustID
						AND cls.ParentID <> CONST_PARENTID_WRAPPER
					ORDER BY cat.CategoryPriority ASC, cls.LastModifiedDate DESC
					LIMIT 1
				) AS ltc
		WHERE 	clss.CategoryID = ltc.CategoryID
			AND ltc.CategoryID > lv_LastCategoryID
			AND clss.LastScannedDate <= cate.ScanDate
			AND ltc.ParentID <> CONST_PARENTID_VVIP
			AND ltc.CategoryGroupID <> CONST_CATEGROUPID_PROBATION
		ORDER BY cate.CategoryID ASC
		LIMIT 1;
		
    END IF;
	
	IF lv_NextCategoryID IS NOT NULL THEN
		SELECT ScanDate 
		INTO lv_NextScanDateValid  
		FROM Temp_Category
		WHERE CategoryID = lv_NextCategoryID;
		
		INSERT IGNORE INTO Temp_Normal (CustID, CurrentCategoryID)
		SELECT clss.CustID, clss.CategoryID
		FROM CTS_DataCenter.CTSCustomerClassification AS clss USE INDEX(IX_CTSCC_CategoryID_CustID_LastScannedDate)
		,	LATERAL (
				SELECT cls.CategoryID, cat.CategoryGroupID, cat.ParentID
				FROM CTS_DataCenter.CTSCustomerClassification AS cls 
					INNER JOIN CTS_DataCenter.CustomerCategory AS cat ON cat.CategoryID = cls.CategoryID AND cat.IsActive = 1
				WHERE cls.CustID = clss.CustID
					AND cls.ParentID <> CONST_PARENTID_WRAPPER
				ORDER BY cat.CategoryPriority ASC, cls.LastModifiedDate DESC
				LIMIT 1
			) AS ltc
		WHERE 	clss.CustID > 0
			AND clss.CategoryID = ltc.CategoryID
			AND ltc.CategoryID = lv_NextCategoryID
			AND clss.LastScannedDate <= lv_NextScanDateValid
			AND ltc.ParentID <> CONST_PARENTID_VVIP
			AND ltc.CategoryGroupID <> CONST_CATEGROUPID_PROBATION
		ORDER BY clss.CategoryID ASC
			,	clss.CustID ASC
		LIMIT lv_BatchSize
		;
	
	ELSE
		SET lv_NextCategoryID = lv_LastCategoryID;
	END IF;
	
	SELECT MAX(CustID)
    INTO lv_NextCustID
    FROM Temp_Normal;
	
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
	
	SELECT DISTINCT	
		tmpNr.CustID
	,	cc.CategoryGroupID AS CurrentCategoryID
    FROM Temp_Normal AS tmpNr
		INNER JOIN CTS_DataCenter.CustomerCategory AS cc ON tmpNr.CurrentCategoryID = cc.CategoryID;
	
END$$
DELIMITER ;