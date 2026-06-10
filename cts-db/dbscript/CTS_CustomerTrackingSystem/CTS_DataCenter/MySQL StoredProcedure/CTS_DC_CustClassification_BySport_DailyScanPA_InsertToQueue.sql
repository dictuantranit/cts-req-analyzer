/*<info serverAlias="CTSMain-CTS_DataCenter" databaseType="2" executers="ctsServiceAdmin" isFunction="0" isNested="0"></info>*/
DROP PROCEDURE IF EXISTS `CTS_DataCenter`.`CTS_DC_CustClassification_BySport_DailyScanPA_InsertToQueue`;

DELIMITER $$
CREATE DEFINER=`ctsOwner`@`%` PROCEDURE `CTS_DC_CustClassification_BySport_DailyScanPA_InsertToQueue`(
		IN ip_CustInfoList		TEXT
)
    SQL SECURITY INVOKER
BEGIN
	/*
		Created: 20251113@Logan.Nguyen
		Task: Insert problem accounts By Sport with new placebets to queue [Redmine ID: #239955]
		DB: CTS_DataCenter
        
		Original:
		Revisions:
			- 20251113@Logan.Nguyen: 	Get List CustID and SportType for daily scan PA By Sport [Redmine ID: #239955]

		Param's Explanation (filtered by):      
			CALL CTS_DC_CustClassification_BySport_DailyScanPA_InsertToQueue (
    			'[{"CustID":761925,"SportGroup":1}]'
			);
	*/
    
	SET @lv_CurrentDateTime	= NOW(); 
    
	DROP TEMPORARY TABLE IF EXISTS Temp_CustIDs;    
	CREATE TEMPORARY TABLE Temp_CustIDs( 	  
			CustID			BIGINT UNSIGNED
        ,   SportGroup		INT
		,	PRIMARY KEY (CustID, SportGroup)
	);

    INSERT INTO Temp_CustIDs (CustID, SportGroup)
		SELECT DISTINCT t.CustID, t.SportGroup
		FROM JSON_TABLE(
        		ip_CustInfoList,
        		'$[*]' COLUMNS (
              			CustID		BIGINT	UNSIGNED	PATH '$.CustID'
					,	SportGroup	INT					PATH '$.SportGroup'
        		)
		) AS t;
    
    INSERT INTO CTS_DataCenter.CTSCustomerClassification_BySport_DailyPAQueue(CustID, SportGroup, CreatedTime)
	SELECT  CustID
		,	SportGroup
        ,	@lv_CurrentDateTime
	FROM Temp_CustIDs;
    
END$$
DELIMITER ;