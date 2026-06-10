DELIMITER $$
USE CTS_Adhoc $$
DROP PROCEDURE IF EXISTS CTS_Adhoc.cs0519_DCSAccountNotInCTS_GetDeviceCode$$

CREATE PROCEDURE CTS_Adhoc.cs0519_DCSAccountNotInCTS_GetDeviceCode()
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


	DROP TABLE IF EXISTS CTS_Adhoc.cs0519_DeviceCode_RemoveBK;
	CREATE TABLE CTS_Adhoc.cs0519_DeviceCode_RemoveBK
    SELECT 		dcd.*
    FROM 		DCS_DataCenter.DeviceCode AS dcd
    INNER JOIN  CTS_Adhoc.cs0519_Device_RemoveBK AS revDev
				ON dcd.DeviceID = revDev.DeviceID;
                
END$$
DELIMITER ;