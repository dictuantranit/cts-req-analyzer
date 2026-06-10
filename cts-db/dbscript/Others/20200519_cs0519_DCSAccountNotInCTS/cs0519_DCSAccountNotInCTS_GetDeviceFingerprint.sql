DELIMITER $$
USE CTS_Adhoc $$
DROP PROCEDURE IF EXISTS CTS_Adhoc.cs0519_DCSAccountNotInCTS_GetDeviceFingerprint$$

CREATE PROCEDURE CTS_Adhoc.cs0519_DCSAccountNotInCTS_GetDeviceFingerprint()
BEGIN
	/*
		Created:	20200519@Casey
		Task:		Remove Account NOT In CTS
		DB:			CTS_Adhoc
		Original:

		Revisions:
		Param's Explanation (filtered by):
	*/
	SET SESSION TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;
    INSERT INTO CTS_Adhoc.cs0519_DeviceFingerprint_RemoveBK
    SELECT		def.*
	FROM 		DCS_DataCenter.DeviceFingerprint AS def
	INNER JOIN 	CTS_Adhoc.cs0519_Device_RemoveBK AS dev
				ON def.DeviceID = dev.DeviceID;

END$$
DELIMITER ;