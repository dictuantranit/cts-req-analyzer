/*<info serverAlias="CTSMain-DCS_DataCenter" databaseType="2" executers="ctsServiceAdmin" isFunction="0" isNested="0"></info>*/
DROP PROCEDURE IF EXISTS `DCS_DC_ArchiveData_Device_CheckReActive`;

DELIMITER $$
CREATE DEFINER=`ctsOwner`@`%` PROCEDURE `DCS_DC_ArchiveData_Device_CheckReActive`()
SQL SECURITY INVOKER
BEGIN
	/*
		Created:	20240502@Jonathan.Doan
		Task:		Check Device re-active
		DB:			DCS_DataCenter
		Original:

		Revisions:
			- 20240502@Jonathan.Doan: Created [Redmine ID: #203691]
		Param's Explanation (filtered by):
            CALL DCS_DataCenter.DCS_DC_ArchiveData_Device_CheckReActive();
	*/
    DROP TEMPORARY TABLE IF EXISTS Temp_DeviceReActived;
    
    CREATE TEMPORARY TABLE Temp_DeviceReActived(
			DeviceID 		BIGINT UNSIGNED NOT NULL PRIMARY KEY
    );
    
    INSERT INTO Temp_DeviceReActived(DeviceID)
    SELECT DISTINCT ad.DeviceID
    FROM DCS_DataCenter.ArchiveDevice_NotUsed AS ad
    WHERE EXISTS (SELECT 1 FROM DCS_DataCenter.Association AS ass WHERE ass.DeviceID = ad.DeviceID);
    
    DELETE ad
    FROM DCS_DataCenter.ArchiveDevice_NotUsed AS ad
		INNER JOIN Temp_DeviceReActived AS tmp ON tmp.DeviceID = ad.DeviceID;
        
    DELETE adc
    FROM DCS_DataCenter.ArchiveDeviceCode_NotUsed AS adc
		INNER JOIN Temp_DeviceReActived AS tmp ON tmp.DeviceID = adc.DeviceID;
    
END$$

DELIMITER ;
