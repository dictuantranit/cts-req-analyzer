/*<info serverAlias="CTSMain-DCS_DataCenter" databaseType="2" executers="ctsServiceAdmin" isFunction="0" isNested="0"></info>*/
DROP PROCEDURE IF EXISTS `DCS_DC_OpenSearch_TableDailyIDRange_Update`;

DELIMITER $$
CREATE DEFINER=`ctsOwner`@`%` PROCEDURE `DCS_DC_OpenSearch_TableDailyIDRange_Update`(
		IN ip_DatabaseName	VARCHAR(255)
	,	IN ip_TableName		VARCHAR(255)
	,	IN ip_Date			DATE
	,	IN ip_MinID			BIGINT UNSIGNED
	,	IN ip_MaxID			BIGINT UNSIGNED
)
SQL SECURITY INVOKER
BEGIN
    /*
	    Created: 20250428@Jonathan.Doan
	    Task : Update data of table TableDailyIDRange
	    DB: DCS_DataCenter
	    Original:

	    Revisions:
		    - 20250429@Jonathan.Doan: Created [Redmine ID: #224502]
	    Param's Explanation (filtered by):
		Example:
			CALL DCS_DC_OpenSearch_TableDailyIDRange_Update('DCS_DataCenter', 'FP_FingerPrint', '2025-04-14', 1, 2);
    */
    
    IF ip_MinID > 0 AND ip_MaxID > 0 THEN
		UPDATE DCS_DataCenter.TableDailyIDRange
		SET		MinID = ip_MinID
			,	MaxID = ip_MaxID
			,	InsertedTime = NOW()
		WHERE DatabaseName = ip_DatabaseName
			AND TableName = ip_TableName
			AND CreatedDate = ip_Date;
    END IF;
    
END$$
DELIMITER ;
