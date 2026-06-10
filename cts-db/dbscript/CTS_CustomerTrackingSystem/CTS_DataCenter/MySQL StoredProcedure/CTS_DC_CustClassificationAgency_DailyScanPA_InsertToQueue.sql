/*<info serverAlias="CTSMain-CTS_DataCenter" databaseType="2" executers="ctsServiceAdmin" isFunction="0" isNested="0"></info>*/
DROP PROCEDURE IF EXISTS `CTS_DataCenter`.`CTS_DC_CustClassificationAgency_DailyScanPA_InsertToQueue`;

DELIMITER $$
CREATE DEFINER=`ctsOwner`@`%` PROCEDURE `CTS_DC_CustClassificationAgency_DailyScanPA_InsertToQueue`(
		IN ip_CustIDs 		TEXT
)
    SQL SECURITY INVOKER
BEGIN
	/*
		Created: 20250228@Thomas.Nguyen
		Task:
		DB: CTS_DataCenter
        
		Original:
		Revisions:
			- 20250228@Thomas.Nguyen: Created [Redmine ID: #218588]

		Param's Explanation (filtered by):      
				CALL CTS_DC_CustClassificationAgency_DailyScanPA_InsertToQueue ('123,455');
	*/
    
	DECLARE lv_CurrentDateTime			DATETIME DEFAULT NOW();
    
	DROP TEMPORARY TABLE IF EXISTS Temp_CustID;    
	CREATE TEMPORARY TABLE Temp_CustID( 	  
		CustID		BIGINT UNSIGNED PRIMARY KEY
	);

    SET @sql = CONCAT("INSERT INTO Temp_CustID (CustID) VALUES ('", REPLACE(ip_CustIDs, ",", "'),('"),"');");
	PREPARE stmt1 FROM @sql;
	EXECUTE stmt1;
    
    INSERT INTO CTS_DataCenter.CTSCustomerClassificationAgency_DailyPAQueue(CustID, CreatedTime)
	SELECT  CustID
        ,	lv_CurrentDateTime
	FROM Temp_CustID;
    
END$$
DELIMITER ;