/*<info serverAlias="CTSMain-DCS_DataCenter" databaseType="2" executers="ctsServiceAdmin" isFunction="0" isNested="0"></info>*/
DROP PROCEDURE IF EXISTS `DCS_DC_Transform_MBDeviceCodeMachine_Insert`;

DELIMITER $$
CREATE DEFINER=`ctsOwner`@`%` PROCEDURE `DCS_DC_Transform_MBDeviceCodeMachine_Insert`(
	IN ip_MBDeviceCodeMachineJson	LONGTEXT
)
    SQL SECURITY INVOKER
BEGIN
    /*
	    Created: 20241121@Jonathan.Doan
	    Task : Insert MBDeviceCodeMachine
	    DB: DCS_DataCenter
	    Original:

	    Revisions:
		    - 20241121@Jonathan.Doan: Transform to MBTransaction [Redmine ID: #213401]
		    - 20250425@Jonathan.Doan: Add field CreatedDate, CreatedTime [Redmine ID: #221973]
		    - 20250811@Jonathan.Doan: Update new rule [Redmine ID: #235457]
	    Param's Explanation (filtered by):
		Example:
			CALL DCS_DC_Transform_MBDeviceCodeMachine_Insert('[{"Code":"Code4","MachineOS":"Android","TransTime":"2025-05-12 01:02:03"},{"Code":"Code2","TransTime":"2025-05-12 01:02:04"},{"Code":"Code3","MachineOS":""}]');
            SELECT * FROM DCS_DataCenter.MBDeviceCodeMachine ORDER BY ID DESC;
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
		SELECT 'DCS_DC_Transform_MBDeviceCodeMachine_Insert', NULL, lv_FullMessage, CURRENT_TIMESTAMP();
        
        RESIGNAL;
	END;
    
	DROP TEMPORARY TABLE IF EXISTS Temp_MBDeviceCodeMachineInsert;
	CREATE TEMPORARY TABLE Temp_MBDeviceCodeMachineInsert(
			Code					VARCHAR(32) 	NOT NULL PRIMARY KEY
		,	MachineOSType	 		SMALLINT 		NOT NULL COMMENT 'DCS_DataCenter.StaticList.ListID = 5'
		,	TransTime				DATETIME(4)
		,	IsNewRecord				TINYINT			DEFAULT 1
    );
    
	INSERT IGNORE INTO Temp_MBDeviceCodeMachineInsert(Code, MachineOSType, TransTime)
    SELECT	js.Code
		,	IFNULL(sl.ItemID, 0) AS MachineOSType
		,	js.TransTime
	FROM JSON_TABLE(
			ip_MBDeviceCodeMachineJson,
			 "$[*]" COLUMNS(
						Code		VARCHAR(32) COLLATE utf8_unicode_ci PATH "$.Code"
					,	MachineOS	VARCHAR(32) COLLATE utf8_unicode_ci PATH "$.MachineOS"
					,	TransTime	DATETIME(4)							PATH "$.TransTime"
				)
		   ) AS js
		LEFT JOIN DCS_DataCenter.StaticList AS sl ON sl.ListID = 5 AND sl.ItemCode = js.MachineOS
	WHERE js.Code <> '';
	 
    UPDATE Temp_MBDeviceCodeMachineInsert AS tmp
		INNER JOIN DCS_DataCenter.MBDeviceCodeMachine AS ar ON ar.Code = tmp.Code AND ar.MachineOSType = tmp.MachineOSType
    SET tmp.IsNewRecord = 0;
	
	INSERT INTO DCS_DataCenter.MBDeviceCodeMachine(Code, MachineOSType, InsertedTime, LastAccessedDate, CreatedDate)
	SELECT	Code
		,	MachineOSType
		,	lv_CurrentDatetime AS InsertedTime
		,	DATE(TransTime) AS LastAccessedDate
		,	DATE(TransTime) AS CreatedDate
	FROM Temp_MBDeviceCodeMachineInsert
    WHERE IsNewRecord = 1;
END$$
DELIMITER ;