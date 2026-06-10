/*<info serverAlias="CTSMain-CTS_DataCenter" databaseType="2" executers="ctsService" isFunction="0" isNested="0"></info>*/
DROP PROCEDURE IF EXISTS `CTS_DataCenter`.`CTS_DC_CustClassificationAgency_DailyScanPA_GetFromQueue`;

DELIMITER $$
CREATE DEFINER=`ctsOwner`@`%` PROCEDURE `CTS_DataCenter`.`CTS_DC_CustClassificationAgency_DailyScanPA_GetFromQueue`(
)
    SQL SECURITY INVOKER
BEGIN
	/*
		Created: 20250303@Thomas.Nguyen
		Task: Return PA category for daily Agency scan PA 
		DB: CTS_DataCenter
		Original:
		Revisions:
			- 20250303@Thomas.Nguyen: 	Created [Redmine ID: #218588]

		Param's Explanation (filtered by):    
			CALL CTS_DC_CustClassificationAgency_DailyScanPA_GetFromQueue()
	*/ 
   
	DECLARE CONST_BATCHSIZE_PARAMETERID			INT DEFAULT 186;
	DECLARE CONST_LASTSCANNEDTIME_PARAMETERID	INT DEFAULT 187;
    DECLARE lv_BatchSize 						INT;
    DECLARE lv_LastScannedTime					DATETIME;

	DROP TEMPORARY TABLE IF EXISTS Temp_Cust;
	CREATE TEMPORARY TABLE Temp_Cust(
			CustID	BIGINT UNSIGNED PRIMARY KEY
	);

	SELECT ParameterValue 
    INTO lv_BatchSize 
    FROM CTS_DataCenter.SystemParameter 
    WHERE ParameterID = CONST_BATCHSIZE_PARAMETERID;
    
    SELECT ParameterValue 
    INTO lv_LastScannedTime 
    FROM CTS_DataCenter.SystemParameter 
    WHERE ParameterID = CONST_LASTSCANNEDTIME_PARAMETERID;
	
    SET lv_LastScannedTime = DATE_ADD(lv_LastScannedTime, INTERVAL 24 HOUR);
    
	INSERT INTO Temp_Cust(CustID)
	WITH CTE_CustFromQueue AS ( 
		SELECT ID, CustID
		FROM CTS_DataCenter.CTSCustomerClassificationAgency_DailyPAQueue
		WHERE CreatedTime <= lv_LastScannedTime
		ORDER BY ID ASC
		LIMIT lv_BatchSize
	)
	SELECT DISTINCT CustID
    FROM CTE_CustFromQueue;
    
	SELECT CustID
	FROM Temp_Cust;

END$$
DELIMITER ;