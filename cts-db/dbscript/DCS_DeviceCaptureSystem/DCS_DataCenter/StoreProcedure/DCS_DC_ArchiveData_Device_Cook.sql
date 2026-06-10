/*<info serverAlias="CTSMain-DCS_DataCenter" databaseType="2" executers="ctsServiceAdmin" isFunction="0" isNested="0"></info>*/
DROP PROCEDURE IF EXISTS `DCS_DC_ArchiveData_Device_Cook`;

DELIMITER $$
CREATE DEFINER=`ctsOwner`@`%` PROCEDURE `DCS_DC_ArchiveData_Device_Cook`(
		IN ip_BatchSize INT UNSIGNED
        
	,	OUT op_ShouldContinue INT
)
SQL SECURITY INVOKER
BEGIN
	/*
		Created:	20240502@Jonathan.Doan
		Task:		Cook Orphaned Device after Archiving Account
		DB:			DCS_DataCenter
		Original:

		Revisions:
			- 20240502@Jonathan.Doan: Created [Redmine ID: #203691]
		Param's Explanation (filtered by):
            CALL DCS_DataCenter.DCS_DC_ArchiveData_Device_Cook(50, @shouldContinue); SELECT @shouldContinue;
	*/
    DECLARE CONST_SYSTEM_ARCHIVE_MAXDEVICEID INT DEFAULT 4963736;
    
    DECLARE lv_MaxDeviceID  BIGINT UNSIGNED;
    
    SET lv_MaxDeviceID = (SELECT CAST(VValue AS UNSIGNED) FROM DCS_DataCenter.SystemSetting WHERE ID = CONST_SYSTEM_ARCHIVE_MAXDEVICEID);
    
    DROP TEMPORARY TABLE IF EXISTS Temp_Device;
    
    CREATE TEMPORARY TABLE Temp_Device(
			DeviceID BIGINT UNSIGNED NOT NULL PRIMARY KEY
    );
    
    INSERT INTO Temp_Device(DeviceID)
    SELECT dv.DeviceID
    FROM DCS_DataCenter.Device AS dv
    WHERE dv.DeviceID > lv_MaxDeviceID
		AND NOT EXISTS (SELECT 1 FROM DCS_DataCenter.Association AS ass WHERE ass.DeviceID = dv.DeviceID)
    ORDER BY dv.DeviceID ASC
    LIMIT ip_BatchSize;
    
    SET lv_MaxDeviceID = (SELECT MAX(DeviceID) FROM Temp_Device);
    
    INSERT IGNORE INTO DCS_DataCenter.ArchiveDevice_NotUsed(DeviceID)
    SELECT DeviceID
    FROM Temp_Device;
    
    INSERT IGNORE INTO DCS_DataCenter.ArchiveDeviceCode_NotUsed(DeviceCodeID, DeviceCode, DeviceID)
    SELECT	dc.DeviceCodeID
		,	dc.DeviceCode
        ,	dc.DeviceID
    FROM Temp_Device AS tmp
		INNER JOIN DCS_DataCenter.DeviceCode AS dc ON dc.DeviceID = tmp.DeviceID;

    /* == Update SystemSetting == */
    IF(lv_MaxDeviceID IS NOT NULL AND lv_MaxDeviceID > 0) THEN
        UPDATE DCS_DataCenter.SystemSetting 
        SET VValue = lv_MaxDeviceID
        WHERE ID = CONST_SYSTEM_ARCHIVE_MAXDEVICEID;
        
		SET op_ShouldContinue = 1;
	ELSE
		SET op_ShouldContinue = 0;
    END IF;
    
END$$

DELIMITER ;
