DELIMITER $$
USE CTS_Adhoc $$
DROP PROCEDURE IF EXISTS CTS_Adhoc.CTMAX_GetDevice$$
CREATE PROCEDURE CTS_Adhoc.CTMAX_GetDevice()
BEGIN
	/*
		Created:	20200601@Casey
		Task:		
		DB:			CTS_Adhoc
		Original:

		Revisions:
		Param's Explanation (filtered by):
	*/
    DECLARE n BIGINT;
    DECLARE i BIGINT;
    
	SET SESSION TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;
    
    SELECT '1. INSERT INTO CTS_Adhoc.csCTMAX_tempAssRevDeviceCount';
    DROP TABLE IF EXISTS csCTMAX_tempAssRevDeviceCount;
    CREATE TABLE CTS_Adhoc.csCTMAX_tempAssRevDeviceCount
	SELECT		assRev.DeviceID, COUNT(1) AS NoOfAccount
	FROM		CTS_Adhoc.csCTMax_Association_bk AS assRev
	GROUP BY	assRev.DeviceID;	
	
    ALTER TABLE csCTMAX_tempAssRevDeviceCount
    ADD INDEX IX_csCTMAX_tempAssRevDeviceCount_DeviceID(DeviceID);
    
    # GET ALL Association
   
	SELECT '2. INSERT INTO CTS_Adhoc.csCTMAX_tempAssociationDevice';
    CREATE TABLE CTS_Adhoc.csCTMAX_tempAssociationDevice
    SELECT		ass.*
	FROM		CTS_Adhoc.csCTMAX_tempAssRevDeviceCount AS revCou
	INNER JOIN	DCS_DataCenter.Association AS ass
				ON revCou.DeviceID = ass.DeviceID;
                
	ALTER TABLE csCTMAX_tempAssociationDevice
    ADD INDEX IX_csCTMAX_csCTMAX_tempAssociationDeviceCount_DeviceID(DeviceID);
			

	SELECT '3. INSERT INTO CTS_Adhoc.csCTMAX_tempAssociationDeviceCount';
	CREATE TABLE CTS_Adhoc.csCTMAX_tempAssociationDeviceCount
    SELECT		assDev.DeviceID, COUNT(1) AS NoOfAccount
	FROM		CTS_Adhoc.csCTMAX_tempAssociationDevice AS assDev
	GROUP BY	assDev.DeviceID;

	SELECT '4. INSERT INTO CTS_Adhoc.csCTMAX_Device_RemoveBK';
	DROP TABLE IF EXISTS CTS_Adhoc.csCTMAX_Device_bk;
	CREATE TABLE CTS_Adhoc.csCTMAX_Device_bk
    SELECT 		dev.*
    FROM 		DCS_DataCenter.Device AS dev
	INNER JOIN 	(	SELECT 		revCou.DeviceID
					FROM 		CTS_Adhoc.csCTMAX_tempAssRevDeviceCount AS revCou
                    INNER JOIN 	CTS_Adhoc.csCTMAX_tempAssociationDeviceCount AS assCou
								ON revCou.DeviceID = assCou.DeviceID
									AND revCou.NoOfAccount = assCou.NoOfAccount
				) 	AS tmpDev
				ON dev.DeviceID = tmpDev.DeviceID;
    ALTER TABLE CTS_Adhoc.csCTMAX_Device_bk
    ADD INDEX IX_csCTMAX_Device_bk_DeviceID(DeviceID);
END$$
DELIMITER ;