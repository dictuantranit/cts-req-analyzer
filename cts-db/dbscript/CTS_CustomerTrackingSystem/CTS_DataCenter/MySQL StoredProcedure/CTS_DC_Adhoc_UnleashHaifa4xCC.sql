/*<info serverAlias="CTSMain-CTS_DataCenter" databaseType="2" executers="ctsServiceAdmin" isFunction="0" isNested="0"></info>*/
DROP PROCEDURE IF EXISTS `CTS_DC_Adhoc_UnleashHaifa4xCC`;

DELIMITER $$
CREATE DEFINER=`ctsOwner`@`%` PROCEDURE `CTS_DC_Adhoc_UnleashHaifa4xCC`(
)
BEGIN
	/*
		Created:	20220409@Long.Luu	
		Task :		Unleash Haifa 4x CC
		DB:			CTS_DataCenter
		Original: 
		Revisions:
			- 20220409@Long.Luu: Created [Redmine ID: #0000]
            
		Param's Explanation:
	*/ 
    DROP TEMPORARY TABLE IF EXISTS Temp_4xCCCust;
	CREATE TEMPORARY TABLE Temp_4xCCCust (
			CustID		BIGINT UNSIGNED PRIMARY KEY
	);

	DROP TEMPORARY TABLE IF EXISTS Temp_PA4xCCCust;
	CREATE TEMPORARY TABLE Temp_PA4xCCCust (
			CustID		BIGINT UNSIGNED PRIMARY KEY
	);

	# Get Cust with CC 4x
	INSERT INTO Temp_4xCCCust (CustID)
	SELECT DISTINCT CustID
	FROM CTS_DataCenter.SpecialCustomerClass
	WHERE CustomerClass IN (41,42,43,44,45,46,47,48,49,2500,2503,2504,2505);

	# Check whether Cust are PA or not
	INSERT INTO Temp_PA4xCCCust (CustID)
	SELECT DISTINCT t.CustID
	FROM Temp_4xCCCust AS t
		INNER JOIN CTSCustomerClassification AS c ON t.CustID = c.CustID
	WHERE c.SportGroupID = 0
		AND c.CategoryID < 200;

	# Log Rescan to History
	INSERT INTO CTSCustomerClassification_History(CustID,CTSCustID,TargetCC,SourceTypeID,IsAppliedCC,IsDataChanged,ActionType,IsAuto,LastModifiedDate,LastModifiedBy,InsertDate,TaggingType)
	SELECT t.CustID,c.CTSCustID,-1,12,1,1,2,0,NOW(),10278938,NOW(),1
	FROM Temp_PA4xCCCust AS t
		INNER JOIN CTSCustomer AS c ON t.CustID = c.CustID;
		
	# Remove PA from SpecialCC
	DELETE s
	FROM Temp_PA4xCCCust AS t 
		INNER JOIN CTS_DataCenter.SpecialCustomerClass AS s ON s.CustID = t.CustID
	WHERE CustomerClass IN (41,42,43,44,45,46,47,48,49,2500,2503,2504,2505);

	# Results
    INSERT INTO Adhoc_Haifa4xCCUnleashed(CustID, Username,CreatedDate,CreatedTime)
	SELECT c.CustID, c.UserName, NOW(), NOW()
	FROM Temp_PA4xCCCust AS t 
		INNER JOIN CTSCustomer AS c ON t.CustID = c.CustID;  
END$$
DELIMITER ;