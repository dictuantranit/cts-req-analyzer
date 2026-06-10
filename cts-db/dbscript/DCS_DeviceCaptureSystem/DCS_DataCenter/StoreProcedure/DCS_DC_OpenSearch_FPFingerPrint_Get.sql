/*<info serverAlias="CTSMain-DCS_DataCenter" databaseType="2" executers="ctsServiceAdmin" isFunction="0" isNested="0"></info>*/
DROP PROCEDURE IF EXISTS `DCS_DC_OpenSearch_FPFingerPrint_Get`;

DELIMITER $$
CREATE DEFINER=`ctsOwner`@`%` PROCEDURE `DCS_DC_OpenSearch_FPFingerPrint_Get`(
		IN ip_FromDate		DATETIME
	,	IN ip_ToDate		DATETIME
	,	IN ip_BatchSize		INT
	,	IN ip_LastID		BIGINT UNSIGNED
)
SQL SECURITY INVOKER
BEGIN
    /*
	    Created: 20250429@Jonathan.Doan
	    Task : Get FP_FingerPrint
	    DB: DCS_DataCenter
	    Original:

	    Revisions:
		    - 20250428@Jonathan.Doan: Created [Redmine ID: #224502]
	    Param's Explanation (filtered by):
		Example:
			CALL DCS_DC_OpenSearch_FPFingerPrint_Get('2025-03-24', '2025-05-01', 100, 0);
    */
    
    DECLARE CONST_DATABASE_NAME		VARCHAR(255) DEFAULT 'DCS_DataCenter';
    DECLARE CONST_TABLE_NAME		VARCHAR(255) DEFAULT 'FP_FingerPrint';
    
    DECLARE lv_MinID				BIGINT UNSIGNED DEFAULT 0;
    DECLARE lv_MaxID				BIGINT UNSIGNED DEFAULT 0;
    DECLARE lv_EffectiveStartID		BIGINT UNSIGNED DEFAULT 0;
    DECLARE lv_FromDate				DATE;
	DECLARE lv_ToDate				DATE;

	SET lv_FromDate	= DATE(ip_FromDate);
	SET lv_ToDate	= DATE(ip_ToDate);
    
    SELECT MinID
    INTO lv_MinID
    FROM DCS_DataCenter.TableDailyIDRange
    WHERE DatabaseName = CONST_DATABASE_NAME
		AND TableName = CONST_TABLE_NAME
        AND CreatedDate <= lv_FromDate
	ORDER BY CreatedDate DESC
    LIMIT 1;

    SELECT MaxID
    INTO lv_MaxID
    FROM DCS_DataCenter.TableDailyIDRange
    WHERE DatabaseName = CONST_DATABASE_NAME
		AND TableName = CONST_TABLE_NAME
        AND CreatedDate >= lv_ToDate
	ORDER BY CreatedDate ASC
    LIMIT 1;
    
    SET lv_MinID			= IFNULL(lv_MinID,0);
    SET lv_MaxID			= IFNULL(lv_MaxID,0);
    SET lv_EffectiveStartID	= GREATEST(lv_MinID, ip_LastID + 1);
    
    SELECT	ID
		,	Code
        ,	Attribute
        ,	InsertedTime
    FROM DCS_DataCenter.FP_FingerPrint
    WHERE ID >= lv_EffectiveStartID
		AND (lv_MaxID = 0 OR ID <= lv_MaxID)
		AND InsertedTime >= lv_FromDate
		AND InsertedTime < DATE_ADD(lv_ToDate, INTERVAL 1 DAY)
	ORDER BY ID ASC
    LIMIT ip_BatchSize;
    
END$$
DELIMITER ;
