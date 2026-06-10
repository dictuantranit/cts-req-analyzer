/*<info serverAlias="CTSMain-DCS_DataCenter" databaseType="2" executers="ctsServiceAdmin" isFunction="0" isNested="0"></info>*/
DROP PROCEDURE IF EXISTS `DCS_DC_Transform_MBDeviceCodeMediaDRM_Insert`;

DELIMITER $$
CREATE DEFINER=`ctsOwner`@`%` PROCEDURE `DCS_DC_Transform_MBDeviceCodeMediaDRM_Insert`(
	IN ip_MediaDRMJson	LONGTEXT
)
    SQL SECURITY INVOKER
BEGIN
    /*
	    Created: 20241121@Jonathan.Doan
	    Task : Insert MBDeviceCodeMediaDRM
	    DB: DCS_DataCenter
	    Original:

	    Revisions:
		    - 20241121@Jonathan.Doan: Transform to MBTransaction [Redmine ID: #213401]
		    - 20250425@Jonathan.Doan: Add field CreatedDate, CreatedTime [Redmine ID: #221973]
	    Param's Explanation (filtered by):
		Example:
			CALL DCS_DC_Transform_MBDeviceCodeMediaDRM_Insert('123');
            SELECT * FROM DCS_DataCenter.MBDeviceCodeMediaDRM ORDER BY ID DESC;
    */
    DECLARE lv_CurrentDatetime DATETIME DEFAULT NOW();
    
    /********************** Error handler ***********************************/
	DECLARE lv_SQLState CHAR(5);
	DECLARE lv_ErrorCode INT;
	DECLARE lv_ErrorMessage TEXT;
	DECLARE lv_FullMessage TEXT;

	DECLARE EXIT HANDLER FOR SQLEXCEPTION 
	BEGIN
		GET DIAGNOSTICS CONDITION 1
			lv_SQLState = RETURNED_SQLSTATE,
			lv_ErrorCode = MYSQL_ERRNO,
			lv_ErrorMessage = MESSAGE_TEXT;

		SET lv_FullMessage = CONCAT('SQL:', lv_SQLState, ', code:', lv_ErrorCode, ', Msg:', lv_ErrorMessage);
        
		INSERT INTO CTS_Log.FPSLog(SpName, JsonString, OtherText, InsertTime)
		SELECT 'DCS_DC_Transform_MBDeviceCodeMediaDRM_Insert', NULL, lv_FullMessage, CURRENT_TIMESTAMP();
        
        RESIGNAL;
	END;
    
	DROP TEMPORARY TABLE IF EXISTS Temp_MBDeviceCodeMediaDRMInsert;
	CREATE TEMPORARY TABLE Temp_MBDeviceCodeMediaDRMInsert(
			Code			VARCHAR(32) 	NOT NULL PRIMARY KEY
		,	TransTime		DATETIME(4)
		,	IsNewRecord		TINYINT			DEFAULT 1
    );
    
	INSERT IGNORE INTO Temp_MBDeviceCodeMediaDRMInsert(Code, TransTime)
    SELECT	js.Code
		,	js.TransTime
	FROM JSON_TABLE(
			ip_MediaDRMJson,
			 "$[*]" COLUMNS(
						Code		VARCHAR(32) COLLATE utf8_unicode_ci PATH "$.Code"
					,	TransTime	DATETIME(4)							PATH "$.TransTime"
				)
		   ) AS js
	WHERE js.Code <> '';
    
    UPDATE Temp_MBDeviceCodeMediaDRMInsert AS tmp
		INNER JOIN DCS_DataCenter.MBDeviceCodeMediaDRM AS drm ON drm.Code = tmp.Code
    SET tmp.IsNewRecord = 0;
	
	INSERT INTO DCS_DataCenter.MBDeviceCodeMediaDRM(Code, InsertedTime, LastAccessedDate, CreatedDate)
	SELECT	Code
		,	lv_CurrentDatetime AS InsertedTime
		,	DATE(TransTime) AS LastAccessedDate
		,	DATE(TransTime) AS CreatedDate
	FROM Temp_MBDeviceCodeMediaDRMInsert
    WHERE IsNewRecord = 1;
END$$
DELIMITER ;