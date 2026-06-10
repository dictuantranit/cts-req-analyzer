/*<info serverAlias="CTSMain-CTS_DataCenter" databaseType="2" executers="ctsWeb" isFunction="0" isNested="0"></info>*/
DROP PROCEDURE IF EXISTS `CTS_DC_CustClassification_GetCategoryByCustIDs`;

DELIMITER $$
CREATE DEFINER=`ctsOwner`@`%` PROCEDURE `CTS_DC_CustClassification_GetCategoryByCustIDs`(
	IN ip_CustIDs TEXT
)
	SQL SECURITY INVOKER
BEGIN
	/*
		Created:	20240820@Long.Luu	
		Task :		Get Customer Category by List CustID
		DB:			CTS_DataCenter
		Original: 

		Revisions:
			- 20240820@Long.Luu: 			Created [Redmine ID: #209403]
			- 20240822@Victoria.Le: 		Renovate CC phase 2 [Redmine ID: #205317]
            - 20241016@Thomas.Nguyen: 		Agent CC [Redmine ID: #185799]

		Param's Explanation:

		Example:  
			- CALL CTS_DataCenter.CTS_DC_CustClassification_GetCategoryByCustIDs("1,2,3");
	*/ 
	DECLARE CONST_PARENTID_WRAPPER 				INT;
	
	SET CONST_PARENTID_WRAPPER 					= CTS_DC_CategoryTypeParent_Get ('CONST_PARENTID_WRAPPER');

	DROP TEMPORARY TABLE IF EXISTS Temp_InputCustomers;
    CREATE TEMPORARY TABLE 		Temp_InputCustomers (
			CustID              BIGINT UNSIGNED PRIMARY KEY
    );  
    
	DROP TEMPORARY TABLE IF EXISTS Temp_CustCategory;
    CREATE TEMPORARY TABLE 		Temp_CustCategory (
			CustID              BIGINT UNSIGNED
		,	CategoryID			INT UNSIGNED
		,	CustomerClass		INT UNSIGNED
		,	CreatedDate			DATETIME
		,	PRIMARY KEY (CustID, CategoryID)
    );

    /* 1. Insert CustIDs */
	SET @sql = 	CONCAT("INSERT IGNORE INTO Temp_InputCustomers (CustID) VALUES ('", REPLACE(ip_CustIDs, ",", "'),('"),"');");
	PREPARE stmt1 FROM @sql;
	EXECUTE stmt1;    
    
	DROP TEMPORARY TABLE IF EXISTS Temp_InputCustomers_Dup;
	CREATE TEMPORARY TABLE Temp_InputCustomers_Dup LIKE Temp_InputCustomers;
	INSERT INTO Temp_InputCustomers_Dup 
	SELECT CustID FROM Temp_InputCustomers;

	INSERT IGNORE INTO Temp_CustCategory(CustID, CategoryID, CustomerClass, CreatedDate)
	WITH CTE AS
	(

		SELECT b.CustID, b.CategoryID, b.CreatedDate
		FROM Temp_InputCustomers AS a
			 INNER JOIN CTS_DataCenter.CTSCustomerClassification AS b ON a.CustID = b.CustID
		WHERE b.ParentID = CONST_PARENTID_WRAPPER
		UNION
		SELECT b.CustID, b.CategoryID, b.CreatedDate
		FROM Temp_InputCustomers_Dup AS a
			INNER JOIN CTS_DataCenter.CTSCustomerClassification AS b ON a.CustID = b.CustID
			,	LATERAL (
					SELECT cls.ParentID
					FROM CTS_DataCenter.CTSCustomerClassification AS cls
						INNER JOIN CTS_DataCenter.CustomerCategory AS cat ON cat.CategoryID = cls.CategoryID AND cat.IsActive = 1
					WHERE cls.CustID = b.CustID AND cls.ParentID <> CONST_PARENTID_WRAPPER
					ORDER BY cat.CategoryPriority ASC, cls.LastModifiedDate DESC
					LIMIT 1
				) AS ltr
		WHERE b.ParentID = ltr.ParentID
	)
	SELECT c.CustID, cat.OldCategoryID AS CategoryID, cat.CustomerClass, c.CreatedDate
	FROM CTE AS c
		INNER JOIN CTS_DataCenter.CustomerCategory AS cat ON cat.CategoryID = c.CategoryID
	WHERE cat.IsActive = 1
		AND cat.CustomerClass IS NOT NULL;

	/*For Agency*/
	INSERT IGNORE INTO Temp_CustCategory(CustID, CategoryID, CustomerClass, CreatedDate)
	WITH CTE_Agency AS
	(
		SELECT b.CustID, b.CategoryID, b.CreatedDate
		FROM Temp_InputCustomers_Dup AS a
			INNER JOIN CTS_DataCenter.CTSCustomerClassificationAgency AS b ON a.CustID = b.CustID
			,	LATERAL (
					SELECT cls.ParentID
					FROM CTS_DataCenter.CTSCustomerClassificationAgency AS cls
						INNER JOIN CTS_DataCenter.CustomerCategoryAgency AS cat ON cat.CategoryID = cls.CategoryID AND cat.IsActive = 1
					WHERE cls.CustID = b.CustID
					ORDER BY cat.CategoryPriority ASC
					LIMIT 1
				) AS ltr
		WHERE b.ParentID = ltr.ParentID
	)
	SELECT c.CustID, cat.CategoryID AS CategoryID, cat.CustomerClass, c.CreatedDate
	FROM CTE_Agency AS c
		INNER JOIN CTS_DataCenter.CustomerCategoryAgency AS cat ON cat.CategoryID = c.CategoryID
	WHERE cat.IsActive = 1
		AND cat.CustomerClass IS NOT NULL;

	SELECT	CustID
		,	CategoryID
		,	CustomerClass
		,	CreatedDate
	FROM Temp_CustCategory;

END$$

DELIMITER ;
