/*<info serverAlias="CTSMain-CTS_DataCenter" databaseType="2" executers="ctsWeb" isFunction="0" isNested="0"></info>*/
DROP PROCEDURE IF EXISTS `CTS_DC_CustClassification_GetAllByCategory`;

DELIMITER $$
CREATE DEFINER=`ctsOwner`@`%` PROCEDURE `CTS_DC_CustClassification_GetAllByCategory`(
		IN ip_CategoryIDList 	VARCHAR(200)
)
	SQL SECURITY INVOKER
BEGIN
	/*
		Created:	20200924@Long.Luu	
		Task :		Get All Customers by Category
		DB:			CTS_DataCenter
		Original: 
		Revisions:
			- 20200924@Long.Luu: Created [Redmine ID: #141755]
            - 20201202@Lex.Khuat: Hotfix remove sportgroup, no use sportgroup table [Redmine ID: #146819]
			- 20210622@Aries.Nguyen: Update coding convention  [Redmine ID: #157203]
            - 20240628@Thomas.Nguyen: Renovate CC phase 2 - Change datatype for CategoryID to INT [Redmine ID: #205317]
			- 20241017@Casey.Huynh: Get Agency Category [Redmine ID: #185799]
            
		Param's Explanation:

		Example:
			- CALL CTS_DC_CustClassification_GetAllByCategory('101010,1010');
	*/ 

    DROP TEMPORARY TABLE IF EXISTS Temp_CategoryID;
    CREATE TEMPORARY TABLE Temp_CategoryID (
		CategoryID	INT UNSIGNED PRIMARY KEY
    );  
    
    DROP TEMPORARY TABLE IF EXISTS Temp_MemberCategory;
    CREATE TEMPORARY TABLE Temp_MemberCategory (
		CategoryID	INT UNSIGNED PRIMARY KEY
    ); 
    
	DROP TEMPORARY TABLE IF EXISTS Temp_AgencyCategory;
    CREATE TEMPORARY TABLE Temp_AgencyCategory (
		CategoryID	INT UNSIGNED PRIMARY KEY
    ); 
    
    SET @sql = CONCAT("INSERT INTO Temp_CategoryID (CategoryID) VALUES ('", REPLACE(ip_CategoryIDList, ",", "'),('"),"');");
	PREPARE stmt1 FROM @sql;
	EXECUTE stmt1;
    
    INSERT INTO Temp_MemberCategory(CategoryID)
    SELECT tmp.CategoryID 
    FROM Temp_CategoryID AS tmp
		INNER JOIN CTS_DataCenter.CustomerCategory AS cca ON cca.CategoryID = tmp.CategoryID;
        
	INSERT INTO Temp_AgencyCategory(CategoryID)
    SELECT tmp.CategoryID 
    FROM Temp_CategoryID AS tmp
		INNER JOIN CTS_DataCenter.CustomerCategoryAgency AS cca ON cca.CategoryID = tmp.CategoryID;    
    
    
    SELECT DISTINCT tmp.CustID, tmp.CategoryID, tmp.CategoryName
    FROM (
			SELECT DISTINCT c.CustID
				,	c.CategoryID
				,	a.CategoryName
			FROM Temp_MemberCategory AS t
				INNER JOIN CTS_DataCenter.CustomerCategory AS a ON t.CategoryID = a.CategoryID
				INNER JOIN CTS_DataCenter.CTSCustomerClassification AS c ON t.CategoryID = c.CategoryID
			WHERE a.IsActive = 1    
			UNION
			SELECT DISTINCT c.CustID
				,	c.CategoryID
				,	a.CategoryName
			FROM Temp_AgencyCategory AS t
				INNER JOIN CTS_DataCenter.CustomerCategoryAgency AS a ON t.CategoryID = a.CategoryID
				INNER JOIN CTS_DataCenter.CTSCustomerClassificationAgency AS c ON t.CategoryID = c.CategoryID
			WHERE a.IsActive = 1
            ) tmp
	ORDER BY tmp.CustID ASC; 
    
END$$
DELIMITER ;
