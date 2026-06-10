DELIMITER $$
USE CTS_Adhoc $$
DROP PROCEDURE IF EXISTS CTS_Adhoc.cs0519_DCSAccountNotInCTS_DeleteDeviceCode$$

CREATE PROCEDURE CTS_Adhoc.cs0519_DCSAccountNotInCTS_DeleteDeviceCode()
BEGIN
	/*
		Created:	20200519@Casey
		Task:		Remove Account NOT In CTS
		DB:			CTS_Adhoc
		Original:

		Revisions:
		Param's Explanation (filtered by):
	*/
	
	DELETE 		dev
    FROM 		DCS_DataCenter.DeviceCode AS dev
    INNER JOIN	CTS_Adhoc.cs0519_DeviceCode_RemoveBK AS devRev
    WHERE		dev.DeviceCodeID = devRev.DeviceCodeID;
    
END$$
DELIMITER ;