/*<info serverAlias="CTSMain-CTS_DataCenter" databaseType="2" executers="ctsServiceAdmin" isFunction="0" isNested="0"></info>*/
DROP PROCEDURE IF EXISTS `CTS_DataCenter`.`CTS_DC_CustClassification_DailyScanPA_InsertToQueue`;

DELIMITER $$
CREATE DEFINER=`ctsOwner`@`%` PROCEDURE `CTS_DC_CustClassification_DailyScanPA_InsertToQueue`(
		IN ip_CustIDs 		TEXT
)
    SQL SECURITY INVOKER
BEGIN
	/*
		Created: 20220328@Aries.Nguyen
		Task: Insert problem accounts with new placebets to queue [Redmine ID: #184772]
		DB: CTS_DataCenter
        
		Original:
		Revisions:
			- 20230313@Jonas.Huynh: Created [Redmine ID: #184772]

		Param's Explanation (filtered by):      
				CALL CTS_DC_CustClassification_DailyScanPA_InsertToQueue ('123,455');
	*/
    
	SET @lv_CurrentDateTime	= NOW(); 
    
	DROP TEMPORARY TABLE IF EXISTS Temp_CustIDs;    
	CREATE TEMPORARY TABLE Temp_CustIDs( 	  
		CustID		BIGINT UNSIGNED PRIMARY KEY
	);

    SET @sql = CONCAT("INSERT INTO Temp_CustIDs (CustID) VALUES ('", REPLACE(ip_CustIDs, ",", "'),('"),"');");
	PREPARE stmt1 FROM @sql;
	EXECUTE stmt1;
    
    INSERT INTO CTS_DataCenter.CTSCustomerClassification_DailyPAQueue(CustID, CreatedTime)
	SELECT  CustID
        ,	@lv_CurrentDateTime
	FROM Temp_CustIDs;
    
END$$
DELIMITER ;