/*<info serverAlias="CTSMain-DCS_DataCenter" databaseType="2" executers="ctsServiceAdmin" isFunction="0" isNested="0"></info>*/
DROP PROCEDURE IF EXISTS `DCS_DC_ArchiveData_Device_Archive`;

DELIMITER $$
CREATE DEFINER=`ctsOwner`@`%` PROCEDURE `DCS_DC_ArchiveData_Device_Archive`(
		IN ip_BatchSize INT UNSIGNED
        
	,	OUT op_ShouldContinue INT
)
SQL SECURITY INVOKER
BEGIN
	/*
		Created:	20240502@Jonathan.Doan
		Task:		Delete Orphaned Device after Archiving Account
		DB:			DCS_DataCenter
		Original:

		Revisions:
			- 20240502@Jonathan.Doan: Created [Redmine ID: #203691]
		Param's Explanation (filtered by):
            CALL DCS_DataCenter.DCS_DC_ArchiveData_Device_Archive(50, @shouldContinue); SELECT @shouldContinue;
	*/
    DECLARE lv_InsertTime TIMESTAMP DEFAULT CURRENT_TIMESTAMP();
    
    DROP TEMPORARY TABLE IF EXISTS Temp_Device;
    DROP TEMPORARY TABLE IF EXISTS Temp_ReActiveDevice;
    DROP TEMPORARY TABLE IF EXISTS Temp_DeviceCode;
    
    CREATE TEMPORARY TABLE Temp_Device(
			DeviceID 		BIGINT UNSIGNED NOT NULL PRIMARY KEY
    );
    
    CREATE TEMPORARY TABLE Temp_ReActiveDevice(
			DeviceID 		BIGINT UNSIGNED NOT NULL PRIMARY KEY
    );
    
    CREATE TEMPORARY TABLE Temp_DeviceCode(
			DeviceCodeID 	BIGINT UNSIGNED NOT NULL PRIMARY KEY
    );
    
    /* == Get data needing archiving == */
    INSERT INTO Temp_Device(DeviceID)
	SELECT DeviceID
	FROM DCS_DataCenter.ArchiveDevice_NotUsed
	ORDER BY DeviceID ASC
	LIMIT ip_BatchSize;
    
    INSERT INTO Temp_DeviceCode(DeviceCodeID)
	SELECT DeviceCodeID
	FROM DCS_DataCenter.ArchiveDeviceCode_NotUsed
	ORDER BY DeviceCodeID ASC
	LIMIT ip_BatchSize;
    
    /* == Archive Device & DeviceFingerprint not used == */
	DELETE dv
	FROM DCS_DataCenter.Device AS dv
		INNER JOIN Temp_Device AS tmp ON tmp.DeviceID = dv.DeviceID;
        
	INSERT INTO DCS_DataCenter.ArchiveAccount_RowCount(InsertTime, TableArchived, RowCount)
	SELECT lv_InsertTime, 'Device', ROW_COUNT();
        
	DELETE dvf
	FROM DCS_DataCenter.DeviceFingerprint AS dvf
		INNER JOIN Temp_Device AS tmp ON tmp.DeviceID = dvf.DeviceID;
        
	INSERT INTO DCS_DataCenter.ArchiveAccount_RowCount(InsertTime, TableArchived, RowCount)
	SELECT lv_InsertTime, 'DeviceFingerprint', ROW_COUNT();

	DELETE arcDv
    FROM DCS_DataCenter.ArchiveDevice_NotUsed AS arcDv
		INNER JOIN Temp_Device AS tmp ON tmp.DeviceID = arcDv.DeviceID;
    
    /* == Archive DeviceCode not used == */
	DELETE dvc
	FROM DCS_DataCenter.DeviceCode AS dvc
		INNER JOIN Temp_DeviceCode AS tmp ON tmp.DeviceCodeID = dvc.DeviceCodeID;
        
	INSERT INTO DCS_DataCenter.ArchiveAccount_RowCount(InsertTime, TableArchived, RowCount)
	SELECT lv_InsertTime, 'DeviceCode', ROW_COUNT();

	DELETE arcDvc
    FROM DCS_DataCenter.ArchiveDeviceCode_NotUsed AS arcDvc
		INNER JOIN Temp_DeviceCode AS tmp ON tmp.DeviceCodeID = arcDvc.DeviceCodeID;

	
    /* Update op_ShouldContinue */
    IF (EXISTS (SELECT 1 FROM DCS_DataCenter.ArchiveDevice_NotUsed LIMIT 1)) THEN
		SET op_ShouldContinue = 1;
	ELSEIF (EXISTS (SELECT 1 FROM DCS_DataCenter.ArchiveDeviceCode_NotUsed LIMIT 1)) THEN
		SET op_ShouldContinue = 1;
	ELSE
		SET op_ShouldContinue = 0;
	END IF;
    
END$$

DELIMITER ;
