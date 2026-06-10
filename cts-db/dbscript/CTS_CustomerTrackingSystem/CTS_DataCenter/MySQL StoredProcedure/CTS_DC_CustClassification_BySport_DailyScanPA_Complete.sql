/*<info serverAlias="CTSMain-CTS_DataCenter" databaseType="2" executers="ctsServiceAdmin" isFunction="0" isNested="0"></info>*/
DROP PROCEDURE IF EXISTS `CTS_DataCenter`.`CTS_DC_CustClassification_BySport_DailyScanPA_Complete`;

DELIMITER $$
CREATE DEFINER=`ctsOwner`@`%` PROCEDURE `CTS_DC_CustClassification_BySport_DailyScanPA_Complete`(
		IN ip_CustInfoList      TEXT
)
    SQL SECURITY INVOKER
BEGIN
	/*
		Created: 20251114@Logan.Nguyen
		Task:  Return PA category for daily scan PA By Sport [Redmine ID: #239955]
		DB: CTS_DataCenter
		Original:
		Revisions:
            - 20251114@Logan.Nguyen: Get PA category for daily scan PA By Sport [Redmine ID: #239955]

		Param's Explanation (filtered by):      
			 CALL CTS_DC_CustClassification_BySport_DailyScanPA_Complete (
    			'[{"CustID":761925,"SportGroup":1}]'
			);
	*/
	DECLARE lv_LastScannedTime		DATETIME;
     
    DROP TEMPORARY TABLE IF EXISTS Temp_Customers;
	CREATE TEMPORARY TABLE Temp_Customers (
		 	CustID			BIGINT UNSIGNED
        ,   SportGroup      INT
		,	PRIMARY KEY (CustID, SportGroup)
	);
    
	INSERT INTO Temp_Customers (CustID, SportGroup)
		SELECT  t.CustID, t.SportGroup
		FROM JSON_TABLE(
        		ip_CustInfoList,
        		'$[*]' COLUMNS (
              			CustID     BIGINT UNSIGNED	PATH '$.CustID'
              		,	SportGroup INT           	PATH '$.SportGroup'
				)
		) AS t;
    
	SELECT ParameterValue 
	INTO lv_LastScannedTime 
	FROM CTS_DataCenter.SystemParameter 
	WHERE ParameterID = 200;
	
	SET lv_LastScannedTime = DATE_ADD(lv_LastScannedTime, INTERVAL 24 HOUR);
        
	IF ((SELECT COUNT(1) FROM Temp_Customers) > 0) THEN
        DELETE queue
		FROM CTS_DataCenter.CTSCustomerClassification_BySport_DailyPAQueue AS queue 
		WHERE queue.CreatedTime <= lv_LastScannedTime
			AND EXISTS (SELECT 1 FROM Temp_Customers AS tmp WHERE tmp.CustID = queue.CustID AND tmp.SportGroup = queue.SportGroup);
    ELSE
		UPDATE CTS_DataCenter.SystemParameter
        SET ParameterValue = lv_LastScannedTime
        WHERE ParameterID = 200;
    END IF;
    
END$$
DELIMITER ;