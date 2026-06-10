/*<info serverAlias="CTSMain-CTS_DataCenter" databaseType="2" executers="ctsWeb,ctsAPI,ctsService" isFunction="0" isNested="0"></info>*/
DROP PROCEDURE IF EXISTS `CTS_DC_CustClassification_ProblemAccount_GetB2CByBatch`;

DELIMITER $$
CREATE DEFINER=`ctsOwner`@`%` PROCEDURE `CTS_DC_CustClassification_ProblemAccount_GetB2CByBatch`()
    SQL SECURITY INVOKER
BEGIN
	/*
		Created:	20211130@Aries.Nguyen
		Task:		Scan PA to update info AFC
		DB:			CTS_DataCenter
		Original:

		Revisions:
			- 20211130@Aries.Nguyen: Created [Redmine: #164079]
            - 20240620@Jonas.Huynh:  Renovate CC [RedmineID: #205317]
		Param's Explanation (filtered by):   
        
        Example: 
			- CALL CTS_DC_CustClassification_ProblemAccount_GetB2CByBatch ();
	*/	 
    DECLARE	CONST_PARENTID_PA 		INT;
    DECLARE	CONST_PARENTID_WRAPPER	INT;
    
    DECLARE lv_LastCustID 			INT UNSIGNED;
    DECLARE lv_NextCustID 			INT UNSIGNED;
	DECLARE lv_BatchSize 			INT;
    DECLARE lv_CurrentSubID 		INT UNSIGNED;
    DECLARE lv_NextSubID 			INT UNSIGNED;

	SET CONST_PARENTID_PA			= CTS_DC_CategoryTypeParent_Get ('CONST_PARENTID_PA');
	SET CONST_PARENTID_WRAPPER		= CTS_DC_CategoryTypeParent_Get ('CONST_PARENTID_WRAPPER');
    
	DROP TEMPORARY TABLE IF EXISTS Temp_ProblemAccount;
    CREATE TEMPORARY TABLE Temp_ProblemAccount (
			CustID 		INT  UNSIGNED PRIMARY KEY
    );
    
    DROP TEMPORARY TABLE IF EXISTS Temp_Cust;
    CREATE TEMPORARY TABLE Temp_Cust (
			CustID 		INT  UNSIGNED 
		,	FraudID		int
        ,	PRIMARY KEY(CustID, FraudID)
    );
	
    SELECT ParameterValue
	INTO lv_LastCustID
	FROM CTS_DataCenter.SystemParameter 
	WHERE ParameterID = 64; 
    
    SELECT ParameterValue
	INTO lv_CurrentSubID
	FROM CTS_DataCenter.SystemParameter 
	WHERE ParameterID = 65;
    
	SELECT ParameterValue
	INTO lv_BatchSize
	FROM CTS_DataCenter.SystemParameter 
	WHERE ParameterID = 66;
    
    INSERT IGNORE INTO Temp_ProblemAccount(CustID)
	SELECT DISTINCT clss.CustID
	FROM CTS_DataCenter.CTSCustomerClassification AS clss
		, LATERAL	
		  (		SELECT cc.CustID, ca.ParentID
				FROM CTS_DataCenter.CTSCustomerClassification AS cc 
					INNER JOIN CTS_DataCenter.CustomerCategory AS ca ON ca.CategoryID = cc.CategoryID
				WHERE cc.CustID = clss.CustID
					AND ca.IsActive = 1
					AND ca.ParentID <> CONST_PARENTID_WRAPPER
				ORDER BY ca.CategoryPriority ASC, cc.LastModifiedDate DESC
				LIMIT 1
		   ) AS tmplc
	WHERE clss.CustID > lv_LastCustID
		AND clss.ParentID = CONST_PARENTID_PA
        AND clss.SubscriberID = lv_CurrentSubID
        AND tmplc.CustID = clss.CustID
        AND tmplc.ParentID = CONST_PARENTID_PA
        AND EXISTS (SELECT 1 
					FROM CTS_DataCenter.CTSCustomerClassification AS cc 
						INNER JOIN CTS_DataCenter.CustomerCategory AS ca ON cc.CustID = tmplc.CustID
					WHERE clss.ParentID = CONST_PARENTID_PA
						AND ca.AFCFraudID IS NOT NULL)
	ORDER BY clss.CustID ASC
	LIMIT lv_BatchSize;
        
	INSERT IGNORE INTO Temp_Cust(CustID, FraudID)
	SELECT DISTINCT pa.CustID, ca.AFCFraudID
	FROM Temp_ProblemAccount AS pa
		INNER JOIN CTS_DataCenter.CTSCustomerClassification AS clss ON clss.CustID = pa.CustID
        INNER JOIN CTS_DataCenter.CustomerCategory AS ca ON ca.CategoryID = clss.CategoryID
	WHERE clss.ParentID = CONST_PARENTID_PA
		AND ca.AFCFraudID IS NOT NULL;
    
    IF NOT EXISTS (SELECT 1 FROM Temp_Cust) THEN
		SELECT ItemID
        INTO lv_NextSubID
		FROM CTS_DataCenter.StaticList  AS sub
			INNER JOIN CTS_DataCenter.CTSCustomerClassification AS clss ON sub.ItemID = clss.SubscriberID AND clss.ParentID = CONST_PARENTID_PA
			, LATERAL	
			  (		SELECT cc.CustID, ca.ParentID, cc.SubscriberID
					FROM CTS_DataCenter.CTSCustomerClassification AS cc 
						INNER JOIN CTS_DataCenter.CustomerCategory AS ca ON ca.CategoryID = cc.CategoryID
					WHERE cc.CustID = clss.CustID
						AND ca.IsActive = 1
						AND ca.ParentID <> CONST_PARENTID_WRAPPER
					ORDER BY ca.CategoryPriority ASC, cc.LastModifiedDate DESC
					LIMIT 1
			   ) AS tmplc
		WHERE ListID = 15 
			AND ItemID > lv_CurrentSubID
			AND tmplc.ParentID = CONST_PARENTID_PA
            AND tmplc.SubscriberID = sub.ItemID
			AND EXISTS (SELECT 1 
						FROM CTS_DataCenter.CTSCustomerClassification AS cc 
							INNER JOIN CTS_DataCenter.CustomerCategory AS ca ON cc.CustID = tmplc.CustID
						WHERE clss.ParentID = CONST_PARENTID_PA	
							AND ca.AFCFraudID IS NOT NULL)
		ORDER BY ItemID ASC
		LIMIT 1;
    END IF;
    
	IF lv_NextSubID IS NOT NULL THEN
		TRUNCATE Temp_ProblemAccount;
        
		INSERT IGNORE INTO Temp_ProblemAccount(CustID)
		SELECT DISTINCT clss.CustID
		FROM CTS_DataCenter.CTSCustomerClassification AS clss
			, LATERAL	
			  (		SELECT cc.CustID, ca.ParentID
					FROM CTS_DataCenter.CTSCustomerClassification AS cc 
						INNER JOIN CTS_DataCenter.CustomerCategory AS ca ON ca.CategoryID = cc.CategoryID
					WHERE cc.CustID = clss.CustID
						AND ca.IsActive = 1
						AND ca.ParentID <> CONST_PARENTID_WRAPPER
					ORDER BY ca.CategoryPriority ASC, cc.LastModifiedDate DESC
					LIMIT 1
			   ) AS tmplc
		WHERE clss.CustID > 0
			AND clss.ParentID = CONST_PARENTID_PA
			AND clss.SubscriberID = lv_NextSubID
            AND tmplc.CustID = clss.CustID
			AND tmplc.ParentID = CONST_PARENTID_PA
			AND EXISTS (SELECT 1 
						FROM CTS_DataCenter.CTSCustomerClassification AS cc 
							INNER JOIN CTS_DataCenter.CustomerCategory AS ca ON cc.CustID = tmplc.CustID
						WHERE clss.ParentID = CONST_PARENTID_PA	
							AND ca.AFCFraudID IS NOT NULL)
		ORDER BY clss.CustID ASC
		LIMIT lv_BatchSize;
			
		INSERT IGNORE INTO Temp_Cust(CustID, FraudID)
		SELECT DISTINCT pa.CustID, ca.AFCFraudID
		FROM Temp_ProblemAccount AS pa
			INNER JOIN CTS_DataCenter.CTSCustomerClassification AS clss ON clss.CustID = pa.CustID
			INNER JOIN CTS_DataCenter.CustomerCategory AS ca ON ca.CategoryID = clss.CategoryID
		WHERE clss.ParentID = CONST_PARENTID_PA
			AND ca.AFCFraudID IS NOT NULL;
	ELSE
		SET lv_NextSubID = lv_CurrentSubID;
 	END IF;
    
    SELECT MAX(CustID)
    INTO lv_NextCustID
    FROM Temp_Cust;
		
    IF lv_NextCustID IS NOT NULL THEN        
		UPDATE CTS_DataCenter.SystemParameter 
        SET ParameterValue = lv_NextCustID
		WHERE ParameterID = 64;
        
        UPDATE CTS_DataCenter.SystemParameter 
        SET ParameterValue = lv_NextSubID
		WHERE ParameterID = 65;
	ELSE 
		SELECT ItemID
        INTO lv_NextSubID
		FROM CTS_DataCenter.StaticList 
		WHERE ListID = 15 
		ORDER BY ItemID ASC 
		LIMIT 1;
        
		UPDATE CTS_DataCenter.SystemParameter 
        SET ParameterValue = 0
		WHERE ParameterID = 64;
        
        UPDATE CTS_DataCenter.SystemParameter 
        SET ParameterValue = lv_NextSubID
		WHERE ParameterID = 65;
    END IF;
    
    SELECT 	CustID
		,	GROUP_CONCAT(FraudID) AS FraudID
    FROM Temp_Cust
    GROUP BY CustID;
    
END$$
DELIMITER ;