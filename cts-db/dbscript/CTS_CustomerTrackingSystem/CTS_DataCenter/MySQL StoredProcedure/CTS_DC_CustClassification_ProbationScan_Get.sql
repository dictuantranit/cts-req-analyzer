/*<info serverAlias="CTSMain-CTS_DataCenter" databaseType="2" executers="ctsService" isFunction="0" isNested="0"></info>*/

DROP PROCEDURE IF EXISTS `CTS_DataCenter`.`CTS_DC_CustClassification_ProbationScan_Get`;

DELIMITER $$
CREATE DEFINER=`ctsOwner`@`%` PROCEDURE  `CTS_DataCenter`.`CTS_DC_CustClassification_ProbationScan_Get`(
		IN 	ip_NoOfRecord 			INT
	,	OUT	op_LastCustID			INT
	,	OUT	op_LastCategoryID		INT
)
    SQL SECURITY INVOKER 
sp: BEGIN
	/*
		Created:	20200918@Harvey.Nguyen
		Task:		Return the Probation list for scanning
		DB:			CTS_DataCenter
		Original:
		Revisions:
			- [20200923@Irena.Vo][141755]: Enhance SP.
            - [20201111@Irena.Vo][145028]: Update ScanTime = 20 Last Days
			- 20201214-20201221@Irena.Vo: Ignore Pin category. Declare lv_CurrentDate & Enhance logic SP [RedmineID: #145951]
			- 20210525@Irena.Vo: Change col name PinCustomerCategory: CustID -> CTSCustID [RedmineID: #152965] 
			- 20210611@Irena.Vo: Update schedule scan [RedmineID: #156466]
            - 20210722@Irena.Vo: Refactor SP [RedmineID: #157203]
			- 202230426@Long.Luu: Adjust Probation's period from 20 to 15 [Redmine ID: #187433]
			- 20230605@Jonas.Huynh: Renovate normal classification (phase2) [Redmine ID: #186684]
           	- 20240620@Jonas.Huynh: Renovate CC [RedmineID: #205317]
		
        Param's Explanation (filtered by):
			- CALL CTS_DC_CustClassification_ProbationScan_Get (100);
	*/
    DECLARE	CONST_PARENTID_NORMAL			INT;
    DECLARE	CONST_CATEGROUPID_PROBATION		INT;
    DECLARE CONST_PARENTID_WRAPPER			INT;   
    
	DECLARE lv_BatchSize 					INT;
    DECLARE lv_LastCustID					BIGINT UNSIGNED;
    DECLARE lv_NextCustID 					BIGINT UNSIGNED;
    DECLARE lv_LastCategoryID				BIGINT UNSIGNED;
    DECLARE lv_NextCategoryID 				BIGINT UNSIGNED;
    DECLARE lv_CurrentDate 					DATE DEFAULT CURRENT_DATE();
    DECLARE lv_ToLastDay 					DATE DEFAULT DATE_SUB(lv_CurrentDate, INTERVAL 2 DAY); /*Up to 3 Last Day*/
    
    SET CONST_PARENTID_NORMAL 				= CTS_DC_CategoryTypeParent_Get ('CONST_PARENTID_NORMAL');
    SET CONST_PARENTID_WRAPPER 				= CTS_DC_CategoryTypeParent_Get ('CONST_PARENTID_WRAPPER');
	SET CONST_CATEGROUPID_PROBATION 		= CTS_DC_CategoryTypeParent_Get ('CONST_CATEGROUPID_PROBATION');
    
    DROP TEMPORARY TABLE IF EXISTS Temp_Category;
	CREATE TEMPORARY TABLE Temp_Category(
			CategoryID		INT PRIMARY KEY
	);
    
    DROP TEMPORARY TABLE IF EXISTS Temp_Cust;
    CREATE TEMPORARY TABLE Temp_Cust(
			CustID 			BIGINT UNSIGNED PRIMARY KEY
    );
    
    SELECT ParameterValue 
    INTO lv_BatchSize 
    FROM CTS_DataCenter.SystemParameter 
    WHERE ParameterID = 165; 
    
    SELECT ParameterValue 
    INTO lv_LastCategoryID
    FROM CTS_DataCenter.SystemParameter 
    WHERE ParameterID = 166;
    
	SELECT ParameterValue 
    INTO lv_LastCustID 
    FROM CTS_DataCenter.SystemParameter 
    WHERE ParameterID = 167; 
    
 	INSERT INTO Temp_Category(CategoryID)
	SELECT ca.CategoryID
	FROM CTS_DataCenter.CustomerCategory AS ca
	WHERE ca.CategoryGroupID = CONST_CATEGROUPID_PROBATION 
		AND ca.IsActive = 1;
        
	 IF lv_LastCategoryID IS NULL OR lv_LastCategoryID = 0 THEN
		SELECT CategoryID 
		INTO lv_LastCategoryID
		FROM Temp_Category
		ORDER BY CategoryID ASC
        LIMIT 1;
	END IF;
    
    INSERT INTO Temp_Cust(CustID)
    SELECT 	tmplc.CustID
    FROM	CTS_DataCenter.CTSCustomerClassification AS clss
		,	LATERAL	
				(	SELECT cc.CustID, cc.CategoryID, ca.CategoryGroupID, cc.LastScannedDate, cc.CreatedDate
					FROM CTS_DataCenter.CTSCustomerClassification AS cc 
						INNER JOIN CTS_DataCenter.CustomerCategory AS ca ON ca.CategoryID = cc.CategoryID
					WHERE cc.CustID = clss.CustID
						AND ca.IsActive = 1
                        AND ca.ParentID <> CONST_PARENTID_WRAPPER 
					ORDER BY ca.CategoryPriority ASC, cc.LastModifiedDate DESC
					LIMIT 1
			   ) AS tmplc
	WHERE clss.CustID > lv_LastCustID
		AND clss.CategoryID = lv_LastCategoryID
        AND clss.ParentID = CONST_PARENTID_NORMAL
		AND tmplc.CategoryID = lv_LastCategoryID
		AND (tmplc.LastScannedDate IS NULL OR tmplc.LastScannedDate < lv_CurrentDate)
		AND (tmplc.CreatedDate < lv_ToLastDay)
	ORDER BY clss.CategoryID ASC
		,	 clss.CustID ASC
	LIMIT	lv_BatchSize;
    
    IF NOT EXISTS (SELECT 1 FROM Temp_Cust) THEN
		SELECT tmplc.CategoryID
        INTO   lv_NextCategoryID
		FROM Temp_Category AS cate
			INNER JOIN CTS_DataCenter.CTSCustomerClassification AS clss ON clss.CategoryID = cate.CategoryID
			, LATERAL	
				(	SELECT cc.CategoryID, cc.LastScannedDate, cc.CreatedDate
					FROM CTS_DataCenter.CTSCustomerClassification AS cc 
						INNER JOIN CTS_DataCenter.CustomerCategory AS ca ON ca.CategoryID = cc.CategoryID
					WHERE cc.CustID = clss.CustID
						AND ca.IsActive = 1
						AND ca.ParentID <> CONST_PARENTID_WRAPPER 
					ORDER BY ca.CategoryPriority ASC, cc.LastModifiedDate DESC
					LIMIT 1
			    ) AS tmplc
		WHERE cate.CategoryID > lv_LastCategoryID
			AND tmplc.CategoryID = cate.CategoryID
			AND (tmplc.LastScannedDate IS NULL OR tmplc.LastScannedDate < lv_CurrentDate)
			AND (tmplc.CreatedDate < lv_ToLastDay)
		ORDER BY cate.CategoryID ASC
		LIMIT 1; 
     END IF;
     
     IF lv_NextCategoryID IS NOT NULL THEN
		INSERT IGNORE INTO Temp_Cust (CustID)
		SELECT 	tmplc.CustID
		FROM	CTS_DataCenter.CTSCustomerClassification AS clss
			,	LATERAL	
					(	SELECT cc.CustID, cc.CategoryID, ca.CategoryGroupID, cc.LastScannedDate, cc.CreatedDate 
						FROM CTS_DataCenter.CTSCustomerClassification AS cc 
							INNER JOIN CTS_DataCenter.CustomerCategory AS ca ON ca.CategoryID = cc.CategoryID
						WHERE cc.CustID = clss.CustID
							AND ca.IsActive = 1
							AND ca.ParentID <> CONST_PARENTID_WRAPPER 
						ORDER BY ca.CategoryPriority ASC, cc.LastModifiedDate DESC
						LIMIT 1
				   ) AS tmplc
		WHERE clss.CustID > 0
			AND clss.CategoryID = lv_NextCategoryID
			AND clss.ParentID = CONST_PARENTID_NORMAL
			AND tmplc.CategoryID = lv_NextCategoryID
			AND (tmplc.LastScannedDate IS NULL OR tmplc.LastScannedDate < lv_CurrentDate)
			AND (tmplc.CreatedDate < lv_ToLastDay)
		ORDER BY clss.CategoryID ASC
			,	 clss.CustID ASC
		LIMIT	lv_BatchSize;
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
    
    SELECT DISTINCT	tmp.CustID
    FROM Temp_Cust AS tmp;
    
END$$
DELIMITER ;