/*<info serverAlias="CTSMain-CTS_DataCenter" databaseType="2" executers="ctsServiceAdmin" isFunction="0" isNested="0"></info>*/
DROP PROCEDURE IF EXISTS `CTS_DC_Adhoc_CorrectInactiveCategory`;

DELIMITER $$
CREATE DEFINER=`ctsOwner`@`%` PROCEDURE `CTS_DC_Adhoc_CorrectInactiveCategory`()
    SQL SECURITY INVOKER
sp: BEGIN
	/*
		Created:	20241225@Jonas.Huynh	
		Task :		HF - Correct Inactive Category
		DB:			CTS_DataCenter
		Original:

		Revisions:
			- 20241225@Jonas.Huynh: Created [Redmine ID: #215615]
            
		Param's Explanation (filtered by):	

		Example: call CTS_DC_Adhoc_CorrectInactiveCategory();
			
	*/
	DROP TEMPORARY TABLE IF EXISTS Temp_Customers;    
	CREATE TEMPORARY TABLE Temp_Customers (          
				CustID     		BIGINT UNSIGNED PRIMARY KEY
	 );
	 
	DROP TEMPORARY TABLE IF EXISTS Temp_CustomersByBatch;    
	CREATE TEMPORARY TABLE Temp_CustomersByBatch (          
				CustID     		BIGINT UNSIGNED PRIMARY KEY
			,   OldCategoryID  	INT NULL
	 );
	 
     
	INSERT INTO Temp_Customers(CustID)
	SELECT adh.CustID 
	FROM CTS_DataCenter.Adhoc_CC_Inactive_Incorrect AS adh
		INNER JOIN CTS_DataCenter.CTSCustomerClassification AS cc ON cc.CustID = adh.CustID
	WHERE cc.CategoryID = 40700
		AND cc.ParentID = 40000;

	WHILE EXISTS (SELECT 1 FROM Temp_Customers)
	DO
		TRUNCATE TABLE Temp_CustomersByBatch;
		
		INSERT INTO Temp_CustomersByBatch(CustID)
		SELECT CustID
		FROM Temp_Customers
		LIMIT 5000;
		
		UPDATE Temp_CustomersByBatch AS adh
			, LATERAL (
				SELECT 	h.CustID
					,  	h.CategoryID
					, 	h.OldCategoryID AS FromCategoryID
					, 	h.DWCategoryID AS ToCategoryID
				FROM CTSCustomerClassification_History AS h
				WHERE h.CustID = adh.CustID
					AND h.ParentID <> 10000
				ORDER BY h.ID DESC
				LIMIT 1
			) AS h
		SET adh.OldCategoryID = h.FromCategoryID
		WHERE adh.CustID = h.CustID
			AND h.CategoryID = 40700
			AND h.ToCategoryID = 40700
			AND h.FromCategoryID IN (40400,40401,40402,40403,40404,40405,40406,40500,40501,40502,40503,40504,40505,40506,40600,40601,40602,40603,40604,40605,40606);
			
		UPDATE CTS_DataCenter.CTSCustomerClassification AS cc
			INNER JOIN Temp_CustomersByBatch AS b ON b.CustID = cc.CustID AND cc.CategoryID = 40700
			INNER JOIN CTS_DataCenter.CustomerCategory AS cate ON cate.CategoryID = b.OldCategoryID
		SET 	cc.CategoryID = b.OldCategoryID
			,	cc.ParentID = cate.ParentID;
		
        DELETE t
        FROM Temp_Customers AS t
            INNER JOIN Temp_CustomersByBatch AS a ON t.CustID = a.CustID;
            
        DO SLEEP(0.1);
	END WHILE;
END$$
DELIMITER ;