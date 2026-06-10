/*<info serverAlias="CTSMain-DCS_DataCenter" databaseType="2" executers="ctsServiceAdmin" isFunction="0" isNested="0"></info>*/
DROP PROCEDURE IF EXISTS `DCS_DC_OpenSearch_TableDailyIDRange_Insert`;

DELIMITER $$
CREATE DEFINER=`ctsOwner`@`%` PROCEDURE `DCS_DC_OpenSearch_TableDailyIDRange_Insert`(
		IN ip_DatabaseName	VARCHAR(255)
	,	IN ip_TableName		VARCHAR(255)
	,	IN ip_DateField		VARCHAR(255)
	,	IN ip_IDField		VARCHAR(255)
	,	IN ip_Date			DATE
)
SQL SECURITY INVOKER
BEGIN
    /*
	    Created: 20250428@Jonathan.Doan
	    Task : Insert data to TableDailyIDRange
	    DB: DCS_DataCenter
	    Original:

	    Revisions:
		    - 20250429@Jonathan.Doan: Created [Redmine ID: #224502]
	    Param's Explanation (filtered by):
		Example:
			CALL DCS_DC_OpenSearch_TableDailyIDRange_Insert('DCS_DataCenter', 'FP_FingerPrint', 'InsertedTime', 'ID', '2025-02-15');
    */
    
    DECLARE lv_PrevMinID	BIGINT UNSIGNED DEFAULT 0;
    DECLARE lv_IsExists		TINYINT DEFAULT 0;
    
    SELECT	MinID
		,	CASE WHEN CreatedDate = ip_Date THEN 1 ELSE 0 END AS IsExists
    INTO lv_PrevMinID, lv_IsExists
    FROM DCS_DataCenter.TableDailyIDRange
    WHERE DatabaseName = ip_DatabaseName
		AND TableName = ip_TableName
		AND CreatedDate <= ip_Date
	ORDER BY CreatedDate DESC
    LIMIT 1;
    
    SET @sql = CONCAT(
		'SELECT ',
			'MIN(', ip_IDField, ') AS MinID, ',
			'MAX(', ip_IDField, ') AS MaxID ',
		'INTO @lv_MinID, @lv_MaxID ',
		'FROM ', ip_DatabaseName, '.', ip_TableName, ' ',
		'WHERE ', ip_IDField, ' >= IFNULL(', lv_PrevMinID, ', 0) ',
			'AND ', ip_DateField, ' >= \'', ip_Date, '\' ',
			'AND ', ip_DateField, ' < DATE_ADD(\'', ip_Date, '\', INTERVAL 1 DAY) '
	);
	PREPARE stmt1 FROM @sql;
	EXECUTE stmt1;
    
    IF lv_IsExists = 1 THEN
		UPDATE DCS_DataCenter.TableDailyIDRange
		SET 	MinID = @lv_MinID
			,	MaxID = @lv_MaxID
		WHERE DatabaseName = ip_DatabaseName
			AND TableName = ip_TableName
			AND CreatedDate = ip_Date;
	ELSEIF (@lv_MinID > 0 AND @lv_MaxID > 0) THEN
		INSERT INTO DCS_DataCenter.TableDailyIDRange(DatabaseName, TableName, CreatedDate, MinID, MaxID, InsertedTime)
        SELECT	ip_DatabaseName
			,	ip_TableName
            ,	ip_Date
            ,	@lv_MinID
            ,	@lv_MaxID
            ,	NOW();
    END IF;
    
    SET @lv_MinID = NULL;
	SET @lv_MaxID = NULL;
	SET @sql = NULL;
    
END$$
DELIMITER ;
