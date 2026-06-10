/*<info serverAlias="CTSMain-CTS_DataCenter" databaseType="2" executers="ctsWeb,ctsAPI,ctsService" isFunction="0" isNested="0"></info>*/
DROP PROCEDURE IF EXISTS `CTS_DC_CustClassification_ProblemAccount_FilterByB2C`;

DELIMITER $$
CREATE DEFINER=`ctsOwner`@`%` PROCEDURE `CTS_DC_CustClassification_ProblemAccount_FilterByB2C`(
	IN ip_CustIDs LONGTEXT
)
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
			-CALL CTS_DC_CustClassification_ProblemAccount_FilterByB2C("8,9,10");
	*/	
	DECLARE	CONST_PARENTID_PA 		INT;
        
    DROP TEMPORARY TABLE IF EXISTS Temp_Cust;    
	CREATE TEMPORARY TABLE Temp_Cust( 	  
			CustID		INT UNSIGNED	
        ,	PRIMARY	KEY (CustID)
	);
    
    SET CONST_PARENTID_PA			= CTS_DC_CategoryTypeParent_Get ('CONST_PARENTID_PA');
        
    SET @sql = 	CONCAT("INSERT IGNORE INTO Temp_Cust (CustID) VALUES ('", REPLACE(ip_CustIDs, ",", "'),('"),"');");
	PREPARE 	stmt1 FROM @sql;
	EXECUTE 	stmt1;
    
    SELECT 	cust.CustID
		,	CASE WHEN clss.ParentID = CONST_PARENTID_PA THEN GROUP_CONCAT(DISTINCT cate.AFCFraudID)
			ELSE NULL END AS FraudID 
    FROM Temp_Cust AS cust
		INNER JOIN CTS_DataCenter.CTSCustomerClassification AS clss ON clss.CustID = cust.CustID
        INNER JOIN CTS_DataCenter.CustomerCategory AS cate ON clss.CategoryID = cate.CategoryID 
	WHERE clss.SubscriberID IN (SELECT ItemID 
								FROM CTS_DataCenter.StaticList 
								WHERE ListID = 15)
	GROUP BY cust.CustID
		,	 clss.ParentID;
END$$
DELIMITER ;