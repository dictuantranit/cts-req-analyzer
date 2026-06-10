/*<info serverAlias="CTSMain-DCS_DataCenter" databaseType="2" executers="ctsServiceAdmin" isFunction="0" isNested="0"></info>*/
DROP PROCEDURE IF EXISTS `DCS_DC_Transform_MBDeviceCodeMachineAccount_Insert`;

DELIMITER $$
CREATE DEFINER=`ctsOwner`@`%` PROCEDURE `DCS_DC_Transform_MBDeviceCodeMachineAccount_Insert`(
	IN ip_MBDeviceCodeMachineAccountJson	LONGTEXT
)
    SQL SECURITY INVOKER
BEGIN
    /*
	    Created: 20250808@Jonathan.Doan
	    Task : Insert MBDeviceCodeMachineAccount
	    DB: DCS_DataCenter
	    Original:

	    Revisions:
		    - 20250808@Jonathan.Doan: Insert MBDeviceCodeMachineAccount [Redmine ID: #235457]
	    Param's Explanation (filtered by):
		Example:
			CALL DCS_DC_Transform_MBDeviceCodeMachineAccount_Insert('[{"MBDeviceCodeMachineID":1, "MBAccountID":2, "TransTime":"2025-08-11 11:05:16"}]');
            SELECT * FROM DCS_DataCenter.MBDeviceCodeMachineAccount ORDER BY ID DESC;
    */
    DECLARE lv_CurrentDatetime DATETIME DEFAULT NOW();
    
	DROP TEMPORARY TABLE IF EXISTS Temp_MBDeviceCodeMachineAccountInsert;
	CREATE TEMPORARY TABLE Temp_MBDeviceCodeMachineAccountInsert(
			MBDeviceCodeMachineID		BIGINT UNSIGNED NOT NULL
		,	MBAccountID					BIGINT UNSIGNED NOT NULL
		,	TransTime					DATETIME(4)
		,	IsNewRecord					TINYINT	DEFAULT 1
        ,	PRIMARY KEY (MBDeviceCodeMachineID, MBAccountID)
    );
	
	INSERT IGNORE INTO Temp_MBDeviceCodeMachineAccountInsert(MBDeviceCodeMachineID, MBAccountID, TransTime)
    SELECT	js.MBDeviceCodeMachineID
		,	js.MBAccountID
		,	js.TransTime
	FROM JSON_TABLE(
			ip_MBDeviceCodeMachineAccountJson,
			 "$[*]" COLUMNS(
						MBDeviceCodeMachineID		BIGINT UNSIGNED		PATH "$.MBDeviceCodeMachineID"
					,	MBAccountID					BIGINT UNSIGNED		PATH "$.MBAccountID"
					,	TransTime					DATETIME(4)		    PATH "$.TransTime"
				)
		   ) AS js
	WHERE js.MBDeviceCodeMachineID <> ''
		AND js.MBAccountID <> '';
	
    UPDATE Temp_MBDeviceCodeMachineAccountInsert AS tmp
		INNER JOIN DCS_DataCenter.MBDeviceCodeMachineAccount AS tg ON tg.MBDeviceCodeMachineID = tmp.MBDeviceCodeMachineID
																	AND tg.MBAccountID = tmp.MBAccountID
    SET tmp.IsNewRecord = 0;
	
	INSERT INTO DCS_DataCenter.MBDeviceCodeMachineAccount(MBDeviceCodeMachineID, MBAccountID, InsertedTime, CreatedDate)
	SELECT	MBDeviceCodeMachineID
		,	MBAccountID
		,	lv_CurrentDatetime AS InsertedTime
		,	DATE(TransTime) AS CreatedDate
	FROM Temp_MBDeviceCodeMachineAccountInsert
    WHERE IsNewRecord = 1;
END$$
DELIMITER ;