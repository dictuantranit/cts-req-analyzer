/*<info serverAlias="CTSMain-CTS_DataCenter" databaseType="2" executers="ctsService" isFunction="0" isNested="0"></info>*/
DROP PROCEDURE IF EXISTS `CTS_DataCenter`.`CTS_DC_CustClassification_BySport_DailyScan_GetNormal`;

DELIMITER $$
CREATE PROCEDURE `CTS_DC_CustClassification_BySport_DailyScan_GetNormal`(
		OUT op_LastCategoryID 	INT 
	,	OUT op_LastCustID 		BIGINT UNSIGNED 

)
    SQL SECURITY INVOKER
BEGIN
	/*
		Created: 20220908@Harvey.Nguyen
		Task: Get cust for daily scan [Redmine ID: #176992]
		DB: CTS_DataCenter
        
		Original:
		Revisions:
			- 20220908@Harvey.Nguyen: Created [Redmine ID: #176992]
            - 20230707@Jonas.Huynh: Normal Renovation [Redmine ID: #189875]
			- 20240124@Jonas.Huynh: Exclude inactive customer within 30days [Redmine ID: #199632]
			- 20240718@Jonas.Huynh: Renovate CC [Redmine ID: #205317]
            
		Param's Explanation (filtered by):      
			- CALL CTS_DC_CustClassification_BySport_DailyScan_GetNormal (@op_LastCategoryID, @op_LastCustID);
	*/
    DECLARE	CONST_CATEGROUPID_PROBATION 	INT;
	DECLARE	CONST_PARENTID_NORMAL 			INT;
	DECLARE	CONST_PARENTID_WRAPPER 			INT;
        	
	DECLARE lv_LastCategoryID 		INT;
	DECLARE lv_LastCustID 			BIGINT UNSIGNED;
    DECLARE lv_BatchSize 			BIGINT;
    DECLARE lv_ScanDateValid 		DATETIME;
    
    DECLARE lv_NextCategoryID 		INT;
    DECLARE lv_NextCustID 			BIGINT UNSIGNED;
    DECLARE lv_NextScanDateValid 	DATETIME;
    
    DECLARE lv_CurrentDate 			DATE DEFAULT CURRENT_DATE();
    DECLARE lv_From30Date 			DATE DEFAULT DATE_SUB(lv_CurrentDate, INTERVAL 29 DAY);
    
    SET CONST_PARENTID_NORMAL 			= CTS_DC_CategoryTypeParent_Get ('CONST_PARENTID_NORMAL');
    SET CONST_CATEGROUPID_PROBATION 	= CTS_DC_CategoryTypeParent_Get ('CONST_CATEGROUPID_PROBATION');
    SET CONST_PARENTID_WRAPPER 			= CTS_DC_CategoryTypeParent_Get ('CONST_PARENTID_WRAPPER');
    
    DROP TEMPORARY TABLE IF EXISTS Temp_Category;
	CREATE TEMPORARY TABLE Temp_Category(
			CategoryID		INT PRIMARY KEY
        ,	ScanDate		DATETIME
	);
    
    DROP TEMPORARY TABLE IF EXISTS Temp_Normal;
    CREATE TEMPORARY TABLE 	Temp_Normal (
            CustID					BIGINT UNSIGNED
		,	SportID					SMALLINT
        ,	PRIMARY KEY (CustID, SportID)
	);
    
    INSERT INTO Temp_Category(CategoryID, ScanDate)
	SELECT 	CategoryID
        , 	DATE_SUB(NOW(), INTERVAL ScanIntervalInSecond - 86400 SECOND)
	FROM CTS_DataCenter.CustomerCategory
	WHERE ParentID = CONST_PARENTID_NORMAL 
		AND CategoryGroupID <> CONST_CATEGROUPID_PROBATION 
		AND IsActive = 1
		AND ScanIntervalInSecond > 0; 
    
    SELECT ParameterValue 
    INTO lv_BatchSize
    FROM CTS_DataCenter.SystemParameter 
    WHERE ParameterID = 113; 
    
    SELECT ParameterValue 
    INTO lv_LastCategoryID 
    FROM CTS_DataCenter.SystemParameter 
    WHERE ParameterID = 114;
    
    SELECT ParameterValue 
    INTO lv_LastCustID 
    FROM CTS_DataCenter.SystemParameter 
    WHERE ParameterID = 115;
    
    IF lv_LastCategoryID IS NULL OR lv_LastCategoryID = 0 THEN
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
  
	INSERT IGNORE INTO Temp_Normal (CustID, SportID)
	SELECT 	tmplc.CustID, tmplc.SportID
	FROM CTS_DataCenter.CTSCustomerClassification_BySport AS clss USE INDEX(IX_CTSCC_BySport_CategoryID_CustID_LastScannedDate)
		,	LATERAL	
			(	SELECT cc.CustID, cc.SportID, cc.CategoryID
				FROM CTS_DataCenter.CTSCustomerClassification_BySport AS cc 
					INNER JOIN CTS_DataCenter.CustomerCategory AS ca ON ca.CategoryID = cc.CategoryID
				WHERE cc.CustID = clss.CustID
					AND cc.SportID = clss.SportID
					AND ca.IsActive = 1
					AND ca.ParentID <> CONST_PARENTID_WRAPPER 
				ORDER BY ca.CategoryPriority ASC, cc.LastModifiedDate DESC
				LIMIT 1
		   ) AS tmplc
	WHERE clss.CustID > lv_LastCustID
		AND clss.CategoryID = lv_LastCategoryID
		AND clss.LastScannedDate <= lv_ScanDateValid
		AND tmplc.CategoryID = lv_LastCategoryID
		AND EXISTS (SELECT 1
					FROM CTS_Archive.CTSCustomerAssociationStatus AS arc
					WHERE arc.CustID = clss.CustID AND arc.LastTicketDate >= lv_From30Date)
	ORDER BY 	clss.CategoryID ASC
		, 		clss.CustID ASC
	LIMIT lv_BatchSize;
    
    IF NOT EXISTS (SELECT 1 FROM Temp_Normal) THEN
		SELECT 	cate.CategoryID
			,	cate.ScanDate
        INTO 	lv_NextCategoryID
			,	lv_NextScanDateValid
		FROM Temp_Category AS cate
			INNER JOIN CTS_DataCenter.CTSCustomerClassification_BySport AS clss ON clss.CategoryID = cate.CategoryID
			,	LATERAL	
				(	SELECT cc.CategoryID, cc.LastScannedDate
					FROM CTS_DataCenter.CTSCustomerClassification_BySport AS cc 
						INNER JOIN CTS_DataCenter.CustomerCategory AS ca ON ca.CategoryID = cc.CategoryID
					WHERE cc.CustID = clss.CustID
						AND cc.SportID = clss.SportID
						AND ca.IsActive = 1
						AND ca.ParentID <> CONST_PARENTID_WRAPPER 
					ORDER BY ca.CategoryPriority ASC, cc.LastModifiedDate DESC
					LIMIT 1
			    ) AS tmplc
		WHERE cate.CategoryID > lv_LastCategoryID
			AND tmplc.CategoryID = cate.CategoryID
			AND tmplc.LastScannedDate <= cate.ScanDate
			AND EXISTS (SELECT 1
						FROM CTS_Archive.CTSCustomerAssociationStatus AS arc
						WHERE arc.CustID = clss.CustID AND arc.LastTicketDate >= lv_From30Date)
		ORDER BY cate.CategoryID ASC
		LIMIT 1; 
    END IF;
    
    IF lv_NextCategoryID IS NOT NULL THEN      
        INSERT IGNORE INTO Temp_Normal (CustID, SportID)
		SELECT 	tmplc.CustID, tmplc.SportID
		FROM CTS_DataCenter.CTSCustomerClassification_BySport AS clss USE INDEX(IX_CTSCC_BySport_CategoryID_CustID_LastScannedDate)
			, LATERAL	
				(	SELECT cc.CustID, cc.SportID, cc.CategoryID
					FROM CTS_DataCenter.CTSCustomerClassification_BySport AS cc 
						INNER JOIN CTS_DataCenter.CustomerCategory AS ca ON ca.CategoryID = cc.CategoryID
					WHERE cc.CustID = clss.CustID
						AND cc.SportID = clss.SportID
						AND ca.IsActive = 1
						AND ca.ParentID <> CONST_PARENTID_WRAPPER 
					ORDER BY ca.CategoryPriority ASC, cc.LastModifiedDate DESC
					LIMIT 1
			   ) AS tmplc 
		WHERE clss.CustID > 0
			AND clss.CategoryID = lv_NextCategoryID
			AND clss.LastScannedDate <= lv_NextScanDateValid
            AND tmplc.CategoryID = lv_NextCategoryID
			AND EXISTS (SELECT 1
						FROM CTS_Archive.CTSCustomerAssociationStatus AS arc
						WHERE arc.CustID = clss.CustID AND arc.LastTicketDate >= lv_From30Date)
		ORDER BY 	clss.CategoryID ASC
            , 		clss.CustID ASC
		LIMIT lv_BatchSize;
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
    
    SELECT 	CustID  AS CustId, 
			SportID AS SportGroup
    FROM Temp_Normal;

END$$
DELIMITER ;