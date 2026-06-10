/*<info serverAlias="CTSMain-CTS_DataCenter" databaseType="2" executers="ctsService,ctsServiceAdmin" isFunction="0" isNested="0"></info>*/
DROP PROCEDURE IF EXISTS `CTS_DataCenter`.`CTS_DC_CustClassification_SabaDangerLevel_Update`;

DELIMITER $$
CREATE DEFINER=`ctsOwner`@`%` PROCEDURE `CTS_DC_CustClassification_SabaDangerLevel_Update`(
		IN ip_CustInfo 	JSON
)
    SQL SECURITY INVOKER
BEGIN
	/* 
		Created:	20220818@Aries.Nguyen
		Task :		Customer Class - Update Saba Danger Level
		DB:			CTS_DataCenter
		Original: 
		Revisions: 
			- 20220818@Aries.Nguyen: Created [Redmine ID: #176224] 
            
        Param's Explanation: 

		Example:
			-CALL CTS_DataCenter.CTS_DC_CustClassification_SabaDangerLevel_Update('[{"CustID":1,"SportType":1,"Action":1}]');

	*/
    DROP TEMPORARY TABLE IF EXISTS Temp_CustSportType;
    CREATE TEMPORARY TABLE 	Temp_CustSportType (
			CustID 			BIGINT UNSIGNED 
		,	SportType		INT
        ,	`Action`			INT
        ,	PRIMARY KEY(CustID, SportType)
        ,	INDEX 			IX_Temp_CustSportType_Action(Action)
	);
    
	INSERT IGNORE INTO Temp_CustSportType(CustID, SportType, `Action`) 
	SELECT 	js.CustID
		,	js.SportType
        ,	js.`Action`
	FROM JSON_TABLE(ip_CustInfo,
		 "$[*]" COLUMNS(
				CustID 			BIGINT UNSIGNED		PATH "$.CustID"
            ,	SportType 		INT					PATH "$.SportType"
			,	Action 			INT					PATH "$.Action"
		 )) AS js;    
    
    
    INSERT IGNORE INTO  CTS_DataCenter.CTSCustomerSabaDangerLevel(CustID,SportType)
    SELECT 	tmp.CustID
		,	tmp.SportType
    FROM Temp_CustSportType AS tmp
    WHERE tmp.`Action` = 1
		AND NOT EXISTS (SELECT 1 
                        FROM CTSCustomerSabaDangerLevel AS dg 
                        WHERE tmp.CustID = dg.CustID 
							AND tmp.SportType = dg.SportType);
    
    DELETE 
    FROM CTS_DataCenter.CTSCustomerSabaDangerLevel AS cus
    WHERE EXISTS (SELECT 1 
                  FROM Temp_CustSportType AS tmp 
                  WHERE cus.CustID = tmp.CustID
					AND cus.SportType = tmp.SportType
                    AND tmp.`Action` = -1);
END$$
DELIMITER ;