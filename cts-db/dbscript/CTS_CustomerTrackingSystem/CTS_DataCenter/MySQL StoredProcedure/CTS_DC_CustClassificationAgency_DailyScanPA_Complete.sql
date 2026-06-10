/*<info serverAlias="CTSMain-CTS_DataCenter" databaseType="2" executers="ctsServiceAdmin" isFunction="0" isNested="0"></info>*/
DROP PROCEDURE IF EXISTS `CTS_DataCenter`.`CTS_DC_CustClassificationAgency_DailyScanPA_Complete`;

DELIMITER $$
CREATE DEFINER=`ctsOwner`@`%` PROCEDURE `CTS_DC_CustClassificationAgency_DailyScanPA_Complete`(
		IN ip_CustIDs      			TEXT
)
    SQL SECURITY INVOKER
BEGIN
	/*
		Created: 20250303@Casey.Huynh
		Task:  Daily Scan PA Complete
		DB: CTS_DataCenter
		Original:
		Revisions:
            - 20250303@Casey.Huynh: Daily Scan PA Complete [Redmine ID: #218588]

		Param's Explanation (filtered by):  
        
			 CALL CTS_DC_CustClassificationAgency_DailyScanPA_Complete(ip_CustIDs:='123,455');
	*/
    DECLARE CONST_LASTSCANNEDTIME_PARAMETERID INT DEFAULT 187;
    
	DECLARE lv_LastScannedTime		DATETIME;
        
    DROP TEMPORARY TABLE IF EXISTS Temp_Customers;
	CREATE TEMPORARY TABLE Temp_Customers (
		 	CustID	BIGINT UNSIGNED	PRIMARY KEY
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
	WHERE ParameterID = CONST_LASTSCANNEDTIME_PARAMETERID;
	
	SET lv_LastScannedTime = DATE_ADD(lv_LastScannedTime, INTERVAL 24 HOUR);
        
	IF ((SELECT COUNT(1) FROM Temp_Customers) > 0) THEN
        DELETE queue
		FROM CTS_DataCenter.CTSCustomerClassificationAgency_DailyPAQueue AS queue 
		WHERE queue.CreatedTime <= lv_LastScannedTime
			AND EXISTS (SELECT 1 FROM Temp_Customers AS tmp WHERE tmp.CustID = queue.CustID);
    ELSE
		UPDATE CTS_DataCenter.SystemParameter
        SET ParameterValue = lv_LastScannedTime
        WHERE ParameterID = CONST_LASTSCANNEDTIME_PARAMETERID;
    END IF;
    
END$$
DELIMITER ;