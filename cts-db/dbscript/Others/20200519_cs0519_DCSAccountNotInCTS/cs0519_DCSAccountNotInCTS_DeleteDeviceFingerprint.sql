DELIMITER $$
USE CTS_Adhoc $$
DROP PROCEDURE IF EXISTS CTS_Adhoc.cs0519_DCSAccountNotInCTS_DeleteDeviceFingerprint$$

CREATE PROCEDURE CTS_Adhoc.cs0519_DCSAccountNotInCTS_DeleteDeviceFingerprint()
BEGIN
	/*
		Created:	20200519@Casey
		Task:		Remove Account NOT In CTS
		DB:			CTS_Adhoc
		Original:

		Revisions:
		Param's Explanation (filtered by):
	*/
	
	DELETE 		def
    FROM 		DCS_DataCenter.DeviceFingerprint AS def
    INNER JOIN	CTS_Adhoc.cs0519_DeviceFingerprint_RemoveBK AS defRev
    WHERE		def.DeviceFingerprintID = defRev.DeviceFingerprintID;
    
END$$
DELIMITER ;