DELIMITER $$
USE CTS_Adhoc $$
DROP PROCEDURE IF EXISTS CTS_Adhoc.cs0519_DCSAccountNotInCTS_GetDevice$$

CREATE PROCEDURE CTS_Adhoc.cs0519_DCSAccountNotInCTS_GetDevice()
BEGIN
	/*
		Created:	20200519@Casey
		Task:		Remove Account NOT In CTS
		DB:			CTS_Adhoc
		Original:

		Revisions:
		Param's Explanation (filtered by):
	*/
    DECLARE n BIGINT;
    DECLARE i BIGINT;
    
	SET SESSION TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;
    
    SELECT '1. INSERT INTO CTS_Adhoc.cs0519_tempAssRevDeviceCount';
    INSERT INTO CTS_Adhoc.cs0519_tempAssRevDeviceCount
	SELECT		assRev.DeviceID, COUNT(1) AS NoOfAccount
	FROM		CTS_Adhoc.cs0519_Association_RemoveBK AS assRev
	GROUP BY	assRev.DeviceID;	
	
    
    # GET ALL Association
   
	SELECT '2. INSERT INTO CTS_Adhoc.cs0519_tempAssociationDevice';
    INSERT INTO CTS_Adhoc.cs0519_tempAssociationDevice
    SELECT		ass.*
	FROM		CTS_Adhoc.cs0519_tempAssRevDeviceCount AS revCou
	INNER JOIN	DCS_DataCenter.Association AS ass
				ON revCou.DeviceID = ass.DeviceID;
			
	SELECT '3. INSERT INTO CTS_Adhoc.cs0519_tempAssociationDeviceCount';
	INSERT INTO CTS_Adhoc.cs0519_tempAssociationDeviceCount
    SELECT		assDev.DeviceID, COUNT(1)
	FROM		CTS_Adhoc.cs0519_tempAssociationDevice AS assDev
	GROUP BY	assDev.DeviceID;

	SELECT '4. INSERT INTO CTS_Adhoc.cs0519_Device_RemoveBK';
	DROP TABLE IF EXISTS CTS_Adhoc.cs0519_Device_RemoveBK;
	CREATE TABLE CTS_Adhoc.cs0519_Device_RemoveBK
    SELECT 		dev.*
    FROM 		DCS_DataCenter.Device AS dev
	INNER JOIN 	(	SELECT 		revCou.DeviceID
					FROM 		CTS_Adhoc.cs0519_tempAssRevDeviceCount AS revCou
                    INNER JOIN 	CTS_Adhoc.cs0519_tempAssociationDeviceCount AS assCou
								ON revCou.DeviceID = assCou.DeviceID
									AND revCou.NoOfAccount = assCou.NoOfAccount
				) 	AS tmpDev
				ON dev.DeviceID = tmpDev.DeviceID;
                
END$$
DELIMITER ;