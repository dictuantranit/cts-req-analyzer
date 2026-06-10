/*<info serverAlias="CTSMain-CTS_DataCenter" databaseType="2" executers="ctsService" isFunction="0" isNested="0"></info>*/
DROP PROCEDURE IF EXISTS `CTS_DataCenter`.`CTS_DC_CustClassificationAgency_DailyScan_GetCateNew`;

DELIMITER $$
CREATE DEFINER=`ctsOwner`@`%` PROCEDURE `CTS_DC_CustClassificationAgency_DailyScan_GetCateNew`(
		OUT op_LastCategoryID 	INT 
	,	OUT op_LastCustID 		BIGINT UNSIGNED 
)
    SQL SECURITY INVOKER
sp:BEGIN
/*
		Created:	20241010@Adam.Tran
		Task:		Agency CC get new category for Scanning inactive [Redmine ID: #185799]
		DB:			CTS_DataCenter
		Original:
		Revisions:
			- 20241010@Adam.Tran: Created [Redmine ID: #185799]	
		
        Param's Explanation (filtered by):
		Example: 
			- CALL CTS_DC_CustClassificationAgency_DailyScan_GetCateNew (@op_LastCategoryID, @op_LastCustID);
	*/   
    
    DECLARE	CONST_AGENCY_CATEGROUPID_NEW			INT;
    
	DECLARE lv_LastCategoryID 				INT;
	DECLARE lv_LastCustID 					BIGINT UNSIGNED;
    DECLARE lv_BatchSize 					BIGINT;

    DECLARE lv_NextCategoryID 				INT;
    DECLARE lv_NextCustID 					BIGINT UNSIGNED;
	DECLARE lv_ScanDateValid 				DATE DEFAULT DATE_SUB(CURRENT_DATE(), INTERVAL 29 DAY);

	SET CONST_AGENCY_CATEGROUPID_NEW 				= CTS_DC_CategoryTypeParent_Get ('CONST_AGENCY_CATEGROUPID_NEW');

    DROP TEMPORARY TABLE IF EXISTS Temp_Category;
	CREATE TEMPORARY TABLE Temp_Category(
			CategoryID				INT PRIMARY KEY 	
	);
    
    DROP TEMPORARY TABLE IF EXISTS Temp_InactiveNewAgency;
    CREATE TEMPORARY TABLE 	Temp_InactiveNewAgency (
			CustID 			BIGINT UNSIGNED PRIMARY KEY
	);
    
    INSERT INTO Temp_Category(CategoryID)
    SELECT ca.CategoryID
	FROM CTS_DataCenter.CustomerCategoryAgency AS ca
	WHERE ca.CategoryGroupID = CONST_AGENCY_CATEGROUPID_NEW 
		AND ca.IsActive = 1;
  
    SELECT ParameterValue 
    INTO lv_BatchSize 
    FROM CTS_DataCenter.SystemParameter 
    WHERE ParameterID = 178;
    
    SELECT ParameterValue 
    INTO lv_LastCategoryID 
    FROM CTS_DataCenter.SystemParameter 
    WHERE ParameterID = 179;
    
    SELECT ParameterValue 
    INTO lv_LastCustID 
    FROM CTS_DataCenter.SystemParameter 
    WHERE ParameterID = 180;
    
    IF lv_LastCategoryID IS NULL OR  lv_LastCategoryID = 0 THEN
		SELECT CategoryID 
		INTO lv_LastCategoryID 
		FROM Temp_Category
		ORDER BY CategoryID ASC
        LIMIT 1;
	END  IF;
	
    INSERT IGNORE INTO Temp_InactiveNewAgency (CustID)
	SELECT 	tmplc.CustID
	FROM CTS_DataCenter.CTSCustomerClassificationAgency AS clss USE INDEX(IX_CTSCCAgency_CategoryID_CustID_LastScannedDate)
		,	LATERAL	
			(	SELECT cc.CustID, cc.CategoryID
				FROM CTS_DataCenter.CTSCustomerClassificationAgency AS cc 
					INNER JOIN CTS_DataCenter.CustomerCategoryAgency AS ca ON ca.CategoryID = cc.CategoryID
				WHERE cc.CustID = clss.CustID
					AND ca.IsActive = 1				  
				ORDER BY ca.CategoryPriority ASC, cc.LastModifiedDate DESC
				LIMIT 1
			) AS tmplc 
	WHERE clss.CustID > lv_LastCustID
		AND clss.CategoryID = lv_LastCategoryID
		AND clss.CreatedDate <= lv_ScanDateValid
		AND tmplc.CategoryID = lv_LastCategoryID
		AND NOT EXISTS (SELECT 1 
						FROM  CTS_Archive.CTSCustomerAssociationStatus AS ticket 
						WHERE ticket.CTSCustID = clss.CTSCustID
							AND IFNULL(ticket.LastTicketDate, ticket.Created) > lv_ScanDateValid)
	ORDER BY clss.CategoryID ASC
		,	 clss.CustID ASC
	LIMIT lv_BatchSize;
        
    IF NOT EXISTS (SELECT 1 FROM Temp_InactiveNewAgency) THEN
		SELECT 	tmplc.CategoryID
        INTO 	lv_NextCategoryID
		FROM Temp_Category  AS cate
			INNER JOIN CTS_DataCenter.CTSCustomerClassificationAgency AS clss ON clss.CategoryID = cate.CategoryID
			,	LATERAL	
				(	SELECT cc.CTSCustID, cc.CustID, cc.CategoryID, cc.CreatedDate
					FROM CTS_DataCenter.CTSCustomerClassificationAgency AS cc 
						INNER JOIN CTS_DataCenter.CustomerCategoryAgency AS ca ON ca.CategoryID = cc.CategoryID
					WHERE cc.CustID = clss.CustID
						AND ca.IsActive = 1
					ORDER BY ca.CategoryPriority ASC, cc.LastModifiedDate DESC
					LIMIT 1
				) AS tmplc
		WHERE cate.CategoryID > lv_LastCategoryID
			AND tmplc.CategoryID = cate.CategoryID
			AND tmplc.CreatedDate <= lv_ScanDateValid
            AND NOT EXISTS (SELECT 1 
							FROM  CTS_Archive.CTSCustomerAssociationStatus AS ticket 
							WHERE ticket.CTSCustID = tmplc.CTSCustID
								AND IFNULL(ticket.LastTicketDate, ticket.Created) > lv_ScanDateValid)
		ORDER BY cate.CategoryID ASC
		LIMIT 1; 
    END IF;
    
    IF lv_NextCategoryID IS NOT NULL THEN
		INSERT IGNORE INTO Temp_InactiveNewAgency (CustID)
		SELECT 	tmplc.CustID
		FROM CTS_DataCenter.CTSCustomerClassificationAgency AS clss USE INDEX(IX_CTSCCAgency_CategoryID_CustID_LastScannedDate)
			,	LATERAL	
				(	SELECT cc.CustID, cc.CategoryID
					FROM CTS_DataCenter.CTSCustomerClassificationAgency AS cc 
						INNER JOIN CTS_DataCenter.CustomerCategoryAgency AS ca ON ca.CategoryID = cc.CategoryID
					WHERE cc.CustID = clss.CustID
						AND ca.IsActive = 1                       
					ORDER BY ca.CategoryPriority ASC, cc.LastModifiedDate DESC
					LIMIT 1
			   ) AS tmplc 
		WHERE clss.CustID > 0
			AND clss.CategoryID = lv_NextCategoryID
			AND clss.CreatedDate <= lv_ScanDateValid
            AND tmplc.CategoryID = lv_NextCategoryID
			AND NOT EXISTS (SELECT 1 
							FROM  CTS_Archive.CTSCustomerAssociationStatus AS ticket 
							WHERE ticket.CTSCustID = clss.CTSCustID
								AND IFNULL(ticket.LastTicketDate, ticket.Created) > lv_ScanDateValid)
		ORDER BY clss.CategoryID ASC
			,	 clss.CustID ASC
		LIMIT lv_BatchSize;
        
	ELSE
		SET lv_NextCategoryID = lv_LastCategoryID;
	END IF;
    
    SELECT MAX(CustID)
    INTO lv_NextCustID
    FROM Temp_InactiveNewAgency;
    
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
    
    SELECT 	CustID
    FROM Temp_InactiveNewAgency;
END$$
DELIMITER ;