/*<info serverAlias="CTSMain-CTS_DataCenter" databaseType="2" executers="ctsAPI" isFunction="0" isNested="0"></info>*/
DROP PROCEDURE IF EXISTS `CTS_DC_CustClassification_GetRiskLevelByAccount`;
DELIMITER $$
CREATE DEFINER=`ctsOwner`@`%` PROCEDURE `CTS_DC_CustClassification_GetRiskLevelByAccount`(
		IN ip_AccountIDList	LONGTEXT
)
    SQL SECURITY INVOKER
BEGIN
	/*
		Created:	20240819@Casey.Huynh	
		Task :		Get the latest Risk Level By Account 
		DB:			CTS_DataCenter
		Original: 
		Revisions:
			- 20240819@Casey.Huynh: Created [RedmineID: #209435]
            - 20240822@Thomas.Nguyen: Renovate CC phase 2 [Redmine ID: #205317]

        Param's Explanation:     
        Example:
			CALL CTS_DC_CustClassification_GetRiskLevelByAccount('1002,8652,17198,24,20896,20934,20939');
	*/      
	
	DROP TEMPORARY TABLE IF EXISTS Temp_AccountID;    
    CREATE TEMPORARY TABLE Temp_AccountID(
			AccountID	BIGINT UNSIGNED PRIMARY KEY
	);          
    
    DROP TEMPORARY TABLE IF EXISTS Temp_CustDCSAccount;    
    CREATE TEMPORARY TABLE Temp_CustDCSAccount(
			CTSCustID 	BIGINT UNSIGNED	
		,	AccountID	BIGINT UNSIGNED
        
        ,	PRIMARY KEY PK_Temp_CustDCSAccount(CTSCustID, AccountID)
	);     
    
    SET @sql = CONCAT("INSERT IGNORE INTO Temp_AccountID(AccountID) VALUES ('", REPLACE(ip_AccountIDList, ",", "'),('"),"');");
	PREPARE stmt1 FROM @sql;
	EXECUTE stmt1;
    
    INSERT INTO Temp_CustDCSAccount (CTSCustID, AccountID)
	SELECT cda.CTSCustID, cda.AccountID
	FROM Temp_AccountID AS tmp
		INNER JOIN CTS_DataCenter.CustDCSAccount AS cda ON tmp.AccountID = cda.AccountID;    
	
    SELECT  tmp.AccountID
        ,	ltr.Ext_SabaIntelligentRiskLevel AS RiskLevel
    FROM 	Temp_CustDCSAccount AS tmp
		,	LATERAL(SELECT cat.CategoryName, cat.CustomerClassName, cat.CustomerClass, cat.Ext_SabaIntelligentRiskLevel, cls.LastModifiedDate
					FROM CTS_DataCenter.CTSCustomerClassification AS cls
						INNER JOIN CTS_DataCenter.CustomerCategory AS cat ON cls.CategoryID = cat.CategoryID 
																				AND cat.IsActive = 1 AND cat.CustomerClass IS NOT NULL
					WHERE cls.CTSCustID = tmp.CTSCustID
					ORDER BY cat.CustomerClassPriority ASC, cls.LastModifiedDate DESC	
					LIMIT 1) AS ltr;
    
END$$
DELIMITER ;
