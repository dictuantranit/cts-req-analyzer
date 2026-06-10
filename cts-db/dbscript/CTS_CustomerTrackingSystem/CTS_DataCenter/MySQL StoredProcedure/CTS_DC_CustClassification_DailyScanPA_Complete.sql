/*<info serverAlias="CTSMain-CTS_DataCenter" databaseType="2" executers="ctsServiceAdmin" isFunction="0" isNested="0"></info>*/
DROP PROCEDURE IF EXISTS `CTS_DataCenter`.`CTS_DC_CustClassification_DailyScanPA_Complete`;

DELIMITER $$
CREATE DEFINER=`ctsOwner`@`%` PROCEDURE `CTS_DC_CustClassification_DailyScanPA_Complete`(
		IN ip_CustIDs      			TEXT
)
    SQL SECURITY INVOKER
BEGIN
	/*
		Created: 20230313@Jonas.Huynh
		Task:  Return PA category for daily scan PA
		DB: CTS_DataCenter
		Original:
		Revisions:
            - 20230313@Jonas.Huynh: Get PA category for daily scan PA [Redmine ID: #184772]

		Param's Explanation (filtered by):      
			 CALL CTS_DC_CustClassification_DailyScanPA_Complete ('123,455');
	*/
	DECLARE lv_LastScannedTime		DATETIME;
     
    DROP TEMPORARY TABLE IF EXISTS Temp_Customers;
	CREATE TEMPORARY TABLE Temp_Customers (
		 	CustID			BIGINT UNSIGNED	PRIMARY KEY
	);
    
	INSERT INTO Temp_Customers (CustID)
    SELECT DISTINCT temp.CustID
    FROM JSON_TABLE(CONCAT('[',ip_CustIDs,']'),
			'$[*]' COLUMNS(NESTED PATH '$' COLUMNS (
				CustID 		BIGINT UNSIGNED PATH '$'
			))) AS temp;
    
	SELECT ParameterValue 
	INTO lv_LastScannedTime 
	FROM CTS_DataCenter.SystemParameter 
	WHERE ParameterID = 88;
	
	SET lv_LastScannedTime = DATE_ADD(lv_LastScannedTime, INTERVAL 24 HOUR);
        
	IF ((SELECT COUNT(1) FROM Temp_Customers) > 0) THEN
        DELETE queue
		FROM CTS_DataCenter.CTSCustomerClassification_DailyPAQueue AS queue 
		WHERE queue.CreatedTime <= lv_LastScannedTime
			AND EXISTS (SELECT 1 FROM Temp_Customers AS tmp WHERE tmp.CustID = queue.CustID);
    ELSE
		UPDATE CTS_DataCenter.SystemParameter
        SET ParameterValue = lv_LastScannedTime
        WHERE ParameterID = 88;
    END IF;
    
END$$
DELIMITER ;