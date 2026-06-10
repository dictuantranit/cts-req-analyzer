/*<info serverAlias="CTSMain-CTS_DataCenter" databaseType="2" executers="ctsService" isFunction="0" isNested="0"></info>*/
DROP PROCEDURE IF EXISTS `CTS_DataCenter`.`CTS_DC_CustClassification_BySport_DailyScanPA_GetFromQueue`;

DELIMITER $$
CREATE DEFINER=`ctsOwner`@`%` PROCEDURE `CTS_DataCenter`.`CTS_DC_CustClassification_BySport_DailyScanPA_GetFromQueue`(
	IN ip_BatchSize INT
)
    SQL SECURITY INVOKER
BEGIN
	/*
		Created: 20251113@Logan.Nguyen
		Task:  Return List CustID and SportType for daily scan PA
		DB: CTS_DataCenter
		Original:
		Revisions:
			- 20251113@Logan.Nguyen: 	Get List CustID and SportType for daily scan PA By Sport [Redmine ID: #239955]
            
		Param's Explanation (filtered by):    
			CALL CTS_DC_CustClassification_BySport_DailyScanPA_GetFromQueue(500);
	*/ 
   
    DECLARE lv_LastScannedTime		DATETIME;
	DECLARE lv_BatchSize			INT;


	DROP TEMPORARY TABLE IF EXISTS Temp_Customers;
	CREATE TEMPORARY TABLE Temp_Customers(
			CustID					BIGINT UNSIGNED
        ,   SportGroup           	INT
		,	PRIMARY KEY (CustID, SportGroup)
	);

	IF ip_BatchSize IS NULL OR ip_BatchSize <= 0 THEN
        SET lv_BatchSize = 500;
    ELSE
        SET lv_BatchSize = ip_BatchSize;
    END IF;
    
    SELECT ParameterValue 
    INTO lv_LastScannedTime 
    FROM CTS_DataCenter.SystemParameter 
    WHERE ParameterID = 200;
	
    SET lv_LastScannedTime = DATE_ADD(lv_LastScannedTime, INTERVAL 24 HOUR);
    
	INSERT INTO Temp_Customers(CustID, SportGroup)
	WITH cte AS ( 
		SELECT	ccdpa.ID
			,	cc.CustID
			,	ccdpa.SportGroup
		FROM CTS_DataCenter.CTSCustomerClassification_BySport_DailyPAQueue AS ccdpa
		JOIN CTS_DataCenter.CTSCustomerClassification_BySport AS cc ON cc.CustID = ccdpa.CustID AND cc.SportID = ccdpa.SportGroup
		JOIN CTS_DataCenter.CustomerCategorySettings AS ccs ON cc.CategoryID = ccs.CategoryID
		WHERE ccdpa.CreatedTime <= lv_LastScannedTime
			AND ccs.FlowPADailyScan = 1
		ORDER BY ID ASC
		LIMIT lv_BatchSize)
	SELECT DISTINCT CustID, SportGroup
    FROM cte;
    
	SELECT CustID, SportGroup
	FROM Temp_Customers;

END$$
DELIMITER ;