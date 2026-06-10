/*<info serverAlias="CTSMain-CTS_DataCenter" databaseType="2" executers="ctsService" isFunction="0" isNested="0"></info>*/
DROP PROCEDURE IF EXISTS `CTS_DataCenter`.`CTS_DC_CustClassificationAgency_DailyScan_GetNormal`;

DELIMITER $$
CREATE DEFINER=`ctsOwner`@`%` PROCEDURE `CTS_DC_CustClassificationAgency_DailyScan_GetNormal`(
		OUT op_LastCategoryID 	INT 
	,	OUT op_LastCustID 		BIGINT UNSIGNED 

)
    SQL SECURITY INVOKER
BEGIN
	/*
		Created:	20240927@Casey.Huynh
		Task:		Create New Category for New Agent
		DB:			CTS_DataCenter
		Original:
		Revisions: 
				- 20240927@Casey.Huynh: Created [Redmine ID: #185799]

		Param's Explanation(filtered by):
        
        Example:     
			- CALL CTS_DC_CustClassificationAgency_DailyScan_GetNormal(@op_LastCategoryID, @op_LastCustID);

	*/
	
	DECLARE CONST_AGENCY_PARENTID_NORMAL	INT;

	DECLARE lv_LastCategoryID 				INT;
	DECLARE lv_LastCustID 					BIGINT UNSIGNED;
	DECLARE lv_BatchSize 					BIGINT;
	DECLARE lv_ScanDateValid 				DATETIME;

	DECLARE lv_NextCategoryID 				INT;
	DECLARE lv_NextCustID 					BIGINT UNSIGNED;
	DECLARE lv_NextScanDateValid 			DATETIME;

	SET CONST_AGENCY_PARENTID_NORMAL 		= CTS_DC_CategoryTypeParent_Get ('CONST_AGENCY_PARENTID_NORMAL');
    
    DROP TEMPORARY TABLE IF EXISTS Temp_Category;
	CREATE TEMPORARY TABLE Temp_Category(
			CategoryID	INT PRIMARY KEY 	
        ,	ScanDate	DATETIME
	);
    
    DROP TEMPORARY TABLE IF EXISTS Temp_Normal;
    CREATE TEMPORARY TABLE 	Temp_Normal (
			CustID 				BIGINT UNSIGNED PRIMARY KEY
		,	CurrentCategoryID	INT
	);
    
    INSERT INTO Temp_Category(CategoryID, ScanDate)
	SELECT 	CategoryID
        , 	DATE_SUB(NOW(), INTERVAL ScanIntervalInSecond - 86400 SECOND)
	FROM CTS_DataCenter.CustomerCategoryAgency
	WHERE ParentID = CONST_AGENCY_PARENTID_NORMAL 
		AND IsActive = 1
		AND ScanIntervalInSecond > 0; 
    
    SELECT ParameterValue 
    INTO lv_BatchSize 
    FROM CTS_DataCenter.SystemParameter 
    WHERE ParameterID = 175; 
    
    SELECT ParameterValue 
    INTO lv_LastCategoryID 
    FROM CTS_DataCenter.SystemParameter 
    WHERE ParameterID = 176;
    
    SELECT ParameterValue 
    INTO lv_LastCustID 
    FROM CTS_DataCenter.SystemParameter 
    WHERE ParameterID = 177;
    
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
	FROM CTS_DataCenter.CTSCustomerClassificationAgency AS clss USE INDEX(IX_CTSCCAgency_CategoryID_CustID_LastScannedDate)
	,	LATERAL (
			SELECT cls.CustID, cls.CategoryID, cat.CategoryGroupID, cat.ParentID
			FROM CTS_DataCenter.CTSCustomerClassificationAgency AS cls 
				INNER JOIN CTS_DataCenter.CustomerCategoryAgency AS cat ON cat.CategoryID = cls.CategoryID AND cat.IsActive = 1
			WHERE cls.CustID = clss.CustID
			ORDER BY cat.CategoryPriority ASC, cls.LastModifiedDate DESC
			LIMIT 1
		) AS ltc
	WHERE 	clss.CustID > lv_LastCustID
		AND clss.CategoryID = ltc.CategoryID
		AND ltc.CategoryID = lv_LastCategoryID
		AND clss.LastScannedDate <= lv_ScanDateValid
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
			INNER JOIN CTS_DataCenter.CTSCustomerClassificationAgency AS clss ON cate.CategoryID = clss.CategoryID 
			,	LATERAL (
					SELECT cls.CategoryID, cat.CategoryGroupID, cat.ParentID
					FROM CTS_DataCenter.CTSCustomerClassificationAgency AS cls 
						INNER JOIN CTS_DataCenter.CustomerCategoryAgency AS cat ON cat.CategoryID = cls.CategoryID AND cat.IsActive = 1
					WHERE cls.CustID = clss.CustID
					ORDER BY cat.CategoryPriority ASC, cls.LastModifiedDate DESC
					LIMIT 1
				) AS ltc
		WHERE 	clss.CategoryID = ltc.CategoryID
			AND ltc.CategoryID > lv_LastCategoryID
			AND clss.LastScannedDate <= cate.ScanDate
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
		FROM CTS_DataCenter.CTSCustomerClassificationAgency AS clss USE INDEX(IX_CTSCCAgency_CategoryID_CustID_LastScannedDate)
		,	LATERAL (
				SELECT cls.CategoryID, cat.CategoryGroupID, cat.ParentID
				FROM CTS_DataCenter.CTSCustomerClassificationAgency AS cls 
					INNER JOIN CTS_DataCenter.CustomerCategoryAgency AS cat ON cat.CategoryID = cls.CategoryID AND cat.IsActive = 1
				WHERE cls.CustID = clss.CustID
				ORDER BY cat.CategoryPriority ASC, cls.LastModifiedDate DESC
				LIMIT 1
			) AS ltc
		WHERE 	clss.CustID > 0
			AND clss.CategoryID = ltc.CategoryID
			AND ltc.CategoryID = lv_NextCategoryID
			AND clss.LastScannedDate <= lv_NextScanDateValid
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
		INNER JOIN CTS_DataCenter.CustomerCategoryAgency AS cc ON tmpNr.CurrentCategoryID = cc.CategoryID;
	
END$$
DELIMITER ;