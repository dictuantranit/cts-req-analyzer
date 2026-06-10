DELIMITER $$
USE CTS_Adhoc $$
DROP PROCEDURE IF EXISTS CTS_Adhoc.cs0519_DCSAccountNotInCTS_DeleteDevice$$

CREATE PROCEDURE CTS_Adhoc.cs0519_DCSAccountNotInCTS_DeleteDevice()
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
    FROM 		DCS_DataCenter.Device AS dev
    INNER JOIN	CTS_Adhoc.cs0519_Device_RemoveBK AS devRev
    WHERE		dev.DeviceID = devRev.DeviceID;
    
END$$
DELIMITER ;