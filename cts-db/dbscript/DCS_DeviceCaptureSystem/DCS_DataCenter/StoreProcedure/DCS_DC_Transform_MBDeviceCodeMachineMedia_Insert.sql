/*<info serverAlias="CTSMain-DCS_DataCenter" databaseType="2" executers="ctsServiceAdmin" isFunction="0" isNested="0"></info>*/
DROP PROCEDURE IF EXISTS `DCS_DC_Transform_MBDeviceCodeMachineMedia_Insert`;

DELIMITER $$
CREATE DEFINER=`ctsOwner`@`%` PROCEDURE `DCS_DC_Transform_MBDeviceCodeMachineMedia_Insert`(
	IN ip_MBDeviceCodeMachineMediaJson	LONGTEXT
)
    SQL SECURITY INVOKER
BEGIN
    /*
	    Created: 20250808@Jonathan.Doan
	    Task : Insert MBDeviceCodeMachineMedia
	    DB: DCS_DataCenter
	    Original:

	    Revisions:
		    - 20250808@Jonathan.Doan: Insert MBDeviceCodeMachineMedia [Redmine ID: #235457]
	    Param's Explanation (filtered by):
		Example:
			CALL DCS_DC_Transform_MBDeviceCodeMachineMedia_Insert('[{"MBDeviceCodeMachineID":1, "MBDeviceCodeMediaDRMID":4, "TransTime":"2025-08-11 11:05:16"},{"MBDeviceCodeMachineID":2, "MBDeviceCodeMediaDRMID":4, "TransTime":"2025-08-11 11:05:16"}]');
            SELECT * FROM DCS_DataCenter.MBDeviceCodeMachineMedia ORDER BY ID DESC;
    */
    DECLARE lv_CurrentDatetime DATETIME DEFAULT NOW();
    
	DROP TEMPORARY TABLE IF EXISTS Temp_MBDeviceCodeMachineMediaInsert;
	CREATE TEMPORARY TABLE Temp_MBDeviceCodeMachineMediaInsert(
			MBDeviceCodeMachineID		BIGINT UNSIGNED NOT NULL
		,	MBDeviceCodeMediaDRMID		BIGINT UNSIGNED NOT NULL
		,	TransTime					DATETIME(4)
		,	IsNewRecord					TINYINT	DEFAULT 1
        ,	PRIMARY KEY (MBDeviceCodeMachineID, MBDeviceCodeMediaDRMID)
    );
	
	INSERT IGNORE INTO Temp_MBDeviceCodeMachineMediaInsert(MBDeviceCodeMachineID, MBDeviceCodeMediaDRMID, TransTime)
    SELECT	js.MBDeviceCodeMachineID
		,	js.MBDeviceCodeMediaDRMID
		,	js.TransTime
	FROM JSON_TABLE(
			ip_MBDeviceCodeMachineMediaJson,
			 "$[*]" COLUMNS(
						MBDeviceCodeMachineID		BIGINT UNSIGNED		PATH "$.MBDeviceCodeMachineID"
					,	MBDeviceCodeMediaDRMID		BIGINT UNSIGNED		PATH "$.MBDeviceCodeMediaDRMID"
					,	TransTime					DATETIME(4)			PATH "$.TransTime"
				)
		   ) AS js
	WHERE js.MBDeviceCodeMachineID <> ''
		AND js.MBDeviceCodeMediaDRMID <> '';
	
    UPDATE Temp_MBDeviceCodeMachineMediaInsert AS tmp
		INNER JOIN DCS_DataCenter.MBDeviceCodeMachineMedia AS tg ON tg.MBDeviceCodeMachineID = tmp.MBDeviceCodeMachineID
																	AND tg.MBDeviceCodeMediaDRMID = tmp.MBDeviceCodeMediaDRMID
    SET tmp.IsNewRecord = 0;
	
	INSERT INTO DCS_DataCenter.MBDeviceCodeMachineMedia(MBDeviceCodeMachineID, MBDeviceCodeMediaDRMID, InsertedTime, CreatedDate)
	SELECT	MBDeviceCodeMachineID
		,	MBDeviceCodeMediaDRMID
		,	lv_CurrentDatetime AS InsertedTime
		,	DATE(TransTime) AS CreatedDate
	FROM Temp_MBDeviceCodeMachineMediaInsert
    WHERE IsNewRecord = 1;
END$$
DELIMITER ;